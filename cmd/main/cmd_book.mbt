///|
// Book/build/serve/watch command handlers.

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
    ["inspect", source] => print_json(@packhost.inspect(source))
    ["install", source, workspace, profile] =>
      print_json(@packhost.install_authorized(source, workspace, profile))
    ["install", source, workspace] =>
      print_json(@packhost.install(source, workspace))
    ["active", workspace] => print_json(@packhost.list_active(workspace))
    ["active"] => print_json(@packhost.list_active("."))
    ["project", workspace, pack_id] =>
      print_json(@packhost.project_active(workspace, pack_id))
    ["verify", workspace, pack_id, version] =>
      print_json(@packhost.verify(workspace, pack_id, version))
    ["activate", workspace, pack_id, version] =>
      print_json(@packhost.activate(workspace, pack_id, version))
    ["rollback", workspace, pack_id, version] =>
      print_json(@packhost.activate(workspace, pack_id, version))
    ["deactivate", workspace, pack_id] =>
      print_json(@packhost.deactivate(workspace, pack_id))
    _ =>
      println(
        "moonbook pack usage:\n  moonbook pack list\n  moonbook pack enable <extension> [root]\n  moonbook pack inspect <source>\n  moonbook pack install <source> <workspace> [host-profile.json]\n  moonbook pack active [workspace]\n  moonbook pack project <workspace> <pack-id>\n  moonbook pack verify <workspace> <pack-id> <version>\n  moonbook pack activate <workspace> <pack-id> <version>\n  moonbook pack rollback <workspace> <pack-id> <version>\n  moonbook pack deactivate <workspace> <pack-id>",
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
      println("moonbook book init failed: \{error}")
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
      println("moonbook book clean failed: \{error}")
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
      println("moonbook book load failed: \{error}")
      return
    }
  }
  println(book.to_json().stringify(indent=2))
}

///|
async fn run_test(root : String) -> Unit {
  let book = @driver.load(root) catch {
    error => {
      println("moonbook book test failed: \{error}")
      return
    }
  }
  let rust_blocks = book.count_rust_code_blocks()
  println("discovered \{rust_blocks} rust fenced code blocks")
}

///|
fn moongate_startup_ready_message(base_url : String) -> String {
  "MoonGate available at \{base_url}; suite telemetry endpoint enabled"
}

///|
fn moongate_startup_unavailable_message(
  base_url : String,
  error : String,
) -> String {
  "MoonGate unavailable at \{base_url}; continuing as standalone Moonbook: \{error}"
}

///|
async fn print_moongate_startup_status() -> Unit {
  let client = @moongate.discover()
  match client.health() {
    Ok(_) => println(moongate_startup_ready_message(client.base_url()))
    Err(error) =>
      println(moongate_startup_unavailable_message(client.base_url(), error))
  }
}

///|
async fn run_serve(args : Array[String]) -> Unit {
  let options = match @moonwiki.parse_serve_args(args) {
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
  let server = @moonwiki.Server::new(options.hostname, options.port) catch {
    error => {
      println("moonbook serve failed: \{error}")
      return
    }
  }
  println("serving \{build_dir}")
  let serving_url = "http://\{options.hostname}:\{server.port()}"
  println("listening on \{serving_url}")
  @async.with_task_group(group => {
    group.spawn_bg(
      () => print_moongate_startup_status(),
      no_wait=true,
      allow_failure=true,
    )
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
    let src_dir = moonbook_cmd_path(options.root)
      .join(moonbook_cmd_path(book.config.book.src))
      .to_string()
    let config_path = moonbook_cmd_path(options.root)
      .join(moonbook_cmd_path("book.toml"))
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
  let src_dir = moonbook_cmd_path(options.root)
    .join(moonbook_cmd_path(book.config.book.src))
    .to_string()
  let config_path = moonbook_cmd_path(options.root)
    .join(moonbook_cmd_path("book.toml"))
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
    let index_path = moonbook_cmd_path(
        @driver.resolved_build_dir(options.root, book.config),
      )
      .join(moonbook_cmd_path("index.html"))
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
  println("moonbook wiki extension accept [root] <goal>")
  println("moonbook wiki extension tasks [root] <goal>")
  println("moonbook wiki extension context [root] <goal> [--task <task-id>]")
  println("moonbook wiki extension persist [root] <result.json>")
  println("moonbook wiki extension catalog [root]")
  println("moonbook wiki extension summary [root]")
  println("moonbook wiki extension health [root]")
  println("moonbook build [root]")
  println(
    "moonbook serve [root] [-n hostname] [-p port] [-d dest-dir] [-o] [--watcher poll|native]",
  )
  println("moonbook watch [root] [-d dest-dir] [-o] [--watcher poll|native]")
  println("moonbook version")
}

///|
async fn write_live_reload_token(build_dir : String) -> Unit {
  let token_path = moonbook_cmd_path(build_dir)
    .join(moonbook_cmd_path(@moonwiki.live_reload_token_file))
    .to_string()
  let token_parent = moonbook_cmd_path(token_path).dirname().to_string()
  @fsx.make_directory(token_parent, recursive=true, exists_ok=true) catch {
    _ => ()
  }
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
  if moonbook_cmd_path(dest_dir).is_absolute() {
    moonbook_cmd_path(dest_dir).normalize().to_string()
  } else {
    match @env.current_dir() {
      Some(current_dir) =>
        moonbook_cmd_path(current_dir)
        .join(moonbook_cmd_path(dest_dir))
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
