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
