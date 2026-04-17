///|
pub struct SkillHubServeOptions {
  root : String
  hostname : String
  port : Int
  open_browser : Bool
} derive(Show, ToJson)

///|
pub fn make_skill_hub_serve_options(
  root : String,
  hostname : String,
  port : Int,
  open_browser : Bool,
) -> SkillHubServeOptions {
  { root, hostname, port, open_browser }
}

///|
struct SkillHubRecord {
  id : String
  name : String
  path : String
  category : String
  origin : String
  description : String
  line_count : Int
  mut duplicate : Bool
  content : String
  snapshot_count : Int
  mtime : Int64
} derive(Show, ToJson, FromJson)

///|
struct SkillHubRootStatus {
  path : String
  category : String
  exists : Bool
  hit_count : Int
} derive(Show, ToJson, FromJson)

///|
struct SkillHubState {
  title : String
  root : String
  home : String
  cwd : String
  skill_count : Int
  duplicate_names : Array[String]
  roots : Array[SkillHubRootStatus]
  skills : Array[SkillHubRecord]
  generated_at : Int
} derive(Show, ToJson, FromJson)

///|
struct SkillHubDebug {
  root : String
  home : String
  cwd : String
  extra_paths : Array[String]
  roots : Array[SkillHubRootStatus]
  watch_roots : Array[String]
  ignored_patterns : Array[String]
  errors : Array[String]
  duration_ms : Int
  generated_at : Int
} derive(Show, ToJson, FromJson)

///|
struct SkillSnapshotRecord {
  id : String
  path : String
  created_at : Int
  summary : String
  content_path : String
} derive(Show, ToJson, FromJson)

///|
struct SkillHubSaveRequest {
  path : String
  content : String
  summary : String?
} derive(FromJson)

///|
struct SkillHubRollbackRequest {
  path : String
  snapshot_id : String
} derive(FromJson)

///|
pub async fn serve_skill_hub(options : SkillHubServeOptions) -> Unit {
  let root = @pathx.normalize(options.root)
  let state_dir = skill_hub_state_dir(root)
  ensure_skill_hub_dirs(root)
  refresh_skill_hub_state(root)
  let server = @http.Server::new(
    @socket.Addr::parse(
      "\{skill_hub_bind_host(options.hostname)}:\{options.port}",
    ),
  ) catch {
    error => fail("moonbook skill hub failed: \{error}")
  }
  let serving_url = "http://\{options.hostname}:\{server.addr().port()}"
  println("skill hub state: \{state_dir}")
  println("skill hub listening on \{serving_url}")
  @async.with_task_group(group => {
    if options.open_browser {
      group.spawn_bg(
        () => open_skill_hub_browser(serving_url),
        no_wait=true,
        allow_failure=true,
      )
    }
    group.spawn_bg(
      () => watch_skill_hub(root),
      no_wait=true,
      allow_failure=true,
    )
    server.run_forever(
      (request, body, conn) => {
        handle_skill_hub_request(root, request, body, conn)
      },
      allow_failure=true,
    )
  })
}

///|
async fn handle_skill_hub_request(
  root : String,
  request : @http.Request,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  let path = request.path
  match (request.meth, strip_query(path)) {
    (@http.RequestMethod::Get, "/") => send_html(conn, skill_hub_html())
    (@http.RequestMethod::Get, "/app.js") =>
      send_javascript(conn, skill_hub_script())
    (@http.RequestMethod::Get, "/styles.css") =>
      send_css(conn, skill_hub_styles())
    (@http.RequestMethod::Get, "/api/state") =>
      send_json(conn, read_skill_hub_state(root).to_json().stringify(indent=2))
    (@http.RequestMethod::Get, "/api/debug") =>
      send_json(conn, read_skill_hub_debug(root).to_json().stringify(indent=2))
    (@http.RequestMethod::Get, "/api/snapshots") => {
      let path = decode_query_value(
        query_value(request.path, "path").unwrap_or(""),
      )
      send_json(
        conn,
        list_skill_snapshots(root, path).to_json().stringify(indent=2),
      )
    }
    (@http.RequestMethod::Get, "/api/events") =>
      send_skill_hub_events(conn, root)
    (@http.RequestMethod::Post, "/api/save") => {
      let payload : SkillHubSaveRequest = parse_skill_hub_json(body)
      save_skill_hub_content(root, payload)
      refresh_skill_hub_state(root)
      send_json(conn, "{\"ok\":true}")
    }
    (@http.RequestMethod::Post, "/api/rollback") => {
      let payload : SkillHubRollbackRequest = parse_skill_hub_json(body)
      rollback_skill_hub_snapshot(root, payload.path, payload.snapshot_id)
      refresh_skill_hub_state(root)
      send_json(conn, "{\"ok\":true}")
    }
    _ => send_text(conn, 404, "Not Found", "Not Found\n")
  }
}

