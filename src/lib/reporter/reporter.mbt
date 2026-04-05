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
  }
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
  match config.rate {
    Some(r) => buf.write_string("    \"rate_rps\": \{r},\n")
    None => buf.write_string("    \"rate_rps\": null,\n")
  }
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
  // "latency" section (convert us to ms)
  let lat = stats.latency
  buf.write_string("  \"latency\": {\n")
  buf.write_string(
    "    \"p50_ms\": \{format_double(lat.p50_us.to_double() / 1000.0)},\n",
  )
  buf.write_string(
    "    \"p75_ms\": \{format_double(lat.p75_us.to_double() / 1000.0)},\n",
  )
  buf.write_string(
    "    \"p90_ms\": \{format_double(lat.p90_us.to_double() / 1000.0)},\n",
  )
  buf.write_string(
    "    \"p95_ms\": \{format_double(lat.p95_us.to_double() / 1000.0)},\n",
  )
  buf.write_string(
    "    \"p99_ms\": \{format_double(lat.p99_us.to_double() / 1000.0)},\n",
  )
  buf.write_string(
    "    \"p99_9_ms\": \{format_double(lat.p99_9_us.to_double() / 1000.0)},\n",
  )
  buf.write_string(
    "    \"max_ms\": \{format_double(lat.max_us.to_double() / 1000.0)},\n",
  )
  buf.write_string(
    "    \"min_ms\": \{format_double(lat.min_us.to_double() / 1000.0)},\n",
  )
  buf.write_string("    \"mean_ms\": \{format_double(lat.mean_us / 1000.0)},\n")
  buf.write_string(
    "    \"stdev_ms\": \{format_double(lat.stdev_us / 1000.0)}\n",
  )
  buf.write_string("  },\n")
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
  buf.write_string("\n  }\n")
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
