///|
fn reconstruct(diff : @page_compare.PageTextDiff) -> (String, String) {
  let before = StringBuilder()
  let after = StringBuilder()
  for line in diff.lines {
    if line.kind != "add" {
      before.write_string(line.text)
    }
    if line.kind != "remove" {
      after.write_string(line.text)
    }
  }
  (before.to_string(), after.to_string())
}

///|
test "compare complete policy revisions with insertions and deletions" {
  let before = "# Refund policy\nWindow: 14 days\nContact support\n"
  let after = "# Refund policy\nWindow: 30 days\nKeep receipt\nContact support\n"
  let diff = @page_compare.compare_page_text(before, after)
  assert_eq(diff.unchanged, 2)
  assert_eq(diff.removed, 1)
  assert_eq(diff.added, 2)
  assert_eq(diff.lines[1].kind, "remove")
  assert_eq(diff.lines[1].before_line, Some(2))
  assert_eq(diff.lines[2].kind, "add")
  assert_eq(diff.lines[2].after_line, Some(2))
  assert_eq(reconstruct(diff), (before, after))
}

///|
test "comparison preserves Unicode carriage returns trailing blanks and final newlines" {
  for
    before in [
      "", "\n", "a", "a\n", "a\r\n", "a\r", "東京 🌙\n\n", "same\nrepeat\nsame\n",
    ] {
    for
      after in [
        "", "\n", "a", "a\n", "a\r\n", "東京 🌙\n\n", "same\nsame\nrepeat\n",
      ] {
      let diff = @page_compare.compare_page_text(before, after)
      assert_eq(reconstruct(diff), (before, after))
      assert_eq(diff.before_lines, diff.unchanged + diff.removed)
      assert_eq(diff.after_lines, diff.unchanged + diff.added)
      if before == after {
        assert_eq(diff.added + diff.removed, 0)
      }
    }
  }
  let ending = @page_compare.compare_page_text("x", "x\n")
  assert_eq(ending.added, 1)
  assert_eq(ending.removed, 1)
}

///|
test "comparison ambiguity chooses removals first and aligns insertions" {
  let diff = @page_compare.compare_page_text("a\nb\n", "b\na\n")
  assert_eq(diff.lines[0].kind, "remove")
  assert_eq(diff.lines[1].kind, "equal")
  assert_eq(diff.lines[2].kind, "add")
  let insert = @page_compare.compare_page_text("a\nb\n", "new\na\nb\n")
  assert_eq(insert.added, 1)
  assert_eq(insert.removed, 0)
  assert_eq(insert.lines[1].before_line, Some(1))
  assert_eq(insert.lines[1].after_line, Some(2))
}

///|
test "comparison enforces complete-page bounds before alignment" {
  assert_true(
    (try? @page_compare.compare_page_text("x".repeat(262145), "")) is Err(_),
  )
  assert_true(
    (try? @page_compare.compare_page_text("", "x\n".repeat(1001))) is Err(_),
  )
  let bounded = @page_compare.compare_page_text(
    "x\n".repeat(1000),
    "x\n".repeat(1000),
  )
  assert_eq(bounded.unchanged, 1000)
  let large = "x".repeat(262144)
  assert_eq(
    reconstruct(@page_compare.compare_page_text(large, "")),
    (large, ""),
  )
}
