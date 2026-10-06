///|
fn guidance_exact_keys(value : Json, allowed : Array[String]) -> Bool {
  match value {
    Object(fields) =>
      fields.length() == allowed.length() &&
      fields.keys().all(key => allowed.contains(key))
    _ => false
  }
}

///|
fn guidance_reference(
  value : Json,
) -> @bookkeeper.VersionedRecordReference raise {
  if !guidance_exact_keys(value, [
      "record_id", "record_version", "record_digest",
    ]) {
    fail("Guidance requires an exact minimal record reference")
  }
  let reference : @bookkeeper.VersionedRecordReference = @json.from_json(value)
  if !closure_record_complete(reference) ||
    [reference.record_id, reference.record_version, reference.record_digest].any(value => {
        value.length() > 512
      },
    ) {
    fail("Guidance reference is incomplete or too long")
  }
  reference
}

///|
fn guidance_conditions(value : Json) -> Array[OutcomeLessonCondition] raise {
  guard value is Array(values) && values.length() <= 32 else {
    fail("Guidance supports at most 32 explicit conditions")
  }
  for item in values {
    if !guidance_exact_keys(item, ["key", "value"]) {
      fail("Guidance conditions must contain only key and value")
    }
  }
  let conditions : Array[OutcomeLessonCondition] = @json.from_json(value)
  if lesson_conditions_issue(conditions) is Some(issue) {
    fail(issue)
  }
  if conditions.any(condition => {
      condition.key.length() > 128 || condition.value.length() > 512
    }) {
    fail("Guidance condition is too long; no content was truncated")
  }
  conditions
}

///|
/// A pre-Start task projection is query context, never task acceptance or a
/// Book review. It intentionally has a separate wire from outcome handoffs.
pub fn resolve_task_guidance_query(handoff : Json) -> Json raise {
  if !guidance_exact_keys(handoff, [
      "contract_version", "source_product", "target_task", "task_snapshot", "conditions",
      "authorizing",
    ]) ||
    lesson_handoff_text(handoff, "contract_version") !=
    "moonproj.book-guidance-query.v1" ||
    lesson_handoff_text(handoff, "source_product") != "moonproj" ||
    lesson_handoff_field(handoff, "authorizing") != false.to_json() {
    fail("Unsupported non-authorizing task guidance query")
  }
  let target = guidance_reference(lesson_handoff_field(handoff, "target_task"))
  let text = lesson_handoff_text(handoff, "task_snapshot")
  if text.is_blank() ||
    text.length() > 8192 ||
    lesson_handoff_digest(text) != target.record_digest {
    fail("Guidance task snapshot digest does not match")
  }
  let task = @json.parse(text)
  if !guidance_exact_keys(task, [
      "task_id", "project_id", "product_id", "revision",
    ]) ||
    lesson_handoff_text(task, "task_id") != target.record_id ||
    lesson_handoff_field(task, "revision").stringify() != target.record_version {
    fail("Guidance task identity or minimal snapshot does not match")
  }
  guard lesson_handoff_field(task, "revision") is Number(version) &&
    version >= 1 &&
    version <= 9007199254740991.0 &&
    version.trunc() == version else {
    fail("Guidance task revision is invalid")
  }
  let project = lesson_handoff_text(task, "project_id")
  guard lesson_handoff_field(task, "product_id") is String(product) &&
    !project.is_blank() else {
    fail("Guidance task project and suite product context are unavailable")
  }
  let expected : Array[OutcomeLessonCondition] = [
    { key: "project_id", value: project, },
  ]
  if !product.is_blank() {
    // The task's product_id is a suite catalog tag. It is not source_product
    // or a customer's business product_id, so retain a distinct scope key.
    expected.push({ key: "suite_product_id", value: product, })
  }
  let conditions = guidance_conditions(
    lesson_handoff_field(handoff, "conditions"),
  )
  if conditions != expected {
    fail(
      "Guidance conditions differ from the exact task project and suite product",
    )
  }
  {
    "contract_version": "moonbook.task-guidance-query-readback.v1",
    "handoff": handoff,
    "query": {
      "contract_version": "moonbook.outcome-lesson-query.v1",
      "target_task": target.to_json(),
      "conditions": conditions.to_json(),
    },
    "activation_authorized": false,
    "external_side_effects_applied": false,
  }
}

