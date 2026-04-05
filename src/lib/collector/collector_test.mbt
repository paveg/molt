///|
test "collect single successful result" {
  let c = @collector.Collector::new()
  c.record({
    status_code: 200,
    latency_us: 5000L,
    error: None,
    scheduled_time_us: 0L,
  })
  let stats = c.finalize(1000.0)
  inspect(stats.total_requests, content="1")
  inspect(stats.successful, content="1")
  inspect(stats.failed, content="0")
}

///|
test "collect mixed results" {
  let c = @collector.Collector::new()
  for _ in 0..<90 {
    c.record({
      status_code: 200,
      latency_us: 1000L,
      error: None,
      scheduled_time_us: 0L,
    })
  }
  for _ in 0..<10 {
    c.record({
      status_code: 500,
      latency_us: 5000L,
      error: None,
      scheduled_time_us: 0L,
    })
  }
  let stats = c.finalize(1000.0)
  inspect(stats.total_requests, content="100")
  inspect(stats.successful, content="90")
  inspect(stats.failed, content="10")
  inspect(stats.status_codes.get(200), content="Some(90)")
  inspect(stats.status_codes.get(500), content="Some(10)")
}

///|
test "collect error results" {
  let c = @collector.Collector::new()
  c.record({
    status_code: 0,
    latency_us: 0L,
    error: Some(@types.RequestError::Timeout),
    scheduled_time_us: 0L,
  })
  c.record({
    status_code: 0,
    latency_us: 0L,
    error: Some(@types.RequestError::ConnectionRefused),
    scheduled_time_us: 0L,
  })
  let stats = c.finalize(1000.0)
  inspect(stats.total_requests, content="2")
  inspect(stats.failed, content="2")
}

///|
test "latency stats are computed" {
  let c = @collector.Collector::new()
  for i in 1..<=100 {
    c.record({
      status_code: 200,
      latency_us: (i * 100).to_int64(),
      error: None,
      scheduled_time_us: 0L,
    })
  }
  let stats = c.finalize(1000.0)
  inspect(
    stats.latency.p50_us >= 4900L && stats.latency.p50_us <= 5100L,
    content="true",
  )
  inspect(stats.latency.min_us, content="100")
  inspect(stats.latency.max_us, content="10000")
}

///|
test "finalize with zero time" {
  let c = @collector.Collector::new()
  c.record({
    status_code: 200,
    latency_us: 1000L,
    error: None,
    scheduled_time_us: 0L,
  })
  let stats = c.finalize(0.0)
  // RPS should be 0 when total_time is 0
  inspect(stats.requests_per_sec, content="0")
}

///|
test "all requests failed" {
  let c = @collector.Collector::new()
  for _ in 0..<5 {
    c.record({
      status_code: 0,
      latency_us: 0L,
      error: Some(@types.RequestError::Timeout),
      scheduled_time_us: 0L,
    })
  }
  let stats = c.finalize(1000.0)
  inspect(stats.total_requests, content="5")
  inspect(stats.failed, content="5")
  inspect(stats.successful, content="0")
}

///|
test "zero latency successful request" {
  let c = @collector.Collector::new()
  c.record({
    status_code: 200,
    latency_us: 0L,
    error: None,
    scheduled_time_us: 0L,
  })
  let stats = c.finalize(1000.0)
  inspect(stats.total_requests, content="1")
  inspect(stats.successful, content="1")
  inspect(stats.latency.min_us, content="0")
}

///|
test "multiple error types accumulated" {
  let c = @collector.Collector::new()
  c.record({
    status_code: 0,
    latency_us: 0L,
    error: Some(@types.RequestError::Timeout),
    scheduled_time_us: 0L,
  })
  c.record({
    status_code: 0,
    latency_us: 0L,
    error: Some(@types.RequestError::Timeout),
    scheduled_time_us: 0L,
  })
  c.record({
    status_code: 0,
    latency_us: 0L,
    error: Some(@types.RequestError::ConnectionReset),
    scheduled_time_us: 0L,
  })
  let stats = c.finalize(1000.0)
  inspect(stats.failed, content="3")
}

