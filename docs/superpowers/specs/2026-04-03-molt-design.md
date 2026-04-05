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
| `--method` | `-m` | GET | HTTP method (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS) |
| `--header` | `-H` | (none) | Custom header (can be specified multiple times) |
| `--body` | `-b` | (none) | Request body (string) |
| `--body-file` | `-B` | (none) | Request body (file path) |
| `--timeout` | `-t` | 30s | Per-request timeout |
| `--percentiles` | | 50,75,90,95,99,99.9 | Custom percentiles to compute (comma-separated) |
| `--latency-threshold` | | (none) | Fail (exit 3) if p99 > value (e.g. `100ms`) |
| `--error-threshold` | | (none) | Fail (exit 3) if error rate > percentage (e.g. `1.0`) |
| `--warm-up` | | 0 | Warm-up duration excluded from stats (e.g. `3s`) |
| `--auth` | | (none) | Basic auth credentials (`user:password`) |
| `--serve` | | (none) | Start built-in test HTTP server (e.g. `127.0.0.1:8080`) |
| `--no-tui` | | false | Disable TUI, use plain output |
| `--json` | `-j` | false | Output results as JSON |
| `--csv` | | false | Output per-request results as CSV (streaming) |
| `--insecure` | `-k` | false | Skip TLS certificate verification |
| `--disable-keepalive` | | false | Disable HTTP keep-alive, create new connection per request |
| `--debug` | | false | Send a single request and print full details, then exit |
| `--redirect` | `-L` | false | Follow HTTP redirects (up to 10 hops) |

### Validation Rules

- `--duration` and `--requests` are mutually exclusive; specifying both is an error
- When neither `--duration` nor `--requests` is specified, defaults to `--duration 10s`
- `--body` and `--body-file` are mutually exclusive
- `--csv` and `--json` are mutually exclusive
- `--rate` must be a positive integer
- `--connections` must be a positive integer
- `--auth` must be in `user:password` format
- `--percentiles` values must be between 0 and 100
- `--serve` mode does not require a URL positional argument

## 3. Architecture

### Package Structure

```
molt/
  moon.mod.json                -- module: paveg/molt
  src/
    cmd/
      main/
        moon.pkg               -- depends: types, duration, threshold, coordinator, reporter, tui, mizchi/tui/vnode, mizchi/tui/io, async, async/http, async/socket, argparse, strconv, env, fs, sys
        main.mbt               -- entry point: CLI parse -> Config -> Coordinator -> Reporter; serve mode, debug mode, CSV streaming, threshold checks
    lib/
      types/
        moon.pkg               -- (no dependencies)
        types.mbt              -- Config, RequestResult, Stats, LatencyStats, TimeSeriesPoint, HttpMethod, TestMode, parse_header, base64_encode
      duration/
        moon.pkg               -- depends: strconv
        duration.mbt           -- "10s", "1m30s" -> milliseconds
        duration_test.mbt
      histogram/
        moon.pkg               -- depends: math
        histogram.mbt          -- Gil Tene HDR Histogram
        histogram_test.mbt
      rate_limiter/
        moon.pkg               -- depends: async, async/aqueue
        rate_limiter.mbt       -- Token bucket with absolute-deadline scheduling (oha pattern)
        rate_limiter_wbtest.mbt
      threshold/
        moon.pkg               -- depends: types
        threshold.mbt          -- Post-run pass/fail checks (latency p99, error rate)
        threshold_test.mbt
      worker/
        moon.pkg               -- depends: types, rate_limiter, async, async/http, bench, strconv
        worker.mbt             -- HTTP client loop, TTFB measurement, CO correction, redirect following, keepalive control, error classification
        worker_wbtest.mbt
      coordinator/
        moon.pkg               -- depends: types, worker, collector, tui, rate_limiter, async, bench
        coordinator.mbt        -- TaskGroup management, TuiCallbacks, rate limiter lifecycle, warm-up, time-series capture, termination
      collector/
        moon.pkg               -- depends: types, histogram
        collector.mbt          -- Synchronous result recording, stats aggregation
      reporter/
        moon.pkg               -- depends: types
        reporter.mbt           -- Text/JSON/CSV summary output, TTFB and throughput sections
      tui/
        moon.pkg               -- depends: mizchi/tui/vnode, mizchi/tui/components, bench
        tui.mbt                -- TuiState, VNode-based render_tui_node, progress bar, stat widgets
        tui_wbtest.mbt
        tui_test.mbt
```

