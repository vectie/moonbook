///|
fn guidance_test_handoff() -> Json {
  let snapshot = (
    {
      "task_id": "OPC-TASK-next",
      "project_id": "project-a",
      "product_id": "moonbook",
      "revision": 3,
    } : Json).stringify()
  {
    "contract_version": "moonproj.book-guidance-query.v1",
    "source_product": "moonproj",
    "target_task": {
      "record_id": "OPC-TASK-next",
      "record_version": "3",
      "record_digest": lesson_handoff_digest(snapshot),
    },
    "task_snapshot": snapshot,
    "conditions": [
      { "key": "project_id", "value": "project-a" },
      { "key": "suite_product_id", "value": "moonbook" },
    ],
    "authorizing": false,
  }
}

///|
async test "task guidance query route reads exact pre-start binding without journal mutation" {
  let root = @fs.tmpdir(prefix="moonbook-guidance-query-")
  let before = replay_bookkeeper_store(root)
  let handoff = guidance_test_handoff()
  let (status, response) = outcome_lesson_request(
    root, "/api/bookkeeper/lessons/guidance-query", handoff,
  )
  assert_eq(status, 200)
  let result = lesson_handoff_field(response, "result")
  assert_eq(lesson_handoff_field(result, "handoff"), handoff)
  assert_eq(
    lesson_handoff_field(result, "activation_authorized"),
    false.to_json(),
  )
  assert_eq(replay_bookkeeper_store(root), before)
}

///|
fn guidance_test_set(value : Json, key : String, replacement : Json) -> Json {
  guard value is Object(fields) else { return value }
  let fields = fields.copy()
  fields[key] = replacement
  Json::object(fields)
}

///|
fn guidance_test_query(
  handoff : Json,
  conditions : Array[OutcomeLessonCondition],
) -> Json {
  let known : Array[OutcomeLessonCondition] = @json.from_json(
    lesson_handoff_field(handoff, "conditions"),
  ) catch {
    _ => []
  }
  {
    "contract_version": "moonbook.outcome-lesson-query.v1",
    "target_task": lesson_handoff_field(handoff, "target_task"),
    "conditions": (conditions + known).to_json(),
  }
}

///|
fn guidance_test_request(
  handoff : Json,
  query : Json,
  reference : @bookkeeper.VersionedRecordReference,
) -> Json {
  { "handoff": handoff, "query": query, "lesson": reference.to_json() }
}

