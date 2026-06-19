///|
test "book result emits portable executable book event" {
  let result : BookResult = {
    task_id: "task-code-tool",
    summary: "Accepted a book-owned miniapp implementation.",
    artifacts: ["tools/summarize/main.mbt", "wiki/reviews/approved.md"],
    memory_candidates: [],
    requires_review: false,
    notify_town: true,
  }
  let event = result.to_executable_book_event(
    book_id="research-tools",
    evidence_id=Some("EV-tool"),
    run_id=Some("run-1"),
  )
  assert_eq(event.protocol, "moonbook.executable_event.v1")
  assert_eq(event.source, "moonbook")
  assert_eq(event.event_type, "knowledge_accepted")
  assert_true(event.accepted)
  assert_true(event.notify_town)
  assert_true(event.artifacts.contains("tools/summarize/main.mbt"))
  let text = event.to_json().stringify()
  assert_true(text.contains("\"protocol\":\"moonbook.executable_event.v1\""))
  assert_true(text.contains("\"book_id\":\"research-tools\""))
  assert_true(text.contains("\"evidence_id\":\"EV-tool\""))
}

///|
test "review-required book result is not treated as accepted knowledge" {
  let result : BookResult = {
    task_id: "task-review",
    summary: "Needs Bookkeeper review before durable promotion.",
    artifacts: ["raw/analysis-runs/run-1/report.md"],
    memory_candidates: [],
    requires_review: true,
    notify_town: true,
  }
  let event = result.to_executable_book_event(
    book_id="research-tools",
    evidence_id=Some("EV-review"),
    review_path=Some("wiki/reviews/pending.md"),
  )
  assert_eq(event.event_type, "review_required")
  assert_true(!event.accepted)
  assert_true(event.requires_review)
  assert_true(event.review_path is Some("wiki/reviews/pending.md"))
}

///|
test "decode book result payload accepts direct BookResult json" {
  let decoded = decode_book_result_payload({
    "task_id": "task-direct",
    "summary": "Direct worker result.",
    "artifacts": ["wiki/direct.md"],
    "memory_candidates": Json::array([]),
    "requires_review": false,
    "notify_town": true,
  })
  assert_eq(decoded.task_id, "task-direct")
  assert_true(decoded.artifacts.contains("wiki/direct.md"))
  assert_true(decoded.notify_town)
}

///|
test "decode book result payload accepts MoonClaw sidecar envelope" {
  let decoded = decode_book_result_payload({
    "kind": "mooncode-book-result",
    "protocol": "moonbook.executable_event.v1",
    "owner": "moonclaw",
    "book_result": {
      "task_id": "cmd-runtime-prompt",
      "summary": "Created a MoonBook-owned executable tool.",
      "artifacts": [
        "portable/app-tool/mooncode/session/book-result-cmd-runtime-prompt.json",
        "tools/mooncode-generated/cmd-runtime-prompt/run.sh",
      ],
      "memory_candidates": Json::array([]),
      "requires_review": true,
      "notify_town": true,
    },
    "executable_book_event": {
      "protocol": "moonbook.executable_event.v1",
      "event_type": "review_required",
    },
  })
  assert_eq(decoded.task_id, "cmd-runtime-prompt")
  assert_true(decoded.requires_review)
  assert_true(decoded.notify_town)
  assert_true(
    decoded.artifacts.contains(
      "tools/mooncode-generated/cmd-runtime-prompt/run.sh",
    ),
  )
}

///|
async test "persist result writes MoonBook executable event files" {
  let root = "/tmp/moonbook-executable-event-\{@async.now().to_int()}"
  ignore(init_workspace(root))
  let outcome = persist_result(root, {
    task_id: "task-persist-event",
    summary: "Persisted executable book output.",
    artifacts: ["tools/demo/main.mbt"],
    memory_candidates: [],
    requires_review: false,
    notify_town: true,
  })
  assert_true(outcome.executable_event.accepted)
  assert_eq(outcome.executable_event.event_type, "knowledge_accepted")
  assert_true(outcome.executable_event_path.has_prefix(".moonbook/events/"))
  assert_eq(
    outcome.latest_executable_event_path,
    ".moonbook/events/latest.json",
  )
  let event_text = @fsx.read_file(root + "/" + outcome.executable_event_path)
  assert_true(
    event_text.contains("\"protocol\": \"moonbook.executable_event.v1\""),
  )
  assert_true(event_text.contains("\"accepted\": true"))
  let latest_text = @fsx.read_file(
    root + "/" + outcome.latest_executable_event_path,
  )
  assert_true(
    latest_text.contains("\"id\": \"\{outcome.executable_event.id}\""),
  )
}
