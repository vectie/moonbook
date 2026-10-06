///|
fn task_outcome_matches(
  submission : ProductOutcomeSubmission,
  handoff : OutcomeLessonTaskHandoff,
) -> Bool {
  submission.source_product == "moonproj" &&
  lesson_handoff_evidence_matches(submission.evidence_refs, handoff.task) &&
  lesson_handoff_evidence_matches(submission.evidence_refs, handoff.report)
}

///|
fn task_outcome_submissions(
  snapshot : BookkeeperStoreSnapshot,
  handoff : OutcomeLessonTaskHandoff,
) -> Array[(ProductOutcomeSubmission, DurableBookkeeperRecord)] raise {
  let matches : Array[(ProductOutcomeSubmission, DurableBookkeeperRecord)] = []
  for record in snapshot.records {
    if record.stage != DeliverableAcceptance ||
      record.source_product != "moonproj" {
      continue
    }
    guard record.payload
      is {
        "candidate_schema": "product_outcome_submission.v1",
        "product_outcome_submission": value,
        ..
      } else {
      continue
    }
    let submission : ProductOutcomeSubmission = @json.from_json(value)
    if !task_outcome_matches(submission, handoff) {
      continue
    }
    validate_product_outcome_submission(submission)
    if record.record !=
      submission_record_reference(submission, "deliverable", record.payload) {
      fail(
        "The saved outcome submission has a conflicting deliverable reference",
      )
    }
    if matches.any(item => item.0.submission == submission.submission) {
      fail("The saved outcome submission is ambiguous")
    }
    matches.push((submission, record))
  }
  matches
}

///|
fn task_outcome_progress(
  snapshot : BookkeeperStoreSnapshot,
  submission : ProductOutcomeSubmission,
  deliverable : DurableBookkeeperRecord,
) -> Json raise {
  let review = product_outcome_exact_human_decision(
    snapshot,
    deliverable.record,
    DeliverableAcceptance,
  )
  let mut state = "deliverable_review_required"
  let mut next_record = Some(deliverable.record)
  if review is Some(review) {
    next_record = None
    if review.disposition == @bookkeeper.Reject {
      state = "deliverable_rejected"
    } else {
      state = "continue_required"
      let outcomes = snapshot.records.filter(record => {
        record.stage == OutcomeBinding &&
        record.source_product == submission.source_product &&
        record.subject == Some(deliverable.record) &&
        lesson_handoff_field(record.payload, "request") ==
        submission.submission.to_json()
      })
      if outcomes.length() > 1 {
        fail("The saved outcome binding is ambiguous")
      }
      if outcomes.get(0) is Some(outcome) {
        let assessments = snapshot.records.filter(record => {
          record.stage == ThreeGapFinding &&
          record.subject == Some(outcome.record) &&
          record.links.contains(outcome.record) &&
          lesson_handoff_field(record.payload, "request") ==
          submission.submission.to_json()
        })
        if assessments.length() > 1 {
          fail("The saved outcome assessment is ambiguous")
        }
        if assessments.get(0) is Some(assessment) {
          let decision = product_outcome_exact_human_decision(
            snapshot,
            assessment.record,
            ThreeGapFinding,
          )
          match decision {
            None => {
              state = "assessment_review_required"
              next_record = Some(assessment.record)
            }
            Some(decision) =>
              state = if decision.disposition == @bookkeeper.Accept {
                "reviewed_source_available"
              } else {
                "assessment_rejected"
              }
          }
        }
      }
    }
  }
  // An interrupted intake may contain its deliverable but not the result yet.
  // Continue reconciles the original submission before asking for review.
  if state == "deliverable_review_required" &&
    !snapshot.envelopes.any(envelope => {
      envelope.direction == Ingress &&
      envelope.message_kind == "product.result" &&
      envelope.subject == deliverable.record &&
      lesson_handoff_field(envelope.payload, "submission") ==
      submission.submission.to_json()
    }) {
    state = "continue_required"
    next_record = None
  }
  {
    "submission": submission.submission.to_json(),
    "deliverable": deliverable.record.to_json(),
    "title": submission.deliverable_title,
    "outcome_summary": submission.outcome_summary,
    "state": state,
    "next_record": match next_record {
      Some(reference) => reference.to_json()
      None => Json::null()
    },
  }
}

///|
fn task_outcome_progress_list(
  snapshot : BookkeeperStoreSnapshot,
  handoff : OutcomeLessonTaskHandoff,
) -> Array[Json] raise {
  task_outcome_submissions(snapshot, handoff).map(item => {
    task_outcome_progress(snapshot, item.0, item.1)
  })
}

///|
// The existing host owns root. Imported content cannot choose a Book root or
// install authority, and Proj acceptance remains evidence rather than review.
async fn task_outcome_operation(
  root : String,
  operation : String,
  payload : Json,
) -> Json {
  let handoff : OutcomeLessonTaskHandoff = @json.from_json(
    lesson_handoff_field(payload, "handoff"),
  )
  ignore(validate_lesson_handoff(handoff))
  let snapshot = replay_bookkeeper_store(root)
  if !snapshot.replay_issues.is_empty() {
    fail("Bookkeeper journal has replay issues")
  }
  let saved = task_outcome_submissions(snapshot, handoff)
  let submission : ProductOutcomeSubmission = if operation == "outcome-import" {
    let incoming : ProductOutcomeSubmission = @json.from_json(
      lesson_handoff_field(payload, "submission"),
    )
    validate_product_outcome_submission(incoming)
    if !task_outcome_matches(incoming, handoff) {
      fail(
        "Choose an outcome from MoonProj that cites this exact task and accepted report, including both versions and digests",
      )
    }
    for (existing, _) in saved {
      if existing.submission.record_id == incoming.submission.record_id &&
        existing.submission.record_version == incoming.submission.record_version &&
        existing != incoming {
        fail(
          "This outcome version is already saved with different content; import its original file or an explicitly new version",
        )
      }
    }
    incoming
  } else {
    let reference : @bookkeeper.VersionedRecordReference = @json.from_json(
      lesson_handoff_field(payload, "submission"),
    )
    let matches = saved.filter(item => item.0.submission == reference)
    guard matches is [(submission, _)] else {
      fail(
        "The exact saved outcome is unavailable in this Book; refresh the task or import its original outcome file",
      )
    }
    submission
  }
  // Intake is idempotent and never progresses through a review, even when a
  // previously reviewed file is imported again or another tab reviews it.
  let (deliverable, result) = intake_product_outcome(root, submission)
  if operation == "outcome-continue" {
    let current = replay_bookkeeper_store(root)
    let decision = product_outcome_exact_human_decision(
      current,
      deliverable,
      DeliverableAcceptance,
    )
    if decision is Some(review) && review.disposition == @bookkeeper.Accept {
      ignore(
        prepare_product_outcome_assessment(
          root,
          submission_closure_request(submission, deliverable, result, review),
        ),
      )
    }
  }
  resolve_outcome_lesson_handoff(root, handoff)
}
