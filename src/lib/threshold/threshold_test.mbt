///|
fn make_stats(p99_us : Int64, total : Int, failed : Int) -> @types.Stats {
  {
    total_requests: total,
    successful: total - failed,
    failed,
    total_time_ms: 1000.0,
    requests_per_sec: total.to_double(),
    latency: {
      p50_us: 0L,
      p75_us: 0L,
      p90_us: 0L,
      p95_us: 0L,
      p99_us,
      p99_9_us: 0L,
      max_us: 0L,
      min_us: 0L,
      mean_us: 0.0,
      stdev_us: 0.0,
    },
    ttfb: {
      p50_us: 0L,
      p75_us: 0L,
      p90_us: 0L,
      p95_us: 0L,
      p99_us: 0L,
      p99_9_us: 0L,
      max_us: 0L,
      min_us: 0L,
      mean_us: 0.0,
      stdev_us: 0.0,
    },
    status_codes: {},
    errors: {},
    custom_percentiles: [],
    time_series: [],
    total_bytes: 0L,
    bytes_per_sec: 0.0,
  }
}

///|
fn make_config(
  latency_threshold_us? : Int64? = None,
  error_threshold_pct? : Double? = None,
) -> @types.Config {
  {
    url: "http://example.com",
    connections: 10,
    mode: @types.TestMode::Duration(10000),
    http_method: @types.HttpMethod::Get,
    headers: [],
    body: None,
    timeout_ms: 30000,
    enable_tui: false,
    json_output: false,
    latency_correction: true,
    rate: None,
    percentiles: [50.0, 75.0, 90.0, 95.0, 99.0, 99.9],
    latency_threshold_us,
    error_threshold_pct,
    warm_up_ms: 0,
    insecure: false,
    disable_keepalive: false,
    debug: false,
    csv_output: false,
    max_redirects: 0,
    serve_addr: None,
  }
}

///|
test "no thresholds always passes" {
  let stats = make_stats(100000L, 100, 10)
  let config = make_config()
  let result = @threshold.check(stats, config)
  inspect(result.passed, content="true")
  inspect(result.violations.length(), content="0")
}

///|
test "latency threshold exactly at limit passes" {
  let stats = make_stats(100000L, 100, 0) // p99 = 100000us
  let config = make_config(latency_threshold_us=Some(100000L))
  let result = @threshold.check(stats, config)
  inspect(result.passed, content="true")
}

///|
test "latency threshold exceeded fails" {
  let stats = make_stats(100001L, 100, 0) // p99 = 100001us, threshold = 100000us
  let config = make_config(latency_threshold_us=Some(100000L))
  let result = @threshold.check(stats, config)
  inspect(result.passed, content="false")
  inspect(result.violations.length(), content="1")
}

///|
test "latency threshold with zero latency passes" {
  let stats = make_stats(0L, 100, 0)
  let config = make_config(latency_threshold_us=Some(100000L))
  let result = @threshold.check(stats, config)
  inspect(result.passed, content="true")
}

///|
test "error threshold exactly at limit passes" {
  // 1 failed out of 100 = 1.0%, threshold = 1.0%
  let stats = make_stats(0L, 100, 1)
  let config = make_config(error_threshold_pct=Some(1.0))
  let result = @threshold.check(stats, config)
  inspect(result.passed, content="true")
}

///|
test "error threshold exceeded fails" {
  // 2 failed out of 100 = 2.0%, threshold = 1.0%
  let stats = make_stats(0L, 100, 2)
  let config = make_config(error_threshold_pct=Some(1.0))
  let result = @threshold.check(stats, config)
  inspect(result.passed, content="false")
  inspect(result.violations.length(), content="1")
}

///|
test "error threshold with zero requests passes" {
  let stats = make_stats(0L, 0, 0)
  let config = make_config(error_threshold_pct=Some(1.0))
  let result = @threshold.check(stats, config)
  inspect(result.passed, content="true")
}

///|
test "error threshold 0% fails on any error" {
  // 1 failed out of 100 = 1.0%, threshold = 0.0%
  let stats = make_stats(0L, 100, 1)
  let config = make_config(error_threshold_pct=Some(0.0))
  let result = @threshold.check(stats, config)
  inspect(result.passed, content="false")
}

///|
test "both thresholds checked independently" {
  // latency ok, error ok
  let stats = make_stats(50000L, 100, 0)
  let config = make_config(
    latency_threshold_us=Some(100000L),
    error_threshold_pct=Some(1.0),
  )
  let result = @threshold.check(stats, config)
  inspect(result.passed, content="true")
  inspect(result.violations.length(), content="0")
}

///|
test "both thresholds violated reports both" {
  // latency exceeded, error exceeded
  let stats = make_stats(200000L, 100, 5)
  let config = make_config(
    latency_threshold_us=Some(100000L),
    error_threshold_pct=Some(1.0),
  )
  let result = @threshold.check(stats, config)
  inspect(result.passed, content="false")
  inspect(result.violations.length(), content="2")
}
