///|
pub struct ExtensionInstallResult {
  root : String
  extension : String
  manifest_path : String
  installed_files : Array[String]
} derive(Show, ToJson)

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
  let extensions_dir = @path.Path(normalized_root)
    .join(@path.Path(".moonbook/extensions"))
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
  let keeper_path = @path.Path(root).join(@path.Path("KEEPER.md")).to_string()
  let skills_dir = @path.Path(root).join(@path.Path("skills")).to_string()
  let maintainer_dir = @path.Path(skills_dir)
    .join(@path.Path("wiki-maintainer"))
    .to_string()
  let review_dir = @path.Path(skills_dir)
    .join(@path.Path("wiki-review"))
    .to_string()
  let maintainer_skill_path = @path.Path(maintainer_dir)
    .join(@path.Path("SKILL.md"))
    .to_string()
  let review_skill_path = @path.Path(review_dir)
    .join(@path.Path("SKILL.md"))
    .to_string()
  @fsx.make_directory(skills_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(maintainer_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(review_dir, recursive=true, exists_ok=true)
  write_extension_file_if_missing(config_path, moonclaw_config_text(root))
  write_extension_file_if_missing(jobs_path, moonclaw_jobs_text())
  write_extension_file_if_missing(identity_path, identity_text(root))
  write_extension_file_if_missing(user_path, user_text())
  write_extension_file_if_missing(routines_path, routines_text())
  write_extension_file_if_missing(memory_path, memory_text())
  write_extension_file_if_missing(keeper_path, keeper_text())
  write_extension_file_if_missing(
    maintainer_skill_path,
    wiki_maintainer_skill_text(),
  )
  write_extension_file_if_missing(review_skill_path, wiki_review_skill_text())
  write_extension_file_if_missing(manifest_path, moonclaw_manifest_text())
  {
    root,
    extension: "moonclaw",
    manifest_path,
    installed_files: [
      config_path, jobs_path, identity_path, user_path, routines_path, memory_path,
      keeper_path, maintainer_skill_path, review_skill_path,
    ],
  }
}

///|
async fn install_moontown_extension(
  root : String,
  extensions_dir : String,
) -> ExtensionInstallResult {
  let manifest_path = @path.Path(extensions_dir)
    .join(@path.Path("moontown.json"))
    .to_string()
  let book_api_path = @path.Path(root)
    .join(@path.Path("moontown.book.json"))
    .to_string()
  let bridge_path = @path.Path(root).join(@path.Path("BOOK_API.md")).to_string()
  write_extension_file_if_missing(book_api_path, moontown_book_text(root))
  write_extension_file_if_missing(bridge_path, book_api_text())
  write_extension_file_if_missing(manifest_path, moontown_manifest_text())
  {
    root,
    extension: "moontown",
    manifest_path,
    installed_files: [book_api_path, bridge_path],
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
fn moontown_manifest_text() -> String {
  "{\n" +
  "  \"id\": \"moontown\",\n" +
  "  \"kind\": \"town-control-plane\",\n" +
  "  \"entry\": {\n" +
  "    \"book\": \"moontown.book.json\",\n" +
  "    \"guide\": \"BOOK_API.md\"\n" +
  "  }\n" +
  "}\n"
}

///|
fn moontown_book_text(root : String) -> String {
  "{\n" +
  "  \"id\": \"\{escape_json_string(@path.Path(root).basename().to_string())}\",\n" +
  "  \"name\": \"\{escape_json_string(@path.Path(root).basename().to_string())}\",\n" +
  "  \"purpose\": \"Persistent per-domain MoonBook workspace.\",\n" +
  "  \"workspace_root\": \"\{escape_json_string(root)}\",\n" +
  "  \"kind\": \"moonbook-domain-harness\",\n" +
  "  \"catalog_export\": \"moon run cmd/main -- wiki book catalog \{escape_json_string(root)}\",\n" +
  "  \"apis\": {\n" +
  "    \"accept_goal\": \"moon run cmd/main -- wiki book accept \{escape_json_string(root)} <goal>\",\n" +
  "    \"produce_task_batch\": \"moon run cmd/main -- wiki book tasks \{escape_json_string(root)} <goal>\",\n" +
  "    \"hydrate_worker_context\": \"moon run cmd/main -- wiki book context \{escape_json_string(root)} <goal> [--task <task-id>]\",\n" +
  "    \"persist_result\": \"moon run cmd/main -- wiki book persist \{escape_json_string(root)} <result.json>\",\n" +
  "    \"summarize_state\": \"moon run cmd/main -- wiki book summary \{escape_json_string(root)}\",\n" +
  "    \"report_health\": \"moon run cmd/main -- wiki book health \{escape_json_string(root)}\"\n" +
  "  }\n" +
  "}\n"
}

///|
fn book_api_text() -> String {
  "# Book API\n\n" +
  "This workspace exposes MoonBook's domain-harness surface for town-level orchestration.\n\n" +
  "## Town-facing operations\n\n" +
  "- `accept_goal`\n" +
  "- `produce_task_batch`\n" +
  "- `hydrate_worker_context`\n" +
  "- `persist_result`\n" +
  "- `summarize_state`\n" +
  "- `report_health`\n\n" +
  "These should be treated as the town-to-book boundary. Worker execution still belongs to MoonClaw.\n"
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
  "        \"family\": \"wiki_ingest_controller\",\n" +
  "        \"role\": \"controller\",\n" +
  "        \"priority\": 130,\n" +
  "        \"tags\": [\"wiki\", \"maintainer\", \"ingest\", \"source\"],\n" +
  "        \"match\": {\n" +
  "          \"all\": [\"wiki\"],\n" +
  "          \"any\": [\"ingest\", \"source\", \"integrate\", \"raw/\"]\n" +
  "        },\n" +
  "        \"steps\": [\n" +
  "          {\n" +
  "            \"id\": \"inspect_source\",\n" +
  "            \"title\": \"Inspect raw source and current wiki state\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Act as the wiki maintainer keeper for ${proposal.title}. Inspect the raw source material, wiki/index.md, wiki/log.md, and the most relevant entity, concept, synthesis, and source pages. Identify what is new, what changed, what is contradicted, and which pages must be revised.\",\n" +
  "            \"metadata\": {\n" +
  "              \"preferred_skills\": [\"wiki-maintainer\"],\n" +
  "              \"enable_tools\": true,\n" +
  "              \"board_lane\": \"Inspect\",\n" +
  "              \"board_order\": 0\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"plan_revisions\",\n" +
  "            \"title\": \"Plan durable wiki revisions\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Turn the inspected wiki state for ${proposal.title} into a concrete revision plan. Specify which pages to create or update under wiki/entities/, wiki/concepts/, wiki/synthesis/, wiki/sources/, wiki/queries/, plus the required changes to wiki/index.md and wiki/log.md. Prefer cumulative revisions over one-off chat summaries. Favor stable domain pages and synthesis pages over token-derived or low-signal pages. Merge or delete noisy pages instead of preserving weak ontology.\",\n" +
  "            \"metadata\": {\n" +
  "              \"preferred_skills\": [\"wiki-maintainer\"],\n" +
  "              \"enable_tools\": true,\n" +
  "              \"board_lane\": \"Plan\",\n" +
  "              \"board_order\": 1\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"apply_revisions\",\n" +
  "            \"title\": \"Apply wiki revisions\",\n" +
  "            \"kind\": \"job.delegate\",\n" +
  "            \"request_template\": \"Apply the approved wiki revision plan for ${proposal.title}. Edit the wiki markdown directly, keep raw/ immutable, update cross-links, and make sure wiki/index.md and wiki/log.md reflect the changes. Prefer high-signal source summaries, stable entity/concept naming, and synthesis-first organization over token extraction.\",\n" +
  "            \"child_profile\": \"wiki_revision_worker\",\n" +
  "            \"include_parent_outputs\": true,\n" +
  "            \"max_depth\": 3,\n" +
  "            \"metadata\": {\n" +
  "              \"board_lane\": \"Revise\",\n" +
  "              \"board_order\": 2\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"review_revisions\",\n" +
  "            \"title\": \"Review wiki consistency\",\n" +
  "            \"kind\": \"job.delegate\",\n" +
  "            \"request_template\": \"Review the wiki revisions for ${proposal.title}. Check link integrity, missing backreferences, unsupported claims, stale wording, whether wiki/index.md and wiki/log.md were updated consistently, and whether the resulting ontology is clean rather than token-derived.\",\n" +
  "            \"child_profile\": \"wiki_review_worker\",\n" +
  "            \"include_parent_outputs\": true,\n" +
  "            \"max_depth\": 3,\n" +
  "            \"metadata\": {\n" +
  "              \"board_lane\": \"Review\",\n" +
  "              \"board_order\": 3\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"finalize_ingest\",\n" +
  "            \"title\": \"Finalize ingest brief\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Summarize the wiki ingest result for ${proposal.title}. Explain what pages changed, what claims were strengthened or challenged, what remains uncertain, and which next sources or follow-up questions would most improve the wiki.\",\n" +
  "            \"metadata\": {\n" +
  "              \"preferred_skills\": [\"wiki-maintainer\"],\n" +
  "              \"enable_tools\": true,\n" +
  "              \"board_lane\": \"Finalize\",\n" +
  "              \"board_order\": 4\n" +
  "            }\n" +
  "          }\n" +
  "        ],\n" +
  "        \"metadata\": {\n" +
  "          \"role_runtime\": {\n" +
  "            \"planning_layer\": \"domain\",\n" +
  "            \"runtime_mode\": \"planner_only\",\n" +
  "            \"tool_access\": \"limited\",\n" +
  "            \"memory_scope\": \"domain\",\n" +
  "            \"allow_delegate\": true,\n" +
  "            \"allow_workspace_write\": false,\n" +
  "            \"allow_execution_tools\": false,\n" +
  "            \"output_contract\": \"keeper.plan.packet.v1\"\n" +
  "          }\n" +
  "        }\n" +
  "      },\n" +
  "      \"wiki_query_controller\": {\n" +
  "        \"family\": \"wiki_query_controller\",\n" +
  "        \"role\": \"controller\",\n" +
  "        \"priority\": 120,\n" +
  "        \"tags\": [\"wiki\", \"maintainer\", \"query\"],\n" +
  "        \"match\": {\n" +
  "          \"all\": [\"wiki\"],\n" +
  "          \"any\": [\"query\", \"answer\", \"summarize\", \"compare\", \"brief\"]\n" +
  "        },\n" +
  "        \"steps\": [\n" +
  "          {\n" +
  "            \"id\": \"locate_pages\",\n" +
  "            \"title\": \"Locate relevant wiki pages\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Act as the wiki maintainer keeper for ${proposal.title}. Read wiki/index.md first, then locate the pages most relevant to the question. Prefer maintained wiki pages over raw sources except when the wiki clearly needs a gap check.\",\n" +
  "            \"metadata\": {\n" +
  "              \"preferred_skills\": [\"wiki-maintainer\"],\n" +
  "              \"enable_tools\": true,\n" +
  "              \"board_lane\": \"Locate\",\n" +
  "              \"board_order\": 0\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"synthesize_answer\",\n" +
  "            \"title\": \"Synthesize cited answer\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Answer ${request} from the maintained wiki with citations to page paths. Highlight uncertainty, conflicting pages, and missing evidence instead of flattening disagreements.\",\n" +
  "            \"metadata\": {\n" +
  "              \"preferred_skills\": [\"wiki-maintainer\"],\n" +
  "              \"enable_tools\": true,\n" +
  "              \"board_lane\": \"Answer\",\n" +
  "              \"board_order\": 1\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"file_query_note\",\n" +
  "            \"title\": \"File durable query note\",\n" +
  "            \"kind\": \"job.delegate\",\n" +
  "            \"request_template\": \"If the synthesized answer for ${proposal.title} creates durable value, write or update a query note under wiki/queries/, then update wiki/index.md and wiki/log.md. If no durable note is justified, explain why and leave the wiki untouched.\",\n" +
  "            \"child_profile\": \"wiki_revision_worker\",\n" +
  "            \"include_parent_outputs\": true,\n" +
  "            \"max_depth\": 3,\n" +
  "            \"metadata\": {\n" +
  "              \"board_lane\": \"File\",\n" +
  "              \"board_order\": 2\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"finalize_query\",\n" +
  "            \"title\": \"Finalize query brief\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Summarize the final answer for ${proposal.title}, the pages it relied on, and whether the wiki was updated with a durable query note.\",\n" +
  "            \"metadata\": {\n" +
  "              \"preferred_skills\": [\"wiki-maintainer\"],\n" +
  "              \"enable_tools\": false,\n" +
  "              \"board_lane\": \"Finalize\",\n" +
  "              \"board_order\": 3\n" +
  "            }\n" +
  "          }\n" +
  "        ],\n" +
  "        \"metadata\": {\n" +
  "          \"role_runtime\": {\n" +
  "            \"planning_layer\": \"domain\",\n" +
  "            \"runtime_mode\": \"planner_only\",\n" +
  "            \"tool_access\": \"limited\",\n" +
  "            \"memory_scope\": \"domain\",\n" +
  "            \"allow_delegate\": true,\n" +
  "            \"allow_workspace_write\": false,\n" +
  "            \"allow_execution_tools\": false,\n" +
  "            \"output_contract\": \"keeper.answer.packet.v1\"\n" +
  "          }\n" +
  "        }\n" +
  "      },\n" +
  "      \"wiki_lint_controller\": {\n" +
  "        \"family\": \"wiki_lint_controller\",\n" +
  "        \"role\": \"controller\",\n" +
  "        \"priority\": 120,\n" +
  "        \"tags\": [\"wiki\", \"maintainer\", \"lint\", \"health\"],\n" +
  "        \"match\": {\n" +
  "          \"all\": [\"wiki\"],\n" +
  "          \"any\": [\"lint\", \"audit\", \"health\", \"orphan\", \"stale\", \"contradiction\"]\n" +
  "        },\n" +
  "        \"steps\": [\n" +
  "          {\n" +
  "            \"id\": \"audit_structure\",\n" +
  "            \"title\": \"Audit wiki health\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Audit the wiki for ${proposal.title}. Look for orphan pages, missing index/log updates, stale claims, unsupported assertions, contradictory pages, weak cross-linking, and important concepts that lack pages.\",\n" +
  "            \"metadata\": {\n" +
  "              \"preferred_skills\": [\"wiki-maintainer\"],\n" +
  "              \"enable_tools\": true,\n" +
  "              \"board_lane\": \"Audit\",\n" +
  "              \"board_order\": 0\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"propose_repairs\",\n" +
  "            \"title\": \"Propose repair plan\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Turn the audit findings for ${proposal.title} into a repair plan ordered by impact. Be explicit about which wiki pages, index entries, and log entries should change.\",\n" +
  "            \"metadata\": {\n" +
  "              \"preferred_skills\": [\"wiki-maintainer\"],\n" +
  "              \"enable_tools\": true,\n" +
  "              \"board_lane\": \"Plan\",\n" +
  "              \"board_order\": 1\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"apply_repairs\",\n" +
  "            \"title\": \"Apply repair edits\",\n" +
  "            \"kind\": \"job.delegate\",\n" +
  "            \"request_template\": \"Apply the approved wiki health repairs for ${proposal.title}. Edit only the wiki layer, preserve raw/ sources, and keep wiki/index.md plus wiki/log.md consistent with the repairs.\",\n" +
  "            \"child_profile\": \"wiki_revision_worker\",\n" +
  "            \"include_parent_outputs\": true,\n" +
  "            \"max_depth\": 3,\n" +
  "            \"metadata\": {\n" +
  "              \"board_lane\": \"Repair\",\n" +
  "              \"board_order\": 2\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"finalize_lint\",\n" +
  "            \"title\": \"Finalize lint report\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Produce the final wiki health report for ${proposal.title}. Separate fixed issues from remaining risks, note where the wiki still lacks evidence, and suggest the next highest-value sources or investigations.\",\n" +
  "            \"metadata\": {\n" +
  "              \"preferred_skills\": [\"wiki-maintainer\"],\n" +
  "              \"enable_tools\": false,\n" +
  "              \"board_lane\": \"Finalize\",\n" +
  "              \"board_order\": 3\n" +
  "            }\n" +
  "          }\n" +
  "        ],\n" +
  "        \"metadata\": {\n" +
  "          \"role_runtime\": {\n" +
  "            \"planning_layer\": \"domain\",\n" +
  "            \"runtime_mode\": \"planner_only\",\n" +
  "            \"tool_access\": \"limited\",\n" +
  "            \"memory_scope\": \"domain\",\n" +
  "            \"allow_delegate\": true,\n" +
  "            \"allow_workspace_write\": false,\n" +
  "            \"allow_execution_tools\": false,\n" +
  "            \"output_contract\": \"keeper.lint.packet.v1\"\n" +
  "          }\n" +
  "        }\n" +
  "      },\n" +
  "      \"wiki_revision_worker\": {\n" +
  "        \"family\": \"wiki_revision_worker\",\n" +
  "        \"priority\": 20,\n" +
  "        \"tags\": [\"wiki\", \"maintainer\", \"worker\", \"revision\"],\n" +
  "        \"steps\": [\n" +
  "          {\n" +
  "            \"id\": \"revise_wiki\",\n" +
  "            \"title\": \"Revise wiki files\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Act as the wiki revision worker for ${request}. Edit the maintained wiki markdown directly, preserve raw/ as immutable source-of-truth input, strengthen cross-references, update wiki/index.md and wiki/log.md when the wiki changes, and leave a concise change summary with any unresolved uncertainties.\",\n" +
  "            \"metadata\": {\n" +
  "              \"preferred_skills\": [\"wiki-maintainer\"],\n" +
  "              \"enable_tools\": true,\n" +
  "              \"role_runtime\": {\n" +
  "                \"planning_layer\": \"execution\",\n" +
  "                \"runtime_mode\": \"executor\",\n" +
  "                \"tool_access\": \"full\",\n" +
  "                \"memory_scope\": \"workspace\",\n" +
  "                \"allow_delegate\": false,\n" +
  "                \"allow_workspace_write\": true,\n" +
  "                \"allow_execution_tools\": true,\n" +
  "                \"output_contract\": \"wiki.revision.result.v1\"\n" +
  "              }\n" +
  "            }\n" +
  "          }\n" +
  "        ],\n" +
  "        \"metadata\": {\n" +
  "          \"worker_role\": \"wiki_revision\"\n" +
  "        }\n" +
  "      },\n" +
  "      \"wiki_review_worker\": {\n" +
  "        \"family\": \"wiki_review_worker\",\n" +
  "        \"priority\": 20,\n" +
  "        \"tags\": [\"wiki\", \"maintainer\", \"worker\", \"review\"],\n" +
  "        \"steps\": [\n" +
  "          {\n" +
  "            \"id\": \"review_wiki\",\n" +
  "            \"title\": \"Review wiki changes\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Act as the wiki review worker for ${request}. Review the changed wiki pages for consistency, unsupported synthesis, broken links, missing index/log maintenance, stale wording, and obvious contradictions. Findings first; if clean, state residual risk.\",\n" +
  "            \"metadata\": {\n" +
  "              \"preferred_skills\": [\"wiki-review\"],\n" +
  "              \"enable_tools\": true,\n" +
  "              \"role_runtime\": {\n" +
  "                \"planning_layer\": \"execution\",\n" +
  "                \"runtime_mode\": \"executor\",\n" +
  "                \"tool_access\": \"full\",\n" +
  "                \"memory_scope\": \"workspace\",\n" +
  "                \"allow_delegate\": false,\n" +
  "                \"allow_workspace_write\": false,\n" +
  "                \"allow_execution_tools\": true,\n" +
  "                \"output_contract\": \"wiki.review.result.v1\"\n" +
  "              }\n" +
  "            }\n" +
  "          }\n" +
  "        ],\n" +
  "        \"metadata\": {\n" +
  "          \"worker_role\": \"wiki_review\"\n" +
  "        }\n" +
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
fn keeper_text() -> String {
  "# Keeper\n\n" +
  "This file defines MoonBook's host-owned keeper policy for the embedded MoonClaw planner.\n\n" +
  "MoonBook is the thin harness. The keeper should load skill files and workspace memory, then make latent-space judgments there instead of pushing more policy into code.\n\n" +
  "## Role\n\n" +
  "- role id: `moonbook-keeper`\n" +
  "- planning layer: domain\n" +
  "- runtime mode: planner-only\n" +
  "- writable authority: none by default\n" +
  "- primary job: produce revision plans, context slices, and persistence decisions for this book\n\n" +
  "## Responsibilities\n\n" +
  "1. decompose town or user goals into book-local tasks\n" +
  "2. read `RESOLVER.md` and load the relevant `skills/*/SKILL.md` before broad planning\n" +
  "3. read `wiki/index.md` and `wiki/log.md` before broad revisions\n" +
  "4. preserve `raw/` as immutable source material\n" +
  "5. prefer cumulative wiki revisions over chat-only summaries\n" +
  "6. queue uncertain or contested changes for review instead of silently promoting them\n" +
  "7. prefer stable domain ontology and synthesis pages over token-derived pages\n" +
  "8. collapse noisy low-signal pages into stronger maintained pages when necessary\n"
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
fn wiki_maintainer_skill_text() -> String {
  "---\n" +
  "name: wiki-maintainer\n" +
  "description: Keeper/revision skill for maintaining a MoonBook wiki workspace.\n" +
  "---\n\n" +
  "# Wiki Maintainer\n\n" +
  "Operate on the maintained wiki layer, not on raw chat history. Treat this as a reusable method, not a one-off prompt.\n\n" +
  "## Rules\n\n" +
  "1. Read `RESOLVER.md`, then `wiki/index.md`.\n" +
  "2. Treat `raw/` as immutable source-of-truth input.\n" +
  "3. Prefer revising existing entity, concept, source, synthesis, and query pages over creating isolated notes.\n" +
  "4. Update `wiki/index.md` and `wiki/log.md` whenever the maintained wiki changes.\n" +
  "5. Preserve uncertainty explicitly; do not flatten contradictions.\n" +
  "6. Prefer stable domain pages over token-derived or low-signal pages.\n" +
  "7. Source pages should read like durable summaries, not raw excerpt dumps.\n"
}

///|
fn wiki_review_skill_text() -> String {
  "---\n" +
  "name: wiki-review\n" +
  "description: Review skill for consistency, support, and maintenance quality in a MoonBook wiki workspace.\n" +
  "---\n\n" +
  "# Wiki Review\n\n" +
  "Review changes to the maintained wiki with findings-first discipline.\n\n" +
  "## Checklist\n\n" +
  "1. broken or missing links\n" +
  "2. unsupported claims or overreach\n" +
  "3. stale wording without clear dates\n" +
  "4. missing backreferences or cross-links\n" +
  "5. missing `wiki/index.md` / `wiki/log.md` maintenance\n" +
  "6. weak ontology: token-derived, duplicate, or low-signal pages that should be merged or renamed\n"
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
  assert_eq(supported_extensions(), ["moonclaw", "moontown"])
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
  assert_true(text.contains("\"wiki_query_controller\""))
  assert_true(text.contains("\"wiki_lint_controller\""))
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
}

///|
test "moontown manifest declares book and guide entrypoints" {
  let text = moontown_manifest_text()
  assert_true(text.contains("\"book\": \"moontown.book.json\""))
  assert_true(text.contains("\"guide\": \"BOOK_API.md\""))
}

///|
test "moontown book text declares book harness apis" {
  let text = moontown_book_text("/tmp/wiki")
  assert_true(text.contains("\"kind\": \"moonbook-domain-harness\""))
  assert_true(text.contains("\"catalog_export\""))
  assert_true(text.contains("\"accept_goal\""))
  assert_true(text.contains("\"persist_result\""))
}
