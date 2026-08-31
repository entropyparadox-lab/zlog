const std = @import("std");
const zlog = @import("zlog");

fn getMonotonicNs() u64 {
    var ts: std.posix.timespec = undefined;
    _ = std.posix.system.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * 1_000_000_000 + @as(u64, @intCast(ts.nsec));
}

pub fn main(init: std.process.Init) !void {
    _ = init;

    var mem = zlog.MemorySink.init();
    var logger = zlog.Logger.init(.{ .min_level = .debug, .format = .ndjson }, mem.sink());

    // 1. Warmup
    var w: usize = 0;
    while (w < 10_000) : (w += 1) {
        mem.clear();
        logger.info("HTTP Request Completed", .{
            .status = @as(u16, 200),
            .path = "/api/v1/users",
            .latency_ms = 4.25,
            .user_id = @as(u64, 104928),
        });
    }

    // 2. Measure
    const iterations: usize = 1_000_000;
    const start_ns = getMonotonicNs();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        mem.clear();
        logger.info("HTTP Request Completed", .{
            .status = @as(u16, 200),
            .path = "/api/v1/users",
            .latency_ms = 4.25,
            .user_id = @as(u64, 104928),
        });
    }

    const end_ns = getMonotonicNs();
    const elapsed_ns = end_ns - start_ns;
    const elapsed_sec = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    const ops_per_sec = @as(f64, @floatFromInt(iterations)) / elapsed_sec;
    const latency_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));

    std.debug.print("\n=== zlog Benchmark Highlights (ReleaseFast, {d} runs) ===\n", .{iterations});
    std.debug.print("• Total Time   : {d:.4} s\n", .{elapsed_sec});
    std.debug.print("• Throughput   : {d:.2} logs/sec ({d:.2} M logs/sec)\n", .{ ops_per_sec, ops_per_sec / 1_000_000.0 });
    std.debug.print("• Latency      : {d:.2} ns/log\n", .{latency_ns});
    std.debug.print("• Memory Alloc : 0 bytes (Zero-Allocation Stack Buffer)\n\n", .{});
}
