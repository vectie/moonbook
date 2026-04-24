///|
// Skill and Skill Hub command handlers.

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
