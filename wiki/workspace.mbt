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
  let raw_dir = @path.Path(normalized_root).join(@path.Path("raw")).to_string()
  let wiki_dir = @path.Path(normalized_root)
    .join(@path.Path("wiki"))
    .to_string()
  let summary_path = @path.Path(wiki_dir)
    .join(@path.Path("SUMMARY.md"))
    .to_string()
  { root: normalized_root, raw_dir, wiki_dir, summary_path }
}
