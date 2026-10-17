///|
/// An operator-supplied example, not a model run. The full lesson and both
/// outputs are digest-bound by the existing immutable lesson artifact.
priv struct OutcomeLessonRehearsal {
  contract_version : String
  lesson : OutcomeLessonDraft
  example_input : String
  baseline_output : String
  corrected_output : String
  required_text : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Deterministic, case-sensitive literal checks. Passing these checks says
/// nothing about factual correctness, generalization, or model behavior.
fn evaluate_outcome_lesson_rehearsal(
  rehearsal : OutcomeLessonRehearsal,
) -> Json raise {
  if rehearsal.contract_version != "moonbook.outcome-lesson-rehearsal.v1" ||
    rehearsal.example_input.is_blank() ||
    rehearsal.baseline_output.is_blank() ||
    rehearsal.corrected_output.is_blank() ||
    rehearsal.required_text.is_empty() ||
    rehearsal.required_text.length() > 20 {
    fail(
      "Rehearsal needs one example, two supplied outputs, and 1 to 20 literal checks",
    )
  }
  for
    text in [
      rehearsal.example_input,
      rehearsal.baseline_output,
      rehearsal.corrected_output,
    ] {
    if text.length() > 16384 {
      fail("Rehearsal text exceeds 16384 characters; no content was truncated")
    }
  }
  let seen : Array[String] = []
  let checks : Array[Json] = []
  let mut before_passed = 0
  let mut after_passed = 0
  for text in rehearsal.required_text {
    if text.is_blank() || text.length() > 512 || seen.contains(text) {
      fail(
        "Literal checks must be non-blank, unique, and at most 512 characters",
      )
    }
    seen.push(text)
    let before = rehearsal.baseline_output.contains(text)
    let after = rehearsal.corrected_output.contains(text)
    if before {
      before_passed += 1
    }
    if after {
      after_passed += 1
    }
    checks.push({
      "text": text,
      "baseline_passed": before,
      "corrected_passed": after,
    })
  }
  {
    "contract_version": "moonbook.outcome-lesson-rehearsal-result.v1",
    "evaluation_kind": "operator_supplied_literal_rehearsal",
    "checks": checks.to_json(),
    "baseline_passed": before_passed.to_json(),
    "corrected_passed": after_passed.to_json(),
    "total": checks.length().to_json(),
    "improved": (after_passed == checks.length() && before_passed < after_passed).to_json(),
    "model_executed": false,
    "activation_authorized": false,
  }
}

///|
fn outcome_lesson_rehearsal(
  record : DurableBookkeeperRecord,
) -> OutcomeLessonRehearsal? raise {
  match record.payload {
    {
      "candidate_schema": "outcome_lesson.rehearsed.v1",
      "rehearsal": value,
      ..
    } => Some(@json.from_json(value))
    { "candidate_schema": "outcome_lesson.rehearsed.v1", .. } =>
      fail("Rehearsed lesson is missing its exact example")
    _ => None
  }
}

///|
fn outcome_lesson_rehearsal_record(
  snapshot : BookkeeperStoreSnapshot,
  rehearsal : OutcomeLessonRehearsal,
) -> DurableBookkeeperRecord raise {
  let outcome = outcome_lesson_source(snapshot, rehearsal.lesson)
  let result = evaluate_outcome_lesson_rehearsal(rehearsal)
  if !(result is { "improved": true, .. }) {
    fail(
      "A rehearsal-backed proposal requires every corrected-output check to pass and at least one baseline failure",
    )
  }
  let original = outcome_lesson_record(rehearsal.lesson, outcome)
  let payload : Json = {
    "contract_version": @bookkeeper.bookkeeper_contract_version(),
    "candidate_schema": "outcome_lesson.rehearsed.v1",
    "outcome_lesson": rehearsal.lesson.to_json(),
    "rehearsal": rehearsal.to_json(),
    "rehearsal_result": result,
  }
  {
    ..original,
    record: {
      ..original.record,
      record_digest: bookkeeper_payload_digest(payload),
    },
    payload,
    next_action: "Inspect the supplied example, literal checks, proposed guidance and scope. Named-human acceptance makes this exact version selectable for a later task; it does not activate a capability.",
  }
}

///|
/// Recompute checks at admission; a browser's claimed pass is never trusted.
/// Review, retrieval, current-version selection and rollback use existing paths.
async fn prepare_outcome_lesson_rehearsal(
  root : String,
  rehearsal : OutcomeLessonRehearsal,
) -> BookkeeperMutationResult {
  let snapshot = replay_bookkeeper_store(root)
  if !snapshot.replay_issues.is_empty() {
    return rejected_result(root, ["Bookkeeper journal has replay issues"])
  }
  let record = outcome_lesson_rehearsal_record(snapshot, rehearsal) catch {
    error => return rejected_result(root, [error.to_string()])
  }
  persist_bookkeeper_record(root, record)
}
