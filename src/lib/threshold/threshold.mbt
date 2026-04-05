///|
pub(all) struct ThresholdResult {
  passed : Bool
  violations : Array[String]
}

///|
pub fn check(stats : @types.Stats, config : @types.Config) -> ThresholdResult {
  let violations : Array[String] = []
  if config.latency_threshold_us is Some(max_us) &&
    stats.latency.p99_us > max_us {
    let actual_ms = stats.latency.p99_us.to_double() / 1000.0
    let max_ms = max_us.to_double() / 1000.0
    violations.push("p99 latency \{actual_ms}ms exceeds threshold \{max_ms}ms")
  }
  if config.error_threshold_pct is Some(max_pct) && stats.total_requests > 0 {
    let error_pct = stats.failed.to_double() /
      stats.total_requests.to_double() *
      100.0
    if error_pct > max_pct {
      violations.push("error rate \{error_pct}% exceeds threshold \{max_pct}%")
    }
  }
  { passed: violations.length() == 0, violations }
}
