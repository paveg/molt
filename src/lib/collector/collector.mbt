///|
pub struct Collector {
  priv histogram : @histogram.Histogram
  priv ttfb_histogram : @histogram.Histogram
  priv mut total_requests : Int
  priv mut failed : Int
  priv status_codes : Map[Int, Int]
  priv errors : Map[String, Int]
  priv mut total_bytes : Int64
  // Cached percentiles for TUI (updated every N records)
  priv mut cached_p50 : Int64
  priv mut cached_p99 : Int64
  priv mut cache_stale : Int // records since last cache update
}

///|
pub fn Collector::new() -> Collector {
  {
    histogram: @histogram.Histogram::new(3600000000L, 3),
    ttfb_histogram: @histogram.Histogram::new(3600000000L, 3),
    total_requests: 0,
    failed: 0,
    status_codes: {},
    errors: {},
    total_bytes: 0L,
    cached_p50: 0L,
    cached_p99: 0L,
    cache_stale: 0,
  }
}

///|
pub fn Collector::reset(self : Collector) -> Unit {
  self.histogram.reset()
  self.ttfb_histogram.reset()
  self.total_requests = 0
  self.failed = 0
  self.status_codes.clear()
  self.errors.clear()
  self.total_bytes = 0L
  self.cached_p50 = 0L
  self.cached_p99 = 0L
  self.cache_stale = 0
}

///|

///|
/// Increment a map counter, combining get+set into a single pattern.
fn increment_counter(m : Map[Int, Int], key : Int) -> Unit {
  m[key] = m.get(key).unwrap_or(0) + 1
}

///|
fn increment_str_counter(m : Map[String, Int], key : String) -> Unit {
  m[key] = m.get(key).unwrap_or(0) + 1
}

///|
pub fn Collector::record(
  self : Collector,
  result : @types.RequestResult,
) -> Unit {
  self.total_requests = self.total_requests + 1
  self.total_bytes = self.total_bytes + result.response_size_bytes
  self.cache_stale = self.cache_stale + 1
  match result.error {
    Some(err) => {
      self.failed = self.failed + 1
      increment_str_counter(self.errors, err.to_string())
    }
    None => {
      self.histogram.record(result.latency_us)
      if result.ttfb_us > 0L {
        self.ttfb_histogram.record(result.ttfb_us)
      }
      increment_counter(self.status_codes, result.status_code)
      if result.status_code >= 500 {
        self.failed = self.failed + 1
      }
    }
  }
}

///|
pub fn Collector::total_requests(self : Collector) -> Int {
  self.total_requests
}

///|
pub fn Collector::failed_count(self : Collector) -> Int {
  self.failed
}

///|
/// Returns cached p50/p99 for TUI display. Refreshes every 100 records.
pub fn Collector::live_percentile(self : Collector, p : Double) -> Int64 {
  if self.cache_stale > 100 {
    self.cached_p50 = self.histogram.percentile(50.0)
    self.cached_p99 = self.histogram.percentile(99.0)
    self.cache_stale = 0
  }
  if p <= 50.0 {
    self.cached_p50
  } else {
    self.cached_p99
  }
}

///|
fn latency_stats_from_histogram(
  h : @histogram.Histogram,
) -> @types.LatencyStats {
  {
    p50_us: h.percentile(50.0),
    p75_us: h.percentile(75.0),
    p90_us: h.percentile(90.0),
    p95_us: h.percentile(95.0),
    p99_us: h.percentile(99.0),
    p99_9_us: h.percentile(99.9),
    max_us: h.max(),
    min_us: h.min(),
    mean_us: h.mean(),
    stdev_us: h.stdev(),
  }
}

///|
pub fn Collector::finalize(
  self : Collector,
  total_time_ms : Double,
  percentiles? : Array[Double] = [50.0, 75.0, 90.0, 95.0, 99.0, 99.9],
) -> @types.Stats {
  let successful = self.total_requests - self.failed
  let rps = if total_time_ms > 0.0 {
    successful.to_double() / (total_time_ms / 1000.0)
  } else {
    0.0
  }
  let latency = latency_stats_from_histogram(self.histogram)
  let ttfb = latency_stats_from_histogram(self.ttfb_histogram)
  let custom_percentiles = percentiles.map(fn(p) {
    (p, self.histogram.percentile(p))
  })
  let bytes_per_sec = if total_time_ms > 0.0 {
    self.total_bytes.to_double() / (total_time_ms / 1000.0)
  } else {
    0.0
  }
  {
    total_requests: self.total_requests,
    successful,
    failed: self.failed,
    total_time_ms,
    requests_per_sec: rps,
    latency,
    ttfb,
    status_codes: self.status_codes,
    errors: self.errors,
    custom_percentiles,
    time_series: [],
    total_bytes: self.total_bytes,
    bytes_per_sec,
  }
}

///|
pub fn Collector::snapshot(self : Collector) -> (Int, Int, Int64) {
  // Returns (total_requests, failed, total_bytes) for time-series capture
  (self.total_requests, self.failed, self.total_bytes)
}
