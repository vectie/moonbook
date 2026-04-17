///|
async fn main {
  let args = @env.args()
  match args[1:] {
    ["book", .. book_args] => run_book(book_args.to_array())
    ["pack", .. pack_args] => run_pack(pack_args.to_array())
    ["skill", .. skill_args] => run_skill(skill_args.to_array())
    ["doctor", .. doctor_args] => run_doctor(doctor_args.to_array())
    ["wiki", .. wiki_args] => run_wiki(wiki_args.to_array())
    ["build", root] => run_build(root)
    ["build"] => run_build(".")
    ["serve", .. serve_args] => run_serve(serve_args.to_array())
    ["watch", .. watch_args] => run_watch(watch_args.to_array())
    ["init", root] => run_init(root)
    ["init"] => run_init(".")
    ["clean", root] => run_clean(root)
    ["clean"] => run_clean(".")
    ["load", root] => run_load(root)
    ["load"] => run_load(".")
    ["test", root] => run_test(root)
    ["test"] => run_test(".")
    ["version"] => println(@core.mdbook_version)
    _ => print_usage()
  }
}

///|
async fn run_book(args : Array[String]) -> Unit {
  match args {
    ["init", root] => run_init(root)
    ["init"] => run_init(".")
    ["clean", root] => run_clean(root)
    ["clean"] => run_clean(".")
    ["load", root] => run_load(root)
    ["load"] => run_load(".")
    ["test", root] => run_test(root)
    ["test"] => run_test(".")
    _ =>
      println(
        "moonbook book usage: moonbook book init [root]\nmoonbook book clean [root]\nmoonbook book load [root]\nmoonbook book test [root]",
      )
  }
}

///|
async fn run_pack(args : Array[String]) -> Unit {
  match args {
    ["list"] => run_pack_list()
    ["enable", extension, root] => run_wiki_enable(root, extension)
    ["enable", extension] => run_wiki_enable(".", extension)
    _ =>
      println(
        "moonbook pack usage: moonbook pack list\nmoonbook pack enable <extension> [root]",
      )
  }
}

///|
fn run_pack_list() -> Unit {
  for extension in @wiki.supported_extensions() {
    println(extension)
  }
}

///|
async fn run_skill(args : Array[String]) -> Unit {
  match args {
    ["hub", .. hub_args] => run_skill_hub(hub_args.to_array())
    ["list", root] => run_skill_list(root)
    ["list"] => run_skill_list(".")
    ["show", name, root] => run_skill_show(root, name)
    ["show", name] => run_skill_show(".", name)
    ["compare", name, root] => run_skill_compare(root, name)
    ["compare", name] => run_skill_compare(".", name)
    ["sync", name, root] => run_skill_sync(root, name)
    ["sync", name] => run_skill_sync(".", name)
    ["install", name, root] => run_skill_install(root, name)
    ["install", name] => run_skill_install(".", name)
    ["scaffold", name, root] => run_skill_scaffold(root, name)
    ["scaffold", name] => run_skill_scaffold(".", name)
    ["doctor", root] => run_skill_doctor(root)
    ["doctor"] => run_skill_doctor(".")
    _ =>
      println(
        "moonbook skill usage: moonbook skill hub [root] [-n hostname] [-p port] [-o]\nmoonbook skill list [root]\nmoonbook skill show <name> [root]\nmoonbook skill compare <name[@extension]> [root]\nmoonbook skill sync <name[@extension]> [root]\nmoonbook skill install <name[@extension]> [root]\nmoonbook skill scaffold <name> [root]\nmoonbook skill doctor [root]",
      )
  }
}

///|
async fn run_skill_hub(args : Array[String]) -> Unit {
  let mut root = "."
  let mut hostname = "localhost"
  let mut port = 3456
  let mut open_browser = false
  let mut index = 0
  let mut seen_root = false
  while index < args.length() {
    match args[index] {
      "-o" | "--open" => {
        open_browser = true
        index += 1
      }
      "-n" | "--hostname" =>
        if index + 1 < args.length() {
          hostname = args[index + 1]
          index += 2
        } else {
          println(
            "moonbook skill hub usage: moonbook skill hub [root] [-n hostname] [-p port] [-o]",
          )
          return
        }
      "-p" | "--port" =>
        if index + 1 < args.length() {
          port = @strconv.parse_int(args[index + 1]) catch {
            _ => {
              println(
                "moonbook skill hub usage: moonbook skill hub [root] [-n hostname] [-p port] [-o]",
              )
              return
            }
          }
          index += 2
        } else {
          println(
            "moonbook skill hub usage: moonbook skill hub [root] [-n hostname] [-p port] [-o]",
          )
          return
        }
      value =>
        if !seen_root && !value.has_prefix("-") {
          root = value
          seen_root = true
          index += 1
        } else {
          println(
            "moonbook skill hub usage: moonbook skill hub [root] [-n hostname] [-p port] [-o]",
          )
          return
        }
    }
  }
  @wiki.serve_skill_hub(
    @wiki.make_skill_hub_serve_options(root, hostname, port, open_browser),
  ) catch {
    error => println("moonbook skill hub failed: \{error}")
  }
}

