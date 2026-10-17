///|
/// A line including its original LF terminator, if present. CR is retained.
/// Added lines have no before_line; removed lines have no after_line.
pub struct PageDiffLine {
  kind : String
  before_line : Int32?
  after_line : Int32?
  text : String
} derive(ToJson)

///|
pub struct PageTextDiff {
  before_lines : Int32
  after_lines : Int32
  added : Int32
  removed : Int32
  unchanged : Int32
  lines : Array[PageDiffLine]
} derive(ToJson)

///|
fn comparison_lines(text : String) -> Array[String] raise {
  guard text.length() <= 262144 else {
    fail("Page exceeds 256 Ki UTF-16 code units")
  }
  if text.is_empty() {
    return []
  }
  let parts = text.split("\n").to_array()
  let lines : Array[String] = []
  for index, part in parts {
    if index < parts.length() - 1 {
      lines.push(part.to_owned() + "\n")
    } else if !part.is_empty() {
      lines.push(part.to_owned())
    }
  }
  guard lines.length() <= 1000 else { fail("Page exceeds 1000 lines") }
  lines
}

///|
/// Deterministic exact line alignment using longest common subsequence. All
/// lines are returned; no trimming, newline normalization, or semantic judgment.
/// Equal alternatives prefer removal before addition. Bounded to 1000 lines
/// and 256 Ki UTF-16 code units per page before quadratic alignment allocation.
pub fn compare_page_text(before : String, after : String) -> PageTextDiff raise {
  let left = comparison_lines(before)
  let right = comparison_lines(after)
  let lengths = Array::makei(left.length() + 1, _ => {
    Array::make(right.length() + 1, 0)
  })
  let mut i = left.length() - 1
  while i >= 0 {
    let mut j = right.length() - 1
    while j >= 0 {
      lengths[i][j] = if left[i] == right[j] {
        lengths[i + 1][j + 1] + 1
      } else {
        lengths[i + 1][j].max(lengths[i][j + 1])
      }
      j -= 1
    }
    i -= 1
  }
  let lines : Array[PageDiffLine] = []
  let mut added = 0
  let mut removed = 0
  let mut unchanged = 0
  let mut old = 0
  let mut new = 0
  while old < left.length() || new < right.length() {
    if old < left.length() && new < right.length() && left[old] == right[new] {
      lines.push({
        kind: "equal",
        before_line: Some(old + 1),
        after_line: Some(new + 1),
        text: left[old],
      })
      old += 1
      new += 1
      unchanged += 1
    } else if old < left.length() &&
      (new == right.length() || lengths[old + 1][new] >= lengths[old][new + 1]) {
      lines.push({
        kind: "remove",
        before_line: Some(old + 1),
        after_line: None,
        text: left[old],
      })
      old += 1
      removed += 1
    } else {
      lines.push({
        kind: "add",
        before_line: None,
        after_line: Some(new + 1),
        text: right[new],
      })
      new += 1
      added += 1
    }
  }
  {
    before_lines: left.length(),
    after_lines: right.length(),
    added,
    removed,
    unchanged,
    lines,
  }
}
