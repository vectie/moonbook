///|
fn bibtex_fixture() -> String {
  (
    #|A synthetic local bibliography, not real research.
    #|@comment{Preserve this original note with {nested braces}.}
    #|@STRING{venue = "Synthetic " # {Service Research}}
    #|@Article{Aurora2026,
    #|  title = {Aurora {MoonBit} onboarding study},
    #|  author = {Lin, Mei and Rivera, Ana and {Example Research Group}},
    #|  year = 2026,
    #|  month = sep,
    #|  journal = VENUE,
    #|  abstract = {Eight teams completed guided setup.
    #|Counterevidence must still be reviewed. 跨团队复盘。},
    #|  doi = {10.0000/synthetic.aurora},
    #|  note = {All data is synthetic. ``` <script>unsafe()</script>},
    #|  custom_field = {Preserved additional metadata},
    #|}
    #|@techreport(AuroraCounter,
    #|  title = "Aurora capacity counterstudy",
    #|  author = "Chen, Li and Kurt G{\"o}del",
    #|  abstract = "Only five teams received " # {follow-up support.},
    #|  crossref = {Aurora2026}
    #|)
  )
}

///|
async fn bibtex_test_root(name : String) -> String {
  match @env.get_env_var("MOONBOOK_BIBTEX_EVIDENCE") {
    Some(base) => {
      let root = base + "/" + name
      @fsx.make_directory(root, recursive=true, exists_ok=true)
      root
    }
    None => @fs.tmpdir(prefix="moonbook-bibtex-")
  }
}

///|
test "BibTeX parser preserves citation keys complete metadata nested values and abbreviations" {
  let records = parse_bibtex(bibtex_fixture())
  assert_eq(records.length(), 2)
  assert_eq(records[0].key, "Aurora2026")
  assert_eq(records[0].kind, "article")
  assert_eq(records[0].title, "Aurora {MoonBit} onboarding study")
  let text = bibtex_record_text(records[0])
  assert_true(text.contains("journal: Synthetic Service Research"))
  assert_true(text.contains("month: September"))
  assert_true(
    text.contains(
      "author: Lin, Mei and Rivera, Ana and {Example Research Group}",
    ),
  )
  assert_true(
    text.contains("Counterevidence must still be reviewed. 跨团队复盘。"),
  )
  assert_true(text.contains("custom_field: Preserved additional metadata"))
  assert_true(
    bibtex_record_text(records[1]).contains(
      "Only five teams received follow-up support.",
    ),
  )
  assert_true(bibtex_record_text(records[1]).contains("Kurt G{\\\"o}del"))
  assert_true(bibtex_record_text(records[1]).contains("crossref: Aurora2026"))
  assert_eq(
    parse_bibtex("@misc{k,title={東京 🌙}}\n")[0].title,
    "東京 🌙",
  )
}

///|
test "BibTeX parser rejects repairable malformed unsupported and ambiguous input" {
  for
    input in [
      "",
      "@article{k,title={Unclosed}",
      "@article{k,title=undefined}",
      "@article{k,title={A} title={B}}",
      "@article{k,title={A},TITLE={B}}",
      "@article{k,title={A}} @article{K,title={B}}",
      "@article{k,author={No title}}",
      "@article{,title={No key}}",
      "@article{two keys,title={Bad key}}",
      "@article{k,title=\"Unbalanced }\"}",
      "@preamble{\"\\newcommand{\\x}{x}\"} @article{k,title={A}}",
      "@string{s={A}} @string{S={B}} @article{k,title=s}",
      "@article{k,title={" + "x".repeat(401) + "}}",
      "@article{k,title={A},abstract={" + "x".repeat(131073) + "}}",
    ] {
    assert_true(
      (try? parse_bibtex(input)) is Err(_),
      msg="Expected rejection: " + input[:input.length().min(80)].to_owned(),
    )
  }
  let many = Array::makei(501, i => "@misc{k\{i},title={A}}")
  assert_true((try? parse_bibtex(many.join("\n"))) is Err(_))
  let fields = Array::makei(1000, i => "f\{i}={x}")
  assert_true(
    (try? parse_bibtex("@misc{k,title={A}," + fields.join(",") + "}")) is Err(_),
  )
  let big = "x".repeat(65536)
  assert_true(
    (try? parse_bibtex(
      "@string{s={" + big + "}} @misc{k,title={A},abstract=s#s#s}",
    ))
    is Err(_),
  )
}

