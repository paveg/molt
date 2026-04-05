# molt

Simple HTTP load testing CLI built with MoonBit.

## Features

- **Concurrent connections** -- configurable number of parallel HTTP workers
- **HDR Histogram** -- accurate latency percentiles (p50, p75, p90, p95, p99, p99.9)
- **TUI mode** -- real-time terminal dashboard with live stats
- **Plain mode** -- simple text output for terminals without TUI support
- **JSON output** -- machine-readable results for CI pipelines
- **HTTP methods** -- GET, POST, PUT, DELETE with custom headers and body
- **Flexible test modes** -- run by duration or by total request count

## Installation

Requires [MoonBit](https://www.moonbitlang.com/) toolchain.

```sh
moon build --target native
```

The binary is located at:

```
_build/native/debug/build/src/cmd/main/main.exe
```

Optionally, copy it somewhere on your PATH:

```sh
cp _build/native/debug/build/src/cmd/main/main.exe /usr/local/bin/molt
```

## Usage

### Basic GET load test (default: 50 connections, 10s duration)

```sh
molt http://localhost:8080/
```

### Custom connections and duration

```sh
molt -c 100 -d 30s http://localhost:8080/api/health
```

### POST with headers and body

```sh
molt -m POST \
  -H 'Content-Type: application/json' \
  -b '{"name":"test"}' \
  -c 20 -d 15s \
  http://localhost:8080/api/users
```

### Request count mode

```sh
molt -n 10000 -c 50 http://localhost:8080/
```

### JSON output for CI

```sh
molt --json -d 10s http://localhost:8080/ > results.json
```

### Plain text mode (no TUI)

```sh
molt --no-tui -d 10s http://localhost:8080/
```

## CLI Reference

| Option | Short | Description | Default |
|---|---|---|---|
| `--connections` | `-c` | Number of concurrent connections | `50` |
| `--duration` | `-d` | Test duration (e.g. `10s`, `1m`) | `10s` |
| `--requests` | `-n` | Total number of requests (mutually exclusive with `--duration`) | -- |
| `--method` | `-m` | HTTP method (`GET`, `POST`, `PUT`, `DELETE`) | `GET` |
| `--header` | `-H` | Custom header (repeatable, e.g. `'Key: Value'`) | -- |
| `--body` | `-b` | Request body string | -- |
| `--no-tui` | | Disable TUI, use plain output | off |
| `--json` | `-j` | Output results as JSON | off |

**Positional argument:** `<url>` -- target URL (required).

## Output Formats

| Format | Flag | Description |
|---|---|---|
| Text | *(default)* | Human-readable summary with latency percentiles and status code breakdown |
| JSON | `--json` | Machine-readable JSON for scripting and CI integration |
| TUI | *(default)* | Real-time terminal dashboard with live metrics |
| Plain | `--no-tui` | One-line status updates without terminal UI |

When `--json` is set, TUI is automatically disabled.

## Architecture

```
src/
  cmd/main/       CLI entry point and argument parsing
  lib/
    types/        Core types (Config, Stats, LatencyStats, HttpMethod, TestMode)
    worker/       Async HTTP worker loop
    coordinator/  TaskGroup-based worker management
    collector/    Result aggregation
    histogram/    HDR Histogram for latency recording
    reporter/     Text and JSON output formatting
    tui/          Terminal UI rendering
    duration/     Duration string parsing (e.g. "10s", "1m")
    rate_limiter/ Request rate limiting
```

## Development

```sh
# Build
moon build --target native

# Run tests
moon test

# Format
moon fmt
```

## License

[Apache-2.0](LICENSE)
