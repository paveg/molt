# molt - MoonBit HTTP Load Testing CLI

> Design document for molt, a simple HTTP load testing CLI built with MoonBit native backend.

## 1. Overview

### Purpose

A simple HTTP load testing CLI in the vein of oha/hey, built with MoonBit native backend.
Serves as both a practical tool contribution to the MoonBit ecosystem and a showcase of the language's async/networking capabilities.

### Design Principles

- **Simple-first**: Usable as a CLI one-liner with no config files required
- **Accurate measurement**: Gil Tene HDR Histogram-based latency measurement with Coordinated Omission correction
- **Readable output**: Real-time TUI display + final summary
- **MoonBit native**: No WASM intermediary; direct I/O via `moonbitlang/async`

### Non-goals (v1)

- Scenario-based complex testing (k6/Locust territory)
- Distributed load generation
- WASM plugin mechanism
- gRPC / WebSocket load (HTTP/1.1 only)

## 2. CLI Interface

```
molt [options] <URL>
```

### Options

| Option | Short | Default | Description |
|---|---|---|---|
| `--connections` | `-c` | 50 | Number of concurrent connections |
| `--duration` | `-d` | 10s | Test duration (`10s`, `1m`, `30s`, etc.) |
| `--requests` | `-n` | (none) | Total request count (mutually exclusive with duration) |
| `--rate` | `-r` | (none) | Target RPS (unlimited when unspecified) |
| `--method` | `-m` | GET | HTTP method |
| `--header` | `-H` | (none) | Custom header (can be specified multiple times) |
| `--body` | `-b` | (none) | Request body (string) |
| `--body-file` | `-B` | (none) | Request body (file path) |
| `--timeout` | `-t` | 30s | Per-request timeout |
| `--no-tui` | | false | Disable TUI, use plain output |
| `--json` | `-j` | false | Output results as JSON |
| `--latency-correction` | | true | Coordinated Omission correction |
| `--http2` | | false | Use HTTP/2 (future support) |

### Validation Rules

- `--duration` and `--requests` are mutually exclusive; specifying both is an error
- When neither `--duration` nor `--requests` is specified, defaults to `--duration 10s`
- `--body` and `--body-file` are mutually exclusive
- `--rate` must be a positive integer
- `--connections` must be a positive integer

## 3. Architecture

### Package Structure

```
molt/
  moon.mod.json                -- module: paveg/molt
  src/
    main/
      moon.pkg.json            -- depends: config, coordinator, reporter
      main.mbt                 -- entry point: CLI parse -> Config -> Coordinator -> Reporter
    lib/
      config/
        moon.pkg.json
        config.mbt             -- Config type, validation
        config_test.mbt
      duration/
        moon.pkg.json
        duration.mbt           -- "10s", "1m30s" -> milliseconds
        duration_test.mbt
      histogram/
        moon.pkg.json
        histogram.mbt          -- Gil Tene HDR Histogram
        histogram_test.mbt
      worker/
        moon.pkg.json          -- depends: config, collector
        worker.mbt             -- HTTP client loop, latency measurement
        worker_test.mbt
      coordinator/
        moon.pkg.json          -- depends: config, worker, collector
        coordinator.mbt        -- TaskGroup management, rate limiter, termination
        coordinator_test.mbt
      collector/
        moon.pkg.json          -- depends: histogram
        collector.mbt          -- Queue receiver, stats aggregation
        collector_test.mbt
      rate_limiter/
        moon.pkg.json
        rate_limiter.mbt       -- Token bucket algorithm
        rate_limiter_test.mbt
      reporter/
        moon.pkg.json          -- depends: collector
        reporter.mbt           -- Text/JSON summary output
        reporter_test.mbt
      tui/
        moon.pkg.json          -- depends: collector, mizchi/tui
        tui.mbt                -- Real-time display
```

### Data Flow

