///|
pub struct RateLimiter {
  priv rate : Int
  priv queue : @aqueue.Queue[Unit]
}

///|
pub fn RateLimiter::new(rate : Int) -> RateLimiter {
  let safe_rate = if rate < 1 { 1 } else { rate }
  { rate: safe_rate, queue: @aqueue.Queue::new(kind=DiscardLatest(100)) }
}

///|
/// Start the token filler task. Must be called inside a TaskGroup.
/// Uses absolute deadline scheduling (oha pattern) to prevent cumulative drift.
/// Tokens due by the current instant are emitted as a batch, so rates above
/// 1000 req/s work despite `@async.sleep` only having millisecond resolution.
pub fn RateLimiter::start(
  self : RateLimiter,
  group : @async.TaskGroup[Unit],
) -> Unit {
  if self.rate <= 0 {
    return
  }
  let rate = self.rate.to_int64()
  group.spawn_bg(no_wait=true, async fn() {
    let start = @async.now()
    let mut emitted = 0L
    while true {
      let elapsed = @async.now() - start
      // +1 seeds the first token at t=0 instead of after one interval
      let target = elapsed * rate / 1000L + 1L
      while emitted < target {
        self.queue.put(())
        emitted = emitted + 1L
      }
      // Earliest instant at which the next token becomes due
      let next_deadline = (emitted * 1000L + rate - 1L) / rate
      let wait = start + next_deadline - @async.now()
      if wait > 0L {
        @async.sleep(wait.to_int())
      } else {
        @async.pause()
      }
    }
  })
}

///|
/// Block until a token is available.
pub async fn RateLimiter::acquire(self : RateLimiter) -> Unit {
  self.queue.get()
}

///|
pub fn RateLimiter::rate(self : RateLimiter) -> Int {
  self.rate
}
