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
fn build_headers(pairs : Array[(String, String)]) -> Map[String, String] {
  let m : Map[String, String] = {}
  for pair in pairs {
    m[pair.0] = pair.1
  }
  m
}

///|
fn classify_error(msg : String) -> @types.RequestError {
  if msg.contains("timeout") || msg.contains("Timeout") {
    @types.RequestError::Timeout
  } else if msg.contains("refused") || msg.contains("Refused") {
    @types.RequestError::ConnectionRefused
  } else if msg.contains("reset") || msg.contains("Reset") {
    @types.RequestError::ConnectionReset
  } else if msg.contains("DNS") || msg.contains("dns") || msg.contains("resolve") {
    @types.RequestError::DnsError
  } else if msg.contains("TLS") || msg.contains("tls") || msg.contains("SSL") || msg.contains("certificate") {
    @types.RequestError::TlsError
  } else {
    @types.RequestError::Other(msg)
  }
}

///|
pub async fn run(
  config : @types.Config,
  on_result : (@types.RequestResult) -> Unit,
  should_stop : () -> Bool,
  rate_limiter~ : @rate_limiter.RateLimiter? = None,
) -> Unit {
  let (base_url, path) = parse_url(config.url)
  let client = @http.Client::new(base_url)
  let headers = build_headers(config.headers)
  while not(should_stop()) {
    match rate_limiter {
      Some(rl) => rl.acquire()
      None => ()
    }
    let start = @bench.monotonic_clock_start()
    try {
      let result = @async.with_timeout_opt(config.timeout_ms, async fn() {
        match config.http_method {
          @types.HttpMethod::Get =>
            client.get(path, extra_headers=headers)
          @types.HttpMethod::Post => {
            let body_data : String = match config.body {
              Some(b) => b
              None => ""
            }
            client.post(path, body_data, extra_headers=headers)
          }
          @types.HttpMethod::Put => {
            let body_data : String = match config.body {
              Some(b) => b
              None => ""
            }
            client.put(path, body_data, extra_headers=headers)
          }
          @types.HttpMethod::Delete => {
            client.request(@http.Delete, path, extra_headers=headers)
            client.end_request()
          }
        }
      })
      match result {
        Some(response) => {
          let elapsed_us = @bench.monotonic_clock_end(start)
          on_result(
            {
              status_code: response.code,
              latency_us: elapsed_us.to_int64(),
              error: None,
              scheduled_time_us: 0L,
            },
          )
          client.skip_response_body()
        }
        None => {
          let elapsed_us = @bench.monotonic_clock_end(start)
          on_result(
            {
              status_code: 0,
              latency_us: elapsed_us.to_int64(),
              error: Some(@types.RequestError::Timeout),
              scheduled_time_us: 0L,
            },
          )
        }
      }
    } catch {
      err => {
        let elapsed_us = @bench.monotonic_clock_end(start)
        let error_type = classify_error(err.to_string())
        on_result(
          {
            status_code: 0,
            latency_us: elapsed_us.to_int64(),
            error: Some(error_type),
            scheduled_time_us: 0L,
          },
        )
      }
    }
  }
  client.close()
}
