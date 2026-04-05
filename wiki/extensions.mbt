///|
pub struct ExtensionInstallResult {
  root : String
  extension : String
  manifest_path : String
  installed_files : Array[String]
} derive(Show, ToJson)

///|
pub fn supported_extensions() -> Array[String] {
  ["moonclaw"]
}

///|
pub async fn enable_extension(
  root : String,
  extension : String,
) -> ExtensionInstallResult {
  let normalized_root = @pathx.normalize(root)
  let normalized_extension = extension.trim().to_lower()
  let supported = supported_extensions().join(", ")
  let extensions_dir = @path.Path(normalized_root)
    .join(@path.Path(".moonbook/extensions"))
    .to_string()
  @fsx.make_directory(extensions_dir, recursive=true, exists_ok=true)
  match normalized_extension {
    "moonclaw" => install_moonclaw_extension(normalized_root, extensions_dir)
    _ =>
      fail(
        "unsupported wiki extension: \{extension}. supported extensions: \{supported}",
      )
  }
}

///|
async fn install_moonclaw_extension(
  root : String,
  extensions_dir : String,
) -> ExtensionInstallResult {
  let manifest_path = @path.Path(extensions_dir)
    .join(@path.Path("moonclaw.json"))
    .to_string()
  let config_path = @path.Path(root)
    .join(@path.Path("moonclaw.json"))
    .to_string()
  let jobs_path = @path.Path(root)
    .join(@path.Path("moonclaw.jobs.json"))
    .to_string()
  let identity_path = @path.Path(root)
    .join(@path.Path("IDENTITY.md"))
    .to_string()
  let user_path = @path.Path(root).join(@path.Path("USER.md")).to_string()
  let routines_path = @path.Path(root)
    .join(@path.Path("ROUTINES.md"))
    .to_string()
  let memory_path = @path.Path(root).join(@path.Path("MEMORY.md")).to_string()
  write_extension_file_if_missing(config_path, moonclaw_config_text(root))
  write_extension_file_if_missing(jobs_path, moonclaw_jobs_text())
  write_extension_file_if_missing(identity_path, identity_text(root))
  write_extension_file_if_missing(user_path, user_text())
  write_extension_file_if_missing(routines_path, routines_text())
  write_extension_file_if_missing(memory_path, memory_text())
  write_extension_file_if_missing(manifest_path, moonclaw_manifest_text())
  {
    root,
    extension: "moonclaw",
    manifest_path,
    installed_files: [
      config_path, jobs_path, identity_path, user_path, routines_path, memory_path,
    ],
  }
}

///|
async fn write_extension_file_if_missing(
  path : String,
  content : String,
) -> Unit {
  if !@fsx.exists(path) {
    @fsx.write_to_file(path, content, create=0o644)
  }
}

///|
fn moonclaw_manifest_text() -> String {
  "{\n" +
  "  \"id\": \"moonclaw\",\n" +
  "  \"kind\": \"agent-runtime\",\n" +
  "  \"entry\": {\n" +
  "    \"config\": \"moonclaw.json\",\n" +
  "    \"jobs\": \"moonclaw.jobs.json\"\n" +
  "  }\n" +
  "}\n"
}

///|
fn moonclaw_config_text(root : String) -> String {
  "{\n" +
  "  \"agents\": {\n" +
  "    \"defaults\": {\n" +
  "      \"workspace\": \"\{escape_json_string(root)}\"\n" +
  "    }\n" +
  "  }\n" +
  "}\n"
}

