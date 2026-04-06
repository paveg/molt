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
