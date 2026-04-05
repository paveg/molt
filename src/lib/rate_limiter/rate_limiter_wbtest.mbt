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
