///|
fn company_docx_fixture(body : String) -> Bytes raise {
  let document_package : @opc.Package = { parts: [], }
  let document_package = document_package
    .replace_text(
      "[Content_Types].xml", "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>",
    )
    .replace_text(
      "_rels/.rels", "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>",
    )
    .replace_text(
      "word/document.xml",
      "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>" +
      body +
      "</w:body></w:document>",
    )
  Bytes::from_array(@opc.save(document_package)[:])
}

///|
async test "DOCX company knowledge searches heading CJK paragraph and later table while retaining attachment" {
  let root = "/tmp/moonbook-docx-company-knowledge-\{@async.now().to_int()}"
  ignore(init_workspace(root))
  let paragraphs = StringBuilder()
  for index in 0..<30 {
    paragraphs.write_string(
      "<w:p><w:r><w:t>Company background paragraph \{index}.</w:t></w:r></w:p>",
    )
  }
  let bytes = company_docx_fixture(
    "<w:p><w:pPr><w:pStyle w:val=\"Heading1\"/></w:pPr><w:r><w:t>Aurora Company Handbook</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>跨部门知识共享：客户反馈每周归档。</w:t></w:r></w:p>" +
    paragraphs.to_string() +
    "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Department</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Owner</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:p><w:r><w:t>Orchid escalation desk</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Customer success</w:t></w:r></w:p></w:tc></w:tr></w:tbl>",
  )
  let input = root + "/company-handbook.DOCX"
  @fsx.write_bytes(input, bytes, create=0o644)
  let result = ingest_source(root, input)
  assert_true(result.imported)
  assert_eq(result.title, "Aurora Company Handbook")
  assert_eq(@fsx.read_bytes(result.raw_path), bytes)
  let page = @fsx.read_file(result.page_path)
  assert_true(page.contains("../../raw/imported/company-handbook.DOCX"))
  assert_true(page.contains("MoonLeaf DOCX plain text"))
  assert_true(
    page.contains("跨部门知识共享：客户反馈每周归档。"),
  )
  assert_true(page.contains("Orchid escalation desk"))
  let citation = relative_to_root(result.page_path, root)
  for
    term in [
      "Aurora Company Handbook", "跨部门知识共享", "Orchid escalation desk",
    ] {
    let query = query_wiki(root, term)
    assert_true(query.citations.contains(citation))
    assert_true(
      query.excerpts.any(excerpt => {
        excerpt.citation == citation && excerpt.excerpt.contains(term)
      }),
    )
  }
  // Reopening the retained attachment exercises the real binary, not extracted text.
  let reopened = @docx.read(
    @opc.open(@fsx.read_bytes(result.raw_path).to_fixedarray()),
  )
  assert_true(reopened.plain_text().contains("Orchid escalation desk"))
  println("DOCX functional proof workspace: \{root}")
}

///|
async test "DOCX without readable text remains available as its original attachment" {
  let root = "/tmp/moonbook-docx-empty-text-\{@async.now().to_int()}"
  ignore(init_workspace(root))
  let input = root + "/scanned-document.docx"
  let bytes = company_docx_fixture("<w:p/>")
  @fsx.write_bytes(input, bytes, create=0o644)
  let result = ingest_source(root, input)
  assert_eq(@fsx.read_bytes(result.raw_path), bytes)
  assert_true(
    @fsx.read_file(result.page_path).contains(
      "No readable document text was found",
    ),
  )
}
