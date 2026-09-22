///|
// Portable and evolving-agent lifecycle commands.

async fn run_agent(args : Array[String]) -> Unit {
  match args {
    ["pack"] => run_agent_pack(".", "1.0.0", None)
    ["pack", root] => run_agent_pack(root, "1.0.0", None)
    ["pack", root, version] => run_agent_pack(root, version, None)
    ["pack", root, version, output] =>
      run_agent_pack(root, version, Some(output))
    ["inspect", bundle] =>
      print_json(@agent.inspect_agent_bundle(bundle)) catch {
        error => {
          println("moonbook agent inspect failed: \{error}")
          @sys.exit(1)
        }
      }
    ["verify", bundle] => {
      let result = @agent.verify_agent_bundle(bundle)
      print_json(result)
      if !result.ok {
        @sys.exit(1)
      }
    }
    ["diff", left, right] =>
      print_json(@agent.diff_agent_bundles(left, right)) catch {
        error => {
          println("moonbook agent diff failed: \{error}")
          @sys.exit(1)
        }
      }
    ["merge", bundle, root] => run_agent_merge(bundle, root)
    ["import", bundle, root] =>
      print_json(@agent.import_agent_bundle(bundle, root)) catch {
        error => {
          println("moonbook agent import failed: \{error}")
          @sys.exit(1)
        }
      }
    ["upgrade", bundle, root] =>
      print_json(@agent.upgrade_agent_bundle(bundle, root)) catch {
        error => {
          println("moonbook agent upgrade failed: \{error}")
          @sys.exit(1)
        }
      }
    ["rollback", root, receipt] =>
      print_json(@agent.rollback_agent_bundle(root, receipt)) catch {
        error => {
          println("moonbook agent rollback failed: \{error}")
          @sys.exit(1)
        }
      }
    _ => {
      print_agent_usage()
      @sys.exit(2)
    }
  }
}

///|
async fn run_agent_pack(
  root : String,
  version : String,
  output : String?,
) -> Unit {
  let path = match output {
    Some(output_path) =>
      @agent.pack_agent(root, version~, output=output_path) catch {
        error => {
          println("moonbook agent pack failed: \{error}")
          @sys.exit(1)
          return
        }
      }
    None =>
      @agent.pack_agent(root, version~) catch {
        error => {
          println("moonbook agent pack failed: \{error}")
          @sys.exit(1)
          return
        }
      }
  }
  println("agent bundle: \{path}")
}

///|
async fn run_agent_merge(bundle : String, root : String) -> Unit {
  let plan = @agent.plan_agent_merge(bundle, root) catch {
    error => {
      println("moonbook agent merge failed: \{error}")
      @sys.exit(1)
      return
    }
  }
  let path = @agent.write_agent_merge_plan(bundle, root)
  print_json(plan)
  println("merge plan: \{path}")
  if !plan.protected_conflicts.is_empty() {
    println("protected conflicts require inspection before agent upgrade")
  }
}

///|
fn print_agent_usage() -> Unit {
  println("moonbook agent pack [root] [version] [output]")
  println("moonbook agent inspect <bundle>")
  println("moonbook agent verify <bundle>")
  println("moonbook agent diff <left-bundle> <right-bundle>")
  println("moonbook agent merge <bundle> <book>")
  println("moonbook agent import <bundle> <new-book>")
  println("moonbook agent upgrade <bundle> <book>")
  println("moonbook agent rollback <book> <receipt>")
}
