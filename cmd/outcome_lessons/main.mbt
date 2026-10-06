///|
async fn main {
  let args = @env.args()
  match args[1:] {
    ["history", root, lesson_id] =>
      println(
        @bookkeeper_store.outcome_lesson_history(root, lesson_id).stringify(
          indent=2,
        ),
      )
    [operation, root, path] if operation == "revise" || operation == "select" => {
      let (status, response) = @bookkeeper_store.outcome_lesson_request(
        root,
        "/api/bookkeeper/lessons/" + operation,
        @json.parse(@fsx.read_file(path)),
      )
      println(response.stringify(indent=2))
      if status != 200 {
        fail("lesson version choice was not persisted")
      }
    }
    ["prepare", root, path] => {
      let draft : @bookkeeper_store.OutcomeLessonDraft = @json.from_json(
        @json.parse(@fsx.read_file(path)),
      )
      let result = @bookkeeper_store.prepare_outcome_lesson(root, draft)
      println(result.to_json().stringify(indent=2))
      if !result.accepted {
        fail("outcome lesson was not persisted")
      }
    }
    ["retrieve", root, path] => {
      let query : @bookkeeper_store.OutcomeLessonQuery = @json.from_json(
        @json.parse(@fsx.read_file(path)),
      )
      println(
        @bookkeeper_store.retrieve_outcome_lessons(root, query).stringify(
          indent=2,
        ),
      )
    }
    _ =>
      fail(
        "Usage: outcome_lessons prepare|revise|select|retrieve <book-root> <request.json> | history <book-root> <lesson-id>",
      )
  }
}
