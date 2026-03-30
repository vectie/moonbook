///|
pub struct Summary {
  title : String?
  prefix_chapters : Array[SummaryItem]
  numbered_chapters : Array[SummaryItem]
  suffix_chapters : Array[SummaryItem]
} derive(Show, ToJson, FromJson)

///|
pub struct Link {
  name : String
  location : String?
  number : @core.SectionNumber?
  nested_items : Array[SummaryItem]
} derive(Show, ToJson, FromJson)

///|
pub enum SummaryItem {
  Link(Link)
  Separator
  PartTitle(String)
} derive(Show, ToJson, FromJson)

///|
pub fn parse_summary(summary : String) -> Summary raise {
  let mut title : String? = None
  let prefix_chapters : Array[SummaryItem] = []
  let numbered_chapters : Array[SummaryItem] = []
  let suffix_chapters : Array[SummaryItem] = []
  let stack : Array[(Int, Link)] = []
  let mut seen_numbered = false
  let mut in_suffix = false
  let mut current_numbers : Array[Int] = []
  for raw_line in summary.split("\n") {
    let line = raw_line.to_string()
    let trimmed = line.trim().to_string()
    if trimmed.is_empty() {
      continue
    }
    if trimmed.has_prefix("<!--") {
      continue
    }
    if title is None && trimmed.has_prefix("# ") {
      title = Some(trimmed[2:].trim().to_string())
      continue
    }
    if trimmed.has_prefix("# ") {
      flush_stack(
        stack, prefix_chapters, numbered_chapters, suffix_chapters, seen_numbered,
        in_suffix,
      )
      if in_suffix {
        fail("Suffix chapters cannot be followed by a list")
      }
      seen_numbered = true
      numbered_chapters.push(PartTitle(trimmed[2:].trim().to_string()))
      current_numbers = []
      continue
    }
    if trimmed == "---" {
      flush_stack(
        stack, prefix_chapters, numbered_chapters, suffix_chapters, seen_numbered,
        in_suffix,
      )
      if seen_numbered {
        in_suffix = true
      } else {
        prefix_chapters.push(Separator)
      }
      current_numbers = []
      continue
    }
    if trimmed.has_prefix("## ") {
      continue
    }
    let bullet = trimmed.has_prefix("- ") || trimmed.has_prefix("* ")
    let depth = indent_depth(line)
    let link_line = if bullet {
      trimmed[2:].trim().to_string()
    } else {
      trimmed
    }
    let link = parse_link_line(link_line) catch { _ => continue }
    if bullet {
      seen_numbered = true
      if in_suffix {
        fail("Suffix chapters cannot be followed by a list")
      }
      while stack.length() > depth {
        finalize_top(stack, numbered_chapters)
      }
      if stack.length() == depth {
        if current_numbers.length() > depth {
          current_numbers = current_numbers[:depth].to_array()
        }
        let next = next_number(current_numbers, depth)
        current_numbers = next.copy()
        let numbered = { ..link, number: Some(@core.SectionNumber::new(next)) }
        stack.push((depth, numbered))
      } else {
        fail("Invalid SUMMARY nesting")
      }
    } else {
      flush_stack(
        stack, prefix_chapters, numbered_chapters, suffix_chapters, seen_numbered,
        in_suffix,
      )
      if seen_numbered {
        in_suffix = true
        suffix_chapters.push(Link(link))
      } else {
        prefix_chapters.push(Link(link))
      }
    }
  }
  flush_stack(
    stack, prefix_chapters, numbered_chapters, suffix_chapters, seen_numbered, in_suffix,
  )
  check_duplicate_files(prefix_chapters, {})
  check_duplicate_files(numbered_chapters, {})
  check_duplicate_files(suffix_chapters, {})
  { title, prefix_chapters, numbered_chapters, suffix_chapters }
}

///|
fn indent_depth(line : String) -> Int {
  let mut spaces = 0
  for c in line {
    if c == ' ' {
      spaces += 1
    } else {
      break
    }
  }
  spaces / 2
}

///|
fn parse_link_line(line : String) -> Link raise {
  let open_name = match line.find("[") {
    Some(index) => index
    None => fail("missing [")
  }
  let close_name = match line.find("]") {
    Some(index) => index
    None => fail("missing ]")
  }
  let open_path = match line.find("(") {
    Some(index) => index
    None => fail("missing (")
  }
  let close_path = match line.rev_find(")") {
    Some(index) => index
    None => fail("missing )")
  }
  let location_text = line[open_path + 1:close_path].to_string()
  {
    name: line[open_name + 1:close_name].to_string(),
    location: if location_text.is_empty() {
      None
    } else {
      Some(location_text)
    },
    number: None,
    nested_items: [],
  }
}

///|
fn check_duplicate_files(
  items : Array[SummaryItem],
  seen : Map[String, Unit],
) -> Unit raise {
  for item in items {
    match item {
      Link(link) => {
        match link.location {
          Some(location) =>
            if seen.contains(location) {
              fail("Duplicate file in SUMMARY.md: \"\{location}\"")
            } else {
              seen[location] = ()
            }
          None => ()
        }
        check_duplicate_files(link.nested_items, seen)
      }
      _ => ()
    }
  }
}

///|
fn next_number(current : Array[Int], depth : Int) -> Array[Int] {
  let next = if current.length() > depth {
    current[:depth + 1].to_array()
  } else {
    current.copy()
  }
  while next.length() <= depth {
    next.push(0)
  }
  next[depth] = next[depth] + 1
  next
}

///|
fn finalize_top(
  stack : Array[(Int, Link)],
  destination : Array[SummaryItem],
) -> Unit {
  let (_, node) = stack.pop().unwrap()
  if stack.is_empty() {
    destination.push(Link(node))
  } else {
    let (_, parent) = stack[stack.length() - 1]
    parent.nested_items.push(Link(node))
    stack[stack.length() - 1] = (stack[stack.length() - 1].0, parent)
  }
}

///|
fn flush_stack(
  stack : Array[(Int, Link)],
  _prefix_chapters : Array[SummaryItem],
  numbered_chapters : Array[SummaryItem],
  suffix_chapters : Array[SummaryItem],
  seen_numbered : Bool,
  in_suffix : Bool,
) -> Unit {
  while !stack.is_empty() {
    if in_suffix && seen_numbered {
      finalize_top(stack, suffix_chapters)
    } else {
      finalize_top(stack, numbered_chapters)
    }
  }
}

///|
test "parse summary with parts and nesting" {
  let summary = parse_summary(
    "# Summary\n[Intro](intro.md)\n# Part One\n- [Chapter 1](chapter-1.md)\n  - [Section](section.md)\n",
  )
  assert_eq(summary.prefix_chapters.length(), 1)
  assert_eq(summary.numbered_chapters.length(), 2)
}

///|
test "parse summary ignores subheaders inside numbered chapters" {
  let summary = parse_summary(
    "# Summary\n- [First](first.md)\n## Subheading\n- [Second](second.md)\n",
  )
  assert_eq(summary.numbered_chapters.length(), 2)
}

///|
test "parse summary allows draft chapters with empty destinations" {
  let summary = parse_summary("# Summary\n- [Draft]()\n")
  match summary.numbered_chapters[0] {
    Link(link) => assert_eq(link.location, None)
    _ => fail("expected a link")
  }
}

///|
test "parse summary rejects duplicate files" {
  let err = try? parse_summary(
    "# Summary\n- [A](./a.md)\n  - [Again](./a.md)\n",
  )
  match err {
    Err(_) => ()
    Ok(_) => fail("expected duplicate-file failure")
  }
}
