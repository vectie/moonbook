///|
async fn native_review_test_query(
  root : String,
  work_id? : String = "native-work-1",
  request_digest? : String = native_wenyu_digest("frozen-request"),
  payload_digest? : String = native_wenyu_digest(
    native_wenyu_test_result().to_json().stringify(),
  ),
  result_id? : String = "wenyu-goal-1-code-patch",
) -> NativeWenyuReviewResolution {
  resolve_review(root, work_id, request_digest, payload_digest, result_id)
}

///|
// Mirror only the established manual writer's on-disk shape. The wiki test uses
// the real approve/reject API to guard this fixture against writer drift.
async fn native_review_test_finalize(
  root : String,
  disposition : String,
) -> Unit {
  let pending = @fsx.read_file(root + "/wiki/reviews/pending.md")
  let key = native_wenyu_digest("native-work-1")
  let review_id = "result-review-native-wenyu-\{key}"
  @fsx.write_to_file(
    root + "/wiki/reviews/pending.md",
    "# Pending Review\n\n## Items\n\n_None yet._\n",
  )
  @fsx.write_to_file(
    root + "/wiki/reviews/approved.md",
    pending
    .replace(old="- Status: `pending`", new="- Status: `\{disposition}`")
    .to_string() +
    "- Resolution: `\{disposition}` at `1730000000`\n",
  )
  let evidence = @fsx.read_file(root + "/wiki/synthesis/evidence.md")
  @fsx.write_to_file(
    root + "/wiki/synthesis/evidence.md",
    evidence
    .replace(old="- Status: `pending-review`", new="- Status: `\{disposition}`")
    .to_string() +
    "- Review note: review \{disposition} for \{review_id}\n",
  )
}

///|
async fn native_review_test_snapshot(root : String) -> Array[(String, String)] {
  let paths = @fsx.list_directory(root)
  let snapshot : Array[(String, String)] = []
  for path in paths {
    match @fs.kind(path, follow_symlink=false) {
      Directory =>
        for pair in native_review_test_snapshot(path) {
          snapshot.push(pair)
        }
      Regular => snapshot.push((path, @fsx.read_file(path)))
      _ => ()
    }
  }
  snapshot
}

///|
async test "native review approved and rejected readback preserves every file and historical receipt" {
  for disposition in ["approved", "rejected"] {
    let root = @fs.tmpdir(prefix="moonbook-review-final-")
    let original = persist(root, native_wenyu_test_payload())
    native_review_test_finalize(root, disposition)
    let before = native_review_test_snapshot(root)
    let resolved = native_review_test_query(root)
    assert_eq(
      resolved.status,
      if disposition == "approved" {
        Approved
      } else {
        Rejected
      },
    )
    assert_eq(resolved.resolution_timestamp, Some("1730000000"))
    assert_eq(resolved.original_task_acceptance, "unevaluated")
    assert_eq(native_review_test_query(root).to_json(), resolved.to_json())
    assert_eq(native_review_test_snapshot(root), before)
    assert_eq(persist(root, native_wenyu_test_payload()), original)
    assert_eq(native_review_test_query(root).to_json(), resolved.to_json())
    assert_eq(native_review_test_snapshot(root), before)
  }
}

///|
async test "native review exact identity isolates same result across work and request generations" {
  let root = @fs.tmpdir(prefix="moonbook-review-isolation-")
  ignore(persist(root, native_wenyu_test_payload()))
  native_review_test_finalize(root, "approved")
  ignore(
    persist(
      root,
      native_wenyu_test_payload(
        work_id="native-work-2",
        request_digest=native_wenyu_digest("generation-2"),
      ),
    ),
  )
  let before = native_review_test_snapshot(root)
  assert_eq(native_review_test_query(root).status, Approved)
  assert_eq(
    native_review_test_query(
      root,
      work_id="native-work-2",
      request_digest=native_wenyu_digest("generation-2"),
    ).status,
    Pending,
  )
  assert_eq(
    native_review_test_query(root, work_id="native-work-2").status,
    Unresolved,
  )
  assert_eq(
    native_review_test_query(
      root,
      request_digest=native_wenyu_digest("generation-2"),
    ).status,
    Unresolved,
  )
  assert_eq(
    native_review_test_query(
      root,
      payload_digest=native_wenyu_digest("pretty or package json"),
    ).status,
    Unresolved,
  )
  assert_eq(
    native_review_test_query(root, result_id="forged-result").status,
    Unresolved,
  )
  assert_eq(
    native_review_test_query(root, work_id="absent-work").status,
    Unresolved,
  )
  let other = @fs.tmpdir(prefix="moonbook-review-other-")
  assert_eq(native_review_test_query(other).status, Unresolved)
  assert_eq(@fsx.list_directory(other).length(), 0)
  assert_eq(native_review_test_snapshot(root), before)
}

