///|
async fn main {
  let args = @env.args()
  match args[1:] {
    ["book", .. book_args] => run_book(book_args.to_owned())
    ["bookkeeper", .. bookkeeper_args] =>
      run_bookkeeper(bookkeeper_args.to_owned())
    ["pack", .. pack_args] => run_pack(pack_args.to_owned())
    ["skill", .. skill_args] => run_skill(skill_args.to_owned())
    ["doctor", .. doctor_args] => run_doctor(doctor_args.to_owned())
    ["wiki", .. wiki_args] => run_wiki(wiki_args.to_owned())
    ["build", root] => run_build(root)
    ["build"] => run_build(".")
    ["serve", .. serve_args] => run_serve(serve_args.to_owned())
    ["watch", .. watch_args] => run_watch(watch_args.to_owned())
    ["version"] => println(@core.moonbook_version)
    _ => print_usage()
  }
}

///|
fn[T : ToJson] print_json(value : T) -> Unit {
  println(value.to_json().stringify(indent=2))
}

///|
