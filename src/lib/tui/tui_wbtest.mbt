///|
test "new tui state has zero values" {
  let state = TuiState::new("https://example.com", 50, 10000)
  inspect(state.url, content="https://example.com")
  inspect(state.connections, content="50")
  inspect(state.duration_ms, content="10000")
  inspect(state.total_requests, content="0")
  inspect(state.successful, content="0")
  inspect(state.failed, content="0")
  inspect(state.current_rps, content="0")
  inspect(state.p50_us, content="0")
  inspect(state.p99_us, content="0")
}

///|
test "update state from collector snapshot" {
  let state = TuiState::new("https://example.com", 50, 10000)
  state.update(
    total_requests=100,
    successful=98,
    failed=2,
    elapsed_ms=1000.0,
    p50_us=5000L,
    p99_us=50000L,
  )
  inspect(state.total_requests, content="100")
  inspect(state.successful, content="98")
  inspect(state.failed, content="2")
  inspect(state.current_rps, content="100")
  inspect(state.p50_us, content="5000")
  inspect(state.p99_us, content="50000")
}

///|
test "rps calculation with zero elapsed time" {
  let state = TuiState::new("https://example.com", 50, 10000)
  state.update(
    total_requests=10,
    successful=10,
    failed=0,
    elapsed_ms=0.0,
    p50_us=1000L,
    p99_us=5000L,
  )
  inspect(state.current_rps, content="0")
}

///|
test "progress ratio for duration mode" {
  let state = TuiState::new("https://example.com", 50, 10000)
  state.update(
    total_requests=50,
    successful=50,
    failed=0,
    elapsed_ms=5000.0,
    p50_us=1000L,
    p99_us=5000L,
  )
  let ratio = state.progress_ratio()
  // 5000ms / 10000ms = 0.5
  inspect(ratio >= 0.49 && ratio <= 0.51, content="true")
}

///|
test "progress ratio clamped to 1.0" {
  let state = TuiState::new("https://example.com", 50, 10000)
  state.update(
    total_requests=100,
    successful=100,
    failed=0,
    elapsed_ms=15000.0,
    p50_us=1000L,
    p99_us=5000L,
  )
  let ratio = state.progress_ratio()
  inspect(ratio <= 1.0, content="true")
}

///|
test "format_latency_display microseconds to ms" {
  inspect(format_latency_display(0L), content="0.00ms")
  inspect(format_latency_display(500L), content="0.50ms")
  inspect(format_latency_display(1000L), content="1.00ms")
  inspect(format_latency_display(12345L), content="12.34ms")
  inspect(format_latency_display(1000000L), content="1000.00ms")
}

///|
test "format_elapsed_display" {
  inspect(format_elapsed_display(0.0), content="0.0s")
  inspect(format_elapsed_display(1500.0), content="1.5s")
  inspect(format_elapsed_display(10000.0), content="10.0s")
  inspect(format_elapsed_display(65000.0), content="65.0s")
}

///|
test "render_tui produces output with key sections" {
  let state = TuiState::new("https://example.com", 50, 10000)
  state.update(
    total_requests=500,
    successful=495,
    failed=5,
    elapsed_ms=5000.0,
    p50_us=12000L,
    p99_us=50000L,
  )
  let output = render_tui_to_string(state, 80, 20)
  // Should contain key information
  inspect(output.contains("example.com"), content="true")
  inspect(output.contains("500"), content="true")
}

///|
test "format_plain_status one-liner" {
  let state = TuiState::new("https://example.com", 50, 10000)
  state.update(
    total_requests=2500,
    successful=2498,
    failed=2,
    elapsed_ms=5000.0,
    p50_us=12000L,
    p99_us=67000L,
  )
  let line = format_plain_status(state)
  inspect(line.contains("[5.0s]"), content="true")
  inspect(line.contains("2500 requests"), content="true")
  inspect(line.contains("500 req/s"), content="true")
  inspect(line.contains("p50: 12.00ms"), content="true")
  inspect(line.contains("p99: 67.00ms"), content="true")
  inspect(line.contains("errors: 2"), content="true")
}

///|
test "format_plain_status at zero state" {
  let state = TuiState::new("https://example.com", 50, 10000)
  let line = format_plain_status(state)
  inspect(line.contains("[0.0s]"), content="true")
  inspect(line.contains("0 requests"), content="true")
  inspect(line.contains("0 req/s"), content="true")
  inspect(line.contains("errors: 0"), content="true")
}

///|
test "progress_ratio with zero duration" {
  let state = TuiState::new("https://example.com", 50, 0)
  inspect(state.progress_ratio(), content="0")
}

///|
test "render_tui with zero state" {
  let state = TuiState::new("https://example.com", 10, 5000)
  let output = render_tui_to_string(state, 80, 20)
  // Should still render without crashing
  inspect(output.contains("molt"), content="true")
  inspect(output.contains("10"), content="true")
}
