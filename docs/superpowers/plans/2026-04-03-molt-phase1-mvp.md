# molt Phase 1 MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the MVP of molt — a MoonBit native HTTP load testing CLI that can run concurrent GET requests against a URL and report latency statistics with HDR Histogram accuracy.

**Architecture:** Modular package structure with clear boundaries. CLI args → Config → Coordinator (spawns Workers via TaskGroup) → Collector (aggregates via Queue + HDR Histogram) → Reporter (text summary). Each package is independently testable.

**Tech Stack:** MoonBit native backend, `moonbitlang/async` (TaskGroup, Queue, sleep), `moonbitlang/async/http` (Client API), `@argparse` (CLI), `@bench` (monotonic clock)

**Parallel Development Strategy:** Tasks 1-3 are leaf nodes with zero internal dependencies — develop in parallel worktrees. Tasks 4-6 depend only on shared types from Task 0 — develop in parallel after Task 0. Tasks 7-9 are sequential integration work.

---

## File Structure

```
molt/
  moon.mod.json                          -- module: paveg/molt
  src/
    cmd/main/
      moon.pkg                           -- is-main, imports all lib packages
      main.mbt                           -- CLI parsing, orchestration
    lib/
      types/
        moon.pkg                         -- no deps (shared type definitions)
        types.mbt                        -- Config, RequestResult, Stats, etc.
      duration/
        moon.pkg                         -- no deps
        duration.mbt                     -- parse "10s", "1m30s" → milliseconds
        duration_wbtest.mbt              -- whitebox tests
      histogram/
        moon.pkg                         -- no deps
        histogram.mbt                    -- Gil Tene HDR Histogram
        histogram_wbtest.mbt             -- whitebox tests (internal index math)
        histogram_test.mbt              -- blackbox tests (percentile accuracy)
      collector/
        moon.pkg                         -- imports: types, histogram
        collector.mbt                    -- stats aggregation from RequestResult
        collector_test.mbt              -- blackbox tests
      reporter/
        moon.pkg                         -- imports: types
        reporter.mbt                     -- text summary output
        reporter_test.mbt              -- blackbox tests
      worker/
        moon.pkg                         -- imports: types, moonbitlang/async, moonbitlang/async/http
        worker.mbt                       -- HTTP client loop
      coordinator/
        moon.pkg                         -- imports: types, worker, collector, moonbitlang/async
        coordinator.mbt                  -- TaskGroup orchestration
```

**Key design note:** Shared types live in `lib/types/` so leaf packages (duration, histogram) don't need cross-dependencies. Packages that need `Config`, `RequestResult`, or `Stats` import `lib/types/`.

---

### Task 0: Project Scaffold and Shared Types

**Files:**
- Create: `moon.mod.json`
- Create: `src/lib/types/moon.pkg`
- Create: `src/lib/types/types.mbt`
- Create: all `moon.pkg` files for every package
- Create: `src/cmd/main/moon.pkg`
- Create: `src/cmd/main/main.mbt` (placeholder)

This task sets up the skeleton so parallel worktree agents have a compilable base.

- [ ] **Step 1: Initialize MoonBit project**

Run:
```bash
cd /Users/ryota/repos/github.com/paveg/molt
moon new . --user paveg --name molt
```

If the directory already has files, create `moon.mod.json` manually:

```json
{
  "name": "paveg/molt",
  "version": "0.1.0",
  "readme": "README.mbt.md",
  "repository": "https://github.com/paveg/molt",
  "license": "Apache-2.0",
  "keywords": ["load-testing", "http", "benchmark"],
  "description": "Simple HTTP load testing CLI built with MoonBit"
}
```

- [ ] **Step 2: Add dependencies**

Run:
```bash
moon add moonbitlang/async
```

Verify `moon.mod.json` now contains `"deps": { "moonbitlang/async": "..." }`.

- [ ] **Step 3: Create shared types package**

Create `src/lib/types/moon.pkg`:
```
```

Create `src/lib/types/types.mbt`:
```moonbit
///|
pub enum TestMode {
  Duration(Int)
  RequestCount(Int)
} derive(Show, Eq)

///|
pub enum HttpMethod {
  Get
  Post
  Put
  Delete
} derive(Show, Eq)

///|
pub struct Config {
  pub url : String
  pub connections : Int
  pub mode : TestMode
  pub method : HttpMethod
  pub headers : Array[(String, String)]
  pub body : String?
  pub timeout_ms : Int
  pub enable_tui : Bool
  pub json_output : Bool
  pub latency_correction : Bool
} derive(Show)

///|
pub fn Config::default_with_url(url : String) -> Config {
  {
    url,
    connections: 50,
    mode: Duration(10000),
    method: Get,
    headers: [],
    body: None,
    timeout_ms: 30000,
    enable_tui: true,
    json_output: false,
    latency_correction: true,
  }
}

///|
pub enum RequestError {
  Timeout
  ConnectionRefused
  ConnectionReset
  DnsError
  TlsError
  Other(String)
} derive(Show, Eq)

///|
pub struct RequestResult {
  pub status_code : Int
  pub latency_us : Int64
  pub error : RequestError?
} derive(Show)

///|
pub struct LatencyStats {
  pub p50_us : Int64
  pub p75_us : Int64
  pub p90_us : Int64
  pub p95_us : Int64
  pub p99_us : Int64
  pub p99_9_us : Int64
  pub max_us : Int64
  pub min_us : Int64
  pub mean_us : Double
  pub stdev_us : Double
} derive(Show)

///|
pub struct Stats {
  pub total_requests : Int
  pub successful : Int
  pub failed : Int
  pub total_time_ms : Double
  pub requests_per_sec : Double
  pub latency : LatencyStats
  pub status_codes : Map[Int, Int]
  pub errors : Map[String, Int]
} derive(Show)
```

