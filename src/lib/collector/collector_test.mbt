///|
test "collect single successful result" {
  let c = @collector.Collector::new()
  c.record({ status_code: 200, latency_us: 5000L, error: None })
  let stats = c.finalize(1000.0)
  inspect(stats.total_requests, content="1")
  inspect(stats.successful, content="1")
  inspect(stats.failed, content="0")
}

///|
test "collect mixed results" {
  let c = @collector.Collector::new()
  for _ in 0..<90 {
    c.record({ status_code: 200, latency_us: 1000L, error: None })
  }
  for _ in 0..<10 {
    c.record({ status_code: 500, latency_us: 5000L, error: None })
  }
  let stats = c.finalize(1000.0)
  inspect(stats.total_requests, content="100")
  inspect(stats.successful, content="100")
  inspect(stats.failed, content="0")
  inspect(stats.status_codes.get(200), content="Some(90)")
  inspect(stats.status_codes.get(500), content="Some(10)")
}

///|
test "collect error results" {
  let c = @collector.Collector::new()
  c.record({ status_code: 0, latency_us: 0L, error: Some(@types.RequestError::Timeout) })
  c.record({ status_code: 0, latency_us: 0L, error: Some(@types.RequestError::ConnectionRefused) })
  let stats = c.finalize(1000.0)
  inspect(stats.total_requests, content="2")
  inspect(stats.failed, content="2")
}

///|
test "latency stats are computed" {
  let c = @collector.Collector::new()
  for i in 1..=100 {
    c.record({ status_code: 200, latency_us: (i * 100).to_int64(), error: None })
  }
  let stats = c.finalize(1000.0)
  inspect(stats.latency.p50_us >= 4900L && stats.latency.p50_us <= 5100L, content="true")
  inspect(stats.latency.min_us, content="100")
  inspect(stats.latency.max_us, content="10000")
}
