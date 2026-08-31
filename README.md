# zlog 🪵

[![Zig Version](https://img.shields.io/badge/Zig-0.16.0%2B-orange.svg)](https://ziglang.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Zero-Allocation](https://img.shields.io/badge/Zero--Allocation-Stack%20Fast--Path-brightgreen.svg)]()
[![OpenTelemetry](https://img.shields.io/badge/OpenTelemetry-W3C%20TraceContext-purple.svg)]()

**Zero-Allocation Structured Logger, ANSI/NDJSON Formatters & W3C OpenTelemetry Tracing for Pure Zig (v0.16.0+)**

`zlog` brings fast, ergonomic structured logging and distributed tracing to Zig. It features **zero heap allocations** on the logging fast-path (using an inline 4KB stack buffer and comptime struct reflection), high-contrast ANSI terminal formatting, production-grade NDJSON streaming, and full **W3C TraceContext** (`traceparent`) / **OpenTelemetry OTLP** span correlation.

---

## Benchmark Highlights (AMD Ryzen / ReleaseFast, 1,000,000 runs)

| Scenario | Throughput (logs/sec) | Latency (ns/log) | Memory Allocation |
| :--- | :--- | :--- | :--- |
| **4-Field Structured NDJSON Log** | **1,427,000 logs/sec** | **700.7 ns** | **0 bytes (Zero-Alloc Stack Buffer)** |

---

## Key Features

- 🚀 **Zero-Allocation Stack Fast-Path**: Serializes structured key-value attributes directly into an inline 4KB buffer with 0 heap bytes allocated.
- 🎨 **Rich Output Formatters**:
  - **Pretty ANSI Terminal**: Color-coded level badges (`INFO`, `WARN`, `ERROR`), microsecond timestamps, and syntax-highlighted key=value pairs.
  - **Production NDJSON**: Standard newline-delimited JSON logs (`{"time":1740840000,"level":"info","msg":"...","user_id":42}`).
  - **Compact Text**: Key=value pair format for log collectors.
- 🌐 **W3C TraceContext & OpenTelemetry Integration (`zlog.trace` / `zlog.otel`)**:
  - **W3C `traceparent` Standard**: `00-{trace_id}-{span_id}-{flags}` generator and parser.
  - **Hierarchical Spans**: Nested span timing, status codes, and trace context propagation.
  - **OTLP/JSON Exporter**: Formats spans into OpenTelemetry Collector JSON payloads for `zfetch`.
- 🔌 **Pluggable Sinks**: `StdioSink` (stdout/stderr), `MemorySink` (unit testing), and custom sinks.
- 📦 **Pure Zig 0.16.0+**: Zero C dependencies, instant build times, fully cross-compilable.

---

## Installation (`build.zig.zon`)

Add `zlog` to your `build.zig.zon`:

```bash
zig fetch --save https://github.com/entropyparadox-lab/zlog/archive/refs/tags/v1.0.0.tar.gz
```

In your `build.zig`:

```zig
const zlog_dep = b.dependency("zlog", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zlog", zlog_dep.module("zlog"));
```

---

## Quickstart

### 1. Structured Logging & Distributed Tracing

```zig
const std = @import("std");
const zlog = @import("zlog");

pub fn main(init: std.process.Init) !void {
    _ = init;

    // 1. Structured Logging
    zlog.setFormat(.ansi);
    zlog.setMinLevel(.debug);

    // 2. Distributed Tracing
    var span = zlog.startSpan("handle_http_request", null);
    defer span.end();

    const traceparent = span.toTraceparent();

    zlog.info("Incoming API Request", .{
        .method = "POST",
        .path = "/api/v1/checkout",
        .traceparent = &traceparent,
        .client_ip = "192.168.1.100",
        .user_id = @as(u64, 42918),
    });
}
```

---

## License

MIT License (c) 2026 Entropy Paradox Lab / Charles Choi
