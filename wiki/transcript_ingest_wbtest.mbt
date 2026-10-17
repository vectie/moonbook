///|
fn transcript_vtt_fixture() -> Bytes {
  let early = StringBuilder()
  for index in 0..<32 {
    let second = if index < 10 {
      "0" + index.to_string()
    } else {
      index.to_string()
    }
    early.write_string(
      "\nbackground-\{index}\n00:00:\{second}.000 --> 00:00:\{second}.900\n<v Alex>Earlier workshop background.\n",
    )
  }
  @utf8.encode(
    "\u{FEFF}WEBVTT - Synthetic Aurora interview\r\nKind: captions\r\nLanguage: en\r\n\r\nNOTE internal editorial note\r\nNOT_A_SPOKEN_CLAIM\r\n\r\nSTYLE\r\n::cue { color: red; }\r\n\r\nREGION\r\nid:bottom\r\n" +
    early.to_string().replace_all(old="\n", new="\r\n") +
    "\r\ncustomer-feedback\r\n00:12:34.500 --> 00:12:40.000 align:start position:10%\r\n<v.customer Mei &amp; Lin>跨团队复盘发现支持不足。\r\nOrchid escalation desk closes Friday. 🚀</v>\r\n\r\n00:12:39.000 --> 00:12:42.000\r\n<v Alex><b>Preserve</b> the overlap &lt;example&gt; and ``` as quoted evidence.\r\n",
  )
}

///|
test "VTT reads complete timed cues voices wrapped Unicode BOM CRLF settings and overlapping speech" {
  let cues = parse_transcript(transcript_vtt_fixture(), true)
  assert_eq(cues.length(), 34)
  assert_eq(cues[32].start, "00:12:34.500")
  assert_eq(cues[32].end, "00:12:40.000")
  assert_eq(
    cues[32].text,
    "Mei & Lin: 跨团队复盘发现支持不足。 Orchid escalation desk closes Friday. 🚀",
  )
  assert_true(
    cues[33].text.contains("Alex: Preserve the overlap <example> and ```"),
  )
  assert_false(cues.any(cue => cue.text.contains("NOT_A_SPOKEN_CLAIM")))
  let short = parse_transcript(
    @utf8.encode(
      "WEBVTT\n\n00:01.200 --> 01:02.300\n<v Mei>One <00:02.000><i>two</i> &amp; three\n",
    ),
    true,
  )
  assert_eq(short[0].start, "00:00:01.200")
  assert_eq(short[0].end, "00:01:02.300")
  assert_eq(short[0].text, "Mei: One two & three")
}

///|
test "SRT preserves supplied speaker labels and export order while projecting standard timecodes" {
  let cues = parse_transcript(
    @utf8.encode(
      "\u{FEFF}7\r00:10:00,001 --> 00:10:01,999\rMei: <i>Migration</i> needs\ran owner.\r\r12\r00:09:00,000 --> 00:10:02,000\rAlex: Keep the earlier offset; &amp; no chronology inference.\r",
    ),
    false,
  )
  assert_eq(cues.length(), 2)
  assert_eq(cues[0].start, "00:10:00.001")
  assert_eq(cues[0].text, "Mei: Migration needs an owner.")
  assert_eq(cues[1].start, "00:09:00.000")
  assert_true(cues[1].text.contains("& no chronology"))
  assert_eq(
    transcript_plain_text("<script>literal</script> &amp;lt;b&amp;gt;", true),
    "<script>literal</script> &lt;b&gt;",
  )
}

