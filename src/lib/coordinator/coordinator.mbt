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
  tui_callbacks~ : TuiCallbacks? = None,
) -> @types.Stats {
  let collector = @collector.Collector::new()
  let mut stopped = false
  let start_time = @bench.monotonic_clock_start()
  let duration_ms = match config.mode {
    @types.TestMode::Duration(ms) => ms
    @types.TestMode::RequestCount(_) => 0
  }
  let tui_state = @tui.TuiState::new(config.url, config.connections, duration_ms)
  // Initialize TUI
  match tui_callbacks {
    Some(cb) => (cb.on_init)()
    None => ()
  }
  @async.with_task_group(async fn(group) {
    // TUI/plain update task
    match tui_callbacks {
      Some(cb) =>
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
      None => ()
    }
    // Spawn workers
    for _ in 0..<config.connections {
      group.spawn_bg(async fn() {
        @worker.run(config, fn(result) { collector.record(result) }, fn() {
          stopped
        })
      })
    }
    // Wait for termination condition
    match config.mode {
      @types.TestMode::Duration(ms) => @async.sleep(ms)
      @types.TestMode::RequestCount(n) => {
        while collector.total_requests() < n {
          @async.sleep(10)
        }
      }
    }
    stopped = true
  })
  // Cleanup TUI
  match tui_callbacks {
    Some(cb) => (cb.on_cleanup)()
    None => ()
  }
  let elapsed_ms = @bench.monotonic_clock_end(start_time) / 1000.0
  collector.finalize(elapsed_ms)
}
