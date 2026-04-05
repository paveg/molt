///|
pub let csv_header : String = "latency_us,status_code,error,response_size_bytes"

///|
pub fn format_csv_row(result : @types.RequestResult) -> String {
  let error_str = match result.error {
    Some(err) => err.to_string()
    None => ""
  }
  "\{result.latency_us},\{result.status_code},\{error_str},\{result.response_size_bytes}"
}

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
fn json_escape(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
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

///|
fn write_json_lat_field(
  buf : StringBuilder,
  name : String,
  us : Int64,
  trailing_comma : Bool,
) -> Unit {
  let comma = if trailing_comma { "," } else { "" }
  buf.write_string("    \"\{name}\": \{us_to_ms_str(us)}\{comma}\n")
}

///|
fn write_json_latency_section(
  buf : StringBuilder,
  name : String,
  lat : @types.LatencyStats,
) -> Unit {
  buf.write_string("  \"\{name}\": {\n")
  write_json_lat_field(buf, "p50_ms", lat.p50_us, true)
  write_json_lat_field(buf, "p75_ms", lat.p75_us, true)
  write_json_lat_field(buf, "p90_ms", lat.p90_us, true)
  write_json_lat_field(buf, "p95_ms", lat.p95_us, true)
  write_json_lat_field(buf, "p99_ms", lat.p99_us, true)
  write_json_lat_field(buf, "p99_9_ms", lat.p99_9_us, true)
  write_json_lat_field(buf, "max_ms", lat.max_us, true)
  write_json_lat_field(buf, "min_ms", lat.min_us, true)
  buf.write_string("    \"mean_ms\": \{format_double(lat.mean_us / 1000.0)},\n")
  buf.write_string(
    "    \"stdev_ms\": \{format_double(lat.stdev_us / 1000.0)}\n",
  )
  buf.write_string("  },\n")
}

///|
pub fn report_json(config : @types.Config, stats : @types.Stats) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{\n")
  // "config" section
  buf.write_string("  \"config\": {\n")
  buf.write_string("    \"url\": \"\{json_escape(config.url)}\",\n")
  buf.write_string("    \"connections\": \{config.connections},\n")
  let duration_sec = match config.mode {
    @types.TestMode::Duration(ms) => ms.to_double() / 1000.0
    @types.TestMode::RequestCount(_) => 0.0
  }
  buf.write_string("    \"duration_sec\": \{format_double(duration_sec)},\n")
  let rate_str = match config.rate {
    Some(r) => r.to_string()
    None => "null"
  }
  buf.write_string("    \"rate_rps\": \{rate_str},\n")
  buf.write_string("    \"timeout_ms\": \{config.timeout_ms},\n")
  buf.write_string(
    "    \"method\": \"\{method_to_string(config.http_method)}\"\n",
  )
  buf.write_string("  },\n")
  // "summary" section
  buf.write_string("  \"summary\": {\n")
  buf.write_string("    \"total_requests\": \{stats.total_requests},\n")
  buf.write_string("    \"successful\": \{stats.successful},\n")
  buf.write_string("    \"failed\": \{stats.failed},\n")
  buf.write_string(
    "    \"total_time_sec\": \{format_double(stats.total_time_ms / 1000.0)},\n",
  )
  buf.write_string(
    "    \"requests_per_sec\": \{format_double(stats.requests_per_sec)}\n",
  )
  buf.write_string("  },\n")
  // "latency" section
  write_json_latency_section(buf, "latency", stats.latency)
  // "ttfb" section
  write_json_latency_section(buf, "ttfb", stats.ttfb)
  // "status_codes" section
  buf.write_string("  \"status_codes\": {")
  let mut first = true
  for code, count in stats.status_codes {
    if not(first) {
      buf.write_string(",")
    }
    buf.write_string("\n    \"\{code}\": \{count}")
    first = false
  }
  buf.write_string("\n  },\n")
  // "errors" section
  buf.write_string("  \"errors\": {")
  first = true
  for err_type, count in stats.errors {
    if not(first) {
      buf.write_string(",")
    }
    buf.write_string("\n    \"\{json_escape(err_type)}\": \{count}")
    first = false
  }
  buf.write_string("\n  },\n")
  // "custom_percentiles" section
  buf.write_string("  \"custom_percentiles\": {")
  first = true
  for pair in stats.custom_percentiles {
    if not(first) {
      buf.write_string(",")
    }
    let (p, v) = pair
    buf.write_string("\n    \"p\{format_double(p)}_ms\": \{us_to_ms_str(v)}")
    first = false
  }
  buf.write_string("\n  },\n")
  // "throughput" section
  buf.write_string("  \"throughput\": {\n")
  buf.write_string("    \"total_bytes\": \{stats.total_bytes},\n")
  buf.write_string(
    "    \"bytes_per_sec\": \{format_double(stats.bytes_per_sec)}\n",
  )
  buf.write_string("  },\n")
  // "time_series" section
  buf.write_string("  \"time_series\": [")
  first = true
  for point in stats.time_series {
    if not(first) {
      buf.write_string(",")
    }
    buf.write_string("\n    {")
    buf.write_string("\"elapsed_sec\": \{format_double(point.elapsed_sec)}, ")
    buf.write_string("\"requests\": \{point.requests}, ")
    buf.write_string("\"rps\": \{format_double(point.rps)}, ")
    buf.write_string("\"p50_ms\": \{us_to_ms_str(point.p50_us)}, ")
    buf.write_string("\"p99_ms\": \{us_to_ms_str(point.p99_us)}, ")
    buf.write_string("\"errors\": \{point.errors}}")
    first = false
  }
  buf.write_string("\n  ]\n")
  buf.write_string("}")
  buf.to_string()
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
  buf.write_string(
    "  Requests/sec:      \{format_rps(stats.requests_per_sec)}\n",
  )
  buf.write_string("\n")
  buf.write_string("Latency Distribution:\n")
  if stats.custom_percentiles.length() > 0 {
    for pair in stats.custom_percentiles {
      let (p, v) = pair
      let label = "p\{format_double(p)}"
      buf.write_string("  \{label}  \{format_us_as_ms(v)}\n")
    }
  } else {
    let lat = stats.latency
    buf.write_string("  p50     \{format_us_as_ms(lat.p50_us)}\n")
    buf.write_string("  p75     \{format_us_as_ms(lat.p75_us)}\n")
    buf.write_string("  p90     \{format_us_as_ms(lat.p90_us)}\n")
    buf.write_string("  p95     \{format_us_as_ms(lat.p95_us)}\n")
    buf.write_string("  p99     \{format_us_as_ms(lat.p99_us)}\n")
    buf.write_string("  p99.9   \{format_us_as_ms(lat.p99_9_us)}\n")
  }
  let lat = stats.latency
  buf.write_string("  max     \{format_us_as_ms(lat.max_us)}\n")
  buf.write_string("\n")
  buf.write_string("  mean    \{format_us_as_ms(lat.mean_us.to_int64())}\n")
  buf.write_string("  stdev   \{format_us_as_ms(lat.stdev_us.to_int64())}\n")
  if stats.ttfb.max_us > 0L {
    buf.write_string("\nTTFB (Time to First Byte):\n")
    let ttfb = stats.ttfb
    buf.write_string("  p50     \{format_us_as_ms(ttfb.p50_us)}\n")
    buf.write_string("  p99     \{format_us_as_ms(ttfb.p99_us)}\n")
    buf.write_string("  max     \{format_us_as_ms(ttfb.max_us)}\n")
    buf.write_string("  mean    \{format_us_as_ms(ttfb.mean_us.to_int64())}\n")
  }
  if stats.total_bytes > 0L {
    buf.write_string("\n")
    buf.write_string("Throughput:\n")
    buf.write_string("  Total:      \{stats.total_bytes} bytes\n")
    buf.write_string("  Bytes/sec:  \{format_double(stats.bytes_per_sec)}\n")
  }
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