///|
async test "native pending review never infers approval from removal or partial evidence" {
  let root = @fs.tmpdir(prefix="moonbook-review-pending-debt-")
  ignore(persist(root, native_wenyu_test_payload()))
  let path = root + "/wiki/reviews/pending.md"
  let pending = @fsx.read_file(path)
  for
    changed in [
      "# Pending Review\n\n## Items\n\n_None yet._\n",
      pending + pending,
      pending + "- Resolution: `approved` at `1730000000`\n",
      pending
      .replace(old="- Status: `pending`", new="- Status: `approved`")
      .to_string(),
    ] {
    @fsx.write_to_file(path, changed)
    assert_eq(native_review_test_query(root).status, Unresolved)
    assert_eq(@fsx.read_file(path), changed)
  }
  @fsx.write_to_file(path, pending)
  assert_eq(native_review_test_query(root).status, Pending)
  @fs.rename(path, path + ".missing")
  assert_eq(native_review_test_query(root).status, Unresolved)
  assert_true(!@fsx.exists(path))
}

///|
async test "native review fails closed for partial conflicting duplicate and mismatched final records" {
  let root = @fs.tmpdir(prefix="moonbook-review-invalid-records-")
  ignore(persist(root, native_wenyu_test_payload()))
  let original_pending = @fsx.read_file(root + "/wiki/reviews/pending.md")
  native_review_test_finalize(root, "approved")
  let pending = @fsx.read_file(root + "/wiki/reviews/pending.md")
  let finalized = @fsx.read_file(root + "/wiki/reviews/approved.md")
  let evidence = @fsx.read_file(root + "/wiki/synthesis/evidence.md")
  let key = native_wenyu_digest("native-work-1")
  let review_id = "result-review-native-wenyu-\{key}"
  let wrong_digest = native_wenyu_digest("wrong")
  let cases : Array[(String, String, String)] = [
    (original_pending, finalized, evidence),
    (pending, finalized + finalized, evidence),
    (pending, finalized, evidence + evidence),
    (pending, "", evidence),
    (pending, finalized, ""),
    (
      pending,
      finalized
      .replace(old="- Resolution: `approved` at `1730000000`", new="")
      .to_string(),
      evidence,
    ),
    (
      pending,
      finalized + "- Resolution: `approved` at `1730000000`\n",
      evidence,
    ),
    (
      pending,
      finalized
      .replace(
        old="`approved` at `1730000000`",
        new="`rejected` at `1730000000`",
      )
      .to_string(),
      evidence,
    ),
    (
      pending,
      finalized
      .replace(old="at `1730000000`", new="at `not-a-timestamp`")
      .to_string(),
      evidence,
    ),
    (pending, finalized + "- Status: `approved`\n", evidence),
    (
      pending,
      finalized
      .replace(old="- Status: `approved`", new="- Status: approved")
      .to_string(),
      evidence,
    ),
    (
      pending,
      finalized
      .replace(
        old="### Result review | wenyu-goal-1-code-patch",
        new="### Result review | forged",
      )
      .to_string(),
      evidence,
    ),
    (
      pending,
      finalized
      .replace(
        old="[wenyu-goal-1-code-patch](../synthesis/observations.md)",
        new="[forged](../synthesis/observations.md)",
      )
      .to_string(),
      evidence,
    ),
    (
      pending,
      finalized
      .replace(
        old="- Native work: `native-work-1`",
        new="- Native work: `wrong-work`",
      )
      .to_string(),
      evidence,
    ),
    (
      pending,
      finalized
      .replace(
        old="- Request digest: `\{native_wenyu_digest("frozen-request")}`",
        new="- Request digest: `\{wrong_digest}`",
      )
      .to_string(),
      evidence,
    ),
    (
      pending,
      finalized
      .replace(
        old="- Payload digest: `\{native_wenyu_digest(native_wenyu_test_result().to_json().stringify())}`",
        new="- Payload digest: `\{wrong_digest}`",
      )
      .to_string(),
      evidence,
    ),
    (
      pending,
      finalized
      .replace(
        old="- Evidence ID: `EV-native-wenyu-\{key}`",
        new="- Evidence ID: `other-evidence`",
      )
      .to_string(),
      evidence,
    ),
    (
      pending,
      finalized
      .replace(
        old="- Review ID: `\{review_id}`",
        new="- Review ID: `wrong-review`",
      )
      .to_string(),
      evidence,
    ),
    (
      pending,
      finalized,
      evidence
      .replace(
        old="- Task ID: `wenyu-goal-1-code-patch`",
        new="- Task ID: `forged`",
      )
      .to_string(),
    ),
    (
      pending,
      finalized,
      evidence
      .replace(old="- Status: `approved`", new="- Status: `pending-review`")
      .to_string(),
    ),
    (
      pending,
      finalized,
      evidence
      .replace(old="- Review note: review approved for \{review_id}", new="")
      .to_string(),
    ),
    (
      pending,
      finalized,
      evidence
      .replace(
        old="review approved for \{review_id}",
        new="review rejected for \{review_id}",
      )
      .to_string(),
    ),
    (pending, finalized, evidence + "- Status: `approved`\n"),
    (
      pending,
      finalized
      .replace(old="- Resolution:", new="## Another section\n\n- Resolution:")
      .to_string(),
      evidence,
    ),
  ]
  for index in 0..<cases.length() {
    let (pending_case, final_case, evidence_case) = cases[index]
    @fsx.write_to_file(root + "/wiki/reviews/pending.md", pending_case)
    @fsx.write_to_file(root + "/wiki/reviews/approved.md", final_case)
    @fsx.write_to_file(root + "/wiki/synthesis/evidence.md", evidence_case)
    let before = native_review_test_snapshot(root)
    let result = native_review_test_query(root)
    guard result.status == Unresolved else {
      fail("invalid case \{index}: \{result.reason}")
    }
    assert_eq(result.resolution_timestamp, None)
    assert_eq(native_review_test_snapshot(root), before)
  }
}