- [ ] **Step 4: Create all package moon.pkg files**

Create `src/lib/duration/moon.pkg`:
```
```

Create `src/lib/histogram/moon.pkg`:
```
```

Create `src/lib/collector/moon.pkg`:
```
import {
  "paveg/molt/src/lib/types",
  "paveg/molt/src/lib/histogram",
}
```

Create `src/lib/reporter/moon.pkg`:
```
import {
  "paveg/molt/src/lib/types",
}
```

Create `src/lib/worker/moon.pkg`:
```
import {
  "paveg/molt/src/lib/types",
  "moonbitlang/async",
  "moonbitlang/async/http",
}

options(
  targets: {
    "worker.mbt": [ "native" ],
  },
)
```

Create `src/lib/coordinator/moon.pkg`:
```
import {
  "paveg/molt/src/lib/types",
  "paveg/molt/src/lib/worker",
  "paveg/molt/src/lib/collector",
  "moonbitlang/async",
}

options(
  targets: {
    "coordinator.mbt": [ "native" ],
  },
)
```

Create `src/cmd/main/moon.pkg`:
```
import {
  "paveg/molt/src/lib/types",
  "paveg/molt/src/lib/duration",
  "paveg/molt/src/lib/coordinator",
  "paveg/molt/src/lib/reporter",
  "moonbitlang/async",
}

options(
  "is-main": true,
  targets: {
    "main.mbt": [ "native" ],
  },
)
```

- [ ] **Step 5: Create placeholder source files**

Create `src/lib/duration/duration.mbt`:
```moonbit
///|
/// Parses a duration string like "10s", "1m", "1m30s" into milliseconds.
pub fn parse(input : String) -> Int raise {
  abort("not implemented")
}
```

Create `src/lib/histogram/histogram.mbt`:
```moonbit
///|
pub struct Histogram {
  priv counts : Array[Int64]
  priv mut total_count : Int64
  priv mut min_value : Int64
  priv mut max_value : Int64
}

///|
pub fn Histogram::new(highest_trackable : Int64, significant_figures : Int) -> Histogram {
  abort("not implemented")
}
```

Create `src/lib/collector/collector.mbt`:
```moonbit
///|
pub struct Collector {
  priv mut total : Int
}

///|
pub fn Collector::new() -> Collector {
  { total: 0 }
}
```

Create `src/lib/reporter/reporter.mbt`:
```moonbit
///|
pub fn report_text(stats : @types.Stats) -> String {
  abort("not implemented")
}
```

Create `src/lib/worker/worker.mbt`:
```moonbit
// Worker implementation (native only)
```

Create `src/lib/coordinator/coordinator.mbt`:
```moonbit
// Coordinator implementation (native only)
```

Create `src/cmd/main/main.mbt`:
```moonbit
///|
fn main {
  println("molt v0.1.0 -- MoonBit HTTP Load Tester")
}
```

- [ ] **Step 6: Verify the project compiles**

Run:
```bash
moon check --target native
```

Expected: no errors. If there are import path issues, fix the `moon.pkg` import paths.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: scaffold project structure with shared types"
```

---

### Task 1: Duration Parser (PARALLEL — leaf node)

**Files:**
- Modify: `src/lib/duration/duration.mbt`
- Create: `src/lib/duration/duration_wbtest.mbt`

**No dependencies on other molt packages.**

- [ ] **Step 1: Write failing tests**

Create `src/lib/duration/duration_wbtest.mbt`:
```moonbit
///|
test "parse seconds" {
  inspect(parse("10s"), content="10000")
}

///|
test "parse minutes" {
  inspect(parse("1m"), content="60000")
}

///|
test "parse combined minutes and seconds" {
  inspect(parse("1m30s"), content="90000")
}

///|
test "parse hours" {
  inspect(parse("1h"), content="3600000")
}

///|
test "parse complex duration" {
  inspect(parse("1h2m3s"), content="3723000")
}

///|
test "parse seconds only decimal-like" {
  inspect(parse("30s"), content="30000")
}

