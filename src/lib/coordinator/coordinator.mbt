///|
pub async fn run(config : @types.Config) -> @types.Stats {
  let collector = @collector.Collector::new()
  let mut stopped = false
  let start_time = @bench.monotonic_clock_start()
  @async.with_task_group(async fn(group) {
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
  let elapsed_ms = @bench.monotonic_clock_end(start_time) / 1000.0
  collector.finalize(elapsed_ms)
}
