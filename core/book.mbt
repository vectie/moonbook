///|
pub let mdbook_version : String = "0.5.2"

///|
pub struct Book {
  items : Array[BookItem]
} derive(Show, ToJson, FromJson)

///|
pub enum BookItem {
  Chapter(Chapter)
  Separator
  PartTitle(String)
} derive(Show, ToJson, FromJson)

///|
pub struct Chapter {
  name : String
  content : String
  number : SectionNumber?
  sub_items : Array[BookItem]
  path : String?
  source_path : String?
  parent_names : Array[String]
} derive(Show, ToJson, FromJson)

///|
pub struct SectionNumber {
  items : Array[Int]
} derive(Show, ToJson, FromJson)

///|
pub fn new() -> Book {
  { items: [] }
}

///|
pub fn new_with_items(items : Array[BookItem]) -> Book {
  { items, }
}

///|
pub fn Book::push_item(self : Book, item : BookItem) -> Unit {
  self.items.push(item)
}

///|
pub fn Book::iter(self : Book) -> Array[BookItem] {
  let flattened : Array[BookItem] = []
  flatten_items(self.items, flattened)
  flattened
}

///|
fn flatten_items(items : Array[BookItem], flattened : Array[BookItem]) -> Unit {
  for item in items {
    match item {
      Chapter(chapter) => {
        flattened.push(item)
        flatten_items(chapter.sub_items, flattened)
      }
      _ => flattened.push(item)
    }
  }
}

///|
pub fn Book::chapters(self : Book) -> Array[Chapter] {
  let chapters : Array[Chapter] = []
  collect_chapters(self.items, chapters)
  chapters
}

///|
fn collect_chapters(items : Array[BookItem], chapters : Array[Chapter]) -> Unit {
  for item in items {
    match item {
      Chapter(chapter) => {
        if !chapter.is_draft_chapter() {
          chapters.push(chapter)
        }
        collect_chapters(chapter.sub_items, chapters)
      }
      _ => ()
    }
  }
}

///|
pub fn Book::for_each_mut(self : Book, f : (BookItem) -> BookItem) -> Book {
  { items: map_items(self.items, f) }
}

///|
fn map_items(
  items : Array[BookItem],
  f : (BookItem) -> BookItem,
) -> Array[BookItem] {
  let mapped : Array[BookItem] = []
  for item in items {
    let next = match item {
      Chapter(chapter) =>
        Chapter({ ..chapter, sub_items: map_items(chapter.sub_items, f) })
      _ => item
    }
    mapped.push(f(next))
  }
  mapped
}

///|
pub fn Book::for_each_chapter_mut(
  self : Book,
  f : (Chapter) -> Chapter,
) -> Book {
  { items: map_chapter_items(self.items, f) }
}

///|
fn map_chapter_items(
  items : Array[BookItem],
  f : (Chapter) -> Chapter,
) -> Array[BookItem] {
  let mapped : Array[BookItem] = []
  for item in items {
    match item {
      Chapter(chapter) => {
        let nested = {
          ..chapter,
          sub_items: map_chapter_items(chapter.sub_items, f),
        }
        if nested.is_draft_chapter() {
          mapped.push(Chapter(nested))
        } else {
          mapped.push(Chapter(f(nested)))
        }
      }
      _ => mapped.push(item)
    }
  }
  mapped
}

///|
pub fn SectionNumber::new(items : Array[Int]) -> SectionNumber {
  { items, }
}

///|
pub fn chapter(
  name : String,
  content : String,
  number? : SectionNumber? = None,
  sub_items? : Array[BookItem] = [],
  path? : String? = None,
  source_path? : String? = None,
  parent_names? : Array[String] = [],
) -> Chapter {
  { name, content, number, sub_items, path, source_path, parent_names }
}

///|
pub fn item_chapter(chapter : Chapter) -> BookItem {
  Chapter(chapter)
}

///|
pub fn item_separator() -> BookItem {
  Separator
}

///|
pub fn item_part_title(title : String) -> BookItem {
  PartTitle(title)
}

///|
pub fn SectionNumber::to_string(self : SectionNumber) -> String {
  if self.items.is_empty() {
    "0"
  } else {
    let builder = StringBuilder::new()
    for item in self.items {
      builder.write_string(item.to_string())
      builder.write_char('.')
    }
    builder.to_string()
  }
}

///|
pub fn Chapter::new(
  name : String,
  content : String,
  path : String,
  parent_names : Array[String],
) -> Chapter {
  {
    name,
    content,
    number: None,
    sub_items: [],
    path: Some(path),
    source_path: Some(path),
    parent_names,
  }
}

///|
pub fn Chapter::new_draft(
  name : String,
  parent_names : Array[String],
) -> Chapter {
  {
    name,
    content: "",
    number: None,
    sub_items: [],
    path: None,
    source_path: None,
    parent_names,
  }
}

///|
pub fn Chapter::is_draft_chapter(self : Chapter) -> Bool {
  self.path is None
}

///|
pub fn Chapter::display(self : Chapter) -> String {
  match self.number {
    Some(number) => number.to_string() + " " + self.name
    None => self.name
  }
}

///|
test "book iter depth-first" {
  let book = new_with_items([
    PartTitle("Part 1"),
    Chapter({
      ..Chapter::new("A", "a", "a.md", []),
      sub_items: [Chapter(Chapter::new("B", "b", "b.md", ["A"]))],
    }),
  ])
  assert_eq(book.iter().length(), 3)
}

///|
test "book chapters skip draft" {
  let book = new_with_items([
    Chapter(Chapter::new_draft("Draft", [])),
    Chapter(Chapter::new("Real", "# hi", "real.md", [])),
  ])
  assert_eq(book.chapters().length(), 1)
}
