///|
fn email_fixture() -> Bytes {
  let late = "跨团队复盘发现支持不足。 Orchid escalation desk closes Friday."
  let plain = "Synthetic email for research.\n" +
    "Earlier background paragraph.\n".repeat(32) +
    late +
    "\n```\n<script>example only</script>\n"
  @utf8.encode(
    "From: =?UTF-8?Q?Lin=2C_Mei?= <mei@example.invalid>\r\n" +
    "To: Founder <founder@example.invalid>,\r\n\tResearch <research@example.invalid>\r\n" +
    "Subject: =?UTF-8?B?QXVyb3Jh?=\r\n =?utf-8?Q?_support_follow-up?=\r\n" +
    "Date: Thu, 08 Oct 2026 10:00:00 +0000\r\nMessage-ID: <aurora-42@example.invalid>\r\nMIME-Version: 1.0\r\n" +
    "Content-Type: multipart/mixed; boundary=\"outer;42\"\r\n\r\nPreamble is not evidence.\r\n--outer;42\r\n" +
    "Content-Type: multipart/alternative;\r\n boundary=inner\r\n\r\n--inner\r\n" +
    "Content-Type: text/html; charset=utf-8\r\n\r\n<script>HTML_ONLY_NEVER_INDEX</script>\r\n" +
    "--inner\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n\r\n" +
    @base64.encode(@utf8.encode(plain)) +
    "\r\n--inner--\r\n--outer;42\r\n" +
    "Content-Type: text/plain; name=private.txt\r\nContent-Disposition: attachment; filename=private.txt\r\n\r\nATTACHMENT_ONLY_NEVER_INDEX\r\n--outer;42--\r\nEpilogue is not evidence.\r\n",
  )
}

///|
test "EML chooses inline plain alternative decodes folded attribution and ignores attachment HTML and preamble" {
  let email = parse_email(email_fixture())
  assert_eq(email.title, "Aurora support follow-up")
  assert_true(
    email.attribution.contains("From: Lin, Mei <mei@example.invalid>"),
  )
  assert_true(
    email.attribution.contains(
      "To: Founder <founder@example.invalid>, Research <research@example.invalid>",
    ),
  )
  assert_true(
    email.attribution.contains("Message-ID: <aurora-42@example.invalid>"),
  )
  assert_true(email.body.contains("跨团队复盘发现支持不足。"))
  assert_false(email.body.contains("HTML_ONLY_NEVER_INDEX"))
  assert_false(email.body.contains("ATTACHMENT_ONLY_NEVER_INDEX"))
  assert_false(email.body.contains("Preamble"))
  assert_false(email.body.contains("Epilogue"))
}

///|
test "EML supports quoted printable soft lines UTF8 8bit and binary ignored attachments" {
  let email = parse_email(
    @utf8.encode(
      "Subject: Re: =?UTF-8?Q?caf=C3=A9?=\nContent-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: quoted-printable\n\nThe caf=C3=A9 sup=\nport works.=0A=E5=AE=A2=E6=88=B7=E5=8F=8D=E9=A6=88\n",
    ),
  )
  assert_eq(email.title, "Re: café")
  assert_true(email.body.contains("café support works.\n客户反馈"))
  let unicode_header = parse_email(
    @utf8.encode("Subject: =?UTF-8?Q?=E5=AE=A2=E6=88=B7?=\n\nBody"),
  )
  assert_eq(unicode_header.title, "客户")
  let plain = parse_email(
    @utf8.encode(
      "From: Mei <mei@example.invalid>\nContent-Transfer-Encoding: 8bit\n\n客户反馈 retained",
    ),
  )
  assert_eq(plain.title, "Email without subject")
  assert_eq(plain.body, "客户反馈 retained")
  let binary = email_bytes(
    email_byte_text(
      @utf8.encode(
        "Subject: Binary attachment\nContent-Type: multipart/mixed; boundary=x\n\n--x\nContent-Type: text/plain\n\nReadable body\n--x\nContent-Disposition: attachment\n\n",
      ),
    ) +
    "\u{00FF}\u{0000}\n--x--\n",
  )
  assert_true(parse_email(binary).body.contains("Readable body"))
  let named = parse_email(
    @utf8.encode(
      "Subject: Extended filename\nContent-Type: multipart/mixed; boundary=x\n\n--x\nContent-Type: text/plain\n\nVisible body\n--x\nContent-Type: text/plain; name*=utf-8''private.txt\n\nSECRET_NAMED_ATTACHMENT\n--x\nContent-Type: text/plain\nContent-Disposition: inline; filename*0*=utf-8''private.txt\n\nSECRET_INLINE_ATTACHMENT\n--x--\n",
    ),
  )
  assert_true(named.body.contains("Visible body"))
  assert_false(named.body.contains("SECRET_"))
}

