# Contributing to zlog 🪵

Thank you for contributing to `zlog`! To maintain high throughput, low latency, and zero memory leaks in the Zig ecosystem, we follow strict quality guidelines.

---

## 1. Compiler Versioning & Branch Strategy

* **`main` (Protected)**: Requires Zig **0.17.0** or newer; CI tests stable Zig **0.17.1**. All production releases (`vX.Y.Z`) are cut exclusively from `main`.
* **Development snapshots**: Pin the full Zig version, including the commit suffix, in `build.zig.zon` and CI. Do not describe an unreleased version as stable.
* **`feat/<name>` / `fix/<name>`**: Branch off `main` for stable changes.

---

## 2. Strict Quality & Verification Gate

1. **100% Tested & Verified**: Every PR must include reproducible test coverage (`zig build test`).
2. **Zero-Allocation Invariant**: Structured logging fast-path must **NEVER** allocate heap memory.
3. **No Regressions**: Benchmark throughput (`zig build bench`) must sustain >1.4M logs/sec.

---

## 3. Fast Local Development & Git Hooks

Install local pre-commit hooks:
```bash
./scripts/setup-hooks.sh
```

Before opening a PR, run full local verification:
```bash
# 1. Format code
zig fmt src/ examples/ tests/ build.zig

# 2. Run unit tests
zig build test

# 3. Run benchmarks
zig build bench
```
