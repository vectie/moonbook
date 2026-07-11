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
    _ =>
      println(
        "moonbook executable usage: moonbook executable compile <book-root> <document.json>",
      )
  }
}