### Data Flow

```
CLI args
  -> Config (validated via @argparse)
    -> main sets up TuiCallbacks (VNode TUI, plain mode, or None)
    -> Coordinator.run(config, tui_callbacks?)
      |-- create Collector (synchronous recording, no Queue)
      |-- spawn TUI updater via TuiCallbacks.on_update (polls Collector every 500ms/1s)
      |-- spawn Workers x N (each: Client::new -> request loop)
      |     \-- each result -> collector.record(RequestResult)
      \-- Termination condition (duration timeout or request count)
      \-- stopped = true -> workers exit
    -> Collector.finalize(elapsed_ms) -> Stats
      -> Reporter.report_text(stats) or report_json(config, stats)
```

### Dependencies

| Package | Source | Purpose |
|---|---|---|
| `moonbitlang/async` (0.16.0) | registry | Async runtime, TaskGroup, sleep, `now()` |
| `moonbitlang/async/http` | registry | HTTP client (Client API), HTTP server |
| `moonbitlang/async/aqueue` | registry | Async unbounded queue (rate limiter tokens) |
| `moonbitlang/async/socket` | registry | `Addr::parse` for serve mode |
| `mizchi/tui` (0.8.0) | registry | TUI framework (VNode, components, io) |
| `@argparse` | core lib | CLI argument parsing |
| `@bench` | core lib | Monotonic clock for latency measurement |
| `@strconv` | core lib | String-to-int/double parsing |
| `@env` | core lib | CLI argv access |
| `@math` | core lib | Math operations for histogram |
| `@fs` | x lib | File reading (`--body-file`) |
| `@sys` | x lib | `sys.exit()` for non-zero exit codes |

## 4. Core Types

All types are defined in `src/lib/types/types.mbt`. Fields use `pub(all) struct` without per-field `pub` prefix (MoonBit convention: `pub(all)` makes all fields public).

