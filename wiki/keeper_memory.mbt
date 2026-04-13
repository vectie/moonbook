///|
priv struct KeeperPaths {
  dir : String
  memory_path : String
  user_path : String
  working_path : String
  policy_path : String
}

///|
priv struct KeeperSnapshot {
  active_memory : Array[String]
  user_memory : Array[String]
  working_memory : Array[String]
}

///|
fn keeper_paths(root : String) -> KeeperPaths {
  let normalized_root = @pathx.normalize(root)
  let dir = @path.Path(normalized_root).join(@path.Path("keeper")).to_string()
  {
    dir,
    memory_path: @path.Path(dir).join(@path.Path("MEMORY.md")).to_string(),
    user_path: @path.Path(dir).join(@path.Path("USER.md")).to_string(),
    working_path: @path.Path(dir).join(@path.Path("WORKING.md")).to_string(),
    policy_path: @path.Path(dir).join(@path.Path("POLICY.md")).to_string(),
  }
}

///|
async fn ensure_keeper_files(root : String) -> Unit {
  let paths = keeper_paths(root)
  @fsx.make_directory(paths.dir, recursive=true, exists_ok=true)
  keeper_write_if_missing(paths.memory_path, keeper_memory_text())
  keeper_write_if_missing(paths.user_path, keeper_user_text())
  keeper_write_if_missing(paths.working_path, keeper_working_text())
  keeper_write_if_missing(paths.policy_path, keeper_policy_text())
}

///|
async fn keeper_snapshot(root : String) -> KeeperSnapshot {
  let paths = keeper_paths(root)
  ensure_keeper_files(root)
  {
    active_memory: keeper_entries(@fsx.read_file(paths.memory_path)),
    user_memory: keeper_entries(@fsx.read_file(paths.user_path)),
    working_memory: keeper_entries(@fsx.read_file(paths.working_path)),
  }
}

///|
async fn keeper_sync_result(
  root : String,
  result : BookResult,
) -> Array[String] {
  let paths = keeper_paths(root)
  ensure_keeper_files(root)
  let updated : Array[String] = []

  let working_entry = keeper_result_entry(result)
  if keeper_append_entry(paths.working_path, working_entry, 18, 2400) {
    updated.push("keeper/WORKING.md")
  }

  for candidate in result.memory_candidates {
    if candidate.durable {
      continue
    }
    let path = keeper_target_path(paths, candidate)
    let relative = keeper_relative_path(path, paths)
    let entry = keeper_candidate_entry(candidate)
    if keeper_append_entry(
        path,
        entry,
        keeper_entry_limit(path, paths),
        keeper_char_limit(path, paths),
      ) {
      if !updated.contains(relative) {
        updated.push(relative)
      }
    }
  }
  updated
}

///|
async fn keeper_capture_query_insight(
  root : String,
  question : String,
  insight : String,
) -> String {
  let paths = keeper_paths(root)
  ensure_keeper_files(root)
  ignore(
    keeper_append_entry(
      paths.memory_path,
      "- Query insight | \{question}: \{keeper_compact_text(insight)}",
      12,
      1800,
    ),
  )
  "keeper/MEMORY.md"
}

///|
fn keeper_target_path(
  paths : KeeperPaths,
  candidate : MemoryCandidate,
) -> String {
  let kind = candidate.kind.to_lower()
  if kind.contains("user") ||
    kind.contains("preference") ||
    kind.contains("style") ||
    kind.contains("profile") ||
    kind.contains("workflow") {
    paths.user_path
  } else if kind.contains("task") ||
    kind.contains("follow") ||
    kind.contains("todo") ||
    kind.contains("observation") {
    paths.working_path
  } else {
    paths.memory_path
  }
}

///|
fn keeper_relative_path(path : String, paths : KeeperPaths) -> String {
  if path == paths.user_path {
    "keeper/USER.md"
  } else if path == paths.working_path {
    "keeper/WORKING.md"
  } else {
    "keeper/MEMORY.md"
  }
}

///|
fn keeper_entry_limit(path : String, paths : KeeperPaths) -> Int {
  if path == paths.user_path {
    10
  } else if path == paths.working_path {
    18
  } else {
    12
  }
}

///|
fn keeper_char_limit(path : String, paths : KeeperPaths) -> Int {
  if path == paths.user_path {
    1400
  } else if path == paths.working_path {
    2400
  } else {
    1800
  }
}

///|
fn keeper_result_entry(result : BookResult) -> String {
  "- \{result.task_id}: \{keeper_compact_text(result.summary)}"
}

///|
fn keeper_candidate_entry(candidate : MemoryCandidate) -> String {
  "- \{candidate.title}: \{keeper_compact_text(candidate.detail)}"
}

