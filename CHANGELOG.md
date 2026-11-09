# Changelog

## 1.1.1 — 2026-11-09

- Validate tests, the example, and benchmarks with Zig 0.17.1 while retaining
  Zig 0.17.0 as the tested minimum compiler version.
- Pin CI to stable Zig 0.17.1.
- Include examples and benchmark sources in the package paths so fetched
  archives support the build steps declared in `build.zig`.
- Document the development `main` installation archive and compiler support.
- No public functions added or changed.
