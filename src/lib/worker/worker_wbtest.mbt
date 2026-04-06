///|
test "parse_url/standard" {
  let (base, path) = parse_url("http://example.com/path")
  inspect(base, content="http://example.com")
  inspect(path, content="/path")
}

///|
test "parse_url/without_path" {
  let (base, path) = parse_url("http://example.com")
  inspect(base, content="http://example.com")
  inspect(path, content="/")
}

///|
test "parse_url/root_path" {
  let (base, path) = parse_url("http://example.com/")
  inspect(base, content="http://example.com")
  inspect(path, content="/")
}

///|
test "parse_url/multi_segment_path" {
  let (base, path) = parse_url("http://example.com/api/v1/users")
  inspect(base, content="http://example.com")
  inspect(path, content="/api/v1/users")
}

///|
test "parse_url/https" {
  let (base, path) = parse_url("https://example.com/path")
  inspect(base, content="https://example.com")
  inspect(path, content="/path")
}

///|
test "parse_url/with_port" {
  let (base, path) = parse_url("http://example.com:8080/path")
  inspect(base, content="http://example.com:8080")
  inspect(path, content="/path")
}

///|
test "parse_url/port_no_path" {
  let (base, path) = parse_url("http://localhost:3000")
  inspect(base, content="http://localhost:3000")
  inspect(path, content="/")
}

///|
test "parse_url/query_string" {
  let (base, path) = parse_url("http://example.com/path?q=1&b=2")
  inspect(base, content="http://example.com")
  inspect(path, content="/path?q=1&b=2")
}

///|
test "parse_url/localhost" {
  let (base, path) = parse_url("http://localhost/api")
  inspect(base, content="http://localhost")
  inspect(path, content="/api")
}

///|
test "parse_url/ip_address" {
  let (base, path) = parse_url("http://127.0.0.1:8080/health")
  inspect(base, content="http://127.0.0.1:8080")
  inspect(path, content="/health")
}

///|
test "build_headers empty array" {
  let h = build_headers([])
  inspect(h.length(), content="0")
}

///|
test "build_headers single header" {
  let h = build_headers([("Content-Type", "application/json")])
  inspect(h.get("Content-Type"), content="Some(\"application/json\")")
}

///|
test "build_headers multiple headers" {
  let h = build_headers([
    ("Content-Type", "application/json"),
    ("Authorization", "Bearer token"),
  ])
  inspect(h.get("Content-Type"), content="Some(\"application/json\")")
  inspect(h.get("Authorization"), content="Some(\"Bearer token\")")
}

///|
test "build_headers duplicate key uses last value" {
  let h = build_headers([("X-Key", "first"), ("X-Key", "second")])
  inspect(h.get("X-Key"), content="Some(\"second\")")
}

///|
test "compute_scheduled_time first request" {
  // Worker 0 of 2, rate=100 RPS → interval = 10000us per request per worker
  // First request: scheduled = epoch + 0 * 20000 + 0 * 10000 = epoch
  let scheduled = compute_scheduled_time(
    epoch_us=1000000L,
    request_index=0,
    rate=100,
    worker_id=0,
    num_workers=2,
  )
  inspect(scheduled, content="1000000")
}

///|
test "compute_scheduled_time second request" {
  // Worker 0 of 2, rate=100 → interval_per_request = 10000us
  // Each worker sends every 20000us (2 workers * 10000us)
  // Second request: epoch + 1 * 20000
  let scheduled = compute_scheduled_time(
    epoch_us=1000000L,
    request_index=1,
    rate=100,
    worker_id=0,
    num_workers=2,
  )
  inspect(scheduled, content="1020000")
}

///|
test "compute_scheduled_time worker offset" {
  // Worker 1 of 2 starts offset by 10000us from worker 0
  let scheduled = compute_scheduled_time(
    epoch_us=1000000L,
    request_index=0,
    rate=100,
    worker_id=1,
    num_workers=2,
  )
  inspect(scheduled, content="1010000")
}

