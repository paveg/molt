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
    if !first {
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
    if !first {
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
    if !first {
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
    if !first {
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
