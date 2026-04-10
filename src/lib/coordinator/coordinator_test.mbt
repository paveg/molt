///|
fn test_config(url : String, duration_ms : Int) -> @types.Config {
  {
    url,
    connections: 2,
    mode: @types.TestMode::Duration(duration_ms),
    http_method: @types.HttpMethod::Get,
    headers: [],
    body: None,
    timeout_ms: 5000,
    enable_tui: false,
    json_output: false,
    latency_correction: false,
    rate: None,
    percentiles: [50.0, 99.0],
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
async fn start_server(group : @async.TaskGroup[Unit]) -> (@http.Server, Int) {
  let server = @http.Server::new(@socket.Addr::parse("127.0.0.1:0"))
  let port = server.addr.port()
  group.spawn_bg(no_wait=true, async fn() {
    server.run_forever(async fn(_request, body, conn) {
      while body.read_some() is Some(_) {

      }
      conn.send_response(200, "OK")
      conn.write("ok")
    }) catch {
      _ => ()
    }
  })
  (server, port)
}

///|
async test "integration: basic duration mode" {
  @async.with_task_group(async fn(group) {
    let (server, port) = start_server(group)
    let stats = @coordinator.run(test_config("http://127.0.0.1:\{port}", 300))
    server.close()
    inspect(stats.total_requests > 0, content="true")
    inspect(stats.failed, content="0")
    inspect(stats.latency.p50_us > 0L, content="true")
  })
}

///|
async test "integration: request count mode" {
  @async.with_task_group(async fn(group) {
    let (server, port) = start_server(group)
    let config = {
      ..test_config("http://127.0.0.1:\{port}", 0),
      mode: @types.TestMode::RequestCount(20),
    }
    let stats = @coordinator.run(config)
    server.close()
    inspect(stats.total_requests >= 20, content="true")
    inspect(stats.failed, content="0")
  })
}

///|
async test "integration: on_result callback" {
  @async.with_task_group(async fn(group) {
    let (server, port) = start_server(group)
    let mut count = 0
    let stats = @coordinator.run(
      test_config("http://127.0.0.1:\{port}", 300),
      on_result=Some(fn(_r) { count = count + 1 }),
    )
    server.close()
    inspect(stats.total_requests > 0, content="true")
    inspect(count > 0, content="true")
  })
}
