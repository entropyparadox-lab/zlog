const std = @import("std");

pub const Level = enum(u8) {
    debug = 0,
    info = 1,
    warn = 2,
    err = 3,
    fatal = 4,
    silent = 5,

    pub fn asString(self: Level) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
            .fatal => "FATAL",
            .silent => "SILENT",
        };
    }

    pub fn asLowerString(self: Level) []const u8 {
        return switch (self) {
            .debug => "debug",
            .info => "info",
            .warn => "warn",
            .err => "error",
            .fatal => "fatal",
            .silent => "silent",
        };
    }

    pub fn ansiColor(self: Level) []const u8 {
        return switch (self) {
            .debug => "\x1b[36m", // Cyan
            .info => "\x1b[32m", // Green
            .warn => "\x1b[33m", // Yellow
            .err => "\x1b[31m", // Red
            .fatal => "\x1b[35m", // Magenta
            .silent => "",
        };
    }
};

pub const Format = enum {
    ansi,
    ndjson,
    compact,
};

pub const Sink = struct {
    ptr: *anyopaque,
    write_fn: *const fn (ctx: *anyopaque, bytes: []const u8) anyerror!void,

    pub fn write(self: Sink, bytes: []const u8) !void {
        return self.write_fn(self.ptr, bytes);
    }
};

pub const StdioSink = struct {
    fd: std.posix.fd_t,

    pub fn stdout() StdioSink {
        return .{ .fd = std.posix.STDOUT_FILENO };
    }

    pub fn stderr() StdioSink {
        return .{ .fd = std.posix.STDERR_FILENO };
    }

    pub fn sink(self: *StdioSink) Sink {
        return .{
            .ptr = self,
            .write_fn = writeFn,
        };
    }

    fn writeFn(ctx: *anyopaque, bytes: []const u8) anyerror!void {
        const self: *StdioSink = @ptrCast(@alignCast(ctx));
        _ = std.posix.system.write(self.fd, bytes.ptr, bytes.len);
    }
};

pub const MemorySink = struct {
    buffer: [65536]u8 = undefined,
    len: usize = 0,

    pub fn init() MemorySink {
        return .{};
    }

    pub fn sink(self: *MemorySink) Sink {
        return .{
            .ptr = self,
            .write_fn = writeFn,
        };
    }

    pub fn getWritten(self: *const MemorySink) []const u8 {
        return self.buffer[0..self.len];
    }

    pub fn clear(self: *MemorySink) void {
        self.len = 0;
    }

    fn writeFn(ctx: *anyopaque, bytes: []const u8) anyerror!void {
        const self: *MemorySink = @ptrCast(@alignCast(ctx));
        if (self.len + bytes.len > self.buffer.len) {
            return error.BufferOverflow;
        }
        @memcpy(self.buffer[self.len .. self.len + bytes.len], bytes);
        self.len += bytes.len;
    }
};
