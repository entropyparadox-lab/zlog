const std = @import("std");
const zlog = @import("zlog");

pub fn main(init: std.process.Init) !void {
    _ = init;

    // 1. Pretty ANSI Terminal Logging
    zlog.setFormat(.ansi);
    zlog.setMinLevel(.debug);

    zlog.info("Server starting", .{
        .host = "127.0.0.1",
        .port = @as(u16, 8080),
        .workers = @as(u32, 8),
    });

    // 2. OpenTelemetry W3C Tracing
    var span = zlog.startSpan("handle_http_request", null);
    defer span.end();

    const traceparent = span.toTraceparent();
    zlog.info("Incoming API Request", .{
        .method = "POST",
        .path = "/api/v1/checkout",
        .traceparent = &traceparent,
        .client_ip = "192.168.1.100",
    });

    // 3. Child Span
    var db_span = zlog.startSpan("db_query_orders", span.context);
    defer db_span.end();

    const db_trace_hex = db_span.context.trace_id.hex();
    zlog.debug("Executing SQL Query", .{
        .query = "SELECT * FROM orders WHERE user_id = $1",
        .user_id = @as(u64, 42918),
        .trace_id = &db_trace_hex,
    });

    zlog.warn("Rate limit approaching", .{
        .remaining_quota = @as(u32, 5),
        .reset_seconds = 12.5,
    });
}
