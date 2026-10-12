///|
// A portable source package is retained evidence, not another acceptance gate.
// All supplied evidence bytes remain available after decline, defer or restart.
fn outcome_source_digest(text : String) -> String {
  "sha256:" +
  @crypto.bytes_to_hex_string(@crypto.sha256(@encoding/utf8.encode(text)))
}

///|
fn decode_product_outcome_package(
  value : Json,
) -> ProductOutcomeSubmission raise {
  guard value
    is {
      "contract_version": "moonbook.product-outcome-package.v1",
      "package_digest": String(digest),
      "payload_json": String(text),
      ..
    } else {
    fail("Choose a portable product outcome package")
  }
  if @encoding/utf8.encode(text).length() > 8 * 1024 * 1024 ||
    outcome_source_digest(text) != digest {
    fail("Outcome package bytes changed or exceed 8 MiB")
  }
  guard @json.parse(text)
    is { "submission": value, "artifacts": Array(artifacts), .. } else {
    fail(
      "Outcome package requires its original submission and retained evidence",
    )
  }
  let submission : ProductOutcomeSubmission = @json.from_json(value)
  validate_product_outcome_submission(submission)
  if artifacts.length() != submission.evidence_refs.length() {
    fail("Retain every supplied evidence artifact exactly once")
  }
  let seen : Map[String, Bool] = Map([])
  for artifact in artifacts {
    guard artifact
      is {
        "reference": value,
        "text": String(bytes),
        "media_type": String(media),
        ..
      } else {
      fail("Retained evidence requires reference, text and media type")
    }
    let reference : @bookkeeper.VersionedEvidenceReference = @json.from_json(
      value,
    )
    if media.is_blank() ||
      seen.contains(reference.reference_id) ||
      !submission.evidence_refs.contains(reference) ||
      outcome_source_digest(bytes) != reference.digest {
      fail("Retained evidence does not match the exact submission")
    }
    seen[reference.reference_id] = true
  }
  submission
}

///|
fn product_outcome_packages(
  snapshot : BookkeeperStoreSnapshot,
) -> Array[(ProductOutcomeSubmission, Json, DurableBookkeeperRecord)] raise {
  if !snapshot.replay_issues.is_empty() {
    fail("Bookkeeper journal has replay issues")
  }
  let result : Array[(ProductOutcomeSubmission, Json, DurableBookkeeperRecord)] = []
  for envelope in snapshot.envelopes {
    if envelope.direction != Ingress ||
      envelope.message_kind != "product.outcome_package" {
      continue
    }
    let submission = decode_product_outcome_package(envelope.payload)
    guard find_record(snapshot, envelope.subject) is Some(deliverable) &&
      deliverable.stage == DeliverableAcceptance &&
      lesson_handoff_field(deliverable.payload, "product_outcome_submission") ==
      submission.to_json() else {
      fail("Saved source package has no matching deliverable")
    }
    if result.any(item => item.0.submission == submission.submission) {
      fail("Saved source package is ambiguous")
    }
    result.push((submission, envelope.payload, deliverable))
  }
  result
}

///|
fn product_package_readback(
  snapshot : BookkeeperStoreSnapshot,
  submission : ProductOutcomeSubmission,
  source_pack : Json,
  deliverable : DurableBookkeeperRecord,
) -> Json raise {
  let progress = task_outcome_progress(snapshot, submission, deliverable)
  let reviews = snapshot.reviews.filter(review => {
    (
      review.subject == deliverable.record &&
      review.stage == DeliverableAcceptance
    ) ||
    snapshot.records.any(record => {
      record.record == review.subject &&
      record.stage == ThreeGapFinding &&
      review.stage == ThreeGapFinding &&
      lesson_handoff_field(record.payload, "request") ==
      submission.submission.to_json() &&
      snapshot.records.any(outcome => {
        outcome.stage == OutcomeBinding &&
        outcome.source_product == submission.source_product &&
        outcome.subject == Some(deliverable.record) &&
        record.subject == Some(outcome.record) &&
        record.links.contains(outcome.record) &&
        lesson_handoff_field(outcome.payload, "request") ==
        submission.submission.to_json()
      })
    })
  })
  {
    "contract_version": "moonbook.product-outcome-readback.v1",
    "package_digest": lesson_handoff_field(source_pack, "package_digest"),
    "package": source_pack,
    "progress": progress,
    "reviews": reviews.to_json(),
    "activation_authorized": false,
    "external_side_effects_applied": false,
  }
}

