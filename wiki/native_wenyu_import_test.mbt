///|
async test "native Wenyu public payload API retains exact receipt and leaves BookResult shape unchanged" {
  let root = @fs.realpath(@fs.tmpdir(prefix="moonbook-native-wenyu-public-"))
  let result : @wiki.BookResult = @json.from_json({
    "result_id": "wenyu-public-code-patch",
    "summary": "Verified native implementation awaiting product review.",
    "artifacts": ["wiki/CODE_PATCH.md", "wiki/TEST_RESULTS.md"],
    "memory_candidates": [],
    "requires_review": true,
    "notify_town": true,
  })
  let nested = result.to_json()
  let payload : Json = {
    "book_result": nested,
    "native_import": {
      "contract": "moontown.wenyu.import.v1",
      "work_id": "native-public-work",
      "request_digest": @wiki.executable_sha256("request")[7:].to_owned(),
      "payload_digest": @wiki.executable_sha256(nested.stringify())[7:].to_owned(),
    },
  }
  let first = @wiki.persist_result_payload(
    root,
    @json.parse(payload.stringify()),
  )
  let second = @wiki.persist_result_payload(root, payload)
  assert_eq(first.to_json(), second.to_json())
  assert_true(first.review_queued && first.notify_town)
  assert_true(!first.executable_event.accepted)
  assert_eq(first.executable_event.artifacts, result.artifacts)
  let expected_event = result.to_executable_book_event(
    book_id=@wiki.book_identity(root),
    evidence_id=Some(first.evidence_id),
    review_path=Some("wiki/reviews/pending.md"),
  )
  assert_eq(first.executable_event, expected_event)
  let raw = @native_wenyu_import.persist(root, payload)
  let decoded : @wiki.PersistResultOutcome = @json.from_json(raw)
  assert_eq(decoded.to_json(), first.to_json())
  assert_true(!nested.stringify().contains("native_import"))
  assert_eq(@wiki.decode_book_result_payload(payload).to_json(), nested)
}
