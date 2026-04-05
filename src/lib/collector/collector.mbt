///|
pub struct Collector {
  priv histogram : @histogram.Histogram
  priv mut total_requests : Int
  priv mut failed : Int
  priv status_codes : Map[Int, Int]
  priv errors : Map[String, Int]
  priv mut total_bytes : Int64
}

///|
pub fn Collector::new() -> Collector {
  {
    histogram: @histogram.Histogram::new(3600000000L, 3),
    total_requests: 0,
    failed: 0,
    status_codes: {},
    errors: {},
    total_bytes: 0L,
  }
}

///|
pub fn Collector::reset(self : Collector) -> Unit {
  self.histogram.reset()
  self.total_requests = 0
  self.failed = 0
  self.status_codes.clear()
  self.errors.clear()
  self.total_bytes = 0L
}

///|
pub fn Collector::record(
  self : Collector,
  result : @types.RequestResult,
) -> Unit {
  self.total_requests = self.total_requests + 1
  self.total_bytes = self.total_bytes + result.response_size_bytes
  match result.error {
    Some(err) => {
      self.failed = self.failed + 1
      let key = err.to_string()
      self.errors[key] = self.errors.get(key).unwrap_or(0) + 1
    }
    None => {
      self.histogram.record(result.latency_us)
      let code = result.status_code
      self.status_codes[code] = self.status_codes.get(code).unwrap_or(0) + 1
      if code >= 500 {
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
pub fn Collector::live_percentile(self : Collector, p : Double) -> Int64 {
  self.histogram.percentile(p)
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
  let custom_percentiles : Array[(Double, Int64)] = []
  for p in percentiles {
    custom_percentiles.push((p, self.histogram.percentile(p)))
  }
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