///|
test "transcript rejects malformed timing empty bodies invalid UTF8 and bounded cue counts" {
  for
    input in [
      "not VTT\n\n00:00.000 --> 00:01.000\nBody",
      "WEBVTT\n00:00.000 --> 00:01.000\nBody",
      "WEBVTT\n\nNOTE only a comment",
      "WEBVTT\n\nid without timing",
      "WEBVTT\n\n00:61.000 --> 01:02.000\nBody",
      "WEBVTT\n\n00:01.000 --> 00:01.000\nBody",
      "WEBVTT\n\n00:02.000 --> 00:01.000\nBody",
      "WEBVTT\n\n00:00.00 --> 00:01.000\nBody",
      "WEBVTT\n\n100:00:00.000 --> 100:00:01.000\nBody",
      "WEBVTT\n\n00:00.000 --> 00:01.000\n<b></b>",
      "WEBVTT\n\n00:00.000 --> 00:01.000\nNUL\u{0000}",
      "WEBVTT\n\n00:00.000 --> 00:01.000\n" + "x".repeat(16385),
      "WEBVTT\n\n" + "00:00.000 --> 00:01.000\nBody\n\n".repeat(5001),
    ] {
    assert_true(
      (Ok(parse_transcript(@utf8.encode(input), true)) catch {
        error => Err(error)
      })
      is Err(_),
    )
  }
  for
    input in [
      "00:00:00,000 --> 00:00:01,000\nNo index", "one\n00:00:00,000 --> 00:00:01,000\nInvalid index",
      "1\n00:00:00.000 --> 00:00:01.000\nWrong separator", "1\n00:00:00,000 --> 00:00:01,000 align:start\nSettings",
      "1\n00:00,000 --> 00:01,000\nMissing hour",
    ] {
    assert_true(
      (Ok(parse_transcript(@utf8.encode(input), false)) catch {
        error => Err(error)
      })
      is Err(_),
    )
  }
  assert_true(
    (Ok(parse_transcript(Bytes::from_array([0xFF, 0x00]), true)) catch {
      error => Err(error)
    })
    is Err(_),
  )
}

///|
async test "transcript ingest retains exact files searches late timed speech and appends repeat snapshots" {
  let root = @fs.realpath(@fs.tmpdir(prefix="book-transcript-"))
  defer @fs.rmdir(root, recursive=true)
  ignore(init_workspace(root))
  let input = root + "/Aurora interview.VTT"
  let bytes = transcript_vtt_fixture()
  @fsx.write_bytes(input, bytes, create=0o644)
  let imported = ingest_source(root, input)
  assert_eq(@fsx.read_bytes(imported.raw_path), bytes)
  let page = @fsx.read_file(imported.page_path)
  assert_true(page.contains("../../raw/imported/transcript.vtt"))
  assert_true(page.contains("````text\n"))
  assert_false(page.contains("NOT_A_SPOKEN_CLAIM"))
  let citation = relative_to_root(imported.page_path, root)
  for term in ["跨团队复盘", "Orchid escalation desk", "Mei & Lin", "🚀"] {
    let query = query_wiki(root, term)
    assert_true(query.citations.contains(citation), msg=term)
    assert_true(
      query.excerpts.any(item => {
        item.citation == citation &&
        item.excerpt.contains(term) &&
        item.excerpt.contains("00:12:34.500")
      }),
      msg=query.to_json().stringify(),
    )
  }
  let repeated = ingest_source(root, input)
  assert_false(repeated.raw_path == imported.raw_path)
  assert_false(repeated.page_path == imported.page_path)
  assert_eq(@fsx.read_file(imported.page_path), page)
  let srt = "1\n00:01:20,500 --> 00:01:24,000\nAlex: Cedar onboarding needs a named owner.\n"
  @fsx.write_to_file(root + "/Cedar.srt", srt, create=0o644)
  let srt_imported = ingest_source(root, "Cedar.srt")
  assert_eq(@fsx.read_file(srt_imported.raw_path), srt)
  assert_true(
    query_wiki(root, "Cedar onboarding").excerpts.any(item => {
      item.excerpt.contains("00:01:20.500")
    }),
  )
  if @env.get_env_var("MOONBOOK_TRANSCRIPT_EVIDENCE") is Some(path) {
    @fsx.write_bytes(path + "/synthetic-interview.vtt", bytes, create=0o644)
    @fsx.write_to_file(path + "/synthetic-onboarding.srt", srt, create=0o644)
    @fsx.write_to_file(
      path + "/srt-source.md",
      @fsx.read_file(srt_imported.page_path),
      create=0o644,
    )
    @fsx.write_to_file(path + "/transcript-source.md", page, create=0o644)
    @fsx.write_to_file(
      path + "/transcript-query.json",
      query_wiki(root, "跨团队复盘").to_json().stringify(indent=2),
      create=0o644,
    )
  }
}

