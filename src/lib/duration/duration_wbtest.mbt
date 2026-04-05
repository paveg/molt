///|
test "parse seconds" {
  inspect(parse("10s"), content="10000")
}

///|
test "parse minutes" {
  inspect(parse("1m"), content="60000")
}

///|
test "parse combined" {
  inspect(parse("1m30s"), content="90000")
}

///|
test "parse hours" {
  inspect(parse("1h"), content="3600000")
}

///|
test "parse complex" {
  inspect(parse("1h2m3s"), content="3723000")
}

///|
test "parse 30s" {
  inspect(parse("30s"), content="30000")
}

///|
test "parse 0s" {
  inspect(parse("0s"), content="0")
}

///|
test "empty raises" {
  let r = Ok(parse("")) catch { e => Err(e) }
  inspect(r is Err(_), content="true")
}

///|
test "no unit raises" {
  let r = Ok(parse("123")) catch { e => Err(e) }
  inspect(r is Err(_), content="true")
}

///|
test "invalid char raises" {
  let r = Ok(parse("10x")) catch { e => Err(e) }
  inspect(r is Err(_), content="true")
}

///|
test "missing number raises" {
  let r = Ok(parse("s")) catch { e => Err(e) }
  inspect(r is Err(_), content="true")
}

///|
test "overflow hours raises" {
  let r = Ok(parse("999999h")) catch { e => Err(e) }
  inspect(r is Err(_), content="true")
}

///|
test "overflow minutes raises" {
  let r = Ok(parse("99999999m")) catch { e => Err(e) }
  inspect(r is Err(_), content="true")
}

///|
test "overflow seconds raises" {
  let r = Ok(parse("9999999999s")) catch { e => Err(e) }
  inspect(r is Err(_), content="true")
}

///|
test "max safe duration does not overflow" {
  // 596 hours = 596 * 3600000 = 2_145_600_000 (within Int range)
  let r = Ok(parse("596h")) catch { e => Err(e) }
  inspect(r is Ok(_), content="true")
}

///|
test "parse_count 10k" {
  inspect(parse_count("10k"), content="10000")
}

///|
test "parse_count 1m" {
  inspect(parse_count("1m"), content="1000000")
}

///|
test "parse_count 100 no suffix" {
  inspect(parse_count("100"), content="100")
}

///|
test "parse_count 0k" {
  inspect(parse_count("0k"), content="0")
}

///|
test "parse_count empty raises" {
  let r = Ok(parse_count("")) catch { e => Err(e) }
  inspect(r is Err(_), content="true")
}

///|
test "parse_count invalid suffix raises" {
  let r = Ok(parse_count("10x")) catch { e => Err(e) }
  inspect(r is Err(_), content="true")
}

///|
test "parse_count uppercase K" {
  inspect(parse_count("5K"), content="5000")
}

///|
test "parse_count uppercase M" {
  inspect(parse_count("2M"), content="2000000")
}
