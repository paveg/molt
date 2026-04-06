///|
pub struct Histogram {
  priv counts : Array[Int64]
  priv mut total_count : Int64
  priv mut min_value : Int64
  priv mut max_value : Int64
  priv sub_bucket_count : Int
  priv sub_bucket_half_count : Int
  priv sub_bucket_half_count_magnitude : Int
  priv sub_bucket_mask : Int64
  priv unit_magnitude : Int
  priv bucket_count : Int
  priv counts_len : Int
  priv mut sum : Double
  priv mut sum_of_squares : Double
  priv mut dropped_count : Int64
}

///|
fn clz64(value : Int64) -> Int {
  guard value != 0L else { return 64 }
  let mut n = 0
  let mut v = value
  if v.land(0xFFFFFFFF00000000L) == 0L {
    n = n + 32
    v = v << 32
  }
  if v.land(0xFFFF000000000000L) == 0L {
    n = n + 16
    v = v << 16
  }
  if v.land(0xFF00000000000000L) == 0L {
    n = n + 8
    v = v << 8
  }
  if v.land(0xF000000000000000L) == 0L {
    n = n + 4
    v = v << 4
  }
  if v.land(0xC000000000000000L) == 0L {
    n = n + 2
    v = v << 2
  }
  if v.land(0x8000000000000000L) == 0L {
    n = n + 1
  }
  n
}

///|
fn power_of_2(exp : Int) -> Int64 {
  1L << exp
}

///|
pub fn Histogram::new(
  highest_trackable : Int64,
  significant_figures : Int,
) -> Histogram {
  let highest = if highest_trackable < 1L { 1L } else { highest_trackable }
  let sig_figs = if significant_figures < 1 {
    1
  } else if significant_figures > 5 {
    5
  } else {
    significant_figures
  }
  let largest_value_with_single_unit_resolution = 2L *
    power_of_2(@math.ceil(sig_figs.to_double() / @math.log10(2.0)).to_int())
  let sub_bucket_count_magnitude = @math.ceil(
    @math.log2(largest_value_with_single_unit_resolution.to_double()),
  ).to_int()
  let sub_bucket_half_count_magnitude = if sub_bucket_count_magnitude > 1 {
    sub_bucket_count_magnitude - 1
  } else {
    0
  }
  let sub_bucket_count = 1 << sub_bucket_count_magnitude
  let sub_bucket_half_count = sub_bucket_count / 2
  let unit_magnitude = 0
  let sub_bucket_mask = (sub_bucket_count - 1).to_int64() << unit_magnitude
  let mut buckets = 1
  let mut smallest_untrackable = sub_bucket_count.to_int64() << unit_magnitude
  while smallest_untrackable <= highest {
    smallest_untrackable = smallest_untrackable << 1
    buckets = buckets + 1
  }
  let counts_len = (buckets + 1) * sub_bucket_half_count
  {
    counts: Array::make(counts_len, 0L),
    total_count: 0L,
    min_value: 0x7FFFFFFFFFFFFFFFL,
    max_value: 0L,
    sub_bucket_count,
    sub_bucket_half_count,
    sub_bucket_half_count_magnitude,
    sub_bucket_mask,
    unit_magnitude,
    bucket_count: buckets,
    counts_len,
    sum: 0.0,
    sum_of_squares: 0.0,
    dropped_count: 0L,
  }
}

///|
fn Histogram::counts_index(self : Histogram, bucket : Int, sub : Int) -> Int {
  (bucket + 1) * self.sub_bucket_half_count + sub - self.sub_bucket_half_count
}

///|
fn Histogram::get_bucket_index(self : Histogram, value : Int64) -> Int {
  let pow2ceiling = 64 - clz64(value.lor(self.sub_bucket_mask))
  pow2ceiling - self.unit_magnitude - (self.sub_bucket_half_count_magnitude + 1)
}

///|
fn Histogram::get_sub_bucket_index(
  self : Histogram,
  value : Int64,
  bucket : Int,
) -> Int {
  (value >> (bucket + self.unit_magnitude)).to_int()
}

///|
fn Histogram::value_from_index(
  self : Histogram,
  bucket : Int,
  sub : Int,
) -> Int64 {
  sub.to_int64() << (bucket + self.unit_magnitude)
}

///|
fn Histogram::update_stats(self : Histogram, v : Int64) -> Unit {
  self.total_count = self.total_count + 1L
  if v < self.min_value {
    self.min_value = v
  }
  if v > self.max_value {
    self.max_value = v
  }
  let fv = v.to_double()
  self.sum = self.sum + fv
  self.sum_of_squares = self.sum_of_squares + fv * fv
}

///|
pub fn Histogram::record(self : Histogram, value : Int64) -> Unit {
  let v = if value < 0L { 0L } else { value }
  let bucket = self.get_bucket_index(v)
  let sub = self.get_sub_bucket_index(v, bucket)
  let idx = self.counts_index(bucket, sub)
  if idx < 0 || idx >= self.counts_len {
    self.dropped_count = self.dropped_count + 1L
    self.update_stats(v)
    return
  }
  self.counts[idx] = self.counts[idx] + 1L
  self.update_stats(v)
}

///|
pub fn Histogram::percentile(self : Histogram, p : Double) -> Int64 {
  guard self.total_count > 0L else { return 0L }
  let target_count = (p / 100.0 * self.total_count.to_double() + 0.5).to_int64()
  let mut accumulated : Int64 = 0L
  for bucket in 0..<(self.bucket_count + 1) {
    let sub_start = if bucket == 0 { 0 } else { self.sub_bucket_half_count }
    for sub in sub_start..<self.sub_bucket_count {
      let idx = self.counts_index(bucket, sub)
      if idx >= self.counts_len {
        return self.max_value
      }
      accumulated = accumulated + self.counts[idx]
      if accumulated >= target_count {
        return self.value_from_index(bucket, sub)
      }
    }
  }
  self.max_value
}

///|
pub fn Histogram::mean(self : Histogram) -> Double {
  guard self.total_count > 0L else { return 0.0 }
  self.sum / self.total_count.to_double()
}

///|
pub fn Histogram::stdev(self : Histogram) -> Double {
  guard self.total_count > 1L else { return 0.0 }
  let n = self.total_count.to_double()
  let variance = (self.sum_of_squares - self.sum * self.sum / n) / (n - 1.0)
  if variance < 0.0 {
    0.0
  } else {
    variance.sqrt()
  }
}

///|
pub fn Histogram::min(self : Histogram) -> Int64 {
  guard self.total_count > 0L else { return 0L }
  self.min_value
}

///|
pub fn Histogram::max(self : Histogram) -> Int64 {
  self.max_value
}

///|
pub fn Histogram::total_count(self : Histogram) -> Int64 {
  self.total_count
}

///|
pub fn Histogram::dropped_count(self : Histogram) -> Int64 {
  self.dropped_count
}

///|
pub fn Histogram::reset(self : Histogram) -> Unit {
  for i in 0..<self.counts_len {
    self.counts[i] = 0L
  }
  self.total_count = 0L
  self.min_value = 0x7FFFFFFFFFFFFFFFL
  self.max_value = 0L
  self.sum = 0.0
  self.sum_of_squares = 0.0
  self.dropped_count = 0L
}
