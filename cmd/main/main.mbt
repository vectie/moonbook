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
    ["lint", root] => run_wiki_lint(root)
    ["lint"] => run_wiki_lint(".")
    ["query", .. query_args] => run_wiki_query(query_args.to_array())
    ["ingest", root, source] => run_wiki_ingest(root, source)
    ["ingest", source] => run_wiki_ingest(".", source)
    ["init", root] => run_wiki_init(root)
    ["init"] => run_wiki_init(".")
    _ =>
      println(
        "moonbook wiki usage: moonbook wiki init [root]\nmoonbook wiki ingest [root] <source>\nmoonbook wiki query [root] <question> [--save]",
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
struct ParsedWikiQueryArgs {
  root : String
  question : String
  save : Bool
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
  println("moonbook wiki ingest [root] <source>")
  println("moonbook wiki query [root] <question> [--save]")
  println("moonbook wiki lint [root]")
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
