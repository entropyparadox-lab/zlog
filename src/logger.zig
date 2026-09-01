const std = @import("std");
const types = @import("types.zig");

pub const StackWriter = struct {
    buf: [4096]u8 = undefined,
    pos: usize = 0,

    pub fn writeByte(self: *StackWriter, b: u8) !void {
        if (self.pos >= self.buf.len) return error.NoSpaceLeft;
        self.buf[self.pos] = b;
        self.pos += 1;
    }

    pub fn writeAll(self: *StackWriter, s: []const u8) !void {
        if (self.pos + s.len > self.buf.len) return error.NoSpaceLeft;
        @memcpy(self.buf[self.pos .. self.pos + s.len], s);
        self.pos += s.len;
    }

    pub fn print(self: *StackWriter, comptime fmt: []const u8, args: anytype) !void {
        const formatted = try std.fmt.bufPrint(self.buf[self.pos..], fmt, args);
        self.pos += formatted.len;
    }

    pub fn getWritten(self: *const StackWriter) []const u8 {
        return self.buf[0..self.pos];
    }
};

pub const LoggerConfig = struct {
    min_level: types.Level = .info,
    format: types.Format = .ansi,
};

pub const Logger = struct {
    config: LoggerConfig,
    sink: types.Sink,

    pub fn init(config: LoggerConfig, sink: types.Sink) Logger {
        return .{
            .config = config,
            .sink = sink,
        };
    }

    pub fn log(self: *Logger, level: types.Level, msg: []const u8, fields: anytype) !void {
        if (@intFromEnum(level) < @intFromEnum(self.config.min_level)) return;

        var writer = StackWriter{};

        switch (self.config.format) {
            .ansi => try formatAnsi(&writer, level, msg, fields),
            .ndjson => try formatNdjson(&writer, level, msg, fields),
            .compact => try formatCompact(&writer, level, msg, fields),
        }

        try self.sink.write(writer.getWritten());
    }

    pub fn debug(self: *Logger, msg: []const u8, fields: anytype) void {
        self.log(.debug, msg, fields) catch {};
    }

    pub fn info(self: *Logger, msg: []const u8, fields: anytype) void {
        self.log(.info, msg, fields) catch {};
    }

    pub fn warn(self: *Logger, msg: []const u8, fields: anytype) void {
        self.log(.warn, msg, fields) catch {};
    }

    pub fn err(self: *Logger, msg: []const u8, fields: anytype) void {
        self.log(.err, msg, fields) catch {};
    }

    pub fn fatal(self: *Logger, msg: []const u8, fields: anytype) void {
        self.log(.fatal, msg, fields) catch {};
    }
};

fn formatAnsi(writer: *StackWriter, level: types.Level, msg: []const u8, fields: anytype) !void {
    var sec: u64 = 0;
    var ms: u64 = 0;
    if (@import("builtin").os.tag == .windows) {
        var pc: std.os.windows.LARGE_INTEGER = undefined;
        _ = std.os.windows.ntdll.RtlQueryPerformanceCounter(&pc);
        sec = @as(u64, @intCast(@max(0, pc))) / 10_000_000;
        ms = (@as(u64, @intCast(@max(0, pc))) / 10_000) % 1000;
    } else {
        var ts: std.posix.timespec = undefined;
        _ = std.posix.system.clock_gettime(.REALTIME, &ts);
        sec = @as(u64, @intCast(ts.sec));
        ms = @as(u64, @intCast(ts.nsec)) / 1_000_000;
    }
    const hours = (sec / 3600) % 24;
    const mins = (sec / 60) % 60;
    const secs = sec % 60;

    // Timestamp & Badge
    try writer.print("\x1b[90m{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}\x1b[0m {s}{s: <5}\x1b[0m \x1b[1;37m{s}\x1b[0m", .{
        hours,
        mins,
        secs,
        ms,
        level.ansiColor(),
        level.asString(),
        msg,
    });

    // Fields
    const FieldsType = @TypeOf(fields);
    if (@typeInfo(FieldsType) == .@"struct") {
        inline for (@typeInfo(FieldsType).@"struct".fields) |f| {
            const val = @field(fields, f.name);
            try writer.print(" \x1b[36m{s}\x1b[0m=", .{f.name});
            try formatValueAnsi(writer, val);
        }
    }

    try writer.writeAll("\n");
}

