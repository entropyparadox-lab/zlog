const std = @import("std");

pub const types = @import("types.zig");
pub const logger = @import("logger.zig");
pub const trace = @import("trace.zig");
pub const otel = @import("otel.zig");

// Types & Loggers
pub const Level = types.Level;
pub const Format = types.Format;
pub const Sink = types.Sink;
pub const StdioSink = types.StdioSink;
pub const MemorySink = types.MemorySink;
pub const Logger = logger.Logger;
pub const LoggerConfig = logger.LoggerConfig;

// Tracing & OTel
pub const TraceId = trace.TraceId;
pub const SpanId = trace.SpanId;
pub const TraceContext = trace.TraceContext;
pub const Span = trace.Span;
pub const SpanStatus = trace.SpanStatus;
pub const startSpan = trace.Span.start;
pub const formatOtlpJson = otel.formatOtlpJson;

// Default Global Stderr Logger (Zero-Allocation)
var default_stderr_sink = types.StdioSink.stderr();
pub var default_logger = Logger{
    .config = .{ .min_level = .info, .format = .ansi },
    .sink = default_stderr_sink.sink(),
};

pub fn setMinLevel(lvl: Level) void {
    default_logger.config.min_level = lvl;
}

pub fn setFormat(fmt: Format) void {
    default_logger.config.format = fmt;
}

pub fn debug(msg: []const u8, fields: anytype) void {
    default_logger.debug(msg, fields);
}

pub fn info(msg: []const u8, fields: anytype) void {
    default_logger.info(msg, fields);
}

pub fn warn(msg: []const u8, fields: anytype) void {
    default_logger.warn(msg, fields);
}

pub fn err(msg: []const u8, fields: anytype) void {
    default_logger.err(msg, fields);
}

pub fn fatal(msg: []const u8, fields: anytype) void {
    default_logger.fatal(msg, fields);
}

test {
    _ = types;
    _ = logger;
    _ = trace;
    _ = otel;
}
