///|
// Public Extension API data contracts and package-local coverage summaries.

///|
pub struct BookTask {
  id : String
  title : String
  kind : String
  prompt : String
  priority : Int
  requires_review : Bool
  target_pages : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct BookTaskBatch {
  goal_id : String
  goal : String
  summary : String
  tasks : Array[BookTask]
} derive(Debug, ToJson, FromJson)

///|
pub struct BookGoalAcceptance {
  goal_id : String
  accepted : Bool
  reason : String
  task_count : Int
  summary : String
} derive(Debug, ToJson, FromJson)

///|
pub struct WorkerContextBundle {
  book_id : String
  workspace_root : String
  task_id : String
  prompt : String
  policy : Array[String]
  routines : Array[String]
  skill_paths : Array[String]
  context_pages : Array[String]
  active_memory : Array[String]
  user_memory : Array[String]
  working_memory : Array[String]
  memory_summary : String
  output_contract : Array[String]
} derive(Debug, ToJson, FromJson)

///|
pub struct MemoryCandidate {
  kind : String
  title : String
  detail : String
  durable : Bool
  target_page : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct BookResult {
  result_id : String
  summary : String
  artifacts : Array[String]
  memory_candidates : Array[MemoryCandidate]
  requires_review : Bool
  notify_town : Bool
} derive(Debug, ToJson, FromJson)

///|
pub struct ExecutableBookLifecycleProof {
  contract_id : String
  owner : String
  session_id : String
  book_root : String
  ready : Bool
  status : String
  completed_step_count : Int
  step_count : Int
  blocked_step_count : Int
  first_blocker_id : String
  first_blocker_label : String
  first_blocker_evidence : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct DecodedBookResultPayload {
  result : BookResult
  lifecycle_proof : ExecutableBookLifecycleProof?
} derive(Debug, ToJson, FromJson)

///|
pub fn decode_book_result_payload(value : Json) -> BookResult raise {
  @json.from_json(value) catch {
    _ =>
      match decode_provider_task_result(value) {
        Some(result) => result
        None => decode_book_result_envelope(value)
      }
  }
}

///|
/// MoonClaw's provider transport names the stable result key `task_id` while
/// MoonBook's durable contract calls it `result_id`. Accept that transport
/// shape at the provider boundary and normalize it immediately; persisted book
/// events continue to use only MoonBook terminology.
fn decode_provider_task_result(value : Json) -> BookResult? {
  guard value is Object(fields) else { return None }
  guard fields.get("task_id") is Some(String(task_id)) else { return None }
  let normalized : Map[String, Json] = {}
  for key, value in fields {
    normalized[key] = value
  }
  normalized.remove("task_id")
  normalized["result_id"] = task_id.to_json()
  Some(@json.from_json(Json::object(normalized))) catch {
    _ => None
  }
}

///|
pub fn decode_book_result_payload_text(text : String) -> BookResult raise {
  decode_book_result_payload(@json.parse(text))
}

///|
pub fn decode_book_result_payload_with_metadata(
  value : Json,
) -> DecodedBookResultPayload raise {
  {
    result: decode_book_result_payload(value),
    lifecycle_proof: decode_book_result_lifecycle_proof(value),
  }
}

///|
pub fn decode_book_result_payload_with_metadata_text(
  text : String,
) -> DecodedBookResultPayload raise {
  decode_book_result_payload_with_metadata(@json.parse(text))
}

///|
fn decode_book_result_envelope(value : Json) -> BookResult raise {
  match value {
    Object(fields) =>
      match fields.get("book_result") {
        Some(Object(_) as nested) =>
          @json.from_json(nested) catch {
            error =>
              fail(
                "invalid book_result envelope: nested book_result is not a BookResult: \{error}",
              )
          }
        _ =>
          match fields.get("content") {
            Some(String(content)) =>
              decode_book_result_payload_text(content) catch {
                error =>
                  fail(
                    "invalid book result envelope: content is not a BookResult: \{error}",
                  )
              }
            _ =>
              fail(
                "invalid book result payload: expected BookResult, a book_result object, or a content string containing a BookResult",
              )
          }
      }
    _ =>
      fail(
        "invalid book result payload: expected BookResult or envelope with object field book_result",
      )
  }
}

///|
pub fn decode_book_result_lifecycle_proof(
  value : Json,
) -> ExecutableBookLifecycleProof? raise {
  match value {
    Object(fields) =>
      match fields.get("executable_book_lifecycle") {
        Some(Object(_) as proof) =>
          Some(decode_executable_book_lifecycle_proof(proof))
        Some(_) =>
          fail(
            "invalid book result payload: executable_book_lifecycle must be an object",
          )
        None =>
          match fields.get("lifecycle_proof") {
            Some(Object(_) as proof) =>
              Some(decode_executable_book_lifecycle_proof(proof))
            Some(_) =>
              fail(
                "invalid book result payload: lifecycle_proof must be an object",
              )
            None => None
          }
      }
    _ => None
  }
}

///|
pub fn decode_executable_book_lifecycle_proof(
  value : Json,
) -> ExecutableBookLifecycleProof raise {
  @json.from_json(value) catch {
    error =>
      fail(
        "invalid executable book lifecycle proof: expected mooncode executable-book lifecycle report: \{error}",
      )
  }
}

///|
pub struct PersistResultOutcome {
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
pub fn executable_book_event_protocol() -> String {
  "moonbook.executable_event.v1"
}

///|
pub struct ExecutableBookEvent {
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
  lifecycle_proof : ExecutableBookLifecycleProof?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ExecutableBookEvent::new(
  id~ : String,
  book_id~ : String,
  result_id~ : String,
  summary~ : String,
  artifacts? : Array[String] = [],
  run_id? : String? = None,
  event_type? : String = "knowledge_accepted",
  accepted? : Bool = true,
  requires_review? : Bool = false,
  notify_town? : Bool = false,
  evidence_id? : String? = None,
  review_path? : String? = None,
  lifecycle_proof? : ExecutableBookLifecycleProof? = None,
) -> ExecutableBookEvent {
  {
    protocol: executable_book_event_protocol(),
    id,
    source: "moonbook",
    book_id,
    result_id,
    run_id,
    event_type,
    accepted,
    requires_review,
    notify_town,
    summary,
    artifacts,
    evidence_id,
    review_path,
    lifecycle_proof,
  }
}

///|
pub fn BookResult::to_executable_book_event(
  self : BookResult,
  book_id~ : String,
  evidence_id? : String? = None,
  run_id? : String? = None,
  review_path? : String? = None,
  lifecycle_proof? : ExecutableBookLifecycleProof? = None,
) -> ExecutableBookEvent {
  let evidence_part = evidence_id.unwrap_or(self.result_id)
  let event_type = if self.requires_review {
    "review_required"
  } else {
    "knowledge_accepted"
  }
  ExecutableBookEvent::new(
    id="book-event-\{book_id}-\{evidence_part}",
    book_id~,
    result_id=self.result_id,
    summary=self.summary,
    artifacts=self.artifacts,
    run_id~,
    event_type~,
    accepted=!self.requires_review,
    requires_review=self.requires_review,
    notify_town=self.notify_town,
    evidence_id~,
    review_path~,
    lifecycle_proof~,
  )
}

///|
pub struct BookStateSummary {
  book_id : String
  root : String
  page_count : Int
  source_count : Int
  source_page_count : Int
  candidate_source_count : Int
  provisional_source_count : Int
  verified_source_count : Int
  entity_count : Int
  entity_page_count : Int
  concept_count : Int
  concept_page_count : Int
  query_note_count : Int
  pending_review_count : Int
  keeper_memory_count : Int
  keeper_working_count : Int
  evidence_count : Int
  total_evidence_count : Int
  operational_evidence_count : Int
  substantive_coverage_ready : Bool
  summary : String
} derive(Debug, ToJson, FromJson)

///|
pub struct BookHealthReport {
  level : String
  summary : String
  source_page_count : Int
  candidate_source_count : Int
  provisional_source_count : Int
  verified_source_count : Int
  entity_page_count : Int
  concept_page_count : Int
  query_note_count : Int
  pending_review_count : Int
  low_confidence_claim_count : Int
  maintenance_entry_count : Int
  keeper_working_count : Int
  evidence_count : Int
  substantive_coverage_ready : Bool
  issues : Array[String]
} derive(Debug, ToJson, FromJson)

///|
pub struct BookCatalogRecord {
  id : String
  name : String
  purpose : String
  workspace_root : String
  memory_scope : String
  tags : Array[String]
  skills : Array[String]
} derive(Debug, ToJson, FromJson)

///|
pub fn knowledge_bundle_contract() -> String {
  "moonbook.knowledge_bundle.v1"
}

///|
pub struct KnowledgePageRecord {
  path : String
  moonbook_type : String
  title : String
  summary : String
  review_status : String
  source_quality : String
  tags : Array[String]
  outbound_links : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct KnowledgeGraphEdge {
  from : String
  to : String
  label : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct KnowledgeGraph {
  nodes : Array[KnowledgePageRecord]
  edges : Array[KnowledgeGraphEdge]
} derive(Debug, ToJson, FromJson)

///|
pub struct KnowledgeBundle {
  contract : String
  book_id : String
  root : String
  generated_at : Int
  summary : BookStateSummary
  health : BookHealthReport
  pages : Array[KnowledgePageRecord]
  graph : KnowledgeGraph
  review_queue_path : String
  event_protocol : String
} derive(Debug, ToJson, FromJson)

///|
pub fn book_state_contract() -> String {
  "moonbook.book_state.v1"
}

///|
pub struct BookStatePaths {
  knowledge_manifest : String
  generated_knowledge_bundle : String
  generated_graph : String
  latest_event : String
  review_queue : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct BookStateSnapshot {
  contract : String
  book_id : String
  root : String
  generated_at : Int
  catalog : BookCatalogRecord
  summary : BookStateSummary
  health : BookHealthReport
  knowledge : KnowledgeBundle
  latest_event : ExecutableBookEvent?
  paths : BookStatePaths
} derive(Debug, ToJson, FromJson)

///|
priv struct SourceCoverageSummary {
  total_count : Int
  candidate_count : Int
  provisional_count : Int
  verified_count : Int
}

///|
