///|
pub struct ExtensionInstallResult {
  root : String
  extension : String
  manifest_path : String
  installed_files : Array[String]
} derive(Debug, ToJson)

///|
pub fn supported_extensions() -> Array[String] {
  ["moonclaw", "moontown"]
}

///|
pub async fn enable_extension(
  root : String,
  extension : String,
) -> ExtensionInstallResult {
  let normalized_root = @pathx.normalize(root)
  let normalized_extension = extension.trim().to_lower()
  let supported = supported_extensions().join(", ")
  let extensions_dir = moonbook_wiki_path(normalized_root)
    .join(moonbook_wiki_path("extensions"))
    .to_string()
  @fsx.make_directory(extensions_dir, recursive=true, exists_ok=true)
  match normalized_extension {
    "moonclaw" => install_moonclaw_extension(normalized_root, extensions_dir)
    "moontown" => install_moontown_extension(normalized_root, extensions_dir)
    _ =>
      fail(
        "unsupported wiki extension: \{extension}. supported extensions: \{supported}",
      )
  }
}

///|
fn escape_json_string(text : String) -> String {
  text
  .replace(old="\\", new="\\\\")
  .to_string()
  .replace(old="\"", new="\\\"")
  .to_string()
}

///|
async fn unique_extension_test_root(base : String) -> String {
  unique_extension_test_root_with_attempt(base, 0)
}

///|
async fn unique_extension_test_root_with_attempt(
  base : String,
  attempt : Int,
) -> String {
  let suffix = if attempt == 0 { "" } else { "-" + attempt.to_string() }
  let candidate = base + suffix
  if @fsx.exists(candidate) {
    unique_extension_test_root_with_attempt(base, attempt + 1)
  } else {
    candidate
  }
}

///|
test "supported extensions includes moonclaw" {
  assert_true(supported_extensions() == ["moonclaw", "moontown"])
}

///|
test "moonclaw manifest declares config and jobs entrypoints" {
  let text = moonclaw_manifest_text()
  assert_true(
    text.contains(
      "\"config\": \"\{@moonsuite.product_display_artifact("moonclaw", "moonclaw.json")}\"",
    ),
  )
  assert_true(text.contains("\"jobs\": \"moonclaw.jobs.json\""))
}

///|
test "moonclaw jobs seed wiki profiles" {
  let text = moonclaw_jobs_text()
  assert_true(text.contains("\"wiki_ingest_controller\""))
  assert_true(text.contains("\"wiki_course_controller\""))
  assert_true(text.contains("\"wiki_planbook_controller\""))
  assert_true(text.contains("\"wiki_gather_worker\""))
  assert_true(text.contains("\"wiki_query_controller\""))
  assert_true(text.contains("\"wiki_lint_controller\""))
  assert_true(text.contains("\"wiki_course_worker\""))
  assert_true(text.contains("\"wiki_planbook_worker\""))
  assert_true(text.contains("\"wiki_revision_worker\""))
  assert_true(text.contains("\"wiki_review_worker\""))
}

///|
test "moonclaw jobs include role runtime metadata" {
  let text = moonclaw_jobs_text()
  assert_true(text.contains("\"role_runtime\""))
  assert_true(text.contains("\"planning_layer\": \"domain\""))
  assert_true(text.contains("\"runtime_mode\": \"planner_only\""))
  assert_true(text.contains("\"output_contract\": \"keeper.plan.packet.v1\""))
  assert_true(
    text.contains("\"output_contract\": \"keeper.planbook.packet.v1\""),
  )
  assert_true(text.contains("\"output_contract\": \"wiki.gather.result.v1\""))
}

///|
test "moonclaw ingest controller decomposes gather before revision" {
  let text = moonclaw_jobs_text()
  assert_true(text.contains("\"id\": \"plan_gather_fanout\""))
  assert_true(text.contains("\"id\": \"gather_docs\""))
  assert_true(text.contains("\"id\": \"gather_implementation\""))
  assert_true(text.contains("\"id\": \"gather_architecture\""))
  assert_true(text.contains("\"id\": \"prepare_materials\""))
  assert_true(text.contains("parallel-lane bootstrap intent"))
  assert_true(text.contains("\"child_profile\": \"wiki_gather_worker\""))
  assert_true(text.contains("docs lane"))
  assert_true(text.contains("implementation lane"))
  assert_true(text.contains("architecture lane"))
  assert_true(
    text.contains(
      "Do not edit durable wiki pages directly; MoonBook will materialize",
    ),
  )
}

///|
test "moonclaw ingest profiles request web search explicitly" {
  let text = moonclaw_jobs_text()
  assert_true(text.contains("\"web_search\": true"))
  assert_true(
    text.contains(
      "\"id\": \"plan_gather_fanout\",\n            \"title\": \"Plan gather worker fan-out\"",
    ),
  )
  assert_true(
    text.contains(
      "\"id\": \"gather_materials\",\n            \"title\": \"Gather source materials\"",
    ),
  )
  assert_true(
    text.contains(
      "\"id\": \"revise_wiki\",\n            \"title\": \"Revise wiki files\"",
    ),
  )
}

