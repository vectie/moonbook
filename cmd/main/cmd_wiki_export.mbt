///|
async fn run_wiki_export_pages(args : Array[String]) -> Unit {
  let output = wiki_export_pages_output(args) catch {
    error => {
      println("moonbook wiki export-pages failed: \{error}")
      @os.exit(1)
    }
  }
  println(output)
}

///|
async fn wiki_export_pages_output(args : Array[String]) -> String {
  let json = args.last() == Some("--json")
  let positional = if json { args[:args.length() - 1].to_array() } else { args }
  guard positional.length() >= 2 else {
    fail("Usage: moonbook wiki export-pages <root> <citation>... [--json]")
  }
  let dossier = @wiki.export_wiki_pages(
    positional[0],
    positional[1:].to_array(),
  )
  if json {
    dossier.to_json().stringify(indent=2)
  } else {
    dossier.to_markdown()
  }
}
