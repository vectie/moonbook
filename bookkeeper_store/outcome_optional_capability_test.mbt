///|
fn optional_public_reference(
  id : String,
) -> @bookkeeper.VersionedRecordReference {
  {
    record_id: id,
    record_version: "1",
    record_digest: "sha256:" + "a".repeat(64),
  }
}

///|
async fn optional_public_accept(
  root : String,
  record : @bookkeeper_store.DurableBookkeeperRecord,
  suffix : String,
) -> @bookkeeper_store.GovernedReviewReceipt {
  let grant = optional_public_reference("grant-" + suffix)
  let evidence_ids = record.evidence_refs.map(reference => {
    reference.reference_id
  })
  ignore(
    @bookkeeper_store.install_bookkeeper_authority_grant(root, {
      contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
      grant,
      reviewer_id: "public-reviewer-" + suffix,
      reviewer_kind: @bookkeeper.Human,
      authority_ref: "fixture://authority-" + suffix,
      evidence_refs: evidence_ids,
      active: true,
      granted_at: record.recorded_at,
    }),
  )
  let result = @bookkeeper_store.apply_governed_review(root, {
    contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
    mutation: optional_public_reference("mutation-" + suffix),
    receipt: optional_public_reference("receipt-" + suffix),
    stage: record.stage,
    subject: record.record,
    requested: @bookkeeper.Accept,
    reviewer_kind: @bookkeeper.Human,
    reviewer: {
      grant,
      reviewer_id: "public-reviewer-" + suffix,
      authority_ref: "fixture://authority-" + suffix,
      authorized: true,
      evidence_refs: evidence_ids,
    },
    evidence_refs: record.evidence_refs,
    summary: "Synthetic explicit public-API human review",
    decided_at: record.recorded_at + 1,
  })
  assert_true(result.accepted)
  result.review.unwrap()
}

///|
async test "external native callers construct and read Some and None requests through submit and close" {
  for supplied in [false, true] {
    let root = @fs.tmpdir(prefix="book-public-optional-capability-")
    let gap : @bookkeeper_store.ProductOutcomeGapStatement = {
      present: false,
      severity: 0,
      summary: "No gap observed in a synthetic native fixture",
      evidence_refs: ["observed-evidence"],
    }
    let submission : @bookkeeper_store.ProductOutcomeSubmission = {
      contract_version: @bookkeeper_store.product_outcome_submission_contract_version(),
      submission: optional_public_reference("public-submission"),
      source_product: "example-product",
      deliverable_title: "Synthetic work",
      deliverable_summary: "Evidence for the existing review",
      outcome_summary: "The outcome met its criterion",
      owner_route: "fixture://owner",
      evidence_refs: [
        {
          reference_id: "observed-evidence",
          reference_version: "1",
          digest: "sha256:" + "b".repeat(64),
          provenance_ref: "fixture://observation",
        },
      ],
      decision_evidence_id: "observed-evidence",
      observed_at: 1,
      recorded_at: 2,
      information_gap: gap,
      recognition_gap: gap,
      decisiveness_gap: gap,
      capability_id: if supplied {
        Some("existing-example-capability")
      } else {
        None
      },
      capability_version: if supplied {
        Some("1")
      } else {
        None
      },
      capability_change_digest: if supplied {
        Some("sha256:" + "c".repeat(64))
      } else {
        None
      },
      capability_summary: if supplied {
        Some("Keep the legacy description")
      } else {
        None
      },
    }
    match submission.capability_id {
      Some(id) => {
        assert_true(supplied)
        assert_eq(id, "existing-example-capability")
      }
      None => assert_false(supplied)
    }
    let first = @bookkeeper_store.submit_product_outcome(root, submission)
    assert_eq(first.state, "deliverable_review_required")
    let deliverable = @bookkeeper_store.replay_bookkeeper_store(root).records.filter(record => {
          record.record == first.deliverable
        },
      )[0]
    let review = optional_public_accept(root, deliverable, "deliverable")
    let request : @bookkeeper_store.ProductOutcomeClosureRequest = {
      contract_version: @bookkeeper_store.product_outcome_closure_contract_version(),
      request: submission.submission,
      source_product: submission.source_product,
      deliverable: first.deliverable,
      result: first.result,
      deliverable_review: review.receipt,
      observed_at: submission.observed_at,
      recorded_at: submission.recorded_at,
      outcome_summary: submission.outcome_summary,
      owner_route: submission.owner_route,
      evidence_refs: submission.evidence_refs,
      information_gap: submission.information_gap,
      recognition_gap: submission.recognition_gap,
      decisiveness_gap: submission.decisiveness_gap,
      capability_id: submission.capability_id,
      capability_version: submission.capability_version,
      capability_change_digest: submission.capability_change_digest,
      capability_summary: submission.capability_summary,
    }
    let second = @bookkeeper_store.close_product_outcome(root, request)
    assert_eq(second.state, "assessment_review_required")
    let assessment = @bookkeeper_store.replay_bookkeeper_store(root).records.filter(record => {
          record.record == second.three_gap_assessment
        },
      )[0]
    assert_eq(
      assessment.summary,
      if supplied {
        "Keep the legacy description"
      } else {
        submission.outcome_summary
      },
    )
    ignore(optional_public_accept(root, assessment, "assessment"))
    assert_eq(
      @bookkeeper_store.close_product_outcome(root, request).state,
      "closed_no_capability_change",
    )
    let final_snapshot = @bookkeeper_store.replay_bookkeeper_store(root)
    assert_eq(
      @bookkeeper_store.submit_product_outcome(root, submission).state,
      "closed_no_capability_change",
    )
    assert_eq(@bookkeeper_store.replay_bookkeeper_store(root), final_snapshot)
  }
}
