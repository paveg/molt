///|
async fn main {
  let config = parse_args() catch {
    err => {
      println("Error: \{err}")
      @sys.exit(1)
      panic()
    }
  }
  // Serve mode: built-in test HTTP server
  match config.serve_addr {
    Some(addr) => {
      println("molt test server listening on \{addr}")
      println("Press Ctrl+C to stop\n")
      let server = @http.Server::new(@socket.Addr::parse(addr))
      server.run_forever(async fn(_request, body, conn) {
        // Drain request body
        while body.read_some() is Some(_) {

        }
        conn.send_response(200, "OK")
        conn.write("{\"status\":\"ok\"}")
      })
      return
    }
    None => ()
  }
  if config.debug {
    println("DEBUG: sending single request to \{config.url}\n")
    try {
      let (base_url, path) = @worker.parse_url(config.url)
      let client = @http.Client::new(base_url, verify=!config.insecure)
      let response = client.get(path)
      println("Status: \{response.code} \{response.reason}")
      println("Headers:")
      for k, v in response.headers {
        println("  \{k}: \{v}")
      }
      let data = (client : &@async_io.Reader).read_all()
      let body_str = data.text() catch { _ => "<binary or decode error>" }
      let preview = if body_str.length() > 500 {
        body_str[:500].to_string() + "..."
      } else {
        body_str
      }
      println("Body:\n\{preview}")
    } catch {
      err => {
        println("DEBUG request failed: \{err}")
        @sys.exit(1)
        panic()
      }
    }
    return
  }
  if !config.json_output && !config.enable_tui {
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
  } else if !config.json_output {
    // Plain mode: print one-line status
    Some({
      on_init: fn() {  },
      on_update: fn(state) { println(@tui.format_plain_status(state)) },
      on_cleanup: fn() {  },
    })
  } else {
    None
  }
  let csv_callback : ((@types.RequestResult) -> Unit)? = if config.csv_output {
    println(@reporter.csv_header)
    Some(fn(result) { println(@reporter.format_csv_row(result)) })
  } else {
    None
  }
  let stats = @coordinator.run(config, tui_callbacks~, on_result=csv_callback)
  if config.json_output {
    println(@reporter.report_json(config, stats))
  } else {
    println(@reporter.report_text(stats))
  }
  let threshold_result = @threshold.check(stats, config)
  if !threshold_result.passed {
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