///|
async fn run_skill_list(root : String) -> Unit {
  let records = @wiki.list_skills(root) catch {
    error => {
      println("moonbook skill list failed: \{error}")
      return
    }
  }
  if records.is_empty() {
    println("no skills found")
    return
  }
  for record in records {
    let extension = match record.extension {
      Some(extension) => extension
      None => "-"
    }
    println("\{record.name}\t\{record.scope}\t\{extension}\t\{record.path}")
  }
}

///|
async fn run_skill_show(root : String, name : String) -> Unit {
  let maybe_record = @wiki.find_skill(root, name) catch {
    error => {
      println("moonbook skill show failed: \{error}")
      return
    }
  }
  match maybe_record {
    Some(record) => println(record.to_json().stringify(indent=2))
    None => println("moonbook skill show failed: no skill found for \{name}")
  }
}

///|
async fn run_skill_install(root : String, name : String) -> Unit {
  let result = @wiki.install_skill(root, name) catch {
    error => {
      println("moonbook skill install failed: \{error}")
      return
    }
  }
  println("installed skill \{result.name}")
  println("workspace path: \{result.destination_path}")
  match result.source_path {
    Some(path) => println("seed source: \{path}")
    None => ()
  }
}

///|
async fn run_skill_compare(root : String, name : String) -> Unit {
  let result = @wiki.compare_skill(root, name) catch {
    error => {
      println("moonbook skill compare failed: \{error}")
      return
    }
  }
  println(result.to_json().stringify(indent=2))
}

///|
async fn run_skill_sync(root : String, name : String) -> Unit {
  let result = @wiki.sync_skill(root, name) catch {
    error => {
      println("moonbook skill sync failed: \{error}")
      return
    }
  }
  println("synced skill \{result.name}")
  println("candidate dir: \{result.candidate_dir}")
  println("manifest: \{result.manifest_path}")
  println("workspace source: \{result.selected_path}")
  println("baseline source: \{result.baseline_path}")
}

///|
async fn run_skill_scaffold(root : String, name : String) -> Unit {
  let result = @wiki.scaffold_skill(root, name) catch {
    error => {
      println("moonbook skill scaffold failed: \{error}")
      return
    }
  }
  println("scaffolded skill \{result.name}")
  println("workspace path: \{result.destination_path}")
}

///|
async fn run_skill_doctor(root : String) -> Unit {
  let report = @wiki.doctor_skills(root) catch {
    error => {
      println("moonbook skill doctor failed: \{error}")
      return
    }
  }
  println("skill count: \{report.total_count}")
  println("workspace skills: \{report.workspace_count}")
  println("seed core skills: \{report.seed_core_count}")
  println("seed extension skills: \{report.seed_extension_count}")
  if report.duplicate_names.is_empty() &&
    report.missing_reference_paths.is_empty() &&
    report.warnings.is_empty() {
    println("skill doctor: clean")
    return
  }
  if !report.duplicate_names.is_empty() {
    let duplicate_names = report.duplicate_names.join(", ")
    println("duplicate names: \{duplicate_names}")
  }
  if !report.missing_reference_paths.is_empty() {
    println("missing references:")
    for path in report.missing_reference_paths {
      println("- \{path}")
    }
  }
  if !report.warnings.is_empty() {
    println("warnings:")
    for warning in report.warnings {
      println("- \{warning}")
    }
  }
}

///|
async fn run_doctor(args : Array[String]) -> Unit {
  let root = match args {
    [root] => root
    [] => "."
    _ => {
      println("moonbook doctor usage: moonbook doctor [root]")
      return
    }
  }
  let skill_report = @wiki.doctor_skills(root) catch {
    error => {
      println("moonbook doctor failed: \{error}")
      return
    }
  }
  println("MoonBook doctor for \{root}")
  println("skills: \{skill_report.total_count}")
  if skill_report.warnings.is_empty() &&
    skill_report.duplicate_names.is_empty() &&
    skill_report.missing_reference_paths.is_empty() {
    println("skill status: clean")
  } else {
    println("skill status: attention needed")
  }
  if @fsx.exists(@path.Path(root).join(@path.Path("wiki")).to_string()) {
    let health = @wiki.report_health(root) catch {
      error => {
        println("wiki health failed: \{error}")
        return
      }
    }
    println("wiki health: \{health.level}")
    println("summary: \{health.summary}")
    println(
      "coverage: sources=\{health.source_page_count} entities=\{health.entity_page_count} concepts=\{health.concept_page_count} queries=\{health.query_note_count}",
    )
  } else {
    println("wiki health: skipped (no wiki workspace detected)")
  }
}

