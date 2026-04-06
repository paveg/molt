///|
let base64_table : Array[Char] = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
  'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
  'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
  'w', 'x', 'y', 'z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '+', '/',
]

///|
pub fn base64_encode(input : String) -> String {
  if input.length() == 0 {
    return ""
  }
  let bytes : Array[Int] = []
  for c in input {
    bytes.push(c.to_int())
  }
  let len = bytes.length()
  let buf = StringBuilder::new()
  let mut i = 0
  while i + 2 < len {
    let b0 = bytes[i]
    let b1 = bytes[i + 1]
    let b2 = bytes[i + 2]
    buf.write_char(base64_table[b0 >> 2])
    buf.write_char(base64_table[((b0 & 0x03) << 4) | (b1 >> 4)])
    buf.write_char(base64_table[((b1 & 0x0F) << 2) | (b2 >> 6)])
    buf.write_char(base64_table[b2 & 0x3F])
    i = i + 3
  }
  let remaining = len - i
  if remaining == 1 {
    let b0 = bytes[i]
    buf.write_char(base64_table[b0 >> 2])
    buf.write_char(base64_table[(b0 & 0x03) << 4])
    buf.write_char('=')
    buf.write_char('=')
  } else if remaining == 2 {
    let b0 = bytes[i]
    let b1 = bytes[i + 1]
    buf.write_char(base64_table[b0 >> 2])
    buf.write_char(base64_table[((b0 & 0x03) << 4) | (b1 >> 4)])
    buf.write_char(base64_table[(b1 & 0x0F) << 2])
    buf.write_char('=')
  }
  buf.to_string()
}