///|
fn moonclaw_jobs_text() -> String {
  "{\n" +
  "  \"jobs\": {\n" +
  "    \"profiles\": {\n" +
  "      \"wiki_ingest_controller\": {\n" +
  "        \"family\": \"wiki_ingest\",\n" +
  "        \"role\": \"controller\",\n" +
  "        \"priority\": 100,\n" +
  "        \"tags\": [\"wiki\", \"ingest\", \"controller\"],\n" +
  "        \"match\": {\n" +
  "          \"any\": [\"ingest\", \"import\", \"source\", \"article\", \"paper\", \"notes\", \"wiki\"]\n" +
  "        },\n" +
  "        \"steps\": [\n" +
  "          {\n" +
  "            \"id\": \"inspect_source\",\n" +
  "            \"title\": \"Inspect raw source\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Read the raw source material relevant to ${request}. Extract candidate entities, concepts, durable claims, contradictions, and updates required for the wiki workspace.\"\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"update_wiki\",\n" +
  "            \"title\": \"Update wiki pages\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Update the wiki for ${proposal.title}. Touch source pages, related entity pages, concept pages, synthesis pages, SUMMARY.md, index.md, and log.md when warranted. Preserve uncertainty explicitly.\"\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"reconcile\",\n" +
  "            \"title\": \"Reconcile contradictions\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Review the affected wiki pages for stale wording, contradictory claims, weak cross-links, and missing follow-up pages after ${proposal.title}.\"\n" +
  "          }\n" +
  "        ]\n" +
  "      },\n" +
  "      \"wiki_query_capture\": {\n" +
  "        \"family\": \"wiki_query\",\n" +
  "        \"priority\": 90,\n" +
  "        \"tags\": [\"wiki\", \"query\"],\n" +
  "        \"match\": {\n" +
  "          \"any\": [\"query\", \"answer\", \"compare\", \"summarize\", \"synthesize\", \"question\"]\n" +
  "        },\n" +
  "        \"steps\": [\n" +
  "          {\n" +
  "            \"id\": \"search_wiki\",\n" +
  "            \"title\": \"Search wiki pages\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Read wiki/index.md first, then inspect the relevant wiki pages for ${request}. Answer from the maintained wiki with explicit page citations.\"\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"capture_durable_answer\",\n" +
  "            \"title\": \"Capture durable answer\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Decide whether the answer for ${proposal.title} should be filed back into wiki/queries/ or related synthesis pages. If so, update the wiki artifacts accordingly.\"\n" +
  "          }\n" +
  "        ]\n" +
  "      },\n" +
  "      \"wiki_lint_maintainer\": {\n" +
  "        \"family\": \"wiki_lint\",\n" +
  "        \"priority\": 95,\n" +
  "        \"tags\": [\"wiki\", \"lint\", \"maintenance\"],\n" +
  "        \"match\": {\n" +
  "          \"any\": [\"lint\", \"health\", \"orphan\", \"contradiction\", \"stale\", \"cross-link\"]\n" +
  "        },\n" +
  "        \"steps\": [\n" +
  "          {\n" +
  "            \"id\": \"scan_wiki\",\n" +
  "            \"title\": \"Scan wiki health\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Inspect the wiki for orphan pages, stale claims, contradictory statements, weak cross-references, and missing entity or concept pages related to ${request}.\"\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"record_maintenance\",\n" +
  "            \"title\": \"Record maintenance pass\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Update wiki/log.md and any directly affected maintenance pages for ${proposal.title}. Keep the result cumulative and revision-oriented.\"\n" +
  "          }\n" +
  "        ]\n" +
  "      }\n" +
  "    }\n" +
  "  }\n" +
  "}\n"
}

///|
fn identity_text(root : String) -> String {
  "# Identity\n\n" +
  "This workspace is a persistent LLM-maintained wiki.\n\n" +
  "- Renderer/build/serve layer: MoonBook\n" +
  "- Agent/job orchestration layer: MoonClaw\n" +
  "- Workspace root: `\{root}`\n"
}

///|
fn user_text() -> String {
  "# User\n\n" +
  "Record durable collaboration preferences here.\n\n" +
  "Suggested topics:\n\n" +
  "- preferred depth vs brevity\n" +
  "- ingest review habits\n" +
  "- how aggressively the agent should update synthesis pages\n"
}

///|
fn routines_text() -> String {
  "# Routines\n\n" +
  "## Ingest\n\n" +
  "1. Read the raw source from `raw/`\n" +
  "2. Update `wiki/sources/` and any relevant entity, concept, or synthesis pages\n" +
  "3. Update `wiki/index.md`, `wiki/SUMMARY.md`, and `wiki/log.md`\n\n" +
  "## Query\n\n" +
  "1. Read `wiki/index.md` first\n" +
  "2. Read the relevant wiki pages\n" +
  "3. Answer with citations to wiki page paths\n" +
  "4. Save durable analyses back into the wiki when useful\n\n" +
  "## Lint\n\n" +
  "1. Check for orphan pages\n" +
  "2. Check for stale or contradictory claims\n" +
  "3. Check for weak cross-links and missing pages\n" +
  "4. Record the pass in `wiki/log.md`\n"
}

///|
fn memory_text() -> String {
  "# Memory\n\n" +
  "Capture durable synthesis, open questions, and recurring patterns here.\n\n" +
  "Suggested entries:\n\n" +
  "- long-lived hypotheses\n" +
  "- unresolved contradictions\n" +
  "- recurring source categories worth ingesting\n"
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
test "supported extensions includes moonclaw" {
  assert_eq(supported_extensions(), ["moonclaw"])
}

///|
test "moonclaw manifest declares config and jobs entrypoints" {
  let text = moonclaw_manifest_text()
  assert_true(text.contains("\"config\": \"moonclaw.json\""))
  assert_true(text.contains("\"jobs\": \"moonclaw.jobs.json\""))
}

///|
test "moonclaw jobs seed wiki profiles" {
  let text = moonclaw_jobs_text()
  assert_true(text.contains("\"wiki_ingest_controller\""))
  assert_true(text.contains("\"wiki_query_capture\""))
  assert_true(text.contains("\"wiki_lint_maintainer\""))
}