///|
async fn run_wiki(args : Array[String]) -> Unit {
  match args {
    ["book", .. book_args] => run_wiki_book(book_args.to_array())
    ["keeper", .. keeper_args] => run_wiki_keeper(keeper_args.to_array())
    ["enable", extension, root] => run_wiki_enable(root, extension)
    ["enable", extension] => run_wiki_enable(".", extension)
    ["lint", root] => run_wiki_lint(root)
    ["lint"] => run_wiki_lint(".")
    ["review", .. review_args] => run_wiki_review(review_args.to_array())
    ["query", .. query_args] => run_wiki_query(query_args.to_array())
    ["ingest", root, source] => run_wiki_ingest(root, source)
    ["ingest", source] => run_wiki_ingest(".", source)
    ["init", root] => run_wiki_init(root)
    ["init"] => run_wiki_init(".")
    _ =>
      println(
        "moonbook wiki usage: moonbook wiki init [root]\nmoonbook wiki enable <extension> [root]\nmoonbook wiki ingest [root] <source>\nmoonbook wiki query [root] <question> [--save]\nmoonbook wiki lint [root]\nmoonbook wiki review list [root]\nmoonbook wiki review approve [root] <review-id>\nmoonbook wiki review reject [root] <review-id>\nmoonbook wiki keeper submit [root] <packet.json> [--confirm] [--home <dir>] [--cwd <dir>] [--moonclaw <dir>] [--latest]\nmoonbook wiki book accept [root] <goal>\nmoonbook wiki book tasks [root] <goal>\nmoonbook wiki book context [root] <goal> [--task <task-id>]\nmoonbook wiki book persist [root] <result.json>\nmoonbook wiki book summary [root]\nmoonbook wiki book health [root]",
      )
  }
}

///|
async fn run_wiki_init(root : String) -> Unit {
  let workspace = @wiki.init_workspace(root) catch {
    error => {
      println("moonbook wiki init failed: \{error}")
      return
    }
  }
  println("initialized wiki workspace at \{workspace.root}")
  println("raw sources: \{workspace.raw_dir}")
  println("wiki pages: \{workspace.wiki_dir}")
  println("schema: \{workspace.schema_path}")
}

///|
async fn run_wiki_enable(root : String, extension : String) -> Unit {
  let integration = @wiki.enable_extension(root, extension) catch {
    error => {
      println("moonbook wiki enable failed: \{error}")
      return
    }
  }
  println(
    "enabled wiki extension \{integration.extension} at \{integration.root}",
  )
  println("extension manifest: \{integration.manifest_path}")
  for path in integration.installed_files {
    println("installed: \{path}")
  }
}

///|
async fn run_wiki_ingest(root : String, source : String) -> Unit {
  let result = @wiki.ingest_source(root, source) catch {
    error => {
      println("moonbook wiki ingest failed: \{error}")
      return
    }
  }
  println("ingested \{result.title}")
  println("raw source: \{result.raw_path}")
  println("wiki page: \{result.page_path}")
  if !result.keeper_packet_path.is_empty() {
    println("keeper packet: \{result.keeper_packet_path}")
  }
}

///|
async fn run_wiki_query(args : Array[String]) -> Unit {
  let parsed = parse_wiki_query_args(args) catch {
    error => {
      println("moonbook wiki query failed: \{error}")
      return
    }
  }
  let result = @wiki.query_wiki(parsed.root, parsed.question, save=parsed.save) catch {
    error => {
      println("moonbook wiki query failed: \{error}")
      return
    }
  }
  println(result.answer)
  match result.saved_page {
    Some(path) => println("saved query page: \{path}")
    None => ()
  }
}

///|
async fn run_wiki_lint(root : String) -> Unit {
  let result = @wiki.lint_wiki(root) catch {
    error => {
      println("moonbook wiki lint failed: \{error}")
      return
    }
  }
  println(result.report)
}

///|
async fn run_wiki_review(args : Array[String]) -> Unit {
  match args {
    ["list", root] => run_wiki_review_list(root)
    ["list"] => run_wiki_review_list(".")
    ["approve", root, review_id] =>
      run_wiki_review_action(root, review_id, "approve")
    ["approve", review_id] => run_wiki_review_action(".", review_id, "approve")
    ["reject", root, review_id] =>
      run_wiki_review_action(root, review_id, "reject")
    ["reject", review_id] => run_wiki_review_action(".", review_id, "reject")
    _ =>
      println(
        "moonbook wiki review usage: moonbook wiki review list [root]\nmoonbook wiki review approve [root] <review-id>\nmoonbook wiki review reject [root] <review-id>",
      )
  }
}