///|
async fn refresh_skill_hub_state(root : String) -> Unit {
  let started = @async.now().to_int()
  ensure_skill_hub_dirs(root)
  let scan = collect_skill_hub_scan(root)
  let roots = scan.0
  let skills = scan.1
  let errors = scan.2
  let duplicates = duplicate_skill_names(
    skills.map(fn(skill) {
      {
        id: skill.id,
        name: skill.name,
        path: skill.path,
        scope: skill.category,
        origin: skill.origin,
        source_kind: "hub",
        extension: None,
        description: skill.description,
        references: [],
        overrides: [],
        shadowed_by: [],
        line_count: skill.line_count,
      }
    }),
  )
  let state : SkillHubState = {
    title: "MoonBook Skill Hub",
    root,
    home: skill_hub_home_dir(),
    cwd: @env.current_dir().unwrap_or(root),
    skill_count: skills.length(),
    duplicate_names: duplicates,
    roots,
    skills,
    generated_at: @async.now().to_int(),
  }
  let debug : SkillHubDebug = {
    root,
    home: skill_hub_home_dir(),
    cwd: @env.current_dir().unwrap_or(root),
    extra_paths: skill_hub_extra_paths(),
    roots,
    watch_roots: skill_hub_watch_roots(roots, skills),
    ignored_patterns: [
      ".git", "node_modules", "_build", "book", ".moonbook-skill-hub",
    ],
    errors,
    duration_ms: @async.now().to_int() - started,
    generated_at: @async.now().to_int(),
  }
  @fsx.write_to_file(
    skill_hub_state_path(root),
    state.to_json().stringify(indent=2),
    create=0o644,
  )
  @fsx.write_to_file(
    skill_hub_debug_path(root),
    debug.to_json().stringify(indent=2),
    create=0o644,
  )
  @fsx.write_to_file(
    skill_hub_version_path(root),
    state.generated_at.to_string(),
    create=0o644,
  )
}

///|
async fn collect_skill_hub_scan(
  root : String,
) -> (Array[SkillHubRootStatus], Array[SkillHubRecord], Array[String]) {
  let statuses : Array[SkillHubRootStatus] = []
  let records : Array[SkillHubRecord] = []
  let errors : Array[String] = []
  let seen_dirs : Array[String] = []
  for candidate in skill_hub_scan_roots(root) {
    if seen_dirs.contains(candidate.path) {
      continue
    }
    seen_dirs.push(candidate.path)
    let exists = @fsx.exists(candidate.path)
    let before = records.length()
    if exists {
      collect_skill_hub_records_from_root(
        root,
        candidate.path,
        candidate.category,
        records,
        errors,
      )
    }
    statuses.push({
      path: candidate.path,
      category: candidate.category,
      exists,
      hit_count: records.length() - before,
    })
  }
  mark_skill_hub_duplicates(records)
  records.sort_by(fn(left, right) {
    (left.name + "|" + left.category + "|" + left.path).compare(
      right.name + "|" + right.category + "|" + right.path,
    )
  })
  (statuses, records, errors)
}

///|
priv struct SkillHubScanRoot {
  path : String
  category : String
}

