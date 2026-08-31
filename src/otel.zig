const std = @import("std");
const Allocator = std.mem.Allocator;
const trace = @import("trace.zig");

pub fn formatOtlpJson(allocator: Allocator, service_name: []const u8, span: *const trace.Span) ![]u8 {
    var trace_hex: [32]u8 = undefined;
    _ = span.context.trace_id.toHex(&trace_hex);

    var span_hex: [16]u8 = undefined;
    _ = span.context.span_id.toHex(&span_hex);

    const start_time_nano = span.start_ns;
    const end_time_nano = span.end_ns orelse span.start_ns;

    const status_code: u8 = switch (span.status) {
        .unset => 0,
        .ok => 1,
        .err => 2,
    };

    if (span.parent_span_id) |parent| {
        var parent_hex: [16]u8 = undefined;
        _ = parent.toHex(&parent_hex);

        return std.fmt.allocPrint(allocator,
            \\{{"resourceSpans":[{{"resource":{{"attributes":[{{"key":"service.name","value":{{"stringValue":"{s}"}}}}]}},"scopeSpans":[{{"scope":{{"name":"zlog.trace","version":"1.0.0"}},"spans":[{{"traceId":"{s}","spanId":"{s}","parentSpanId":"{s}","name":"{s}","kind":1,"startTimeUnixNano":"{d}","endTimeUnixNano":"{d}","status":{{"code":{d}}}}}]}}]}}
        , .{
            service_name,
            trace_hex,
            span_hex,
            parent_hex,
            span.name,
            start_time_nano,
            end_time_nano,
            status_code,
        });
    } else {
        return std.fmt.allocPrint(allocator,
            \\{{"resourceSpans":[{{"resource":{{"attributes":[{{"key":"service.name","value":{{"stringValue":"{s}"}}}}]}},"scopeSpans":[{{"scope":{{"name":"zlog.trace","version":"1.0.0"}},"spans":[{{"traceId":"{s}","spanId":"{s}","name":"{s}","kind":1,"startTimeUnixNano":"{d}","endTimeUnixNano":"{d}","status":{{"code":{d}}}}}]}}]}}
        , .{
            service_name,
            trace_hex,
            span_hex,
            span.name,
            start_time_nano,
            end_time_nano,
            status_code,
        });
    }
}

test "otlp json formatting" {
    const allocator = std.testing.allocator;

    var span = trace.Span.start("test-operation", null);
    span.end();

    const otlp_json = try formatOtlpJson(allocator, "test-service", &span);
    defer allocator.free(otlp_json);

    try std.testing.expect(std.mem.indexOf(u8, otlp_json, "\"test-service\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, otlp_json, "\"test-operation\"") != null);
}