///|
async fn run_wiki_review_list(root : String) -> Unit {
  let items = @wiki.list_pending_reviews(root) catch {
    error => {
      println("moonbook wiki review failed: \{error}")
      return
    }
  }
  if items.is_empty() {
    println("no pending review items")
    return
  }
  for item in items {
    println("\{item.review_id}\t\{item.kind}\t\{item.status}\t\{item.title}")
  }
}

///|
async fn run_wiki_review_action(
  root : String,
  review_id : String,
  action : String,
) -> Unit {
  let result = if action == "approve" {
    @wiki.approve_review(root, review_id) catch {
      error => {
        println("moonbook wiki review failed: \{error}")
        return
      }
    }
  } else {
    @wiki.reject_review(root, review_id) catch {
      error => {
        println("moonbook wiki review failed: \{error}")
        return
      }
    }
  }
  println("\{action}d review \{result.review_id}")
  for page in result.promoted_pages {
    println("updated: wiki/\{page}")
  }
}

///|
async fn run_wiki_keeper(args : Array[String]) -> Unit {
  match args {
    ["submit", .. raw] => run_wiki_keeper_submit(raw.to_array())
    _ =>
      println(
        "moonbook wiki keeper usage: moonbook wiki keeper submit [root] <packet.json> [--confirm] [--home <dir>] [--cwd <dir>] [--moonclaw <dir>] [--latest]",
      )
  }
}

///|
async fn run_wiki_keeper_submit(args : Array[String]) -> Unit {
  let parsed = parse_wiki_keeper_submit_args(args) catch {
    error => {
      println("moonbook wiki keeper submit failed: \{error}")
      return
    }
  }
  ensure_wiki_keeper_submit_runtime(parsed.root) catch {
    error => {
      println("moonbook wiki keeper submit failed: \{error}")
      return
    }
  }
  let moon_args = [
    "-C",
    parsed.moonclaw_root,
    "run",
    "cmd/main",
    "--",
    "proposal",
    "import",
    parsed.packet_path,
    "--json",
    "--cwd",
    parsed.cwd,
    ..match parsed.home {
      Some(home) => ["--home", home]
      None => []
    },
    ..if parsed.confirm {
      ["--confirm"]
    } else {
      []
    },
  ]
  let code = @process.run("moon", moon_args) catch {
    error => {
      println("moonbook wiki keeper submit failed: \{error}")
      return
    }
  }
  if code != 0 {
    println(
      "moonbook wiki keeper submit failed: moonclaw exited with code \{code}",
    )
  }
}

///|
async fn run_wiki_book(args : Array[String]) -> Unit {
  match args {
    ["accept", .. raw] => run_wiki_book_accept(raw.to_array())
    ["tasks", .. raw] => run_wiki_book_tasks(raw.to_array())
    ["context", .. raw] => run_wiki_book_context(raw.to_array())
    ["persist", root, path] => run_wiki_book_persist(root, path)
    ["persist", path] => run_wiki_book_persist(".", path)
    ["catalog", root] => run_wiki_book_catalog(root)
    ["catalog"] => run_wiki_book_catalog(".")
    ["summary", root] => run_wiki_book_summary(root)
    ["summary"] => run_wiki_book_summary(".")
    ["health", root] => run_wiki_book_health(root)
    ["health"] => run_wiki_book_health(".")
    _ =>
      println(
        "moonbook wiki book usage: moonbook wiki book accept [root] <goal>\nmoonbook wiki book tasks [root] <goal>\nmoonbook wiki book context [root] <goal> [--task <task-id>]\nmoonbook wiki book persist [root] <result.json>\nmoonbook wiki book catalog [root]\nmoonbook wiki book summary [root]\nmoonbook wiki book health [root]",
      )
  }
}

///|
async fn run_wiki_book_accept(args : Array[String]) -> Unit {
  let parsed = parse_wiki_book_goal_args(args, false) catch {
    error => {
      println("moonbook wiki book accept failed: \{error}")
      return
    }
  }
  let result = @wiki.accept_goal(parsed.root, parsed.goal) catch {
    error => {
      println("moonbook wiki book accept failed: \{error}")
      return
    }
  }
  print_json(result)
}

///|
async fn run_wiki_book_tasks(args : Array[String]) -> Unit {
  let parsed = parse_wiki_book_goal_args(args, false) catch {
    error => {
      println("moonbook wiki book tasks failed: \{error}")
      return
    }
  }
  let result = @wiki.produce_task_batch(parsed.root, parsed.goal) catch {
    error => {
      println("moonbook wiki book tasks failed: \{error}")
      return
    }
  }
  print_json(result)
}

