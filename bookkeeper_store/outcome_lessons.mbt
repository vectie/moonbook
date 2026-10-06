///|
/// An explicit condition such as customer_id, project_id, or decision_kind.
/// Values are compared exactly; topical similarity never widens the scope.
pub(all) struct OutcomeLessonCondition {
  key : String
  value : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A reusable correction is a reviewable artifact in the existing journal.
/// Editing a rejected or accepted correction requires a new immutable version.
pub(all) struct OutcomeLessonDraft {
  contract_version : String
  lesson_id : String
  lesson_version : String
  title : String
  guidance : String
  outcome : @bookkeeper.VersionedRecordReference
  assessment : @bookkeeper.VersionedRecordReference
  assessment_review : @bookkeeper.VersionedRecordReference
  applicability : Array[OutcomeLessonCondition]
  invalidation : Array[OutcomeLessonCondition]
  recorded_at : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct OutcomeLessonQuery {
  contract_version : String
  target_task : @bookkeeper.VersionedRecordReference
  conditions : Array[OutcomeLessonCondition]
} derive(Debug, Eq, ToJson, FromJson)

///|
fn lesson_conditions_issue(
  conditions : Array[OutcomeLessonCondition],
) -> String? {
  let keys : Array[String] = []
  for condition in conditions {
    if condition.key.is_blank() || condition.value.is_blank() {
      return Some("lesson conditions require non-blank keys and values")
    }
    if keys.contains(condition.key) {
      return Some("lesson conditions contain a duplicate key: " + condition.key)
    }
    keys.push(condition.key)
  }
  None
}

///|
fn outcome_lesson_payload(draft : OutcomeLessonDraft) -> Json {
  {
    "contract_version": @bookkeeper.bookkeeper_contract_version(),
    "candidate_schema": "outcome_lesson.v1",
    "outcome_lesson": draft.to_json(),
  }
}

///|
fn outcome_lesson_draft(
  record : DurableBookkeeperRecord,
) -> OutcomeLessonDraft? raise {
  match record.payload {
    { "candidate_schema": "outcome_lesson.v1", "outcome_lesson": value, .. } =>
      Some(@json.from_json(value))
    { "candidate_schema": "outcome_lesson.v2", "outcome_lesson": value, .. } =>
      Some(@json.from_json(value))
    { "candidate_schema": "outcome_lesson.v1", .. }
    | { "candidate_schema": "outcome_lesson.v2", .. } =>
      fail("outcome lesson payload is missing its draft")
    _ => None
  }
}

///|
fn outcome_lesson_source(
  snapshot : BookkeeperStoreSnapshot,
  draft : OutcomeLessonDraft,
) -> DurableBookkeeperRecord raise {
  if draft.contract_version != "moonbook.outcome-lesson.v1" ||
    draft.lesson_id.is_blank() ||
    draft.lesson_version.is_blank() ||
    draft.title.is_blank() ||
    draft.guidance.is_blank() ||
    draft.applicability.is_empty() ||
    draft.recorded_at < 0 {
    fail(
      "lesson requires its versioned contract, identity, guidance, and explicit applicability",
    )
  }
  for conditions in [draft.applicability, draft.invalidation] {
    if lesson_conditions_issue(conditions) is Some(issue) {
      fail(issue)
    }
  }
  for condition in draft.invalidation {
    if draft.applicability.contains(condition) {
      fail(
        "a lesson condition cannot both require and invalidate the same value",
      )
    }
  }
  let outcome = match find_record(snapshot, draft.outcome) {
    Some(record) if record.stage == OutcomeBinding => record
    _ => fail("lesson requires an exact durable outcome binding")
  }
  let assessment = match find_record(snapshot, draft.assessment) {
    Some(record) if record.stage == ThreeGapFinding &&
      record.subject == Some(draft.outcome) &&
      record.links.contains(draft.outcome) => record
    _ => fail("lesson requires an exact assessment of that outcome")
  }
  let decision = product_outcome_exact_human_decision(
    snapshot,
    assessment.record,
    ThreeGapFinding,
  )
  guard decision is Some(review) &&
    review.receipt == draft.assessment_review &&
    review.disposition == @bookkeeper.Accept &&
    review.issues.is_empty() &&
    !review.side_effects_applied &&
    review_subject_evidence_exact(assessment, review.evidence_refs) else {
    fail("lesson requires the exact named-human accepted assessment review")
  }
  if draft.recorded_at < review.decided_at {
    fail("lesson cannot predate its source assessment review")
  }
  outcome
}

///|
fn outcome_lesson_record(
  draft : OutcomeLessonDraft,
  outcome : DurableBookkeeperRecord,
) -> DurableBookkeeperRecord {
  let payload = outcome_lesson_payload(draft)
  {
    contract_version: bookkeeper_store_contract_version(),
    record: {
      record_id: "outcome-lesson:" +
      draft.lesson_id +
      "@" +
      draft.lesson_version,
      record_version: draft.lesson_version,
      record_digest: bookkeeper_payload_digest(payload),
    },
    stage: DeliverableAcceptance,
    subject: Some(draft.outcome),
    links: [draft.outcome, draft.assessment, draft.assessment_review],
    title: draft.title,
    summary: draft.guidance,
    owner_route: outcome.owner_route,
    status: "awaiting human review",
    evidence_refs: outcome.evidence_refs,
    issue_refs: [],
    requires_human_review: true,
    next_action: "Review the lesson guidance and applicability in Bookkeeper. After acceptance, retrieve it for a later task with matching conditions.",
    source_product: "moonbook",
    recorded_at: draft.recorded_at,
    payload,
    side_effects_applied: false,
  }
}

///|
/// Called by ordinary record admission too, so UI Record and CLI share one path.
fn validate_outcome_lesson_record(
  snapshot : BookkeeperStoreSnapshot,
  record : DurableBookkeeperRecord,
) -> Unit raise {
  if outcome_lesson_draft(record) is Some(draft) {
    let outcome = outcome_lesson_source(snapshot, draft)
    let expected = match lesson_revision(record) {
      Some(revision) => lesson_revision_record(snapshot, revision)
      None => outcome_lesson_record(draft, outcome)
    }
    if record != expected {
      fail("lesson artifact metadata differs from its exact draft and outcome")
    }
    lesson_transition_current(snapshot, record)
  }
}

///|
/// Persist a candidate only. The existing governed review UI/CLI owns Accept
/// and Reject; preparing a lesson never supplies its own review.
pub async fn prepare_outcome_lesson(
  root : String,
  draft : OutcomeLessonDraft,
) -> BookkeeperMutationResult {
  let snapshot = replay_bookkeeper_store(root)
  if !snapshot.replay_issues.is_empty() {
    return rejected_result(root, ["Bookkeeper journal has replay issues"])
  }
  let outcome = outcome_lesson_source(snapshot, draft) catch {
    error => return rejected_result(root, [error.to_string()])
  }
  persist_bookkeeper_record(root, outcome_lesson_record(draft, outcome))
}

///|
/// Retrieve the original reviewed artifact and source chain without changing
/// either. target_task is caller-supplied context, not proof of task acceptance.
pub async fn retrieve_outcome_lessons(
  root : String,
  query : OutcomeLessonQuery,
) -> Json {
  outcome_lesson_retrieval(replay_bookkeeper_store(root), query)
}

///|
fn outcome_lesson_retrieval(
  snapshot : BookkeeperStoreSnapshot,
  query : OutcomeLessonQuery,
) -> Json raise {
  if query.contract_version != "moonbook.outcome-lesson-query.v1" ||
    !closure_record_complete(query.target_task) {
    fail("lesson query requires its contract and exact target task reference")
  }
  if lesson_conditions_issue(query.conditions) is Some(issue) {
    fail(issue)
  }
  if !snapshot.replay_issues.is_empty() {
    fail("Bookkeeper journal has replay issues")
  }
  let matches : Array[Json] = []
  let exclusions : Array[Json] = []
  for record in snapshot.records {
    let draft = match outcome_lesson_draft(record) {
      Some(value) => value
      None => continue
    }
    // Replay validated each artifact at its original journal position. A later
    // accepted transition intentionally makes its captured head historical.
    ignore(outcome_lesson_source(snapshot, draft))
    let decision = product_outcome_exact_human_decision(
      snapshot,
      record.record,
      DeliverableAcceptance,
    )
    let review = match decision {
      Some(review) if review.disposition == @bookkeeper.Accept => review
      _ => {
        exclusions.push({
          "lesson": record.record.to_json(),
          "reason": "lesson is not human-accepted",
        })
        continue
      }
    }
    let (head, current, _) = lesson_version_state(snapshot, draft.lesson_id)
    if head is Some(_) && current != Some(record.record) {
      exclusions.push({
        "lesson": record.record.to_json(),
        "reason": "accepted historical version is not the explicitly selected current lesson",
        "current": lesson_nullable_reference(current),
        "selection_review": lesson_nullable_reference(head),
      })
      continue
    }
    let missing = draft.applicability.filter(condition => {
      !query.conditions.contains(condition)
    })
    let invalidated = draft.invalidation.filter(condition => {
      query.conditions.contains(condition)
    })
    if !missing.is_empty() || !invalidated.is_empty() {
      exclusions.push({
        "lesson": record.record.to_json(),
        "reason": "task conditions do not meet reviewed applicability",
        "unmatched_conditions": missing.to_json(),
        "invalidation_matches": invalidated.to_json(),
      })
      continue
    }
    matches.push({
      "status": "scope-matched-reviewed-lesson",
      "lesson": record.to_json(),
      "review": review.to_json(),
      "selection_review": lesson_nullable_reference(head),
      "outcome": find_record(snapshot, draft.outcome).unwrap().to_json(),
      "assessment": find_record(snapshot, draft.assessment).unwrap().to_json(),
      "assessment_review": closure_find_review(
        snapshot,
        draft.assessment_review,
      )
      .unwrap()
      .to_json(),
      "applicability_decision_required": true,
    })
  }
  {
    "contract_version": "moonbook.outcome-lesson-retrieval.v1",
    "query": query.to_json(),
    "matches": matches.to_json(),
    "exclusions": exclusions.to_json(),
    "activation_authorized": false,
    "external_side_effects_applied": false,
  }
}
