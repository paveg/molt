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
      let count = match self.errors.get(key) {
        Some(c) => c
        None => 0
      }
      self.errors[key] = count + 1
    }
    None => {
      self.histogram.record(result.latency_us)
      let code = result.status_code
      let count = match self.status_codes.get(code) {
        Some(c) => c
        None => 0
      }
      self.status_codes[code] = count + 1
    }
  }
}

///|
pub fn Collector::total_requests(self : Collector) -> Int {
  self.total_requests
}

///|
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
