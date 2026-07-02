///|
test "book result emits portable executable book event" {
  let result : BookResult = {
    result_id: "task-code-tool",
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
    result_id: "task-review",
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
    "result_id": "result-direct",
    "summary": "Direct worker result.",
    "artifacts": ["wiki/direct.md"],
    "memory_candidates": Json::array([]),
    "requires_review": false,
    "notify_town": true,
  })
  assert_eq(decoded.result_id, "result-direct")
  assert_true(decoded.artifacts.contains("wiki/direct.md"))
  assert_true(decoded.notify_town)
}

///|
test "decode book result payload accepts MoonClaw sidecar envelope" {
  let decoded = decode_book_result_payload({
    "kind": "mooncode-book-result",
    "protocol": "moonbook.executable_event.v1",
    "owner": "moonclaw",
    "command_id": "cmd-runtime-prompt",
    "result_id": "mooncode-session-cmd-runtime-prompt",
    "book_result": {
      "result_id": "mooncode-session-cmd-runtime-prompt",
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
      "command_id": "cmd-runtime-prompt",
      "result_id": "mooncode-session-cmd-runtime-prompt",
      "event_type": "review_required",
    },
  })
  assert_eq(decoded.result_id, "mooncode-session-cmd-runtime-prompt")
  assert_true(decoded.requires_review)
  assert_true(decoded.notify_town)
  assert_true(
    decoded.artifacts.contains(
      "tools/mooncode-generated/cmd-runtime-prompt/run.sh",
    ),
  )
}

///|
test "decode book result payload keeps executable lifecycle proof" {
  let decoded = decode_book_result_payload_with_metadata({
    "kind": "mooncode-book-result",
    "protocol": "moonbook.executable_event.v1",
    "owner": "moonclaw",
    "command_id": "cmd-runtime-prompt",
    "result_id": "mooncode-session-cmd-runtime-prompt",
    "book_result": {
      "result_id": "mooncode-session-cmd-runtime-prompt",
      "summary": "Created a MoonBook-owned executable tool.",
      "artifacts": ["tools/mooncode-generated/cmd-runtime-prompt/run.sh"],
      "memory_candidates": Json::array([]),
      "requires_review": true,
      "notify_town": true,
    },
    "executable_book_lifecycle": {
      "kind": "mooncode-executable-book-lifecycle-report",
      "protocol": "mooncode.v1",
      "contract_id": "mooncode-executable-book-lifecycle.v1",
      "owner": "moonclaw",
      "session_id": "mooncode-session",
      "book_root": "/tmp/research-tools",
      "ready": false,
      "status": "blocked",
      "completed_step_count": 6,
      "step_count": 9,
      "blocked_step_count": 3,
      "first_blocker_id": "accept_result",
      "first_blocker_label": "Accept result",
      "first_blocker_evidence": "accepted receipt/book result present false",
      "steps": Json::array([]),
      "rule": "Lifecycle status is based on durable sidecars.",
    },
  })
  assert_eq(decoded.result.result_id, "mooncode-session-cmd-runtime-prompt")
  assert_true(decoded.lifecycle_proof is Some(_))
  let proof = decoded.lifecycle_proof.unwrap()
  assert_eq(proof.contract_id, "mooncode-executable-book-lifecycle.v1")
  assert_eq(proof.owner, "moonclaw")
  assert_true(!proof.ready)
  assert_eq(proof.first_blocker_id, "accept_result")
}

///|
test "executable book event carries lifecycle proof" {
  let proof : ExecutableBookLifecycleProof = {
    contract_id: "mooncode-executable-book-lifecycle.v1",
    owner: "moonclaw",
    session_id: "mooncode-session",
    book_root: "/tmp/research-tools",
    ready: true,
    status: "complete",
    completed_step_count: 9,
    step_count: 9,
    blocked_step_count: 0,
    first_blocker_id: "",
    first_blocker_label: "",
    first_blocker_evidence: "",
  }
  let result : BookResult = {
    result_id: "task-code-tool",
    summary: "Accepted a book-owned miniapp implementation.",
    artifacts: ["tools/summarize/main.mbt"],
    memory_candidates: [],
    requires_review: false,
    notify_town: true,
  }
  let event = result.to_executable_book_event(
    book_id="research-tools",
    evidence_id=Some("EV-tool"),
    lifecycle_proof=Some(proof),
  )
  assert_true(event.lifecycle_proof is Some(_))
  assert_true(event.accepted)
  let text = event.to_json().stringify()
  assert_true(
    text.contains("\"contract_id\":\"mooncode-executable-book-lifecycle.v1\""),
  )
  assert_true(text.contains("\"status\":\"complete\""))
}

///|
async test "persist result writes MoonBook executable event files" {
  let root = "/tmp/moonbook-executable-event-\{@async.now().to_int()}"
  ignore(init_workspace(root))
  let outcome = persist_result(root, {
    result_id: "task-persist-event",
    summary: "Persisted executable book output.",
    artifacts: ["tools/demo/main.mbt"],
    memory_candidates: [],
    requires_review: false,
    notify_town: true,
  })
  assert_true(outcome.executable_event.accepted)
  assert_eq(outcome.executable_event.event_type, "knowledge_accepted")
  assert_true(outcome.executable_event_path.has_prefix("events/"))
  assert_eq(outcome.latest_executable_event_path, "events/latest.json")
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

///|
async test "persist result writes lifecycle proof into executable event" {
  let root = "/tmp/moonbook-executable-lifecycle-\{@async.now().to_int()}"
  ignore(init_workspace(root))
  let proof : ExecutableBookLifecycleProof = {
    contract_id: "mooncode-executable-book-lifecycle.v1",
    owner: "moonclaw",
    session_id: "mooncode-session",
    book_root: root,
    ready: false,
    status: "blocked",
    completed_step_count: 7,
    step_count: 9,
    blocked_step_count: 2,
    first_blocker_id: "package_output",
    first_blocker_label: "Package output",
    first_blocker_evidence: "package results 0, package events 0",
  }
  let outcome = persist_result(
    root,
    {
      result_id: "task-persist-lifecycle",
      summary: "Persisted executable book output with runtime proof.",
      artifacts: ["tools/demo/main.mbt"],
      memory_candidates: [],
      requires_review: true,
      notify_town: true,
    },
    lifecycle_proof=Some(proof),
  )
  assert_true(outcome.executable_event.lifecycle_proof is Some(_))
  assert_true(!outcome.executable_event.accepted)
  let event_text = @fsx.read_file(root + "/" + outcome.executable_event_path)
  assert_true(
    event_text.contains(
      "\"contract_id\": \"mooncode-executable-book-lifecycle.v1\"",
    ),
  )
  assert_true(event_text.contains("\"first_blocker_id\": \"package_output\""))
}
