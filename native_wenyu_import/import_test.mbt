///|
async test "native Wenyu public API persists an exact wire payload and replays its receipt" {
  let root = @fs.tmpdir(prefix="moonbook-native-wenyu-wire-")
  let result : Json = {
    "result_id": "wenyu-public-code-patch",
    "summary": "Verified native implementation awaiting product review.",
    "artifacts": ["wiki/CODE_PATCH.md", "wiki/TEST_RESULTS.md"],
    "memory_candidates": [],
    "requires_review": true,
    "notify_town": true,
  }
  let request_digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@utf8.encode("request")),
  )
  let payload_digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@utf8.encode(result.stringify())),
  )
  let envelope : Json = {
    "book_result": result,
    "native_import": {
      "contract": "moontown.wenyu.import.v1",
      "work_id": "native-public-work",
      "request_digest": request_digest,
      "payload_digest": payload_digest,
    },
  }
  let first = @native_wenyu_import.persist(
    root,
    @json.parse(envelope.stringify()),
  )
  assert_eq(first, @native_wenyu_import.persist(root, envelope))
  guard first is Object(fields) else {
    fail("expected existing outcome object")
  }
  assert_eq(fields["review_queued"], true.to_json())
  assert_eq(fields["notify_town"], true.to_json())
  guard fields["executable_event"] is Object(event) else {
    fail("expected event object")
  }
  assert_eq(event["accepted"], false.to_json())
  assert_eq(event["event_type"], "review_required".to_json())
  assert_eq(event["protocol"], "moonbook.executable_event.v1".to_json())
  assert_eq(event.get("lifecycle_proof"), None)
  assert_eq(event.get("run_id"), None)
}
