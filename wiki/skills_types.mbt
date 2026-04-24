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
  line_count : Int
} derive(Show, ToJson)

///|
pub struct SkillDoctorReport {
  root : String
  total_count : Int
  workspace_count : Int
  seed_core_count : Int
  seed_extension_count : Int
  duplicate_names : Array[String]
  missing_reference_paths : Array[String]
  warnings : Array[String]
} derive(Show, ToJson)

///|
pub struct SkillInstallResult {
  root : String
  name : String
  destination_path : String
  source_path : String?
  action : String
} derive(Show, ToJson)

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
  compared_line_count : Int
  changed_line_count : Int
  selected_only_line_count : Int
  baseline_only_line_count : Int
  first_change_line : Int?
  selected_excerpt : Array[String]
  baseline_excerpt : Array[String]
} derive(Show, ToJson)

///|
pub struct SkillSyncResult {
  root : String
  name : String
  candidate_dir : String
  manifest_path : String
  selected_path : String
  baseline_path : String
  summary : String
} derive(Show, ToJson)

///|
struct SkillSyncManifest {
  name : String
  selected_path : String
  baseline_path : String
  selected_scope : String
  baseline_scope : String
  summary : String
  status : String
  changed_line_count : Int
  selected_only_line_count : Int
  baseline_only_line_count : Int
  first_change_line : Int?
  generated_at : Int
} derive(ToJson)

///|
