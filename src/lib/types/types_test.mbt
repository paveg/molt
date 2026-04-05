///|
test "default config has correct defaults" {
  let c = @types.Config::default_with_url("https://example.com")
  inspect(c.connections, content="50")
  inspect(c.mode, content="Duration(10000)")
  inspect(c.http_method, content="Get")
  inspect(c.timeout_ms, content="30000")
  inspect(c.enable_tui, content="true")
  inspect(c.json_output, content="false")
  inspect(c.latency_correction, content="true")
}

///|
test "request result with scheduled time" {
  let r : @types.RequestResult = {
    status_code: 200,
    latency_us: 5000L,
    error: None,
    scheduled_time_us: 1000L,
    response_size_bytes: 0L,
  }
  inspect(r.scheduled_time_us, content="1000")
}

///|
test "request result with zero scheduled time" {
  let r : @types.RequestResult = {
    status_code: 200,
    latency_us: 5000L,
    error: None,
    scheduled_time_us: 0L,
    response_size_bytes: 0L,
  }
  inspect(r.scheduled_time_us, content="0")
}

///|
test "parse_header standard header" {
  inspect(
    @types.parse_header("Content-Type: application/json"),
    content="Some((\"Content-Type\", \"application/json\"))",
  )
}

///|
test "parse_header no space after colon returns None" {
  inspect(@types.parse_header("Key:Value"), content="None")
}

///|
test "parse_header empty value after colon-space" {
  inspect(@types.parse_header("X-Empty: "), content="Some((\"X-Empty\", \"\"))")
}

///|
test "parse_header colon in value splits on first occurrence" {
  inspect(
    @types.parse_header("Authorization: Bearer: token"),
    content="Some((\"Authorization\", \"Bearer: token\"))",
  )
}

///|
test "parse_header no colon returns None" {
  inspect(@types.parse_header("InvalidHeader"), content="None")
}

///|
test "parse_header empty string returns None" {
  inspect(@types.parse_header(""), content="None")
}

///|
test "parse_header only colon-space prefix yields empty key" {
  inspect(@types.parse_header(": value"), content="Some((\"\", \"value\"))")
}

///|
test "parse_header rejects CRLF in value" {
  inspect(@types.parse_header("X-Bad: value\r\nInjected: evil"), content="None")
}

///|
test "parse_header rejects newline in name" {
  inspect(@types.parse_header("X-Bad\n: value"), content="None")
}

///|
test "parse_header rejects carriage return" {
  inspect(@types.parse_header("X-Bad: value\rmore"), content="None")
}

///|
test "default config has rate None" {
  let c = @types.Config::default_with_url("https://example.com")
  inspect(c.rate, content="None")
}

///|
test "default config has default percentiles" {
  let c = @types.Config::default_with_url("https://example.com")
  inspect(c.percentiles.length(), content="6")
  inspect(c.percentiles[0], content="50")
  inspect(c.percentiles[5], content="99.9")
}

///|
test "time series point creation" {
  let point : @types.TimeSeriesPoint = {
    elapsed_sec: 1.0,
    requests: 100,
    rps: 100.0,
    p50_us: 5000L,
    p99_us: 50000L,
    errors: 0,
  }
  inspect(point.rps, content="100")
  inspect(point.requests, content="100")
  inspect(point.elapsed_sec, content="1")
  inspect(point.errors, content="0")
}

///|
test "request result with response size" {
  let r : @types.RequestResult = {
    status_code: 200,
    latency_us: 5000L,
    error: None,
    scheduled_time_us: 0L,
    response_size_bytes: 4096L,
  }
  inspect(r.response_size_bytes, content="4096")
}

///|
test "base64 encode empty" {
  inspect(@types.base64_encode(""), content="")
}

///|
test "base64 encode simple" {
  inspect(@types.base64_encode("user:pass"), content="dXNlcjpwYXNz")
}

///|
test "base64 encode with padding" {
  inspect(@types.base64_encode("a"), content="YQ==")
}

///|
test "base64 encode no padding" {
  inspect(@types.base64_encode("abc"), content="YWJj")
}

///|
test "base64 encode one pad" {
  inspect(@types.base64_encode("ab"), content="YWI=")
}

///|
test "base64 encode longer string" {
  inspect(@types.base64_encode("Hello, World!"), content="SGVsbG8sIFdvcmxkIQ==")
}

///|
test "stats new with custom percentiles" {
  let stats = @types.Stats::new(
    total_requests=100,
    successful=100,
    failed=0,
    total_time_ms=1000.0,
    requests_per_sec=100.0,
    latency=@types.LatencyStats::new(
      p50_us=1000L,
      p75_us=2000L,
      p90_us=3000L,
      p95_us=4000L,
      p99_us=5000L,
      p99_9_us=6000L,
      max_us=7000L,
      min_us=500L,
      mean_us=1500.0,
      stdev_us=800.0,
    ),
    status_codes={ 200: 100 },
    errors={},
    custom_percentiles=[(50.0, 1000L), (99.0, 5000L)],
    total_bytes=102400L,
    bytes_per_sec=102400.0,
  )
  inspect(stats.custom_percentiles.length(), content="2")
  inspect(stats.total_bytes, content="102400")
  inspect(stats.bytes_per_sec, content="102400")
}
