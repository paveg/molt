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
    cmd/
      main/
        moon.pkg               -- depends: types, duration, coordinator, reporter, tui, mizchi/tui/vnode, mizchi/tui/io, async, argparse, strconv, env
        main.mbt               -- entry point: CLI parse -> Config -> Coordinator -> Reporter
    lib/
      types/
        moon.pkg               -- (no dependencies)
        types.mbt              -- Config, RequestResult, Stats, LatencyStats, HttpMethod, TestMode, parse_header
      duration/
        moon.pkg               -- depends: strconv
        duration.mbt           -- "10s", "1m30s" -> milliseconds
        duration_test.mbt
      histogram/
        moon.pkg               -- depends: math
        histogram.mbt          -- Gil Tene HDR Histogram
        histogram_test.mbt
      worker/
        moon.pkg               -- depends: types, async/http, bench
        worker.mbt             -- HTTP client loop, latency measurement
        worker_wbtest.mbt
      coordinator/
        moon.pkg               -- depends: types, worker, collector, tui, async, bench
        coordinator.mbt        -- TaskGroup management, TuiCallbacks, termination
      collector/
        moon.pkg               -- depends: types, histogram
        collector.mbt          -- Synchronous result recording, stats aggregation
      reporter/
        moon.pkg               -- depends: types
        reporter.mbt           -- Text/JSON summary output
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
| `moonbitlang/async` (0.16.0) | registry | Async runtime, TaskGroup, sleep |
| `moonbitlang/async/http` | registry | HTTP client (Client API) |
| `mizchi/tui` (0.8.0) | registry | TUI framework (VNode, components, io) |
| `@argparse` | core lib | CLI argument parsing |
| `@bench` | core lib | Monotonic clock for latency measurement |
| `@strconv` | core lib | String-to-int parsing |
| `@env` | core lib | CLI argv access |
| `@math` | core lib | Math operations for histogram |

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
} derive(Show, Eq)

pub(all) struct Config {
  url : String
  connections : Int          // default 50
  mode : TestMode            // Duration(ms) | RequestCount(Int)
  http_method : HttpMethod   // Get, Post, Put, Delete
  headers : Array[(String, String)]
  body : String?
  timeout_ms : Int           // default 30000
  enable_tui : Bool          // default true
  json_output : Bool         // default false
  latency_correction : Bool  // default true
} derive(Show)

// Config::default_with_url(url) provides defaults

// === worker -> collector ===