///|
test "parse zero" {
  inspect(parse("0s"), content="0")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
moon test --package paveg/molt/src/lib/duration
```

Expected: FAIL — `abort("not implemented")`

- [ ] **Step 3: Implement duration parser**

Replace `src/lib/duration/duration.mbt`:
```moonbit
///|
pub suberror ParseError {
  InvalidDuration(String)
} derive(Show)

///|
/// Parses a duration string like "10s", "1m", "1m30s", "1h2m3s" into milliseconds.
/// Supported units: h (hours), m (minutes), s (seconds).
pub fn parse(input : String) -> Int raise {
  guard input.length() > 0 else {
    raise InvalidDuration("empty duration string")
  }
  let mut total_ms = 0
  let mut num_start = 0
  let mut has_unit = false
  for i, c in input {
    match c {
      'h' | 'm' | 's' => {
        guard i > num_start else {
          raise InvalidDuration("missing number before '\{c}' in \"\{input}\"")
        }
        let num_str = input.substring(start=num_start, end=i)
        let n = @strconv.parse_int(num_str) catch {
          _ =>
            raise InvalidDuration(
              "invalid number \"\{num_str}\" in \"\{input}\"",
            )
        }
        match c {
          'h' => total_ms = total_ms + n * 3600000
          'm' => total_ms = total_ms + n * 60000
          's' => total_ms = total_ms + n * 1000
          _ => ()
        }
        num_start = i + 1
        has_unit = true
      }
      '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' => ()
      _ => raise InvalidDuration("unexpected character '\{c}' in \"\{input}\"")
    }
  }
  guard has_unit else {
    raise InvalidDuration("no time unit found in \"\{input}\"")
  }
  guard num_start == input.length() else {
    raise InvalidDuration("trailing number without unit in \"\{input}\"")
  }
  total_ms
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
moon test --package paveg/molt/src/lib/duration
```

Expected: all 7 tests PASS.

- [ ] **Step 5: Add error case tests**

Add to `src/lib/duration/duration_wbtest.mbt`:
```moonbit
///|
test "parse empty string raises error" {
  let result = try { Ok(parse("")) } catch { e => Err(e) }
  inspect(result.is_err(), content="true")
}

///|
test "parse no unit raises error" {
  let result = try { Ok(parse("123")) } catch { e => Err(e) }
  inspect(result.is_err(), content="true")
}

///|
test "parse invalid character raises error" {
  let result = try { Ok(parse("10x")) } catch { e => Err(e) }
  inspect(result.is_err(), content="true")
}

///|
test "parse missing number before unit raises error" {
  let result = try { Ok(parse("s")) } catch { e => Err(e) }
  inspect(result.is_err(), content="true")
}
```

- [ ] **Step 6: Run all duration tests**

Run:
```bash
moon test --package paveg/molt/src/lib/duration
```

Expected: all 11 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add src/lib/duration/
git commit -m "feat: implement duration parser with full test coverage"
```

---

### Task 2: HDR Histogram (PARALLEL — leaf node)

**Files:**
- Modify: `src/lib/histogram/histogram.mbt`
- Create: `src/lib/histogram/histogram_wbtest.mbt`
- Create: `src/lib/histogram/histogram_test.mbt`

**No dependencies on other molt packages.**

This is the most complex component. Gil Tene's algorithm uses a two-level indexing scheme: leading zero count determines the bucket, sub-bucket index provides resolution within that bucket.

- [ ] **Step 1: Write failing whitebox tests for index math**

Create `src/lib/histogram/histogram_wbtest.mbt`:
```moonbit
///|
test "new histogram has correct bucket count" {
  let h = Histogram::new(3600000000L, 3)
  // significant_figures=3 → sub_bucket_count_magnitude=10, sub_bucket_count=2048
  inspect(h.sub_bucket_count, content="2048")
  inspect(h.total_count, content="0")
}

///|
test "record single value" {
  let h = Histogram::new(3600000000L, 3)
  h.record(1000L)
  inspect(h.total_count, content="1")
  inspect(h.min_value, content="1000")
  inspect(h.max_value, content="1000")
}

///|
test "record multiple values" {
  let h = Histogram::new(3600000000L, 3)
  h.record(100L)
  h.record(200L)
  h.record(300L)
  inspect(h.total_count, content="3")
  inspect(h.min_value, content="100")
  inspect(h.max_value, content="300")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
moon test --package paveg/molt/src/lib/histogram
```

Expected: FAIL — `abort("not implemented")`

- [ ] **Step 3: Implement HDR Histogram core**

Replace `src/lib/histogram/histogram.mbt`:
```moonbit
///|
pub struct Histogram {
  priv counts : Array[Int64]
  priv mut total_count : Int64
  priv mut min_value : Int64
  priv mut max_value : Int64
  // Internal parameters
  priv sub_bucket_count : Int
  priv sub_bucket_half_count : Int
  priv sub_bucket_half_count_magnitude : Int
  priv sub_bucket_mask : Int64
  priv unit_magnitude : Int
  priv bucket_count : Int
  priv counts_len : Int
  // Running sums for mean/stdev
  priv mut sum : Double
  priv mut sum_of_squares : Double
}

///|
fn clz64(value : Int64) -> Int {
  guard value != 0L else { return 64 }
  let mut n = 0
  let mut v = value
  if v.land(0xFFFFFFFF00000000L) == 0L {
    n = n + 32
    v = v.lsl(32)
  }
  if v.land(0xFFFF000000000000L) == 0L {
    n = n + 16
    v = v.lsl(16)
  }
  if v.land(0xFF00000000000000L) == 0L {
    n = n + 8
    v = v.lsl(8)
  }
  if v.land(0xF000000000000000L) == 0L {
    n = n + 4
    v = v.lsl(4)
  }
  if v.land(0xC000000000000000L) == 0L {
    n = n + 2
    v = v.lsl(2)
  }
  if v.land(0x8000000000000000L) == 0L {
    n = n + 1
  }
  n
}

///|
fn power_of_2(exp : Int) -> Int64 {
  1L.lsl(exp)
}

///|
/// Creates a new HDR Histogram.
/// `highest_trackable` is the maximum value to track (in microseconds).
/// `significant_figures` is the number of significant decimal digits of precision (1-5).
pub fn Histogram::new(
  highest_trackable : Int64,
  significant_figures : Int,
) -> Histogram {
  let largest_value_with_single_unit_resolution = 2L * power_of_2(
      (significant_figures.to_double() * @math.log10(2.0).recip()).to_int(),
    )
  let sub_bucket_count_magnitude = (
    @math.ceil(
      @math.log2(largest_value_with_single_unit_resolution.to_double()),
    )
  ).to_int()
  let sub_bucket_half_count_magnitude = if sub_bucket_count_magnitude > 1 {
    sub_bucket_count_magnitude - 1
  } else {
    0
  }
  let sub_bucket_count = 1.lsl(sub_bucket_count_magnitude)
  let sub_bucket_half_count = sub_bucket_count / 2
  let sub_bucket_mask = sub_bucket_count.to_int64().lsl(32).asr(32)
  let unit_magnitude = 0
  // Determine bucket count needed
  let mut buckets = 1
  let mut smallest_untrackable = sub_bucket_count.to_int64().lsl(unit_magnitude)
  while smallest_untrackable <= highest_trackable {
    smallest_untrackable = smallest_untrackable.lsl(1)
    buckets = buckets + 1
  }
  let counts_len = (buckets + 1) * (sub_bucket_half_count)
  {
    counts: Array::make(counts_len, 0L),
    total_count: 0L,
    min_value: 0x7FFFFFFFFFFFFFFFL,
    max_value: 0L,
    sub_bucket_count,
    sub_bucket_half_count,
    sub_bucket_half_count_magnitude,
    sub_bucket_mask,
    unit_magnitude,
    bucket_count: buckets,
    counts_len,
    sum: 0.0,
    sum_of_squares: 0.0,
  }
}

///|
fn Histogram::counts_index(
  self : Histogram,
  bucket : Int,
  sub : Int,
) -> Int {
  (bucket + 1) * self.sub_bucket_half_count + sub - self.sub_bucket_half_count
}

///|
fn Histogram::get_bucket_index(self : Histogram, value : Int64) -> Int {
  let pow2ceiling = 64 - clz64(value.lor(self.sub_bucket_mask))
  pow2ceiling - self.unit_magnitude - (self.sub_bucket_half_count_magnitude + 1)
}

///|
fn Histogram::get_sub_bucket_index(
  self : Histogram,
  value : Int64,
  bucket : Int,
) -> Int {
  value.asr(bucket + self.unit_magnitude).to_int()
}

///|
fn Histogram::value_from_index(
  self : Histogram,
  bucket : Int,
  sub : Int,
) -> Int64 {
  sub.to_int64().lsl(bucket + self.unit_magnitude)
}

///|
/// Records a value in the histogram.
pub fn Histogram::record(self : Histogram, value : Int64) -> Unit {
  let bucket = self.get_bucket_index(value)
  let sub = self.get_sub_bucket_index(value, bucket)
  let idx = self.counts_index(bucket, sub)
  self.counts[idx] = self.counts[idx] + 1L
  self.total_count = self.total_count + 1L
  if value < self.min_value {
    self.min_value = value
  }
  if value > self.max_value {
    self.max_value = value
  }
  let fv = value.to_double()
  self.sum = self.sum + fv
  self.sum_of_squares = self.sum_of_squares + fv * fv
}

///|
/// Returns the value at the given percentile (0.0 to 100.0).
pub fn Histogram::percentile(self : Histogram, p : Double) -> Int64 {
  guard self.total_count > 0L else { return 0L }
  let target_count = (
    p / 100.0 * self.total_count.to_double() + 0.5
  ).to_int64()
  let mut accumulated : Int64 = 0L
  let mut result : Int64 = 0L
  let mut found = false
  for bucket in 0..<self.bucket_count + 1 {
    if found {
      break
    }
    let sub_start = if bucket == 0 { 0 } else { self.sub_bucket_half_count }
    for sub in sub_start..<self.sub_bucket_count {
      let idx = self.counts_index(bucket, sub)
      if idx >= self.counts_len {
        found = true
        result = self.max_value
        break
      }
      accumulated = accumulated + self.counts[idx]
      if accumulated >= target_count {
        found = true
        result = self.value_from_index(bucket, sub)
        break
      }
    }
  }
  if found { result } else { self.max_value }
}

///|
pub fn Histogram::mean(self : Histogram) -> Double {
  guard self.total_count > 0L else { return 0.0 }
  self.sum / self.total_count.to_double()
}

///|
pub fn Histogram::stdev(self : Histogram) -> Double {
  guard self.total_count > 1L else { return 0.0 }
  let n = self.total_count.to_double()
  let variance = (self.sum_of_squares - self.sum * self.sum / n) / (n - 1.0)
  if variance < 0.0 {
    0.0
  } else {
    variance.sqrt()
  }
}

///|
pub fn Histogram::min(self : Histogram) -> Int64 {
  guard self.total_count > 0L else { return 0L }
  self.min_value
}

///|
pub fn Histogram::max(self : Histogram) -> Int64 {
  self.max_value
}

///|
pub fn Histogram::total_count(self : Histogram) -> Int64 {
  self.total_count
}

///|
pub fn Histogram::reset(self : Histogram) -> Unit {
  for i in 0..<self.counts_len {
    self.counts[i] = 0L
  }
  self.total_count = 0L
  self.min_value = 0x7FFFFFFFFFFFFFFFL
  self.max_value = 0L
  self.sum = 0.0
  self.sum_of_squares = 0.0
}
```

- [ ] **Step 4: Run whitebox tests**

Run:
```bash
moon test --package paveg/molt/src/lib/histogram
```

Expected: all 3 whitebox tests PASS.

- [ ] **Step 5: Add blackbox percentile accuracy tests**

Create `src/lib/histogram/histogram_test.mbt`:
```moonbit
///|
test "percentile with uniform distribution" {
  let h = @histogram.Histogram::new(100000L, 3)
  for i in 1..=1000 {
    h.record(i.to_int64())
  }
  let p50 = h.percentile(50.0)
  let p99 = h.percentile(99.0)
  // p50 should be near 500, p99 near 990
  // HDR Histogram reports the highest equivalent value in the bucket
  inspect(p50 >= 495L && p50 <= 505L, content="true")
  inspect(p99 >= 985L && p99 <= 995L, content="true")
}

///|
test "percentile with single value" {
  let h = @histogram.Histogram::new(100000L, 3)
  h.record(42L)
  inspect(h.percentile(50.0), content="42")
  inspect(h.percentile(99.0), content="42")
  inspect(h.percentile(99.9), content="42")
}

///|
test "percentile with identical values" {
  let h = @histogram.Histogram::new(100000L, 3)
  for _ in 0..<1000 {
    h.record(500L)
  }
  inspect(h.percentile(50.0), content="500")
  inspect(h.percentile(99.0), content="500")
}

///|
test "mean and stdev" {
  let h = @histogram.Histogram::new(100000L, 3)
  for i in 1..=100 {
    h.record(i.to_int64())
  }
  let mean = h.mean()
  // Mean of 1..100 = 50.5
  inspect(mean >= 50.0 && mean <= 51.0, content="true")
  let sd = h.stdev()
  // Stdev of 1..100 ≈ 29.01
  inspect(sd >= 28.0 && sd <= 30.0, content="true")
}

///|
test "min and max" {
  let h = @histogram.Histogram::new(3600000000L, 3)
  h.record(10L)
  h.record(50000L)
  h.record(1000000L)
  inspect(h.min(), content="10")
  inspect(h.max(), content="1000000")
}

///|
test "empty histogram" {
  let h = @histogram.Histogram::new(100000L, 3)
  inspect(h.percentile(50.0), content="0")
  inspect(h.mean(), content="0")
  inspect(h.stdev(), content="0")
  inspect(h.total_count(), content="0")
}

///|
test "reset clears all data" {
  let h = @histogram.Histogram::new(100000L, 3)
  h.record(100L)
  h.record(200L)
  h.reset()
  inspect(h.total_count(), content="0")
  inspect(h.percentile(50.0), content="0")
}

///|
test "large values within range" {
  let h = @histogram.Histogram::new(3600000000L, 3)
  h.record(1L)
  h.record(1000000L)
  h.record(3000000000L)
  inspect(h.total_count(), content="3")
  inspect(h.min(), content="1")
  inspect(h.max(), content="3000000000")
}
```

- [ ] **Step 6: Run all histogram tests**

Run:
```bash
moon test --package paveg/molt/src/lib/histogram
```

Expected: all 11 tests PASS. If percentile accuracy tests fail, adjust the bucket math. The HDR Histogram should be accurate to 3 significant figures, so p50 of [1..1000] should be within 0.1% of 500.

- [ ] **Step 7: Commit**

```bash
git add src/lib/histogram/
git commit -m "feat: implement Gil Tene HDR Histogram with percentile accuracy"
```

---

### Task 3: Config Validation (PARALLEL — depends only on types)

**Files:**
- Create: `src/lib/types/types_test.mbt`

Config validation logic lives with the Config type. Tests verify defaults and mutual exclusion rules.

- [ ] **Step 1: Write failing tests**

Create `src/lib/types/types_test.mbt`:
```moonbit
///|
test "default config has correct defaults" {
  let c = @types.Config::default_with_url("https://example.com")
  inspect(c.connections, content="50")
  inspect(c.mode, content="Duration(10000)")
  inspect(c.method, content="Get")
  inspect(c.timeout_ms, content="30000")
  inspect(c.enable_tui, content="true")
  inspect(c.json_output, content="false")
  inspect(c.latency_correction, content="true")
}
```

- [ ] **Step 2: Run tests**

Run:
```bash
moon test --package paveg/molt/src/lib/types
```

Expected: PASS (the default constructor already exists).

- [ ] **Step 3: Commit**

```bash
git add src/lib/types/
git commit -m "feat: add config validation tests"
```

---

### Task 4: Collector (depends on types + histogram)

**Files:**
- Modify: `src/lib/collector/collector.mbt`
- Create: `src/lib/collector/collector_test.mbt`

The Collector aggregates `RequestResult` values into `Stats`. For Phase 1 MVP, it operates synchronously (no Queue yet — that comes with the async Coordinator integration).

- [ ] **Step 1: Write failing tests**

Create `src/lib/collector/collector_test.mbt`:
```moonbit
///|
test "collect single successful result" {
  let c = @collector.Collector::new()
  c.record(@types.RequestResult::{
    status_code: 200,
    latency_us: 5000L,
    error: None,
  })
  let stats = c.finalize(1000.0)
  inspect(stats.total_requests, content="1")
  inspect(stats.successful, content="1")
  inspect(stats.failed, content="0")
}

///|
test "collect mixed results" {
  let c = @collector.Collector::new()
  for _ in 0..<90 {
    c.record(@types.RequestResult::{
      status_code: 200,
      latency_us: 1000L,
      error: None,
    })
  }
  for _ in 0..<10 {
    c.record(@types.RequestResult::{
      status_code: 500,
      latency_us: 5000L,
      error: None,
    })
  }
  let stats = c.finalize(1000.0)
  inspect(stats.total_requests, content="100")
  inspect(stats.successful, content="100")
  inspect(stats.failed, content="0")
  inspect(stats.status_codes.get(200), content="Some(90)")
  inspect(stats.status_codes.get(500), content="Some(10)")
}

///|
test "collect error results" {
  let c = @collector.Collector::new()
  c.record(@types.RequestResult::{
    status_code: 0,
    latency_us: 0L,
    error: Some(@types.RequestError::Timeout),
  })
  c.record(@types.RequestResult::{
    status_code: 0,
    latency_us: 0L,
    error: Some(@types.RequestError::ConnectionRefused),
  })
  let stats = c.finalize(1000.0)
  inspect(stats.total_requests, content="2")
  inspect(stats.failed, content="2")
  inspect(stats.errors.get("Timeout"), content="Some(1)")
  inspect(stats.errors.get("ConnectionRefused"), content="Some(1)")
}

///|
test "latency stats are computed" {
  let c = @collector.Collector::new()
  for i in 1..=100 {
    c.record(@types.RequestResult::{
      status_code: 200,
      latency_us: (i * 100).to_int64(),
      error: None,
    })
  }
  let stats = c.finalize(1000.0)
  // p50 of [100, 200, ..., 10000] ≈ 5000
  inspect(stats.latency.p50_us >= 4900L && stats.latency.p50_us <= 5100L, content="true")
  inspect(stats.latency.min_us, content="100")
  inspect(stats.latency.max_us, content="10000")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
moon test --package paveg/molt/src/lib/collector
```

Expected: FAIL — placeholder implementation.

- [ ] **Step 3: Implement Collector**

Replace `src/lib/collector/collector.mbt`:
```moonbit
///|
pub struct Collector {
  priv histogram : @histogram.Histogram
  priv mut total_requests : Int
  priv mut failed : Int
  priv status_codes : Map[Int, Int]
  priv errors : Map[String, Int]
}

///|
pub fn Collector::new() -> Collector {
  {
    histogram: @histogram.Histogram::new(3600000000L, 3),
    total_requests: 0,
    failed: 0,
    status_codes: {},
    errors: {},
  }
}

///|
pub fn Collector::record(self : Collector, result : @types.RequestResult) -> Unit {
  self.total_requests = self.total_requests + 1
  match result.error {
    Some(err) => {
      self.failed = self.failed + 1
      let key = err.to_string()
      let count = self.errors.get(key).or(0)
      self.errors[key] = count + 1
    }
    None => {
      self.histogram.record(result.latency_us)
      let code = result.status_code
      let count = self.status_codes.get(code).or(0)
      self.status_codes[code] = count + 1
    }
  }
}

///|
/// Finalize and produce Stats. `total_time_ms` is the wall clock duration.
pub fn Collector::finalize(self : Collector, total_time_ms : Double) -> @types.Stats {
  let successful = self.total_requests - self.failed
  let rps = if total_time_ms > 0.0 {
    successful.to_double() / (total_time_ms / 1000.0)
  } else {
    0.0
  }
  let latency : @types.LatencyStats = {
    p50_us: self.histogram.percentile(50.0),
    p75_us: self.histogram.percentile(75.0),
    p90_us: self.histogram.percentile(90.0),
    p95_us: self.histogram.percentile(95.0),
    p99_us: self.histogram.percentile(99.0),
    p99_9_us: self.histogram.percentile(99.9),
    max_us: self.histogram.max(),
    min_us: self.histogram.min(),
    mean_us: self.histogram.mean(),
    stdev_us: self.histogram.stdev(),
  }
  {
    total_requests: self.total_requests,
    successful,
    failed: self.failed,
    total_time_ms,
    requests_per_sec: rps,
    latency,
    status_codes: self.status_codes,
    errors: self.errors,
  }
}
```

- [ ] **Step 4: Run tests**

Run:
```bash
moon test --package paveg/molt/src/lib/collector
```

Expected: all 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/lib/collector/
git commit -m "feat: implement Collector with HDR Histogram-based stats aggregation"
```

---

### Task 5: Reporter — Text Output (depends on types)

**Files:**
- Modify: `src/lib/reporter/reporter.mbt`
- Create: `src/lib/reporter/reporter_test.mbt`

- [ ] **Step 1: Write failing tests**

Create `src/lib/reporter/reporter_test.mbt`:
```moonbit
///|
fn make_test_stats() -> @types.Stats {
  {
    total_requests: 1000,
    successful: 990,
    failed: 10,
    total_time_ms: 10000.0,
    requests_per_sec: 99.0,
    latency: {
      p50_us: 12340L,
      p75_us: 18560L,
      p90_us: 25120L,
      p95_us: 32450L,
      p99_us: 67890L,
      p99_9_us: 145230L,
      max_us: 312450L,
      min_us: 1230L,
      mean_us: 15670.0,
      stdev_us: 12340.0,
    },
    status_codes: { 200: 980, 500: 10 },
    errors: { "Timeout": 8, "ConnectionReset": 2 },
  }
}

///|
test "report_text contains summary section" {
  let output = @reporter.report_text(make_test_stats())
  inspect(output.contains("Total requests"), content="true")
  inspect(output.contains("1000"), content="true")
  inspect(output.contains("990"), content="true")
}

///|
test "report_text contains latency section" {
  let output = @reporter.report_text(make_test_stats())
  inspect(output.contains("p50"), content="true")
  inspect(output.contains("p99"), content="true")
}

///|
test "report_text contains status codes" {
  let output = @reporter.report_text(make_test_stats())
  inspect(output.contains("200"), content="true")
  inspect(output.contains("500"), content="true")
}

///|
test "report_text contains errors" {
  let output = @reporter.report_text(make_test_stats())
  inspect(output.contains("Timeout"), content="true")
  inspect(output.contains("ConnectionReset"), content="true")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
moon test --package paveg/molt/src/lib/reporter
```

Expected: FAIL — `abort("not implemented")`

- [ ] **Step 3: Implement text reporter**

Replace `src/lib/reporter/reporter.mbt`:
```moonbit
///|
fn format_us_as_ms(us : Int64) -> String {
  let ms_whole = us / 1000L
  let ms_frac = (us % 1000L) / 10L
  "\{ms_whole}.\{ms_frac}ms"
}

///|
fn format_percentage(part : Int, total : Int) -> String {
  guard total > 0 else { return "0.00%" }
  let pct = part.to_double() / total.to_double() * 100.0
  let whole = pct.to_int()
  let frac = ((pct - whole.to_double()) * 100.0).to_int()
  "\{whole}.\{frac}%"
}

///|
fn format_rps(rps : Double) -> String {
  let whole = rps.to_int()
  let frac = ((rps - whole.to_double()) * 100.0).to_int()
  "\{whole}.\{frac}"
}

///|
fn format_time(ms : Double) -> String {
  let whole = (ms / 1000.0).to_int()
  let frac = ((ms % 1000.0) / 10.0).to_int()
  "\{whole}.\{frac}s"
}

///|
pub fn report_text(stats : @types.Stats) -> String {
  let buf = StringBuilder::new()
  buf.write_string("Summary:\n")
  buf.write_string("  Total requests:    \{stats.total_requests}\n")
  buf.write_string(
    "  Successful:        \{stats.successful} (\{format_percentage(stats.successful, stats.total_requests)})\n",
  )
  buf.write_string(
    "  Failed:            \{stats.failed} (\{format_percentage(stats.failed, stats.total_requests)})\n",
  )
  buf.write_string("  Total time:        \{format_time(stats.total_time_ms)}\n")
  buf.write_string("  Requests/sec:      \{format_rps(stats.requests_per_sec)}\n")
  buf.write_string("\n")
  buf.write_string("Latency Distribution:\n")
  let lat = stats.latency
  buf.write_string("  p50     \{format_us_as_ms(lat.p50_us)}\n")
  buf.write_string("  p75     \{format_us_as_ms(lat.p75_us)}\n")
  buf.write_string("  p90     \{format_us_as_ms(lat.p90_us)}\n")
  buf.write_string("  p95     \{format_us_as_ms(lat.p95_us)}\n")
  buf.write_string("  p99     \{format_us_as_ms(lat.p99_us)}\n")
  buf.write_string("  p99.9   \{format_us_as_ms(lat.p99_9_us)}\n")
  buf.write_string("  max     \{format_us_as_ms(lat.max_us)}\n")
  buf.write_string("\n")
  buf.write_string("  mean    \{format_us_as_ms(lat.mean_us.to_int64())}\n")
  buf.write_string("  stdev   \{format_us_as_ms(lat.stdev_us.to_int64())}\n")
  buf.write_string("\n")
  buf.write_string("Status Codes:\n")
  for code, count in stats.status_codes {
    buf.write_string("  \{code}: \{count}\n")
  }
  if stats.errors.size() > 0 {
    buf.write_string("\nErrors:\n")
    for err_type, count in stats.errors {
      buf.write_string("  \{err_type}: \{count}\n")
    }
  }
  buf.to_string()
}
```

- [ ] **Step 4: Run tests**

Run:
```bash
moon test --package paveg/molt/src/lib/reporter
```

Expected: all 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/lib/reporter/
git commit -m "feat: implement text summary reporter"
```

---

### Task 6: Worker (depends on types + async/http)

**Files:**
- Modify: `src/lib/worker/worker.mbt`

The Worker is an async function that sends HTTP requests in a loop and sends results to a callback. For Phase 1, we implement the core loop. Testing happens at the integration level (Task 8) since it requires a live HTTP server.

- [ ] **Step 1: Implement Worker**

Replace `src/lib/worker/worker.mbt`:
```moonbit
///|
pub async fn run(
  config : @types.Config,
  on_result : (@types.RequestResult) -> Unit,
  should_stop : () -> Bool,
) -> Unit {
  let url = config.url
  let client = @http.Client::new(url)
  while not(should_stop()) {
    let start = @bench.monotonic_clock_start()
    try {
      let response = client.get("/")
      let elapsed_us = @bench.monotonic_clock_end(start)
      on_result(
        {
          status_code: response.code,
          latency_us: elapsed_us.to_int64(),
          error: None,
        },
      )
      client.skip_response_body()
    } catch {
      _ => {
        let elapsed_us = @bench.monotonic_clock_end(start)
        on_result(
          {
            status_code: 0,
            latency_us: elapsed_us.to_int64(),
            error: Some(@types.RequestError::Other("request failed")),
          },
        )
      }
    }
  }
  client.close()
}
```

- [ ] **Step 2: Verify compilation**

Run:
```bash
moon check --target native
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add src/lib/worker/
git commit -m "feat: implement async HTTP worker loop"
```

---

### Task 7: Coordinator (depends on types + worker + collector + async)

**Files:**
- Modify: `src/lib/coordinator/coordinator.mbt`

The Coordinator wires everything together: spawns workers, collects results, enforces termination.

- [ ] **Step 1: Implement Coordinator**

Replace `src/lib/coordinator/coordinator.mbt`:
```moonbit
///|
pub async fn run(config : @types.Config) -> @types.Stats {
  let collector = @collector.Collector::new()
  let mut stopped = false
  let start_time = @bench.monotonic_clock_start()
  @async.with_task_group(
    fn(group) {
      // Spawn workers
      for _ in 0..<config.connections {
        group.spawn_bg(
          fn() {
            @worker.run(
              config,
              fn(result) { collector.record(result) },
              fn() { stopped },
            )
          },
        )
      }
      // Wait for termination condition
      match config.mode {
        @types.TestMode::Duration(ms) => @async.sleep(ms.to_int64())
        @types.TestMode::RequestCount(n) => {
          // Poll until we reach the target count
          while collector.total_requests() < n {
            @async.sleep(10L)
          }
        }
      }
      stopped = true
    },
  )
  let elapsed_ms = @bench.monotonic_clock_end(start_time) / 1000.0
  collector.finalize(elapsed_ms)
}
```

- [ ] **Step 2: Add `total_requests` accessor to Collector**

Add to `src/lib/collector/collector.mbt`:
```moonbit
///|
pub fn Collector::total_requests(self : Collector) -> Int {
  self.total_requests
}
```

- [ ] **Step 3: Verify compilation**

Run:
```bash
moon check --target native
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add src/lib/coordinator/ src/lib/collector/
git commit -m "feat: implement Coordinator with TaskGroup-based worker management"
```

---

### Task 8: CLI Entry Point (depends on everything)

**Files:**
- Modify: `src/cmd/main/main.mbt`

- [ ] **Step 1: Implement CLI parser and main**

Replace `src/cmd/main/main.mbt`:
```moonbit
///|
fn main {
  @async.with_task_group(
    fn(group) {
      group.spawn(
        fn() {
          let config = parse_args() catch {
            err => {
              println("Error: \{err}")
              return
            }
          }
          println("molt v0.1.0 -- MoonBit HTTP Load Tester\n")
          println("Target:       \{config.url}")
          println("Connections:  \{config.connections}")
          match config.mode {
            @types.TestMode::Duration(ms) =>
              println("Duration:     \{ms / 1000}s")
            @types.TestMode::RequestCount(n) =>
              println("Requests:     \{n}")
          }
          println("\nRunning...\n")
          let stats = @coordinator.run(config)
          let report = @reporter.report_text(stats)
          println(report)
        },
      )
    },
  )
}

///|
fn parse_args() -> @types.Config raise {
  let cmd = @argparse.Command(
    "molt",
    about="MoonBit HTTP Load Tester",
    version="0.1.0",
    options=[
      @argparse.OptionArg("connections", short='c', long="connections", about="Number of concurrent connections", default_values=["50"]),
      @argparse.OptionArg("duration", short='d', long="duration", about="Test duration (e.g. 10s, 1m)"),
      @argparse.OptionArg("requests", short='n', long="requests", about="Total number of requests"),
    ],
    positionals=[
      @argparse.PositionArg("url", about="Target URL"),
    ],
  )
  let matches = cmd.parse()
  let url_values = matches.values.get("url").or([])
  guard url_values.length() > 0 else {
    abort("URL is required")
  }
  let url = url_values[0]
  let connections = @strconv.parse_int(
    matches.values.get("connections").or(["50"])[0],
  ) catch { _ => 50 }
  // Determine test mode
  let duration_val = matches.values.get("duration")
  let requests_val = matches.values.get("requests")
  let mode = match (duration_val, requests_val) {
    (Some(d), Some(_)) => {
      // Both specified — error
      abort("Cannot specify both --duration and --requests")
    }
    (Some(d), None) => {
      guard d.length() > 0 else {
        @types.TestMode::Duration(10000)
      }
      let ms = @duration.parse(d[0]) catch { _ => 10000 }
      @types.TestMode::Duration(ms)
    }
    (None, Some(r)) => {
      guard r.length() > 0 else {
        @types.TestMode::Duration(10000)
      }
      let n = @strconv.parse_int(r[0]) catch { _ => abort("Invalid request count") }
      @types.TestMode::RequestCount(n)
    }
    (None, None) => @types.TestMode::Duration(10000)
  }
  {
    url,
    connections,
    mode,
    method: @types.HttpMethod::Get,
    headers: [],
    body: None,
    timeout_ms: 30000,
    enable_tui: false,
    json_output: false,
    latency_correction: true,
  }
}
```

- [ ] **Step 2: Verify compilation**

Run:
```bash
moon check --target native
```

Expected: no errors.

- [ ] **Step 3: Build native binary**

Run:
```bash
moon build --target native
```

Expected: binary produced in `_build/native/debug/build/`.

- [ ] **Step 4: Commit**

```bash
git add src/cmd/main/
git commit -m "feat: implement CLI entry point with argparse"
```

---

### Task 9: Integration Test — End-to-End Smoke Test

**Files:**
- Create: `src/lib/coordinator/coordinator_test.mbt`

Uses `@http.Server` to start a local HTTP server and runs the Coordinator against it.

- [ ] **Step 1: Write integration test**

Create `src/lib/coordinator/coordinator_test.mbt`:
```moonbit
///|
async test "coordinator runs against local server" {
  @async.with_task_group(
    fn(group) {
      // Start test HTTP server
      let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
      group.spawn_bg(
        no_wait=true,
        fn() {
          server.run_forever(
            fn(_request, body, conn) {
              // Drain request body
              while body.read_some() is Some(_) {

              }
              conn.send_response(200, "OK")
              conn.write("ok")
            },
          )
        },
      )
      let port = server.addr.port()
      let config : @types.Config = {
        url: "http://127.0.0.1:\{port}",
        connections: 2,
        mode: @types.TestMode::Duration(1000),
        method: @types.HttpMethod::Get,
        headers: [],
        body: None,
        timeout_ms: 5000,
        enable_tui: false,
        json_output: false,
        latency_correction: true,
      }
      let stats = @coordinator.run(config)
      // Should have completed some requests in 1 second
      inspect(stats.total_requests > 0, content="true")
      inspect(stats.successful > 0, content="true")
      inspect(stats.failed, content="0")
      inspect(stats.latency.p50_us > 0L, content="true")
      inspect(stats.status_codes.get(200).is_empty().not(), content="true")
    },
  )
}
```

- [ ] **Step 2: Update coordinator moon.pkg for test imports**

Update `src/lib/coordinator/moon.pkg` to add test-only imports:
```
import {
  "paveg/molt/src/lib/types",
  "paveg/molt/src/lib/worker",
  "paveg/molt/src/lib/collector",
  "moonbitlang/async",
}

import {
  "moonbitlang/async/http",
  "moonbitlang/async/socket",
} for "test"

options(
  targets: {
    "coordinator.mbt": [ "native" ],
    "coordinator_test.mbt": [ "native" ],
  },
)
```

- [ ] **Step 3: Run integration test**

Run:
```bash
moon test --package paveg/molt/src/lib/coordinator --target native
```

Expected: PASS. The test starts a local server, runs 2 workers for 1 second, and verifies requests were made.

If the test fails, common issues:
- Import paths may need adjustment
- `@http.Server` constructor or `run_forever` API may differ — check the actual source
- Worker may need URL path parsing fixes

- [ ] **Step 4: Commit**

```bash
git add src/lib/coordinator/
git commit -m "test: add integration test with local HTTP server"
```

---

### Task 10: Manual Smoke Test

- [ ] **Step 1: Build the binary**

Run:
```bash
moon build --target native
```

- [ ] **Step 2: Run against a public endpoint**

Run:
```bash
./_build/native/debug/build/src/cmd/main/main -c 5 -d 3s https://httpbin.org/get
```

Expected output (approximate):
```
molt v0.1.0 -- MoonBit HTTP Load Tester

Target:       https://httpbin.org/get
Connections:  5
Duration:     3s

Running...

Summary:
  Total requests:    ...
  Successful:        ...
  ...
```

If the binary path is different, check `find _build -type f -perm +111` to locate it.

- [ ] **Step 3: Fix any issues discovered during manual testing**

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: molt Phase 1 MVP complete — concurrent HTTP load testing with HDR Histogram"
```
