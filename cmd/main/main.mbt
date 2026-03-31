///|
async fn main {
  let args = @env.args()
  match args[1:] {
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
        "moonbook serve usage: moonbook serve [root] [-n hostname] [-p port] [-d dest-dir]",
      )
      return
    }
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
  write_live_reload_token(build_dir)
  let server = @httpserve.Server::new(options.hostname, options.port) catch {
    error => {
      println("moonbook serve failed: \{error}")
      return
    }
  }
  println("serving \{build_dir}")
  println("listening on http://\{options.hostname}:\{server.port()}")
  @async.with_task_group(group => {
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
    @watcher.rebuild_on_change(watch_paths, async fn(changed : Array[String]) {
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
      println("moonbook watch usage: moonbook watch [root]")
      return
    }
  }
  let book = @driver.load(options.root) catch {
    error => {
      println("moonbook watch failed to load: \{error}")
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
  book.build() catch {
    error => {
      println("moonbook watch initial build failed: \{error}")
      return
    }
  }
  println("watching \{options.root}")
  @watcher.rebuild_on_change(
    watch_paths,
    async fn(changed : Array[String]) {
      let changed_text = changed.join(", ")
      println("files changed: \{changed_text}")
      let book = @driver.load(options.root) catch {
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
  println("moonbook build [root]")
  println("moonbook serve [root] [-n hostname] [-p port] [-d dest-dir]")
  println("moonbook watch [root]")
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
    Some(dest_dir) => config.with_build_dir(resolve_serve_dest_dir(dest_dir))
    None => config
  }
}

///|
fn resolve_serve_dest_dir(dest_dir : String) -> String {
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