///|
test "EML malformed and unsupported messages reject without inventing usable text" {
  for
    input in [
      "Subject: No separator",
      " folded without a header\n\nBody",
      "Subject: A\nSubject: B\n\nBody",
      "Subject: =?utf-8?Q?broken\n\nBody",
      "Subject: =?utf-8?Q?bad=0Aheader?=\n\nBody",
      "Subject: " + "x".repeat(401) + "\n\nBody",
      "Content-Type: text/html\n\n<p>HTML only</p>",
      "Content-Type: text/plain; charset=iso-8859-1\n\nBody",
      "Content-Type: text/plain; charset=us-ascii\n\n客户",
      "Content-Type: text/plain\nContent-Transfer-Encoding: base64\n\n%%%",
      "Content-Transfer-Encoding: quoted-printable\n\ninvalid=GG",
      "Content-Transfer-Encoding: quoted-printable\n\ninvalid=",
      "Content-Type: multipart/mixed; boundary=x\n\n--x\n\nBody",
      "Content-Type: multipart/mixed; boundary=x\n\n--x--\n",
      "Content-Type: multipart/mixed; boundary=x\n\n--x\nContent-Disposition: attachment\n\nOnly attachment\n--x--",
      "Content-Type: text/plain; charset=\"utf-8\n\nBody",
      "Content-Type: text/plain; charset=utf-8; charset=us-ascii\n\nBody",
      "Subject: Blank\n\n   \n",
      "Subject: NUL\n\n\u{0000}",
      "X-Test: " + "x".repeat(65536) + "\n\nBody",
      "X-Test: one\n".repeat(201) + "\nBody",
      "Content-Type: multipart/mixed; boundary=x\n\n" +
      "--x\n\nBody\n".repeat(65) +
      "--x--\n",
    ] {
    try parse_email(@utf8.encode(input)) catch {
      _ => ()
    } noraise {
      _ =>
        fail(
          "expected EML rejection: " +
          input[:Int32::min(input.length(), 100)].to_owned(),
        )
    }
  }
  let mut deep = "Content-Type: text/plain\n\nBody"
  for level in 0..<9 {
    let boundary = "level" + level.to_string()
    deep = "Content-Type: multipart/mixed; boundary=" +
      boundary +
      "\n\n--" +
      boundary +
      "\n" +
      deep +
      "\n--" +
      boundary +
      "--\n"
  }
  assert_true(
    (Ok(parse_email(@utf8.encode(deep))) catch { error => Err(error) })
    is Err(_),
  )
  assert_true(
    (Ok(parse_email(Bytes::from_array([0xFF, 0x0A, 0x0A, 0xFF]))) catch {
      error => Err(error)
    })
    is Err(_),
  )
}

