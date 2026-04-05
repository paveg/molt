# molt

Simple HTTP load testing CLI built with MoonBit native backend.

## Build & Test

```sh
moon build --target native          # build
moon build --target native --release # release build (~2.3MB)
moon test                           # wasm-gc tests (152)
moon test --target native           # all tests including native-only (208)
moon fmt                            # format
moon check --target native          # type check
```

`moon test` (no args) skips native-only packages (worker, coordinator, tui, rate_limiter).
`moon test --target native` runs everything but shows 1 unavoidable WARN (cc-link-flags override).

## Project Structure

```
src/cmd/main/       CLI entry point, argparse
src/lib/types/      Shared types (Config, Stats, RequestResult, HttpMethod)
src/lib/worker/     Async HTTP request loop
src/lib/coordinator/ TaskGroup orchestration, warm-up, rate limiter wiring
src/lib/collector/  Result aggregation with HDR Histogram
src/lib/histogram/  Gil Tene HDR Histogram (3 sig fig)
src/lib/reporter/   Text and JSON output
src/lib/tui/        Real-time TUI via mizchi/tui
src/lib/duration/   Duration string parser ("10s", "1m30s")
src/lib/rate_limiter/ Token bucket with absolute-deadline scheduling
src/lib/threshold/  SLA threshold checking
```

## Conventions

- MoonBit native backend only. Package manifests use `moon.pkg` (DSL format, not JSON).
- `pub(all) struct` fields don't need `pub` prefix.
- Config struct has many fields — adding a field breaks all construction sites. Search with `grep -rn "url," src/` to find them.
- `reserved_keyword` warning: avoid `method` as a field/variable name (use `http_method`).
- Tests: `_test.mbt` (blackbox, `@pkg.` prefix), `_wbtest.mbt` (whitebox, direct access).
- Async functions need `async` keyword. `@async.sleep` takes Int (milliseconds).
- `@http.Client::new(uri)` requires base URL only (no path). Path goes to `client.get(path)`.

## Commit Convention

Conventional Commits: `feat:`, `fix:`, `chore:`, `test:`, `docs:`, `ci:`, `style:`.
Enforced by commitlint on PRs.

## Known Constraints

- `mizchi/tui/io` C stubs don't propagate via cc-link-flags. `cmd/main/moon.pkg` manually links `.mooncakes/mizchi/tui/src/io/tui_native.c`.
- `--insecure` flag exists but upstream `@http.Client` doesn't expose `verify~` to `Tls::client` yet (issue moonbitlang/async#329).
- Rate limiter capped at ~1000 RPS due to ms-only `@async.sleep`. Absolute-deadline scheduling mitigates drift.
