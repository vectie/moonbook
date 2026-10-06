///|
/// Socket-free request handler shared by the existing Book host and fixtures.
/// The caller supplies its configured Book root, never a root from request JSON.
pub async fn outcome_lesson_request(
  root : String,
  path : String,
  payload : Json,
) -> (Int, Json) noraise {
  let operation = match path {
    "/api/bookkeeper/lessons/prepare" => "prepare"
    "/api/bookkeeper/lessons/retrieve" => "retrieve"
    "/api/bookkeeper/lessons/guidance-query" => "guidance-query"
    "/api/bookkeeper/lessons/guidance-select" => "guidance-select"
    "/api/bookkeeper/lessons/task-handoff" => "task-handoff"
    "/api/bookkeeper/lessons/history" => "history"
    "/api/bookkeeper/lessons/revise" => "revise"
    "/api/bookkeeper/lessons/select" => "select"
    "/api/bookkeeper/lessons/outcome-import" => "outcome-import"
    "/api/bookkeeper/lessons/outcome-continue" => "outcome-continue"
    _ => return (404, { "ok": false, "error": "Unsupported lesson route" })
  }
  try {
    let result = if operation == "guidance-query" {
      resolve_task_guidance_query(payload)
    } else if operation == "guidance-select" {
      select_task_guidance(root, payload)
    } else if operation == "outcome-import" || operation == "outcome-continue" {
      task_outcome_operation(root, operation, payload)
    } else if operation == "history" {
      guard payload is { "lesson_id": String(id), .. } else {
        fail("history requires a lesson ID")
      }
      outcome_lesson_history(root, id)
    } else if operation == "revise" || operation == "select" {
      let result = if operation == "revise" {
        prepare_outcome_lesson_revision(root, @json.from_json(payload))
      } else {
        prepare_outcome_lesson_selection(root, @json.from_json(payload))
      }
      if !result.accepted {
        fail(result.issues.join("; "))
      }
      result.to_json()
    } else if operation == "task-handoff" {
      let handoff : OutcomeLessonTaskHandoff = @json.from_json(payload)
      resolve_outcome_lesson_handoff(root, handoff)
    } else if operation == "prepare" {
      let draft : OutcomeLessonDraft = @json.from_json(payload)
      let result = prepare_outcome_lesson(root, draft)
      if !result.accepted {
        fail(result.issues.join("; "))
      }
      result.to_json()
    } else {
      let query : OutcomeLessonQuery = @json.from_json(payload)
      retrieve_outcome_lessons(root, query)
    }
    (
      200,
      {
        "schema": "moonbook.outcome-lesson-operation.v1",
        "ok": true,
        "operation": operation,
        "result": result,
      },
    )
  } catch {
    error =>
      (
        422,
        {
          "schema": "moonbook.outcome-lesson-operation.v1",
          "ok": false,
          "operation": operation,
          "error": error.to_string(),
        },
      )
  }
}