///|
async test "EML ingest retains exact original appends repeats and searches attribution and late Unicode body" {
  let root = @fs.realpath(@fs.tmpdir(prefix="book-eml-"))
  defer @fs.rmdir(root, recursive=true)
  ignore(init_workspace(root))
  let input = root + "/export [support].EML"
  let bytes = email_fixture()
  @fsx.write_bytes(input, bytes, create=0o644)
  let result = ingest_source(root, input)
  assert_eq(@fsx.read_bytes(result.raw_path), bytes)
  assert_eq(result.title, "Aurora support follow-up")
  let page = @fsx.read_file(result.page_path)
  assert_true(page.contains("../../raw/imported/message.eml"))
  assert_true(page.contains("````text\n"))
  assert_false(page.contains("HTML_ONLY_NEVER_INDEX"))
  assert_false(page.contains("ATTACHMENT_ONLY_NEVER_INDEX"))
  let citation = relative_to_root(result.page_path, root)
  for
    term in [
      "Aurora support follow-up", "mei@example.invalid", "aurora-42", "Orchid escalation desk",
      "跨团队复盘",
    ] {
    let query = query_wiki(root, term)
    assert_true(query.citations.contains(citation), msg=term)
    assert_true(
      query.excerpts.any(item => {
        item.citation == citation && item.excerpt.contains(term)
      }),
      msg=term + ": " + query.to_json().stringify(),
    )
  }
  let repeated = ingest_source(root, input)
  assert_false(repeated.raw_path == result.raw_path)
  assert_false(repeated.page_path == result.page_path)
  assert_eq(@fsx.read_file(result.page_path), page)
  if @env.get_env_var("MOONBOOK_EML_EVIDENCE") is Some(path) {
    @fsx.write_bytes(path + "/synthetic-support.eml", bytes, create=0o644)
    @fsx.write_to_file(path + "/support-source.md", page, create=0o644)
    @fsx.write_to_file(
      path + "/import-result.json",
      result.to_json().stringify(indent=2),
      create=0o644,
    )
    @fsx.write_to_file(
      path + "/late-body-query.json",
      query_wiki(root, "跨团队复盘").to_json().stringify(indent=2),
      create=0o644,
    )
  }
}

///|
async test "EML failures preserve raw bytes but create no partial page and oversized inputs stay outside Book" {
  let root = @fs.tmpdir(prefix="book-eml-bad-")
  defer @fs.rmdir(root, recursive=true)
  ignore(init_workspace(root))
  let input = root + "/bad.eml"
  let before = @fsx.list_directory(root + "/wiki/sources")
  for
    bytes in [
      @utf8.encode("Subject: No separator"),
      Bytes::from_array([0xFF, 0x00]),
      @utf8.encode("Content-Type: text/html\n\nHTML only"),
    ] {
    @fsx.write_bytes(input, bytes, create=0o644)
    try ingest_source(root, input) catch {
      error => assert_true("\{error}".contains("original retained at"))
    } noraise {
      _ => fail("expected EML failure")
    }
  }
  assert_eq(
    @fsx.read_bytes(root + "/raw/imported/message-1.eml"),
    Bytes::from_array([0xFF, 0x00]),
  )
  assert_eq(@fsx.list_directory(root + "/wiki/sources"), before)
  let raw_before = @fsx.list_directory(root + "/raw/imported")
  @fsx.write_to_file(input, "x".repeat(2097153), create=0o644)
  try ingest_source(root, input) catch {
    error => assert_true("\{error}".contains("exceeds 2 MiB"))
  } noraise {
    _ => fail("expected size limit")
  }
  assert_eq(@fsx.list_directory(root + "/raw/imported"), raw_before)
}

///|
async test "EML ordinary CLI ingests omitted dot and explicit roots queries body and reports failures" {
  guard @env.get_env_var("MOONBOOK_EML_CLI") is Some(executable) else { return }
  let root = @fs.tmpdir(prefix="book-eml-cli-")
  defer @fs.rmdir(root, recursive=true)
  ignore(init_workspace(root))
  @fsx.write_bytes(root + "/support.eml", email_fixture(), create=0o644)
  for
    args in [
      ["wiki", "ingest", "support.eml"],
      ["wiki", "ingest", ".", "support.eml"],
      ["wiki", "ingest", root, "support.eml"],
    ] {
    let (code, output, errors) = @process.collect_output(
      executable,
      args,
      cwd=root,
    )
    assert_eq(code, 0, msg=output.text() + errors.text())
    assert_true(output.text().contains("ingested Aurora support follow-up"))
  }
  let (code, output, _) = @process.collect_output(
    executable,
    ["wiki", "query", root, "跨团队复盘"],
    cwd=root,
  )
  assert_eq(code, 0)
  assert_true(output.text().contains("跨团队复盘"))
  assert_true(
    output.text().contains("wiki/sources/email-aurora-support-follow-up"),
  )
  @fsx.write_to_file(root + "/bad.eml", "Subject: Missing body", create=0o644)
  let (code, output, _) = @process.collect_output(
    executable,
    ["wiki", "ingest", "bad.eml"],
    cwd=root,
  )
  assert_eq(code, 1)
  assert_true(output.text().contains("original retained at"))
}
