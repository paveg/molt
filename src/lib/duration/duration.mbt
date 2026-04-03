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
        let n = @strconv.parse_int(num_str) catch {
          _ =>
            raise InvalidDuration("invalid number \"\{num_str}\" in \"\{input}\"")
        }
        match c {
          'h' => total_ms = total_ms + n * 3600000
          'm' => total_ms = total_ms + n * 60000
          's' => total_ms = total_ms + n * 1000
          _ => ()
        }
        num_start = i + 1
        has_unit = true
      }
      '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' => ()
      _ =>
        raise InvalidDuration("unexpected character '\{c}' in \"\{input}\"")
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
