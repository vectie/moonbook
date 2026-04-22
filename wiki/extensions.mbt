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
  let runtime_dir = @path.Path(root).join(@path.Path(".moonclaw")).to_string()
  let providers_path = @path.Path(runtime_dir)
    .join(@path.Path("providers.json"))
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
  @fsx.make_directory(runtime_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(maintainer_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(review_dir, recursive=true, exists_ok=true)
  write_extension_file_if_missing(config_path, moonclaw_config_text(root))
  write_extension_file_if_missing(jobs_path, moonclaw_jobs_text())
  write_extension_file_if_missing(providers_path, moonclaw_providers_text(root))
  write_extension_file_if_missing(identity_path, identity_text(root))
  write_extension_file_if_missing(user_path, user_text())
  write_extension_file_if_missing(routines_path, routines_text())
  write_extension_file_if_missing(memory_path, memory_text())
  write_extension_file_if_missing(keeper_path, keeper_text())
  copy_extension_seed_tree_if_missing(
    maintainer_dir, "seed/extensions/moonclaw/skills/wiki-maintainer",
  )
  copy_extension_seed_tree_if_missing(
    review_dir, "seed/extensions/moonclaw/skills/wiki-review",
  )
  write_extension_file_if_missing(manifest_path, moonclaw_manifest_text())
  {
    root,
    extension: "moonclaw",
    manifest_path,
    installed_files: [
      config_path, jobs_path, providers_path, identity_path, user_path, routines_path,
      memory_path, keeper_path, maintainer_skill_path, review_skill_path,
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
async fn copy_extension_seed_tree_if_missing(
  destination_path : String,
  seed_relative_path : String,
) -> Unit {
  let source_path = @path.Path(detect_moonbook_module_root())
    .join(@path.Path(seed_relative_path))
    .to_string()
  if !@fsx.exists(source_path) {
    fail("missing extension seed file: \{source_path}")
  }
  copy_extension_seed_tree(source_path, destination_path)
}

///|
async fn copy_extension_seed_tree(
  source_path : String,
  destination_path : String,
) -> Unit {
  match @fs.kind(source_path, follow_symlink=false) {
    @fs.FileKind::Directory => {
      @fsx.make_directory(destination_path, recursive=true, exists_ok=true)
      for child in @fsx.list_directory(source_path) {
        let child_name = @path.Path(child).basename().to_string()
        copy_extension_seed_tree(
          child,
          @path.Path(destination_path).join(@path.Path(child_name)).to_string(),
        )
      }
    }
    _ =>
      if !@fsx.exists(destination_path) {
        @fsx.write_to_file(
          destination_path,
          @fsx.read_file(source_path),
          create=0o644,
        )
      }
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
  "            \"id\": \"plan_gather_fanout\",\n" +
  "            \"title\": \"Plan gather worker fan-out\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Act as the book keeper for ${proposal.title}. Read the imported proposal request and notes first. If the proposal declares gather lane specs or parallel-lane bootstrap intent, preserve them. Do not compress multiple gather lanes into one worker unless the source surface is obviously tiny. Produce a concrete execution note for separate docs, implementation, and architecture workers before gather begins.\",\n" +
  "            \"metadata\": {\n" +
  "              \"preferred_skills\": [\"wiki-maintainer\"],\n" +
  "              \"enable_tools\": true,\n" +
  "              \"web_search\": true,\n" +
  "              \"board_lane\": \"Plan\",\n" +
  "              \"board_order\": 0\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"gather_docs\",\n" +
  "            \"title\": \"Gather repo and product docs\",\n" +
  "            \"kind\": \"job.delegate\",\n" +
  "            \"request_template\": \"Act as the wiki gather worker for the docs lane of ${proposal.title}. Inspect only high-signal docs, specs, READMEs, guides, and product-facing markdown from the current workspace and any explicitly allowed local sources. Write packet-ready evidence into raw/bootstrap/ with provenance, evidence bullets, source-path notes, entity candidates, concept candidates, and open questions. Do not read the entire repo and do not claim final ingest success from this lane.\",\n" +
  "            \"child_profile\": \"wiki_gather_worker\",\n" +
  "            \"include_parent_outputs\": true,\n" +
  "            \"max_depth\": 3,\n" +
  "            \"metadata\": {\n" +
  "              \"web_search\": true,\n" +
  "              \"board_lane\": \"Gather\",\n" +
  "              \"board_order\": 1\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"gather_implementation\",\n" +
  "            \"title\": \"Gather implementation evidence\",\n" +
  "            \"kind\": \"job.delegate\",\n" +
  "            \"request_template\": \"Act as the wiki gather worker for the implementation lane of ${proposal.title}. Inspect only the highest-signal code, config, manifests, and runtime wiring that support durable wiki claims. Produce packet-ready evidence under raw/bootstrap/ with concrete source paths, evidence bullets, entity candidates, concept candidates, and unresolved questions. Keep the lane narrow and do not try to summarize the whole system.\",\n" +
  "            \"child_profile\": \"wiki_gather_worker\",\n" +
  "            \"include_parent_outputs\": true,\n" +
  "            \"max_depth\": 3,\n" +
  "            \"metadata\": {\n" +
  "              \"web_search\": true,\n" +
  "              \"board_lane\": \"Gather\",\n" +
  "              \"board_order\": 2\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"gather_architecture\",\n" +
  "            \"title\": \"Gather architecture and topology notes\",\n" +
  "            \"kind\": \"job.delegate\",\n" +
  "            \"request_template\": \"Act as the wiki gather worker for the architecture lane of ${proposal.title}. Inspect only the files that explain system boundaries, call chains, topology, and cross-component responsibilities. Write packet-ready architecture notes into raw/bootstrap/ with provenance, evidence bullets, relationship candidates, and explicit uncertainty markers. Do not duplicate doc or implementation lanes.\",\n" +
  "            \"child_profile\": \"wiki_gather_worker\",\n" +
  "            \"include_parent_outputs\": true,\n" +
  "            \"max_depth\": 3,\n" +
  "            \"metadata\": {\n" +
  "              \"web_search\": true,\n" +
  "              \"board_lane\": \"Gather\",\n" +
  "              \"board_order\": 3\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"prepare_materials\",\n" +
  "            \"title\": \"Prepare ingestable materials\",\n" +
  "            \"kind\": \"job.delegate\",\n" +
  "            \"request_template\": \"Act as the wiki gather worker for the material-prep lane of ${proposal.title}. Consolidate the bounded gather outputs into ingestable raw packets under raw/bootstrap/: source summaries, evidence bullets, candidate pages to update, and explicit blockers when material is still too weak. Return the raw/bootstrap paths in artifacts. If the gathered material is not enough for MoonBook ingestion, say so explicitly and explain what is missing.\",\n" +
  "            \"child_profile\": \"wiki_gather_worker\",\n" +
  "            \"include_parent_outputs\": true,\n" +
  "            \"max_depth\": 3,\n" +
  "            \"metadata\": {\n" +
  "              \"web_search\": true,\n" +
  "              \"board_lane\": \"Prepare\",\n" +
  "              \"board_order\": 4\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"inspect_source\",\n" +
  "            \"title\": \"Inspect provider-updated wiki state\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Act as the wiki maintainer keeper for ${proposal.title}. Review the gathered raw/bootstrap packets and provider-updated wiki state. Treat MoonBook as the owner of durable wiki writes, but verify whether the gathered material is actually strong enough for ingestion. Inspect `raw/bootstrap/`, `wiki/sources/`, `wiki/index.md`, `wiki/log.md`, the gather-worker outputs, and the most relevant entity, concept, synthesis, and query pages. Do not re-decide whether hidden placeholders, `.gitkeep`, or other workspace scaffolding count as substantive sources.\",\n" +
  "            \"metadata\": {\n" +
  "              \"preferred_skills\": [\"wiki-maintainer\"],\n" +
  "              \"enable_tools\": true,\n" +
  "              \"web_search\": true,\n" +
  "              \"board_lane\": \"Inspect\",\n" +
  "              \"board_order\": 5\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"plan_revisions\",\n" +
  "            \"title\": \"Plan durable wiki revisions\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Turn the gathered raw/bootstrap materials and inspected wiki state for ${proposal.title} into a concrete MoonBook materialization plan. Separate: raw artifacts completed, source ids, entity candidates, concept candidates, synthesis claims, and blockers caused by weak materials. Treat generic completion text as failure, not success. Do not require MoonClaw to write durable wiki pages; MoonBook owns promotion into wiki/sources, wiki/entities, wiki/concepts, and synthesis pages from the raw research envelope.\",\n" +
  "            \"metadata\": {\n" +
  "              \"preferred_skills\": [\"wiki-maintainer\"],\n" +
  "              \"enable_tools\": true,\n" +
  "              \"web_search\": true,\n" +
  "              \"board_lane\": \"Plan\",\n" +
  "              \"board_order\": 6\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"apply_revisions\",\n" +
  "            \"title\": \"Finalize research envelope\",\n" +
  "            \"kind\": \"job.delegate\",\n" +
  "            \"request_template\": \"Finalize the research envelope for ${proposal.title}. Read the prepared raw/bootstrap packets and make sure the required raw artifacts exist: research-question.md, search-log.md, source-screen.md, evidence-matrix.md, local-sources.md, and synthesis-brief.md. Return those raw/bootstrap paths in artifacts. Do not edit durable wiki pages directly; MoonBook will materialize wiki/sources, wiki/entities, wiki/concepts, and synthesis pages from this envelope. If any required raw artifact is missing, return an explicit structured blocker.\",\n" +
  "            \"child_profile\": \"wiki_revision_worker\",\n" +
  "            \"include_parent_outputs\": true,\n" +
  "            \"max_depth\": 3,\n" +
  "            \"metadata\": {\n" +
  "              \"web_search\": true,\n" +
  "              \"board_lane\": \"Revise\",\n" +
  "              \"board_order\": 7\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"review_revisions\",\n" +
  "            \"title\": \"Review wiki consistency\",\n" +
  "            \"kind\": \"job.delegate\",\n" +
  "            \"request_template\": \"Review the research envelope for ${proposal.title}. Check that required raw/bootstrap artifacts exist, source screening is explicit, evidence rows support the synthesis brief, false leads are pruned, and blockers name unavailable tools or inaccessible sources. Do not require MoonClaw-created durable wiki pages; MoonBook owns final wiki materialization.\",\n" +
  "            \"child_profile\": \"wiki_review_worker\",\n" +
  "            \"include_parent_outputs\": true,\n" +
  "            \"max_depth\": 3,\n" +
  "            \"metadata\": {\n" +
  "              \"board_lane\": \"Review\",\n" +
  "              \"board_order\": 8\n" +
  "            }\n" +
  "          },\n" +
  "          {\n" +
  "            \"id\": \"finalize_ingest\",\n" +
  "            \"title\": \"Finalize ingest brief\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Summarize the wiki ingest result for ${proposal.title}. Explain which raw/bootstrap packets were written, what substantive pages changed, what claims were strengthened or challenged, what remains uncertain, and which next sources or follow-up questions would most improve the wiki. If no substantive pages changed, say that explicitly and classify the run as administrative rather than knowledge-producing.\",\n" +
  "            \"metadata\": {\n" +
  "              \"preferred_skills\": [\"wiki-maintainer\"],\n" +
  "              \"enable_tools\": true,\n" +
  "              \"web_search\": true,\n" +
  "              \"board_lane\": \"Finalize\",\n" +
  "              \"board_order\": 9\n" +
  "            }\n" +
  "          }\n" +
  "        ],\n" +
  "        \"metadata\": {\n" +
  "          \"profile_metadata\": {\n" +
  "            \"disable_waiting_for_input\": true\n" +
  "          },\n" +
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
  "          \"profile_metadata\": {\n" +
  "            \"disable_waiting_for_input\": true\n" +
  "          },\n" +
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
  "          \"profile_metadata\": {\n" +
  "            \"disable_waiting_for_input\": true\n" +
  "          },\n" +
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
  "      \"wiki_gather_worker\": {\n" +
  "        \"family\": \"wiki_gather_worker\",\n" +
  "        \"priority\": 25,\n" +
  "        \"tags\": [\"wiki\", \"maintainer\", \"worker\", \"gather\"],\n" +
  "        \"steps\": [\n" +
  "          {\n" +
  "            \"id\": \"gather_materials\",\n" +
  "            \"title\": \"Gather source materials\",\n" +
  "            \"kind\": \"job.analysis\",\n" +
  "            \"prompt_template\": \"Act as the wiki gather worker for ${request}. Read the workspace, collect substantive evidence, identify concrete source paths, write ingestable source packets under raw/bootstrap/, extract entity and concept candidates, and prepare materials that MoonBook can ingest. Return structured gather output, not generic completion prose.\",\n" +
  "            \"metadata\": {\n" +
  "              \"preferred_skills\": [\"wiki-maintainer\"],\n" +
  "              \"enable_tools\": true,\n" +
  "              \"web_search\": true,\n" +
  "              \"role_runtime\": {\n" +
  "                \"planning_layer\": \"execution\",\n" +
  "                \"runtime_mode\": \"executor\",\n" +
  "                \"tool_access\": \"full\",\n" +
  "                \"memory_scope\": \"workspace\",\n" +
  "                \"allow_delegate\": false,\n" +
  "                \"allow_workspace_write\": true,\n" +
  "                \"allow_execution_tools\": true,\n" +
  "                \"output_contract\": \"wiki.gather.result.v1\"\n" +
  "              }\n" +
  "            }\n" +
  "          }\n" +
  "        ],\n" +
  "        \"metadata\": {\n" +
  "          \"worker_role\": \"wiki_gather\"\n" +
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
  "              \"web_search\": true,\n" +
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
fn moonclaw_providers_text(root : String) -> String {
  let module_root = detect_moonbook_module_root()
  ("[\n" +
  "  {\n" +
  "    \"name\": \"moonbook\",\n" +
  "    \"title\": \"MoonBook Book Harness\",\n" +
  "    \"description\": \"MoonBook provider-task bridge for domain-local workspace logic.\",\n" +
  "    \"kind\": \"task-provider\",\n" +
  "    \"capabilities\": [\"provider\", \"extension\", \"provider.task\", \"extension.task\", \"bookapi\", \"moonbook.bookapi\"],\n" +
  "    \"metadata\": {\n" +
  "      \"command\": \"moon\",\n" +
  "      \"args\": [\"run\", \"cmd/main\", \"--\"],\n" +
  "      \"cwd\": \"__MODULE_ROOT__\",\n" +
  "      \"workspace_root\": \"__WORKSPACE_ROOT__\"\n" +
  "    }\n" +
  "  }\n" +
  "]\n")
  .replace(old="__MODULE_ROOT__", new=escape_json_string(module_root))
  .to_string()
  .replace(old="__WORKSPACE_ROOT__", new=escape_json_string(root))
  .to_string()
}

///|
fn detect_moonbook_module_root() -> String {
  @env.current_dir().unwrap_or(".")
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
  "2. Produce a complete research envelope under `raw/bootstrap/`\n" +
  "3. Let MoonBook materialize durable `wiki/sources/`, entity, concept, and synthesis pages from that envelope\n" +
  "4. Update `wiki/index.md`, `wiki/SUMMARY.md`, and `wiki/log.md`\n\n" +
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
  "2. fan out research/bootstrap work into separate gather, material-prep, revision, and review tasks instead of trying to do discovery monolithically inside one step\n" +
  "3. read `RESOLVER.md` and load the relevant `skills/*/SKILL.md` before broad planning\n" +
  "4. read `wiki/index.md` and `wiki/log.md` before broad revisions\n" +
  "5. preserve `raw/` as immutable source material\n" +
  "6. prefer cumulative wiki revisions over chat-only summaries\n" +
  "7. queue uncertain or contested changes for review instead of silently promoting them\n" +
  "8. prefer stable domain ontology and synthesis pages over token-derived pages\n" +
  "9. collapse noisy low-signal pages into stronger maintained pages when necessary\n" +
  "10. do not treat generic task-completion prose as successful knowledge gathering; require concrete materials or an explicit blocker\n"
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
  assert_true(text.contains("\"wiki_gather_worker\""))
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
test "moonclaw providers text seeds moonbook provider target" {
  let text = moonclaw_providers_text("/tmp/wiki")
  assert_true(text.contains("\"name\": \"moonbook\""))
  assert_true(text.contains("\"kind\": \"task-provider\""))
  assert_true(
    text.contains(
      "\"capabilities\": [\"provider\", \"extension\", \"provider.task\", \"extension.task\", \"bookapi\", \"moonbook.bookapi\"]",
    ),
  )
  assert_true(text.contains("\"workspace_root\": \"/tmp/wiki\""))
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
