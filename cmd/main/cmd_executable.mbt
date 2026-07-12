///|
async fn run_executable(args : Array[String]) -> Unit {
  match args {
    ["compile", root, document_path] => {
      let record = @wiki.compile_executable_document_file(root, document_path) catch {
        error => {
          println("moonbook executable compile failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(record)
    }
    ["compile-goal", workspace, book_id, goal_path, revision, recorded_at] => {
      let record = @wiki.compile_goal_file(
        workspace, book_id, goal_path, revision, recorded_at,
      ) catch {
        error => {
          println("moonbook executable compile-goal failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(record)
    }
    [
      "prepare-unattended",
      workspace,
      book_id,
      revision,
      gate_executable,
      worker_executable,
      model,
    ] => {
      let record = @wiki.prepare_goal_unattended_runtime(
        workspace, book_id, revision, gate_executable, worker_executable, model,
      ) catch {
        error => {
          println("moonbook executable prepare-unattended failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(record)
    }
    _ =>
      println(
        "moonbook executable usage:\n  moonbook executable compile <book-root> <document.json>\n  moonbook executable compile-goal <workspace> <book-id> <goal.txt> <revision> <recorded-at>\n  moonbook executable prepare-unattended <workspace> <book-id> <revision> <gate-executable> <worker-executable> <model>",
      )
  }
}
