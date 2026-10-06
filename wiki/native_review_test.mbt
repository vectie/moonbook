///|
async test "native readback observes existing manual approve and reject without migration or acceptance" {
  for action in ["approved", "rejected"] {
    let root = @fs.tmpdir(prefix="moonbook-native-human-review-")
    ignore(@wiki.init_workspace(root))
    let result : @wiki.BookResult = @json.from_json({
      "result_id": "human-reviewed-result",
      "summary": "Engineering result remains subject to original-task acceptance.",
      "artifacts": ["wiki/CODE_PATCH.md", "wiki/TEST_RESULTS.md"],
      "memory_candidates": [],
      "requires_review": true,
      "notify_town": true,
    })
    let work_id = "native-human-review-\{action}"
    let request_digest = @wiki.executable_sha256("frozen-request")[7:].to_owned()
    let payload_digest = @wiki.executable_sha256(result.to_json().stringify())[7:].to_owned()
    let payload : Json = {
      "book_result": result.to_json(),
      "native_import": {
        "contract": "moontown.wenyu.import.v1",
        "work_id": work_id,
        "request_digest": request_digest,
        "payload_digest": payload_digest,
      },
    }
    let receipt = @wiki.persist_result_payload(root, payload)
    let key = @wiki.executable_sha256(work_id)[7:].to_owned()
    let review_id = "result-review-native-wenyu-\{key}"
    let observed = @wiki.native_review_status(
      root,
      work_id,
      request_digest,
      payload_digest,
      result.result_id,
    )
    guard observed is Object(pending) else {
      fail("expected typed review object")
    }
    assert_eq(pending["status"], "pending".to_json())
    if action == "approved" {
      ignore(@wiki.approve_review(root, review_id))
    } else {
      ignore(@wiki.reject_review(root, review_id))
    }
    let paths = [
      "wiki/reviews/pending.md",
      "wiki/reviews/approved.md",
      "wiki/synthesis/evidence.md",
      "wiki/log.md",
      "events/latest.json",
      ".moonbook/native-wenyu-imports/\{key}.intent.json",
      ".moonbook/native-wenyu-imports/\{key}.receipt.json",
    ]
    let before : Array[String] = []
    for path in paths {
      before.push(@fsx.read_file(root + "/" + path))
    }
    let readback = @wiki.native_review_status(
      root,
      work_id,
      request_digest,
      payload_digest,
      result.result_id,
    )
    guard readback is Object(fields) else {
      fail("expected typed review object")
    }
    assert_eq(fields["status"], action.to_json())
    assert_eq(fields["review_id"], review_id.to_json())
    assert_eq(fields["evidence_id"], receipt.evidence_id.to_json())
    assert_eq(fields["original_task_acceptance"], "unevaluated".to_json())
    guard fields["resolution_timestamp"] is String(timestamp) else {
      fail("expected saved resolution timestamp")
    }
    assert_true(!timestamp.is_empty())
    assert_eq(
      @wiki.persist_result_payload(root, payload).to_json(),
      receipt.to_json(),
    )
    assert_true(!receipt.executable_event.accepted)
    assert_eq(
      @wiki.native_review_status(
        root,
        work_id,
        request_digest,
        payload_digest,
        result.result_id,
      ),
      readback,
    )
    for index in 0..<paths.length() {
      assert_eq(@fsx.read_file(root + "/" + paths[index]), before[index])
    }
  }
}