///|
// The host owns root; packages cannot install review authority or choose paths.
async fn product_outcome_package_operation(
  root : String,
  operation : String,
  payload : Json,
) -> Json {
  let snapshot = replay_bookkeeper_store(root)
  let saved = product_outcome_packages(snapshot)
  if operation == "product-list" {
    return {
      "items": saved.map(item => task_outcome_progress(snapshot, item.0, item.2)),
    }
  }
  let (submission, source_pack) = if operation == "product-import" {
    let incoming = decode_product_outcome_package(payload)
    // Check both prior packages and generic submissions before any write.
    for record in snapshot.records {
      if record.stage != DeliverableAcceptance {
        continue
      }
      let original = lesson_handoff_field(
        record.payload,
        "product_outcome_submission",
      )
      if original is Null {
        continue
      }
      let existing : ProductOutcomeSubmission = @json.from_json(original)
      if existing.submission.record_id == incoming.submission.record_id &&
        existing.submission.record_version == incoming.submission.record_version &&
        existing != incoming {
        fail(
          "This outcome version already has different content; retain the original or export a new version",
        )
      }
    }
    for (existing, original, _) in saved {
      if existing.submission == incoming.submission && original != payload {
        fail("The saved source package differs; reopen its original bytes")
      }
    }
    (incoming, payload)
  } else {
    let reference : @bookkeeper.VersionedRecordReference = @json.from_json(
      lesson_handoff_field(payload, "submission"),
    )
    guard saved.filter(item => item.0.submission == reference)
      is [(submission, source_pack, _)] else {
      fail(
        "Exact saved outcome is unavailable; refresh or import its original package",
      )
    }
    (submission, source_pack)
  }
  if operation == "product-import" || operation == "product-continue" {
    let (deliverable, result) = intake_product_outcome(root, submission)
    submission_require_persisted(
      persist_transport_envelope(root, {
        contract_version: bookkeeper_transport_contract_version(),
        envelope: submission_record_reference(
          submission, "source-package", source_pack,
        ),
        direction: Ingress,
        source_product: submission.source_product,
        destination_product: "moonbook",
        message_kind: "product.outcome_package",
        subject: deliverable,
        links: [result],
        evidence_refs: submission.evidence_refs,
        authority_ref: "evidence-only://" + submission.decision_evidence_id,
        recorded_at: submission.recorded_at,
        payload: source_pack,
        external_activation_allowed: false,
        side_effects_applied: false,
      }),
      "retained outcome source package",
    )
    if operation == "product-continue" {
      let current = replay_bookkeeper_store(root)
      if product_outcome_exact_human_decision(
          current,
          deliverable,
          DeliverableAcceptance,
        )
        is Some(review) &&
        review.disposition == @bookkeeper.Accept {
        ignore(
          prepare_product_outcome_assessment(
            root,
            submission_closure_request(submission, deliverable, result, review),
          ),
        )
      }
    }
  }
  let current = replay_bookkeeper_store(root)
  guard product_outcome_packages(current).filter(item => {
      item.0.submission == submission.submission
    })
    is [(submission, source_pack, deliverable)] else {
    fail(
      "Saved source package readback is unavailable; retry the exact package",
    )
  }
  product_package_readback(current, submission, source_pack, deliverable)
}
