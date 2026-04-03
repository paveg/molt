///|
test "parse_url/standard" {
  let (base, path) = parse_url("http://example.com/path")
  inspect(base, content="http://example.com")
  inspect(path, content="/path")
}

///|
test "parse_url/without_path" {
  let (base, path) = parse_url("http://example.com")
  inspect(base, content="http://example.com")
  inspect(path, content="/")
}

///|
test "parse_url/root_path" {
  let (base, path) = parse_url("http://example.com/")
  inspect(base, content="http://example.com")
  inspect(path, content="/")
}

///|
test "parse_url/multi_segment_path" {
  let (base, path) = parse_url("http://example.com/api/v1/users")
  inspect(base, content="http://example.com")
  inspect(path, content="/api/v1/users")
}

///|
test "parse_url/https" {
  let (base, path) = parse_url("https://example.com/path")
  inspect(base, content="https://example.com")
  inspect(path, content="/path")
}

///|
test "parse_url/with_port" {
  let (base, path) = parse_url("http://example.com:8080/path")
  inspect(base, content="http://example.com:8080")
  inspect(path, content="/path")
}

///|
test "parse_url/port_no_path" {
  let (base, path) = parse_url("http://localhost:3000")
  inspect(base, content="http://localhost:3000")
  inspect(path, content="/")
}

///|
test "parse_url/query_string" {
  let (base, path) = parse_url("http://example.com/path?q=1&b=2")
  inspect(base, content="http://example.com")
  inspect(path, content="/path?q=1&b=2")
}

///|
test "parse_url/localhost" {
  let (base, path) = parse_url("http://localhost/api")
  inspect(base, content="http://localhost")
  inspect(path, content="/api")
}

///|
test "parse_url/ip_address" {
  let (base, path) = parse_url("http://127.0.0.1:8080/health")
  inspect(base, content="http://127.0.0.1:8080")
  inspect(path, content="/health")
}

///|
test "build_headers empty array" {
  let h = build_headers([])
  inspect(h.length(), content="0")
}

///|
test "build_headers single header" {
  let h = build_headers([("Content-Type", "application/json")])
  inspect(h.get("Content-Type"), content="Some(\"application/json\")")
}

///|
test "build_headers multiple headers" {
  let h = build_headers([("Content-Type", "application/json"), ("Authorization", "Bearer token")])
  inspect(h.get("Content-Type"), content="Some(\"application/json\")")
  inspect(h.get("Authorization"), content="Some(\"Bearer token\")")
}

///|
test "build_headers duplicate key uses last value" {
  let h = build_headers([("X-Key", "first"), ("X-Key", "second")])
  inspect(h.get("X-Key"), content="Some(\"second\")")
}
