///|
async test "native HTTP headers retain the mixed case same origin refusal boundary" {
  let headers : @http.Headers = {
    "sEc-FeTcH-sItE": "cross-site",
    "cOnTeNt-TyPe": "application/json",
  }
  let plain = wiki_review_http_plain_headers(headers)
  assert_eq(wiki_review_http_header(plain, "content-type"), "application/json")
  let (review_status, _) = wiki_review_http_response(
    "/unused-cross-site-root", "POST", "/api/wiki/reviews", plain, "{}",
  )
  assert_eq(review_status, 403)
  let (search_status, _) = book_search_http_response(
    "/unused-cross-site-root", "POST", "/api/book/query", plain, "{}",
  )
  assert_eq(search_status, 403)
}
