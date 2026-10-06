///|
fn native_wenyu_check_review_intent(
  binding : NativeWenyuReviewResolution,
  key : String,
  intent_text : String,
  receipt_text : String,
) -> Unit raise {
  let intent_json = @json.parse(intent_text)
  native_wenyu_exact_fields(intent_json, [
    "contract", "root", "identity", "payload_text", "outcome", "writes",
  ])
  guard intent_json is Object(intent_fields) else {
    fail("native review import intent must be an object")
  }
  native_wenyu_exact_fields(intent_fields["identity"], [
    "contract", "work_id", "request_digest", "payload_digest",
  ])
  let intent : NativeWenyuIntent = @json.from_json(intent_json)
  guard intent.contract == "moonbook.native-wenyu-intent.v1" &&
    intent.root == binding.root else {
    fail("native review import intent root or contract mismatch")
  }
  let (identity, result, canonical_payload) = decode_native_wenyu_import({
    "native_import": intent.identity.to_json(),
    "book_result": @json.parse(intent.payload_text),
  })
  guard identity.work_id == binding.work_id &&
    identity.request_digest == binding.request_digest &&
    identity.payload_digest == binding.payload_digest &&
    result.result_id == binding.result_id &&
    canonical_payload == intent.payload_text else {
    fail("native review import intent identity or canonical payload mismatch")
  }
  let expected : PersistResultOutcome = {
    log_path: binding.root + "/wiki/log.md",
    updated_pages: [
      "synthesis/observations.md", "synthesis/evidence.md", "reviews/pending.md",
      "history/journey.md", "history/debug-journal.md", "SUMMARY.md", "index.md",
    ],
    review_queued: true,
    notify_town: true,
    evidence_id: binding.evidence_id,
    executable_event_path: "events/native-wenyu-\{key}.json",
    latest_executable_event_path: "events/latest.json",
    executable_event: native_wenyu_event(
      binding.root,
      result,
      binding.evidence_id,
    ),
  }
  // Compare wire objects directly as well as decoding them: unknown or omitted
  // receipt fields cannot disappear through FromJson defaults.
  let receipt_json = @json.parse(receipt_text)
  guard receipt_json == expected.to_json() &&
    intent_fields["outcome"] == expected.to_json() &&
    intent.outcome.to_json() == expected.to_json() else {
    fail("native review import receipt or outcome does not match its binding")
  }
  let pending_writes = intent.writes.filter(write => {
    write.path == "wiki/reviews/pending.md"
  })
  let evidence_writes = intent.writes.filter(write => {
    write.path == "wiki/synthesis/evidence.md"
  })
  guard pending_writes is [pending] && evidence_writes is [evidence] else {
    fail(
      "native review import intent lacks unique prepared review and evidence",
    )
  }
  let initial = native_wenyu_classify_review(
    binding,
    pending.after,
    "",
    evidence.after,
  )
  guard initial.status == Pending else {
    fail("native review import intent does not bind a pending review")
  }
}

///|
async fn read_native_wenyu_review(
  binding : NativeWenyuReviewResolution,
  key : String,
) -> NativeWenyuReviewResolution {
  let root = binding.root
  guard root.has_prefix("/") &&
    root != "/" &&
    @pathx.normalize(root) == root &&
    @fs.realpath(root) == root &&
    native_wenyu_kind(root) == Some(Directory) else {
    fail("native review requires an existing canonical non-symlink Book root")
  }
  let paths = [
    ".moonbook/native-wenyu-imports/\{key}.intent.json",
    ".moonbook/native-wenyu-imports/\{key}.receipt.json",
    "wiki/reviews/pending.md",
    "wiki/reviews/approved.md",
    "wiki/synthesis/evidence.md",
  ]
  let snapshot : Array[String?] = []
  for path in paths {
    snapshot.push(native_wenyu_read(root, path))
  }
  guard snapshot[0] is Some(intent) && snapshot[1] is Some(receipt) else {
    fail("native review requires a committed import intent and receipt")
  }
  native_wenyu_check_review_intent(binding, key, intent, receipt)
  guard snapshot[2] is Some(pending) && snapshot[4] is Some(evidence) else {
    fail("native review pending or evidence page is missing")
  }
  let resolution = native_wenyu_classify_review(
    binding,
    pending,
    snapshot[3].unwrap_or(""),
    evidence,
  )
  // Existing human approval uses multiple file writes and has no shared lock.
  // Reread all bound records; a moving or partially observed projection must be
  // retried by the caller, without repairing or serializing a human decision.
  for index in 0..<paths.length() {
    guard native_wenyu_read(root, paths[index]) == snapshot[index] else {
      fail("native review records changed while being observed")
    }
  }
  guard @fs.realpath(root) == root && native_wenyu_kind(root) == Some(Directory) else {
    fail("native review root changed while being observed")
  }
  resolution
}
