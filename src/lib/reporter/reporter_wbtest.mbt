///|
test "format_us_as_ms zero" {
  inspect(format_us_as_ms(0L), content="0.0ms")
}

///|
test "format_us_as_ms 1us rounds to 0 fractional" {
  inspect(format_us_as_ms(1L), content="0.0ms")
}

///|
test "format_us_as_ms 999us" {
  inspect(format_us_as_ms(999L), content="0.99ms")
}

///|
test "format_us_as_ms 1000us exact millisecond" {
  inspect(format_us_as_ms(1000L), content="1.0ms")
}

///|
test "format_us_as_ms 1500us" {
  inspect(format_us_as_ms(1500L), content="1.50ms")
}

///|
test "format_us_as_ms 999999us" {
  inspect(format_us_as_ms(999999L), content="999.99ms")
}

///|
test "format_us_as_ms 1000000us" {
  inspect(format_us_as_ms(1000000L), content="1000.0ms")
}

///|
test "format_percentage zero total guard" {
  inspect(format_percentage(0, 0), content="0.00%")
}

///|
test "format_percentage zero of hundred" {
  inspect(format_percentage(0, 100), content="0.0%")
}

///|
test "format_percentage hundred of hundred" {
  inspect(format_percentage(100, 100), content="100.0%")
}

///|
test "format_percentage one third" {
  inspect(format_percentage(1, 3), content="33.33%")
}

///|
test "format_percentage fifty percent" {
  inspect(format_percentage(50, 100), content="50.0%")
}

///|
test "format_rps zero" {
  inspect(format_rps(0.0), content="0.0")
}

///|
test "format_rps fractional" {
  inspect(format_rps(1.5), content="1.50")
}

///|
test "format_rps large whole number" {
  inspect(format_rps(1000.0), content="1000.0")
}

///|
test "format_rps two decimal places" {
  inspect(format_rps(99.99), content="99.98")
}

///|
test "format_time zero" {
  inspect(format_time(0.0), content="0.0s")
}

///|
test "format_time 999ms" {
  inspect(format_time(999.0), content="0.99s")
}

///|
test "format_time 1000ms exact second" {
  inspect(format_time(1000.0), content="1.0s")
}

///|
test "format_time 60000ms" {
  inspect(format_time(60000.0), content="60.0s")
}

///|
test "format_time 100ms" {
  inspect(format_time(100.0), content="0.10s")
}

///|
test "format_double zero" {
  inspect(format_double(0.0), content="0.00")
}

///|
test "format_double whole number" {
  inspect(format_double(5.0), content="5.00")
}

///|
test "format_double rounds up" {
  // 1.999 → frac = ((0.999)*100+0.5).to_int() = 100 → triggers whole+1
  inspect(format_double(1.999), content="2.00")
}

///|
test "format_double small fraction" {
  inspect(format_double(0.01), content="0.01")
}

///|
test "format_double negative" {
  // Check behavior with negative values (latency can't be negative, but test the edge)
  inspect(format_double(-1.5), content="-1.50")
}

///|
test "format_double large value" {
  inspect(format_double(99999.99), content="99999.99")
}

///|
test "method_to_string all variants" {
  inspect(method_to_string(@types.HttpMethod::Get), content="GET")
  inspect(method_to_string(@types.HttpMethod::Post), content="POST")
  inspect(method_to_string(@types.HttpMethod::Put), content="PUT")
  inspect(method_to_string(@types.HttpMethod::Delete), content="DELETE")
  inspect(method_to_string(@types.HttpMethod::Patch), content="PATCH")
  inspect(method_to_string(@types.HttpMethod::Head), content="HEAD")
  inspect(method_to_string(@types.HttpMethod::Options), content="OPTIONS")
}

///|
test "json_escape quotes" {
  inspect(json_escape("hello \"world\""), content="hello \\\"world\\\"")
}

///|
test "json_escape backslash" {
  inspect(json_escape("path\\to\\file"), content="path\\\\to\\\\file")
}

///|
test "json_escape newlines" {
  inspect(json_escape("line1\nline2"), content="line1\\nline2")
}

///|
test "json_escape no special chars" {
  inspect(json_escape("normal string"), content="normal string")
}

///|
test "json_escape tab" {
  inspect(json_escape("col1\tcol2"), content="col1\\tcol2")
}

///|
test "json_escape carriage return" {
  inspect(json_escape("line1\rline2"), content="line1\\rline2")
}

///|
test "json_escape empty string" {
  inspect(json_escape(""), content="")
}

///|
test "json_escape consecutive special chars" {
  inspect(json_escape("\"\\\n"), content="\\\"\\\\\\n")
}