///|
async test "BibTeX import reaches query full inspection and exact retained export without changing earlier pages" {
  let root = bibtex_test_root("library")
  ignore(init_workspace(root))
  let input = root + "/export [research].bib"
  let bytes = @utf8.encode(
    "\u{FEFF}" + bibtex_fixture().replace_all(old="\n", new="\r\n"),
  )
  @fsx.write_bytes(input, bytes, create=0o644)
  let imported = import_bibtex(root, input)
  assert_eq(imported.references.length(), 2)
  assert_eq(imported.references[0].citation_key, "Aurora2026")
  assert_eq(@fsx.read_bytes(imported.raw_path), bytes)
  let first = imported.references[0]
  let second = imported.references[1]
  for
    (term, reference) in [
      ("Aurora2026", first),
      ("Rivera", first),
      ("guided setup", first),
      ("跨团队复盘", first),
      ("capacity counterstudy", second),
      ("follow-up support", second),
    ] {
    let result = query_wiki(root, term)
    assert_true(
      result.citations.contains(reference.citation),
      msg="Missing query: " + term,
    )
  }
  let first_page = query_page_text(root, first.citation)
  let second_page = query_page_text(root, second.citation)
  assert_true(first_page.contains("Record number in retained export: 1"))
  assert_true(first_page.contains("````text\n"))
  assert_false(first_page.contains("Only five teams"))
  assert_true(second_page.contains("Only five teams"))
  guard query_retained_descriptor(root, first.citation, first_page)
    is Some(descriptor) else {
    fail("missing ordinary retained-source binding")
  }
  let retained = query_retained_source(
    root,
    first.citation,
    descriptor.page_digest,
  )
  assert_eq(@base64.decode(retained.bytes_base64), bytes)
  let reimported = import_bibtex(root, input)
  assert_false(reimported.raw_path == imported.raw_path)
  assert_false(reimported.references[0].citation == first.citation)
  assert_eq(query_page_text(root, first.citation), first_page)
  assert_eq(query_page_text(root, second.citation), second_page)
  @fsx.write_to_file(
    root + "/import-result.json",
    imported.to_json().stringify(indent=2),
    create=0o644,
  )
  @fsx.write_to_file(
    root + "/query-guided-setup.json",
    query_wiki(root, "guided setup").to_json().stringify(indent=2),
    create=0o644,
  )
  @fsx.write_to_file(
    root + "/retained-source.json",
    retained.to_json().stringify(indent=2),
    create=0o644,
  )
}

///|
async test "BibTeX malformed later entry preserves raw bytes without partially importing references" {
  let root = bibtex_test_root("malformed")
  ignore(init_workspace(root))
  let before = @fsx.list_directory(root + "/wiki/sources")
  let summary = @fsx.read_file(workspace_paths(root).summary_path)
  let index = @fsx.read_file(root + "/wiki/index.md")
  let input = root + "/bad.bib"
  let raw = "@article{valid,title={Good}}\n@article{bad,title={Unclosed}"
  @fsx.write_to_file(input, raw, create=0o644)
  try import_bibtex(root, input) catch {
    error => {
      assert_true("\{error}".contains("original retained at"))
      assert_true("\{error}".contains("BibTeX line"))
    }
  } noraise {
    _ => fail("expected malformed later record failure")
  }
  assert_eq(@fsx.read_file(root + "/raw/imported/references.bib"), raw)
  assert_eq(@fsx.list_directory(root + "/wiki/sources"), before)
  assert_eq(@fsx.read_file(workspace_paths(root).summary_path), summary)
  assert_eq(@fsx.read_file(root + "/wiki/index.md"), index)
  @fsx.write_bytes(input, Bytes::from_array([0xFF]), create=0o644)
  assert_true((try? import_bibtex(root, input)) is Err(_))
  assert_eq(
    @fsx.read_bytes(root + "/raw/imported/references-1.bib"),
    Bytes::from_array([0xFF]),
  )
  assert_eq(@fsx.list_directory(root + "/wiki/sources"), before)
}