///|
async fn run_wiki_book_context(args : Array[String]) -> Unit {
  let parsed = parse_wiki_book_goal_args(args, true) catch {
    error => {
      println("moonbook wiki book context failed: \{error}")
      return
    }
  }
  let task = @wiki.resolve_task_for_goal(
    parsed.root,
    parsed.goal,
    task_id=parsed.task_id,
  ) catch {
    error => {
      println("moonbook wiki book context failed: \{error}")
      return
    }
  }
  match task {
    Some(task) => {
      let context = @wiki.hydrate_worker_context(parsed.root, task) catch {
        error => {
          println("moonbook wiki book context failed: \{error}")
          return
        }
      }
      print_json(context)
    }
    None =>
      println(
        "moonbook wiki book context failed: no matching task found for goal",
      )
  }
}

///|
async fn run_wiki_book_persist(root : String, path : String) -> Unit {
  let text = @fsx.read_file(path) catch {
    error => {
      println("moonbook wiki book persist failed: \{error}")
      return
    }
  }
  let result : @wiki.BookResult = @json.from_json(@json.parse(text)) catch {
    error => {
      println("moonbook wiki book persist failed: \{error}")
      return
    }
  }
  let outcome = @wiki.persist_result(root, result) catch {
    error => {
      println("moonbook wiki book persist failed: \{error}")
      return
    }
  }
  print_json(outcome)
}

///|
async fn run_wiki_book_catalog(root : String) -> Unit {
  let result = @wiki.catalog_record(root) catch {
    error => {
      println("moonbook wiki book catalog failed: \{error}")
      return
    }
  }
  print_json(result)
}

///|
async fn run_wiki_book_summary(root : String) -> Unit {
  let result = @wiki.summarize_state(root) catch {
    error => {
      println("moonbook wiki book summary failed: \{error}")
      return
    }
  }
  print_json(result)
}

///|
async fn run_wiki_book_health(root : String) -> Unit {
  let result = @wiki.report_health(root) catch {
    error => {
      println("moonbook wiki book health failed: \{error}")
      return
    }
  }
  print_json(result)
}

///|
struct ParsedWikiQueryArgs {
  root : String
  question : String
  save : Bool
}

///|
struct ParsedWikiBookGoalArgs {
  root : String
  goal : String
  task_id : String?
}

///|
struct ParsedWikiKeeperSubmitArgs {
  root : String
  packet_path : String
  confirm : Bool
  home : String?
  cwd : String
  moonclaw_root : String
}

///|
async fn parse_wiki_query_args(args : Array[String]) -> ParsedWikiQueryArgs {
  let filtered : Array[String] = []
  let mut save = false
  for arg in args {
    if arg == "--save" {
      save = true
    } else {
      filtered.push(arg)
    }
  }
  if filtered.is_empty() {
    fail("usage: moonbook wiki query [root] <question> [--save]")
  }
  if filtered.length() >= 2 && looks_like_wiki_root(filtered[0]) {
    { root: filtered[0], question: filtered[1:].join(" "), save }
  } else {
    { root: ".", question: filtered.join(" "), save }
  }
}

///|
async fn parse_wiki_book_goal_args(
  args : Array[String],
  allow_task : Bool,
) -> ParsedWikiBookGoalArgs {
  let filtered : Array[String] = []
  let mut task_id : String? = None
  let mut i = 0
  while i < args.length() {
    if allow_task && args[i] == "--task" {
      if i + 1 >= args.length() {
        fail("usage requires a value after --task")
      }
      task_id = Some(args[i + 1])
      i += 2
    } else {
      filtered.push(args[i])
      i += 1
    }
  }
  if filtered.is_empty() {
    fail("usage requires a goal")
  }
  if filtered.length() >= 2 && looks_like_wiki_root(filtered[0]) {
    { root: filtered[0], goal: filtered[1:].join(" "), task_id }
  } else {
    { root: ".", goal: filtered.join(" "), task_id }
  }
}