///|
fn skill_hub_scan_roots(root : String) -> Array[SkillHubScanRoot] {
  let home = skill_hub_home_dir()
  let cwd = @env.current_dir().unwrap_or(root)
  let roots : Array[SkillHubScanRoot] = []
  roots.push({
    path: @path.Path(root).join(@path.Path("skills")).to_string(),
    category: "workspace",
  })
  roots.push({
    path: @path.Path(root).join(@path.Path("seed/wiki/skills")).to_string(),
    category: "repo-seed",
  })
  roots.push({
    path: @path.Path(home).join(@path.Path(".claude/skills")).to_string(),
    category: "claude-global",
  })
  roots.push({
    path: @path.Path(home).join(@path.Path(".claude/plugins")).to_string(),
    category: "claude-plugins",
  })
  roots.push({
    path: @path.Path(home).join(@path.Path(".claude/projects")).to_string(),
    category: "claude-projects",
  })
  for
    dir in [
      "Documents", "Projects", "Developer", "Code", "code", "workspace", "dev", "work",
      "repos", "src",
    ] {
    roots.push({
      path: @path.Path(home).join(@path.Path(dir)).to_string(),
      category: "common-dev",
    })
  }
  let mut current = cwd
  let mut depth = 0
  while depth < 4 {
    roots.push({
      path: @path.Path(current).join(@path.Path("skills")).to_string(),
      category: "cwd-skills",
    })
    roots.push({
      path: @path.Path(current).join(@path.Path(".claude/skills")).to_string(),
      category: "cwd-claude",
    })
    let parent = @pathx.dirname(current).to_string()
    if parent == current {
      break
    }
    current = parent
    depth += 1
  }
  for extra in skill_hub_extra_paths() {
    roots.push({ path: extra, category: "extra" })
  }
  roots
}

///|
fn skill_hub_extra_paths() -> Array[String] {
  let values = []
  for key in ["MOONBOOK_SKILL_HUB_EXTRA_PATHS", "SKILL_HUB_EXTRA_PATHS"] {
    match @sys.get_env_var(key) {
      Some(text) =>
        for piece in text.replace(old=",", new=":").split(":") {
          let path = piece.to_string().trim().to_string()
          if !path.is_empty() && !values.contains(path) {
            values.push(path)
          }
        }
      None => ()
    }
  }
  values
}

///|
fn skill_hub_home_dir() -> String {
  @sys.get_env_var("HOME").unwrap_or(@env.current_dir().unwrap_or("."))
}

///|
async fn collect_skill_hub_records_from_root(
  root : String,
  path : String,
  category : String,
  records : Array[SkillHubRecord],
  errors : Array[String],
) -> Unit {
  if !@fsx.exists(path) {
    return
  }
  let kind = @fs.kind(path, follow_symlink=false) catch {
    error => {
      errors.push("\{path}: \{error}")
      return
    }
  }
  match kind {
    @fs.FileKind::Directory => {
      let base = @path.Path(path).basename().to_string()
      if base == "skills" {
        for child in @fsx.list_directory(path) {
          let child_kind = @fs.kind(child, follow_symlink=false) catch {
            _ => continue
          }
          let skill_path = match child_kind {
            @fs.FileKind::Directory =>
              @path.Path(child).join(@path.Path("SKILL.md")).to_string()
            _ =>
              if @path.Path(child).basename().to_string() == "SKILL.md" {
                child
              } else {
                continue
              }
          }
          if !@fsx.exists(skill_path) {
            continue
          }
          let text = @fsx.read_file(skill_path)
          let (name, description) = parse_skill_metadata(child, text)
          let snapshots = list_skill_snapshots(root, skill_path)
          records.push({
            id: skill_hub_record_id(skill_path),
            name,
            path: skill_path,
            category,
            origin: path,
            description,
            line_count: count_lines(text),
            duplicate: false,
            content: text,
            snapshot_count: snapshots.length(),
            mtime: @fsx.mtime(skill_path).unwrap_or(0L),
          })
        }
        return
      }
      if should_descend_skill_hub_dir(path) {
        for child in @fsx.list_directory(path) {
          collect_skill_hub_records_from_root(
            root, child, category, records, errors,
          )
        }
      }
    }
    _ => ()
  }
}

///|
fn should_descend_skill_hub_dir(path : String) -> Bool {
  let base = @path.Path(path).basename().to_string()
  ![
    ".git", "node_modules", "_build", "book", ".moonbook-skill-hub", ".DS_Store",
  ].contains(base)
}

///|
fn mark_skill_hub_duplicates(records : Array[SkillHubRecord]) -> Unit {
  for record in records {
    let count = records.filter(fn(other) { other.name == record.name }).length()
    if count > 1 {
      record.duplicate = true
    }
  }
}

///|
fn skill_hub_record_id(path : String) -> String {
  skill_slug(path)
}

///|
fn skill_hub_state_dir(root : String) -> String {
  @path.Path(root).join(@path.Path(".moonbook-skill-hub")).to_string()
}

///|
fn skill_hub_state_path(root : String) -> String {
  @path.Path(skill_hub_state_dir(root))
  .join(@path.Path("state.json"))
  .to_string()
}

