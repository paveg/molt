///|
async fn main {
  let config = parse_args() catch {
    err => {
      println("Error: \{err}")
      return
    }
  }
  println("molt v0.1.0 -- MoonBit HTTP Load Tester\n")
  println("Target:       \{config.url}")
  println("Connections:  \{config.connections}")
  match config.mode {
    @types.TestMode::Duration(ms) => println("Duration:     \{ms / 1000}s")
    @types.TestMode::RequestCount(n) => println("Requests:     \{n}")
  }
  println("\nRunning...\n")
  let stats = @coordinator.run(config)
  let report = @reporter.report_text(stats)
  println(report)
}

///|
fn parse_args() -> @types.Config raise {
  let cmd = @argparse.Command(
    "molt",
    about="MoonBit HTTP Load Tester",
    version="0.1.0",
    options=[
      @argparse.OptionArg(
        "connections",
        short='c',
        long="connections",
        about="Number of concurrent connections",
        default_values=["50"],
      ),
      @argparse.OptionArg(
        "duration",
        short='d',
        long="duration",
        about="Test duration (e.g. 10s, 1m)",
      ),
      @argparse.OptionArg(
        "requests",
        short='n',
        long="requests",
        about="Total number of requests",
      ),
    ],
    positionals=[@argparse.PositionArg("url", about="Target URL")],
  )
  let argv = @env.args()
  let matches = cmd.parse(argv=argv[:])
  let url_values = matches.values.get("url")
  guard url_values is Some(urls) && urls.length() > 0 else {
    raise Failure::Failure("URL is required")
  }
  let url = url_values.unwrap()[0]
  let conn_str = match matches.values.get("connections") {
    Some(vals) => if vals.length() > 0 { vals[0] } else { "50" }
    None => "50"
  }
  let connections = try {
    @strconv.parse_int(conn_str)
  } catch {
    _ => 50
  }
  let duration_val = matches.values.get("duration")
  let requests_val = matches.values.get("requests")
  let mode : @types.TestMode = match (duration_val, requests_val) {
    (Some(_), Some(_)) =>
      raise Failure::Failure("Cannot specify both --duration and --requests")
    (Some(d), None) =>
      if d.length() > 0 {
        let ms = try {
          @duration.parse(d[0])
        } catch {
          _ => 10000
        }
        @types.TestMode::Duration(ms)
      } else {
        @types.TestMode::Duration(10000)
      }
    (None, Some(r)) =>
      if r.length() > 0 {
        let n = try {
          @strconv.parse_int(r[0])
        } catch {
          _ => raise Failure::Failure("Invalid request count")
        }
        @types.TestMode::RequestCount(n)
      } else {
        @types.TestMode::Duration(10000)
      }
    (None, None) => @types.TestMode::Duration(10000)
  }
  {
    url,
    connections,
    mode,
    method: @types.HttpMethod::Get,
    headers: [],
    body: None,
    timeout_ms: 30000,
    enable_tui: false,
    json_output: false,
    latency_correction: true,
  }
}
