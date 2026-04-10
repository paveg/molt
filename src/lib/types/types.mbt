///|
pub(all) enum TestMode {
  Duration(Int)
  RequestCount(Int)
} derive(Show, Eq)

///|
pub(all) enum HttpMethod {
  Get
  Post
  Put
  Delete
  Patch
  Head
  Options
} derive(Show, Eq)

///|
pub(all) struct Config {
  url : String
  connections : Int
  mode : TestMode
  http_method : HttpMethod
  headers : Array[(String, String)]
  body : String?
  timeout_ms : Int
  enable_tui : Bool
  json_output : Bool
  latency_correction : Bool
  rate : Int? // target RPS, None = unlimited
  percentiles : Array[Double]
  latency_threshold_us : Int64?
  error_threshold_pct : Double?
  warm_up_ms : Int
  insecure : Bool
  disable_keepalive : Bool
  debug : Bool
  csv_output : Bool
  max_redirects : Int
  serve_addr : String?
  compression : Bool
} derive(Show)

///|
pub fn Config::default_with_url(url : String) -> Config {
  {
    url,
    connections: 50,
    mode: Duration(10000),
    http_method: Get,
    headers: [],
    body: None,
    timeout_ms: 30000,
    enable_tui: true,
    json_output: false,
    latency_correction: true,
    rate: None,
    percentiles: [50.0, 75.0, 90.0, 95.0, 99.0, 99.9],
    latency_threshold_us: None,
    error_threshold_pct: None,
    warm_up_ms: 0,
    insecure: false,
    disable_keepalive: false,
    debug: false,
    csv_output: false,
    max_redirects: 0,
    serve_addr: None,
    compression: false,
  }
}

///|
pub(all) enum RequestError {
  Timeout
  ConnectionRefused
  ConnectionReset
  DnsError
  TlsError
  Other(String)
} derive(Show, Eq)

///|
pub(all) struct RequestResult {
  status_code : Int
  latency_us : Int64
  ttfb_us : Int64 // Time to first byte (headers received, before body read)
  error : RequestError?
  scheduled_time_us : Int64 // 0 when not using rate limiting
  response_size_bytes : Int64 // 0 when error or unknown
} derive(Show)

///|
pub(all) struct LatencyStats {
  p50_us : Int64
  p75_us : Int64
  p90_us : Int64
  p95_us : Int64
  p99_us : Int64
  p99_9_us : Int64
  max_us : Int64
  min_us : Int64
  mean_us : Double
  stdev_us : Double
} derive(Show)

///|
pub(all) struct TimeSeriesPoint {
  elapsed_sec : Double
  requests : Int
  rps : Double
  p50_us : Int64
  p99_us : Int64
  errors : Int
} derive(Show)

///|
pub(all) struct Stats {
  total_requests : Int
  successful : Int
  failed : Int
  total_time_ms : Double
  requests_per_sec : Double
  latency : LatencyStats
  ttfb : LatencyStats
  status_codes : Map[Int, Int]
  errors : Map[String, Int]
  custom_percentiles : Array[(Double, Int64)]
  time_series : Array[TimeSeriesPoint]
  total_bytes : Int64
  bytes_per_sec : Double
} derive(Show)

///|
pub fn LatencyStats::new(
  p50_us~ : Int64,
  p75_us~ : Int64,
  p90_us~ : Int64,
  p95_us~ : Int64,
  p99_us~ : Int64,
  p99_9_us~ : Int64,
  max_us~ : Int64,
  min_us~ : Int64,
  mean_us~ : Double,
  stdev_us~ : Double,
) -> LatencyStats {
  {
    p50_us,
    p75_us,
    p90_us,
    p95_us,
    p99_us,
    p99_9_us,
    max_us,
    min_us,
    mean_us,
    stdev_us,
  }
}

///|
/// Parses a header string in "Key: Value" format.
/// Splits on the first ": " (colon followed by space).
/// Returns None if the format is invalid.
pub fn parse_header(h : String) -> (String, String)? {
  let mut colon_pos = -1
  for i, c in h {
    if c == ':' && i + 1 < h.length() && h[i + 1] == ' ' {
      colon_pos = i
      break
    }
  }
  if colon_pos >= 0 {
    let name = h[:colon_pos].to_string()
    let value = h[colon_pos + 2:].to_string()
    // Reject CRLF characters to prevent header injection
    for c in name {
      if c == '\r' || c == '\n' {
        return None
      }
    }
    for c in value {
      if c == '\r' || c == '\n' {
        return None
      }
    }
    Some((name, value))
  } else {
    None
  }
}

///|
pub fn Stats::new(
  total_requests~ : Int,
  successful~ : Int,
  failed~ : Int,
  total_time_ms~ : Double,
  requests_per_sec~ : Double,
  latency~ : LatencyStats,
  ttfb? : LatencyStats = {
    p50_us: 0L,
    p75_us: 0L,
    p90_us: 0L,
    p95_us: 0L,
    p99_us: 0L,
    p99_9_us: 0L,
    max_us: 0L,
    min_us: 0L,
    mean_us: 0.0,
    stdev_us: 0.0,
  },
  status_codes~ : Map[Int, Int],
  errors~ : Map[String, Int],
  custom_percentiles? : Array[(Double, Int64)] = [],
  time_series? : Array[TimeSeriesPoint] = [],
  total_bytes? : Int64 = 0L,
  bytes_per_sec? : Double = 0.0,
) -> Stats {
  {
    total_requests,
    successful,
    failed,
    total_time_ms,
    requests_per_sec,
    latency,
    ttfb,
    status_codes,
    errors,
    custom_percentiles,
    time_series,
    total_bytes,
    bytes_per_sec,
  }
}
