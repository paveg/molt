---
name: molt
description: |
  Run HTTP load tests using molt, a MoonBit-native load testing CLI.
  Use when the user asks to load test, benchmark, stress test, or
  performance test an HTTP endpoint. Handles command construction,
  execution, and result analysis.
license: MIT
metadata:
  author: paveg
  version: '0.1.0'
---

# molt — HTTP Load Testing

molt is a CLI load testing tool. You use it to send concurrent HTTP requests to a target URL and analyze latency, throughput, and error rates.

## Prerequisites

molt must be built before use. Check if a binary exists, otherwise build it:

```bash
# Check for existing binary
ls target/native/release/build/cmd/main/main 2>/dev/null

# Build if needed
moon build --target native --release
```

The binary path is `target/native/release/build/cmd/main/main`, or run directly via `moon run src/cmd/main --target native --`.

## Running Load Tests

**Always use `--no-tui --json`** when running molt. TUI mode requires an interactive terminal and will not work in this environment. JSON output enables structured analysis.

```bash
moon run src/cmd/main --target native -- --no-tui --json [options] <url>
```

### Core Options

| Option | Description | Default |
|--------|-------------|---------|
| `-c, --connections <N>` | Concurrent connections | 50 |
| `-d, --duration <dur>` | Test duration (e.g. `10s`, `1m`) | — |
| `-n, --requests <N>` | Total request count | — |
| `-m, --method <M>` | HTTP method | GET |
| `-H, --header <H>` | Custom header (repeatable) | — |
| `-b, --body <str>` | Request body | — |
| `-B, --body-file <path>` | Request body from file | — |
| `-r, --rate <N>` | Target requests/sec | unlimited |
| `-t, --timeout <dur>` | Per-request timeout | 30s |
| `--warm-up <dur>` | Warm-up period excluded from stats | — |
| `--auth <user:pass>` | Basic auth credentials | — |
| `-L, --redirect` | Follow redirects (up to 10) | off |
| `--disable-keepalive` | New connection per request | off |
| `--debug` | Single request with full details | off |

### Threshold Options (CI/SLA)

| Option | Description | Example |
|--------|-------------|---------|
| `--latency-threshold <dur>` | Fail if p99 exceeds value | `100ms` |
| `--error-threshold <pct>` | Fail if error rate exceeds % | `1.0` |
| `--percentiles <list>` | Custom percentiles to compute | `50,90,99,99.99` |

### Output Formats

| Flag | Format |
|------|--------|
| `--json` | Structured JSON (preferred for analysis) |
| `--csv` | Per-request CSV rows |
| (default) | Human-readable text table |

## JSON Output Schema

```json
{
  "config": { "url", "connections", "duration_sec", "rate_rps", "timeout_ms", "method" },
  "summary": { "total_requests", "successful", "failed", "total_time_sec", "requests_per_sec" },
  "latency": { "p50_ms", "p75_ms", "p90_ms", "p95_ms", "p99_ms", "p99_9_ms", "max_ms", "min_ms", "mean_ms", "stdev_ms" },
  "ttfb": { "p50_ms", "p99_ms", "max_ms", "mean_ms", "stdev_ms" },
  "status_codes": { "<code>": <count> },
  "errors": { "<message>": <count> },
  "throughput": { "total_bytes", "bytes_per_sec" }
}
```

## Common Patterns

### Quick smoke test

```bash
moon run src/cmd/main --target native -- --no-tui --json -c 10 -n 100 https://api.example.com/health
```

### Sustained load for 30 seconds

```bash
moon run src/cmd/main --target native -- --no-tui --json -c 50 -d 30s https://api.example.com/endpoint
```

### Rate-limited test (100 RPS)

```bash
moon run src/cmd/main --target native -- --no-tui --json -c 20 -d 30s -r 100 https://api.example.com/endpoint
```

### POST with JSON body

```bash
moon run src/cmd/main --target native -- --no-tui --json -m POST \
  -H 'Content-Type: application/json' \
  -b '{"key": "value"}' \
  -c 10 -d 10s https://api.example.com/endpoint
```

### CI gate with SLA thresholds

```bash
moon run src/cmd/main --target native -- --no-tui --json \
  -c 50 -d 30s \
  --latency-threshold 200ms \
  --error-threshold 1.0 \
  https://api.example.com/endpoint
```

### Debug a single request

```bash
moon run src/cmd/main --target native -- --debug https://api.example.com/endpoint
```

### Local testing with built-in server

molt includes a test HTTP server. Useful for verifying molt itself or demonstrating usage:

```bash
# Terminal 1: start test server
moon run src/cmd/main --target native -- --serve 127.0.0.1:8080

# Terminal 2: run test against it
moon run src/cmd/main --target native -- --no-tui --json -c 10 -n 100 http://127.0.0.1:8080
```

## Analyzing Results

After running a test with `--json`, parse the output and report:

1. **Throughput**: `summary.requests_per_sec` — is it meeting expectations?
2. **Latency profile**: Compare `p50` vs `p99` — large gaps indicate tail latency issues
3. **Error rate**: `summary.failed / summary.total_requests` — any non-zero errors need investigation
4. **Status codes**: Check for unexpected 4xx/5xx in `status_codes`
5. **TTFB**: `ttfb.p99_ms` — high values suggest server processing bottlenecks

### Red flags to highlight

- p99 > 5x p50 (tail latency problem)
- Error rate > 1%
- Non-2xx status codes present
- stdev > mean (highly variable latency)
- Throughput drops vs connection count (server saturation)

## Important Notes

- **Always use `--no-tui`** — TUI mode blocks in non-interactive environments
- **Prefer `--json`** — enables structured analysis instead of text parsing
- **Be conservative with defaults** — start with low `-c` and short `-d`, increase after baseline
- **Warn before high load** — ask the user before running `-c 100+` or `-r 500+` against production
- **`--insecure` exists but is not yet functional** — TLS verify skip is pending upstream release