```
CLI args
  -> Config (validated)
    -> Coordinator.run(config)
      |-- spawn Collector (owns Queue)
      |-- spawn TUI updater (polls Collector periodically)
      |-- spawn Workers x N (each: Client::new -> request loop)
      |     \-- each result -> Queue.put(RequestResult)
      |-- Rate Limiter (when --rate specified, issues permits to Workers)
      \-- Termination condition (duration timeout or request count)
    -> Collector.finalize() -> Stats
      -> Reporter.report(stats, format)
```

### Dependencies

| Package | Source | Purpose |
|---|---|---|
| `moonbitlang/async` | registry | Async runtime, TaskGroup, Queue, sleep, Semaphore |
| `moonbitlang/async/http` | registry | HTTP client (Client API) |
| `mizchi/tui` | registry | TUI framework |
| `@argparse` | core lib | CLI argument parsing |
| `@bench` | core lib | Monotonic clock for latency measurement |
| `@json` | core lib | JSON output |

## 4. Core Types

```
// === config ===

struct Config {
  url: String
  connections: Int          // default 50
  mode: TestMode            // Duration(ms) | RequestCount(Int)
  rate: Int?                // target RPS, None = unlimited
  method: HttpMethod        // GET, POST, PUT, DELETE
  headers: Array[(String, String)]
  body: String?
  timeout_ms: Int           // default 30000
  enable_tui: Bool          // default true
  json_output: Bool         // default false
  latency_correction: Bool  // default true
}

enum TestMode {
  Duration(Int)             // milliseconds
  RequestCount(Int)
}

// === worker -> collector ===

struct RequestResult {
  status_code: Int
  latency_us: Int64         // microseconds
  error: RequestError?
  scheduled_time_us: Int64? // for Coordinated Omission correction
}

enum RequestError {
  Timeout
  ConnectionRefused
  ConnectionReset
  DnsError
  TlsError
  Other(String)
}

// === collector -> reporter ===

struct Stats {
  total_requests: Int
  successful: Int
  failed: Int
  total_time_ms: Double
  requests_per_sec: Double
  latency: LatencyStats
  status_codes: Map[Int, Int]
  errors: Map[String, Int]
}

struct LatencyStats {
  p50_us: Int64
  p75_us: Int64
  p90_us: Int64
  p95_us: Int64
  p99_us: Int64
  p99_9_us: Int64
  max_us: Int64
  min_us: Int64
  mean_us: Double
  stdev_us: Double
}
```

## 5. HDR Histogram (Gil Tene Algorithm)

### Design

Full Gil Tene HDR Histogram with logarithmic bucket structure and linear sub-buckets.

- **Significant figures**: 3 (relative error < 0.1%)
- **Range**: 1us to 3,600,000,000us (1 hour)
- **Memory**: ~25,000 Int64 counters in a single flat array

### Bucket Structure

```
significant_figures = 3 -> sub_bucket_count = 2048

Bucket 0: [0, 2048)     -> 2048 sub-buckets (1us resolution)
Bucket 1: [2048, 4096)  -> 1024 sub-buckets (2us resolution)
Bucket 2: [4096, 8192)  -> 1024 sub-buckets (4us resolution)
...
Bucket K: range 2^(K+11) -> 1024 sub-buckets
```

### Interface

```
fn Histogram::new(lowest: Int64, highest: Int64, significant_figures: Int) -> Histogram
fn Histogram::record(self, value: Int64) -> Unit
fn Histogram::percentile(self, p: Double) -> Int64
fn Histogram::mean(self) -> Double
fn Histogram::stdev(self) -> Double
fn Histogram::min(self) -> Int64
fn Histogram::max(self) -> Int64
fn Histogram::reset(self) -> Unit
```

### Value-to-index Conversion

The core algorithm: use leading bits to determine the bucket, remaining bits for sub-bucket index. This gives O(1) record and O(total_buckets) percentile calculation.

