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
  let raw_bootstrap_dir = @path.Path(raw_dir)
    .join(@path.Path("bootstrap"))
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
  let routines_path = @path.Path(normalized_root)
    .join(@path.Path("ROUTINES.md"))
    .to_string()
  let resolver_path = @path.Path(normalized_root)
    .join(@path.Path("RESOLVER.md"))
    .to_string()
  let book_toml_path = @path.Path(normalized_root)
    .join(@path.Path("book.toml"))
    .to_string()
  let site_dir = @path.Path(normalized_root)
    .join(@path.Path("site"))
    .to_string()
  let site_index_path = @path.Path(site_dir)
    .join(@path.Path("index.html"))
    .to_string()
  let site_styles_path = @path.Path(site_dir)
    .join(@path.Path("styles.css"))
    .to_string()
  let site_script_path = @path.Path(site_dir)
    .join(@path.Path("app.js"))
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
  let history_dir = @path.Path(wiki_dir).join(@path.Path("history")).to_string()
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
  let journey_path = @path.Path(history_dir)
    .join(@path.Path("journey.md"))
    .to_string()
  let debug_journal_path = @path.Path(history_dir)
    .join(@path.Path("debug-journal.md"))
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
  let skills_dir = @path.Path(normalized_root)
    .join(@path.Path("skills"))
    .to_string()
  let skill_candidates_dir = @path.Path(normalized_root)
    .join(@path.Path("skill-candidates"))
    .to_string()
  let ingest_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("wiki-ingest"))
    .to_string()
  let query_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("wiki-query"))
    .to_string()
  let lint_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("wiki-lint"))
    .to_string()
  let review_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("wiki-review"))
    .to_string()
  let memory_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("wiki-memory"))
    .to_string()
  let marketing_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("wiki-marketing"))
    .to_string()
  let course_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("wiki-course"))
    .to_string()
  let source_diarize_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("source-diarize"))
    .to_string()
  let entity_revise_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("entity-revise"))
    .to_string()
  let concept_revise_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("concept-revise"))
    .to_string()
  let synthesis_revise_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("synthesis-revise"))
    .to_string()
  let claim_audit_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("claim-audit"))
    .to_string()
  let contradiction_review_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("contradiction-review"))
    .to_string()
  let index_maintain_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("index-maintain"))
    .to_string()
  let query_promote_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("query-promote"))
    .to_string()
  let memory_prune_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("memory-prune"))
    .to_string()
  let review_decision_skill_dir = @path.Path(skills_dir)
    .join(@path.Path("review-decision"))
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
  let bootstrap_keep_path = @path.Path(raw_bootstrap_dir)
    .join(@path.Path(".gitkeep"))
    .to_string()
  let resolved_title = title.unwrap_or("LLM Wiki")

  @fsx.make_directory(normalized_root, recursive=true, exists_ok=true)
  @fsx.make_directory(raw_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(raw_assets_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(raw_bootstrap_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(site_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(wiki_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(entities_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(concepts_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(synthesis_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(history_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(queries_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(reviews_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(sources_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(keeper_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(skills_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(skill_candidates_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(ingest_skill_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(query_skill_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(lint_skill_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(review_skill_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(memory_skill_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(marketing_skill_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(course_skill_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(source_diarize_skill_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(entity_revise_skill_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(concept_revise_skill_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(
    synthesis_revise_skill_dir,
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(claim_audit_skill_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(
    contradiction_review_skill_dir,
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(index_maintain_skill_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(query_promote_skill_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(memory_prune_skill_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(review_decision_skill_dir, recursive=true, exists_ok=true)

  write_if_missing(book_toml_path, book_toml_text(resolved_title))
  write_if_missing(config_path, wiki_config_text())
  write_if_missing(schema_path, schema_text())
  write_if_missing(routines_path, base_routines_text())
  write_if_missing(resolver_path, resolver_text())
  write_if_missing(site_index_path, site_index_text(resolved_title))
  write_if_missing(site_styles_path, site_styles_text())
  write_if_missing(site_script_path, site_script_text())
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
  write_if_missing(journey_path, journey_text())
  write_if_missing(debug_journal_path, debug_journal_text())
  write_if_missing(pending_review_path, pending_review_text())
  write_if_missing(approved_review_path, approved_review_text())
  write_if_missing(keeper_memory_path, keeper_memory_text())
  write_if_missing(keeper_user_path, keeper_user_text())
  write_if_missing(keeper_working_path, keeper_working_text())
  write_if_missing(keeper_policy_path, keeper_policy_text())
  write_if_missing(keeper_insights_path, keeper_insights_text())
  copy_seed_tree_if_missing(ingest_skill_dir, "seed/wiki/skills/wiki-ingest")
  copy_seed_tree_if_missing(query_skill_dir, "seed/wiki/skills/wiki-query")
  copy_seed_tree_if_missing(lint_skill_dir, "seed/wiki/skills/wiki-lint")
  copy_seed_tree_if_missing(review_skill_dir, "seed/wiki/skills/wiki-review")
  copy_seed_tree_if_missing(memory_skill_dir, "seed/wiki/skills/wiki-memory")
  copy_seed_tree_if_missing(
    marketing_skill_dir, "seed/wiki/skills/wiki-marketing",
  )
  copy_seed_tree_if_missing(course_skill_dir, "seed/wiki/skills/wiki-course")
  copy_seed_tree_if_missing(
    source_diarize_skill_dir, "seed/wiki/skills/source-diarize",
  )
  copy_seed_tree_if_missing(
    entity_revise_skill_dir, "seed/wiki/skills/entity-revise",
  )
  copy_seed_tree_if_missing(
    concept_revise_skill_dir, "seed/wiki/skills/concept-revise",
  )
  copy_seed_tree_if_missing(
    synthesis_revise_skill_dir, "seed/wiki/skills/synthesis-revise",
  )
  copy_seed_tree_if_missing(
    claim_audit_skill_dir, "seed/wiki/skills/claim-audit",
  )
  copy_seed_tree_if_missing(
    contradiction_review_skill_dir, "seed/wiki/skills/contradiction-review",
  )
  copy_seed_tree_if_missing(
    index_maintain_skill_dir, "seed/wiki/skills/index-maintain",
  )
  copy_seed_tree_if_missing(
    query_promote_skill_dir, "seed/wiki/skills/query-promote",
  )
  copy_seed_tree_if_missing(
    memory_prune_skill_dir, "seed/wiki/skills/memory-prune",
  )
  copy_seed_tree_if_missing(
    review_decision_skill_dir, "seed/wiki/skills/review-decision",
  )
  write_if_missing(raw_readme_path, raw_readme_text())
  write_if_missing(assets_keep_path, "")
  write_if_missing(bootstrap_keep_path, "")

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
async fn copy_seed_tree_if_missing(
  destination_path : String,
  seed_relative_path : String,
) -> Unit {
  let source_path = @path.Path(seed_module_root())
    .join(@path.Path(seed_relative_path))
    .to_string()
  if !@fsx.exists(source_path) {
    fail("missing seed file: \{source_path}")
  }
  copy_seed_tree(source_path, destination_path)
}

///|
async fn copy_seed_tree(
  source_path : String,
  destination_path : String,
) -> Unit {
  match @fs.kind(source_path, follow_symlink=false) {
    @fs.FileKind::Directory => {
      @fsx.make_directory(destination_path, recursive=true, exists_ok=true)
      for child in @fsx.list_directory(source_path) {
        let child_name = @path.Path(child).basename().to_string()
        copy_seed_tree(
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
fn seed_module_root() -> String {
  @env.current_dir().unwrap_or(".")
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
  "resolver = \"RESOLVER.md\"\n" +
  "routines = \"ROUTINES.md\"\n" +
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
  "- [Journey](./history/journey.md)\n" +
  "- [Debug Journal](./history/debug-journal.md)\n" +
  "- [Pending Review](./reviews/pending.md)\n" +
  "- [Approved Review](./reviews/approved.md)\n"
}

///|
fn home_text() -> String {
  "# Home\n\n" +
  "This workspace is an LLM-maintained wiki.\n\n" +
  "## Structure\n\n" +
  "- `../site/`: marketing website projection copied to `book/site/` during build\n" +
  "- `../raw/`: immutable source documents and attachments staged for ingest\n" +
  "- `./sources/`: durable source pages generated from raw material\n" +
  "- `./entities/`: maintained entity pages\n" +
  "- `./concepts/`: maintained concept pages\n" +
  "- `./queries/`: durable analysis and saved query pages\n" +
  "- [Index](./index.md): content catalog of the wiki\n" +
  "- [Log](./log.md): append-only timeline of ingests, queries, and lint passes\n" +
  "- [Claims Register](./synthesis/claims.md): structured claims extracted from sources\n" +
  "- [Maintenance Plan](./synthesis/maintenance-plan.md): queued multi-page wiki revisions\n" +
  "- [Synthesis Map](./synthesis/map.md): coverage and hub view across the wiki\n" +
  "- [Observations](./synthesis/observations.md): persisted worker results and promoted observations\n" +
  "- [Journey](./history/journey.md): compact history of major runs, decisions, and open loops\n" +
  "- [Debug Journal](./history/debug-journal.md): detailed run-by-run material prep and debug notes\n" +
  "- [Pending Review](./reviews/pending.md): human review queue for contested or high-value updates\n" +
  "- `../keeper/`: bounded active memory, user memory, and working memory for Keeper\n" +
  "\n## Research Bootstrap Layout\n\n" +
  "1. `raw/` keeps immutable inputs.\n" +
  "2. `wiki/sources/` stores durable source pages created from those inputs.\n" +
  "3. `wiki/entities/` and `wiki/concepts/` hold maintained ontology coverage.\n" +
  "4. `wiki/queries/` stores durable analysis pages rather than leaving answers in chat.\n" +
  "5. `wiki/synthesis/` tracks overview, claims, maintenance, evidence, and observations.\n\n" +
  "## Usage\n\n" +
  "1. Drop a source into `raw/`\n" +
  "2. Ask the LLM to ingest it into the wiki\n" +
  "3. Build or serve with MoonBook to publish the detailed wiki and the `site/` marketing projection together\n"
}

///|
fn index_text() -> String {
  "# Index\n\n" +
  "## Core Pages\n\n" +
  "- [Overview](./synthesis/overview.md): cross-source synthesis page\n" +
  "- [Home](./Home.md): wiki landing page\n" +
  "- [Index](./index.md): content catalog\n" +
  "- [Log](./log.md): activity timeline\n" +
  "- `../site/index.html`: optional marketing projection for customers, teammates, or operators\n" +
  "- [Claims Register](./synthesis/claims.md): structured claims with confidence and support markers\n" +
  "- [Maintenance Plan](./synthesis/maintenance-plan.md): multi-page synthesis and maintenance queue\n" +
  "- [Query Insights](./synthesis/query-insights.md): durable insights from saved queries\n" +
  "- [Synthesis Map](./synthesis/map.md): coverage and maintenance view across the maintained wiki\n" +
  "- [Observations](./synthesis/observations.md): persisted task results and promoted book observations\n" +
  "- [Evidence](./synthesis/evidence.md): support records for persisted results and reviewed knowledge\n" +
  "- [Journey](./history/journey.md): compact operator-facing journey from earlier runs to the current book state\n" +
  "- [Debug Journal](./history/debug-journal.md): detailed keeper and worker debug trail for intermediate preparation quality\n" +
  "- [Pending Review](./reviews/pending.md): pending human review items\n" +
  "- [Approved Review](./reviews/approved.md): accepted review decisions\n\n" +
  "## Research Bootstrap Layout\n\n" +
  "- `../raw/`: immutable source files waiting to be diarized or revised into the wiki\n" +
  "- `./sources/`: durable source pages that later query and synthesis work should cite\n" +
  "- `./entities/`: maintained entity pages\n" +
  "- `./concepts/`: maintained concept pages\n" +
  "- `./queries/`: durable query notes and saved answers\n" +
  "- `./synthesis/`: overview, claims, maintenance plan, query insights, evidence, and observations\n" +
  "- `./history/`: compact journey plus detailed debug-journal pages generated from persisted work\n\n" +
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
  "MoonClaw bootstrap runs may also write generated source packets into `bootstrap/` before Keeper ingests them into durable wiki pages.\n\n" +
  "Canonical bootstrap flow:\n\n" +
  "1. Store original material in `raw/`.\n" +
  "2. Write generated source packets into `raw/bootstrap/` when bootstrap discovery needs to stage local repo material.\n" +
  "3. Generate durable source pages in `wiki/sources/`.\n" +
  "4. Revise `wiki/entities/`, `wiki/concepts/`, `wiki/queries/`, and `wiki/synthesis/` from those durable pages.\n\n" +
  "Examples:\n\n" +
  "- clipped web articles\n" +
  "- papers\n" +
  "- notes exported from meetings\n" +
  "- images and attachments under `assets/`\n\n" +
  "Keep marketing-site assets in `../site/`, not here.\n"
}

///|
fn site_index_text(title : String) -> String {
  "<!doctype html>\n" +
  "<html lang=\"en\">\n" +
  "<head>\n" +
  "  <meta charset=\"utf-8\">\n" +
  "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" +
  "  <title>\{title} Website</title>\n" +
  "  <meta name=\"description\" content=\"A polished marketing projection for the MoonBook workspace.\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.googleapis.com\">\n" +
  "  <link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>\n" +
  "  <link href=\"https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Space+Grotesk:wght@400;500;700&display=swap\" rel=\"stylesheet\">\n" +
  "  <link rel=\"stylesheet\" href=\"./styles.css\">\n" +
  "</head>\n" +
  "<body>\n" +
  "  <div class=\"backdrop\"></div>\n" +
  "  <header class=\"topbar\">\n" +
  "    <a class=\"brand\" href=\"../index.html\">\n" +
  "      <span class=\"brand-mark\">MB</span>\n" +
  "      <span>\{title}</span>\n" +
  "    </a>\n" +
  "    <nav class=\"nav\">\n" +
  "      <a href=\"../index.html\">Book</a>\n" +
  "      <a href=\"../Home.html\">Wiki</a>\n" +
  "      <a href=\"#layers\">Layers</a>\n" +
  "      <a href=\"#generated\">Generated</a>\n" +
  "    </nav>\n" +
  "  </header>\n" +
  "  <main class=\"page-shell\">\n" +
  "    <section class=\"hero reveal\">\n" +
  "      <div class=\"hero-copy\">\n" +
  "        <p class=\"eyebrow\">Markdown. Wiki. Website.</p>\n" +
  "        <h1>Turn a maintained knowledge workspace into something people can understand in one minute.</h1>\n" +
  "        <p class=\"lede\">MoonBook keeps authored markdown, persistent wiki memory, and a polished marketing projection in one local workspace. Build once, then serve docs, knowledge, and presentation together.</p>\n" +
  "        <div class=\"hero-actions\">\n" +
  "          <a class=\"button button-primary\" href=\"../index.html\">Open the book</a>\n" +
  "          <a class=\"button button-secondary\" href=\"../Home.html\">Open the wiki</a>\n" +
  "          <a class=\"button button-secondary\" href=\"#layers\">See the layers</a>\n" +
  "          <a class=\"button button-secondary\" href=\"#generated\">See generated surfaces</a>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "      <div class=\"hero-stage tilt\" id=\"demo\">\n" +
  "        <div class=\"stage-card terminal-card\">\n" +
  "          <div class=\"stage-label\">keeper</div>\n" +
  "          <pre><code>wiki ingest raw/customer-interviews.md\nwiki query \"What changed in user pain?\"\nwiki review approve review-0007</code></pre>\n" +
  "        </div>\n" +
  "        <div class=\"stage-card metrics-card\">\n" +
  "          <div class=\"stage-label\">workspace state</div>\n" +
  "          <div class=\"metric-grid\">\n" +
  "            <article><strong>3</strong><span>content layers</span></article>\n" +
  "            <article><strong>1</strong><span>build output</span></article>\n" +
  "            <article><strong>∞</strong><span>iterative revisions</span></article>\n" +
  "          </div>\n" +
  "        </div>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\" id=\"layers\">\n" +
  "      <div class=\"section-heading\">\n" +
  "        <p class=\"eyebrow\">Three layers</p>\n" +
  "        <h2>Keep the system legible at every altitude.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"card-grid\">\n" +
  "        <article class=\"module-card tilt\">\n" +
  "          <span class=\"module-kicker\">01</span>\n" +
  "          <h3>Markdown book</h3>\n" +
  "          <p>Authored pages, navigation, and static rendering for canonical docs.</p>\n" +
  "        </article>\n" +
  "        <article class=\"module-card tilt\">\n" +
  "          <span class=\"module-kicker\">02</span>\n" +
  "          <h3>Maintained wiki</h3>\n" +
  "          <p>Persistent entities, concepts, synthesis, claims, review queues, and keeper memory.</p>\n" +
  "        </article>\n" +
  "        <article class=\"module-card tilt\">\n" +
  "          <span class=\"module-kicker\">03</span>\n" +
  "          <h3>Demo website</h3>\n" +
  "          <p>A marketing-oriented presentation surface for customers, teammates, and operators, copied into `book/site/` during build.</p>\n" +
  "        </article>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\">\n" +
  "      <div class=\"section-heading narrow\">\n" +
  "        <p class=\"eyebrow\">Why this shape</p>\n" +
  "        <h2>One workspace, three audiences.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"story-grid\">\n" +
  "        <article>\n" +
  "          <h3>Operators</h3>\n" +
  "          <p>Need the live wiki and review queues to stay cumulative instead of chat-fragmented.</p>\n" +
  "        </article>\n" +
  "        <article>\n" +
  "          <h3>Teammates</h3>\n" +
  "          <p>Need documentation and structure that still feels deterministic and local-first.</p>\n" +
  "        </article>\n" +
  "        <article>\n" +
  "          <h3>Visitors</h3>\n" +
  "          <p>Need a crisp story, not the full internals. The marketing projection gives them that surface.</p>\n" +
  "        </article>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "    <section class=\"section reveal\" id=\"generated\">\n" +
  "      <div class=\"section-heading narrow\">\n" +
  "        <p class=\"eyebrow\">Generated surfaces</p>\n" +
  "        <h2>Build or serve emits the live projections from the current workspace state.</h2>\n" +
  "      </div>\n" +
  "      <div class=\"story-grid\">\n" +
  "        <article>\n" +
  "          <h3>Marketing projection</h3>\n" +
  "          <p>Written to <code>book/site/generated/index.html</code> from wiki, keeper, review, and journey state.</p>\n" +
  "        </article>\n" +
  "        <article>\n" +
  "          <h3>Journal view</h3>\n" +
  "          <p>Written to <code>book/site/generated/journal.html</code> so operators can inspect the durable timeline without entering the full wiki.</p>\n" +
  "        </article>\n" +
  "        <article>\n" +
  "          <h3>Course and skills</h3>\n" +
  "          <p>Written to <code>book/site/generated/course.html</code> and <code>book/site/generated/skills.html</code> when you need education and operations, not just presentation.</p>\n" +
  "        </article>\n" +
  "      </div>\n" +
  "    </section>\n" +
  "  </main>\n" +
  "  <script src=\"./app.js\"></script>\n" +
  "</body>\n" +
  "</html>\n"
}

///|
fn site_styles_text() -> String {
  ":root {\n" +
  "  --paper: #fff7ea;\n" +
  "  --paper-strong: #f5e6ce;\n" +
  "  --ink: #13241f;\n" +
  "  --muted: #54645d;\n" +
  "  --forest: #173c34;\n" +
  "  --amber: #d97706;\n" +
  "  --coral: #e96b4c;\n" +
  "  --line: rgba(19, 36, 31, 0.12);\n" +
  "  --shadow: 0 24px 80px rgba(20, 34, 29, 0.14);\n" +
  "}\n\n" +
  "* { box-sizing: border-box; }\n" +
  "html { scroll-behavior: smooth; }\n" +
  "body {\n" +
  "  margin: 0;\n" +
  "  min-height: 100vh;\n" +
  "  font-family: \"Space Grotesk\", \"Avenir Next\", \"Trebuchet MS\", sans-serif;\n" +
  "  color: var(--ink);\n" +
  "  background: radial-gradient(circle at top, rgba(233, 107, 76, 0.14), transparent 28%), linear-gradient(180deg, #fffaf2 0%, var(--paper) 54%, #f6ead8 100%);\n" +
  "}\n" +
  "a { color: inherit; text-decoration: none; }\n" +
  ".backdrop {\n" +
  "  position: fixed;\n" +
  "  inset: 0;\n" +
  "  pointer-events: none;\n" +
  "  background-image: linear-gradient(rgba(19, 36, 31, 0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(19, 36, 31, 0.03) 1px, transparent 1px);\n" +
  "  background-size: 32px 32px;\n" +
  "  mask-image: linear-gradient(180deg, rgba(0,0,0,0.85), transparent 92%);\n" +
  "}\n" +
  ".topbar {\n" +
  "  position: sticky;\n" +
  "  top: 0;\n" +
  "  z-index: 20;\n" +
  "  display: flex;\n" +
  "  justify-content: space-between;\n" +
  "  align-items: center;\n" +
  "  gap: 1rem;\n" +
  "  padding: 1rem 1.4rem;\n" +
  "  backdrop-filter: blur(18px);\n" +
  "  background: rgba(255, 247, 234, 0.76);\n" +
  "  border-bottom: 1px solid var(--line);\n" +
  "}\n" +
  ".brand {\n" +
  "  display: inline-flex;\n" +
  "  align-items: center;\n" +
  "  gap: 0.8rem;\n" +
  "  font-weight: 700;\n" +
  "  letter-spacing: -0.04em;\n" +
  "}\n" +
  ".brand-mark {\n" +
  "  display: grid;\n" +
  "  place-items: center;\n" +
  "  width: 2.4rem;\n" +
  "  height: 2.4rem;\n" +
  "  border-radius: 0.85rem;\n" +
  "  color: #fff7ea;\n" +
  "  background: linear-gradient(135deg, var(--forest), #245d50);\n" +
  "  box-shadow: 0 16px 40px rgba(23, 60, 52, 0.28);\n" +
  "}\n" +
  ".nav {\n" +
  "  display: inline-flex;\n" +
  "  gap: 1rem;\n" +
  "  flex-wrap: wrap;\n" +
  "  color: var(--muted);\n" +
  "}\n" +
  ".nav a:hover { color: var(--ink); }\n" +
  ".page-shell { width: min(1180px, calc(100% - 2.4rem)); margin: 0 auto; padding: 3rem 0 5rem; }\n" +
  ".hero {\n" +
  "  display: grid;\n" +
  "  grid-template-columns: 1.15fr 0.95fr;\n" +
  "  gap: 2rem;\n" +
  "  align-items: center;\n" +
  "  padding: 3.4rem 0 2rem;\n" +
  "}\n" +
  ".eyebrow {\n" +
  "  margin: 0 0 1rem;\n" +
  "  color: var(--amber);\n" +
  "  font-size: 0.82rem;\n" +
  "  font-weight: 700;\n" +
  "  letter-spacing: 0.16em;\n" +
  "  text-transform: uppercase;\n" +
  "}\n" +
  "h1, h2, h3 { margin: 0; letter-spacing: -0.05em; }\n" +
  "h1 {\n" +
  "  font-family: \"Instrument Serif\", Georgia, serif;\n" +
  "  font-size: clamp(3.4rem, 7vw, 6.4rem);\n" +
  "  line-height: 0.95;\n" +
  "  max-width: 10ch;\n" +
  "}\n" +
  "h2 {\n" +
  "  font-family: \"Instrument Serif\", Georgia, serif;\n" +
  "  font-size: clamp(2.2rem, 5vw, 4rem);\n" +
  "  line-height: 1;\n" +
  "}\n" +
  "h3 { font-size: 1.15rem; }\n" +
  ".lede {\n" +
  "  margin: 1.25rem 0 0;\n" +
  "  max-width: 34rem;\n" +
  "  font-size: 1.05rem;\n" +
  "  line-height: 1.7;\n" +
  "  color: var(--muted);\n" +
  "}\n" +
  ".hero-actions { display: flex; flex-wrap: wrap; gap: 0.9rem; margin-top: 1.6rem; }\n" +
  ".button {\n" +
  "  display: inline-flex;\n" +
  "  align-items: center;\n" +
  "  justify-content: center;\n" +
  "  min-height: 3.2rem;\n" +
  "  padding: 0.8rem 1.2rem;\n" +
  "  border-radius: 999px;\n" +
  "  border: 1px solid transparent;\n" +
  "  font-weight: 700;\n" +
  "}\n" +
  ".button-primary {\n" +
  "  color: #fff8ee;\n" +
  "  background: linear-gradient(135deg, var(--forest), #245d50);\n" +
  "  box-shadow: 0 18px 36px rgba(23, 60, 52, 0.22);\n" +
  "}\n" +
  ".button-secondary {\n" +
  "  border-color: var(--line);\n" +
  "  background: rgba(255, 255, 255, 0.56);\n" +
  "}\n" +
  ".hero-stage, .module-card {\n" +
  "  border: 1px solid var(--line);\n" +
  "  box-shadow: var(--shadow);\n" +
  "}\n" +
  ".hero-stage {\n" +
  "  display: grid;\n" +
  "  gap: 1rem;\n" +
  "  padding: 1.2rem;\n" +
  "  border-radius: 1.8rem;\n" +
  "  background: rgba(255, 252, 246, 0.82);\n" +
  "}\n" +
  ".stage-card {\n" +
  "  padding: 1rem;\n" +
  "  border-radius: 1.3rem;\n" +
  "  background: linear-gradient(180deg, rgba(255,255,255,0.94), rgba(244, 231, 209, 0.7));\n" +
  "}\n" +
  ".stage-label {\n" +
  "  font-size: 0.76rem;\n" +
  "  font-weight: 700;\n" +
  "  letter-spacing: 0.14em;\n" +
  "  text-transform: uppercase;\n" +
  "  color: var(--muted);\n" +
  "}\n" +
  "pre {\n" +
  "  overflow: auto;\n" +
  "  margin: 0.9rem 0 0;\n" +
  "  padding: 1rem;\n" +
  "  border-radius: 1rem;\n" +
  "  background: #10201b;\n" +
  "  color: #edf5f0;\n" +
  "}\n" +
  ".metric-grid {\n" +
  "  display: grid;\n" +
  "  grid-template-columns: repeat(3, minmax(0, 1fr));\n" +
  "  gap: 0.85rem;\n" +
  "  margin-top: 0.9rem;\n" +
  "}\n" +
  ".metric-grid article {\n" +
  "  padding: 1rem;\n" +
  "  border-radius: 1rem;\n" +
  "  background: rgba(23, 60, 52, 0.06);\n" +
  "}\n" +
  ".metric-grid strong {\n" +
  "  display: block;\n" +
  "  font-size: 1.9rem;\n" +
  "  line-height: 1;\n" +
  "}\n" +
  ".metric-grid span, .story-grid p, .module-card p { color: var(--muted); line-height: 1.65; }\n" +
  ".section { padding: 3.5rem 0 0; }\n" +
  ".section-heading { display: flex; flex-direction: column; gap: 0.75rem; max-width: 42rem; }\n" +
  ".section-heading.narrow { max-width: 36rem; }\n" +
  ".card-grid {\n" +
  "  display: grid;\n" +
  "  grid-template-columns: repeat(3, minmax(0, 1fr));\n" +
  "  gap: 1rem;\n" +
  "  margin-top: 1.6rem;\n" +
  "}\n" +
  ".module-card {\n" +
  "  padding: 1.35rem;\n" +
  "  border-radius: 1.5rem;\n" +
  "  background: rgba(255, 252, 246, 0.84);\n" +
  "}\n" +
  ".module-kicker {\n" +
  "  display: inline-block;\n" +
  "  margin-bottom: 0.9rem;\n" +
  "  color: var(--coral);\n" +
  "  font-size: 0.8rem;\n" +
  "  font-weight: 700;\n" +
  "}\n" +
  ".story-grid {\n" +
  "  display: grid;\n" +
  "  grid-template-columns: repeat(3, minmax(0, 1fr));\n" +
  "  gap: 1rem;\n" +
  "  margin-top: 1.6rem;\n" +
  "}\n" +
  ".story-grid article {\n" +
  "  padding: 1.2rem 1.25rem;\n" +
  "  border-top: 1px solid var(--line);\n" +
  "  background: rgba(255, 255, 255, 0.45);\n" +
  "}\n" +
  ".reveal {\n" +
  "  opacity: 0;\n" +
  "  transform: translateY(18px);\n" +
  "  transition: opacity 560ms ease, transform 560ms ease;\n" +
  "}\n" +
  ".reveal.is-visible {\n" +
  "  opacity: 1;\n" +
  "  transform: translateY(0);\n" +
  "}\n" +
  "@media (max-width: 980px) {\n" +
  "  .hero, .card-grid, .story-grid { grid-template-columns: 1fr; }\n" +
  "  .page-shell { width: min(100% - 1.4rem, 1180px); }\n" +
  "  .metric-grid { grid-template-columns: 1fr; }\n" +
  "}\n" +
  "@media (max-width: 640px) {\n" +
  "  .topbar { align-items: flex-start; flex-direction: column; }\n" +
  "  h1 { max-width: none; }\n" +
  "}\n" +
  "@media (prefers-reduced-motion: reduce) {\n" +
  "  html { scroll-behavior: auto; }\n" +
  "  .reveal { opacity: 1; transform: none; transition: none; }\n" +
  "  .tilt { transform: none !important; }\n" +
  "}\n"
}

///|
fn site_script_text() -> String {
  "const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;\n" +
  "const revealNodes = document.querySelectorAll('.reveal');\n" +
  "if (!reduceMotion && 'IntersectionObserver' in window) {\n" +
  "  const observer = new IntersectionObserver((entries) => {\n" +
  "    for (const entry of entries) {\n" +
  "      if (entry.isIntersecting) {\n" +
  "        entry.target.classList.add('is-visible');\n" +
  "        observer.unobserve(entry.target);\n" +
  "      }\n" +
  "    }\n" +
  "  }, { threshold: 0.16 });\n" +
  "  revealNodes.forEach((node) => observer.observe(node));\n" +
  "} else {\n" +
  "  revealNodes.forEach((node) => node.classList.add('is-visible'));\n" +
  "}\n" +
  "if (!reduceMotion) {\n" +
  "  document.querySelectorAll('.tilt').forEach((node) => {\n" +
  "    node.addEventListener('pointermove', (event) => {\n" +
  "      const rect = node.getBoundingClientRect();\n" +
  "      const px = (event.clientX - rect.left) / rect.width - 0.5;\n" +
  "      const py = (event.clientY - rect.top) / rect.height - 0.5;\n" +
  "      node.style.transform = `perspective(1200px) rotateX(${(-py * 5).toFixed(2)}deg) rotateY(${(px * 7).toFixed(2)}deg) translateY(-2px)`;\n" +
  "    });\n" +
  "    node.addEventListener('pointerleave', () => {\n" +
  "      node.style.transform = '';\n" +
  "    });\n" +
  "  });\n" +
  "}\n"
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
fn base_routines_text() -> String {
  "# Routines\n\n" +
  "1. Read `RESOLVER.md` to decide which skills and files matter for the task.\n" +
  "2. Load the relevant `skills/*/SKILL.md` file before planning or writing.\n" +
  "3. Keep deterministic work in MoonBook code and judgment work in skills.\n" +
  "4. Persist durable outcomes back into `wiki/`, `keeper/`, and review queues.\n" +
  "5. Keep `wiki/` detailed and truth-oriented; keep `site/` projection-oriented with distinct marketing, journal, and course surfaces.\n"
}

///|
fn resolver_text() -> String {
  "# Resolver\n\n" +
  "This file routes tasks to the right skills and context files.\n\n" +
  "## Routes\n\n" +
  "- intent: ingest\n" +
  "  skill: `skills/wiki-ingest/SKILL.md`\n" +
  "  supporting_skills: `skills/source-diarize/SKILL.md`, `skills/entity-revise/SKILL.md`, `skills/concept-revise/SKILL.md`, `skills/synthesis-revise/SKILL.md`, `skills/claim-audit/SKILL.md`, `skills/index-maintain/SKILL.md`\n" +
  "  load_first: `wiki/index.md`, `wiki/log.md`, `wiki/synthesis/maintenance-plan.md`\n" +
  "- intent: query\n" +
  "  skill: `skills/wiki-query/SKILL.md`\n" +
  "  supporting_skills: `skills/query-promote/SKILL.md`, `skills/claim-audit/SKILL.md`\n" +
  "  load_first: `wiki/index.md`, `wiki/synthesis/overview.md`, `wiki/synthesis/claims.md`, `wiki/history/journey.md`\n" +
  "- intent: lint\n" +
  "  skill: `skills/wiki-lint/SKILL.md`\n" +
  "  supporting_skills: `skills/contradiction-review/SKILL.md`, `skills/index-maintain/SKILL.md`, `skills/memory-prune/SKILL.md`\n" +
  "  load_first: `wiki/index.md`, `wiki/log.md`, `wiki/synthesis/map.md`, `wiki/history/journey.md`, `keeper/INSIGHTS.md`\n" +
  "- intent: review\n" +
  "  skill: `skills/wiki-review/SKILL.md`\n" +
  "  supporting_skills: `skills/review-decision/SKILL.md`, `skills/contradiction-review/SKILL.md`, `skills/claim-audit/SKILL.md`\n" +
  "  load_first: `wiki/reviews/pending.md`, `wiki/reviews/approved.md`, `wiki/synthesis/evidence.md`\n" +
  "- intent: memory\n" +
  "  skill: `skills/wiki-memory/SKILL.md`\n" +
  "  supporting_skills: `skills/memory-prune/SKILL.md`, `skills/query-promote/SKILL.md`\n" +
  "  load_first: `keeper/MEMORY.md`, `keeper/USER.md`, `keeper/WORKING.md`, `keeper/INSIGHTS.md`\n" +
  "- intent: marketing\n" +
  "  skill: `skills/wiki-marketing/SKILL.md`\n" +
  "  supporting_skills: `skills/wiki-query/SKILL.md`, `skills/synthesis-revise/SKILL.md`, `skills/query-promote/SKILL.md`\n" +
  "  load_first: `wiki/synthesis/overview.md`, `wiki/index.md`, `wiki/synthesis/map.md`, `keeper/INSIGHTS.md`, `site/index.html`\n" +
  "- intent: course\n" +
  "  skill: `skills/wiki-course/SKILL.md`\n" +
  "  supporting_skills: `skills/wiki-query/SKILL.md`, `skills/wiki-marketing/SKILL.md`, `skills/query-promote/SKILL.md`\n" +
  "  load_first: `wiki/index.md`, `wiki/history/journey.md`, `wiki/synthesis/map.md`, `wiki/synthesis/evidence.md`, `site/index.html`\n"
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
  "MoonBook is the thin harness. Skills carry the domain procedures. Keep deterministic indexing, bookkeeping, and safety in code. Keep judgment, synthesis, diarization, and revision planning in skill files.\n\n" +
  "## Layers\n\n" +
  "- `raw/`: immutable source documents. Read-only unless the user explicitly asks to organize files.\n" +
  "- `wiki/`: maintained markdown knowledge base. The LLM owns updates here.\n" +
  "- `site/`: optional marketing website projection for presentation. Build copies it to `book/site/`.\n" +
  "- `wiki/index.md`: content catalog. Update it whenever pages are added or meaningfully changed.\n" +
  "- `wiki/log.md`: append-only activity log. Add one entry per ingest, query, or lint pass.\n\n" +
  "- `wiki/reviews/pending.md`: items that should be reviewed before being treated as trusted synthesis.\n" +
  "- `wiki/reviews/approved.md`: review items that have been accepted or resolved.\n\n" +
  "- `wiki/synthesis/maintenance-plan.md`: queue of planned multi-page wiki revisions.\n\n" +
  "- `RESOLVER.md`: route tasks to the correct skill and context bundle.\n" +
  "- `ROUTINES.md`: shared harness routine, kept short.\n" +
  "- `skills/*/SKILL.md`: reusable procedures that teach the agent how to work this wiki.\n" +
  "- Use a two-layer skill shape: a small set of orchestration skills and a larger set of narrower worker skills.\n\n" +
  "## Extension Boundary\n\n" +
  "- Core wiki workspaces should stay agent-agnostic.\n" +
  "- Agent-specific runtime files should be installed through optional extension packs.\n" +
  "- Do not assume a single agent runtime owns the workspace.\n\n" +
  "## Operations\n\n" +
  "### Ingest\n\n" +
  "When ingesting a source:\n\n" +
  "1. Read `RESOLVER.md` and load `skills/wiki-ingest/SKILL.md`\n" +
  "2. Read the source from `raw/`\n" +
  "3. Create or update relevant wiki pages in `wiki/`\n" +
  "4. Prefer revising related entity, concept, and synthesis pages instead of creating isolated summaries only\n" +
  "5. Update `wiki/index.md`\n" +
  "6. Append a timestamped entry to `wiki/log.md`\n" +
  "7. Preserve uncertainty and note contradictions explicitly\n" +
  "8. Queue contested or low-confidence updates in `wiki/reviews/pending.md`\n\n" +
  "### Query\n\n" +
  "When answering a question:\n\n" +
  "1. Read `RESOLVER.md` and load `skills/wiki-query/SKILL.md`\n" +
  "2. Read `wiki/index.md` first\n" +
  "3. Read the relevant wiki pages\n" +
  "4. Answer from the wiki with citations to page paths\n" +
  "5. If the answer creates durable value, propose filing it back into the wiki\n\n" +
  "### Marketing\n\n" +
  "When updating the marketing projection:\n\n" +
  "1. Read `RESOLVER.md` and load `skills/wiki-marketing/SKILL.md`\n" +
  "2. Treat `wiki/` as the detailed source of truth and `site/` as the compressed presentation layer\n" +
  "3. Keep claims accurate, but rewrite them into audience-facing product language\n" +
  "4. Prefer stable capability framing, clear product boundaries, and links back into maintained wiki pages\n\n" +
  "### Course\n\n" +
  "When updating the educational course projection:\n\n" +
  "1. Read `RESOLVER.md` and load `skills/wiki-course/SKILL.md`\n" +
  "2. Treat the course as a teaching surface, not as the canonical source of truth\n" +
  "3. Use module-based explanation, plain language, and interactive checkpoints to explain how the workspace works\n" +
  "4. Keep the course educational and procedural; do not collapse it into marketing or operator journaling\n\n" +
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
async fn unique_test_root(base : String) -> String {
  unique_test_root_with_attempt(base, 0)
}

///|
async fn unique_test_root_with_attempt(base : String, attempt : Int) -> String {
  let suffix = if attempt == 0 { "" } else { "-" + attempt.to_string() }
  let candidate = base + suffix
  if @fsx.exists(candidate) {
    unique_test_root_with_attempt(base, attempt + 1)
  } else {
    candidate
  }
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
  assert_true(text.contains("[Journey](./history/journey.md)"))
  assert_true(text.contains("[Debug Journal](./history/debug-journal.md)"))
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
  assert_true(text.contains("skills/*/SKILL.md"))
  assert_true(text.contains("thin harness"))
}

///|
async test "init workspace seeds keeper memory files" {
  let root = unique_test_root("/tmp/moonbook-init-keeper")
  ignore(init_workspace(root))
  assert_true(@fsx.exists(root + "/keeper/MEMORY.md"))
  assert_true(@fsx.exists(root + "/keeper/USER.md"))
  assert_true(@fsx.exists(root + "/keeper/WORKING.md"))
  assert_true(@fsx.exists(root + "/keeper/POLICY.md"))
  assert_true(@fsx.exists(root + "/keeper/INSIGHTS.md"))
  assert_true(@fsx.exists(root + "/skill-candidates"))
  assert_true(@fsx.exists(root + "/RESOLVER.md"))
  assert_true(@fsx.exists(root + "/ROUTINES.md"))
  assert_true(@fsx.exists(root + "/skills/wiki-ingest/SKILL.md"))
  assert_true(
    @fsx.exists(root + "/skills/wiki-ingest/references/raw-first-contract.md"),
  )
  assert_true(@fsx.exists(root + "/skills/wiki-query/SKILL.md"))
  assert_true(
    @fsx.exists(root + "/skills/wiki-query/references/promotion-contract.md"),
  )
  assert_true(@fsx.exists(root + "/skills/wiki-lint/SKILL.md"))
  assert_true(@fsx.exists(root + "/skills/wiki-review/SKILL.md"))
  assert_true(
    @fsx.exists(root + "/skills/wiki-review/references/review-gates.md"),
  )
  assert_true(@fsx.exists(root + "/skills/wiki-memory/SKILL.md"))
  assert_true(
    @fsx.exists(root + "/skills/wiki-memory/references/memory-boundaries.md"),
  )
  assert_true(@fsx.exists(root + "/skills/wiki-marketing/SKILL.md"))
  assert_true(@fsx.exists(root + "/skills/source-diarize/SKILL.md"))
  assert_true(@fsx.exists(root + "/skills/entity-revise/SKILL.md"))
  assert_true(@fsx.exists(root + "/skills/concept-revise/SKILL.md"))
  assert_true(@fsx.exists(root + "/skills/synthesis-revise/SKILL.md"))
  assert_true(@fsx.exists(root + "/skills/claim-audit/SKILL.md"))
  assert_true(@fsx.exists(root + "/skills/contradiction-review/SKILL.md"))
  assert_true(@fsx.exists(root + "/skills/index-maintain/SKILL.md"))
  assert_true(@fsx.exists(root + "/skills/query-promote/SKILL.md"))
  assert_true(@fsx.exists(root + "/skills/memory-prune/SKILL.md"))
  assert_true(@fsx.exists(root + "/skills/review-decision/SKILL.md"))
  assert_true(@fsx.exists(root + "/wiki/synthesis/evidence.md"))
  assert_true(@fsx.exists(root + "/wiki/synthesis/map.md"))
  assert_true(@fsx.exists(root + "/wiki/history/journey.md"))
  assert_true(@fsx.exists(root + "/wiki/history/debug-journal.md"))
  assert_true(@fsx.exists(root + "/site/index.html"))
  assert_true(@fsx.exists(root + "/site/styles.css"))
  assert_true(@fsx.exists(root + "/site/app.js"))
  let site_index = @fsx.read_file(root + "/site/index.html")
  assert_true(site_index.contains("<title>"))
  assert_true(!site_index.contains("Demo Site"))
  assert_true(!site_index.contains("./generated/reader.html"))
  assert_true(site_index.contains("book/site/generated/index.html"))
  assert_true(site_index.contains("book/site/generated/journal.html"))
  assert_true(@fsx.exists(root + "/raw/bootstrap/.gitkeep"))
}

///|
async test "seeded wiki ingest skill is copied from repo templates" {
  let root = unique_test_root("/tmp/moonbook-skill-copy")
  ignore(init_workspace(root))
  let text = @fsx.read_file(root + "/skills/wiki-ingest/SKILL.md")
  let reference = @fsx.read_file(
    root + "/skills/wiki-ingest/references/raw-first-contract.md",
  )
  assert_true(text.contains("bootstrap packets live under `raw/bootstrap/`"))
  assert_true(text.contains("references/raw-first-contract.md"))
  assert_true(text.contains("Gather lane contract"))
  assert_true(reference.contains("## Non-negotiable sequence"))
}
