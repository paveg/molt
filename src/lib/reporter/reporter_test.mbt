///|
fn make_test_stats() -> @types.Stats {
  @types.Stats::new(
    total_requests=1000,
    successful=990,
    failed=10,
    total_time_ms=10000.0,
    requests_per_sec=99.0,
    latency=@types.LatencyStats::new(
      p50_us=12340L,
      p75_us=18560L,
      p90_us=25120L,
      p95_us=32450L,
      p99_us=67890L,
      p99_9_us=145230L,
      max_us=312450L,
      min_us=1230L,
      mean_us=15670.0,
      stdev_us=12340.0,
    ),
    status_codes={ 200: 980, 500: 10 },
    errors={ "Timeout": 8, "ConnectionReset": 2 },
  )
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