///|
async fn keeper_append_entry(
  path : String,
  entry : String,
  max_entries : Int,
  max_chars : Int,
) -> Bool {
  let current = if @fsx.exists(path) { @fsx.read_file(path) } else { "" }
  let next_entries = keeper_bounded_entries(
    keeper_entries(current),
    entry,
    max_entries,
    max_chars,
    keeper_title_for_path(path),
    keeper_description_for_path(path),
  )
  let next = render_keeper_file(
    keeper_title_for_path(path),
    keeper_description_for_path(path),
    next_entries,
  )
  if current == next {
    false
  } else {
    @fsx.write_to_file(path, next, create=0o644)
    true
  }
}

///|
fn keeper_bounded_entries(
  entries : Array[String],
  new_entry : String,
  max_entries : Int,
  max_chars : Int,
  title : String,
  description : String,
) -> Array[String] {
  let next : Array[String] = []
  for entry in entries {
    if entry != new_entry {
      next.push(entry)
    }
  }
  next.push(new_entry)
  while next.length() > max_entries {
    trim_first_entry(next)
  }
  while next.length() > 1 &&
        render_keeper_file(title, description, next).length() > max_chars {
    trim_first_entry(next)
  }
  next
}

///|
fn trim_first_entry(entries : Array[String]) -> Unit {
  if entries.is_empty() {
    return
  }
  let rest : Array[String] = []
  for i = 1; i < entries.length(); i = i + 1 {
    rest.push(entries[i])
  }
  entries.clear()
  for entry in rest {
    entries.push(entry)
  }
}

///|
fn keeper_entries(content : String) -> Array[String] {
  let entries : Array[String] = []
  for raw in content.split("\n") {
    let line = raw.trim().to_string()
    if line.has_prefix("- ") {
      entries.push(line)
    }
  }
  entries
}

///|
fn render_keeper_file(
  title : String,
  description : String,
  entries : Array[String],
) -> String {
  let builder = StringBuilder::new()
  builder.write_string("# \{title}\n\n")
  builder.write_string("\{description}\n\n")
  builder.write_string("## Entries\n\n")
  if entries.is_empty() {
    builder.write_string("_None yet._\n")
  } else {
    for entry in entries {
      builder.write_string("\{entry}\n")
    }
  }
  builder.to_string()
}

///|
async fn keeper_write_if_missing(path : String, content : String) -> Unit {
  if !@fsx.exists(path) {
    @fsx.write_to_file(path, content, create=0o644)
  }
}

///|
fn keeper_title_for_path(path : String) -> String {
  if path.has_suffix("/USER.md") {
    "Keeper User"
  } else if path.has_suffix("/WORKING.md") {
    "Keeper Working Memory"
  } else if path.has_suffix("/POLICY.md") {
    "Keeper Policy"
  } else {
    "Keeper Memory"
  }
}

///|
fn keeper_description_for_path(path : String) -> String {
  if path.has_suffix("/USER.md") {
    "Stable user preferences, collaboration habits, and communication constraints."
  } else if path.has_suffix("/WORKING.md") {
    "Short-lived active notes for current tasks, follow-ups, and recent observations."
  } else if path.has_suffix("/POLICY.md") {
    "Admission, pruning, and promotion rules for Keeper-managed memory."
  } else {
    "High-signal reusable domain memory for this book. Keep it concise and rewriteable."
  }
}

///|
fn keeper_memory_text() -> String {
  render_keeper_file(
    "Keeper Memory",
    "High-signal reusable domain memory for this book. Keep it concise and rewriteable.",
    [],
  )
}

///|
fn keeper_user_text() -> String {
  render_keeper_file(
    "Keeper User",
    "Stable user preferences, collaboration habits, and communication constraints.",
    [],
  )
}

///|
fn keeper_working_text() -> String {
  render_keeper_file(
    "Keeper Working Memory",
    "Short-lived active notes for current tasks, follow-ups, and recent observations.",
    [],
  )
}

///|
fn keeper_policy_text() -> String {
  "# Keeper Policy\n\n" +
  "## Principles\n\n" +
  "- Keep active memory small and rewriteable.\n" +
  "- Promote only reviewed durable knowledge into the wiki.\n" +
  "- Prefer replacing stale memory over appending endlessly.\n" +
  "- Use working memory for recent observations and short-lived task context.\n"
}

///|
fn keeper_compact_text(text : String) -> String {
  let normalized = text
    .replace(old="\n", new=" ")
    .replace(old="\r", new=" ")
    .trim()
    .to_string()
  if normalized.length() > 180 {
    normalized[:180].to_string() + "..."
  } else {
    normalized
  }
}

///|
test "keeper bounded entries dedupe and cap" {
  let entries = keeper_bounded_entries(
    ["- alpha", "- beta", "- alpha"],
    "- gamma",
    3,
    500,
    "Keeper Memory",
    "desc",
  )
  assert_eq(entries, ["- beta", "- alpha", "- gamma"])
}

///|
test "keeper candidate kind routes user memory" {
  let paths = keeper_paths("/tmp/keeper-kind")
  let path = keeper_target_path(paths, {
    kind: "user_preference",
    title: "Prefers concise output",
    detail: "Use shorter responses.",
    durable: false,
    target_page: None,
  })
  assert_eq(path, paths.user_path)
}