```
// === types (src/lib/types/) ===

pub(all) enum TestMode {
  Duration(Int)             // milliseconds
  RequestCount(Int)
} derive(Show, Eq)

pub(all) enum HttpMethod {
  Get
  Post
  Put
  Delete
  Patch
  Head
  Options
} derive(Show, Eq)

pub(all) struct Config {
  url : String
  connections : Int          // default 50
  mode : TestMode            // Duration(ms) | RequestCount(Int)
  http_method : HttpMethod   // Get, Post, Put, Delete, Patch, Head, Options
  headers : Array[(String, String)]
  body : String?
  timeout_ms : Int           // default 30000
  enable_tui : Bool          // default true
  json_output : Bool         // default false
  latency_correction : Bool  // default true
  rate : Int?                // target RPS, None = unlimited
  percentiles : Array[Double] // default [50.0, 75.0, 90.0, 95.0, 99.0, 99.9]
  latency_threshold_us : Int64? // fail if p99 exceeds this
  error_threshold_pct : Double? // fail if error rate exceeds this %
  warm_up_ms : Int           // default 0
  insecure : Bool            // default false (skip TLS verification)
  disable_keepalive : Bool   // default false (new connection per request)
  debug : Bool               // default false (single request debug mode)
  csv_output : Bool          // default false (per-request CSV streaming)
  max_redirects : Int        // default 0 (0 = no redirects, --redirect sets 10)
  serve_addr : String?       // built-in test HTTP server address
} derive(Show)

// Config::default_with_url(url) provides defaults for all 21 fields

// === worker -> collector ===

pub(all) struct RequestResult {
  status_code : Int
  latency_us : Int64         // microseconds (total request time)
  ttfb_us : Int64            // time to first byte (headers received, before body read)
  error : RequestError?
  scheduled_time_us : Int64  // 0 when not using rate limiting (non-optional)
  response_size_bytes : Int64 // 0 when error or unknown
} derive(Show)

pub(all) enum RequestError {
  Timeout
  ConnectionRefused
  ConnectionReset
  DnsError
  TlsError
  Other(String)
} derive(Show, Eq)

// === collector -> reporter ===

pub(all) struct TimeSeriesPoint {
  elapsed_sec : Double
  requests : Int
  rps : Double
  p50_us : Int64
  p99_us : Int64
  errors : Int
} derive(Show)

pub(all) struct Stats {
  total_requests : Int
  successful : Int
  failed : Int
  total_time_ms : Double
  requests_per_sec : Double
  latency : LatencyStats
  ttfb : LatencyStats             // time to first byte distribution
  status_codes : Map[Int, Int]
  errors : Map[String, Int]
  custom_percentiles : Array[(Double, Int64)]  // user-specified percentiles
  time_series : Array[TimeSeriesPoint]         // per-second snapshots
  total_bytes : Int64              // total response bytes
  bytes_per_sec : Double           // throughput
} derive(Show)

pub(all) struct LatencyStats {
  p50_us : Int64
  p75_us : Int64
  p90_us : Int64
  p95_us : Int64
  p99_us : Int64
  p99_9_us : Int64
  max_us : Int64
  min_us : Int64
  mean_us : Double
  stdev_us : Double
} derive(Show)

// === utility ===

// parse_header("Key: Value") -> Some(("Key", "Value"))
// Splits on first ": " (colon + space). Returns None if format is invalid.
// Rejects CRLF characters to prevent header injection.
pub fn parse_header(h : String) -> (String, String)?

// base64_encode(input) -> base64-encoded string (used for --auth Basic auth)
pub fn base64_encode(input : String) -> String
```

Notable differences from the original spec:
- `Config.method` was renamed to `Config.http_method` to avoid shadowing MoonBit method syntax
- `Config` now has 21 fields (up from 10 in the original spec) covering rate limiting, thresholds, warm-up, keepalive, debug, CSV, redirects, and serve mode
- `HttpMethod` expanded from 4 variants to 7 (added Patch, Head, Options)
- `RequestResult` gained `ttfb_us` and `response_size_bytes` fields
- `RequestResult.scheduled_time_us` is `Int64` (not `Int64?`), defaults to `0L` when unused
- `Stats` gained `ttfb`, `custom_percentiles`, `time_series`, `total_bytes`, and `bytes_per_sec` fields
- `TimeSeriesPoint` is a new struct for per-second time-series snapshots
- `parse_header` rejects CRLF characters to prevent header injection
- `base64_encode` utility added for `--auth` Basic authentication

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

## 6. Coordinator and TUI Callbacks

### TuiCallbacks Pattern

The Coordinator does not depend on `mizchi/tui` directly. Instead, the caller (main.mbt) provides a `TuiCallbacks` struct with three closures. This decouples the coordinator from the TUI framework.

```
pub(all) struct TuiCallbacks {
  on_update : (TuiState) -> Unit   // called every 500ms (TUI) or 1000ms (plain)
  on_init : () -> Unit             // called before test starts
  on_cleanup : () -> Unit          // called after test completes
}
```

### Coordinator Flow

