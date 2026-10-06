///|
// MoonBook-native state snapshot for suite and UI consumers.

///|
pub async fn generate_book_state_snapshot(root : String) -> BookStateSnapshot {
  let workspace = workspace_paths(root)
  let catalog = catalog_record(root)
  let summary = summarize_state(root)
  let health = report_health(root)
  let knowledge = generate_knowledge_bundle(root)
  {
    contract: book_state_contract(),
    book_id: summary.book_id,
    root: workspace.root,
    generated_at: current_epoch_millis_json_number(),
    catalog,
    summary,
    health,
    knowledge,
    latest_event: read_latest_executable_event(workspace.root),
    paths: book_state_paths(),
  }
}

///|
pub async fn write_book_state_snapshot(root : String) -> String {
  let workspace = workspace_paths(root)
  let snapshot = generate_book_state_snapshot(root)
  let dir = moonbook_wiki_path(workspace.root)
    .join(moonbook_wiki_path("state"))
    .to_string()
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  let path = moonbook_wiki_path(dir)
    .join(moonbook_wiki_path("state.json"))
    .to_string()
  @fsx.write_to_file(path, snapshot.to_json().stringify(indent=2), create=0o644)
  path
}

///|
pub async fn write_generated_book_state(
  root : String,
  generated_dir : String,
) -> String {
  render_generated_book_state(root, generated_dir, async fn(path, text) {
    @fsx.write_to_file(path, text, create=0o644)
  })
}

///|
async fn render_generated_book_state(
  root : String,
  generated_dir : String,
  publish : async (String, String) -> Unit,
) -> String {
  let snapshot = generate_book_state_snapshot(root)
  let path = moonbook_wiki_path(generated_dir)
    .join(moonbook_wiki_path("book-state.json"))
    .to_string()
  publish(path, snapshot.to_json().stringify(indent=2))
  path
}

///|
fn book_state_paths() -> BookStatePaths {
  {
    knowledge_manifest: "book/knowledge/manifest.json",
    generated_knowledge_bundle: "book/site/generated/knowledge-bundle.json",
    generated_graph: "book/site/generated/graph.json",
    latest_event: "events/latest.json",
    review_queue: "wiki/reviews/pending.md",
  }
}

///|
async fn read_latest_executable_event(root : String) -> ExecutableBookEvent? {
  let path = moonbook_wiki_path(root)
    .join(moonbook_wiki_path("events/latest.json"))
    .to_string()
  if !@fsx.exists(path) {
    return None
  }
  try @json.from_json(@json.parse(@fsx.read_file(path))) catch {
    _ => None
  } noraise {
    event => Some(event)
  }
}

///|
async test "book state snapshot includes knowledge bundle and latest event path" {
  let root = "/tmp/moonbook-book-state-snapshot"
  init_workspace(root) |> ignore
  let snapshot = generate_book_state_snapshot(root)
  assert_eq(snapshot.contract, "moonbook.book_state.v1")
  assert_eq(snapshot.knowledge.contract, "moonbook.knowledge_bundle.v1")
  assert_true(snapshot.generated_at > 1_000_000_000_000.0)
  assert_true(snapshot.knowledge.generated_at > 1_000_000_000_000.0)
  assert_eq(snapshot.generated_at, snapshot.generated_at.trunc())
  assert_eq(
    snapshot.knowledge.generated_at,
    snapshot.knowledge.generated_at.trunc(),
  )
  let old_json = snapshot
    .to_json()
    .stringify()
    .replace_all(
      old=snapshot.generated_at.to_json().stringify(),
      new="-236941825",
    )
    .replace_all(
      old=snapshot.knowledge.generated_at.to_json().stringify(),
      new="-236941825",
    )
  let legacy : BookStateSnapshot = @json.from_json(@json.parse(old_json))
  assert_eq(legacy.generated_at, -236941825.0)
  assert_eq(legacy.knowledge.generated_at, -236941825.0)
  assert_eq(snapshot.paths.latest_event, "events/latest.json")
  assert_true(snapshot.latest_event is None)
}
