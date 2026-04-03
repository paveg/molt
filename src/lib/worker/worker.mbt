///|
fn parse_url(url : String) -> (String, String) {
  // Find "://" then first "/" after it to split base and path
  let mut scheme_end = 0
  let mut prev2 = '\u0000'
  let mut prev1 = '\u0000'
  for i, c in url {
    if prev2 == ':' && prev1 == '/' && c == '/' {
      scheme_end = i + 1
      break
    }
    prev2 = prev1
    prev1 = c
  }
  // Find the first "/" after the scheme
  let mut slash_pos = -1
  for i, c in url {
    if i >= scheme_end && c == '/' {
      slash_pos = i
      break
    }
  }
  if slash_pos >= 0 {
    (url[:slash_pos].to_string(), url[slash_pos:].to_string())
  } else {
    (url, "/")
  }
}

///|
pub async fn run(
  config : @types.Config,
  on_result : (@types.RequestResult) -> Unit,
  should_stop : () -> Bool,
) -> Unit {
  let (base_url, path) = parse_url(config.url)
  let client = @http.Client::new(base_url)
  while not(should_stop()) {
    let start = @bench.monotonic_clock_start()
    try {
      let response = client.get(path)
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