```
pub async fn run(
  config: Config,
  tui_callbacks~: TuiCallbacks? = None,
  on_result~: ((RequestResult) -> Unit)? = None,  // CSV streaming callback
) -> Stats {
  let collector = Collector::new()
  let time_series : Array[TimeSeriesPoint] = []
  let mut stopped = false
  let mut start_time = monotonic_clock_start()
  let tui_state = TuiState::new(config.url, config.connections, duration_ms)

  tui_callbacks?.on_init()

  with_task_group(async fn(group) {
    // Set up rate limiter if configured
    let limiter = match config.rate {
      Some(rate) => { let rl = RateLimiter::new(rate); rl.start(group); Some(rl) }
      None => None
    }

    // Time-series capture task (every 1 second)
    group.spawn_bg(async fn() {
      while not(stopped) {
        sleep(1000)
        time_series.push({ elapsed_sec, requests: interval, rps, p50_us, p99_us, errors })
      }
    })

    // TUI/plain update task
    if tui_callbacks is Some(cb) {
      group.spawn_bg(async fn() {
        let interval = if config.enable_tui { 500 } else { 1000 }
        while not(stopped) {
          tui_state.update(...)
          (cb.on_update)(tui_state)
          sleep(interval)
        }
      })
    }

    // Spawn Workers x connections (with rate limiter and CO correction params)
    for i in 0..<num_workers {
      group.spawn_bg(async fn() {
        worker.run(config, fn(result) {
          collector.record(result)
          if on_result is Some(cb) { cb(result) }  // CSV streaming
        }, fn() { stopped }, rate_limiter=limiter, worker_id=i, num_workers~)
      })
    }

    // Warm-up phase: sleep then reset collector and start_time
    if config.warm_up_ms > 0 {
      sleep(config.warm_up_ms)
      collector.reset()
      time_series.clear()
      start_time = monotonic_clock_start()
    }

    // Termination
    match config.mode {
      Duration(ms) => sleep(ms)
      RequestCount(n) => { while collector.total_requests() < n { sleep(10) } }
    }
    stopped = true
  })

  tui_callbacks?.on_cleanup()
  let stats = collector.finalize(elapsed_ms, percentiles=config.percentiles)
  { ..stats, time_series }  // attach time-series data
}
```

Key implementation details:
- No Queue: Collector uses synchronous `record()` calls from worker callbacks, not an async Queue
- No separate Collector task: workers call `collector.record(result)` directly via closure
- Termination via boolean flag: `stopped = true` causes worker loops to exit, rather than closing a Queue
- TUI state is created in the coordinator, updated periodically, and passed to the callback
- Rate limiter lifecycle: created and started inside the TaskGroup, passed to all workers
- Warm-up phase: after `warm_up_ms`, resets the collector (clears histogram) and restarts the clock; time-series is also cleared
- Time-series capture: a background task samples per-second snapshots (requests, RPS, p50, p99, errors)
- `on_result` callback: enables CSV streaming by forwarding each `RequestResult` to a caller-provided function
- Custom percentiles: passed through to `collector.finalize` for user-specified percentile computation

### Rate Limiter (Token Bucket with Absolute-Deadline Scheduling)

The rate limiter (`src/lib/rate_limiter/`) uses a token bucket pattern with `@aqueue.Queue[Unit]` (unbounded). It employs absolute-deadline scheduling (oha pattern) to prevent cumulative drift:

```
pub struct RateLimiter {
  priv rate : Int
  priv queue : @aqueue.Queue[Unit]
}

fn RateLimiter::start(self, group : TaskGroup[Unit]) -> Unit {
  // Spawns a background task that emits tokens at the configured rate.
  // Uses absolute deadlines: next_deadline = start + token_index * interval_ms
  // This prevents drift that would accumulate with relative sleep intervals.
}

async fn RateLimiter::acquire(self) -> Unit {
  self.queue.get()  // blocks until a token is available
}
```

The Coordinator creates the rate limiter when `config.rate` is `Some(rate)`, calls `start(group)` to begin token emission, and passes it to each Worker. Workers call `acquire()` before each request.

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

Each Worker is an `async fn` that maintains one persistent TCP connection via `Client::new(base_url)`. The URL is split into base and path using `parse_url`. The worker accepts callbacks for result recording and termination, plus optional rate limiter and CO correction parameters.

