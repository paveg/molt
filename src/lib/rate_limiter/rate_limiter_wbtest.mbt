///|
test "new rate limiter has correct rate" {
  let rl = RateLimiter::new(100)
  inspect(rl.rate(), content="100")
}

///|
test "rate limiter with rate 1" {
  let rl = RateLimiter::new(1)
  inspect(rl.rate(), content="1")
}

///|
test "rate limiter with high rate" {
  let rl = RateLimiter::new(10000)
  inspect(rl.rate(), content="10000")
}

///|
test "rate limiter interval calculation" {
  // rate=100 → interval = 1000/100 = 10ms
  let rl = RateLimiter::new(100)
  // Can't directly test interval, but verify rate accessor
  inspect(rl.rate(), content="100")
}

///|
test "rate limiter with rate 1000" {
  // rate=1000 → interval = 1000/1000 = 1ms
  let rl = RateLimiter::new(1000)
  inspect(rl.rate(), content="1000")
}

///|
test "rate limiter with rate 5000 does not crash" {
  // rate=5000 → 1000/5000 = 0 via integer division, but clamped to 1ms
  let rl = RateLimiter::new(5000)
  inspect(rl.rate(), content="5000")
}

///|
test "rate limiter with rate 0 clamps to 1" {
  let rl = RateLimiter::new(0)
  inspect(rl.rate(), content="1")
}

///|
test "rate limiter negative rate clamps to 1" {
  let rl = RateLimiter::new(-5)
  inspect(rl.rate(), content="1")
}

///|
test "rate limiter with rate 1 interval" {
  // rate=1 → interval = 1000/1 = 1000ms
  let rl = RateLimiter::new(1)
  inspect(rl.rate(), content="1")
}

///|
test "rate accessor returns clamped value" {
  let rl = RateLimiter::new(500)
  inspect(rl.rate(), content="500")
}

///|
test "rate accessor after negative clamp" {
  let rl = RateLimiter::new(-10)
  inspect(rl.rate(), content="1")
}

///|
async test "rate above 1000 emits tokens faster than 1000 per second" {
  // 400 tokens at rate=4000 should take ~100ms. A filler capped at one
  // token per 1ms sleep tick needs >=400ms, so a 300ms bound separates
  // the two behaviors with margin for scheduler jitter.
  let rl = RateLimiter::new(4000)
  let start = @async.now()
  @async.with_task_group(async fn(group) {
    rl.start(group)
    for _ in 0..<400 {
      rl.acquire()
    }
  })
  let elapsed = @async.now() - start
  inspect(elapsed < 300L, content="true")
}

///|
async test "filler task does not block task group termination" {
  let completed = @async.with_timeout_opt(2000, async fn() {
    @async.with_task_group(async fn(group) {
      let rl = RateLimiter::new(100)
      rl.start(group)
      rl.acquire()
    })
  })
  inspect(completed is Some(_), content="true")
}
