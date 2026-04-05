///|
async fn main {
  let config = parse_args() catch {
    err => {
      println("Error: \{err}")
      @sys.exit(1)
      panic()
    }
  }
  if not(config.json_output) && not(config.enable_tui) {
    println("molt v0.1.0 -- MoonBit HTTP Load Tester\n")
    println("Target:       \{config.url}")
    println("Method:       \{config.http_method}")
    println("Connections:  \{config.connections}")
    match config.mode {
      @types.TestMode::Duration(ms) => println("Duration:     \{ms / 1000}s")
      @types.TestMode::RequestCount(n) => println("Requests:     \{n}")
    }
    match config.rate {
      Some(r) => println("Rate limit:   \{r} req/s")
      None => ()
    }
    println("\nRunning...\n")
  }
  // Set up TUI callbacks
  let tui_callbacks : @coordinator.TuiCallbacks? = if config.enable_tui {
    let (width, height) = @io.get_terminal_size()
    let app = @vnode.VNodeApp::new(width, height)
    Some({
      on_init: fn() { @io.print_raw(@vnode.VNodeApp::init_terminal()) },
      on_update: fn(state) {
        let node = @tui.render_tui_node(state)
        @io.print_raw(app.render(node))
      },
      on_cleanup: fn() { @io.print_raw(@vnode.VNodeApp::restore_terminal()) },
    })
  } else if not(config.json_output) {
    // Plain mode: print one-line status
    Some({
      on_init: fn() {  },
      on_update: fn(state) { println(@tui.format_plain_status(state)) },
      on_cleanup: fn() {  },
    })
  } else {
    None
  }
  let stats = @coordinator.run(config, tui_callbacks~)
  if config.json_output {
    println(@reporter.report_json(config, stats))
  } else {
    println(@reporter.report_text(stats))
  }
  let threshold_result = @threshold.check(stats, config)
  if not(threshold_result.passed) {
    for v in threshold_result.violations {
      println("THRESHOLD VIOLATION: \{v}")
    }
    @sys.exit(3)
    panic()
  }
  if stats.failed > 0 {
    @sys.exit(2)
  }
}

///|
fn parse_comma_separated(s : String) -> Array[String] {
  let result : Array[String] = []
  let buf = StringBuilder::new()
  for c in s {
    if c == ',' {
      let part = buf.to_string()
      if part.length() > 0 {
        result.push(part)
      }
      buf.reset()
    } else if c != ' ' {
      buf.write_char(c)
    }
  }
  let last = buf.to_string()
  if last.length() > 0 {
    result.push(last)
  }
  result
}

///|
fn get_option_value(
  matches : @argparse.Matches,
  key : String,
  default : String,
) -> String {
  match matches.values.get(key) {
    Some(vals) => if vals.length() > 0 { vals[0] } else { default }
    None => default
  }
}

///|
fn get_option_value_opt(matches : @argparse.Matches, key : String) -> String? {
  match matches.values.get(key) {
    Some(vals) => if vals.length() > 0 { Some(vals[0]) } else { None }
    None => None
  }
}

