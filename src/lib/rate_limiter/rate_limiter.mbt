///|
pub struct RateLimiter {
  priv rate : Int
  priv queue : @aqueue.Queue[Unit]
}

///|
pub fn RateLimiter::new(rate : Int) -> RateLimiter {
  { rate, queue: @aqueue.Queue::new(kind=Unbounded) }
}

///|
/// Start the token filler task. Must be called inside a TaskGroup.
/// Emits `rate` tokens per second at uniform intervals.
pub fn RateLimiter::start(self : RateLimiter, group : @async.TaskGroup[Unit]) -> Unit {
  if self.rate <= 0 {
    return
  }
  let interval_ms = if 1000 / self.rate < 1 { 1 } else { 1000 / self.rate }
  group.spawn_bg(async fn() {
    while true {
      self.queue.put(())
      @async.sleep(interval_ms)
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
