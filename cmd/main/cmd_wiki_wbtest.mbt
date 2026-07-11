///|
async test "keeper submit parser preserves explicit inline execution" {
  let parsed = parse_wiki_keeper_submit_args([
    "/tmp/book", "keeper/jobs/research.json", "--confirm", "--inline", "--home",
    "/tmp/suite", "--moonclaw", "/tmp/moonclaw",
  ])
  assert_true(parsed.confirm)
  assert_true(parsed.inline)
  assert_true(parsed.home == Some("/tmp/suite"))
  assert_eq(parsed.cwd, "/tmp/book")
  assert_eq(parsed.moonclaw_root, "/tmp/moonclaw")
}
