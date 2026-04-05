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
  inspect(
    @types.parse_header("X-Empty: "),
    content="Some((\"X-Empty\", \"\"))",
  )
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
  inspect(
    @types.parse_header(": value"),
    content="Some((\"\", \"value\"))",
  )
}
