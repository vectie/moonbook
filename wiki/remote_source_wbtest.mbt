///|
test "remote source content type uses case insensitive HTTP header names" {
  let headers : @http.Headers = { "cOnTeNt-TyPe": "text/plain; charset=utf-8" }
  assert_eq(remote_content_type(headers), "text/plain; charset=utf-8")
  assert_eq(remote_content_type({}), "unknown")
}
