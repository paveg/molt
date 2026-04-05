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

///|
test "new with zero highest_trackable clamps to 1" {
  let h = Histogram::new(0L, 3)
  h.record(0L)
  inspect(h.total_count, content="1")
}

///|
test "new with negative highest_trackable clamps to 1" {
  let h = Histogram::new(-100L, 3)
  h.record(0L)
  inspect(h.total_count, content="1")
}

///|
test "new with zero significant_figures clamps to 1" {
  let h = Histogram::new(100000L, 0)
  h.record(100L)
  inspect(h.total_count, content="1")
}

///|
test "new with negative significant_figures clamps to 1" {
  let h = Histogram::new(100000L, -5)
  h.record(100L)
  inspect(h.total_count, content="1")
}

///|
test "record negative value clamps to zero" {
  let h = Histogram::new(100000L, 3)
  h.record(-500L)
  inspect(h.total_count, content="1")
  inspect(h.min_value, content="0")
}

///|
test "record value exceeding range does not crash" {
  let h = Histogram::new(1000L, 3)
  h.record(999999999L)
  // Should not crash — either records in highest bucket or silently drops
  inspect(h.total_count >= 0L, content="true")
}

///|
test "record out of range tracks in dropped_count" {
  let h = Histogram::new(1000L, 3)
  h.record(999999L)
  inspect(h.dropped_count, content="1")
  inspect(h.total_count, content="1")
  inspect(h.max_value, content="999999")
}

///|
test "record out of range preserves mean" {
  let h = Histogram::new(1000L, 3)
  h.record(100L)
  h.record(999999L) // out of range
  inspect(h.total_count, content="2")
  // mean should include the out-of-range value
  inspect(h.mean() > 100.0, content="true")
}

///|
test "dropped_count cleared on reset" {
  let h = Histogram::new(1000L, 3)
  h.record(999999L)
  inspect(h.dropped_count > 0L, content="true")
  h.reset()
  inspect(h.dropped_count, content="0")
}