pub(all) struct RequestResult {
  status_code : Int
  latency_us : Int64         // microseconds
  error : RequestError?
  scheduled_time_us : Int64  // 0 when not using rate limiting (non-optional)
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

pub(all) struct Stats {
  total_requests : Int
  successful : Int
  failed : Int
  total_time_ms : Double
  requests_per_sec : Double
  latency : LatencyStats
  status_codes : Map[Int, Int]
  errors : Map[String, Int]
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
pub fn parse_header(h : String) -> (String, String)?
```

Notable differences from the original spec:
- `Config.method` was renamed to `Config.http_method` to avoid shadowing MoonBit method syntax
- `Config.rate` field was removed (rate limiting not yet implemented in Config)
- `RequestResult.scheduled_time_us` is `Int64` (not `Int64?`), defaults to `0L` when unused
- `parse_header` is a standalone function in the types package, used by the CLI parser

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
pub async fn run(config: Config, tui_callbacks~: TuiCallbacks? = None) -> Stats {
  let collector = Collector::new()
  let mut stopped = false
  let start_time = monotonic_clock_start()
  let tui_state = TuiState::new(config.url, config.connections, duration_ms)

  // Initialize TUI
  tui_callbacks?.on_init()

  with_task_group(async fn(group) {
    // TUI/plain update task (when callbacks provided)
    if tui_callbacks is Some(cb) {
      group.spawn_bg(async fn() {
        let interval = if config.enable_tui { 500 } else { 1000 }
        while not(stopped) {
          tui_state.update(total_requests=..., elapsed_ms=..., ...)
          (cb.on_update)(tui_state)
          async.sleep(interval)
        }
      })
    }

    // Spawn Workers x connections
    for _ in 0..<config.connections {
      group.spawn_bg(async fn() {
        worker.run(config, fn(result) { collector.record(result) }, fn() { stopped })
      })
    }

    // Termination
    match config.mode {
      Duration(ms) => async.sleep(ms)
      RequestCount(n) => { while collector.total_requests() < n { async.sleep(10) } }
    }
    stopped = true
  })

  // Cleanup TUI
  tui_callbacks?.on_cleanup()
  collector.finalize(elapsed_ms)
}
```

Key implementation details:
- No Queue: Collector uses synchronous `record()` calls from worker callbacks, not an async Queue
- No separate Collector task: workers call `collector.record(result)` directly via closure
- Termination via boolean flag: `stopped = true` causes worker loops to exit, rather than closing a Queue
- TUI state is created in the coordinator, updated periodically, and passed to the callback

### Rate Limiter (Token Bucket) -- Not Yet Implemented

The rate limiter is designed but not yet implemented. The `Config.rate` field has been removed from the current types. When implemented, it will use a token bucket pattern with `Queue[Unit]`.

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

Each Worker is an `async fn` that maintains one persistent TCP connection via `Client::new(base_url)`. The URL is split into base and path using `parse_url`. The worker accepts two callbacks: `on_result` for recording results and `should_stop` for termination.

```
pub async fn run(
  config : Config,
  on_result : (RequestResult) -> Unit,
  should_stop : () -> Bool,
) -> Unit {
  let (base_url, path) = parse_url(config.url)
  let client = Client::new(base_url)
  let headers = build_headers(config.headers)

  while not(should_stop()) {
    let start = monotonic_clock_start()
    try {
      let response = match config.http_method {
        Get => client.get(path, extra_headers=headers)
        Post => client.post(path, body_data, extra_headers=headers)
        Put => client.put(path, body_data, extra_headers=headers)
        Delete => {
          client.request(Delete, path, extra_headers=headers)
          client.end_request()
        }
      }
      let elapsed_us = monotonic_clock_end(start)
      on_result({ status_code: response.code, latency_us: elapsed_us.to_int64(),
                  error: None, scheduled_time_us: 0L })
      client.skip_response_body()
    } catch {
      _ => {
        let elapsed_us = monotonic_clock_end(start)
        on_result({ status_code: 0, latency_us: elapsed_us.to_int64(),
                    error: Some(Other("request failed")), scheduled_time_us: 0L })
      }
    }
  }
  client.close()
}
```

Key implementation details:
- `parse_url` splits URL at the first `/` after `://` to separate base URL from path
- `build_headers` converts `Array[(String, String)]` to `Map[String, String]` for the HTTP client
- `skip_response_body()` is called after each successful response to drain the connection
- Error handling currently catches all exceptions as `Other("request failed")` -- fine-grained error classification (Timeout, ConnectionRefused, etc.) is defined in types but not yet used in the worker
- No rate limiter integration yet: the `rate_limiter?.acquire()` pattern is not implemented

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
- Status code / error classification (types defined; worker uses catch-all)
- JSON output (`--json`) with `report_json(config, stats)`
- `parse_header` utility for `-H "Key: Value"` parsing
- Note: `--rate` and Coordinated Omission correction are designed but not yet implemented

### Phase 3: TUI + Polish -- DONE

- Real-time TUI with `mizchi/tui` VNode framework
- TuiCallbacks pattern decoupling coordinator from TUI
- TuiState with progress bar, stat widgets, live p50/p99
- `--no-tui` plain output mode via same callback pattern
- `format_plain_status` for one-line periodic updates
- Note: `--timeout` per-request enforcement and connection reconnection are designed but not yet implemented

## 13. Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| CLI parser | `@argparse` (core lib) | Structured parsing with help generation; argv slicing to skip program name |
| HDR Histogram | Gil Tene full implementation | Accuracy matters for load testing; 3 significant figures, O(1) record |
| TUI framework | `mizchi/tui` VNode approach | Declarative VNode tree with `@vnode.column`, `@vnode.row`, `@components.stat`, `@components.progress_bar`; avoids manual ANSI escape code management |
| TUI decoupling | `TuiCallbacks` struct pattern | Coordinator passes `TuiState` to caller-provided callbacks; avoids coordinator depending on `mizchi/tui` directly; enables plain mode and JSON mode via same interface |
| HTTP client | Low-level `Client` API | Connection reuse (Keep-Alive) essential for load testing; `skip_response_body()` to drain connections |
| Field naming | `http_method` instead of `method` | Avoids shadowing MoonBit's method syntax in struct definitions |
| `scheduled_time_us` type | `Int64` (non-optional, default `0L`) | Simpler than `Int64?`; zero value is unambiguous since rate limiting is not yet implemented |
| Collector pattern | Synchronous `record()` via closure | No async Queue needed; workers call `collector.record(result)` through a closure passed by the coordinator; simpler than Queue-based design |
| Project structure | Modular (per-component packages) with `moon.pkg` files | 1:1 mapping with architecture diagram; independently testable; `moon.pkg` (not `moon.pkg.json`) is the MoonBit package manifest format |
| Entry point location | `src/cmd/main/` | Separates CLI entry point from library packages under `src/lib/` |
| Types package | `src/lib/types/` (no `config/` package) | All shared types (`Config`, `RequestResult`, `Stats`, etc.) and utility functions (`parse_header`) in one package; no separate config validation package needed |
| Test strategy | Unit + Integration | Component correctness + CLI E2E behavior; benchmarks deferred to future work |
