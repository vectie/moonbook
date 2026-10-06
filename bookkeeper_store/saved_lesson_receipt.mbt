///|
/// Read-only return projection of existing journal facts. A candidate admission
/// is not a review; this function never creates acceptance or a new ledger.
fn saved_task_lesson_receipts(
  snapshot : BookkeeperStoreSnapshot,
  handoff : OutcomeLessonTaskHandoff,
  submission : @bookkeeper.VersionedRecordReference,
  outcome : @bookkeeper.VersionedRecordReference,
  assessment : @bookkeeper.VersionedRecordReference,
  assessment_review : @bookkeeper.VersionedRecordReference,
) -> Array[Json] raise {
  let receipts : Array[Json] = []
  for record in snapshot.records {
    let draft = match outcome_lesson_draft(record) {
      Some(draft) if draft.outcome == outcome &&
        draft.assessment == assessment &&
        draft.assessment_review == assessment_review => draft
      _ => continue
    }
    // Replay already checked revision admission at its original position. A
    // later reviewed current choice must not invalidate a historical artifact.
    ignore(outcome_lesson_source(snapshot, draft))
    let review = product_outcome_exact_human_decision(
      snapshot,
      record.record,
      DeliverableAcceptance,
    )
    if review is Some(review) {
      if !review.issues.is_empty() ||
        review.side_effects_applied ||
        !review.reviewer.authorized ||
        review.reviewer.reviewer_id.is_blank() ||
        !review_subject_evidence_exact(record, review.evidence_refs) {
        fail(
          "The saved lesson review is not a clean exact named-human decision",
        )
      }
    }
    let state = match review {
      Some(review) if review.disposition == @bookkeeper.Accept => "retained"
      Some(review) if review.disposition == @bookkeeper.Reject => "rejected"
      _ => "pending"
    }
    let (head, current, _) = lesson_version_state(snapshot, draft.lesson_id)
    let currentness = if state != "retained" {
      "not_retained"
    } else if current == Some(record.record) {
      "current"
    } else if head is None && current is None {
      "legacy_unselected"
    } else {
      "historical"
    }
    receipts.push({
      "contract_version": "moonbook.saved-lesson-receipt.v1",
      "source_product": "moonbook",
      "destination_product": "moonproj",
      "task": handoff.task.to_json(),
      "report": handoff.report.to_json(),
      "submission": submission.to_json(),
      "outcome": outcome.to_json(),
      "assessment": assessment.to_json(),
      "assessment_review": assessment_review.to_json(),
      "lesson": record.record.to_json(),
      "lesson_id": draft.lesson_id,
      "title": draft.title,
      "state": state,
      "review": match review {
        Some(review) =>
          {
            "receipt": review.receipt.to_json(),
            "disposition": if review.disposition == @bookkeeper.Accept {
              "Accept"
            } else {
              "Reject"
            },
            "reviewer_id": review.reviewer.reviewer_id,
            "decided_at": review.decided_at,
          }
        None => Json::null()
      },
      "current": lesson_nullable_reference(current),
      "selection_review": lesson_nullable_reference(head),
      "currentness": currentness,
      "journal_sequence": snapshot.last_sequence,
      "activation_authorized": false,
      "external_side_effects_applied": false,
      "customer_acceptance": "not_asserted",
      "cash": "not_asserted",
    })
  }
  receipts
}
