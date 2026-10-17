///|
fn browser_test_query(text~ : String = "") -> OutcomeLessonBrowseQuery {
  { contract_version: "moonbook.outcome-lesson-browse-query.v1", text, }
}

///|
fn browser_test_lessons(result : Json) -> Array[Json] raise {
  guard result is { "lessons": Array(values), .. } else {
    fail("missing lesson cards")
  }
  values
}

///|
fn browser_test_refs(result : Json) -> Array[Json] raise {
  browser_test_lessons(result).map(value => {
    match value {
      { "lesson": { "record": reference, .. }, .. } => reference
      _ => ().to_json()
    }
  })
}

///|
async test "planning browser finds accepted guidance without task metadata and preserves exact review and conditions" {
  let (root, draft, original) = version_fixture()
  let before = replay_bookkeeper_store(root)
  let journal_files = @fsx.list_directory(journal_root(root))
  let bytes : Array[String] = []
  for path in journal_files {
    bytes.push(@fsx.read_file(path))
  }
  let query = browser_test_query()
  let result = browse_outcome_lessons(root, query)
  assert_eq(browser_test_refs(result), [original.record.to_json()])
  guard result
    is {
      "query": actual_query,
      "lessons": [
        {
          "lesson": actual_lesson,
          "review": actual_review,
          "selection_review": Null,
          ..
        },
      ],
      "exclusions": [],
      "activation_authorized": false,
      "external_side_effects_applied": false,
      ..
    } else {
    fail("unexpected browser contract")
  }
  assert_eq(actual_query, query.to_json())
  assert_eq(actual_lesson, original.to_json())
  assert_eq(
    actual_review,
    lesson_accepted_review(before, original).unwrap().to_json(),
  )
  assert_false(result.stringify().contains("target_task"))
  for
    text in [
      "CONTRADICTIONS",
      "  vendor\n customer-A  ",
      "decisive\tclaim",
      "evidence_state superseded",
      "customer_id",
      lesson_accepted_review(before, original).unwrap().reviewer.reviewer_id,
      draft.lesson_id,
    ] {
    assert_eq(
      browser_test_refs(browse_outcome_lessons(root, browser_test_query(text~))),
      [original.record.to_json()],
      msg=text,
    )
  }
  assert_true(
    browser_test_lessons(
      browse_outcome_lessons(
        root,
        browser_test_query(text="unrelated-customer"),
      ),
    ).is_empty(),
  )
  assert_eq(browse_outcome_lessons(root, query), result)
  assert_eq(replay_bookkeeper_store(root), before)
  assert_eq(@fsx.list_directory(journal_root(root)), journal_files)
  for i, path in journal_files {
    assert_eq(@fsx.read_file(path), bytes[i])
  }
  // Planning discovery does not widen the task-scoped retrieval contract.
  assert_true(
    lesson_test_matches(
      retrieve_outcome_lessons(
        root,
        lesson_test_query([{ key: "customer_id", value: "other", }]),
      ),
    ).is_empty(),
  )
  if @env.get_env_var("MOONBOOK_BROWSER_RESTART") is Some(path) {
    @fs.write_file(
      path,
      ({ "root": root, "query": query.to_json(), "result": result } : Json).stringify(
        indent=2,
      ),
      create_mode=CreateOrTruncate,
    )
  }
}

///|
async test "browser separates proposed rejected historical and ambiguous legacy versions from current cards" {
  let (root, draft, original) = version_fixture()
  let proposed = version_record(
    root,
    prepare_outcome_lesson(root, { ..draft, lesson_version: "proposed", }),
  )
  let rejected = version_record(
    root,
    prepare_outcome_lesson(root, { ..draft, lesson_version: "rejected", }),
  )
  ignore(
    closure_test_decide(root, rejected, "browser-rejected", @bookkeeper.Reject),
  )
  let result = browse_outcome_lessons(root, browser_test_query())
  assert_eq(browser_test_refs(result), [original.record.to_json()])
  assert_true(result is { "exclusions": [_, _], .. })
  let legacy = version_record(
    root,
    prepare_outcome_lesson(root, {
      ..draft,
      lesson_version: "legacy",
      guidance: "Independent alternate approach",
    }),
  )
  ignore(closure_test_accept(root, legacy, "browser-legacy"))
  let ambiguous = browse_outcome_lessons(root, browser_test_query())
  assert_eq(browser_test_refs(ambiguous), [])
  guard ambiguous is { "exclusions": Array(exclusions), .. } else {
    fail("missing exclusions")
  }
  assert_eq(exclusions.length(), 4)
  assert_true(
    exclusions.any(value => {
      value is { "reason": String(reason), .. } &&
      reason.contains("no selected current version")
    }),
  )
  let selected = version_record(
    root,
    prepare_outcome_lesson_selection(
      root,
      version_selection(root, draft, original, "browser-choose"),
    ),
  )
  ignore(closure_test_accept(root, selected, "browser-choose"))
  assert_eq(
    browser_test_refs(browse_outcome_lessons(root, browser_test_query())),
    [original.record.to_json()],
  )
  let historical = browse_outcome_lessons(
    root,
    browser_test_query(text="Independent alternate"),
  )
  assert_true(
    historical
    is { "lessons": [], "exclusions": [{ "reason": String(reason), .. }], .. } &&
    reason.contains("historical"),
  )
  assert_eq(
    find_record(replay_bookkeeper_store(root), proposed.record),
    Some(proposed),
  )
}