///|
async test "task guidance selection exports only exact accepted advice and produces serialized native fixture" {
  let root = @fs.tmpdir(prefix="moonbook-guidance-wire-")
  let draft = {
    ..lesson_test_source(root),
    guidance: "  先检查 \"关键引文\"，保留来源。\n    Preserve exact contradictory quotations <&> and test the decisive claim.\n  Internal review is not customer acceptance.  ",
  }
  let saved = prepare_outcome_lesson(root, draft)
  let record = find_record(replay_bookkeeper_store(root), saved.event.unwrap()).unwrap()
  let handoff = match @env.get_env_var("MOONPROJ_GUIDANCE_HANDOFF") {
    Some(path) => @json.parse(@fs.read_file(path).text())
    None => guidance_test_handoff()
  }
  let query = guidance_test_query(handoff, draft.applicability)
  let request = guidance_test_request(handoff, query, record.record)
  let (pending_status, _) = outcome_lesson_request(
    root, "/api/bookkeeper/lessons/guidance-select", request,
  )
  assert_eq(pending_status, 422)
  let review = closure_test_accept(root, record, "guidance-wire")
  let before = replay_bookkeeper_store(root)
  let (status, response) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/guidance-select",
    @json.parse(request.stringify()),
  )
  assert_eq(status, 200, msg=response.stringify())
  let selection = lesson_handoff_field(response, "result")
  let exported = lesson_handoff_field(selection, "lesson")
  assert_eq(lesson_handoff_field(selection, "handoff"), handoff)
  assert_eq(lesson_handoff_field(selection, "query"), query)
  assert_eq(lesson_handoff_text(exported, "guidance"), draft.guidance)
  assert_eq(
    lesson_handoff_field(exported, "reference"),
    record.record.to_json(),
  )
  assert_eq(
    lesson_handoff_field(lesson_handoff_field(selection, "review"), "receipt"),
    review.receipt.to_json(),
  )
  assert_eq(lesson_handoff_text(selection, "currentness"), "legacy_unselected")
  assert_false(selection.stringify().contains("outcome_summary"))
  assert_false(selection.stringify().contains("assessment_summary"))
  assert_false(selection.stringify().contains("evidence_refs"))
  assert_false(selection.stringify().contains("owner_route"))
  assert_eq(replay_bookkeeper_store(root), before)
  // The existing source application and target suite tag intentionally differ.
  let outcome = find_record(before, draft.outcome).unwrap()
  assert_eq(outcome.source_product, "moonfind")
  let target = @json.parse(lesson_handoff_text(handoff, "task_snapshot"))
  assert_false(
    lesson_handoff_text(target, "product_id") == outcome.source_product,
  )
  let (query_status, query_response) = outcome_lesson_request(
    root, "/api/bookkeeper/lessons/guidance-query", handoff,
  )
  let (retrieval_status, retrieval_response) = outcome_lesson_request(
    root, "/api/bookkeeper/lessons/retrieve", query,
  )
  assert_eq(query_status, 200)
  assert_eq(retrieval_status, 200)
  if @env.get_env_var("MOONBOOK_GUIDANCE_WIRE") is Some(path) {
    let wire : Json = {
      "handoff": handoff,
      "query": query,
      "reference": record.record.to_json(),
      "query_response": query_response,
      "retrieval_response": retrieval_response,
      "selection_request": request,
      "selection_response": response,
      "journal_root": root,
    }
    @fs.write_file(path, wire.stringify(indent=2), create_mode=CreateOrTruncate)
  }
}

///|
async test "task guidance rejects missing wrong invalidated scope and never conflates product namespaces" {
  let (root, original, record) = version_fixture()
  let handoff = guidance_test_handoff()
  let before = replay_bookkeeper_store(root)
  for
    conditions in [
      [],
      [{ key: "customer_id", value: "customer-a", }],
      [
        { key: "customer_id", value: "customer-b", },
        { key: "decision_kind", value: "vendor-comparison", },
      ],
      original.applicability + [{ key: "evidence_state", value: "superseded", }],
    ] {
    let request = guidance_test_request(
      handoff,
      guidance_test_query(handoff, conditions),
      record.record,
    )
    let (status, _) = outcome_lesson_request(
      root, "/api/bookkeeper/lessons/guidance-select", request,
    )
    assert_eq(status, 422)
  }
  let wrong = guidance_test_set(
    guidance_test_query(handoff, original.applicability),
    "target_task",
    submission_test_ref("another-task").to_json(),
  )
  assert_eq(
    outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/guidance-select",
      guidance_test_request(handoff, wrong, record.record),
    ).0,
    422,
  )
  assert_eq(replay_bookkeeper_store(root), before)
  let scoped = {
    ..original,
    lesson_id: "business-product-scope",
    applicability: original.applicability +
    [{ key: "product_id", value: "customer-product-42", }],
  }
  let saved = prepare_outcome_lesson(root, scoped)
  let scoped_record = find_record(
    replay_bookkeeper_store(root),
    saved.event.unwrap(),
  ).unwrap()
  ignore(closure_test_accept(root, scoped_record, "business-product"))
  // Suite tag cannot satisfy a customer's business-product condition.
  assert_eq(
    outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/guidance-select",
      guidance_test_request(
        handoff,
        guidance_test_query(handoff, original.applicability),
        scoped_record.record,
      ),
    ).0,
    422,
  )
  assert_eq(
    outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/guidance-select",
      guidance_test_request(
        handoff,
        guidance_test_query(handoff, scoped.applicability),
        scoped_record.record,
      ),
    ).0,
    200,
  )
}