## 6. Coordinator and Rate Limiter

### Coordinator Flow

```
fn Coordinator::run(config: Config) -> Stats {
  // 1. Create Collector (owns Queue)
  // 2. Run with TaskGroup for structured concurrency
  with_task_group(fn(group) {
    // Collector task: receives results from Queue
    group.spawn_bg(fn() { collector.run() })

    // TUI task (when enabled): polls Collector every 500ms
    if config.enable_tui {
      group.spawn_bg(fn() { tui.run(collector) })
    }

    // Rate Limiter (when --rate specified)
    if config.rate is Some(rate) {
      rate_limiter = RateLimiter::new(rate)
      rate_limiter.start(group)
    }

    // Spawn Workers x connections
    for i in 0..config.connections {
      group.spawn_bg(fn() {
        worker.run(config, collector.queue, rate_limiter?)
      })
    }

    // Termination
    match config.mode {
      Duration(ms) => async.sleep(ms)
      RequestCount(n) => collector.wait_for(n)
    }
    // Signal stop: close queue -> Workers get QueueAlreadyClosed -> all tasks complete
  })

  collector.finalize()
}
```

### Rate Limiter (Token Bucket)

```
struct RateLimiter {
  rate: Int              // tokens per second
  queue: Queue[Unit]     // Workers block on get()
}

// Filler task: emits tokens at uniform interval
fn RateLimiter::start(self, group: TaskGroup) {
  let interval_us = 1_000_000 / self.rate
  group.spawn_bg(fn() {
    loop {
      self.queue.put(())
      async.sleep_us(interval_us)
    }
  })
}

fn RateLimiter::acquire(self) -> Unit {
  self.queue.get()  // blocks until token available
}
```

## 7. Coordinated Omission Correction

### Problem

When the server is slow, the client delays sending the next request. This creates a bias where slow requests appear fewer than they actually are.

### Solution (--rate mode only)

1. Assign a **scheduled send time** to each request
2. Record latency as `response_time - scheduled_time` (not `response_time - actual_send_time`)
3. Unsent requests past their scheduled time are counted as delayed

```
// In Worker loop (--rate mode)
let scheduled_time = start_time + (request_index * interval)
rate_limiter.acquire()
let actual_start = monotonic_clock_start()
let response = client.get(path)
let elapsed = monotonic_clock_end(actual_start)

let corrected_latency = if config.latency_correction {
  elapsed + (actual_start - scheduled_time)  // includes queue wait
} else {
  elapsed  // raw measurement
}
```

When `--rate` is not specified (max throughput mode), Coordinated Omission does not structurally occur, so no correction is needed.

## 8. Worker and HTTP Communication

### Worker Loop

Each Worker maintains one persistent TCP connection via `Client::new(uri)` and loops sending requests.

```
fn Worker::run(config, queue, rate_limiter?) {
  let client = Client::new(config.url, headers=config.headers)

  // Loop until Queue is closed (QueueAlreadyClosed signals termination)
  while true {
    rate_limiter?.acquire()

    let start = monotonic_clock_start()
    try {
      let response = match config.method {
        GET => client.get(path)
        POST => client.post(path, body)
        PUT => client.put(path, body)
        DELETE => client.request(Delete, path)
      }
      let latency = monotonic_clock_end(start)

      queue.put(RequestResult {
        status_code: response.code,
        latency_us: latency,
        error: None,
        scheduled_time_us: ..
      })
    } catch {
      queue.put(RequestResult { error: Some(classify_error(e)), .. })
    }
  }
  client.close()
}
```

### Error Classification

- Timeout: wrapped with `@async.with_timeout_opt` per-request
- Connection errors: detect server-side disconnect, reconnect via `Client::new`
- Error types: Timeout, ConnectionRefused, ConnectionReset, DnsError, TlsError, Other

### Connection Reconnection

