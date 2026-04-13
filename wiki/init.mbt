///|
pub struct WikiWorkspace {
  root : String
  raw_dir : String
  wiki_dir : String
  schema_path : String
  config_path : String
  summary_path : String
  build_dir : String
} derive(Show, ToJson)

///|
pub async fn init_workspace(
  root : String,
  title? : String? = None,
) -> WikiWorkspace {
  let normalized_root = @pathx.normalize(root)
  let raw_dir = @path.Path(normalized_root).join(@path.Path("raw")).to_string()
  let raw_assets_dir = @path.Path(raw_dir)
    .join(@path.Path("assets"))
    .to_string()
  let wiki_dir = @path.Path(normalized_root)
    .join(@path.Path("wiki"))
    .to_string()
  let schema_path = @path.Path(normalized_root)
    .join(@path.Path("AGENTS.md"))
    .to_string()
  let config_path = @path.Path(normalized_root)
    .join(@path.Path("wiki.toml"))
    .to_string()
  let book_toml_path = @path.Path(normalized_root)
    .join(@path.Path("book.toml"))
    .to_string()
  let gitignore_path = @path.Path(normalized_root)
    .join(@path.Path(".gitignore"))
    .to_string()
  let summary_path = @path.Path(wiki_dir)
    .join(@path.Path("SUMMARY.md"))
    .to_string()
  let home_path = @path.Path(wiki_dir).join(@path.Path("Home.md")).to_string()
  let index_path = @path.Path(wiki_dir).join(@path.Path("index.md")).to_string()
  let log_path = @path.Path(wiki_dir).join(@path.Path("log.md")).to_string()
  let raw_readme_path = @path.Path(raw_dir)
    .join(@path.Path("README.md"))
    .to_string()
  let entities_dir = @path.Path(wiki_dir)
    .join(@path.Path("entities"))
    .to_string()
  let concepts_dir = @path.Path(wiki_dir)
    .join(@path.Path("concepts"))
    .to_string()
  let synthesis_dir = @path.Path(wiki_dir)
    .join(@path.Path("synthesis"))
    .to_string()
  let queries_dir = @path.Path(wiki_dir).join(@path.Path("queries")).to_string()
  let reviews_dir = @path.Path(wiki_dir).join(@path.Path("reviews")).to_string()
  let sources_dir = @path.Path(wiki_dir).join(@path.Path("sources")).to_string()
  let claims_path = @path.Path(synthesis_dir)
    .join(@path.Path("claims.md"))
    .to_string()
  let maintenance_plan_path = @path.Path(synthesis_dir)
    .join(@path.Path("maintenance-plan.md"))
    .to_string()
  let query_insights_path = @path.Path(synthesis_dir)
    .join(@path.Path("query-insights.md"))
    .to_string()
  let synthesis_map_path = @path.Path(synthesis_dir)
    .join(@path.Path("map.md"))
    .to_string()
  let observations_path = @path.Path(synthesis_dir)
    .join(@path.Path("observations.md"))
    .to_string()
  let evidence_path = @path.Path(synthesis_dir)
    .join(@path.Path("evidence.md"))
    .to_string()
  let pending_review_path = @path.Path(reviews_dir)
    .join(@path.Path("pending.md"))
    .to_string()
  let approved_review_path = @path.Path(reviews_dir)
    .join(@path.Path("approved.md"))
    .to_string()
  let keeper_dir = @path.Path(normalized_root)
    .join(@path.Path("keeper"))
    .to_string()
  let keeper_memory_path = @path.Path(keeper_dir)
    .join(@path.Path("MEMORY.md"))
    .to_string()
  let keeper_user_path = @path.Path(keeper_dir)
    .join(@path.Path("USER.md"))
    .to_string()
  let keeper_working_path = @path.Path(keeper_dir)
    .join(@path.Path("WORKING.md"))
    .to_string()
  let keeper_policy_path = @path.Path(keeper_dir)
    .join(@path.Path("POLICY.md"))
    .to_string()
  let keeper_insights_path = @path.Path(keeper_dir)
    .join(@path.Path("INSIGHTS.md"))
    .to_string()
  let assets_keep_path = @path.Path(raw_assets_dir)
    .join(@path.Path(".gitkeep"))
    .to_string()
  let resolved_title = title.unwrap_or("LLM Wiki")

  @fsx.make_directory(normalized_root, recursive=true, exists_ok=true)
  @fsx.make_directory(raw_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(raw_assets_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(wiki_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(entities_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(concepts_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(synthesis_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(queries_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(reviews_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(sources_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(keeper_dir, recursive=true, exists_ok=true)

  write_if_missing(book_toml_path, book_toml_text(resolved_title))
  write_if_missing(config_path, wiki_config_text())
  write_if_missing(schema_path, schema_text())
  write_if_missing(gitignore_path, gitignore_text())
  write_if_missing(summary_path, summary_text())
  write_if_missing(home_path, home_text())
  write_if_missing(index_path, index_text())
  write_if_missing(log_path, log_text())
  write_if_missing(claims_path, claims_text())
  write_if_missing(maintenance_plan_path, maintenance_plan_text())
  write_if_missing(query_insights_path, query_insights_text())
  write_if_missing(synthesis_map_path, synthesis_map_text())
  write_if_missing(observations_path, observations_text())
  write_if_missing(evidence_path, evidence_text())
  write_if_missing(pending_review_path, pending_review_text())
  write_if_missing(approved_review_path, approved_review_text())
  write_if_missing(keeper_memory_path, keeper_memory_text())
  write_if_missing(keeper_user_path, keeper_user_text())
  write_if_missing(keeper_working_path, keeper_working_text())
  write_if_missing(keeper_policy_path, keeper_policy_text())
  write_if_missing(keeper_insights_path, keeper_insights_text())
  write_if_missing(raw_readme_path, raw_readme_text())
  write_if_missing(assets_keep_path, "")

  {
    root: normalized_root,
    raw_dir,
    wiki_dir,
    schema_path,
    config_path,
    summary_path,
    build_dir: @path.Path(normalized_root).join(@path.Path("book")).to_string(),
  }
}

///|
async fn write_if_missing(path : String, content : String) -> Unit {
  if !@fsx.exists(path) {
    @fsx.write_to_file(path, content, create=0o644)
  }
}

///|
fn book_toml_text(title : String) -> String {
  "[book]\n" +
  "title = \"\{escape_toml_string(title)}\"\n" +
  "src = \"wiki\"\n" +
  "\n" +
  "[build]\n" +
  "build-dir = \"book\"\n"
}

///|
fn wiki_config_text() -> String {
  "raw_dir = \"raw\"\n" +
  "wiki_dir = \"wiki\"\n" +
  "schema = \"AGENTS.md\"\n" +
  "index = \"wiki/index.md\"\n" +
  "log = \"wiki/log.md\"\n"
}

///|
fn gitignore_text() -> String {
  "book\n"
}

///|
fn summary_text() -> String {
  "# Summary\n\n" +
  "- [Home](./Home.md)\n" +
  "- [Index](./index.md)\n" +
  "- [Log](./log.md)\n" +
  "- [Claims Register](./synthesis/claims.md)\n" +
  "- [Maintenance Plan](./synthesis/maintenance-plan.md)\n" +
  "- [Query Insights](./synthesis/query-insights.md)\n" +
  "- [Synthesis Map](./synthesis/map.md)\n" +
  "- [Observations](./synthesis/observations.md)\n" +
  "- [Evidence](./synthesis/evidence.md)\n" +
  "- [Pending Review](./reviews/pending.md)\n" +
  "- [Approved Review](./reviews/approved.md)\n"
}

///|
fn home_text() -> String {
  "# Home\n\n" +
  "This workspace is an LLM-maintained wiki.\n\n" +
  "## Structure\n\n" +
  "- [Index](./index.md): content catalog of the wiki\n" +
  "- [Log](./log.md): append-only timeline of ingests, queries, and lint passes\n" +
  "- [Claims Register](./synthesis/claims.md): structured claims extracted from sources\n" +
  "- [Maintenance Plan](./synthesis/maintenance-plan.md): queued multi-page wiki revisions\n" +
  "- [Synthesis Map](./synthesis/map.md): coverage and hub view across the wiki\n" +
  "- [Observations](./synthesis/observations.md): persisted worker results and promoted observations\n" +
  "- [Pending Review](./reviews/pending.md): human review queue for contested or high-value updates\n" +
  "- `../keeper/`: bounded active memory, user memory, and working memory for Keeper\n" +
  "- `../raw/`: immutable source documents\n\n" +
  "## Usage\n\n" +
  "1. Drop a source into `raw/`\n" +
  "2. Ask the LLM to ingest it into the wiki\n" +
  "3. Serve or build the wiki with MoonBook\n"
}

///|
fn index_text() -> String {
  "# Index\n\n" +
  "## Core Pages\n\n" +
  "- [Home](./Home.md): wiki landing page\n" +
  "- [Index](./index.md): content catalog\n" +
  "- [Log](./log.md): activity timeline\n" +
  "- [Claims Register](./synthesis/claims.md): structured claims with confidence and support markers\n" +
  "- [Maintenance Plan](./synthesis/maintenance-plan.md): queued multi-page wiki revisions\n" +
  "- [Query Insights](./synthesis/query-insights.md): durable insights from saved queries\n" +
  "- [Synthesis Map](./synthesis/map.md): coverage and maintenance view across the maintained wiki\n" +
  "- [Observations](./synthesis/observations.md): persisted task results and promoted book observations\n" +
  "- [Evidence](./synthesis/evidence.md): support records for persisted results and reviewed knowledge\n" +
  "- [Pending Review](./reviews/pending.md): pending human review items\n" +
  "- [Approved Review](./reviews/approved.md): accepted review decisions\n\n" +
  "## Entities\n\n" +
  "_None yet._\n\n" +
  "## Concepts\n\n" +
  "_None yet._\n\n" +
  "## Queries\n\n" +
  "_None yet._\n\n" +
  "## Sources\n\n" +
  "_None yet._\n"
}

///|
fn log_text() -> String {
  "# Log\n\n" +
  "## [0000-00-00] init | Workspace created\n\n" +
  "- initialized `raw/`, `wiki/`, `index.md`, `log.md`, and `AGENTS.md`\n"
}

///|
fn raw_readme_text() -> String {
  "# Raw Sources\n\n" +
  "Put immutable source material here.\n\n" +
  "Examples:\n\n" +
  "- clipped web articles\n" +
  "- papers\n" +
  "- notes exported from meetings\n" +
  "- images and attachments under `assets/`\n"
}

///|
fn claims_text() -> String {
  "# Claims Register\n\n" +
  "This page stores lightweight structured claims extracted from sources.\n\n" +
  "## Claims\n\n" +
  "_None yet._\n"
}

///|
fn query_insights_text() -> String {
  "# Query Insights\n\n" +
  "This page accumulates durable insights captured from saved queries.\n\n" +
  "## Insights\n\n" +
  "_None yet._\n"
}

///|
fn synthesis_map_text() -> String {
  "# Synthesis Map\n\n" +
  "Coverage, hub pages, and open maintenance loops for this wiki.\n\n" +
  "## Coverage\n\n" +
  "_None yet._\n\n" +
  "## Entity Hubs\n\n" +
  "_None yet._\n\n" +
  "## Concept Hubs\n\n" +
  "_None yet._\n\n" +
  "## Open Loops\n\n" +
  "_None yet._\n"
}

///|
fn observations_text() -> String {
  "# Observations\n\n" +
  "This page stores persisted task results and durable observations promoted by the book harness.\n\n" +
  "## Results\n\n" +
  "_None yet._\n"
}

///|
fn evidence_text() -> String {
  "# Evidence\n\n" +
  "Structured support records for persisted results and reviewed knowledge.\n\n" +
  "## Records\n\n" +
  "_None yet._\n"
}

///|
fn keeper_insights_text() -> String {
  "# Keeper Insights\n\n" +
  "Signals and suggested cleanups for Keeper-managed memory.\n\n" +
  "## Signals\n\n" +
  "_None yet._\n\n" +
  "## Actions\n\n" +
  "_None yet._\n"
}

///|
fn pending_review_text() -> String {
  "# Pending Review\n\n" +
  "This page queues low-confidence or contested updates for human review.\n\n" +
  "## Items\n\n" +
  "_None yet._\n"
}

///|
fn approved_review_text() -> String {
  "# Approved Review\n\n" +
  "This page records review items that were accepted or resolved.\n\n" +
  "## Items\n\n" +
  "_None yet._\n"
}

///|
fn schema_text() -> String {
  "# Wiki Maintainer Instructions\n\n" +
  "This workspace is a persistent LLM-maintained wiki.\n\n" +
  "## Layers\n\n" +
  "- `raw/`: immutable source documents. Read-only unless the user explicitly asks to organize files.\n" +
  "- `wiki/`: maintained markdown knowledge base. The LLM owns updates here.\n" +
  "- `wiki/index.md`: content catalog. Update it whenever pages are added or meaningfully changed.\n" +
  "- `wiki/log.md`: append-only activity log. Add one entry per ingest, query, or lint pass.\n\n" +
  "- `wiki/reviews/pending.md`: items that should be reviewed before being treated as trusted synthesis.\n" +
  "- `wiki/reviews/approved.md`: review items that have been accepted or resolved.\n\n" +
  "- `wiki/synthesis/maintenance-plan.md`: queue of planned multi-page wiki revisions.\n\n" +
  "## Extension Boundary\n\n" +
  "- Core wiki workspaces should stay agent-agnostic.\n" +
  "- Agent-specific runtime files should be installed through optional extension packs.\n" +
  "- Do not assume a single agent runtime owns the workspace.\n\n" +
  "## Operations\n\n" +
  "### Ingest\n\n" +
  "When ingesting a source:\n\n" +
  "1. Read the source from `raw/`\n" +
  "2. Create or update relevant wiki pages in `wiki/`\n" +
  "3. Prefer revising related entity, concept, and synthesis pages instead of creating isolated summaries only\n" +
  "4. Update `wiki/index.md`\n" +
  "5. Append a timestamped entry to `wiki/log.md`\n" +
  "6. Preserve uncertainty and note contradictions explicitly\n" +
  "7. Queue contested or low-confidence updates in `wiki/reviews/pending.md`\n\n" +
  "### Query\n\n" +
  "When answering a question:\n\n" +
  "1. Read `wiki/index.md` first\n" +
  "2. Read the relevant wiki pages\n" +
  "3. Answer from the wiki with citations to page paths\n" +
  "4. If the answer creates durable value, propose filing it back into the wiki\n\n" +
  "### Lint\n\n" +
  "Periodically check for:\n\n" +
  "- orphan pages\n" +
  "- stale claims\n" +
  "- contradictions across pages\n" +
  "- missing entity or concept pages\n" +
  "- weak cross-references\n\n" +
  "## Conventions\n\n" +
  "- Prefer one concept or entity per page\n" +
  "- Use markdown links between related pages\n" +
  "- Do not delete user-authored raw sources\n" +
  "- Keep the wiki cumulative and revision-oriented, not chatty\n"
}

///|
fn escape_toml_string(text : String) -> String {
  text
  .replace(old="\\", new="\\\\")
  .to_string()
  .replace(old="\"", new="\\\"")
  .to_string()
}

///|
test "book toml points moonbook at wiki directory" {
  let text = book_toml_text("Demo Wiki")
  assert_true(text.contains("title = \"Demo Wiki\""))
  assert_true(text.contains("src = \"wiki\""))
  assert_true(text.contains("build-dir = \"book\""))
}

///|
test "summary seeds wiki navigation pages" {
  let text = summary_text()
  assert_true(text.contains("[Home](./Home.md)"))
  assert_true(text.contains("[Index](./index.md)"))
  assert_true(text.contains("[Log](./log.md)"))
  assert_true(text.contains("[Observations](./synthesis/observations.md)"))
  assert_true(text.contains("[Evidence](./synthesis/evidence.md)"))
  assert_true(text.contains("[Synthesis Map](./synthesis/map.md)"))
  assert_true(text.contains("[Pending Review](./reviews/pending.md)"))
  assert_true(
    text.contains("[Maintenance Plan](./synthesis/maintenance-plan.md)"),
  )
}

///|
test "schema explains ingest query and lint workflows" {
  let text = schema_text()
  assert_true(text.contains("### Ingest"))
  assert_true(text.contains("### Query"))
  assert_true(text.contains("### Lint"))
  assert_true(text.contains("wiki/index.md"))
  assert_true(text.contains("wiki/log.md"))
  assert_true(text.contains("agent-agnostic"))
  assert_true(text.contains("wiki/reviews/pending.md"))
}

///|
async test "init workspace seeds keeper memory files" {
  let root = "/tmp/moonbook-init-keeper"
  ignore(init_workspace(root))
  assert_true(@fsx.exists(root + "/keeper/MEMORY.md"))
  assert_true(@fsx.exists(root + "/keeper/USER.md"))
  assert_true(@fsx.exists(root + "/keeper/WORKING.md"))
  assert_true(@fsx.exists(root + "/keeper/POLICY.md"))
  assert_true(@fsx.exists(root + "/keeper/INSIGHTS.md"))
  assert_true(@fsx.exists(root + "/wiki/synthesis/evidence.md"))
  assert_true(@fsx.exists(root + "/wiki/synthesis/map.md"))
}
