///|
async test "wiki review host owns root rejects cross-site forms and leaves Bookkeeper route separate" {
  let root = @fs.tmpdir(prefix="book-review-http-")
  ignore(@wiki.init_workspace(root))
  let pending = "# Pending Review\n\n## Items\n\n### Query review | Browser item\n\n- Review ID: `browser-id`\n- Status: `pending`\n- Candidate insight: visible exact content\n"
  @fs.write_file(root + "/wiki/reviews/pending.md", pending)
  let (status, response) = @moonwiki.wiki_review_http_response(
    root,
    "GET",
    "/api/wiki/reviews",
    Map([]),
    "",
  )
  assert_eq(status, 200, msg=response.stringify())
  assert_eq(
    @moonwiki.wiki_review_http_response(
      root,
      "POST",
      "/api/wiki/reviews/inspect",
      { "content-type": "text/plain" },
      "{}",
    ).0,
    415,
  )
  assert_eq(
    @moonwiki.wiki_review_http_response(
      root,
      "POST",
      "/api/wiki/reviews/inspect",
      { "content-type": "application/json", "sec-fetch-site": "cross-site" },
      "{}",
    ).0,
    403,
  )
  assert_eq(
    @moonwiki.wiki_review_http_response(
      root,
      "POST",
      "/api/wiki/reviews/inspect",
      { "content-type": "application/json" },
      "broken",
    ).0,
    400,
  )
  assert_eq(
    @moonwiki.wiki_review_http_response(
      root,
      "POST",
      "/api/bookkeeper/reviews",
      { "content-type": "application/json" },
      "{}",
    ).0,
    404,
  )
  let (inspect_status, detail) = @moonwiki.wiki_review_http_response(
    root,
    "POST",
    "/api/wiki/reviews/inspect",
    { "Content-Type": "application/json; charset=utf-8" },
    "{\"review_id\":\"browser-id\",\"root\":\"/some-other-root\"}",
  )
  assert_eq(inspect_status, 200, msg=detail.stringify())
  assert_true(detail.stringify().contains("visible exact content"))
  assert_eq(@fs.read_file(root + "/wiki/reviews/pending.md").text(), pending)
}
