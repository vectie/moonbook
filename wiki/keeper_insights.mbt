///|
async fn ensure_keeper_insights(root : String) -> String {
  let paths = keeper_paths(root)
  ensure_keeper_files(root)
  let path = @path.Path(paths.dir).join(@path.Path("INSIGHTS.md")).to_string()
  if !@fsx.exists(path) {
    @fsx.write_to_file(
      path,
      "# Keeper Insights\n\nSignals and suggested cleanups for Keeper-managed memory.\n\n## Signals\n\n_None yet._\n\n## Actions\n\n_None yet._\n",
      create=0o644,
    )
  }
  "keeper/INSIGHTS.md"
}

///|
async fn refresh_keeper_insights(root : String) -> String {
  let workspace = workspace_paths(root)
  let relative = ensure_keeper_insights(root)
  let absolute = @path.Path(workspace.root)
    .join(@path.Path(relative))
    .to_string()
  let snapshot = keeper_snapshot(root)
  let pending = list_pending_reviews(root)
  let evidence_count = count_evidence_entries(root)
  let low_confidence = count_low_confidence_claims(
    read_if_exists(
      @path.Path(workspace.wiki_dir)
      .join(@path.Path("synthesis/claims.md"))
      .to_string(),
    ),
  )
  let signals : Array[String] = [
    "- Active memory entries: `\{snapshot.active_memory.length()}`",
    "- User memory entries: `\{snapshot.user_memory.length()}`",
    "- Working memory entries: `\{snapshot.working_memory.length()}`",
    "- Pending reviews: `\{pending.length()}`",
    "- Evidence records: `\{evidence_count}`",
    "- Low-confidence claims: `\{low_confidence}`",
  ]
  let actions : Array[String] = []
  if snapshot.working_memory.length() >= 8 {
    actions.push(
      "- Prune `keeper/WORKING.md`; recent task memory is getting crowded.",
    )
  }
  if pending.length() > 0 {
    actions.push(
      "- Clear pending reviews before promoting more durable memory.",
    )
  }
  if low_confidence >= 3 {
    actions.push(
      "- Revisit low-confidence claims and attach stronger evidence.",
    )
  }
  if evidence_count == 0 {
    actions.push(
      "- No evidence records exist yet; persisted results are not building support history.",
    )
  }
  let content = "# Keeper Insights\n\n" +
    "Signals and suggested cleanups for Keeper-managed memory.\n\n" +
    "## Signals\n\n" +
    (if signals.is_empty() {
      "_None yet._\n"
    } else {
      signals.join("\n") + "\n"
    }) +
    "\n## Actions\n\n" +
    (if actions.is_empty() {
      "_None yet._\n"
    } else {
      actions.join("\n") + "\n"
    })
  @fsx.write_to_file(absolute, content, create=0o644)
  relative
}

///|
async fn read_if_exists(path : String) -> String {
  if @fsx.exists(path) {
    @fsx.read_file(path)
  } else {
    ""
  }
}
