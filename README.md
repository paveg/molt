# molt

**Simple HTTP load testing CLI built with MoonBit.**

A lightweight, fast HTTP load testing tool inspired by [oha](https://github.com/hatoo/oha) and [hey](https://github.com/rakyll/hey). Built entirely in MoonBit using the native backend for direct I/O without WASM overhead.

## Features

- **High-performance concurrent load generation** with configurable worker count
- **HDR Histogram latency recording** -- Gil Tene algorithm with 3 significant figures, O(1) per record
- **Real-time TUI dashboard** -- live RPS, p50/p99, progress bar via [mizchi/tui](https://mooncakes.io/docs/#/mizchi/tui/)
- **Multiple output modes** -- TUI (default), plain text (`--no-tui`), JSON (`--json`)
- **Full HTTP method support** -- GET, POST, PUT, DELETE with custom headers and body
- **Flexible test modes** -- by duration (`-d 30s`) or by total request count (`-n 10000`)
- **Accurate percentiles** -- p50, p75, p90, p95, p99, p99.9 via HDR Histogram
- **Small binary** -- ~2.4 MB standalone native executable

## Quick Start

```sh
# Build
moon build --target native

# Copy to PATH (optional)
cp _build/native/debug/build/src/cmd/main/main.exe /usr/local/bin/molt

# Run a basic load test
molt -c 10 -d 5s http://localhost:8080/api/health
```

## Usage Examples

```sh
# Basic GET -- 50 connections, 10 seconds (defaults)
molt http://localhost:8080/

# Custom connections and duration
molt -c 100 -d 30s http://localhost:8080/api/health

# POST with JSON body and headers
molt -m POST \
  -H 'Content-Type: application/json' \
  -b '{"name":"test","value":42}' \
  -c 20 -d 15s \
  http://localhost:8080/api/users

# Fixed request count instead of duration
molt -n 10000 -c 50 http://localhost:8080/

# JSON output for CI pipelines
molt --json -c 50 -d 10s http://localhost:8080/ > results.json

# Plain text mode (no TUI, prints periodic status lines)
molt --no-tui -c 10 -d 10s http://localhost:8080/
```

## Sample Output

### Text mode (`--no-tui`)

```
molt v0.1.0 -- MoonBit HTTP Load Tester

Target:       http://localhost:8080/api/health
Method:       Get
Connections:  10
Duration:     5s

Running...

[1.0s] 2500 requests | 2500 req/s | p50: 1.16ms | p99: 15.32ms | errors: 0
[2.0s] 5100 requests | 2550 req/s | p50: 1.15ms | p99: 15.14ms | errors: 0
[3.0s] 7800 requests | 2600 req/s | p50: 1.15ms | p99: 15.03ms | errors: 0
[4.0s] 10300 requests | 2575 req/s | p50: 1.15ms | p99: 15.24ms | errors: 0

Summary:
  Total requests:    13017
  Successful:        13017 (100.0%)
  Failed:            0 (0.0%)
  Total time:        5.0s
  Requests/sec:      2601.45

Latency Distribution:
  p50     1.16ms
  p75     1.35ms
  p90     1.94ms
  p95     9.16ms
  p99     15.15ms
  p99.9   17.29ms
  max     24.35ms

  mean    1.91ms
  stdev   2.82ms

Status Codes:
  200: 13017
```

### JSON mode (`--json`)

```json
{
  "config": {
    "url": "http://localhost:8080/api/health",
    "connections": 10,
    "duration_sec": 5.00,
    "method": "GET"
  },
  "summary": {
    "total_requests": 13017,
    "successful": 13017,
    "failed": 0,
    "total_time_sec": 5.00,
    "requests_per_sec": 2601.45
  },
  "latency": {
    "p50_ms": 1.16,
    "p75_ms": 1.35,
    "p90_ms": 1.94,
    "p95_ms": 9.16,
    "p99_ms": 15.15,
    "p99_9_ms": 17.29,
    "max_ms": 24.35,
    "mean_ms": 1.91,
    "stdev_ms": 2.82
  },
  "status_codes": {
    "200": 13017
  },
  "errors": {}
}
```

## CLI Reference

```
Usage: molt [options] <url>
```

| Option | Short | Default | Description |
|---|---|---|---|
| `--connections` | `-c` | `50` | Number of concurrent connections |
| `--duration` | `-d` | `10s` | Test duration (`10s`, `1m`, `1m30s`) |
| `--requests` | `-n` | -- | Total request count (mutually exclusive with `-d`) |
| `--method` | `-m` | `GET` | HTTP method: `GET`, `POST`, `PUT`, `DELETE` |
| `--header` | `-H` | -- | Custom header, repeatable (`-H 'K: V'`) |
| `--body` | `-b` | -- | Request body string |
| `--no-tui` | | off | Disable TUI, print periodic status lines |
| `--json` | `-j` | off | Output results as JSON (implies `--no-tui`) |
| `--help` | `-h` | | Show help |
| `--version` | `-V` | | Show version |

## Architecture

```
                         ┌──────────────┐
                         │  CLI Parser  │
                         │  (argparse)  │
                         └──────┬───────┘
                                │ Config
                                v
                         ┌──────────────┐
                         │ Coordinator  │
                         │  (TaskGroup) │
                         └──┬───────┬───┘
                            │       │
                   ┌────────┘       └────────┐
                   v                         v
            ┌────────────┐  ...  ┌────────────┐
            │  Worker 1  │       │  Worker N  │
            │ HTTP Client│       │ HTTP Client│
            └─────┬──────┘       └─────┬──────┘
                  │                     │
                  v                     v
            ┌─────────────────────────────────┐
            │       Collector (HDR Histogram) │
            └────────────────┬────────────────┘
                             │
                    ┌────────┴────────┐
                    v                 v
             ┌────────────┐   ┌────────────┐
             │  TUI / CLI │   │  Reporter  │
             │  (live)    │   │(text/JSON) │
             └────────────┘   └────────────┘
```

### Packages

| Package | Description |
|---|---|
| `cmd/main` | CLI entry point, argument parsing, TUI wiring |
| `lib/types` | Shared types: `Config`, `Stats`, `RequestResult`, `HttpMethod` |
| `lib/worker` | Async HTTP request loop with latency measurement |
| `lib/coordinator` | Structured concurrency via `TaskGroup`, worker lifecycle |
| `lib/collector` | Aggregates results using HDR Histogram |
| `lib/histogram` | Gil Tene HDR Histogram (3 significant figures, 1us-1h range) |
| `lib/reporter` | Text and JSON output formatting |
| `lib/tui` | Real-time TUI state management and VNode rendering |
| `lib/duration` | Duration string parser (`"10s"`, `"1m30s"` -> ms) |
| `lib/rate_limiter` | Token bucket rate limiter (designed, wiring pending) |

## How It Works

1. **CLI Parser** parses arguments into a `Config` struct
2. **Coordinator** spawns N async Worker tasks via `TaskGroup`
3. Each **Worker** maintains a persistent HTTP connection (`Client::new`) and loops sending requests
4. Latency is measured with `@bench.monotonic_clock_start/end` (microsecond precision)
5. Results flow to the **Collector** which records them in an **HDR Histogram**
6. During the test, the **TUI** polls the Collector every 500ms for live updates
7. After completion, the **Reporter** formats the final `Stats` as text or JSON

## Development

```sh
# Build native binary
moon build --target native

# Run all tests (119 tests)
moon test --target native \
  --package paveg/molt/src/lib/types \
  --package paveg/molt/src/lib/duration \
  --package paveg/molt/src/lib/histogram \
  --package paveg/molt/src/lib/collector \
  --package paveg/molt/src/lib/reporter \
  --package paveg/molt/src/lib/worker \
  --package paveg/molt/src/lib/rate_limiter \
  --package paveg/molt/src/lib/tui

# Format code
moon fmt

# Type check without building
moon check --target native

# Run directly via moon
moon run src/cmd/main --target native -- -c 5 -d 3s http://localhost:8080/
```

## Comparison

| | molt | [oha](https://github.com/hatoo/oha) | [hey](https://github.com/rakyll/hey) | [k6](https://github.com/grafana/k6) |
|---|---|---|---|---|
| Language | MoonBit | Rust | Go | Go |
| HDR Histogram | Yes (3 sig fig) | Yes | No | Yes |
| TUI | Yes | Yes | No | No |
| HTTP methods | GET/POST/PUT/DELETE | All | All | All |
| Scenarios | No | No | No | Yes (JS) |
| Binary size | ~2.4 MB | ~3 MB | ~5 MB | ~40 MB |

## Roadmap

- [ ] `--rate` flag: fixed RPS with token bucket rate limiting
- [ ] Coordinated Omission correction (scheduled_time_us field is ready)
- [ ] `--timeout` per-request timeout enforcement
- [ ] `--body-file` for loading request body from file
- [ ] Connection reconnection on server-side close
- [ ] Error classification (timeout, connection refused, DNS error, TLS error)
- [ ] `--http2` HTTP/2 support

## License

[Apache-2.0](LICENSE)