///|
test "moonclaw course profile avoids research report injection" {
  let text = moonclaw_jobs_text()
  assert_true(text.contains("\"wiki_course_controller\""))
  assert_true(text.contains("\"child_profile\": \"wiki_course_worker\""))
  assert_true(text.contains("\"preferred_skills\": [\"wiki-course\"]"))
  assert_true(text.contains("Do not use research-report/SKILL.md"))
  assert_true(text.contains("raw/bootstrap/course-outline.md"))
  assert_true(text.contains("wiki/synthesis/beginner-course.md"))
}

///|
test "moonclaw planbook profile avoids research and course injection" {
  let text = moonclaw_jobs_text()
  assert_true(text.contains("\"wiki_planbook_controller\""))
  assert_true(text.contains("\"child_profile\": \"wiki_planbook_worker\""))
  assert_true(text.contains("\"preferred_skills\": [\"planbook\"]"))
  assert_true(text.contains("keeper.planbook.packet.v1"))
  assert_true(text.contains("plans/<slug>/plan.md"))
  assert_true(text.contains("\"implementation plan\""))
  assert_true(text.contains("\"repair packet\""))
  assert_true(!text.contains("\"plan\", \"implementation plan\""))
  assert_true(!text.contains("\"repair\", \"acceptance criteria\""))
  assert_true(!text.contains("\"self-healing\", \"code plan\""))
  assert_true(text.contains("follow_up_gaps, and remaining_blockers"))
  assert_true(text.contains("remaining_blockers: none"))
  assert_true(
    text.contains("Do not use research-report/SKILL.md or wiki-course/SKILL.md"),
  )
}

///|
test "moonclaw providers text seeds moonbook provider target" {
  let text = moonclaw_providers_text("/tmp/wiki")
  assert_true(text.contains("\"name\": \"moonbook\""))
  assert_true(text.contains("\"kind\": \"task-provider\""))
  assert_true(
    text.contains(
      "\"capabilities\": [\"provider\", \"extension\", \"provider.task\", \"extension.task\"]",
    ),
  )
  assert_true(text.contains("\"workspace_root\": \"/tmp/wiki\""))
}

///|
test "moonclaw product state dir uses standalone moonsuite home" {
  assert_eq(
    moonclaw_product_state_dir_for_root("/tmp/wiki"),
    @moonsuite.product_home_for_workspace_root("/tmp/wiki", "moonclaw").state_path,
  )
}

///|
test "moonclaw product state dir resolves from suite books root" {
  assert_eq(
    moonclaw_product_state_dir_for_root("/tmp/suite/books/research-wiki"),
    @moonsuite.product_home_for_workspace_root(
      "/tmp/suite/books/research-wiki", "moonclaw",
    ).state_path,
  )
}

///|
test "moontown manifest declares book and guide entrypoints" {
  let text = moontown_manifest_text()
  assert_true(text.contains("\"book\": \"moontown.book.json\""))
  assert_true(text.contains("\"guide\": \"EXTENSION_API.md\""))
}

///|
test "moontown book text declares extension API commands" {
  let text = moontown_book_text("/tmp/wiki")
  assert_true(text.contains("\"kind\": \"moonbook-extension-api\""))
  assert_true(text.contains("\"catalog_export\""))
  assert_true(text.contains("\"accept_goal\""))
  assert_true(text.contains("\"persist_result\""))
}

///|
async test "extension maintainer skill is copied from repo templates" {
  let root = unique_extension_test_root("/tmp/moonbook-extension-skill-copy")
  ignore(init_workspace(root))
  ignore(enable_extension(root, "moonclaw"))
  let text = @fsx.read_file(root + "/skills/wiki-maintainer/SKILL.md")
  let reference = @fsx.read_file(
    root + "/skills/wiki-maintainer/references/moonclaw-raw-first.md",
  )
  assert_true(text.contains("write new source packets into `raw/bootstrap/`"))
  assert_true(text.contains("references/moonclaw-raw-first.md"))
  assert_true(text.contains("Bad output to avoid"))
  assert_true(reference.contains("## Worker split"))
}

///|
async test "moonclaw extension installs runtime config and provider manifest into moonsuite product home" {
  let suite_root = unique_extension_test_root("/tmp/moonbook-moonsuite-install")
  let root = suite_root + "/books/research-wiki"
  ignore(init_workspace(root))
  let install = enable_extension(root, "moonclaw")
  let config_path = @moonsuite.product_artifact_for_workspace_root(
    root, "moonclaw", "moonclaw.json",
  )
  let providers_path = @moonsuite.product_artifact_for_workspace_root(
    root, "moonclaw", "providers.json",
  )
  assert_true(@fsx.exists(config_path))
  assert_true(@fsx.exists(providers_path))
  assert_true(!@fsx.exists(root + "/moonclaw.json"))
  assert_true(!@fsx.exists(root + "/.moonclaw/providers.json"))
  assert_true(install.installed_files.contains(config_path))
  assert_true(install.installed_files.contains(providers_path))
}
