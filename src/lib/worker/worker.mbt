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
fn compute_scheduled_time(
  epoch_us~ : Int64,
  request_index~ : Int,
  rate~ : Int,
  worker_id~ : Int,
  num_workers~ : Int,
) -> Int64 {
  let interval_us = 1000000L / rate.to_int64()
  let stride_us = interval_us * num_workers.to_int64()
  epoch_us + request_index.to_int64() * stride_us + worker_id.to_int64() * interval_us
}

///|
fn compute_corrected_latency(
  elapsed_us~ : Int64,
  scheduled_us~ : Int64,
  actual_start_us~ : Int64,
) -> Int64 {
  let delay = actual_start_us - scheduled_us
  let corrected = if delay > 0L { elapsed_us + delay } else { elapsed_us }
  if corrected < 0L { 0L } else { corrected }
}

///|
pub async fn run(
  config : @types.Config,
  on_result : (@types.RequestResult) -> Unit,
  should_stop : () -> Bool,
  rate_limiter~ : @rate_limiter.RateLimiter? = None,
  worker_id~ : Int = 0,
  num_workers~ : Int = 1,
) -> Unit {
  let (base_url, path) = parse_url(config.url)
  let mut client = @http.Client::new(base_url)
  let headers = build_headers(config.headers)
  let epoch_us = @bench.monotonic_clock_end(@bench.monotonic_clock_start()).to_int64()
  let use_co = config.latency_correction && rate_limiter is Some(_)
  let rate = match config.rate {
    Some(r) => r
    None => 1
  }
  let mut request_index = 0
  while not(should_stop()) {
    // Rate limiting
    match rate_limiter {
      Some(rl) => rl.acquire()
      None => ()
    }
    // Compute scheduled time for CO correction
    let scheduled_us = if use_co {
      compute_scheduled_time(epoch_us~, request_index~, rate~, worker_id~, num_workers~)
    } else {
      0L
    }
    let start = @bench.monotonic_clock_start()
    let actual_start_us = @bench.monotonic_clock_end(start).to_int64()
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
          let raw_elapsed = @bench.monotonic_clock_end(start).to_int64()
          let latency_us = if use_co {
            compute_corrected_latency(elapsed_us=raw_elapsed, scheduled_us~, actual_start_us~)
          } else {
            raw_elapsed
          }
          on_result(
            { status_code: response.code, latency_us, error: None, scheduled_time_us: scheduled_us },
          )
          client.skip_response_body()
        }
        None => {
          let raw_elapsed = @bench.monotonic_clock_end(start).to_int64()
          on_result(
            { status_code: 0, latency_us: raw_elapsed, error: Some(@types.RequestError::Timeout), scheduled_time_us: scheduled_us },
          )
        }
      }
    } catch {
      err => {
        let raw_elapsed = @bench.monotonic_clock_end(start).to_int64()
        let error_type = classify_error(err.to_string())
        on_result(
          { status_code: 0, latency_us: raw_elapsed, error: Some(error_type), scheduled_time_us: scheduled_us },
        )
        // Reconnect: the client may be in a broken state after an error
        client.close()
        client = @http.Client::new(base_url)
      }
    }
    request_index = request_index + 1
  }
  client.close()
}
