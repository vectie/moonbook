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
  let sources_dir = @path.Path(wiki_dir).join(@path.Path("sources")).to_string()
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
  @fsx.make_directory(sources_dir, recursive=true, exists_ok=true)

  write_if_missing(book_toml_path, book_toml_text(resolved_title))
  write_if_missing(config_path, wiki_config_text())
  write_if_missing(schema_path, schema_text())
  write_if_missing(gitignore_path, gitignore_text())
  write_if_missing(summary_path, summary_text())
  write_if_missing(home_path, home_text())
  write_if_missing(index_path, index_text())
  write_if_missing(log_path, log_text())
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
  "- [Log](./log.md)\n"
}

///|
fn home_text() -> String {
  "# Home\n\n" +
  "This workspace is an LLM-maintained wiki.\n\n" +
  "## Structure\n\n" +
  "- [Index](./index.md): content catalog of the wiki\n" +
  "- [Log](./log.md): append-only timeline of ingests, queries, and lint passes\n" +
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
  "- [Log](./log.md): activity timeline\n\n" +
  "## Entities\n\n" +
  "_None yet._\n\n" +
  "## Concepts\n\n" +
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
fn schema_text() -> String {
  "# Wiki Maintainer Instructions\n\n" +
  "This workspace is a persistent LLM-maintained wiki.\n\n" +
  "## Layers\n\n" +
  "- `raw/`: immutable source documents. Read-only unless the user explicitly asks to organize files.\n" +
  "- `wiki/`: maintained markdown knowledge base. The LLM owns updates here.\n" +
  "- `wiki/index.md`: content catalog. Update it whenever pages are added or meaningfully changed.\n" +
  "- `wiki/log.md`: append-only activity log. Add one entry per ingest, query, or lint pass.\n\n" +
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
  "3. Update `wiki/index.md`\n" +
  "4. Append a timestamped entry to `wiki/log.md`\n" +
  "5. Preserve uncertainty and note contradictions explicitly\n\n" +
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
}
