///|
pub struct Histogram {
  priv counts : Array[Int64]
  priv mut total_count : Int64
  priv mut min_value : Int64
  priv mut max_value : Int64
}

///|
pub fn Histogram::new(highest_trackable : Int64, significant_figures : Int) -> Histogram {
  abort("not implemented")
}
