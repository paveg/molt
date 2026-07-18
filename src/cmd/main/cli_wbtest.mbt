///|
test "parse_args_from --cacert populates Config.cacert" {
  let config = parse_args_from([
    "molt", "https://example.com", "--cacert", "/path/ca.pem",
  ])
  inspect(config.cacert, content="Some(/path/ca.pem)")
}

///|
test "parse_args_from without --cacert leaves Config.cacert unset" {
  let config = parse_args_from(["molt", "https://example.com"])
  inspect(config.cacert, content="None")
}
