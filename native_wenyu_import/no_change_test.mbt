///|
async test "no change owner summary persists through public Book API without accepting original task" {
  let root = @fs.realpath(@fs.tmpdir(prefix="moonbook-no-change-public-"))
  let result : Json = {
    "result_id": "wenyu-no-change-code-patch",
    "summary": "No net source change; required checks passed; human review required; original-task acceptance unevaluated.",
    "artifacts": [
      "build/CODE_PATCH.md", "build/TEST_RESULTS.md", "raw/build/native/native-no-change-public/output-package.json",
    ],
    "memory_candidates": [],
    "requires_review": true,
    "notify_town": true,
  }
  let envelope : Json = {
    "book_result": result,
    "native_import": {
      "contract": "moontown.wenyu.import.v1",
      "work_id": "native-no-change-public",
      "request_digest": @crypto.bytes_to_hex_string(
        @crypto.sha256(@utf8.encode("explicit opted-in owner request")),
      ),
      "payload_digest": @crypto.bytes_to_hex_string(
        @crypto.sha256(@utf8.encode(result.stringify())),
      ),
    },
  }
  let outcome = @native_wenyu_import.persist(root, envelope)
  assert_eq(outcome, @native_wenyu_import.persist(root, envelope))
  guard outcome is Object(fields) else { fail("expected outcome") }
  assert_eq(fields["review_queued"], true.to_json())
  assert_eq(fields["notify_town"], true.to_json())
  guard fields["executable_event"] is Object(event) else {
    fail("expected review event")
  }
  assert_eq(event["accepted"], false.to_json())
  assert_eq(event["event_type"], "review_required".to_json())
  guard result is Object(result_fields) else { fail("expected result") }
  assert_eq(event["summary"], result_fields["summary"])
  assert_eq(event["artifacts"], result_fields["artifacts"])
  assert_eq(event.get("lifecycle_proof"), None)
  assert_eq(event.get("run_id"), None)
  guard fields["executable_event_path"] is String(event_path) else {
    fail("expected durable event path")
  }
  assert_eq(
    @json.parse(@fsx.read_file(root + "/" + event_path)),
    fields["executable_event"],
  )
}
