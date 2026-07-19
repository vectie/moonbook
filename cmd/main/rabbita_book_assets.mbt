///|
let rabbita_book_app_relative_root : String = "apps/moonbook"

///|
fn moonbook_command_module_root() -> String {
  match @env.get_env_var("MOONBOOK_MODULE_ROOT") {
    Some(root) if !root.trim().is_empty() =>
      return moonbook_cmd_path(root).normalize().to_string()
    _ => ()
  }
  let cwd = @env.current_dir().unwrap_or(".")
  let args = @env.args()
  let executable = if args.length() > 0 { args[0] } else { "" }
  if !executable.trim().is_empty() {
    let executable_path = moonbook_cmd_path(executable)
    let absolute_executable = if executable_path.is_absolute() {
      executable_path.normalize()
    } else {
      moonbook_cmd_path(cwd).join(executable_path).normalize()
    }
    let normalized = absolute_executable.to_string()
    match normalized.find("/_build/") {
      Some(index) if index > 0 => return normalized[:index].to_owned()
      _ => ()
    }
  }
  moonbook_cmd_path(cwd).normalize().to_string()
}

///|
fn rabbita_book_index_html() -> String {
  (
    #|<!doctype html>
    #|<html lang="en">
    #|  <head>
    #|    <meta charset="utf-8">
    #|    <meta name="viewport" content="width=device-width, initial-scale=1">
    #|    <meta name="color-scheme" content="light">
    #|    <title>MoonBook Rabbita</title>
    #|    <style>html,body,#app{min-height:100%;margin:0}body{background:#f8fafc}</style>
    #|  </head>
    #|  <body>
    #|    <div id="app"></div>
    #|    <script src="./main.js"></script>
    #|  </body>
    #|</html>
  )
}

///|
async fn copy_rabbita_book_runtime_file(
  source : String,
  destination : String,
) -> Unit {
  if !@fsx.exists(source) {
    fail("missing Rabbita runtime asset: \{source}")
  }
  @fsx.write_bytes(destination, @fsx.read_bytes(source), create=0o644)
}

///|
async fn ensure_rabbita_book_workspace_state(
  root : String,
  build_dir : String,
  config : @core.Config,
) -> Unit {
  let state_source = moonbook_cmd_path(build_dir)
    .join(moonbook_cmd_path("moonbook-ui-state.json"))
    .to_string()
  if !@fsx.exists(state_source) {
    let snapshot = @bookkeeper_store.replay_bookkeeper_store(root)
    let bookkeeper = @bookkeeper_store.project_bookkeeper_ui_state(
      root, snapshot,
    )
    let title = moonbook_cmd_path(root).normalize().basename().to_owned()
    let state : Json = {
      "root": moonbook_cmd_path(root).normalize().to_string(),
      "title": if title.is_blank() {
        "MoonBook"
      } else {
        title
      },
      "summary": "MoonBook workspace operator state.",
      "status_chips": [],
      "metrics": [],
      "workflow": [],
      "readiness": [],
      "review_queue": [],
      "keeper_items": [],
      "page_families": [],
      "journey": [],
      "chapters": [],
      "skill_diagnostics": {
        "total_count": 0,
        "workspace_count": 0,
        "seed_core_count": 0,
        "seed_extension_count": 0,
        "duplicate_count": 0,
        "missing_reference_count": 0,
        "warning_count": 0,
        "duplicate_names": [],
        "missing_reference_paths": [],
        "warnings": [],
      },
      "skills": [],
      "marketing_brief": {
        "source_path": "",
        "headline": "",
        "lede": "",
        "sections": [],
      },
      "research_artifacts": [],
      "research_brief": "",
      "research_long_report": "",
      "research_report": [],
      "synthesis_preview": "",
      "bookkeeper": bookkeeper.to_json(),
    }
    @fsx.write_to_file(state_source, state.stringify(indent=2), create=0o644)
  }
  let config_source = moonbook_cmd_path(build_dir)
    .join(moonbook_cmd_path("moonbook-ui-config.json"))
    .to_string()
  let live_reload_endpoint = match
    config.read("output.html.live-reload-endpoint") {
    Some(String(endpoint)) if !endpoint.is_blank() => Json::string(endpoint)
    _ => Json::null()
  }
  let client_config : Json = { "live_reload_endpoint": live_reload_endpoint }
  @fsx.write_to_file(
    config_source,
    client_config.stringify(indent=2),
    create=0o644,
  )
}

///|
async fn install_rabbita_book_operator_app(
  root : String,
  build_dir : String,
  config : @core.Config,
) -> Unit {
  ensure_rabbita_book_workspace_state(root, build_dir, config)
  let state_source = moonbook_cmd_path(build_dir)
    .join(moonbook_cmd_path("moonbook-ui-state.json"))
    .to_string()
  let module_root = moonbook_command_module_root()
  let ui_root = moonbook_cmd_path(module_root)
    .join(moonbook_cmd_path("ui/rabbita-book"))
    .to_string()
  let ui_manifest = moonbook_cmd_path(ui_root)
    .join(moonbook_cmd_path("moon.mod"))
    .to_string()
  if !@fsx.exists(ui_manifest) {
    fail(
      "MoonBook Rabbita source is unavailable at \{ui_root}; set MOONBOOK_MODULE_ROOT to the MoonBook checkout",
    )
  }
  let build_status = @process.run("moon", [
    "-C", ui_root, "build", "--target", "js", "--release",
  ])
  if build_status != 0 {
    fail("MoonBook Rabbita JS build exited with code \{build_status}")
  }
  let compiled_js = moonbook_cmd_path(ui_root)
    .join(moonbook_cmd_path("_build/js/release/build/main/main.js"))
    .to_string()
  let app_root = moonbook_cmd_path(build_dir)
    .join(moonbook_cmd_path(rabbita_book_app_relative_root))
    .to_string()
  @fsx.make_directory(app_root, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    moonbook_cmd_path(app_root)
    .join(moonbook_cmd_path("index.html"))
    .to_string(),
    rabbita_book_index_html(),
    create=0o644,
  )
  copy_rabbita_book_runtime_file(
    compiled_js,
    moonbook_cmd_path(app_root).join(moonbook_cmd_path("main.js")).to_string(),
  )
  copy_rabbita_book_runtime_file(
    state_source,
    moonbook_cmd_path(app_root)
    .join(moonbook_cmd_path("moonbook-ui-state.json"))
    .to_string(),
  )
  copy_rabbita_book_runtime_file(
    moonbook_cmd_path(build_dir)
    .join(moonbook_cmd_path("moonbook-ui-config.json"))
    .to_string(),
    moonbook_cmd_path(app_root)
    .join(moonbook_cmd_path("moonbook-ui-config.json"))
    .to_string(),
  )
}

///|
async fn build_book_with_rabbita_operator(
  root : String,
  book : @driver.MDBook,
) -> Unit {
  book.build()
  install_rabbita_book_operator_app(
    root,
    @driver.resolved_build_dir(root, book.config),
    book.config,
  )
}

///|
test "Rabbita app shell uses nested relative assets" {
  let html = rabbita_book_index_html()
  assert_true(html.contains("id=\"app\""))
  assert_true(html.contains("src=\"./main.js\""))
  assert_false(html.contains("/api/bookkeeper"))
}
