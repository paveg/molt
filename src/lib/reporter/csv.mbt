///|
pub let csv_header : String = "latency_us,status_code,error,response_size_bytes"

///|
pub fn format_csv_row(result : @types.RequestResult) -> String {
  let error_str = match result.error {
    Some(err) => {
      let s = err.to_string()
      if s.contains(",") || s.contains("\"") {
        "\"" + json_escape(s) + "\""
      } else {
        s
      }
    }
    None => ""
  }
  "\{result.latency_us},\{result.status_code},\{error_str},\{result.response_size_bytes}"
}
