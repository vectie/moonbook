///|
fn ris_fixture() -> String {
  "TY  - JOUR\r\nTI  - Aurora onboarding study\r\nAU  - Lin, Mei\r\nAU  - Rivera, Ana\r\nPY  - 2025\r\nT2  - Synthetic Service Research\r\nDO  - 10.0000/synthetic.aurora\r\nUR  - https://example.invalid/aurora\r\nAB  - Eight teams completed the onboarding pilot.\r\n      Cohort feedback favored guided setup.\r\nKW  - onboarding\r\nZZ  - Unmapped field remains available\r\nER  -\r\n\r\nTY  - RPRT\r\nT1  - Aurora capacity counterstudy\r\nA1  - Chen, Li\r\nY1  - 2026/09/01\r\nN2  - Counterevidence: only five teams received follow-up support.\r\n跨团队复盘发现支持不足。\r\nKW  - capacity\r\nKW  - follow-up\r\nN1  - All data in this export is synthetic.\r\nER  -\r\n"
}

///|
async test "RIS ordinary CLI resolves omitted and dot roots against its working Book" {
  guard @env.get_env_var("MOONBOOK_RIS_CLI") is Some(executable) else { return }
  let root = @fs.tmpdir(prefix="book-ris-cli-")
  defer @fs.rmdir(root, recursive=true)
  ignore(init_workspace(root))
  @fsx.write_to_file(root + "/library.ris", ris_fixture(), create=0o644)
  for
    args in [
      ["wiki", "import-ris", "library.ris"],
      ["wiki", "import-ris", ".", "library.ris"],
    ] {
    let (code, output, errors) = @process.collect_output(
      executable,
      args,
      cwd=root,
    )
    assert_eq(code, 0, msg=output.text() + errors.text())
    guard @json.parse(output.text())
      is { "raw_path": String(raw_path), "references": Array(references), .. } else {
      fail("missing ordinary CLI import result")
    }
    assert_eq(references.length(), 2)
    assert_eq(@fsx.read_file(raw_path), ris_fixture())
  }
  @fsx.write_to_file(
    root + "/bad.ris",
    "TY  - JOUR\nTI  - Incomplete\n",
    create=0o644,
  )
  let (code, output, _) = @process.collect_output(
    executable,
    ["wiki", "import-ris", "bad.ris"],
    cwd=root,
  )
  assert_eq(code, 1)
  assert_true(output.text().contains("original retained at"))
}

///|
test "RIS parser preserves repeated authors aliases multiline abstracts Unicode and unknown fields" {
  let records = parse_ris(ris_fixture())
  assert_eq(records.length(), 2)
  assert_eq(records[0].title, "Aurora onboarding study")
  assert_eq(records[1].title, "Aurora capacity counterstudy")
  let text = ris_record_text(records[0])
  assert_true(text.contains("Author [AU]: Lin, Mei"))
  assert_true(text.contains("Author [AU]: Rivera, Ana"))
  assert_true(
    text.contains(
      "Eight teams completed the onboarding pilot.\nCohort feedback favored guided setup.",
    ),
  )
  assert_true(
    text.contains("Additional field [ZZ]: Unmapped field remains available"),
  )
  assert_true(
    ris_record_text(records[1]).contains("跨团队复盘发现支持不足。"),
  )
  assert_true(
    ris_fenced_text("```\n<script>alert(1)</script>").has_prefix("````text\n"),
  )
  assert_eq(ris_markdown_title("<script>[paper]"), "&lt;script&gt;\\[paper\\]")
}

///|
test "RIS parser rejects incomplete records missing titles bad boundaries and limits" {
  for
    input in [
      "",
      "TI  - Orphan\n",
      "TY  - JOUR\nTI  - Missing end\n",
      "TY  - JOUR\nTI  - A\nTY  - JOUR\nTI  - B\nER  -\n",
      "TY  - JOUR\nAU  - No title\nER  -\n",
      "ER  -\n",
      "TY  -\nTI  - Empty type\nER  -\n",
      "TY  - JOUR\nTI  - A\nER  - bad value\n",
      "TY  - JOUR\nTI  - " + "x".repeat(401) + "\nER  -\n",
      "TY  - JOUR\nTI  - A\nAB  - " + "x".repeat(131073) + "\nER  -\n",
      "TY  - JOUR\nTI  - A\n" + "KW  - tag\n".repeat(1000) + "ER  -\n",
      "TY  - JOUR\nTI  - A\nER  -\n".repeat(501),
    ] {
    try parse_ris(input) catch {
      _ => ()
    } noraise {
      _ => fail("expected bounded RIS rejection")
    }
  }
}

