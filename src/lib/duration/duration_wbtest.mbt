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
  let r = try { Ok(parse("")) } catch { e => Err(e) }
  inspect(r is Err(_), content="true")
}

///|
test "no unit raises" {
  let r = try { Ok(parse("123")) } catch { e => Err(e) }
  inspect(r is Err(_), content="true")
}

///|
test "invalid char raises" {
  let r = try { Ok(parse("10x")) } catch { e => Err(e) }
  inspect(r is Err(_), content="true")
}

///|
test "missing number raises" {
  let r = try { Ok(parse("s")) } catch { e => Err(e) }
  inspect(r is Err(_), content="true")
}