///|
async test "browser follows reviewed revisions and rollback without changing immutable source history" {
  let (root, draft, original) = version_fixture()
  let second = version_record(
    root,
    prepare_outcome_lesson_revision(
      root,
      version_revision(root, draft, original, "2"),
    ),
  )
  assert_eq(
    browser_test_refs(browse_outcome_lessons(root, browser_test_query())),
    [original.record.to_json()],
  )
  ignore(closure_test_accept(root, second, "browser-revision"))
  assert_eq(
    browser_test_refs(browse_outcome_lessons(root, browser_test_query())),
    [second.record.to_json()],
  )
  let rollback = version_record(
    root,
    prepare_outcome_lesson_selection(
      root,
      version_selection(root, draft, original, "browser-rollback"),
    ),
  )
  assert_eq(
    browser_test_refs(browse_outcome_lessons(root, browser_test_query())),
    [second.record.to_json()],
  )
  let review = closure_test_accept(root, rollback, "browser-rollback")
  let before = replay_bookkeeper_store(root)
  let history = outcome_lesson_history(root, draft.lesson_id)
  let result = browse_outcome_lessons(root, browser_test_query())
  assert_eq(browser_test_refs(result), [original.record.to_json()])
  assert_true(
    result is { "lessons": [{ "selection_review": actual, .. }], .. } &&
    actual == review.receipt.to_json(),
  )
  assert_eq(outcome_lesson_history(root, draft.lesson_id), history)
  assert_eq(replay_bookkeeper_store(root), before)
  ignore(rebuild_bookkeeper_projection(root))
  assert_eq(browse_outcome_lessons(root, browser_test_query()), result)
}

///|
async test "browser host route validates contract and corrupt replay fails closed" {
  let (root, draft, _) = version_fixture()
  assert_true(
    prepare_outcome_lesson(root, {
      ..draft,
      lesson_version: "pending-browser-wire",
    }).accepted,
  )
  let query = browser_test_query(text="vendor")
  let before = replay_bookkeeper_store(root)
  let (status, response) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/browse",
    query.to_json(),
  )
  assert_eq(status, 200)
  assert_true(
    response
    is {
      "schema": "moonbook.outcome-lesson-operation.v1",
      "operation": "browse",
      "ok": true,
      "result": {
        "query": actual,
        "lessons": [_],
        "activation_authorized": false,
        "external_side_effects_applied": false,
        ..
      },
      ..
    } &&
    actual == query.to_json(),
  )
  assert_eq(replay_bookkeeper_store(root), before)
  if @env.get_env_var("MOONBOOK_BROWSER_WIRE") is Some(path) {
    @fs.write_file(
      path,
      ({ "query": query.to_json(), "response": response } : Json).stringify(
        indent=2,
      ),
      create_mode=CreateOrTruncate,
    )
  }
  let invalid : Array[Json] = [
    {},
    { "contract_version": "wrong", "text": "" },
    { "contract_version": "moonbook.outcome-lesson-browse-query.v1" },
  ]
  for payload in invalid {
    assert_eq(
      outcome_lesson_request(root, "/api/bookkeeper/lessons/browse", payload).0,
      422,
    )
  }
  @fs.write_file(
    journal_root(root) + "/corrupt.json",
    "not json",
    create_mode=CreateNew,
  )
  let (status, response) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/browse",
    query.to_json(),
  )
  assert_eq(status, 422)
  assert_true(
    response is { "ok": false, "error": String(error), .. } &&
    error.contains("replay issues"),
  )
}

///|
async test "browser never shows an ambiguous final acceptance as current guidance" {
  let (root, _, original) = version_fixture()
  ignore(
    closure_test_decide(
      root,
      original,
      "browser-second-final",
      @bookkeeper.Reject,
    ),
  )
  let (status, response) = outcome_lesson_request(
    root,
    "/api/bookkeeper/lessons/browse",
    browser_test_query().to_json(),
  )
  assert_eq(status, 422)
  assert_true(
    response is { "ok": false, "error": String(error), .. } &&
    error.contains("ambiguous"),
  )
}
