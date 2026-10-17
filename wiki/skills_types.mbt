///|
// Skill manager public data contracts and sync manifest type.

///|
pub struct SkillRecord {
  id : String
  name : String
  path : String
  scope : String
  origin : String
  source_kind : String
  extension : String?
  description : String
  references : Array[String]
  overrides : Array[String]
  shadowed_by : Array[String]
  line_count : Int32
} derive(Debug, ToJson)

///|
pub struct SkillDoctorReport {
  root : String
  total_count : Int32
  workspace_count : Int32
  seed_core_count : Int32
  seed_extension_count : Int32
  duplicate_names : Array[String]
  missing_reference_paths : Array[String]
  warnings : Array[String]
} derive(Debug, ToJson)

///|
pub struct SkillInstallResult {
  root : String
  name : String
  destination_path : String
  source_path : String?
  action : String
} derive(Debug, ToJson)

///|
pub struct SkillCompareResult {
  root : String
  name : String
  selected_path : String
  selected_scope : String
  baseline_path : String?
  baseline_scope : String?
  status : String
  summary : String
  compared_line_count : Int32
  changed_line_count : Int32
  selected_only_line_count : Int32
  baseline_only_line_count : Int32
  first_change_line : Int32?
  selected_excerpt : Array[String]
  baseline_excerpt : Array[String]
} derive(Debug, ToJson)

///|
pub struct SkillSyncResult {
  root : String
  name : String
  candidate_dir : String
  manifest_path : String
  selected_path : String
  baseline_path : String
  summary : String
} derive(Debug, ToJson)

///|
struct SkillSyncManifest {
  name : String
  selected_path : String
  baseline_path : String
  selected_scope : String
  baseline_scope : String
  summary : String
  status : String
  changed_line_count : Int32
  selected_only_line_count : Int32
  baseline_only_line_count : Int32
  first_change_line : Int32?
  generated_at : Int32
} derive(ToJson)

///|