```
pub async fn run(
  config : Config,
  on_result : (RequestResult) -> Unit,
  should_stop : () -> Bool,
  rate_limiter? : RateLimiter? = None,
  worker_id? : Int = 0,
  num_workers? : Int = 1,
) -> Unit {
  let (base_url, path) = parse_url(config.url)
  let mut client = Client::new(base_url)
  let headers = build_headers(config.headers)
  let use_co = config.latency_correction && rate_limiter is Some(_)

  while not(should_stop()) {
    if rate_limiter is Some(rl) { rl.acquire() }
    let scheduled_us = if use_co { compute_scheduled_time(...) } else { 0L }
    let start = monotonic_clock_start()

    try {
      let result = with_timeout_opt(config.timeout_ms, async fn() {
        match config.http_method {
          Get => client.get(path, extra_headers=headers)
          Post => client.post(path, body_data, extra_headers=headers)
          Put => client.put(path, body_data, extra_headers=headers)
          Patch => { client.request(Patch, ...); client.write(body_data); client.end_request() }
          Head => { client.request(Head, ...); client.end_request() }
          Options => { client.request(Options, ...); client.end_request() }
          Delete => { client.request(Delete, ...); client.end_request() }
        }
      })
      match result {
        Some(response) => {
          let ttfb_us = monotonic_clock_end(start)  // TTFB: before body drain
          client.skip_response_body()
          let final_response = if config.max_redirects > 0 && is_redirect(response) {
            follow_redirects(response, config.max_redirects, config.headers)
          } else { response }
          let latency_us = monotonic_clock_end(start)  // total time
          // CO correction applied to both ttfb_us and latency_us when use_co=true
          on_result({ status_code, latency_us, ttfb_us, error: None, scheduled_time_us, response_size_bytes })
          if config.disable_keepalive {
            client.close(); client = Client::new(base_url)
          }
        }
        None => on_result(make_error_result(elapsed, Timeout, scheduled_us))
      }
    } catch {
      err => {
        on_result(make_error_result(elapsed, classify_error(err), scheduled_us))
        client.close(); client = Client::new(base_url)  // reconnect after error
      }
    }
    request_index += 1
  }
  client.close()
}
```

Key implementation details:
- `parse_url` splits URL at the first `/` after `://` to separate base URL from path
- `build_headers` converts `Array[(String, String)]` to `Map[String, String]` for the HTTP client
- **TTFB measurement**: `ttfb_us` is captured after headers are received but before `skip_response_body()`; `latency_us` is captured after body drain and redirect following
- **Redirect following**: `follow_redirects` uses `@http.get` for up to `max_redirects` hops, following `Location` headers on 3xx responses
- **Keepalive control**: when `disable_keepalive` is true, the client is closed and recreated after each request
- **Per-request timeout**: `@async.with_timeout_opt(timeout_ms, ...)` returns `None` on timeout, producing a `Timeout` error result
- **Error classification**: `classify_error` pattern-matches on the error message string to classify into `Timeout`, `ConnectionRefused`, `ConnectionReset`, `DnsError`, `TlsError`, or `Other`
- **Reconnection on error**: after a caught exception, the client is closed and recreated to recover from broken connection state
- **CO correction integration**: when `rate_limiter` is provided and `latency_correction` is true, both `ttfb_us` and `latency_us` are corrected using `compute_corrected_latency(elapsed_us, scheduled_us, actual_start_us)`. The `compute_scheduled_time` function distributes scheduled times evenly across workers using stride-based interleaving
- **Response size**: extracted from `Content-Length` header when available (0 otherwise)

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

## 10. TUI (mizchi/tui VNode Framework)

### Architecture

The TUI uses the `mizchi/tui` VNode framework (`@vnode`, `@components`) for declarative terminal rendering. The TUI package (`src/lib/tui/`) does not depend on `async` or `collector` -- it is a pure rendering layer that operates on `TuiState`.

### TuiState

