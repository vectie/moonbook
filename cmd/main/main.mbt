///|
async fn main {
  let args = @env.args()
  match args[1:] {
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
async fn run_wiki(args : Array[String]) -> Unit {
  match args {
    ["book", .. book_args] => run_wiki_book(book_args.to_array())
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
        "moonbook wiki usage: moonbook wiki init [root]\nmoonbook wiki enable <extension> [root]\nmoonbook wiki ingest [root] <source>\nmoonbook wiki query [root] <question> [--save]\nmoonbook wiki lint [root]\nmoonbook wiki review list [root]\nmoonbook wiki review approve [root] <review-id>\nmoonbook wiki review reject [root] <review-id>\nmoonbook wiki book accept [root] <goal>\nmoonbook wiki book tasks [root] <goal>\nmoonbook wiki book context [root] <goal> [--task <task-id>]\nmoonbook wiki book persist [root] <result.json>\nmoonbook wiki book summary [root]\nmoonbook wiki book health [root]",
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
  let batch = @wiki.produce_task_batch(parsed.root, parsed.goal) catch {
    error => {
      println("moonbook wiki book context failed: \{error}")
      return
    }
  }
  let task = match parsed.task_id {
    Some(task_id) =>
      batch.tasks
      .iter()
      .find_first(fn(task : @wiki.BookTask) { task.id == task_id })
    None => if batch.tasks.is_empty() { None } else { Some(batch.tasks[0]) }
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
async fn looks_like_wiki_root(path : String) -> Bool {
  let summary = @path.Path(path).join(@path.Path("wiki/SUMMARY.md")).to_string()
  @fsx.exists(summary)
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
  println("moonbook init [root]")
  println("moonbook clean [root]")
  println("moonbook load [root]")
  println("moonbook test [root]")
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