If the server closes the connection (e.g., `Connection: close`, TCP reset), the Worker catches the error and creates a new `Client::new(uri)` to resume.

## 9. Reporter

### Text Output (default)

```
molt v0.1.0 -- MoonBit HTTP Load Tester

Target:       <url>
Connections:  <n>
Duration:     <d>
Rate limit:   <r or (unlimited)>

Summary:
  Total requests:    N
  Successful:        N (XX.XX%)
  Failed:            N (XX.XX%)
  Total time:        Xs
  Requests/sec:      N.NN

Latency Distribution:
  p50     XX.XXms
  p75     XX.XXms
  ...

Status Codes:
  200: N
  ...

Errors:
  timeout: N
  ...
```

### JSON Output (--json)

`Stats` struct serialized to JSON via `@json` standard library. Schema matches the original spec.

## 10. TUI (mizchi/tui)

### Display

- Update interval: 500ms
- Items: elapsed/remaining time, current RPS, p50/p99 live update, request count, error count, progress bar
- Uses `mizchi/tui` framework for rendering. Falls back to ANSI escape sequences if the framework's API is insufficient.

### --no-tui Mode

Prints a 1-line summary to stdout every 1 second:

```
[5.0s] 2,500 requests | 500.0 req/s | p50: 12ms | p99: 67ms | errors: 2
```

## 11. Test Strategy

### Unit Tests

| Package | Test Coverage |
|---|---|
| `duration` | Parse "10s" -> 10000ms, "1m30s" -> 90000ms, invalid input errors |
| `histogram` | Percentile accuracy with known datasets, edge cases (empty, single value, all same), large data (1M entries) |
| `rate_limiter` | Token distribution uniformity, rate accuracy |
| `config` | duration/requests mutual exclusion, defaults, validation |
| `collector` | Stats calculation accuracy (mean, stdev, status code counts) |
| `reporter` | Text/JSON output format verification |

### Integration Tests (oha-inspired)

- Start a test HTTP server using `@http.Server`
- Execute `molt` binary against it and verify output
- Scenarios:
  - All 200 responses -> 100% success rate
  - Mixed error responses (500) -> correct error rate
  - Slow responses -> timeout detection
  - `--json` output -> valid JSON parse
  - `--rate` -> RPS accuracy within +/-5%

## 12. Implementation Phases

### Phase 1: MVP

- CLI parser with `@argparse` (URL, -c, -d, -n)
- Worker with `Client` API for concurrent HTTP GET
- Basic latency stats (mean, min, max, percentiles via HDR Histogram)
- Text summary output
- Unit tests for duration, histogram, config, collector

### Phase 2: Feature Expansion

- POST / PUT / DELETE + headers + body support
- Status code / error classification
- JSON output (`--json`)
- `--rate` with token bucket Rate Limiter
- Coordinated Omission correction
- Integration tests with test HTTP server

### Phase 3: TUI + Polish

- Real-time TUI with `mizchi/tui`
- `--timeout` per-request enforcement
- Edge case handling (DNS failure, TLS errors, connection reconnection)
- `--no-tui` plain output mode
- README and documentation

## 13. Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| CLI parser | `@argparse` (core lib) | Structured parsing with help generation; fall back to pattern match if needed |
| HDR Histogram | Gil Tene full implementation | Accuracy matters for load testing; 3 significant figures, O(1) record |
| TUI framework | `mizchi/tui` | Avoid reinventing terminal rendering; fall back to ANSI if insufficient |
| HTTP client | Low-level `Client` API | Connection reuse (Keep-Alive) essential for load testing |
| Project structure | Modular (per-component packages) | 1:1 mapping with architecture diagram; independently testable |
| Design scope | All phases designed, Phase 1 first | Prevent architectural rework; HDR Histogram and CO correction affect core design |
| Test strategy | Unit + Integration | Component correctness + CLI E2E behavior; benchmarks deferred to Phase 3+ |