///|
fn skill_hub_debug_path(root : String) -> String {
  @path.Path(skill_hub_state_dir(root))
  .join(@path.Path("debug.json"))
  .to_string()
}

///|
fn skill_hub_version_path(root : String) -> String {
  @path.Path(skill_hub_state_dir(root)).join(@path.Path("version")).to_string()
}

///|
fn skill_hub_snapshot_root(root : String) -> String {
  @path.Path(skill_hub_state_dir(root))
  .join(@path.Path("snapshots"))
  .to_string()
}

///|
async fn ensure_skill_hub_dirs(root : String) -> Unit {
  @fsx.make_directory(skill_hub_state_dir(root), recursive=true, exists_ok=true)
  @fsx.make_directory(
    skill_hub_snapshot_root(root),
    recursive=true,
    exists_ok=true,
  )
}

///|
async fn read_skill_hub_state(root : String) -> SkillHubState {
  let path = skill_hub_state_path(root)
  let json = @json.parse(@fsx.read_file(path)) catch {
    _ => fail("missing skill hub state")
  }
  @json.from_json(json) catch {
    _ => fail("invalid skill hub state")
  }
}

///|
async fn read_skill_hub_debug(root : String) -> SkillHubDebug {
  let path = skill_hub_debug_path(root)
  let json = @json.parse(@fsx.read_file(path)) catch {
    _ => fail("missing skill hub debug")
  }
  @json.from_json(json) catch {
    _ => fail("invalid skill hub debug")
  }
}

///|
async fn save_skill_hub_content(
  root : String,
  payload : SkillHubSaveRequest,
) -> Unit {
  let summary = payload.summary.unwrap_or("browser save")
  ignore(create_skill_snapshot(root, payload.path, summary))
  @fsx.write_to_file(payload.path, payload.content, create=0o644)
}

///|
async fn list_skill_snapshots(
  root : String,
  path : String,
) -> Array[SkillSnapshotRecord] {
  let dir = @path.Path(skill_hub_snapshot_root(root))
    .join(@path.Path(skill_hub_record_id(path)))
    .to_string()
  if !@fsx.exists(dir) {
    return []
  }
  let items : Array[SkillSnapshotRecord] = []
  for child in @fsx.list_directory(dir) {
    let manifest = @path.Path(child)
      .join(@path.Path("snapshot.json"))
      .to_string()
    if @fsx.exists(manifest) {
      let json = @json.parse(@fsx.read_file(manifest)) catch { _ => continue }
      items.push(@json.from_json(json) catch { _ => continue })
    }
  }
  items.sort_by(fn(left, right) { right.created_at.compare(left.created_at) })
  items
}

///|
async fn create_skill_snapshot(
  root : String,
  path : String,
  summary : String,
) -> SkillSnapshotRecord {
  let id = @async.now().to_int().to_string()
  let dir = @path.Path(skill_hub_snapshot_root(root))
    .join(@path.Path(skill_hub_record_id(path)))
    .join(@path.Path(id))
    .to_string()
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  let content_path = @path.Path(dir).join(@path.Path("SKILL.md")).to_string()
  let manifest_path = @path.Path(dir)
    .join(@path.Path("snapshot.json"))
    .to_string()
  @fsx.write_to_file(content_path, @fsx.read_file(path), create=0o644)
  let record : SkillSnapshotRecord = {
    id,
    path,
    created_at: @async.now().to_int(),
    summary,
    content_path,
  }
  @fsx.write_to_file(
    manifest_path,
    record.to_json().stringify(indent=2),
    create=0o644,
  )
  record
}

///|
async fn rollback_skill_hub_snapshot(
  root : String,
  path : String,
  snapshot_id : String,
) -> Unit {
  ignore(create_skill_snapshot(root, path, "pre-rollback"))
  let snapshots = list_skill_snapshots(root, path)
  for snapshot in snapshots {
    if snapshot.id == snapshot_id {
      @fsx.write_to_file(
        path,
        @fsx.read_file(snapshot.content_path),
        create=0o644,
      )
      return
    }
  }
  fail("snapshot not found: \{snapshot_id}")
}

///|
async fn watch_skill_hub(root : String) -> Unit {
  let scan = collect_skill_hub_scan(root)
  let watch_roots = skill_hub_watch_roots(scan.0, scan.1)
  if watch_roots.is_empty() {
    return
  }
  @watcher.rebuild_on_change(watch_roots, interval_ms=1200, async fn(
    _changed : Array[String],
  ) {
    refresh_skill_hub_state(root)
  })
}