///|
async test "malformed transcripts keep raw originals without partial source pages and oversized input is rejected" {
  let root = @fs.tmpdir(prefix="book-transcript-bad-")
  defer @fs.rmdir(root, recursive=true)
  ignore(init_workspace(root))
  let before = @fsx.list_directory(root + "/wiki/sources")
  let malformed = "WEBVTT\n\n00:00.000 --> 00:01.000\nValid first cue\n\nbroken second cue\n"
  @fsx.write_to_file(root + "/bad.vtt", malformed, create=0o644)
  try ingest_source(root, "bad.vtt") catch {
    error => assert_true("\{error}".contains("original retained at"))
  } noraise {
    _ => fail("expected transcript error")
  }
  assert_eq(@fsx.read_file(root + "/raw/imported/transcript.vtt"), malformed)
  assert_eq(@fsx.list_directory(root + "/wiki/sources"), before)
  let raw_before = @fsx.list_directory(root + "/raw/imported")
  @fsx.write_to_file(root + "/big.srt", "x".repeat(1048577), create=0o644)
  try ingest_source(root, "big.srt") catch {
    error => assert_true("\{error}".contains("exceeds 1 MiB"))
  } noraise {
    _ => fail("expected size rejection")
  }
  assert_eq(@fsx.list_directory(root + "/raw/imported"), raw_before)
}

///|
async test "ordinary transcript CLI handles omitted dot explicit roots searches timed quotes and exits on malformed input" {
  guard @env.get_env_var("MOONBOOK_TRANSCRIPT_CLI") is Some(executable) else {
    return
  }
  let root = @fs.tmpdir(prefix="book-transcript-cli-")
  defer @fs.rmdir(root, recursive=true)
  ignore(init_workspace(root))
  @fsx.write_bytes(
    root + "/interview.vtt",
    transcript_vtt_fixture(),
    create=0o644,
  )
  for
    args in [
      ["wiki", "ingest", "interview.vtt"],
      ["wiki", "ingest", ".", "interview.vtt"],
      ["wiki", "ingest", root, "interview.vtt"],
    ] {
    let (code, output, errors) = @process.collect_output(
      executable,
      args,
      cwd=root,
    )
    assert_eq(code, 0, msg=output.text() + errors.text())
    assert_true(output.text().contains("ingested Transcript: interview"))
  }
  let (code, output, _) = @process.collect_output(
    executable,
    ["wiki", "query", root, "跨团队复盘"],
    cwd=root,
  )
  assert_eq(code, 0)
  assert_true(output.text().contains("00:12:34.500"))
  assert_true(output.text().contains("Mei & Lin"))
  @fsx.write_to_file(root + "/bad.srt", "1\ninvalid timing\nBody", create=0o644)
  let (bad_code, bad_output, _) = @process.collect_output(
    executable,
    ["wiki", "ingest", "bad.srt"],
    cwd=root,
  )
  assert_eq(bad_code, 1)
  assert_true(bad_output.text().contains("original retained at"))
  if @env.get_env_var("MOONBOOK_TRANSCRIPT_EVIDENCE") is Some(path) {
    @fsx.write_to_file(
      path + "/transcript-cli-query.md",
      output.text(),
      create=0o644,
    )
    @fsx.write_to_file(
      path + "/transcript-cli-error.txt",
      bad_output.text(),
      create=0o644,
    )
  }
}