///|
async fn parse_wiki_keeper_submit_args(
  args : Array[String],
) -> ParsedWikiKeeperSubmitArgs {
  let filtered : Array[String] = []
  let mut confirm = false
  let mut latest = false
  let mut home : String? = None
  let mut cwd : String? = None
  let mut moonclaw_root : String? = None
  let mut i = 0
  while i < args.length() {
    match args[i] {
      "--confirm" => {
        confirm = true
        i += 1
      }
      "--latest" => {
        latest = true
        i += 1
      }
      "--home" => {
        if i + 1 >= args.length() {
          fail("usage requires a value after --home")
        }
        home = Some(args[i + 1])
        i += 2
      }
      "--cwd" => {
        if i + 1 >= args.length() {
          fail("usage requires a value after --cwd")
        }
        cwd = Some(args[i + 1])
        i += 2
      }
      "--moonclaw" => {
        if i + 1 >= args.length() {
          fail("usage requires a value after --moonclaw")
        }
        moonclaw_root = Some(args[i + 1])
        i += 2
      }
      arg => {
        filtered.push(arg)
        i += 1
      }
    }
  }
  if latest && filtered.length() > 1 {
    fail(
      "usage: moonbook wiki keeper submit [root] --latest [--confirm] [--home <dir>] [--cwd <dir>] [--moonclaw <dir>]",
    )
  }
  if !latest && (filtered.is_empty() || filtered.length() > 2) {
    fail(
      "usage: moonbook wiki keeper submit [root] <packet.json> [--confirm] [--home <dir>] [--cwd <dir>] [--moonclaw <dir>] [--latest]",
    )
  }
  let root = if latest {
    if filtered.length() == 1 {
      filtered[0]
    } else {
      "."
    }
  } else if filtered.length() == 2 {
    filtered[0]
  } else {
    "."
  }
  let resolved_packet = if latest {
    latest_keeper_packet_path(root)
  } else {
    let packet_arg = if filtered.length() == 2 {
      filtered[1]
    } else {
      filtered[0]
    }
    resolve_keeper_packet_path(root, packet_arg)
  }
  {
    root,
    packet_path: resolved_packet,
    confirm,
    home,
    cwd: cwd.unwrap_or(root),
    moonclaw_root: moonclaw_root.unwrap_or(default_moonclaw_root()),
  }
}

///|
async fn looks_like_wiki_root(path : String) -> Bool {
  let summary = @path.Path(path).join(@path.Path("wiki/SUMMARY.md")).to_string()
  @fsx.exists(summary)
}

///|
async fn ensure_wiki_keeper_submit_runtime(root : String) -> Unit {
  let jobs_path = @path.Path(root)
    .join(@path.Path("moonclaw.jobs.json"))
    .to_string()
  if @fsx.exists(jobs_path) {
    return
  }
  if !looks_like_wiki_root(root) {
    fail(
      "root is not a wiki workspace and moonclaw.jobs.json is missing: \{root}",
    )
  }
  let install = @wiki.enable_extension(root, "moonclaw")
  println(
    "seeded moonclaw extension for keeper submit: \{install.manifest_path}",
  )
}

///|
async fn latest_keeper_packet_path(root : String) -> String {
  let jobs_dir = @path.Path(root).join(@path.Path("keeper/jobs")).to_string()
  if !@fsx.exists(jobs_dir) {
    fail("keeper jobs directory does not exist: \{jobs_dir}")
  }
  let mut latest_path = ""
  let mut latest_mtime = -1L
  for entry in @fsx.list_directory(jobs_dir) {
    if !entry.has_suffix(".json") {
      continue
    }
    let entry_mtime = @fsx.mtime(entry).unwrap_or(-1L)
    if entry_mtime > latest_mtime {
      latest_path = entry
      latest_mtime = entry_mtime
    }
  }
  if latest_path.is_empty() {
    fail("no keeper packet found under \{jobs_dir}")
  }
  latest_path
}

///|
fn resolve_keeper_packet_path(root : String, packet_path : String) -> String {
  if @path.Path(packet_path).is_absolute() {
    @path.Path(packet_path).normalize().to_string()
  } else if root == "." {
    @path.Path(packet_path).normalize().to_string()
  } else {
    @path.Path(root).join(@path.Path(packet_path)).normalize().to_string()
  }
}

///|
fn default_moonclaw_root() -> String {
  match @env.current_dir() {
    Some(cwd) =>
      @path.Path(cwd).join(@path.Path("../moonclaw")).normalize().to_string()
    None => "../moonclaw"
  }
}

///|
async fn run_build(root : String) -> Unit {
  let book = @driver.load(root) catch {
    error => {
      println("moonbook build failed: \{error}")
      return
    }
  }
  book.build() catch {
    error => {
      println("moonbook render failed: \{error}")
      return
    }
  }
  println("built \{root} -> \{@driver.resolved_build_dir(root, book.config)}")
}

///|
async fn run_init(root : String) -> Unit {
  let book = @driver.init_book(root, create_gitignore=true) catch {
    error => {
      println("moonbook init failed: \{error}")
      return
    }
  }
  println(
    "initialized \{root} with src=\{book.config.book.src} build=\{book.config.build.build_dir}",
  )
}

