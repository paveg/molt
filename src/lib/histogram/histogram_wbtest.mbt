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
