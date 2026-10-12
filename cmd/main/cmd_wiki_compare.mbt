///|
async fn run_wiki_compare_pages(args : Array[String]) -> Unit {
  let result = compare_pages_output(args) catch {
    error => {
      println("moonbook wiki compare-pages failed: \{error}")
      @os.exit(1)
    }
  }
  println(result)
}

///|
async fn compare_pages_output(args : Array[String]) -> String {
  let json = args.last() == Some("--json")
  let positional = if json { args[:args.length() - 1].to_array() } else { args }
  let (root, before, after) = match positional {
    [before, after] => (".", before, after)
    [root, before, after] => (root, before, after)
    _ =>
      fail(
        "Usage: moonbook wiki compare-pages [root] <before-citation> <after-citation> [--json]",
      )
  }
  let comparison = @wiki.compare_wiki_pages(root, before, after)
  if json {
    comparison.to_json().stringify(indent=2)
  } else {
    comparison.to_text()
  }
}
