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

///|
test "request result with scheduled time" {
  let r : @types.RequestResult = {
    status_code: 200,
    latency_us: 5000L,
    error: None,
    scheduled_time_us: 1000L,
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
  }
  inspect(r.scheduled_time_us, content="0")
}
