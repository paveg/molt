///|
async fn main {
  let config = parse_args() catch {
    Failure::Failure(msg) => {
      println("Error: \{msg}")
      @sys.exit(1)
      panic()
    }
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
  let stats = @coordinator.run(config, tui_callbacks=tui_callbacks)
  if config.json_output {
    println(@reporter.report_json(config, stats))
  } else {
    println(@reporter.report_text(stats))
  }
  if stats.failed > 0 {
    @sys.exit(2)
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
        about="HTTP method (GET, POST, PUT, DELETE)",
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
    ],
    flags=[
      @argparse.FlagArg("no-tui", long="no-tui", about="Disable TUI, use plain output"),
      @argparse.FlagArg("json", short='j', long="json", about="Output results as JSON"),
    ],
    positionals=[@argparse.PositionArg("url", about="Target URL")],
  )
  let argv = @env.args()
  // argv[0] is the program name; argparse expects only the arguments
  let args = if argv.length() > 1 { argv[1:] } else { [][:] }
  let matches = cmd.parse(argv=args)
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
  // Parse HTTP method
  let method_str = match matches.values.get("method") {
    Some(vals) => if vals.length() > 0 { vals[0] } else { "GET" }
    None => "GET"
  }
  let http_method = match method_str.to_upper() {
    "GET" => @types.HttpMethod::Get
    "POST" => @types.HttpMethod::Post
    "PUT" => @types.HttpMethod::Put
    "DELETE" => @types.HttpMethod::Delete
    _ => @types.HttpMethod::Get
  }
  // Parse headers from -H "Key: Value" format
  let header_vals = match matches.values.get("header") {
    Some(vals) => vals
    None => []
  }
  let headers : Array[(String, String)] = []
  for h in header_vals {
    match @types.parse_header(h) {
      Some(pair) => headers.push(pair)
      None => () // silently skip malformed headers
    }
  }
  // Parse body (--body and --body-file are mutually exclusive)
  let body_val : String? = match matches.values.get("body") {
    Some(vals) => if vals.length() > 0 { Some(vals[0]) } else { None }
    None => None
  }
  let body_file_val : String? = match matches.values.get("body-file") {
    Some(vals) => if vals.length() > 0 { Some(vals[0]) } else { None }
    None => None
  }
  let body : String? = match (body_val, body_file_val) {
    (Some(_), Some(_)) =>
      raise Failure::Failure("Cannot specify both --body and --body-file")
    (Some(b), None) => Some(b)
    (None, Some(path)) => {
      let content = try {
        @fs.read_file_to_string(path)
      } catch {
        _ => raise Failure::Failure("Failed to read body file: \{path}")
      }
      Some(content)
    }
    (None, None) => None
  }
  // Parse rate
  let rate : Int? = match matches.values.get("rate") {
    Some(vals) =>
      if vals.length() > 0 {
        Some(
          try {
            @strconv.parse_int(vals[0])
          } catch {
            _ => raise Failure::Failure("Invalid rate value")
          },
        )
      } else {
        None
      }
    None => None
  }
  // Parse timeout
  let timeout_str = match matches.values.get("timeout") {
    Some(vals) => if vals.length() > 0 { vals[0] } else { "30s" }
    None => "30s"
  }
  let timeout_ms = try { @duration.parse(timeout_str) } catch { _ => 30000 }
  // Parse flags
  let no_tui = match matches.flags.get("no-tui") {
    Some(v) => v
    None => false
  }
  let json_output = match matches.flags.get("json") {
    Some(v) => v
    None => false
  }
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
  }
}
