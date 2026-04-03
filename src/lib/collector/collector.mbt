///|
pub struct Collector {
  priv mut total : Int
}

///|
pub fn Collector::new() -> Collector {
  { total: 0 }
}
