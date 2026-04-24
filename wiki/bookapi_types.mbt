///|
// Public Book API data contracts and package-local coverage summaries.

///|
pub struct BookTask {
  id : String
  title : String
  kind : String
  prompt : String
  priority : Int
  requires_review : Bool
  target_pages : Array[String]
} derive(Show, Eq, ToJson, FromJson)

///|
pub struct BookTaskBatch {
  goal_id : String
  goal : String
  summary : String
  tasks : Array[BookTask]
} derive(Show, ToJson, FromJson)

///|
pub struct BookGoalAcceptance {
  goal_id : String
  accepted : Bool
  reason : String
  task_count : Int
  summary : String
} derive(Show, ToJson, FromJson)

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
} derive(Show, ToJson, FromJson)

///|
pub struct MemoryCandidate {
  kind : String
  title : String
  detail : String
  durable : Bool
  target_page : String?
} derive(Show, Eq, ToJson, FromJson)

///|
pub struct BookResult {
  task_id : String
  summary : String
  artifacts : Array[String]
  memory_candidates : Array[MemoryCandidate]
  requires_review : Bool
  notify_town : Bool
} derive(Show, ToJson, FromJson)

///|
pub struct PersistResultOutcome {
  log_path : String
  updated_pages : Array[String]
  review_queued : Bool
  notify_town : Bool
  evidence_id : String
} derive(Show, ToJson, FromJson)

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
  substantive_coverage_ready : Bool
  summary : String
} derive(Show, ToJson, FromJson)

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
} derive(Show, ToJson, FromJson)

///|
pub struct BookCatalogRecord {
  id : String
  name : String
  purpose : String
  workspace_root : String
  memory_scope : String
  tags : Array[String]
  skills : Array[String]
} derive(Show, ToJson, FromJson)

///|
priv struct SourceCoverageSummary {
  total_count : Int
  candidate_count : Int
  provisional_count : Int
  verified_count : Int
}

///|
