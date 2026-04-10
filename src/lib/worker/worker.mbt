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
  let lower = msg.to_lower()
  if lower.contains("timeout") {
    @types.RequestError::Timeout
  } else if lower.contains("refused") {
    @types.RequestError::ConnectionRefused
  } else if lower.contains("reset") {
    @types.RequestError::ConnectionReset
  } else if lower.contains("dns") || lower.contains("resolve") {
    @types.RequestError::DnsError
  } else if lower.contains("tls") ||
    lower.contains("ssl") ||
    lower.contains("certificate") {
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
  if rate <= 0 || num_workers <= 0 {
    return epoch_us
  }
  let interval_us = 1000000L / rate.to_int64()
  let stride_us = interval_us * num_workers.to_int64()
  epoch_us +
  request_index.to_int64() * stride_us +
  worker_id.to_int64() * interval_us
}

///|
fn compute_corrected_latency(
  elapsed_us~ : Int64,
  scheduled_us~ : Int64,
  actual_start_us~ : Int64,
) -> Int64 {
  let delay = actual_start_us - scheduled_us
  let corrected = if delay > 0L { elapsed_us + delay } else { elapsed_us }
  if corrected < 0L {
    0L
  } else {
    corrected
  }
}

///|
async fn follow_redirects(
  response : @http.Response,
  max_redirects : Int,
  extra_headers : Array[(String, String)],
) -> @http.Response {
  let mut current = response
  let mut remaining = max_redirects
  let headers = build_headers(extra_headers)
  while remaining > 0 && current.code >= 300 && current.code < 400 {
    match current.headers.get("location") {
      Some(loc) => {
        let (resp, _data) = @http.get(loc, headers~)
        current = resp
        remaining = remaining - 1
      }
      None => break
    }
  }
  current
}

///|
fn make_error_result(
  latency_us : Int64,
  error : @types.RequestError,
  scheduled_time_us : Int64,
) -> @types.RequestResult {
  {
    status_code: 0,
    latency_us,
    ttfb_us: 0L,
    error: Some(error),
    scheduled_time_us,
    response_size_bytes: 0L,
  }
}

///|
pub async fn run(
  config : @types.Config,
  on_result : (@types.RequestResult) -> Unit,
  should_stop : () -> Bool,
  rate_limiter? : @rate_limiter.RateLimiter? = None,
  worker_id? : Int = 0,
  num_workers? : Int = 1,
) -> Unit {
  let (base_url, path) = parse_url(config.url)
  let verify = !config.insecure
  let mut client = @http.Client::new(base_url, verify~) catch {
    err => {
      on_result(make_error_result(0L, classify_error(err.to_string()), 0L))
      return
    }
  }
  let headers = build_headers(config.headers)
  let epoch_us = @bench.monotonic_clock_end(@bench.monotonic_clock_start()).to_int64()
  let use_co = config.latency_correction && rate_limiter is Some(_)
  let rate = config.rate.unwrap_or(1)
  let mut request_index = 0
  while !should_stop() {
    if rate_limiter is Some(rl) {
      rl.acquire()
    }
    // Compute scheduled time for CO correction
    let scheduled_us = if use_co {
      compute_scheduled_time(
        epoch_us~,
        request_index~,
        rate~,
        worker_id~,
        num_workers~,
      )
    } else {
      0L
    }
    let start = @bench.monotonic_clock_start()
    let actual_start_us = @bench.monotonic_clock_end(start).to_int64()
    try {
      let body_data = config.body.unwrap_or("")
      let result = @async.with_timeout_opt(config.timeout_ms, async fn() {
        match config.http_method {
          @types.HttpMethod::Get => client.get(path, extra_headers=headers)
          @types.HttpMethod::Post =>
            client.post(path, body_data, extra_headers=headers)
          @types.HttpMethod::Put =>
            client.put(path, body_data, extra_headers=headers)
          @types.HttpMethod::Patch => {
            client.request(@http.Patch, path, extra_headers=headers)
            client.write(body_data)
            client.end_request()
          }
          @types.HttpMethod::Head => {
            client.request(@http.Head, path, extra_headers=headers)
            client.end_request()
          }
          @types.HttpMethod::Options => {
            client.request(@http.Options, path, extra_headers=headers)
            client.end_request()
          }
          @types.HttpMethod::Delete => {
            client.request(@http.Delete, path, extra_headers=headers)
            client.end_request()
          }
        }
      })
      match result {
        Some(response) => {
          let ttfb_raw = @bench.monotonic_clock_end(start).to_int64()
          let ttfb_us = if use_co {
            compute_corrected_latency(
              elapsed_us=ttfb_raw,
              scheduled_us~,
              actual_start_us~,
            )
          } else {
            ttfb_raw
          }
          client.skip_response_body()
          // Follow redirects if configured
          let final_response = if config.max_redirects > 0 &&
            response.code >= 300 &&
            response.code < 400 {
            follow_redirects(response, config.max_redirects, config.headers)
          } else {
            response
          }
          let size_bytes = match final_response.headers.get("content-length") {
            Some(v) => @string.parse_int64(v) catch { _ => 0L }
            None => 0L
          }
          let total_raw = @bench.monotonic_clock_end(start).to_int64()
          let latency_us = if use_co {
            compute_corrected_latency(
              elapsed_us=total_raw,
              scheduled_us~,
              actual_start_us~,
            )
          } else {
            total_raw
          }
          on_result({
            status_code: final_response.code,
            latency_us,
            ttfb_us,
            error: None,
            scheduled_time_us: scheduled_us,
            response_size_bytes: size_bytes,
          })
          if config.disable_keepalive {
            client.close()
            client = @http.Client::new(base_url, verify~) catch {
              err => {
                on_result(
                  make_error_result(0L, classify_error(err.to_string()), 0L),
                )
                return
              }
            }
          }
        }
        None => {
          let raw_elapsed = @bench.monotonic_clock_end(start).to_int64()
          on_result(
            make_error_result(
              raw_elapsed,
              @types.RequestError::Timeout,
              scheduled_us,
            ),
          )
        }
      }
    } catch {
      err => {
        let raw_elapsed = @bench.monotonic_clock_end(start).to_int64()
        let error_type = classify_error(err.to_string())
        on_result(make_error_result(raw_elapsed, error_type, scheduled_us))
        // Reconnect: the client may be in a broken state after an error.
        // Sleep briefly to avoid tight reconnect loops on persistent failures.
        client.close()
        @async.sleep(100)
        client = @http.Client::new(base_url, verify~) catch {
          reconnect_err => {
            on_result(
              make_error_result(
                0L,
                classify_error(reconnect_err.to_string()),
                0L,
              ),
            )
            return
          }
        }
      }
    }
    request_index = request_index + 1
  }
  client.close()
}
