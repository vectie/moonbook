///|
/// A new immutable lesson and the exact accepted history its reviewer will replace.
pub(all) struct OutcomeLessonRevision {
  contract_version : String
  lesson : OutcomeLessonDraft
  supersedes : @bookkeeper.VersionedRecordReference
  expected_head : @bookkeeper.VersionedRecordReference?
  accepted_reviews : Array[@bookkeeper.VersionedRecordReference]
  reason : String
} derive(Debug, Eq)

///|
/// Explicitly choose an already accepted version, including a rollback.
/// Preparing this artifact never makes the chosen version current.
pub(all) struct OutcomeLessonSelection {
  contract_version : String
  selection_id : String
  lesson_id : String
  target : @bookkeeper.VersionedRecordReference
  expected_head : @bookkeeper.VersionedRecordReference?
  accepted_reviews : Array[@bookkeeper.VersionedRecordReference]
  reason : String
  recorded_at : Int
} derive(Debug, Eq)

///|
fn lesson_revision(
  record : DurableBookkeeperRecord,
) -> OutcomeLessonRevision? raise {
  match record.payload {
    { "candidate_schema": "outcome_lesson.v2", "revision": revision, .. } =>
      Some(@json.from_json(revision))
    { "candidate_schema": "outcome_lesson.v2", .. } =>
      fail("revision metadata is missing")
    _ => None
  }
}

///|
fn lesson_selection(
  record : DurableBookkeeperRecord,
) -> OutcomeLessonSelection? raise {
  match record.payload {
    {
      "candidate_schema": "outcome_lesson_selection.v1",
      "selection": selection,
      ..
    } => Some(@json.from_json(selection))
    { "candidate_schema": "outcome_lesson_selection.v1", .. } =>
      fail("selection metadata is missing")
    _ => None
  }
}

///|
fn lesson_accepted_review(
  snapshot : BookkeeperStoreSnapshot,
  record : DurableBookkeeperRecord,
) -> GovernedReviewReceipt? raise {
  match
    product_outcome_exact_human_decision(
      snapshot,
      record.record,
      DeliverableAcceptance,
    ) {
    Some(review) if review.disposition == @bookkeeper.Accept &&
      review.issues.is_empty() &&
      !review.side_effects_applied &&
      review_subject_evidence_exact(record, review.evidence_refs) =>
      Some(review)
    _ => None
  }
}

///|
fn lesson_accepted_target(
  snapshot : BookkeeperStoreSnapshot,
  reference : @bookkeeper.VersionedRecordReference,
  family : String,
) -> DurableBookkeeperRecord raise {
  guard find_record(snapshot, reference) is Some(record) &&
    outcome_lesson_draft(record) is Some(draft) &&
    draft.lesson_id == family &&
    lesson_accepted_review(snapshot, record) is Some(_) else {
    fail(
      "version choice requires an exact accepted lesson in the same lesson family",
    )
  }
  record
}

///|
fn lesson_transition(
  record : DurableBookkeeperRecord,
) -> (
  String,
  @bookkeeper.VersionedRecordReference,
  @bookkeeper.VersionedRecordReference?,
  Array[@bookkeeper.VersionedRecordReference],
)? raise {
  if lesson_revision(record) is Some(revision) {
    return Some(
      (
        revision.lesson.lesson_id,
        record.record,
        revision.expected_head,
        revision.accepted_reviews,
      ),
    )
  }
  if lesson_selection(record) is Some(selection) {
    return Some(
      (
        selection.lesson_id,
        selection.target,
        selection.expected_head,
        selection.accepted_reviews,
      ),
    )
  }
  None
}

///|
/// Review order is journal order, never a lexical version or caller timestamp.
fn lesson_version_state(
  snapshot : BookkeeperStoreSnapshot,
  family : String,
) -> (
  @bookkeeper.VersionedRecordReference?,
  @bookkeeper.VersionedRecordReference?,
  Array[@bookkeeper.VersionedRecordReference],
) raise {
  let accepted : Array[@bookkeeper.VersionedRecordReference] = []
  let lessons : Array[@bookkeeper.VersionedRecordReference] = []
  for record in snapshot.records {
    if outcome_lesson_draft(record) is Some(draft) &&
      draft.lesson_id == family &&
      lesson_accepted_review(snapshot, record) is Some(review) {
      accepted.push(review.receipt)
      lessons.push(record.record)
    }
  }
  let mut head : @bookkeeper.VersionedRecordReference? = None
  let mut current : @bookkeeper.VersionedRecordReference? = None
  for review in snapshot.reviews {
    if review.disposition != @bookkeeper.Accept || !review.review_complete {
      continue
    }
    guard find_record(snapshot, review.subject) is Some(record) &&
      lesson_transition(record) is Some((id, target, _, _)) &&
      id == family else {
      continue
    }
    guard lesson_accepted_review(snapshot, record) is Some(exact) &&
      exact.receipt == review.receipt else {
      fail("version selection has no unique exact acceptance")
    }
    head = Some(review.receipt)
    current = Some(target)
  }
  if head is None && lessons.length() == 1 {
    current = Some(lessons[0])
  }
  if current is Some(reference) {
    ignore(lesson_accepted_target(snapshot, reference, family))
  }
  (head, current, accepted)
}

