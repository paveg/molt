///|
test "new rate limiter has correct rate" {
  let rl = RateLimiter::new(100)
  inspect(rl.rate(), content="100")
}
