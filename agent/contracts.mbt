///|
/// One content-addressed, workspace-relative file inside a portable agent.
pub struct AgentBundleFile {
  path : String
  role : String
  encoding : String
  digest : String
  size_bytes : Int
  review_status : String
  sensitivity : String
  content : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Portable locator for evidence inside a source. Empty fields are omitted by
/// consumers according to `kind`; paths remain workspace relative.
pub struct AgentSourceLocation {
  workspace_path : String
  kind : String
  page : Int?
  slide : Int?
  sheet : String?
  cell_range : String?
  section : String?
  anchor : String?
  label : String
  content_digest : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Typed reference to a generated artifact. Executable bytes stay in MoonFort;
/// accepted portable artifacts may later be promoted into the book.
pub struct AgentArtifactLocation {
  sandbox_id : String?
  workspace_path : String
  mime_type : String
  preview_path : String?
  location : AgentSourceLocation?
  content_digest : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Governed memory that may participate in an exported agent definition.
pub struct AgentMemoryRecord {
  semantic_id : String
  kind : String
  title : String
  detail : String
  scope : String
  lifecycle : String
  sensitivity : String
  provenance : Array[AgentSourceLocation]
  evidence_refs : Array[String]
  confidence : Double
  review_required : Bool
  expires_at : Int?
  invalidation_conditions : Array[String]
  supersedes : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Named limits and counters replace anonymous memory truncation constants.
pub struct AgentMemoryPolicy {
  contract : String
  active_entry_limit : Int
  preference_entry_limit : Int
  working_entry_limit : Int
  active_character_limit : Int
  preference_character_limit : Int
  working_character_limit : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Portable counters for observing memory admission without exporting private
/// runtime transcripts.
pub struct AgentMemoryMetrics {
  admitted : Int
  rejected : Int
  deduplicated : Int
  expired : Int
  promoted : Int
  exported : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
/// One exact runtime or extension dependency captured in the portable bundle.
/// The lock digest covers the declaration so compatibility cannot be edited
/// without invalidating the enclosing bundle digest.
pub struct AgentDependencyLock {
  component : String
  contract : String
  version_range : String
  required : Bool
  capabilities : Array[String]
  migration : String
  lock_digest : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// One file intentionally omitted from an export.
pub struct AgentBundleExclusion {
  path : String
  reason : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Runtime requirements are declarations, never bundled runtime state.
pub struct AgentCompatibility {
  moonclaw_contract : String
  moonfort_contract : String
  moontown_contract : String
  moongate_contract : String
  required_capabilities : Array[String]
  dependency_locks : Array[AgentDependencyLock]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Explicit privacy and lifecycle policy applied by `agent pack`.
pub struct AgentExportPolicy {
  accepted_knowledge_only : Bool
  include_working_memory : Bool
  include_runtime_state : Bool
  include_credentials : Bool
  relative_paths_only : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A portable, inspectable, versioned agent definition. MoonClaw animates this
/// value; no queue, process, credential, or sandbox state is embedded.
pub struct AgentBundle {
  contract : String
  agent_id : String
  version : String
  book_revision : String
  created_at : Int64
  knowledge_contract : String
  compatibility : AgentCompatibility
  export_policy : AgentExportPolicy
  memory_policy : AgentMemoryPolicy
  memory_metrics : AgentMemoryMetrics
  files : Array[AgentBundleFile]
  exclusions : Array[AgentBundleExclusion]
  bundle_digest : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct AgentBundleFileSummary {
  path : String
  role : String
  digest : String
  size_bytes : Int
  review_status : String
  sensitivity : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct AgentBundleInspection {
  contract : String
  agent_id : String
  version : String
  book_revision : String
  bundle_digest : String
  file_count : Int
  total_bytes : Int
  files : Array[AgentBundleFileSummary]
  exclusions : Array[AgentBundleExclusion]
  compatibility : AgentCompatibility
  export_policy : AgentExportPolicy
  memory_policy : AgentMemoryPolicy
  memory_metrics : AgentMemoryMetrics
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct AgentBundleVerification {
  ok : Bool
  agent_id : String
  version : String
  bundle_digest : String
  checked_file_count : Int
  issues : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct AgentBundleDiff {
  left_agent_id : String
  right_agent_id : String
  left_version : String
  right_version : String
  added : Array[String]
  removed : Array[String]
  changed : Array[String]
  unchanged : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct AgentMergePlan {
  contract : String
  agent_id : String
  version : String
  bundle_digest : String
  target_root : String
  add : Array[String]
  replace : Array[String]
  unchanged : Array[String]
  protected_conflicts : Array[String]
  applies_changes : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct AgentPriorFile {
  path : String
  existed : Bool
  encoding : String
  digest : String
  content : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct AgentInstallationReceipt {
  contract : String
  receipt_id : String
  action : String
  agent_id : String
  version : String
  bundle_digest : String
  target_root : String
  created_at : Int64
  applied_files : Array[String]
  previous_files : Array[AgentPriorFile]
  previous_installation : String
  rollback_available : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct AgentInstallationState {
  contract : String
  agent_id : String
  version : String
  bundle_digest : String
  installed_at : Int64
  receipt_path : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct AgentRollbackResult {
  contract : String
  receipt_id : String
  target_root : String
  restored : Array[String]
  removed : Array[String]
  installation_restored : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn agent_bundle_contract() -> String {
  "moonbook.agent_bundle.v1"
}

///|
pub fn agent_source_location_contract() -> String {
  "moonbook.source_location.v1"
}

///|
pub fn agent_memory_policy_contract() -> String {
  "moonbook.memory_policy.v1"
}

///|
pub fn agent_merge_plan_contract() -> String {
  "moonbook.agent_merge_plan.v1"
}

///|
pub fn agent_installation_receipt_contract() -> String {
  "moonbook.agent_installation_receipt.v1"
}

///|
pub fn agent_installation_state_contract() -> String {
  "moonbook.agent_installation.v1"
}

///|
pub fn agent_rollback_result_contract() -> String {
  "moonbook.agent_rollback_result.v1"
}