///|
async test "task guidance fresh selection refuses rejected and historical guidance after review changes" {
  let (root, draft, original) = version_fixture()
  let handoff = guidance_test_handoff()
  let query = guidance_test_query(handoff, draft.applicability)
  let historical = guidance_test_request(handoff, query, original.record)
  assert_eq(
    outcome_lesson_request(
      root, "/api/bookkeeper/lessons/guidance-select", historical,
    ).0,
    200,
  )
  let revision = version_revision(root, draft, original, "2")
  let current = version_record(
    root,
    prepare_outcome_lesson_revision(root, revision),
  )
  let mutation = version_mutation(root, current, "guidance-current")
  assert_true(apply_governed_review(root, mutation).accepted)
  let before = replay_bookkeeper_store(root)
  assert_eq(
    outcome_lesson_request(
      root, "/api/bookkeeper/lessons/guidance-select", historical,
    ).0,
    422,
  )
  let (status, response) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/guidance-select",
    guidance_test_request(handoff, query, current.record),
  )
  assert_eq(status, 200)
  assert_eq(
    lesson_handoff_text(lesson_handoff_field(response, "result"), "currentness"),
    "current",
  )
  assert_eq(replay_bookkeeper_store(root), before)
  let restore = version_selection(root, draft, original, "guidance-restore")
  let restore_record = version_record(
    root,
    prepare_outcome_lesson_selection(root, restore),
  )
  assert_true(
    apply_governed_review(
      root,
      version_mutation(root, restore_record, "guidance-restore"),
    ).accepted,
  )
  assert_eq(
    outcome_lesson_request(
      root, "/api/bookkeeper/lessons/guidance-select", historical,
    ).0,
    200,
  )
  assert_eq(
    outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/guidance-select",
      guidance_test_request(handoff, query, current.record),
    ).0,
    422,
  )
  let rejected_draft = { ..draft, lesson_id: "rejected-advice", }
  let rejected = version_record(
    root,
    prepare_outcome_lesson(root, rejected_draft),
  )
  ignore(
    closure_test_decide(root, rejected, "guidance-rejected", @bookkeeper.Reject),
  )
  assert_eq(
    outcome_lesson_request(
      root,
      "/api/bookkeeper/lessons/guidance-select",
      guidance_test_request(handoff, query, rejected.record),
    ).0,
    422,
  )
}

///|
async test "task guidance query rejects rewritten identity context and private payload extensions" {
  let root = @fs.tmpdir(prefix="moonbook-guidance-invalid-")
  let valid = guidance_test_handoff()
  for
    bad in [
      guidance_test_set(valid, "authorizing", true.to_json()),
      guidance_test_set(valid, "conditions", [].to_json()),
      guidance_test_set(valid, "source_product", "moonfind".to_json()),
      guidance_test_set(valid, "task_snapshot", "{}".to_json()),
      guidance_test_set(valid, "raw_outcome", "private".to_json()),
    ] {
    assert_eq(
      outcome_lesson_request(
        root, "/api/bookkeeper/lessons/guidance-query", bad,
      ).0,
      422,
    )
  }
}

///|
async test "task guidance actual UI serialized requests replay through production handler unchanged" {
  guard @env.get_env_var("MOONBOOK_GUIDANCE_UI_REQUESTS") is Some(path) else {
    return
  }
  let fixture = @json.parse(@fs.read_file(path).text())
  let root = lesson_handoff_text(fixture, "journal_root")
  let before = replay_bookkeeper_store(root)
  guard lesson_handoff_field(fixture, "requests") is Array(requests) else {
    fail("Missing actual UI requests")
  }
  for request in requests {
    let path = lesson_handoff_text(request, "url")
    let payload = lesson_handoff_field(request, "body")
    let (status, response) = outcome_lesson_request(
      root,
      path,
      @json.parse(payload.stringify()),
    )
    assert_eq(status, 200, msg=response.stringify())
    assert_eq(response, lesson_handoff_field(request, "response"))
  }
  assert_eq(requests.length(), 3)
  assert_eq(replay_bookkeeper_store(root), before)
}
