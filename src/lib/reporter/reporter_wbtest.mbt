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
