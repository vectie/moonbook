///|
async test "native review public query is typed read only and never initializes missing state" {
  let root = @fs.tmpdir(prefix="moonbook-review-empty-")
  let missing = @native_wenyu_import.resolve_review(
    root, "missing-work", "bad-request", "bad-payload", "result",
  )
  assert_eq(missing.status, @native_wenyu_import.Unresolved)
  assert_eq(missing.original_task_acceptance, "unevaluated")
  assert_eq(missing.resolution_timestamp, None)
  assert_eq(@fsx.list_directory(root).length(), 0)
  let absent_root = root + "/absent"
  let absent = @native_wenyu_import.resolve_review(
    absent_root, "missing-work", "bad-request", "bad-payload", "result",
  )
  assert_eq(absent.status, @native_wenyu_import.Unresolved)
  assert_true(!@fsx.exists(absent_root))
  assert_eq(@native_wenyu_import.Pending.to_json(), "pending".to_json())
  assert_eq(@native_wenyu_import.Approved.to_json(), "approved".to_json())
  assert_eq(@native_wenyu_import.Rejected.to_json(), "rejected".to_json())
  assert_eq(@native_wenyu_import.Unresolved.to_json(), "unresolved".to_json())
}

///|
async test "native review public query returns exact committed pending binding without changing receipt" {
  let root = @fs.tmpdir(prefix="moonbook-review-public-")
  let result : Json = {
    "result_id": "same-result",
    "summary": "Completed engineering; acceptance unevaluated.",
    "artifacts": [],
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
  let payload : Json = {
    "book_result": result,
    "native_import": {
      "contract": "moontown.wenyu.import.v1",
      "work_id": "public-review-work",
      "request_digest": request_digest,
      "payload_digest": payload_digest,
    },
  }
  let receipt = @native_wenyu_import.persist(root, payload)
  let pending = @native_wenyu_import.resolve_review(
    root, "public-review-work", request_digest, payload_digest, "same-result",
  )
  assert_eq(pending.status, @native_wenyu_import.Pending)
  assert_eq(pending.contract, "moonbook.native-wenyu-review.v1")
  assert_eq(pending.root, root)
  assert_eq(pending.work_id, "public-review-work")
  assert_eq(pending.request_digest, request_digest)
  assert_eq(pending.payload_digest, payload_digest)
  assert_eq(pending.result_id, "same-result")
  assert_eq(pending.resolution_timestamp, None)
  assert_eq(pending.original_task_acceptance, "unevaluated")
  assert_eq(@native_wenyu_import.persist(root, payload), receipt)
}