fn formatNdjson(writer: *StackWriter, level: types.Level, msg: []const u8, fields: anytype) !void {
    var timestamp_ms: u64 = 0;
    if (@import("builtin").os.tag == .windows) {
        var pc: std.os.windows.LARGE_INTEGER = undefined;
        _ = std.os.windows.ntdll.RtlQueryPerformanceCounter(&pc);
        timestamp_ms = @as(u64, @intCast(@max(0, pc))) / 10_000;
    } else {
        var ts: std.posix.timespec = undefined;
        _ = std.posix.system.clock_gettime(.REALTIME, &ts);
        timestamp_ms = @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
    }

    try writer.print("{{\"time\":{d},\"level\":\"{s}\",\"msg\":\"", .{
        timestamp_ms,
        level.asLowerString(),
    });
    try writeJsonEscaped(writer, msg);
    try writer.writeByte('"');

    const FieldsType = @TypeOf(fields);
    if (@typeInfo(FieldsType) == .@"struct") {
        inline for (@typeInfo(FieldsType).@"struct".fields) |f| {
            const val = @field(fields, f.name);
            try writer.print(",\"{s}\":", .{f.name});
            try formatValueJson(writer, val);
        }
    }

    try writer.writeAll("}\n");
}

fn formatCompact(writer: *StackWriter, level: types.Level, msg: []const u8, fields: anytype) !void {
    try writer.print("level={s} msg=\"{s}\"", .{
        level.asLowerString(),
        msg,
    });

    const FieldsType = @TypeOf(fields);
    if (@typeInfo(FieldsType) == .@"struct") {
        inline for (@typeInfo(FieldsType).@"struct".fields) |f| {
            const val = @field(fields, f.name);
            try writer.print(" {s}=", .{f.name});
            try formatValueAnsi(writer, val);
        }
    }

    try writer.writeAll("\n");
}

fn formatValueAnsi(writer: *StackWriter, val: anytype) !void {
    const T = @TypeOf(val);
    const info = @typeInfo(T);

    switch (info) {
        .int, .float => try writer.print("{d}", .{val}),
        .bool => try writer.writeAll(if (val) "true" else "false"),
        .pointer => |ptr| {
            if (ptr.size == .slice and ptr.child == u8) {
                try writer.print("\"{s}\"", .{val});
            } else if (ptr.size == .one and @typeInfo(ptr.child) == .array and @typeInfo(ptr.child).array.child == u8) {
                try writer.print("\"{s}\"", .{std.mem.sliceTo(val, 0)});
            } else {
                try writer.print("{any}", .{val});
            }
        },
        .@"enum" => try writer.print("{s}", .{@tagName(val)}),
        .optional => {
            if (val) |v| {
                try formatValueAnsi(writer, v);
            } else {
                try writer.writeAll("null");
            }
        },
        else => try writer.print("{any}", .{val}),
    }
}

fn formatValueJson(writer: *StackWriter, val: anytype) !void {
    const T = @TypeOf(val);
    const info = @typeInfo(T);

    switch (info) {
        .int, .float => try writer.print("{d}", .{val}),
        .bool => try writer.writeAll(if (val) "true" else "false"),
        .pointer => |ptr| {
            if (ptr.size == .slice and ptr.child == u8) {
                try writer.writeByte('"');
                try writeJsonEscaped(writer, val);
                try writer.writeByte('"');
            } else if (ptr.size == .one and @typeInfo(ptr.child) == .array and @typeInfo(ptr.child).array.child == u8) {
                try writer.writeByte('"');
                try writeJsonEscaped(writer, std.mem.sliceTo(val, 0));
                try writer.writeByte('"');
            } else {
                try writer.print("\"{any}\"", .{val});
            }
        },
        .@"enum" => try writer.print("\"{s}\"", .{@tagName(val)}),
        .optional => {
            if (val) |v| {
                try formatValueJson(writer, v);
            } else {
                try writer.writeAll("null");
            }
        },
        else => try writer.print("\"{any}\"", .{val}),
    }
}

fn writeJsonEscaped(writer: *StackWriter, str: []const u8) !void {
    for (str) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => try writer.writeByte(c),
        }
    }
}

test "logger ndjson and ansi formatting" {
    var mem = types.MemorySink.init();
    var logger = Logger.init(.{ .min_level = .debug, .format = .ndjson }, mem.sink());

    logger.info("HTTP Request Completed", .{
        .status = @as(u16, 200),
        .path = "/api/v1/users",
        .latency_ms = 4.25,
        .is_auth = true,
    });

    const output = mem.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, output, "\"level\":\"info\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"path\":\"/api/v1/users\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"status\":200") != null);
}