///|
async fn run_clean(root : String) -> Unit {
  let stats = @driver.clean_book(root) catch {
    error => {
      println("moonbook clean failed: \{error}")
      return
    }
  }
  println(
    "removed \{stats.files_removed} files, \{stats.directories_removed} directories, \{stats.bytes_removed} bytes",
  )
}

///|
async fn run_load(root : String) -> Unit {
  let book = @driver.load(root) catch {
    error => {
      println("moonbook load failed: \{error}")
      return
    }
  }
  println(book.to_json().stringify(indent=2))
}

///|
async fn run_test(root : String) -> Unit {
  let book = @driver.load(root) catch {
    error => {
      println("moonbook test failed: \{error}")
      return
    }
  }
  let rust_blocks = book.count_rust_code_blocks()
  println("discovered \{rust_blocks} rust fenced code blocks")
}

///|
async fn run_serve(args : Array[String]) -> Unit {
  let options = match @httpserve.parse_serve_args(args) {
    Some(options) => options
    None => {
      println(
        "moonbook serve usage: moonbook serve [root] [-n hostname] [-p port] [-d dest-dir] [-o] [--watcher poll|native]",
      )
      return
    }
  }
  if options.watcher_kind == "native" {
    println("moonbook serve: --watcher native currently uses the poll backend")
  }
  let base_book = @driver.load(options.root) catch {
    error => {
      println("moonbook serve failed to load: \{error}")
      return
    }
  }
  let live_reload_endpoint = "__livereload"
  let serve_config = build_serve_config(
    base_book.config,
    live_reload_endpoint,
    options.dest_dir,
  )
  let book = @driver.load_with_config(options.root, serve_config) catch {
    error => {
      println("moonbook serve failed to configure: \{error}")
      return
    }
  }
  book.build() catch {
    error => {
      println("moonbook serve failed to build: \{error}")
      return
    }
  }
  let build_dir = @driver.resolved_build_dir(options.root, book.config)
  let watch_filter = @watcher.load_watch_filter(options.root)
  write_live_reload_token(build_dir)
  let server = @httpserve.Server::new(options.hostname, options.port) catch {
    error => {
      println("moonbook serve failed: \{error}")
      return
    }
  }
  println("serving \{build_dir}")
  let serving_url = "http://\{options.hostname}:\{server.port()}"
  println("listening on \{serving_url}")
  @async.with_task_group(group => {
    if options.open_browser {
      group.spawn_bg(
        () => open_browser(serving_url),
        no_wait=true,
        allow_failure=true,
      )
    }
    group.spawn_bg(
      () => {
        server.serve_directory(
          build_dir,
          live_reload_endpoint=Some(live_reload_endpoint),
        )
      },
      no_wait=true,
      allow_failure=true,
    )
    let src_dir = @path.Path(options.root)
      .join(@path.Path(book.config.book.src))
      .to_string()
    let config_path = @path.Path(options.root)
      .join(@path.Path("book.toml"))
      .to_string()
    let watch_paths = [src_dir, config_path]
    @watcher.rebuild_on_change(watch_paths, filter=watch_filter, async fn(
      changed : Array[String],
    ) {
      let changed_text = changed.join(", ")
      println("files changed: \{changed_text}")
      let book = @driver.load_with_config(options.root, serve_config) catch {
        error => {
          println("moonbook serve reload failed: \{error}")
          return
        }
      }
      book.build() catch {
        error => {
          println("moonbook serve rebuild failed: \{error}")
          return
        }
      }
      write_live_reload_token(build_dir)
      println(
        "rebuilt \{options.root} -> \{@driver.resolved_build_dir(options.root, book.config)}",
      )
    })
  })
}

