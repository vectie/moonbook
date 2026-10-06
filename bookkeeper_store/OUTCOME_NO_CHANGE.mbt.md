# Outcomes without a capability change

The existing v1 submission and closure wires allow all four `capability_*`
properties to be absent together only when every supplied gap explicitly has
`present: false` and `severity: 0`. Gap summaries, evidence, exact references and
the existing named-human reviews are still required. Absence is not a placeholder
capability identity. A partial group, null value, or present gap without a real
complete descriptor is rejected.

The native request structs retain their field names and use `String?` for these
four fields. Existing typed callers wrap their supplied strings in `Some`.
Use four `None` values for an explicitly no-gap outcome. The JSON encoder still
emits ordinary flat strings for a supplied descriptor, preserving complete legacy
wire bytes. It emits no capability keys for absence; it does not emit Option
arrays, nulls, empty identities, or a synthetic no-change capability.
This is a native source-level field-type change: readers that previously expected
`String` must now match or otherwise handle `Option`. Existing entry-point
function signatures are retained; the public API is not claimed to be unchanged.

This synthetic example enters the same existing deliverable-review gate:

```mbt check
///|
async test "public no-change submission omits capability keys and still requires review" {
  let gap : @bookkeeper_store.ProductOutcomeGapStatement = {
    present: false,
    severity: 0,
    summary: "No gap observed in this synthetic example.",
    evidence_refs: ["example-evidence"],
  }
  let submission : @bookkeeper_store.ProductOutcomeSubmission = {
    contract_version: @bookkeeper_store.product_outcome_submission_contract_version(),
    submission: {
      record_id: "example-outcome",
      record_version: "1",
      record_digest: "sha256:" + "a".repeat(64),
    },
    source_product: "example-product",
    deliverable_title: "Synthetic reviewed work",
    deliverable_summary: "Evidence supplied for review.",
    outcome_summary: "The observed result met the stated criterion.",
    owner_route: "fixture://example-owner",
    evidence_refs: [
      {
        reference_id: "example-evidence",
        reference_version: "1",
        digest: "sha256:" + "b".repeat(64),
        provenance_ref: "fixture://example-evidence",
      },
    ],
    decision_evidence_id: "example-evidence",
    observed_at: 1,
    recorded_at: 2,
    information_gap: gap,
    recognition_gap: gap,
    decisiveness_gap: gap,
    capability_id: None,
    capability_version: None,
    capability_change_digest: None,
    capability_summary: None,
  }
  guard submission.to_json() is Object(fields) else {
    fail("submission object")
  }
  assert_false(fields.contains("capability_id"))
  let restored : @bookkeeper_store.ProductOutcomeSubmission = @json.from_json(
    submission.to_json(),
  )
  assert_eq(restored, submission)
  let root = @fs.tmpdir(prefix="moonbook-public-no-change-")
  let receipt = @bookkeeper_store.submit_product_outcome(root, submission)
  assert_eq(receipt.state, "deliverable_review_required")
  assert_true(
    @bookkeeper_store.replay_bookkeeper_store(root).reviews.is_empty(),
  )
  let legacy = {
    ..submission,
    capability_id: Some("example-existing-capability"),
    capability_version: Some("1"),
    capability_change_digest: Some("sha256:" + "c".repeat(64)),
    capability_summary: Some("The original supplied capability description."),
  }
  match legacy.capability_id {
    Some(id) => assert_eq(id, "example-existing-capability")
    None => fail("The supplied descriptor must remain present")
  }
  assert_true(
    legacy.to_json()
    is { "capability_id": String(_), "capability_summary": String(_), .. },
  )
  let closure : @bookkeeper_store.ProductOutcomeClosureRequest = {
    contract_version: @bookkeeper_store.product_outcome_closure_contract_version(),
    request: legacy.submission,
    source_product: legacy.source_product,
    deliverable: legacy.submission,
    result: legacy.submission,
    deliverable_review: legacy.submission,
    observed_at: legacy.observed_at,
    recorded_at: legacy.recorded_at,
    outcome_summary: legacy.outcome_summary,
    owner_route: legacy.owner_route,
    evidence_refs: legacy.evidence_refs,
    information_gap: legacy.information_gap,
    recognition_gap: legacy.recognition_gap,
    decisiveness_gap: legacy.decisiveness_gap,
    capability_id: legacy.capability_id,
    capability_version: legacy.capability_version,
    capability_change_digest: legacy.capability_change_digest,
    capability_summary: legacy.capability_summary,
  }
  let restored_closure : @bookkeeper_store.ProductOutcomeClosureRequest = @json.from_json(
    closure.to_json(),
  )
  assert_eq(restored_closure, closure)
}
```

After the existing deliverable and assessment reviews, the no-gap path returns
`closed_no_capability_change`. Its assessment summary uses `outcome_summary` only
when the descriptor is absent. A complete legacy no-gap request keeps its supplied
descriptor and `capability_summary`; it is never rewritten into the omitted form.
Changing descriptor presence for an already-saved identity is a content change,
not an idempotent replay.

Both direct and unattended MoonBook adapters decode these same request types.
The Book UI forwards raw imported JSON to the same native validator. Separate
producer schemas, including MoonClaw's supervisor outcome contract, are not
changed or qualified to emit omitted fields by this Book feature.
