///|
fn socket_test_headers(headers : Map[String, String]) -> @http.Headers {
  let result = Map([])
  for key, value in headers {
    result[@http.CaseInsensitiveString(key)] = value
  }
  result
}
