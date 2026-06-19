///|
priv struct Paths {
  root : String
  raw_dir : String
  wiki_dir : String
  summary_path : String
}

///|
fn workspace_paths(root : String) -> Paths {
  let normalized_root = @pathx.normalize(root)
  let raw_dir = moonbook_wiki_path(normalized_root)
    .join(moonbook_wiki_path("raw"))
    .to_string()
  let wiki_dir = moonbook_wiki_path(normalized_root)
    .join(moonbook_wiki_path("wiki"))
    .to_string()
  let summary_path = moonbook_wiki_path(wiki_dir)
    .join(moonbook_wiki_path("SUMMARY.md"))
    .to_string()
  { root: normalized_root, raw_dir, wiki_dir, summary_path }
}
