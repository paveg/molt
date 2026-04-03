///|
fn format_us_as_ms(us : Int64) -> String {
  let ms_whole = us / 1000L
  let ms_frac = (us % 1000L) / 10L
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
  let frac = ((ms % 1000.0) / 10.0).to_int()
  "\{whole}.\{frac}s"
}

///|
pub fn report_text(stats : @types.Stats) -> String {
  let buf = StringBuilder::new()
  buf.write_string("Summary:\n")
  buf.write_string("  Total requests:    \{stats.total_requests}\n")
  buf.write_string(
    "  Successful:        \{stats.successful} (\{format_percentage(stats.successful, stats.total_requests)})\n",
  )
  buf.write_string(
    "  Failed:            \{stats.failed} (\{format_percentage(stats.failed, stats.total_requests)})\n",
  )
  buf.write_string("  Total time:        \{format_time(stats.total_time_ms)}\n")
  buf.write_string("  Requests/sec:      \{format_rps(stats.requests_per_sec)}\n")
  buf.write_string("\n")
  buf.write_string("Latency Distribution:\n")
  let lat = stats.latency
  buf.write_string("  p50     \{format_us_as_ms(lat.p50_us)}\n")
  buf.write_string("  p75     \{format_us_as_ms(lat.p75_us)}\n")
  buf.write_string("  p90     \{format_us_as_ms(lat.p90_us)}\n")
  buf.write_string("  p95     \{format_us_as_ms(lat.p95_us)}\n")
  buf.write_string("  p99     \{format_us_as_ms(lat.p99_us)}\n")
  buf.write_string("  p99.9   \{format_us_as_ms(lat.p99_9_us)}\n")
  buf.write_string("  max     \{format_us_as_ms(lat.max_us)}\n")
  buf.write_string("\n")
  buf.write_string("  mean    \{format_us_as_ms(lat.mean_us.to_int64())}\n")
  buf.write_string("  stdev   \{format_us_as_ms(lat.stdev_us.to_int64())}\n")
  buf.write_string("\n")
  buf.write_string("Status Codes:\n")
  for code, count in stats.status_codes {
    buf.write_string("  \{code}: \{count}\n")
  }
  if stats.errors.length() > 0 {
    buf.write_string("\nErrors:\n")
    for err_type, count in stats.errors {
      buf.write_string("  \{err_type}: \{count}\n")
    }
  }
  buf.to_string()
}
