///|
fn moonbook_module_root() -> String {
  let cwd = @env.current_dir().unwrap_or(".")
  let args = @env.args()
  let executable = if args.length() > 0 { args[0] } else { "" }
  resolve_moonbook_module_root(
    cwd,
    executable,
    @env.get_env_var("MOONBOOK_MODULE_ROOT"),
  )
}

///|
fn resolve_moonbook_module_root(
  cwd : String,
  executable : String,
  configured_root : String?,
) -> String {
  match configured_root {
    Some(root) if !root.trim().is_empty() => return normalize_module_root(root)
    _ => ()
  }
  if !executable.trim().is_empty() {
    let executable_path = moonbook_wiki_path(executable)
    let absolute_executable = if executable_path.is_absolute() {
      executable_path.normalize()
    } else {
      moonbook_wiki_path(cwd).join(executable_path).normalize()
    }
    let normalized_executable = absolute_executable.to_string()
    match normalized_executable.find("/_build/") {
      Some(index) if index > 0 =>
        return normalize_module_root(normalized_executable[:index].to_owned())
      _ => ()
    }
  }
  normalize_module_root(cwd)
}

///|
fn normalize_module_root(root : String) -> String {
  moonbook_wiki_path(root).normalize().to_string()
}

///|
test "module root resolver finds source root from a development executable" {
  let root = "/tmp/moonbook-module-root"
  let executable = moonbook_wiki_path(root)
    .join(moonbook_wiki_path("_build/native/debug/build/cmd/main/main.exe"))
    .to_string()
  assert_eq(
    resolve_moonbook_module_root("/tmp/unrelated-workspace", executable, None),
    normalize_module_root(root),
  )
}

///|
test "configured module root takes precedence" {
  let root = "/tmp/moonbook-configured-root"
  assert_eq(
    resolve_moonbook_module_root(
      "/tmp/unrelated-workspace",
      "/tmp/unrelated-workspace/moonbook",
      Some(root),
    ),
    normalize_module_root(root),
  )
}