///|
async fn send_skill_hub_events(
  conn : @http.ServerConnection,
  root : String,
) -> Unit {
  conn.send_response(200, "OK", extra_headers={
    "content-type": "text/event-stream; charset=utf-8",
    "cache-control": "no-store, no-cache, must-revalidate",
    "connection": "keep-alive",
    "x-accel-buffering": "no",
  })
  let mut token = read_skill_hub_token(root)
  conn.write("retry: 1000\n")
  conn.write("event: ready\ndata: \{token}\n\n")
  let mut ticks = 0
  while true {
    @async.sleep(1000)
    let next = read_skill_hub_token(root)
    if next != token {
      token = next
      conn.write("event: refresh\ndata: \{token}\n\n")
      ticks = 0
    } else if ticks >= 14 {
      conn.write(": keepalive\n\n")
      ticks = 0
    } else {
      ticks += 1
    }
  }
}

///|
async fn read_skill_hub_token(root : String) -> String {
  let path = skill_hub_version_path(root)
  if @fsx.exists(path) {
    @fsx.read_file(path)
  } else {
    "0"
  }
}

///|
async fn[T : @json.FromJson] parse_skill_hub_json(body : &@io.Reader) -> T {
  let text = body.read_all().text()
  let json = @json.parse(text) catch {
    error => fail("invalid json request body: \{error}")
  }
  @json.from_json(json) catch {
    error => fail("invalid request body: \{error}")
  }
}

///|
fn strip_query(path : String) -> String {
  match path.find("?") {
    Some(index) => path[:index].to_string()
    None => path
  }
}

///|
fn query_value(path : String, key : String) -> String? {
  match path.find("?") {
    Some(index) => {
      for piece in path[index + 1:].split("&") {
        let entry = piece.to_string()
        match entry.find("=") {
          Some(split) =>
            if entry[:split] == key {
              return Some(entry[split + 1:].to_string())
            }
          None => ()
        }
      }
      None
    }
    None => None
  }
}

///|
fn decode_query_value(text : String) -> String {
  text
  .replace(old="%2F", new="/")
  .replace(old="%2E", new=".")
  .replace(old="%3A", new=":")
  .replace(old="%20", new=" ")
  .to_string()
}

///|
async fn send_json(conn : @http.ServerConnection, body : String) -> Unit {
  conn.send_response(200, "OK", extra_headers={
    "content-type": "application/json; charset=utf-8",
  })
  conn.write(body)
  conn.end_response()
}

///|
async fn send_html(conn : @http.ServerConnection, body : String) -> Unit {
  conn.send_response(200, "OK", extra_headers={
    "content-type": "text/html; charset=utf-8",
  })
  conn.write(body)
  conn.end_response()
}

///|
async fn send_css(conn : @http.ServerConnection, body : String) -> Unit {
  conn.send_response(200, "OK", extra_headers={
    "content-type": "text/css; charset=utf-8",
  })
  conn.write(body)
  conn.end_response()
}

///|
async fn send_javascript(conn : @http.ServerConnection, body : String) -> Unit {
  conn.send_response(200, "OK", extra_headers={
    "content-type": "application/javascript",
  })
  conn.write(body)
  conn.end_response()
}

///|
async fn send_text(
  conn : @http.ServerConnection,
  code : Int,
  reason : String,
  body : String,
) -> Unit {
  conn.send_response(code, reason, extra_headers={
    "content-type": "text/plain; charset=utf-8",
  })
  conn.write(body)
  conn.end_response()
}

///|
fn skill_hub_bind_host(host : String) -> String {
  if host == "localhost" {
    "127.0.0.1"
  } else {
    host
  }
}

///|
async fn open_skill_hub_browser(url : String) -> Unit {
  let mac = @process.run("open", [url]) catch { _ => -1 }
  if mac == 0 {
    return
  }
  ignore(@process.run("xdg-open", [url]) catch { _ => -1 })
}