///|
fn get_flag(matches : @argparse.Matches, key : String) -> Bool {
  match matches.flags.get(key) {
    Some(v) => v
    None => false
  }
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
      @argparse.OptionArg(
        "method",
        short='m',
        long="method",
        about="HTTP method (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS)",
        default_values=["GET"],
      ),
      @argparse.OptionArg(
        "header",
        short='H',
        long="header",
        about="Custom header (e.g. 'Content-Type: application/json')",
        action=@argparse.Append,
      ),
      @argparse.OptionArg(
        "body",
        short='b',
        long="body",
        about="Request body string",
      ),
      @argparse.OptionArg(
        "body-file",
        short='B',
        long="body-file",
        about="Request body from file path",
      ),
      @argparse.OptionArg(
        "rate",
        short='r',
        long="rate",
        about="Target requests per second",
      ),
      @argparse.OptionArg(
        "timeout",
        short='t',
        long="timeout",
        about="Per-request timeout (e.g. 5s, 30s)",
        default_values=["30s"],
      ),
      @argparse.OptionArg(
        "percentiles",
        long="percentiles",
        about="Custom percentiles to compute (comma-separated, e.g. 50,90,99,99.99)",
      ),
      @argparse.OptionArg(
        "latency-threshold",
        long="latency-threshold",
        about="Fail if p99 > value (e.g. 100ms)",
      ),
      @argparse.OptionArg(
        "error-threshold",
        long="error-threshold",
        about="Fail if error rate > percentage (e.g. 1.0)",
      ),
      @argparse.OptionArg(
        "warm-up",
        long="warm-up",
        about="Warm-up duration excluded from stats (e.g. 3s)",
      ),
      @argparse.OptionArg(
        "auth",
        long="auth",
        about="Basic auth credentials (user:password)",
      ),
    ],
    flags=[
      @argparse.FlagArg(
        "no-tui",
        long="no-tui",
        about="Disable TUI, use plain output",
      ),
      @argparse.FlagArg(
        "json",
        short='j',
        long="json",
        about="Output results as JSON",
      ),
      @argparse.FlagArg(
        "insecure",
        short='k',
        long="insecure",
        about="Skip TLS certificate verification",
      ),
    ],
    positionals=[@argparse.PositionArg("url", about="Target URL")],
  )
  let argv = @env.args()
  // argv[0] is the program name; argparse expects only the arguments
  let args = if argv.length() > 1 { argv[1:] } else { [][:] }
  let matches = cmd.parse(argv=args)
  let url = match get_option_value_opt(matches, "url") {
    Some(u) => u
    None => raise Failure::Failure("URL is required")
  }
  let conn_str = get_option_value(matches, "connections", "50")
  let connections = @strconv.parse_int(conn_str) catch { _ => 50 }
  if connections <= 0 {
    raise Failure::Failure("--connections must be a positive integer")
  }
  let duration_val = get_option_value_opt(matches, "duration")
  let requests_val = get_option_value_opt(matches, "requests")
  let mode : @types.TestMode = match (duration_val, requests_val) {
    (Some(_), Some(_)) =>
      raise Failure::Failure("Cannot specify both --duration and --requests")
    (Some(d), None) => {
      let ms = @duration.parse(d) catch { _ => 10000 }
      @types.TestMode::Duration(ms)
    }
    (None, Some(r)) => {
      let n = @strconv.parse_int(r) catch {
        _ => raise Failure::Failure("Invalid request count")
      }
      @types.TestMode::RequestCount(n)
    }
    (None, None) => @types.TestMode::Duration(10000)
  }
  let method_str = get_option_value(matches, "method", "GET")
  let http_method = match method_str.to_upper() {
    "GET" => @types.HttpMethod::Get
    "POST" => @types.HttpMethod::Post
    "PUT" => @types.HttpMethod::Put
    "DELETE" => @types.HttpMethod::Delete
    "PATCH" => @types.HttpMethod::Patch
    "HEAD" => @types.HttpMethod::Head
    "OPTIONS" => @types.HttpMethod::Options
    _ => @types.HttpMethod::Get
  }
  let header_vals = match matches.values.get("header") {
    Some(vals) => vals
    None => []
  }
  let headers : Array[(String, String)] = []
  for h in header_vals {
    match @types.parse_header(h) {
      Some(pair) => headers.push(pair)
      None => ()
    }
  }
  let body_val = get_option_value_opt(matches, "body")
  let body_file_val = get_option_value_opt(matches, "body-file")
  let body : String? = match (body_val, body_file_val) {
    (Some(_), Some(_)) =>
      raise Failure::Failure("Cannot specify both --body and --body-file")
    (Some(b), None) => Some(b)
    (None, Some(path)) => {
      let content = @fs.read_file_to_string(path) catch {
        _ => raise Failure::Failure("Failed to read body file: \{path}")
      }
      Some(content)
    }
    (None, None) => None
  }
  let rate : Int? = match get_option_value_opt(matches, "rate") {
    Some(s) => {
      let r = @strconv.parse_int(s) catch {
        _ => raise Failure::Failure("Invalid rate value")
      }
      if r <= 0 {
        raise Failure::Failure("--rate must be a positive integer")
      }
      Some(r)
    }
    None => None
  }
  let timeout_str = get_option_value(matches, "timeout", "30s")
  let timeout_ms = @duration.parse(timeout_str) catch { _ => 30000 }
  let no_tui = get_flag(matches, "no-tui")
  let json_output = get_flag(matches, "json")
  let percentiles_val = get_option_value_opt(matches, "percentiles")
  let percentiles : Array[Double] = match percentiles_val {
    Some(s) => {
      let parts = parse_comma_separated(s)
      let result : Array[Double] = []
      for p in parts {
        let v = @strconv.parse_double(p) catch {
          _ => raise Failure::Failure("Invalid percentile value: \{p}")
        }
        if v < 0.0 || v > 100.0 {
          raise Failure::Failure("Percentile must be between 0 and 100: \{p}")
        }
        result.push(v)
      }
      result
    }
    None => [50.0, 75.0, 90.0, 95.0, 99.0, 99.9]
  }
  let latency_threshold_us : Int64? = match
    get_option_value_opt(matches, "latency-threshold") {
    Some(s) => {
      let ms = @duration.parse(s) catch {
        _ => raise Failure::Failure("Invalid latency threshold")
      }
      Some((ms * 1000).to_int64())
    }
    None => None
  }
  let error_threshold_pct : Double? = match
    get_option_value_opt(matches, "error-threshold") {
    Some(s) =>
      Some(
        @strconv.parse_double(s) catch {
          _ => raise Failure::Failure("Invalid error threshold")
        },
      )
    None => None
  }
  let warm_up_ms = match get_option_value_opt(matches, "warm-up") {
    Some(s) => @duration.parse(s) catch { _ => 0 }
    None => 0
  }
  match get_option_value_opt(matches, "auth") {
    Some(creds) => {
      if not(creds.contains(":")) {
        raise Failure::Failure("--auth must be in user:password format")
      }
      let encoded = @types.base64_encode(creds)
      headers.push(("Authorization", "Basic \{encoded}"))
    }
    None => ()
  }
  let insecure = get_flag(matches, "insecure")
  {
    url,
    connections,
    mode,
    http_method,
    headers,
    body,
    timeout_ms,
    enable_tui: not(no_tui) && not(json_output),
    json_output,
    latency_correction: true,
    rate,
    percentiles,
    latency_threshold_us,
    error_threshold_pct,
    warm_up_ms,
    insecure,
  }
}
