///|
fn format_us_as_ms(us : Int64) -> String {
  let ms_whole = us / 1000L
  let ms_frac = us % 1000L / 10L
  "\{ms_whole}.\{ms_frac}ms"
}

///|
fn format_percentage(part : Int, total : Int) -> String {
  guard total > 0 else { return "0.00%" }
  let pct = part.to_double() / total.to_double() * 100.0
  let whole = pct.to_int()
  let frac = ((pct - whole.to_double()) * 100.0).to_int()
  "\{whole}.\{frac}%"
}

///|
fn format_rps(rps : Double) -> String {
  let whole = rps.to_int()
  let frac = ((rps - whole.to_double()) * 100.0).to_int()
  "\{whole}.\{frac}"
}

///|
fn format_time(ms : Double) -> String {
  let whole = (ms / 1000.0).to_int()
  let frac = (ms % 1000.0 / 10.0).to_int()
  "\{whole}.\{frac}s"
}

///|
fn format_double(v : Double) -> String {
  let whole = v.to_int()
  let frac = ((v - whole.to_double()).abs() * 100.0 + 0.5).to_int()
  if frac >= 100 {
    "\{whole + 1}.00"
  } else {
    let frac_str = if frac < 10 { "0\{frac}" } else { "\{frac}" }
    "\{whole}.\{frac_str}"
  }
}

///|
fn method_to_string(http_method : @types.HttpMethod) -> String {
  match http_method {
    @types.HttpMethod::Get => "GET"
    @types.HttpMethod::Post => "POST"
    @types.HttpMethod::Put => "PUT"
    @types.HttpMethod::Delete => "DELETE"
    @types.HttpMethod::Patch => "PATCH"
    @types.HttpMethod::Head => "HEAD"
    @types.HttpMethod::Options => "OPTIONS"
  }
}

///|
fn us_to_ms_str(us : Int64) -> String {
  format_double(us.to_double() / 1000.0)
}