///|
fn skill_hub_html() -> String {
  "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>MoonBook Skill Hub</title><link rel=\"stylesheet\" href=\"/styles.css\"></head><body><header class=\"topbar\"><div><h1>MoonBook Skill Hub</h1><p>Manage skills across this machine: scan, edit, snapshot, rollback, and debug.</p></div><div class=\"actions\"><button id=\"refresh-btn\">Refresh</button><a href=\"/api/debug\" target=\"_blank\">Debug JSON</a></div></header><main class=\"layout\"><aside class=\"sidebar\"><input id=\"search\" type=\"search\" placeholder=\"Search skills\"><div id=\"skill-list\"></div></aside><section class=\"detail\"><div class=\"detail-meta\"><strong id=\"detail-name\">Select a skill</strong><span id=\"detail-path\"></span></div><div class=\"detail-row\"><span id=\"detail-category\"></span><span id=\"detail-origin\"></span><span id=\"detail-snapshots\"></span></div><textarea id=\"editor\" spellcheck=\"false\"></textarea><div class=\"editor-actions\"><button id=\"save-btn\">Save</button><button id=\"rollback-btn\">Rollback latest</button><button id=\"compare-btn\">Copy compare command</button></div><section class=\"panel\"><h3>Snapshots</h3><div id=\"snapshots\"></div></section><section class=\"panel\"><h3>Debug</h3><pre id=\"debug\"></pre></section></section></main><script src=\"/app.js\"></script></body></html>"
}

///|
fn skill_hub_styles() -> String {
  ":root{--bg:#f5efe4;--ink:#173c34;--muted:#5e6f69;--line:rgba(23,60,52,.16);--card:rgba(255,255,255,.72);--accent:#a54f2a}*{box-sizing:border-box}body{margin:0;font:15px/1.5 \"Space Grotesk\",system-ui,sans-serif;background:linear-gradient(180deg,#f6efe5,#e7ded1);color:var(--ink)}.topbar{display:flex;justify-content:space-between;gap:1rem;padding:1.2rem 1.4rem;border-bottom:1px solid var(--line);background:rgba(255,255,255,.6);position:sticky;top:0;backdrop-filter:blur(10px)}.topbar h1{margin:0 0 .3rem}.topbar p{margin:0;color:var(--muted)}.actions{display:flex;gap:.8rem;align-items:start}.actions a,.actions button,.editor-actions button{border:1px solid var(--line);background:var(--card);padding:.7rem 1rem;border-radius:.9rem;color:var(--ink);text-decoration:none;font:inherit;cursor:pointer}.layout{display:grid;grid-template-columns:21rem minmax(0,1fr);min-height:calc(100vh - 92px)}.sidebar{padding:1rem;border-right:1px solid var(--line)}.sidebar input{width:100%;padding:.8rem 1rem;border-radius:999px;border:1px solid var(--line);background:#fff}.skill-item{display:grid;gap:.25rem;width:100%;padding:.85rem 1rem;margin-top:.75rem;text-align:left;border:1px solid var(--line);border-radius:1rem;background:var(--card);cursor:pointer}.skill-item.active{outline:2px solid rgba(165,79,42,.28)}.skill-item small{color:var(--muted)}.detail{padding:1rem;display:grid;gap:1rem}.detail-meta{display:grid;gap:.25rem}.detail-path,.detail-row span,#snapshots small{color:var(--muted)}.detail-row{display:flex;flex-wrap:wrap;gap:1rem}.panel{padding:1rem;border:1px solid var(--line);border-radius:1rem;background:var(--card)}textarea{width:100%;min-height:24rem;padding:1rem;border-radius:1rem;border:1px solid var(--line);background:#fff;font:13px/1.45 ui-monospace,monospace}.editor-actions{display:flex;gap:.75rem;flex-wrap:wrap}pre{margin:0;white-space:pre-wrap;word-break:break-word}@media(max-width:920px){.layout{grid-template-columns:1fr}.sidebar{border-right:none;border-bottom:1px solid var(--line)}}"
}

