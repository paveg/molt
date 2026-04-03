///|
test "new histogram has correct bucket count" {
  let h = Histogram::new(3600000000L, 3)
  inspect(h.sub_bucket_count, content="2048")
  inspect(h.total_count, content="0")
}

///|
test "record single value" {
  let h = Histogram::new(3600000000L, 3)
  h.record(1000L)
  inspect(h.total_count, content="1")
  inspect(h.min_value, content="1000")
  inspect(h.max_value, content="1000")
}

///|
test "record multiple values" {
  let h = Histogram::new(3600000000L, 3)
  h.record(100L)
  h.record(200L)
  h.record(300L)
  inspect(h.total_count, content="3")
  inspect(h.min_value, content="100")
  inspect(h.max_value, content="300")
}

///|
test "record zero value" {
  let h = Histogram::new(3600000000L, 3)
  h.record(0L)
  inspect(h.total_count, content="1")
  inspect(h.min_value, content="0")
}

///|
test "stdev with single value returns zero" {
  let h = Histogram::new(100000L, 3)
  h.record(500L)
  inspect(h.stdev(), content="0")
}

///|
test "stdev with two values" {
  let h = Histogram::new(100000L, 3)
  h.record(100L)
  h.record(200L)
  let sd = h.stdev()
  // stdev of [100, 200] with sample stdev = ~70.7
  inspect(sd > 60.0 && sd < 80.0, content="true")
}

///|
test "reset already empty histogram" {
  let h = Histogram::new(100000L, 3)
  h.reset()
  inspect(h.total_count, content="0")
  inspect(h.max_value, content="0")
}