///|
async fn run_watch(args : Array[String]) -> Unit {
  let options = match @watcher.parse_watch_args(args) {
    Some(options) => options
    None => {
      println(
        "moonbook watch usage: moonbook watch [root] [-d dest-dir] [-o] [--watcher poll|native]",
      )
      return
    }
  }
  if options.watcher_kind == "native" {
    println("moonbook watch: --watcher native currently uses the poll backend")
  }
  let base_book = @driver.load(options.root) catch {
    error => {
      println("moonbook watch failed to load: \{error}")
      return
    }
  }
  let watch_config = build_watch_config(base_book.config, options.dest_dir)
  let book = @driver.load_with_config(options.root, watch_config) catch {
    error => {
      println("moonbook watch failed to configure: \{error}")
      return
    }
  }
  let src_dir = @path.Path(options.root)
    .join(@path.Path(book.config.book.src))
    .to_string()
  let config_path = @path.Path(options.root)
    .join(@path.Path("book.toml"))
    .to_string()
  let watch_paths = [src_dir, config_path]
  let watch_filter = @watcher.load_watch_filter(options.root)
  book.build() catch {
    error => {
      println("moonbook watch initial build failed: \{error}")
      return
    }
  }
  if options.open_browser {
    let index_path = @path.Path(
        @driver.resolved_build_dir(options.root, book.config),
      )
      .join(@path.Path("index.html"))
      .to_string()
    if @fsx.exists(index_path) {
      open_browser(index_path)
    } else {
      println("moonbook watch could not open: no index.html was generated")
    }
  }
  println("watching \{options.root}")
  @watcher.rebuild_on_change(
    watch_paths,
    filter=watch_filter,
    async fn(changed : Array[String]) {
      let changed_text = changed.join(", ")
      println("files changed: \{changed_text}")
      let book = @driver.load_with_config(options.root, watch_config) catch {
        error => {
          println("moonbook watch reload failed: \{error}")
          return
        }
      }
      book.build() catch {
        error => {
          println("moonbook watch rebuild failed: \{error}")
          return
        }
      }
      println(
        "rebuilt \{options.root} -> \{@driver.resolved_build_dir(options.root, book.config)}",
      )
    },
    interval_ms=options.interval_ms,
  )
}

///|
fn print_usage() -> Unit {
  println("moonbook book init [root]")
  println("moonbook book clean [root]")
  println("moonbook book load [root]")
  println("moonbook book test [root]")
  println("moonbook pack list")
  println("moonbook pack enable <extension> [root]")
  println("moonbook skill list [root]")
  println("moonbook skill show <name> [root]")
  println("moonbook skill doctor [root]")
  println("moonbook doctor [root]")
  println("moonbook wiki init [root]")
  println("moonbook wiki enable <extension> [root]")
  println("moonbook wiki ingest [root] <source>")
  println("moonbook wiki query [root] <question> [--save]")
  println("moonbook wiki lint [root]")
  println("moonbook wiki book accept [root] <goal>")
  println("moonbook wiki book tasks [root] <goal>")
  println("moonbook wiki book context [root] <goal> [--task <task-id>]")
  println("moonbook wiki book persist [root] <result.json>")
  println("moonbook wiki book catalog [root]")
  println("moonbook wiki book summary [root]")
  println("moonbook wiki book health [root]")
  println("moonbook build [root]")
  println(
    "moonbook serve [root] [-n hostname] [-p port] [-d dest-dir] [-o] [--watcher poll|native]",
  )
  println("moonbook watch [root] [-d dest-dir] [-o] [--watcher poll|native]")
  println(
    "moonbook init [root]                  # compatibility alias for `moonbook book init`",
  )
  println(
    "moonbook clean [root]                 # compatibility alias for `moonbook book clean`",
  )
  println(
    "moonbook load [root]                  # compatibility alias for `moonbook book load`",
  )
  println(
    "moonbook test [root]                  # compatibility alias for `moonbook book test`",
  )
  println("moonbook version")
}

///|
async fn write_live_reload_token(build_dir : String) -> Unit {
  let token_path = @path.Path(build_dir)
    .join(@path.Path(@httpserve.live_reload_token_file))
    .to_string()
  let token = "\{@async.now().to_int()}"
  @fsx.write_to_file(token_path, token, create=0o666) catch {
    _ => ()
  }
}

///|
fn build_serve_config(
  config : @core.Config,
  live_reload_endpoint : String,
  dest_dir : String?,
) -> @core.Config {
  let config = config.set(
    "output.html.live-reload-endpoint",
    Json::string(live_reload_endpoint),
  )
  match dest_dir {
    Some(dest_dir) => config.with_build_dir(resolve_cli_dest_dir(dest_dir))
    None => config
  }
}

///|
fn build_watch_config(
  config : @core.Config,
  dest_dir : String?,
) -> @core.Config {
  match dest_dir {
    Some(dest_dir) => config.with_build_dir(resolve_cli_dest_dir(dest_dir))
    None => config
  }
}

///|
fn resolve_cli_dest_dir(dest_dir : String) -> String {
  if @path.Path(dest_dir).is_absolute() {
    @path.Path(dest_dir).normalize().to_string()
  } else {
    match @env.current_dir() {
      Some(current_dir) =>
        @path.Path(current_dir)
        .join(@path.Path(dest_dir))
        .normalize()
        .to_string()
      None => dest_dir
    }
  }
}

///|
async fn open_browser(url : String) -> Unit {
  let mac = @process.run("open", [url]) catch { _ => -1 }
  if mac == 0 {
    return
  }
  ignore(@process.run("xdg-open", [url]) catch { _ => -1 })
}

///|
fn[T : ToJson] print_json(value : T) -> Unit {
  println(value.to_json().stringify(indent=2))
}

///|
