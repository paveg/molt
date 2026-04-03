///|
pub enum TestMode {
  Duration(Int)
  RequestCount(Int)
} derive(Show, Eq)

///|
pub enum HttpMethod {
  Get
  Post
  Put
  Delete
} derive(Show, Eq)

///|
pub struct Config {
  pub url : String
  pub connections : Int
  pub mode : TestMode
  pub method : HttpMethod
  pub headers : Array[(String, String)]
  pub body : String?
  pub timeout_ms : Int
  pub enable_tui : Bool
  pub json_output : Bool
  pub latency_correction : Bool
} derive(Show)

///|
pub fn Config::default_with_url(url : String) -> Config {
  {
    url,
    connections: 50,
    mode: Duration(10000),
    method: Get,
    headers: [],
    body: None,
    timeout_ms: 30000,
    enable_tui: true,
    json_output: false,
    latency_correction: true,
  }
}

///|
pub enum RequestError {
  Timeout
  ConnectionRefused
  ConnectionReset
  DnsError
  TlsError
  Other(String)
} derive(Show, Eq)

///|
pub struct RequestResult {
  pub status_code : Int
  pub latency_us : Int64
  pub error : RequestError?
} derive(Show)

///|
pub struct LatencyStats {
  pub p50_us : Int64
  pub p75_us : Int64
  pub p90_us : Int64
  pub p95_us : Int64
  pub p99_us : Int64
  pub p99_9_us : Int64
  pub max_us : Int64
  pub min_us : Int64
  pub mean_us : Double
  pub stdev_us : Double
} derive(Show)

///|
pub struct Stats {
  pub total_requests : Int
  pub successful : Int
  pub failed : Int
  pub total_time_ms : Double
  pub requests_per_sec : Double
  pub latency : LatencyStats
  pub status_codes : Map[Int, Int]
  pub errors : Map[String, Int]
} derive(Show)
