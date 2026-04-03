///|
pub async fn run(
  config : @types.Config,
  on_result : (@types.RequestResult) -> Unit,
  should_stop : () -> Bool,
) -> Unit {
  let client = @http.Client::new(config.url)
  while not(should_stop()) {
    let start = @bench.monotonic_clock_start()
    try {
      let response = client.get("/")
      let elapsed_us = @bench.monotonic_clock_end(start)
      on_result(
        {
          status_code: response.code,
          latency_us: elapsed_us.to_int64(),
          error: None,
        },
      )
      client.skip_response_body()
    } catch {
      _ => {
        let elapsed_us = @bench.monotonic_clock_end(start)
        on_result(
          {
            status_code: 0,
            latency_us: elapsed_us.to_int64(),
            error: Some(@types.RequestError::Other("request failed")),
          },
        )
      }
    }
  }
  client.close()
}
