///|
// Private wire mirrors of wiki/extension_api_types.mbt. Keeping this narrowly
// scoped package independent of wiki avoids loading legacy provider/materializer
// code. wiki/native_wenyu_import_test.mbt decodes the result with the existing
// public types and compares the event constructor. No legacy type is changed.
priv struct MemoryCandidate {
  kind : String
  title : String
  detail : String
  durable : Bool
  target_page : String?
} derive(Debug, ToJson, FromJson)

///|
priv struct BookResult {
  result_id : String
  summary : String
  artifacts : Array[String]
  memory_candidates : Array[MemoryCandidate]
  requires_review : Bool
  notify_town : Bool
} derive(Debug, ToJson, FromJson)

///|
priv struct ExecutableBookEvent {
  protocol : String
  id : String
  source : String
  book_id : String
  result_id : String
  run_id : String?
  event_type : String
  accepted : Bool
  requires_review : Bool
  notify_town : Bool
  summary : String
  artifacts : Array[String]
  evidence_id : String?
  review_path : String?
  // This contract has no lifecycle proof input. None is omitted by ToJson,
  // matching the existing wiki ExecutableBookEvent wire format.
  lifecycle_proof : Json?
} derive(Debug, ToJson, FromJson)

///|
priv struct PersistResultOutcome {
  log_path : String
  updated_pages : Array[String]
  review_queued : Bool
  notify_town : Bool
  evidence_id : String
  executable_event_path : String
  latest_executable_event_path : String
  executable_event : ExecutableBookEvent
} derive(Debug, ToJson, FromJson)

///|
// Mirrors BookResult::to_executable_book_event for the enforced review=true,
// notify=true Wenyu scope. The cross-package regression guards wire drift.
fn native_wenyu_event(
  root : String,
  result : BookResult,
  evidence_id : String,
) -> ExecutableBookEvent {
  let mut book_id = ""
  for part in root.split("/") {
    if !part.is_empty() {
      book_id = part.to_owned()
    }
  }
  {
    protocol: "moonbook.executable_event.v1",
    id: "book-event-\{book_id}-\{evidence_id}",
    source: "moonbook",
    book_id,
    result_id: result.result_id,
    run_id: None,
    event_type: "review_required",
    accepted: false,
    requires_review: true,
    notify_town: true,
    summary: result.summary,
    artifacts: result.artifacts,
    evidence_id: Some(evidence_id),
    review_path: Some("wiki/reviews/pending.md"),
    lifecycle_proof: None,
  }
}