```
pub struct TuiState {
  url : String
  connections : Int
  duration_ms : Int
  mut total_requests : Int
  mut successful : Int
  mut failed : Int
  mut current_rps : Int
  mut elapsed_ms : Double
  mut p50_us : Int64
  mut p99_us : Int64
}
```

- `TuiState::new(url, connections, duration_ms)` initializes with zeros
- `TuiState::update(total_requests~, successful~, failed~, elapsed_ms~, p50_us~, p99_us~)` refreshes all mutable fields and computes `current_rps`
- `TuiState::progress_ratio()` returns `elapsed_ms / duration_ms` clamped to [0.0, 1.0]

### VNode Rendering

`render_tui_node(state : TuiState) -> @vnode.TuiNode` builds a VNode tree:

- Header: "molt v0.1.0 -- MoonBit HTTP Load Tester" (bold, cyan)
- Target info: URL, connections (using `@components.stat`)
- Progress bar: `[elapsed / remaining]` with `@components.progress_bar(progress, width=40)`
- Live stats: Requests, RPS, Success, Failed (using `@components.stat` in rows)
- Latency: p50, p99 displayed as formatted milliseconds

`render_tui_to_string(state, width, height)` renders the VNode tree to a string via `@vnode.render_vnode_once`.

### Integration with Coordinator

The main entry point (`src/cmd/main/main.mbt`) creates `TuiCallbacks` that wire the VNode framework:

```
// TUI mode
on_init:    fn() { print_raw(VNodeApp::init_terminal()) }
on_update:  fn(state) { print_raw(app.render(render_tui_node(state))) }
on_cleanup: fn() { print_raw(VNodeApp::restore_terminal()) }
```

Uses `@io.get_terminal_size()` for dimensions and `@io.print_raw()` for direct terminal output.

### --no-tui Mode

Uses the same `TuiCallbacks` pattern but with plain text output:

```
on_update: fn(state) { println(format_plain_status(state)) }
```

`format_plain_status` outputs:
```
[5.0s] 2500 requests | 500 req/s | p50: 12.00ms | p99: 67.00ms | errors: 2
```

### --json Mode

No TUI callbacks are provided (`None`). The coordinator runs silently, and `report_json(config, stats)` is called after completion.

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

### Phase 1: MVP -- DONE

- CLI parser with `@argparse` (URL, -c, -d, -n, -m, -H, -b, --no-tui, --json)
- Worker with `Client` API for concurrent HTTP GET/POST/PUT/DELETE
- Basic latency stats (mean, min, max, percentiles via HDR Histogram)
- Text summary output
- Unit tests for duration, histogram, collector

### Phase 2: Feature Expansion -- DONE

- POST / PUT / DELETE + headers + body support
- Fine-grained error classification in worker (`classify_error` pattern matching on error messages)
- JSON output (`--json`) with `report_json(config, stats)` including TTFB, throughput, time-series, and custom percentiles sections
- `parse_header` utility with CRLF injection prevention
- `base64_encode` utility for `--auth` Basic authentication

### Phase 3: TUI + Polish -- DONE

- Real-time TUI with `mizchi/tui` VNode framework
- TuiCallbacks pattern decoupling coordinator from TUI
- TuiState with progress bar, stat widgets, live p50/p99
- `--no-tui` plain output mode via same callback pattern
- `format_plain_status` for one-line periodic updates

### Phase 4: Rate Limiting + CO Correction -- DONE

- Token bucket rate limiter with absolute-deadline scheduling (prevents cumulative drift)
- Coordinated Omission correction in worker: corrected latency = elapsed + (actual_start - scheduled_time)
- Stride-based scheduled time distribution across workers (`compute_scheduled_time`)
- Both TTFB and total latency are CO-corrected when `--rate` is active

### Phase 5: Advanced Features -- DONE