///|
async test "RIS library import creates individually searchable references and preserves exact original and prior pages" {
  let root = @fs.tmpdir(prefix="book-ris-")
  defer @fs.rmdir(root, recursive=true)
  ignore(init_workspace(root))
  let input = root + "/export [research].RIS"
  let bytes = @utf8.encode("\u{FEFF}" + ris_fixture())
  @fsx.write_bytes(input, bytes, create=0o644)
  let imported = import_ris(root, input)
  assert_eq(imported.references.length(), 2)
  assert_eq(@fsx.read_bytes(imported.raw_path), bytes)
  let first = imported.references[0]
  let second = imported.references[1]
  for
    (term, reference) in [
      ("Aurora onboarding study", first),
      ("Rivera", first),
      ("synthetic.aurora", first),
      ("guided setup", first),
      ("capacity counterstudy", second),
      ("跨团队复盘", second),
    ] {
    let result = query_wiki(root, term)
    assert_true(result.citations.contains(reference.citation))
    if term != "synthetic.aurora" {
      assert_true(
        result.excerpts.any(item => {
          item.citation == reference.citation &&
          item.excerpt.to_lower().contains(term.to_lower())
        }),
        msg="Expected excerpt for " + term + ": " + result.to_json().stringify(),
      )
    }
  }
  let first_page = @fsx.read_file(first.page_path)
  let second_page = @fsx.read_file(second.page_path)
  assert_true(first_page.contains("Record number in retained export: 1"))
  assert_true(second_page.contains("Record number in retained export: 2"))
  assert_false(first_page.contains("only five teams"))
  assert_true(second_page.contains("only five teams"))
  assert_true(
    @fsx.read_file(workspace_paths(root).summary_path).contains(
      first.citation[5:],
    ),
  )
  let reimported = import_ris(root, input)
  assert_false(reimported.raw_path == imported.raw_path)
  assert_false(reimported.references[0].citation == first.citation)
  assert_eq(@fsx.read_file(first.page_path), first_page)
  assert_eq(@fsx.read_file(second.page_path), second_page)
  if @env.get_env_var("MOONBOOK_RIS_EVIDENCE") is Some(path) {
    @fsx.write_bytes(path + "/synthetic-library.ris", bytes, create=0o644)
    @fsx.write_to_file(path + "/onboarding-study.md", first_page, create=0o644)
    @fsx.write_to_file(
      path + "/capacity-counterstudy.md",
      second_page,
      create=0o644,
    )
    @fsx.write_to_file(
      path + "/import-result.json",
      imported.to_json().stringify(indent=2),
      create=0o644,
    )
    @fsx.write_to_file(
      path + "/query-guided-setup.json",
      query_wiki(root, "guided setup").to_json().stringify(indent=2),
      create=0o644,
    )
  }
}

///|
async test "RIS malformed export is retained before parse failure without adding partial source pages" {
  let root = @fs.tmpdir(prefix="book-ris-bad-")
  defer @fs.rmdir(root, recursive=true)
  ignore(init_workspace(root))
  let before = @fsx.list_directory(root + "/wiki/sources")
  let input = root + "/bad.ris"
  let raw = "TY  - JOUR\nTI  - Valid first record\nER  -\nTY  - JOUR\nTI  - Missing final ER\n"
  @fsx.write_to_file(input, raw, create=0o644)
  try import_ris(root, input) catch {
    error => assert_true("\{error}".contains("original retained at"))
  } noraise {
    _ => fail("expected incomplete export failure")
  }
  assert_eq(@fsx.read_file(root + "/raw/imported/references.ris"), raw)
  assert_eq(@fsx.list_directory(root + "/wiki/sources"), before)
  @fsx.write_bytes(input, Bytes::from_array([0xFF]), create=0o644)
  try import_ris(root, input) catch {
    error => assert_true("\{error}".contains("original retained at"))
  } noraise {
    _ => fail("expected malformed UTF-8 rejection")
  }
  assert_eq(
    @fsx.read_bytes(root + "/raw/imported/references-1.ris"),
    Bytes::from_array([0xFF]),
  )
}