///|
fn lesson_transition_current(
  snapshot : BookkeeperStoreSnapshot,
  record : DurableBookkeeperRecord,
) -> Unit raise {
  guard lesson_transition(record)
    is Some((family, _, expected_head, accepted_reviews)) else {
    return
  }
  if !snapshot.replay_issues.is_empty() {
    fail("Bookkeeper journal has replay issues")
  }
  let (head, current, accepted) = lesson_version_state(snapshot, family)
  if head != expected_head || accepted != accepted_reviews {
    fail(
      "lesson history changed; reload versions and prepare a new explicit choice",
    )
  }
  if lesson_revision(record) is Some(revision) &&
    current is Some(reference) &&
    revision.supersedes != reference {
    fail("revision must supersede the exact current lesson")
  }
}

///|
fn lesson_revision_record(
  snapshot : BookkeeperStoreSnapshot,
  revision : OutcomeLessonRevision,
) -> DurableBookkeeperRecord raise {
  if revision.contract_version != "moonbook.outcome-lesson-revision.v1" ||
    revision.reason.is_blank() {
    fail("revision requires its contract and reason")
  }
  let previous = lesson_accepted_target(
    snapshot,
    revision.supersedes,
    revision.lesson.lesson_id,
  )
  let original = outcome_lesson_draft(previous).unwrap()
  if revision.lesson.lesson_version == original.lesson_version ||
    revision.lesson.outcome != original.outcome ||
    revision.lesson.assessment != original.assessment ||
    revision.lesson.assessment_review != original.assessment_review {
    fail(
      "revision requires a new version and the unchanged original source chain",
    )
  }
  if revision.lesson.recorded_at <
    lesson_accepted_review(snapshot, previous).unwrap().decided_at {
    fail("revision cannot predate its predecessor acceptance")
  }
  let outcome = outcome_lesson_source(snapshot, revision.lesson)
  let base = outcome_lesson_record(revision.lesson, outcome)
  let payload : Json = {
    "contract_version": @bookkeeper.bookkeeper_contract_version(),
    "candidate_schema": "outcome_lesson.v2",
    "outcome_lesson": revision.lesson.to_json(),
    "revision": revision.to_json(),
  }
  {
    ..base,
    record: {
      ..base.record,
      record_digest: bookkeeper_payload_digest(payload),
    },
    links: base.links +
    [revision.supersedes] +
    revision.accepted_reviews +
    (match revision.expected_head {
      Some(head) => [head]
      None => []
    }),
    next_action: "Compare this revision with its exact predecessor. Existing named-human acceptance selects this version only if the captured history is still current.",
    payload,
  }
}

///|
fn lesson_selection_record(
  snapshot : BookkeeperStoreSnapshot,
  selection : OutcomeLessonSelection,
) -> DurableBookkeeperRecord raise {
  if selection.contract_version != "moonbook.outcome-lesson-selection.v1" ||
    selection.selection_id.is_blank() ||
    selection.lesson_id.is_blank() ||
    selection.reason.is_blank() {
    fail("selection requires its contract, identity, family and reason")
  }
  let target = lesson_accepted_target(
    snapshot,
    selection.target,
    selection.lesson_id,
  )
  if selection.recorded_at <
    lesson_accepted_review(snapshot, target).unwrap().decided_at {
    fail("selection cannot predate the selected lesson acceptance")
  }
  let payload : Json = {
    "contract_version": @bookkeeper.bookkeeper_contract_version(),
    "candidate_schema": "outcome_lesson_selection.v1",
    "selection": selection.to_json(),
  }
  {
    ..target,
    record: {
      record_id: "outcome-lesson-selection:" + selection.selection_id,
      record_version: "1",
      record_digest: bookkeeper_payload_digest(payload),
    },
    subject: Some(selection.target),
    links: [selection.target] +
    selection.accepted_reviews +
    (match selection.expected_head {
      Some(head) => [head]
      None => []
    }),
    title: "Choose lesson version: " +
    target.title +
    " @ " +
    selection.target.record_version,
    summary: selection.reason,
    next_action: "Review this explicit choice of an already accepted lesson. Acceptance changes current retrieval; original lessons and decisions remain unchanged.",
    recorded_at: selection.recorded_at,
    payload,
  }
}

