const std = @import("std");

var global_seq: u64 = 1;

pub const TraceId = struct {
    bytes: [16]u8,

    pub fn generate() TraceId {
        var id = TraceId{ .bytes = undefined };
        fillRandomBytes(&id.bytes);
        if (std.mem.allEqual(u8, &id.bytes, 0)) {
            id.bytes[0] = 1;
        }
        return id;
    }

    pub fn hex(self: TraceId) [32]u8 {
        var out: [32]u8 = undefined;
        _ = self.toHex(&out);
        return out;
    }

    pub fn toHex(self: TraceId, out: *[32]u8) []const u8 {
        const hex_chars = "0123456789abcdef";
        for (self.bytes, 0..) |b, i| {
            out[i * 2] = hex_chars[b >> 4];
            out[i * 2 + 1] = hex_chars[b & 0x0f];
        }
        return out;
    }

    pub fn fromHex(hex_str: []const u8) ?TraceId {
        if (hex_str.len != 32) return null;
        var id = TraceId{ .bytes = undefined };
        _ = std.fmt.hexToBytes(&id.bytes, hex_str) catch return null;
        if (std.mem.allEqual(u8, &id.bytes, 0)) return null;
        return id;
    }
};

pub const SpanId = struct {
    bytes: [8]u8,

    pub fn generate() SpanId {
        var id = SpanId{ .bytes = undefined };
        fillRandomBytes(&id.bytes);
        if (std.mem.allEqual(u8, &id.bytes, 0)) {
            id.bytes[0] = 1;
        }
        return id;
    }

    pub fn toHex(self: SpanId, out: *[16]u8) []const u8 {
        const hex_chars = "0123456789abcdef";
        for (self.bytes, 0..) |b, i| {
            out[i * 2] = hex_chars[b >> 4];
            out[i * 2 + 1] = hex_chars[b & 0x0f];
        }
        return out;
    }

    pub fn fromHex(hex: []const u8) ?SpanId {
        if (hex.len != 16) return null;
        var id = SpanId{ .bytes = undefined };
        _ = std.fmt.hexToBytes(&id.bytes, hex) catch return null;
        if (std.mem.allEqual(u8, &id.bytes, 0)) return null;
        return id;
    }
};

pub const TraceContext = struct {
    trace_id: TraceId,
    span_id: SpanId,
    flags: u8 = 0x01, // Sampled

    pub fn init() TraceContext {
        return .{
            .trace_id = TraceId.generate(),
            .span_id = SpanId.generate(),
            .flags = 0x01,
        };
    }

    pub fn child(self: TraceContext) TraceContext {
        return .{
            .trace_id = self.trace_id,
            .span_id = SpanId.generate(),
            .flags = self.flags,
        };
    }

    /// Formats standard W3C traceparent header: `00-{trace_id}-{span_id}-{flags:0>2x}` (55 bytes)
    pub fn toTraceparent(self: TraceContext) [55]u8 {
        var out: [55]u8 = undefined;
        out[0] = '0';
        out[1] = '0';
        out[2] = '-';

        var trace_hex: [32]u8 = undefined;
        _ = self.trace_id.toHex(&trace_hex);
        @memcpy(out[3..35], &trace_hex);
        out[35] = '-';

        var span_hex: [16]u8 = undefined;
        _ = self.span_id.toHex(&span_hex);
        @memcpy(out[36..52], &span_hex);
        out[52] = '-';

        const hex_chars = "0123456789abcdef";
        out[53] = hex_chars[self.flags >> 4];
        out[54] = hex_chars[self.flags & 0x0f];

        return out;
    }

    pub fn fromTraceparent(header: []const u8) ?TraceContext {
        const trimmed = std.mem.trim(u8, header, " \t");
        if (trimmed.len != 55) return null;
        if (!std.mem.startsWith(u8, trimmed, "00-") or trimmed[35] != '-' or trimmed[52] != '-') return null;

        const trace_id = TraceId.fromHex(trimmed[3..35]) orelse return null;
        const span_id = SpanId.fromHex(trimmed[36..52]) orelse return null;

        var flags_byte: [1]u8 = undefined;
        _ = std.fmt.hexToBytes(&flags_byte, trimmed[53..55]) catch return null;

        return TraceContext{
            .trace_id = trace_id,
            .span_id = span_id,
            .flags = flags_byte[0],
        };
    }
};

pub const SpanStatus = enum {
    unset,
    ok,
    err,
};

pub const Span = struct {
    name: []const u8,
    context: TraceContext,
    parent_span_id: ?SpanId = null,
    start_ns: u64,
    end_ns: ?u64 = null,
    status: SpanStatus = .unset,

    pub fn start(name: []const u8, maybe_parent: ?TraceContext) Span {
        const start_time = getMonotonicNs();
        const ctx = if (maybe_parent) |p| p.child() else TraceContext.init();
        return .{
            .name = name,
            .context = ctx,
            .parent_span_id = if (maybe_parent) |p| p.span_id else null,
            .start_ns = start_time,
        };
    }

    pub fn end(self: *Span) void {
        if (self.end_ns == null) {
            self.end_ns = getMonotonicNs();
            if (self.status == .unset) {
                self.status = .ok;
            }
        }
    }

    pub fn setStatus(self: *Span, status: SpanStatus) void {
        self.status = status;
    }

    pub fn elapsedNs(self: *const Span) u64 {
        const end_time = self.end_ns orelse getMonotonicNs();
        return if (end_time >= self.start_ns) end_time - self.start_ns else 0;
    }

    pub fn toTraceparent(self: *const Span) [55]u8 {
        return self.context.toTraceparent();
    }
};

fn fillRandomBytes(buf: []u8) void {
    var ts: std.posix.timespec = undefined;
    _ = std.posix.system.clock_gettime(.REALTIME, &ts);
    const seed = @as(u64, @intCast(ts.nsec)) ^ (@as(u64, @intCast(ts.sec)) << 32) ^ global_seq;
    global_seq +%= 0x9e3779b97f4a7c15;

    var prng = std.Random.DefaultPrng.init(seed);
    prng.random().bytes(buf);
}

fn getMonotonicNs() u64 {
    var ts: std.posix.timespec = undefined;
    _ = std.posix.system.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * 1_000_000_000 + @as(u64, @intCast(ts.nsec));
}

test "w3c traceparent serialization and deserialization" {
    const ctx = TraceContext.init();
    const tp = ctx.toTraceparent();

    try std.testing.expect(tp.len == 55);
    try std.testing.expect(std.mem.startsWith(u8, &tp, "00-"));

    const parsed = TraceContext.fromTraceparent(&tp).?;
    try std.testing.expectEqual(ctx.trace_id.bytes, parsed.trace_id.bytes);
    try std.testing.expectEqual(ctx.span_id.bytes, parsed.span_id.bytes);
    try std.testing.expectEqual(ctx.flags, parsed.flags);
}
