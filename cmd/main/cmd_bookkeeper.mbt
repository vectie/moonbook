///|
async fn run_bookkeeper(args : Array[String]) -> Unit {
  match args {
    ["reflect", root, observation_path] => {
      let record = @wiki.reflect_bookkeeper_file(root, observation_path) catch {
        error => {
          println("moonbook bookkeeper reflect failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(record)
    }
    ["promote", root, reflection_id] => {
      let paths = @wiki.promote_bookkeeper_procedures(root, reflection_id) catch {
        error => {
          println("moonbook bookkeeper promote failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(paths)
    }
    _ =>
      println(
        "moonbook bookkeeper usage:\n  moonbook bookkeeper reflect <book-root> <observation.json>\n  moonbook bookkeeper promote <book-root> <reflection-id>",
      )
  }
}