- PATCH / HEAD / OPTIONS HTTP methods
- TTFB (Time to First Byte) measurement and reporting
- Per-request timeout via `@async.with_timeout_opt`
- Connection reconnection on error (client close + recreate)
- Keepalive control (`--disable-keepalive`)
- Redirect following (`--redirect` / `-L`, up to 10 hops)
- Custom percentiles (`--percentiles 50,90,99,99.99`)
- Warm-up period (`--warm-up`, resets collector and start time)
- Per-second time-series capture in coordinator
- Response size tracking and throughput reporting (`total_bytes`, `bytes_per_sec`)
- CSV streaming output (`--csv`, per-request rows)
- Debug mode (`--debug`, single request with full response details)
- Built-in test HTTP server (`--serve 127.0.0.1:8080`)
- Threshold checks (`--latency-threshold`, `--error-threshold`) with exit code 3 on violation
- Basic auth (`--auth user:password`)
- TLS skip (`--insecure` / `-k`)
- `--body-file` for reading request body from file

## 13. Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| CLI parser | `@argparse` (core lib) | Structured parsing with help generation; argv slicing to skip program name |
| HDR Histogram | Gil Tene full implementation | Accuracy matters for load testing; 3 significant figures, O(1) record |
| TUI framework | `mizchi/tui` VNode approach | Declarative VNode tree with `@vnode.column`, `@vnode.row`, `@components.stat`, `@components.progress_bar`; avoids manual ANSI escape code management |
| TUI decoupling | `TuiCallbacks` struct pattern | Coordinator passes `TuiState` to caller-provided callbacks; avoids coordinator depending on `mizchi/tui` directly; enables plain mode and JSON mode via same interface |
| HTTP client | Low-level `Client` API | Connection reuse (Keep-Alive) essential for load testing; `skip_response_body()` to drain connections |
| Field naming | `http_method` instead of `method` | Avoids shadowing MoonBit's method syntax in struct definitions |
| `scheduled_time_us` type | `Int64` (non-optional, default `0L`) | Simpler than `Int64?`; zero value is unambiguous when rate limiting is inactive |
| Collector pattern | Synchronous `record()` via closure | No async Queue needed; workers call `collector.record(result)` through a closure passed by the coordinator; simpler than Queue-based design |
| Project structure | Modular (per-component packages) with `moon.pkg` files | 1:1 mapping with architecture diagram; independently testable; `moon.pkg` (not `moon.pkg.json`) is the MoonBit package manifest format |
| Entry point location | `src/cmd/main/` | Separates CLI entry point from library packages under `src/lib/` |
| Types package | `src/lib/types/` (no `config/` package) | All shared types (`Config`, `RequestResult`, `Stats`, etc.) and utility functions (`parse_header`, `base64_encode`) in one package; no separate config validation package needed |
| Test strategy | Unit + Integration | Component correctness + CLI E2E behavior; benchmarks deferred to future work |
| Threshold module | Separate `threshold/` package | Post-run pass/fail checks (p99 latency, error rate) decoupled from reporter; returns `ThresholdResult` with `passed` and `violations`; main exits with code 3 on violation |
| Serve mode | Built-in test HTTP server in `main.mbt` | `--serve 127.0.0.1:8080` starts a simple `@http.Server` returning `{"status":"ok"}`; enables self-contained testing without external infrastructure |
| TTFB measurement | Separate `ttfb_us` field in `RequestResult` | Measured after headers received but before body drain; provides visibility into server processing time vs transfer time; CO-corrected independently |
| CSV streaming | Per-request CSV output via `on_result` callback | `--csv` flag enables real-time CSV rows (latency, status, error, size) printed as each request completes; uses coordinator's `on_result` callback parameter |
| Rate limiter scheduling | Absolute-deadline (oha pattern) | `next_deadline = start + token_index * interval` prevents cumulative drift from relative sleep; stride-based interleaving distributes scheduled times evenly across workers |
| Error reconnection | Close + recreate `Client` on error | After a caught exception, the HTTP client may be in a broken state; closing and recreating ensures the next request starts with a clean connection |
| Exit codes | 0 (success), 2 (failures), 3 (threshold violation) | Enables CI/CD integration; threshold violations are distinct from request failures |