///|
test "coordinated omission correction uses scheduled_time" {
  // When scheduled_time_us > 0 and latency_correction is enabled,
  // the collector should record corrected_latency instead of raw latency.
  // corrected_latency = latency_us + (actual_start - scheduled_time)
  // But since the worker computes the full corrected value in latency_us
  // when CO is active, the collector just needs to record latency_us as-is.
  //
  // The real CO correction happens in the worker:
  //   scheduled_time = epoch + index * interval
  //   actual_start = now()
  //   response = send()
  //   elapsed = now() - actual_start
  //   corrected = elapsed + (actual_start - scheduled_time)  // includes wait
  //
  // The collector records whatever latency_us the worker provides.
  // With CO: latency_us = corrected (includes queue wait time)
  // Without CO: latency_us = raw elapsed
  let c = @collector.Collector::new()
  // Simulate: scheduled at t=0us, actually sent at t=5000us, response at t=10000us
  // Raw latency = 5000us, corrected latency = 10000us (includes 5000us queue wait)
  c.record({
    status_code: 200,
    latency_us: 10000L,
    error: None,
    scheduled_time_us: 0L,
  })
  // Simulate: scheduled at t=10000us, sent on time, response at t=15000us
  // Raw = corrected = 5000us
  c.record({
    status_code: 200,
    latency_us: 5000L,
    error: None,
    scheduled_time_us: 10000L,
  })
  let stats = c.finalize(1000.0)
  inspect(stats.total_requests, content="2")
  // p50 should be around 5000-10000 range
  inspect(stats.latency.min_us >= 5000L, content="true")
  inspect(stats.latency.max_us <= 10000L, content="true")
}

///|
test "scheduled_time_us zero means no correction" {
  let c = @collector.Collector::new()
  c.record({
    status_code: 200,
    latency_us: 1000L,
    error: None,
    scheduled_time_us: 0L,
  })
  c.record({
    status_code: 200,
    latency_us: 2000L,
    error: None,
    scheduled_time_us: 0L,
  })
  let stats = c.finalize(1000.0)
  inspect(stats.latency.min_us, content="1000")
  inspect(stats.latency.max_us, content="2000")
}

///|
test "5xx status codes counted as failed" {
  let c = @collector.Collector::new()
  c.record({
    status_code: 500,
    latency_us: 1000L,
    error: None,
    scheduled_time_us: 0L,
  })
  c.record({
    status_code: 503,
    latency_us: 1000L,
    error: None,
    scheduled_time_us: 0L,
  })
  c.record({
    status_code: 200,
    latency_us: 1000L,
    error: None,
    scheduled_time_us: 0L,
  })
  let stats = c.finalize(1000.0)
  inspect(stats.total_requests, content="3")
  inspect(stats.successful, content="1")
  inspect(stats.failed, content="2")
}

///|
test "499 is not counted as server error" {
  let c = @collector.Collector::new()
  c.record({
    status_code: 499,
    latency_us: 1000L,
    error: None,
    scheduled_time_us: 0L,
  })
  let stats = c.finalize(1000.0)
  inspect(stats.successful, content="1")
  inspect(stats.failed, content="0")
}

///|
test "500 boundary" {
  let c = @collector.Collector::new()
  c.record({
    status_code: 500,
    latency_us: 1000L,
    error: None,
    scheduled_time_us: 0L,
  })
  let stats = c.finalize(1000.0)
  inspect(stats.failed, content="1")
}

///|
test "empty collector finalize" {
  let c = @collector.Collector::new()
  let stats = c.finalize(1000.0)
  inspect(stats.total_requests, content="0")
  inspect(stats.successful, content="0")
  inspect(stats.failed, content="0")
  inspect(stats.requests_per_sec, content="0")
}
