///|
async fn main {
  let args = @env.args()
  match args[1:] {
    ["book", .. book_args] => run_book(book_args.to_array())
    ["pack", .. pack_args] => run_pack(pack_args.to_array())
    ["skill", .. skill_args] => run_skill(skill_args.to_array())
    ["doctor", .. doctor_args] => run_doctor(doctor_args.to_array())
    ["wiki", .. wiki_args] => run_wiki(wiki_args.to_array())
    ["build", root] => run_build(root)
    ["build"] => run_build(".")
    ["serve", .. serve_args] => run_serve(serve_args.to_array())
    ["watch", .. watch_args] => run_watch(watch_args.to_array())
    ["init", root] => run_init(root)
    ["init"] => run_init(".")
    ["clean", root] => run_clean(root)
    ["clean"] => run_clean(".")
    ["load", root] => run_load(root)
    ["load"] => run_load(".")
    ["test", root] => run_test(root)
    ["test"] => run_test(".")
    ["version"] => println(@core.mdbook_version)
    _ => print_usage()
  }
}

///|
fn[T : ToJson] print_json(value : T) -> Unit {
  println(value.to_json().stringify(indent=2))
}

///|