///|
fn validate_lesson_selection_record(
  snapshot : BookkeeperStoreSnapshot,
  record : DurableBookkeeperRecord,
) -> Unit raise {
  if lesson_selection(record) is Some(selection) {
    if record != lesson_selection_record(snapshot, selection) {
      fail(
        "selection artifact differs from its exact choice and accepted target",
      )
    }
    lesson_transition_current(snapshot, record)
  }
}

///|
/// Called under the journal lock and again at the exact replay position.
/// Existing receipt retries are checked before this changing-state predicate.
fn validate_lesson_transition_review(
  snapshot : BookkeeperStoreSnapshot,
  receipt : GovernedReviewReceipt,
) -> Unit raise {
  guard find_record(snapshot, receipt.subject) is Some(record) &&
    lesson_transition(record) is Some(_) else {
    return
  }
  if receipt.requested == @bookkeeper.Accept ||
    receipt.requested == @bookkeeper.Reject {
    if product_outcome_exact_human_decision(
        snapshot,
        record.record,
        DeliverableAcceptance,
      )
      is Some(_) {
      fail("version choice already has a final decision; prepare a new choice")
    }
  }
  if receipt.requested == @bookkeeper.Accept {
    lesson_transition_current(snapshot, record)
    if receipt.decided_at < record.recorded_at {
      fail("version choice review cannot predate its artifact")
    }
  }
}

///|
/// Save a revision for the existing named-human review; does not accept it.
pub async fn prepare_outcome_lesson_revision(
  root : String,
  revision : OutcomeLessonRevision,
) -> BookkeeperMutationResult {
  let snapshot = replay_bookkeeper_store(root)
  if !snapshot.replay_issues.is_empty() {
    return rejected_result(root, ["Bookkeeper journal has replay issues"])
  }
  let record = lesson_revision_record(snapshot, revision) catch {
    error => return rejected_result(root, [error.to_string()])
  }
  persist_bookkeeper_record(root, record)
}

///|
/// Save an explicit current-version choice or rollback for existing review.
pub async fn prepare_outcome_lesson_selection(
  root : String,
  selection : OutcomeLessonSelection,
) -> BookkeeperMutationResult {
  let snapshot = replay_bookkeeper_store(root)
  if !snapshot.replay_issues.is_empty() {
    return rejected_result(root, ["Bookkeeper journal has replay issues"])
  }
  let record = lesson_selection_record(snapshot, selection) catch {
    error => return rejected_result(root, [error.to_string()])
  }
  persist_bookkeeper_record(root, record)
}

///|
/// Read all immutable versions and decisions. A null head preserves legacy
/// multi-version retrieval; only an explicit reviewed choice establishes a head.
pub async fn outcome_lesson_history(root : String, lesson_id : String) -> Json {
  if lesson_id.is_blank() {
    fail("lesson history requires a lesson ID")
  }
  let snapshot = replay_bookkeeper_store(root)
  if !snapshot.replay_issues.is_empty() {
    fail("Bookkeeper journal has replay issues")
  }
  let (head, current, accepted_reviews) = lesson_version_state(
    snapshot, lesson_id,
  )
  let versions : Array[Json] = []
  let selections : Array[Json] = []
  for record in snapshot.records {
    let reviews = snapshot.reviews.filter(review => {
      review.subject == record.record
    })
    if outcome_lesson_draft(record) is Some(draft) &&
      draft.lesson_id == lesson_id {
      versions.push({
        "lesson": record.to_json(),
        "reviews": reviews.to_json(),
        "current": current == Some(record.record),
      })
    } else if lesson_selection(record) is Some(selection) &&
      selection.lesson_id == lesson_id {
      selections.push({
        "record": record.to_json(),
        "reviews": reviews.to_json(),
      })
    }
  }
  {
    "contract_version": "moonbook.outcome-lesson-history.v1",
    "lesson_id": lesson_id,
    "head": lesson_nullable_reference(head),
    "current": lesson_nullable_reference(current),
    "accepted_reviews": accepted_reviews.to_json(),
    "versions": versions.to_json(),
    "selections": selections.to_json(),
  }
}
