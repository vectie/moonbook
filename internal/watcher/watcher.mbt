///|
pub struct WatchOptions {
  root : String
  interval_ms : Int
} derive(Show, ToJson)

///|
pub struct WatchFilter {
  root : String
  patterns : Array[String]
} derive(Show, ToJson)

///|
pub struct FileState {
  path : String
  kind : String
  mtime : Int64
} derive(Show, ToJson, Eq, Compare)

///|
pub fn parse_watch_args(args : Array[String]) -> WatchOptions? {
  match args {
    [root] => Some({ root, interval_ms: 1000 })
    [] => Some({ root: ".", interval_ms: 1000 })
    _ => None
  }
}

///|
pub async fn scan_paths(root_paths : Array[String]) -> Map[String, FileState] {
  scan_paths_filtered(root_paths, None)
}

///|
pub async fn scan_paths_filtered(
  root_paths : Array[String],
  filter : WatchFilter?,
) -> Map[String, FileState] {
  let states : Map[String, FileState] = {}
  for root in root_paths {
    scan_path(root, states, filter)
  }
  states
}

///|
async fn scan_path(
  path : String,
  states : Map[String, FileState],
  filter : WatchFilter?,
) -> Unit {
  if !@fsx.exists(path) {
    return
  }
  if is_ignored_path(path, filter) {
    return
  }
  let kind = @fs.kind(path, follow_symlink=false)
  match kind {
    @fs.FileKind::Directory =>
      for child in @fsx.list_directory(path) {
        scan_path(child, states, filter)
      }
    _ => {
      let mtime = @fsx.mtime(path).unwrap_or(0L)
      states[path] = { path, kind: file_kind_name(kind), mtime }
    }
  }
}

///|
pub fn changed_paths(
  previous : Map[String, FileState],
  current : Map[String, FileState],
) -> Array[String] {
  let paths : Array[String] = []
  for path in current.keys() {
    match previous.get(path) {
      Some(old_state) => if old_state != current[path] { paths.push(path) }
      None => paths.push(path)
    }
  }
  for path in previous.keys() {
    if !current.contains(path) {
      paths.push(path)
    }
  }
  paths.sort()
  paths
}

///|
pub async fn rebuild_on_change(
  root_paths : Array[String],
  interval_ms? : Int = 1000,
  filter? : WatchFilter? = None,
  on_change : async (Array[String]) -> Unit,
) -> Unit {
  let mut previous = scan_paths_filtered(root_paths, filter)
  println("watching for changes...")
  for ;; {
    @async.sleep(interval_ms)
    let current = scan_paths_filtered(root_paths, filter)
    let changed = changed_paths(previous, current)
    if !changed.is_empty() {
      on_change(changed)
      previous = scan_paths_filtered(root_paths, filter)
    } else {
      previous = current
    }
  }
}

///|
pub async fn load_watch_filter(book_root : String) -> WatchFilter? {
  let gitignore_path = @pathx.join(book_root, ".gitignore")
  if !@fsx.exists(gitignore_path) {
    return None
  }
  let patterns = parse_gitignore_patterns(@fsx.read_file(gitignore_path))
  if patterns.is_empty() {
    None
  } else {
    Some({ root: @pathx.normalize(book_root), patterns })
  }
}

///|
fn parse_gitignore_patterns(contents : String) -> Array[String] {
  let patterns : Array[String] = []
  for raw_line in contents.split("\n") {
    let trimmed = raw_line.to_string().trim().to_string()
    if trimmed.is_empty() || trimmed.has_prefix("#") {
      continue
    }
    patterns.push(trimmed)
  }
  patterns
}