///|
fn task_guidance_query(
  handoff : Json,
  value : Json,
) -> OutcomeLessonQuery raise {
  ignore(resolve_task_guidance_query(handoff))
  if !guidance_exact_keys(value, [
      "contract_version", "target_task", "conditions",
    ]) {
    fail("Unsupported task guidance query fields")
  }
  let target = guidance_reference(lesson_handoff_field(value, "target_task"))
  let conditions = guidance_conditions(
    lesson_handoff_field(value, "conditions"),
  )
  if lesson_handoff_text(value, "contract_version") !=
    "moonbook.outcome-lesson-query.v1" ||
    target.to_json() != lesson_handoff_field(handoff, "target_task") {
    fail("Guidance belongs to another exact target task")
  }
  let required = guidance_conditions(
    lesson_handoff_field(handoff, "conditions"),
  )
  if !required.all(condition => conditions.contains(condition)) {
    fail("Keep the task's verified project and suite-product conditions")
  }
  {
    contract_version: "moonbook.outcome-lesson-query.v1",
    target_task: target,
    conditions,
  }
}

///|
/// Fresh read-only selection from the same journal snapshot as retrieval.
/// The browser adds its actual Book origin/time; no raw source bodies leave.
pub async fn select_task_guidance(root : String, payload : Json) -> Json {
  if !guidance_exact_keys(payload, ["handoff", "query", "lesson"]) {
    fail("Guidance selection requires only handoff, query and exact lesson")
  }
  let handoff = lesson_handoff_field(payload, "handoff")
  let query = task_guidance_query(
    handoff,
    lesson_handoff_field(payload, "query"),
  )
  let selected = guidance_reference(lesson_handoff_field(payload, "lesson"))
  let snapshot = replay_bookkeeper_store(root)
  let result = outcome_lesson_retrieval(snapshot, query)
  let matches = match lesson_handoff_field(result, "matches") {
    Array(items) => items
    _ => []
  }
  let selected_matches = matches.filter(item => {
    lesson_handoff_field(lesson_handoff_field(item, "lesson"), "record") ==
    selected.to_json()
  })
  guard selected_matches.length() == 1 else {
    fail(
      "This exact lesson is no longer a current accepted scope match; find lessons again",
    )
  }
  let item = selected_matches[0]
  let record = find_record(snapshot, selected).unwrap()
  let draft = outcome_lesson_draft(record).unwrap()
  let review = product_outcome_exact_human_decision(
    snapshot,
    selected,
    DeliverableAcceptance,
  ).unwrap()
  if draft.title.is_blank() ||
    draft.title.length() > 512 ||
    draft.guidance.is_blank() ||
    draft.guidance.length() > 8192 ||
    review.reviewer.reviewer_id.length() > 256 {
    fail("Selected guidance exceeds the export limit; no content was truncated")
  }
  ignore(guidance_conditions(draft.applicability.to_json()))
  ignore(guidance_conditions(draft.invalidation.to_json()))
  for
    reference in [
      draft.outcome,
      draft.assessment,
      draft.assessment_review,
      review.receipt,
    ] {
    ignore(guidance_reference(reference.to_json()))
  }
  let selection_review = lesson_handoff_field(item, "selection_review")
  if selection_review != Json::null() {
    ignore(guidance_reference(selection_review))
  }
  let selection : Json = {
    "contract_version": "moonbook.task-guidance-selection.v1",
    "handoff": handoff,
    "query": query.to_json(),
    "lesson": {
      "reference": selected.to_json(),
      "title": draft.title,
      "guidance": draft.guidance,
      "applicability": draft.applicability.to_json(),
      "invalidation": draft.invalidation.to_json(),
    },
    "review": {
      "receipt": review.receipt.to_json(),
      "reviewer_id": review.reviewer.reviewer_id,
      "decided_at": review.decided_at,
    },
    "source": {
      "outcome": draft.outcome.to_json(),
      "assessment": draft.assessment.to_json(),
      "assessment_review": draft.assessment_review.to_json(),
    },
    "selection_review": selection_review,
    "currentness": if selection_review == Json::null() {
      "legacy_unselected"
    } else {
      "current"
    },
    "journal_sequence": snapshot.last_sequence,
    "applicability_decision_required": true,
    "activation_authorized": false,
    "external_side_effects_applied": false,
  }
  if @encoding/utf8.encode(selection.stringify()).length() > 32768 {
    fail(
      "Selected guidance exceeds the export byte limit; no content was truncated",
    )
  }
  selection
}
