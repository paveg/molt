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
pub fn RateLimiter::start(
  self : RateLimiter,
  group : @async.TaskGroup[Unit],
) -> Unit {
  if self.rate <= 0 {
    return
  }
  let interval_ms = if 1000 / self.rate < 1 { 1 } else { 1000 / self.rate }
  let interval_ms_i64 = interval_ms.to_int64()
  group.spawn_bg(async fn() {
    let start = @async.now()
    let mut token_index : Int64 = 0L
    while true {
      self.queue.put(())
      token_index = token_index + 1L
      let next_deadline = start + token_index * interval_ms_i64
      let now = @async.now()
      let wait = next_deadline - now
      if wait > 0L {
        @async.sleep(wait.to_int())
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
