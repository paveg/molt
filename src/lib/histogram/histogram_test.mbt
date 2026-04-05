///|
test "percentile with uniform distribution" {
  let h = @histogram.Histogram::new(100000L, 3)
  for i in 1..<=1000 {
    h.record(i.to_int64())
  }
  let p50 = h.percentile(50.0)
  let p99 = h.percentile(99.0)
  inspect(p50 >= 495L && p50 <= 505L, content="true")
  inspect(p99 >= 985L && p99 <= 995L, content="true")
}

///|
test "percentile with single value" {
  let h = @histogram.Histogram::new(100000L, 3)
  h.record(42L)
  inspect(h.percentile(50.0), content="42")
  inspect(h.percentile(99.0), content="42")
  inspect(h.percentile(99.9), content="42")
}

///|
test "percentile with identical values" {
  let h = @histogram.Histogram::new(100000L, 3)
  for _ in 0..<1000 {
    h.record(500L)
  }
  inspect(h.percentile(50.0), content="500")
  inspect(h.percentile(99.0), content="500")
}

///|
test "mean and stdev" {
  let h = @histogram.Histogram::new(100000L, 3)
  for i in 1..<=100 {
    h.record(i.to_int64())
  }
  let mean = h.mean()
  inspect(mean >= 50.0 && mean <= 51.0, content="true")
  let sd = h.stdev()
  inspect(sd >= 28.0 && sd <= 30.0, content="true")
}

///|
test "min and max" {
  let h = @histogram.Histogram::new(3600000000L, 3)
  h.record(10L)
  h.record(50000L)
  h.record(1000000L)
  inspect(h.min(), content="10")
  inspect(h.max(), content="1000000")
}

///|
test "empty histogram" {
  let h = @histogram.Histogram::new(100000L, 3)
  inspect(h.percentile(50.0), content="0")
  inspect(h.mean(), content="0")
  inspect(h.stdev(), content="0")
  inspect(h.total_count(), content="0")
}

///|
test "reset clears all data" {
  let h = @histogram.Histogram::new(100000L, 3)
  h.record(100L)
  h.record(200L)
  h.reset()
  inspect(h.total_count(), content="0")
  inspect(h.percentile(50.0), content="0")
}

///|
test "large values within range" {
  let h = @histogram.Histogram::new(3600000000L, 3)
  h.record(1L)
  h.record(1000000L)
  h.record(3000000000L)
  inspect(h.total_count(), content="3")
  inspect(h.min(), content="1")
  inspect(h.max(), content="3000000000")
}

///|
test "percentile 0 returns min" {
  let h = @histogram.Histogram::new(100000L, 3)
  for i in 1..<=100 {
    h.record(i.to_int64())
  }
  let p0 = h.percentile(0.0)
  // p0 should be the smallest value or close to it
  inspect(p0 >= 0L && p0 <= 2L, content="true")
}

///|
test "percentile 100 returns max" {
  let h = @histogram.Histogram::new(100000L, 3)
  for i in 1..<=100 {
    h.record(i.to_int64())
  }
  let p100 = h.percentile(100.0)
  inspect(p100, content="100")
}

///|
test "record zero value from blackbox" {
  let h = @histogram.Histogram::new(100000L, 3)
  h.record(0L)
  inspect(h.total_count(), content="1")
  inspect(h.min(), content="0")
  inspect(h.max(), content="0")
}
