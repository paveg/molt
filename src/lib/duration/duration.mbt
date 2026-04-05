///|
pub suberror ParseError {
  InvalidDuration(String)
} derive(Show)

///|
pub fn parse(input : String) -> Int raise {
  guard input.length() > 0 else {
    raise InvalidDuration("empty duration string")
  }
  let mut total_ms = 0
  let mut num_start = 0
  let mut has_unit = false
  for i, c in input {
    match c {
      'h' | 'm' | 's' => {
        guard i > num_start else {
          raise InvalidDuration("missing number before '\{c}' in \"\{input}\"")
        }
        let num_str = input[num_start:i].to_string()
        let n = @string.parse_int(num_str) catch {
          _ =>
            raise InvalidDuration(
              "invalid number \"\{num_str}\" in \"\{input}\"",
            )
        }
        let multiplier = match c {
          'h' => 3600000
          'm' => 60000
          's' => 1000
          _ => 0
        }
        let product = n * multiplier
        if multiplier != 0 && product / multiplier != n {
          raise InvalidDuration("duration value too large in \"\{input}\"")
        }
        total_ms = total_ms + product
        num_start = i + 1
        has_unit = true
      }
      '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' => ()
      _ => raise InvalidDuration("unexpected character '\{c}' in \"\{input}\"")
    }
  }
  guard has_unit else {
    raise InvalidDuration("no time unit found in \"\{input}\"")
  }
  guard num_start == input.length() else {
    raise InvalidDuration("trailing number without unit in \"\{input}\"")
  }
  total_ms
}

///|
pub fn parse_count(input : String) -> Int raise {
  let len = input.length()
  if len == 0 {
    raise InvalidDuration("empty count")
  }
  let mut last_char = ' '
  for i, c in input {
    if i == len - 1 {
      last_char = c
    }
  }
  match last_char {
    'k' | 'K' => {
      let num_str = input[:len - 1].to_string()
      let num = @string.parse_int(num_str) catch {
        _ => raise InvalidDuration("invalid count \"\{input}\"")
      }
      if num < 0 || num > 2147483 {
        raise InvalidDuration("count too large: \"\{input}\"")
      }
      num * 1000
    }
    'm' | 'M' => {
      let num_str = input[:len - 1].to_string()
      let num = @string.parse_int(num_str) catch {
        _ => raise InvalidDuration("invalid count \"\{input}\"")
      }
      if num < 0 || num > 2147 {
        raise InvalidDuration("count too large: \"\{input}\"")
      }
      num * 1000000
    }
    _ =>
      @string.parse_int(input) catch {
        _ => raise InvalidDuration("invalid count \"\{input}\"")
      }
  }
}
