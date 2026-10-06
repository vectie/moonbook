///|
/// Read-only captured company projections. These references identify bytes,
/// not authority. The existing journal alone supplies outcome/review decisions.
pub(all) struct OutcomeLessonTaskHandoff {
  contract_version : String
  source_product : String
  task : @bookkeeper.VersionedRecordReference
  report : @bookkeeper.VersionedRecordReference
  task_snapshot : String
  report_snapshot : String
  customer_acceptance : String
  cash : String
  authorizing : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
fn lesson_handoff_field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn lesson_handoff_text(value : Json, key : String) -> String {
  match lesson_handoff_field(value, key) {
    String(text) => text
    _ => ""
  }
}

///|
fn lesson_handoff_digest(text : String) -> String {
  "sha256:" +
  @crypto.bytes_to_hex_string(@crypto.sha256(@encoding/utf8.encode(text)))
}

///|
fn validate_lesson_handoff(
  handoff : OutcomeLessonTaskHandoff,
) -> (Json, Json) raise {
  if handoff.contract_version != "moonproj.book-lesson-handoff.v1" ||
    handoff.source_product != "moonproj" ||
    handoff.authorizing ||
    handoff.customer_acceptance != "not_asserted" ||
    handoff.cash != "not_asserted" ||
    !closure_record_complete(handoff.task) ||
    !closure_record_complete(handoff.report) ||
    handoff.task_snapshot.length() > 1048576 ||
    handoff.report_snapshot.length() > 1048576 ||
    lesson_handoff_digest(handoff.task_snapshot) != handoff.task.record_digest ||
    lesson_handoff_digest(handoff.report_snapshot) !=
    handoff.report.record_digest {
    fail("The task handoff contract or exact snapshot digests do not match")
  }
  let task = @json.parse(handoff.task_snapshot)
  let report_snapshot = @json.parse(handoff.report_snapshot)
  let report = lesson_handoff_field(report_snapshot, "report")
  let receipt = lesson_handoff_field(report_snapshot, "receipt")
  let acceptance = lesson_handoff_field(task, "acceptance_receipt")
  if lesson_handoff_text(task, "task_id") != handoff.task.record_id ||
    lesson_handoff_field(task, "revision").stringify() !=
    handoff.task.record_version ||
    lesson_handoff_text(task, "accepted_report_id") != handoff.report.record_id ||
    lesson_handoff_text(report, "reportGuid") != handoff.report.record_id ||
    lesson_handoff_text(report, "task_id") != handoff.task.record_id ||
    lesson_handoff_field(receipt, "revision").stringify() !=
    handoff.report.record_version ||
    lesson_handoff_text(receipt, "action") != "report" ||
    lesson_handoff_text(acceptance, "action") != "internal_acceptance" ||
    lesson_handoff_field(task, "accepted_delivery_source") !=
    lesson_handoff_field(report, "delivery_source") ||
    lesson_handoff_field(task, "accepted_delivery_source") !=
    lesson_handoff_field(receipt, "delivery_source") ||
    lesson_handoff_field(task, "accepted_delivery_source") !=
    lesson_handoff_field(acceptance, "delivery_source") {
    fail(
      "The task, accepted report and acceptance projection are not the same binding",
    )
  }
  for item in [receipt, acceptance] {
    if lesson_handoff_text(item, "report_id") != handoff.report.record_id ||
      lesson_handoff_text(item, "audit_state") != "available" ||
      [
        lesson_handoff_text(item, "actor_id"),
        lesson_handoff_text(item, "event_id"),
        lesson_handoff_text(item, "audit_id"),
      ].contains("") {
      fail(
        "The task handoff requires its exact named command and audit references",
      )
    }
    guard lesson_handoff_field(item, "revision") is Number(version) &&
      version >= 1 &&
      version.trunc() == version else {
      fail("The command revision is invalid")
    }
  }
  guard lesson_handoff_field(task, "revision") is Number(version) &&
    version >= 1 &&
    version.trunc() == version else {
    fail("The task revision is invalid")
  }
  (task, report)
}

///|
fn lesson_handoff_evidence_matches(
  evidence : Array[@bookkeeper.VersionedEvidenceReference],
  reference : @bookkeeper.VersionedRecordReference,
) -> Bool {
  evidence.any(item => {
    item.reference_id == reference.record_id &&
    item.reference_version == reference.record_version &&
    item.digest == reference.record_digest
  })
}

///|
/// Resolve already-recorded ProductOutcomeSubmission outcomes by both exact
/// task and report evidence. No record, review, lesson or company state is written.
pub async fn resolve_outcome_lesson_handoff(
  root : String,
  handoff : OutcomeLessonTaskHandoff,
) -> Json {
  let (task, report) = validate_lesson_handoff(handoff)
  let snapshot = replay_bookkeeper_store(root)
  if !snapshot.replay_issues.is_empty() {
    fail("Bookkeeper journal has replay issues")
  }
  let sources : Array[Json] = []
  let pending : Array[Json] = []
  let saved_lessons : Array[Json] = []
  for outcome in snapshot.records {
    if outcome.stage != OutcomeBinding ||
      outcome.source_product != "moonproj" ||
      !lesson_handoff_evidence_matches(outcome.evidence_refs, handoff.task) ||
      !lesson_handoff_evidence_matches(outcome.evidence_refs, handoff.report) {
      continue
    }
    let deliverable = match outcome.subject {
      Some(reference) => find_record(snapshot, reference)
      None => None
    }
    guard deliverable is Some(deliverable) &&
      deliverable.payload
      is {
        "candidate_schema": "product_outcome_submission.v1",
        "product_outcome_submission": value,
        ..
      } else {
      continue
    }
    let submission : ProductOutcomeSubmission = @json.from_json(value)
    validate_product_outcome_submission(submission)
    if submission.source_product != "moonproj" ||
      !lesson_handoff_evidence_matches(submission.evidence_refs, handoff.task) ||
      !lesson_handoff_evidence_matches(submission.evidence_refs, handoff.report) {
      continue
    }
    let assessments = snapshot.records.filter(record => {
      record.stage == ThreeGapFinding &&
      record.subject == Some(outcome.record) &&
      record.links.contains(outcome.record)
    })
    let mut matched = false
    for assessment in assessments {
      let decision = product_outcome_exact_human_decision(
        snapshot,
        assessment.record,
        ThreeGapFinding,
      )
      guard decision is Some(review) && review.disposition == @bookkeeper.Accept else {
        continue
      }
      let draft : OutcomeLessonDraft = {
        contract_version: "moonbook.outcome-lesson.v1",
        lesson_id: "read-only-source-check",
        lesson_version: "1",
        title: "Source validation",
        guidance: "Source validation",
        outcome: outcome.record,
        assessment: assessment.record,
        assessment_review: review.receipt,
        applicability: [{ key: "project_id", value: "read-only-check", }],
        invalidation: [],
        recorded_at: review.decided_at,
      }
      ignore(outcome_lesson_source(snapshot, draft))
      sources.push({
        "outcome": outcome.record.to_json(),
        "assessment": assessment.record.to_json(),
        "assessment_review": review.receipt.to_json(),
        "title": assessment.title,
        "outcome_summary": outcome.summary,
        "assessment_summary": assessment.summary,
        "reviewer": review.reviewer.to_json(),
        "reviewed_at": review.decided_at,
      })
      for
        receipt in saved_task_lesson_receipts(
          snapshot,
          handoff,
          submission.submission,
          outcome.record,
          assessment.record,
          review.receipt,
        ) {
        saved_lessons.push(receipt)
      }
      matched = true
    }
    if !matched {
      pending.push({
        "outcome": outcome.record.to_json(),
        "reason": "Named-human accepted assessment required",
      })
    }
  }
  {
    "contract_version": "moonbook.task-lesson-readback.v1",
    "handoff": handoff.to_json(),
    "task_context": task,
    "report_context": report,
    "sources": sources.to_json(),
    "pending": pending.to_json(),
    "outcome_submissions": task_outcome_progress_list(snapshot, handoff).to_json(),
    "saved_lessons": saved_lessons.to_json(),
    "state": if sources.length() == 1 {
      "reviewed_source_available"
    } else if sources.length() > 1 {
      "choose_reviewed_source"
    } else {
      "reviewed_source_missing"
    },
    "activation_authorized": false,
    "external_side_effects_applied": false,
  }
}
