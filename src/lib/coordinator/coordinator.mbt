///|
/// Callback interface for TUI updates during test execution.
pub(all) struct TuiCallbacks {
  on_update : (@tui.TuiState) -> Unit
  on_init : () -> Unit
  on_cleanup : () -> Unit
}

///|
pub async fn run(
  config : @types.Config,
  tui_callbacks? : TuiCallbacks? = None,
) -> @types.Stats {
  let collector = @collector.Collector::new()
  let time_series : Array[@types.TimeSeriesPoint] = []
  let mut stopped = false
  let mut start_time = @bench.monotonic_clock_start()
  let duration_ms = match config.mode {
    @types.TestMode::Duration(ms) => ms
    @types.TestMode::RequestCount(_) => 0
  }
  let tui_state = @tui.TuiState::new(
    config.url,
    config.connections,
    duration_ms,
  )
  if tui_callbacks is Some(cb) {
    (cb.on_init)()
  }
  @async.with_task_group(async fn(group) {
    // Set up rate limiter if configured
    let limiter : @rate_limiter.RateLimiter? = match config.rate {
      Some(rate) => {
        let rl = @rate_limiter.RateLimiter::new(rate)
        rl.start(group)
        Some(rl)
      }
      None => None
    }
    // Time-series capture task (every 1 second)
    group.spawn_bg(async fn() {
      let mut prev_requests = 0
      let mut prev_errors = 0
      while not(stopped) {
        @async.sleep(1000)
        if stopped {
          break
        }
        let elapsed = @bench.monotonic_clock_end(start_time) / 1000.0
        let elapsed_sec = elapsed / 1000.0
        let total = collector.total_requests()
        let failed = collector.failed_count()
        let interval_requests = total - prev_requests
        let interval_errors = failed - prev_errors
        let rps = interval_requests.to_double()
        time_series.push({
          elapsed_sec,
          requests: interval_requests,
          rps,
          p50_us: collector.live_percentile(50.0),
          p99_us: collector.live_percentile(99.0),
          errors: interval_errors,
        })
        prev_requests = total
        prev_errors = failed
      }
    })
    if tui_callbacks is Some(cb) {
      group.spawn_bg(async fn() {
        let interval = if config.enable_tui { 500 } else { 1000 }
        while not(stopped) {
          let elapsed = @bench.monotonic_clock_end(start_time) / 1000.0
          tui_state.update(
            total_requests=collector.total_requests(),
            successful=collector.total_requests() - collector.failed_count(),
            failed=collector.failed_count(),
            elapsed_ms=elapsed,
            p50_us=collector.live_percentile(50.0),
            p99_us=collector.live_percentile(99.0),
          )
          (cb.on_update)(tui_state)
          @async.sleep(interval)
        }
      })
    }
    // Spawn workers with CO correction support
    let num_workers = config.connections
    for i in 0..<num_workers {
      group.spawn_bg(async fn() {
        @worker.run(
          config,
          fn(result) { collector.record(result) },
          fn() { stopped },
          rate_limiter=limiter,
          worker_id=i,
          num_workers~,
        )
      })
    }
    // Warm-up phase: sleep then reset collector and start_time
    if config.warm_up_ms > 0 {
      @async.sleep(config.warm_up_ms)
      collector.reset()
      time_series.clear()
      start_time = @bench.monotonic_clock_start()
    }
    // Wait for termination condition
    match config.mode {
      @types.TestMode::Duration(ms) => @async.sleep(ms)
      @types.TestMode::RequestCount(n) =>
        while collector.total_requests() < n {
          @async.sleep(10)
        }
    }
    stopped = true
  })
  if tui_callbacks is Some(cb) {
    (cb.on_cleanup)()
  }
  let elapsed_ms = @bench.monotonic_clock_end(start_time) / 1000.0
  let stats = collector.finalize(elapsed_ms, percentiles=config.percentiles)
  // Attach time-series data
  { ..stats, time_series, }
}