///|
async test "native review missing corrupt mismatched and noncanonical committed bindings never resolve" {
  let root = @fs.tmpdir(prefix="moonbook-review-invalid-commit-")
  ignore(persist(root, native_wenyu_test_payload()))
  native_review_test_finalize(root, "approved")
  let key = native_wenyu_digest("native-work-1")
  let intent_path = root + "/.moonbook/native-wenyu-imports/\{key}.intent.json"
  let receipt_path = root +
    "/.moonbook/native-wenyu-imports/\{key}.receipt.json"
  let original_intent = @fsx.read_file(intent_path)
  let original_receipt = @fsx.read_file(receipt_path)
  let intent : NativeWenyuIntent = @json.from_json(@json.parse(original_intent))
  for
    changed in [
      "broken-json",
      { ..intent, root: root + "-wrong", }.to_json().stringify(),
      {
        ..intent,
        payload_text: @json.parse(intent.payload_text).stringify(indent=2),
      }
      .to_json()
      .stringify(),
      { ..intent, writes: [], }.to_json().stringify(),
      {
        ..intent,
        identity: {
          ..intent.identity,
          request_digest: native_wenyu_digest("wrong"),
        },
      }
      .to_json()
      .stringify(),
    ] {
    @fsx.write_to_file(intent_path, changed)
    assert_eq(native_review_test_query(root).status, Unresolved)
    assert_eq(@fsx.read_file(intent_path), changed)
  }
  @fsx.write_to_file(intent_path, original_intent)
  for
    changed in [
      "broken-json",
      "{}",
      original_receipt
      .replace(old="review_required", new="accepted")
      .to_string(),
    ] {
    @fsx.write_to_file(receipt_path, changed)
    assert_eq(native_review_test_query(root).status, Unresolved)
    assert_eq(@fsx.read_file(receipt_path), changed)
  }
  @fsx.write_to_file(receipt_path, original_receipt)
  @fs.rename(receipt_path, receipt_path + ".absent")
  assert_eq(native_review_test_query(root).status, Unresolved)
  assert_true(!@fsx.exists(receipt_path))
  @fs.rename(receipt_path + ".absent", receipt_path)
  @fs.rename(intent_path, intent_path + ".absent")
  assert_eq(native_review_test_query(root).status, Unresolved)
  assert_true(!@fsx.exists(intent_path))
  @fs.rename(intent_path + ".absent", intent_path)
  assert_eq(native_review_test_query(root).status, Approved)
  assert_eq(native_review_test_query(root + "/.").status, Unresolved)
}

///|
async test "native review rejects root parent and destination symlinks without writes" {
  let root = @fs.tmpdir(prefix="moonbook-review-symlink-")
  ignore(persist(root, native_wenyu_test_payload()))
  native_review_test_finalize(root, "approved")
  let outside = @fs.tmpdir(prefix="moonbook-review-link-container-")
  @fs.symlink(target=root, outside + "/linked-root")
  assert_eq(
    native_review_test_query(outside + "/linked-root").status,
    Unresolved,
  )
  for
    relative in [
      "wiki/reviews/approved.md",
      "wiki/synthesis/evidence.md",
      ".moonbook/native-wenyu-imports/\{native_wenyu_digest("native-work-1")}.receipt.json",
      "wiki/reviews",
      ".moonbook/native-wenyu-imports",
    ] {
    let path = root + "/" + relative
    @fs.rename(path, path + ".original")
    @fs.symlink(target=path + ".original", path)
    assert_eq(native_review_test_query(root).status, Unresolved)
    @fs.rename(path, path + ".rejected-link")
    @fs.rename(path + ".original", path)
  }
  assert_eq(native_review_test_query(root).status, Approved)
}