///|
fn is_ignored_path(path : String, filter : WatchFilter?) -> Bool {
  match filter {
    Some(filter) => {
      let normalized_path = @pathx.normalize(path)
      let root = filter.root
      let relative = if normalized_path == root {
        "."
      } else if normalized_path.has_prefix(root + "/") {
        normalized_path[root.length() + 1:].to_string()
      } else {
        return false
      }
      if relative == ".gitignore" {
        return false
      }
      for pattern in filter.patterns {
        if gitignore_matches(pattern, relative) {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn gitignore_matches(pattern : String, relative_path : String) -> Bool {
  let anchored = pattern.has_prefix("/")
  let normalized_pattern = normalize_gitignore_pattern(pattern)
  if normalized_pattern.is_empty() {
    return false
  }
  if pattern.has_suffix("/") {
    return relative_path == normalized_pattern ||
      relative_path.has_prefix(normalized_pattern + "/")
  }
  let path_targets = if anchored || normalized_pattern.contains("/") {
    [relative_path]
  } else {
    basename_candidates(relative_path)
  }
  for target in path_targets {
    if glob_matches(normalized_pattern, target) {
      return true
    }
  }
  false
}

///|
fn normalize_gitignore_pattern(pattern : String) -> String {
  let trimmed = pattern.trim().to_string()
  let trimmed = if trimmed.has_prefix("/") {
    trimmed[1:].to_string()
  } else {
    trimmed
  }
  if trimmed.has_suffix("/") {
    trimmed[:trimmed.length() - 1].to_string()
  } else {
    trimmed
  }
}

///|
fn basename_candidates(path : String) -> Array[String] {
  let candidates : Array[String] = [path]
  match path.rev_find("/") {
    Some(index) => candidates.push(path[index + 1:].to_string())
    None => ()
  }
  candidates
}

///|
fn glob_matches(pattern : String, text : String) -> Bool {
  glob_matches_from(pattern, 0, text, 0)
}

///|
fn glob_matches_from(
  pattern : String,
  pattern_index : Int,
  text : String,
  text_index : Int,
) -> Bool {
  if pattern_index >= pattern.length() {
    return text_index >= text.length()
  }
  let token = pattern[pattern_index]
  if token == '*' {
    let mut next = text_index
    while next <= text.length() {
      if glob_matches_from(pattern, pattern_index + 1, text, next) {
        return true
      }
      next += 1
    }
    return false
  }
  if text_index >= text.length() {
    return false
  }
  if token == '?' || token == text[text_index] {
    return glob_matches_from(pattern, pattern_index + 1, text, text_index + 1)
  }
  false
}

///|
fn file_kind_name(kind : @fs.FileKind) -> String {
  match kind {
    @fs.FileKind::Unknown => "unknown"
    @fs.FileKind::Regular => "regular"
    @fs.FileKind::Directory => "directory"
    @fs.FileKind::SymLink => "symlink"
    @fs.FileKind::Socket => "socket"
    @fs.FileKind::Pipe => "pipe"
    @fs.FileKind::BlockDevice => "block-device"
    @fs.FileKind::CharDevice => "char-device"
  }
}

///|
test "parse watch args supports optional root" {
  assert_eq(parse_watch_args([]).unwrap().root, ".")
  assert_eq(parse_watch_args(["/tmp/book"]).unwrap().root, "/tmp/book")
  assert_true(parse_watch_args(["a", "b"]) is None)
}

///|
test "changed paths detects adds removes and updates" {
  let previous : Map[String, FileState] = {
    "a.md": { path: "a.md", kind: "regular", mtime: 1L },
    "b.md": { path: "b.md", kind: "regular", mtime: 1L },
  }
  let current : Map[String, FileState] = {
    "a.md": { path: "a.md", kind: "regular", mtime: 2L },
    "c.md": { path: "c.md", kind: "regular", mtime: 1L },
  }
  assert_eq(changed_paths(previous, current), ["a.md", "b.md", "c.md"])
}

///|
test "parse gitignore patterns skips comments and blanks" {
  assert_eq(parse_gitignore_patterns("# comment\n\nbook/\n*.tmp\n"), [
    "book/", "*.tmp",
  ])
}

///|
test "gitignore matching handles directories files and globs" {
  assert_true(gitignore_matches("book/", "book/index.html"))
  assert_true(gitignore_matches("*.tmp", "scratch.tmp"))
  assert_true(gitignore_matches("*.tmp", "notes/scratch.tmp"))
  assert_true(gitignore_matches("/src/*.md", "src/chapter.md"))
  assert_false(gitignore_matches("/src/*.md", "nested/src/chapter.md"))
  assert_false(gitignore_matches("book/", "src/book.md"))
}

///|
test "ignored path uses root relative matching but keeps gitignore visible" {
  let filter : WatchFilter = { root: "/tmp/book", patterns: ["book/", "*.tmp"] }
  assert_true(is_ignored_path("/tmp/book/book/index.html", Some(filter)))
  assert_true(is_ignored_path("/tmp/book/src/note.tmp", Some(filter)))
  assert_false(is_ignored_path("/tmp/book/.gitignore", Some(filter)))
  assert_false(is_ignored_path("/tmp/book/src/chapter.md", Some(filter)))
}
