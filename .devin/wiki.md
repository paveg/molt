# molt

## Overview

molt is an HTTP load testing CLI built with MoonBit native backend. It generates concurrent HTTP requests and measures latency with HDR Histogram accuracy.

## Build & Test

```sh
moon build --target native          # build
moon build --target native --release # release (~2.3 MB)
moon test --target native           # 241 tests
moon fmt                            # format
```

## Project Structure

- `src/cmd/main/` — CLI entry point (`main.mbt`) and argument parsing (`cli.mbt`)
- `src/lib/types/` — Shared types: Config (21 fields), Stats, RequestResult, HttpMethod
- `src/lib/worker/` — Async HTTP request loop with TTFB, redirect, reconnection
- `src/lib/coordinator/` — TaskGroup orchestration, warm-up, time-series capture
- `src/lib/collector/` — Result aggregation with dual HDR Histogram (latency + TTFB)
- `src/lib/histogram/` — Gil Tene HDR Histogram (3 sig fig, O(1) record)
- `src/lib/reporter/` — Text (`text.mbt`), JSON (`json.mbt`), CSV (`csv.mbt`), helpers (`format.mbt`)
- `src/lib/tui/` — Real-time TUI via mizchi/tui
- `src/lib/duration/` — Duration/count parser ("10s", "1m30s", "10k")
- `src/lib/rate_limiter/` — Absolute-deadline token bucket
- `src/lib/threshold/` — SLA threshold checking

## Key Conventions

- MoonBit native backend only. Package manifests use `moon.pkg` DSL format.
- `pub(all) struct` fields don't need `pub` prefix.
- Config struct has 21 fields — adding a field breaks ALL construction sites.
- Field name `method` is reserved in MoonBit — use `http_method`.
- Tests: `_test.mbt` (blackbox), `_wbtest.mbt` (whitebox).
- Conventional Commits enforced: `feat:`, `fix:`, `chore:`, `test:`, `docs:`, `ci:`.

## Dependencies

- `moonbitlang/async` (0.16.0) — async runtime, TaskGroup, Queue
- `mizchi/tui` (0.8.0) — TUI framework
- `moonbitlang/x` (0.4.40) — filesystem, sys exit

## Known Constraints

- `mizchi/tui/io` C stubs require manual `cc-link-flags` in `cmd/main/moon.pkg`.
- `--insecure` flag exists but upstream `@http.Client` doesn't expose `verify~` yet (moonbitlang/async#329).
- Rate limiter capped at ~1000 RPS due to ms-only `@async.sleep`.
- `@http.Client::new(uri)` requires base URL only (no path). Path goes to `client.get(path)`.

## Exit Codes

- 0: Success
- 1: Configuration error
- 2: Test completed with failures
- 3: SLA threshold violation
