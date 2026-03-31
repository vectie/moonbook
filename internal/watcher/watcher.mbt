///|
pub struct WatchOptions {
  root : String
  interval_ms : Int
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
  let states : Map[String, FileState] = {}
  for root in root_paths {
    scan_path(root, states)
  }
  states
}

///|
async fn scan_path(path : String, states : Map[String, FileState]) -> Unit {
  if !@fsx.exists(path) {
    return
  }
  let kind = @fs.kind(path, follow_symlink=false)
  match kind {
    @fs.FileKind::Directory =>
      for child in @fsx.list_directory(path) {
        scan_path(child, states)
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
  on_change : async (Array[String]) -> Unit,
) -> Unit {
  let mut previous = scan_paths(root_paths)
  println("watching for changes...")
  for ;; {
    @async.sleep(interval_ms)
    let current = scan_paths(root_paths)
    let changed = changed_paths(previous, current)
    if !changed.is_empty() {
      on_change(changed)
      previous = scan_paths(root_paths)
    } else {
      previous = current
    }
  }
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