///|
test "compute_corrected_latency with delay" {
  // Scheduled at t=0us, actually measured elapsed=5000us, but was delayed 3000us
  // Corrected = elapsed + delay = 5000 + 3000 = 8000
  let corrected = compute_corrected_latency(
    elapsed_us=5000L,
    scheduled_us=1000000L,
    actual_start_us=1003000L,
  )
  inspect(corrected, content="8000")
}

///|
test "compute_corrected_latency on time" {
  // Scheduled at t=0us, sent on time → no correction
  let corrected = compute_corrected_latency(
    elapsed_us=5000L,
    scheduled_us=1000000L,
    actual_start_us=1000000L,
  )
  inspect(corrected, content="5000")
}

///|
test "compute_corrected_latency early send" {
  // Sent before scheduled time (shouldn't happen but boundary)
  // actual_start < scheduled → delay is negative → just use elapsed
  let corrected = compute_corrected_latency(
    elapsed_us=5000L,
    scheduled_us=1000000L,
    actual_start_us=999000L,
  )
  // Should not go below elapsed
  inspect(corrected >= 5000L, content="true")
}

///|
test "compute_corrected_latency clamps negative to zero" {
  let corrected = compute_corrected_latency(
    elapsed_us=-100L,
    scheduled_us=1000L,
    actual_start_us=900L,
  )
  inspect(corrected >= 0L, content="true")
}

///|
test "compute_corrected_latency very large delay" {
  // Server was extremely slow, 10 second delay
  let corrected = compute_corrected_latency(
    elapsed_us=5000L,
    scheduled_us=0L,
    actual_start_us=10000000L,
  )
  inspect(corrected, content="10005000")
}

///|
test "compute_corrected_latency zero elapsed zero delay" {
  let corrected = compute_corrected_latency(
    elapsed_us=0L,
    scheduled_us=1000L,
    actual_start_us=1000L,
  )
  inspect(corrected, content="0")
}

///|
test "classify_error/timeout" {
  let err = classify_error("connection timeout exceeded")
  inspect(err, content="Timeout")
}

///|
test "classify_error/Timeout_uppercase" {
  let err = classify_error("Request Timeout")
  inspect(err, content="Timeout")
}

///|
test "classify_error/connection_refused" {
  let err = classify_error("connection refused")
  inspect(err, content="ConnectionRefused")
}

///|
test "classify_error/connection_reset" {
  let err = classify_error("connection reset by peer")
  inspect(err, content="ConnectionReset")
}

///|
test "classify_error/dns_error" {
  let err = classify_error("DNS resolution failed")
  inspect(err, content="DnsError")
}

///|
test "classify_error/dns_resolve" {
  let err = classify_error("failed to resolve hostname")
  inspect(err, content="DnsError")
}

///|
test "classify_error/tls_error" {
  let err = classify_error("TLS handshake failed")
  inspect(err, content="TlsError")
}

///|
test "classify_error/ssl_error" {
  let err = classify_error("SSL certificate error")
  inspect(err, content="TlsError")
}

///|
test "classify_error/other" {
  let err = classify_error("some unknown error")
  inspect(err, content="Other(\"some unknown error\")")
}

///|
test "compute_scheduled_time rate zero returns epoch" {
  let scheduled = compute_scheduled_time(
    epoch_us=1000000L,
    request_index=1,
    rate=0,
    worker_id=0,
    num_workers=2,
  )
  inspect(scheduled, content="1000000")
}

///|
test "compute_scheduled_time num_workers zero returns epoch" {
  let scheduled = compute_scheduled_time(
    epoch_us=1000000L,
    request_index=1,
    rate=100,
    worker_id=0,
    num_workers=0,
  )
  inspect(scheduled, content="1000000")
}

///|
test "compute_scheduled_time negative rate returns epoch" {
  let scheduled = compute_scheduled_time(
    epoch_us=1000000L,
    request_index=1,
    rate=-10,
    worker_id=0,
    num_workers=2,
  )
  inspect(scheduled, content="1000000")
}

///|
test "classify_error empty string" {
  let err = classify_error("")
  inspect(err is @types.RequestError::Other(_), content="true")
}
