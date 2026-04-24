///|
// Extension manifest, provider, identity, and runtime config templates.

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
  "2. Produce a complete research envelope under `raw/bootstrap/`, including `deep-report.md` for article-quality synthesis and `marketing-brief.md` for product-facing copy\n" +
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