///|
fn skill_hub_script() -> String {
  "const stateEl={list:document.getElementById('skill-list'),search:document.getElementById('search'),name:document.getElementById('detail-name'),path:document.getElementById('detail-path'),category:document.getElementById('detail-category'),origin:document.getElementById('detail-origin'),snapshotsMeta:document.getElementById('detail-snapshots'),editor:document.getElementById('editor'),snapshots:document.getElementById('snapshots'),debug:document.getElementById('debug'),save:document.getElementById('save-btn'),rollback:document.getElementById('rollback-btn'),refresh:document.getElementById('refresh-btn'),compare:document.getElementById('compare-btn')};let app={state:null,debug:null,selected:null};const q=v=>encodeURIComponent(v||'');async function load(){const [state,debug]=await Promise.all([fetch('/api/state').then(r=>r.json()),fetch('/api/debug').then(r=>r.json())]);app.state=state;app.debug=debug;renderList();renderDebug();if(!app.selected&&state.skills&&state.skills[0])selectSkill(state.skills[0].path);else if(app.selected)selectSkill(app.selected,false)}function renderList(){const query=(stateEl.search.value||'').trim().toLowerCase();stateEl.list.innerHTML='';(app.state.skills||[]).filter(skill=>!query||[skill.name,skill.path,skill.category,skill.origin].join(' ').toLowerCase().includes(query)).forEach(skill=>{const button=document.createElement('button');button.className='skill-item'+(app.selected===skill.path?' active':'');button.innerHTML=`<strong>${escapeHtml(skill.name)}</strong><small>${escapeHtml(skill.category)} · ${escapeHtml(skill.path)}</small>`;button.onclick=()=>selectSkill(skill.path);stateEl.list.appendChild(button);});}function renderDebug(){stateEl.debug.textContent=JSON.stringify(app.debug,null,2);}function escapeHtml(text){return String(text||'').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');}async function selectSkill(path,loadSnapshots=true){app.selected=path;const skill=(app.state.skills||[]).find(item=>item.path===path);if(!skill)return;stateEl.name.textContent=skill.name;stateEl.path.textContent=skill.path;stateEl.category.textContent=skill.category;stateEl.origin.textContent=skill.origin;stateEl.snapshotsMeta.textContent=`${skill.snapshot_count||0} snapshots`;stateEl.editor.value=skill.content||'';renderList();if(loadSnapshots){const snapshots=await fetch('/api/snapshots?path='+q(path)).then(r=>r.json());renderSnapshots(snapshots);}}function renderSnapshots(snapshots){stateEl.snapshots.innerHTML='';if(!snapshots.length){stateEl.snapshots.innerHTML='<small>No snapshots yet.</small>';return;}snapshots.forEach(snapshot=>{const div=document.createElement('div');div.style.marginTop='.65rem';const button=document.createElement('button');button.textContent='Rollback';button.onclick=()=>rollback(snapshot.id);div.innerHTML=`<strong>${escapeHtml(snapshot.id)}</strong><small> ${escapeHtml(snapshot.summary||'snapshot')}</small>`;div.appendChild(button);stateEl.snapshots.appendChild(div);});}async function save(){if(!app.selected)return;await fetch('/api/save',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({path:app.selected,content:stateEl.editor.value,summary:'browser save'})});await load();}async function rollback(snapshotId){if(!app.selected)return;await fetch('/api/rollback',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({path:app.selected,snapshot_id:snapshotId})});await load();}function copyCompare(){if(!app.selected)return;const skill=(app.state.skills||[]).find(item=>item.path===app.selected);if(!skill)return;const cmd=`moonbook skill compare '${skill.name}' '${app.state.root}'`;navigator.clipboard&&window.isSecureContext?navigator.clipboard.writeText(cmd):stateEl.editor.setRangeText(cmd,0,0,'select');}stateEl.search.addEventListener('input',renderList);stateEl.save.addEventListener('click',save);stateEl.rollback.addEventListener('click',()=>fetch('/api/snapshots?path='+q(app.selected)).then(r=>r.json()).then(items=>items[0]&&rollback(items[0].id)));stateEl.refresh.addEventListener('click',load);stateEl.compare.addEventListener('click',copyCompare);const es=new EventSource('/api/events');es.addEventListener('refresh',()=>load());load();"
}

///|
async test "skill hub refresh writes state and debug files" {
  let root = "/tmp/moonbook-skill-hub-\{@async.now().to_int()}"
  ignore(init_workspace(root))
  refresh_skill_hub_state(root)
  assert_true(@fsx.exists(skill_hub_state_path(root)))
  assert_true(@fsx.exists(skill_hub_debug_path(root)))
}

///|
fn skill_hub_watch_roots(
  roots : Array[SkillHubRootStatus],
  skills : Array[SkillHubRecord],
) -> Array[String] {
  let watch_roots : Array[String] = []
  for root in roots {
    if !root.exists {
      continue
    }
    if root.category == "common-dev" {
      continue
    }
    if !watch_roots.contains(root.path) {
      watch_roots.push(root.path)
    }
  }
  for skill in skills {
    if !watch_roots.contains(skill.origin) {
      watch_roots.push(skill.origin)
    }
  }
  watch_roots
}
