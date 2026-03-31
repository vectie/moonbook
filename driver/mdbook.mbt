///|
pub struct MDBook {
  root : String
  config : @core.Config
  book : @core.Book
  summary : @summary.Summary
} derive(Show, ToJson)

///|
pub struct CleanStats {
  files_removed : Int
  directories_removed : Int
  bytes_removed : Int
} derive(Show, ToJson)

///|
pub async fn load(book_root : String) -> MDBook {
  let config_path = @path.Path(book_root).join(@path.Path("book.toml"))
  let config = if @fs.path_exists(config_path.to_string()) {
    @core.from_toml(@fs.read_file_to_string(config_path.to_string()))
  } else {
    @core.default()
  }
  let src_dir = @path.Path(book_root)
    .join(@path.Path(config.book.src))
    .to_string()
  let summary_path = @path.Path(src_dir)
    .join(@path.Path("SUMMARY.md"))
    .to_string()
  let parsed_summary = @summary.parse_summary(
    @fs.read_file_to_string(summary_path),
  )
  if config.build.create_missing {
    create_missing(src_dir, parsed_summary)
  }
  let book = load_book_from_disk(parsed_summary, src_dir)
  { root: book_root, config, book, summary: parsed_summary }
}

///|
pub async fn load_with_config(
  book_root : String,
  config : @core.Config,
) -> MDBook {
  let src_dir = @path.Path(book_root)
    .join(@path.Path(config.book.src))
    .to_string()
  let summary_path = @path.Path(src_dir)
    .join(@path.Path("SUMMARY.md"))
    .to_string()
  let parsed_summary = @summary.parse_summary(
    @fs.read_file_to_string(summary_path),
  )
  if config.build.create_missing {
    create_missing(src_dir, parsed_summary)
  }
  let book = load_book_from_disk(parsed_summary, src_dir)
  { root: book_root, config, book, summary: parsed_summary }
}

///|
pub async fn init_book(
  book_root : String,
  create_gitignore? : Bool = false,
  copy_theme? : Bool = false,
  config? : @core.Config = @core.default(),
) -> MDBook {
  ignore(copy_theme)
  ensure_dir(book_root) catch {
    error => fail("init ensure_dir(root) failed: \{error}")
  }
  let src_dir = @path.Path(book_root)
    .join(@path.Path(config.book.src))
    .to_string()
  let build_dir = @path.Path(book_root)
    .join(@path.Path(config.build.build_dir))
    .to_string()
  ensure_dir(src_dir) catch {
    error => fail("init ensure_dir(src) failed: \{error}")
  }
  ensure_dir(build_dir) catch {
    error => fail("init ensure_dir(build) failed: \{error}")
  }
  let summary_path = @path.Path(src_dir)
    .join(@path.Path("SUMMARY.md"))
    .to_string()
  if !@fsx.exists(summary_path) {
    write_text_file(
      summary_path, "# Summary\n\n- [Chapter 1](./chapter_1.md)\n",
    ) catch {
      error => fail("init write SUMMARY failed: \{error}")
    }
  }
  let chapter_path = @path.Path(src_dir)
    .join(@path.Path("chapter_1.md"))
    .to_string()
  if !@fsx.exists(chapter_path) {
    write_text_file(chapter_path, "# Chapter 1\n") catch {
      error => fail("init write chapter failed: \{error}")
    }
  }
  let book_toml = @path.Path(book_root)
    .join(@path.Path("book.toml"))
    .to_string()
  write_text_file(book_toml, config_to_toml(config)) catch {
    error => fail("init write book.toml failed: \{error}")
  }
  if create_gitignore {
    write_text_file(
      @path.Path(book_root).join(@path.Path(".gitignore")).to_string(),
      config.build.build_dir + "\n",
    ) catch {
      error => fail("init write .gitignore failed: \{error}")
    }
  }
  let loaded = load(book_root) catch {
    error => fail("init reload failed: \{error}")
  }
  loaded
}

///|
pub async fn MDBook::build(self : MDBook) -> Unit {
  let preprocessed_book = preprocess_book(self.book)
  let build_dir = resolved_build_dir(self.root, self.config)
  @html.render_html(
    @html.new_render_context(
      self.root,
      build_dir,
      self.config,
      preprocessed_book,
    ),
  )
  let manifest_path = @path.Path(build_dir)
    .join(@path.Path("book.json"))
    .to_string()
  let manifest = { ..self, book: preprocessed_book }
  write_text_file(manifest_path, manifest.to_json().stringify(indent=2))
}

///|
pub fn resolved_build_dir(root : String, config : @core.Config) -> String {
  if @pathx.is_absolute(config.build.build_dir) {
    @pathx.normalize(config.build.build_dir)
  } else {
    @path.Path(root).join(@path.Path(config.build.build_dir)).to_string()
  }
}

///|
pub fn MDBook::iter(self : MDBook) -> Array[@core.BookItem] {
  self.book.iter()
}

///|
pub fn MDBook::count_rust_code_blocks(self : MDBook) -> Int {
  let mut rust_block_count = 0
  for chapter in self.book.chapters() {
    rust_block_count += fenced_code_block_count(chapter.content, "rust")
  }
  rust_block_count
}

///|
pub async fn clean_book(
  book_root : String,
  dest_dir? : String? = None,
) -> CleanStats {
  let config_path = @path.Path(book_root)
    .join(@path.Path("book.toml"))
    .to_string()
  let config = if @fs.path_exists(config_path) {
    @core.from_toml(@fs.read_file_to_string(config_path))
  } else {
    @core.default()
  }
  let target = match dest_dir {
    Some(dest_dir) => dest_dir
    None => resolved_build_dir(book_root, config)
  }
  let stats = collect_clean_stats(target)
  if @afs.exists(target) {
    @afs.rmdir(target, recursive=true)
  }
  stats
}

///|
fn load_book_from_disk(
  summary : @summary.Summary,
  src_dir : String,
) -> @core.Book raise {
  let items : Array[@core.BookItem] = []
  append_summary_items(items, summary.prefix_chapters, src_dir, [])
  append_summary_items(items, summary.numbered_chapters, src_dir, [])
  append_summary_items(items, summary.suffix_chapters, src_dir, [])
  @core.new_with_items(items)
}

///|
fn append_summary_items(
  destination : Array[@core.BookItem],
  items : Array[@summary.SummaryItem],
  src_dir : String,
  parent_names : Array[String],
) -> Unit raise {
  for item in items {
    match item {
      Link(link) => {
        let chapter = load_chapter(link, src_dir, parent_names)
        destination.push(@core.item_chapter(chapter))
      }
      Separator => destination.push(@core.item_separator())
      PartTitle(title) => destination.push(@core.item_part_title(title))
    }
  }
}

///|
fn load_chapter(
  link : @summary.Link,
  src_dir : String,
  parent_names : Array[String],
) -> @core.Chapter raise {
  let chapter = match link.location {
    Some(location) => {
      let (disk_path, chapter_path) = resolve_chapter_paths(location, src_dir)
      let content = strip_utf8_bom(@fs.read_file_to_string(disk_path))
      @core.chapter(
        link.name,
        content,
        number=link.number,
        sub_items=[],
        path=Some(chapter_path),
        source_path=Some(chapter_path),
        parent_names~,
      )
    }
    None => @core.Chapter::new_draft(link.name, parent_names)
  }
  let nested_items : Array[@core.BookItem] = []
  let nested_parent_names = parent_names.copy()
  nested_parent_names.push(link.name)
  append_summary_items(
    nested_items,
    link.nested_items,
    src_dir,
    nested_parent_names,
  )
  @core.chapter(
    chapter.name,
    chapter.content,
    number=chapter.number,
    sub_items=nested_items,
    path=chapter.path,
    source_path=chapter.source_path,
    parent_names=chapter.parent_names,
  )
}

///|
fn resolve_chapter_paths(
  location : String,
  src_dir : String,
) -> (String, String) {
  if @pathx.is_absolute(location) {
    let normalized_src = @pathx.normalize(src_dir)
    let normalized_location = @pathx.normalize(location)
    let relative = match
      normalized_location.strip_prefix(normalized_src + "/") {
      Some(path) => path.to_string()
      None => normalized_location
    }
    (normalized_location, relative)
  } else {
    let relative = @pathx.normalize(location)
    let disk_path = @path.Path(src_dir).join(@path.Path(relative)).to_string()
    (disk_path, relative)
  }
}

///|
async fn create_missing(src_dir : String, summary : @summary.Summary) -> Unit {
  create_missing_items(summary.prefix_chapters, src_dir)
  create_missing_items(summary.numbered_chapters, src_dir)
  create_missing_items(summary.suffix_chapters, src_dir)
}

///|
fn preprocess_book(book : @core.Book) -> @core.Book {
  book.for_each_mut(preprocess_book_item)
}

///|
fn preprocess_book_item(item : @core.BookItem) -> @core.BookItem {
  match item {
    Chapter(chapter) => @core.item_chapter(preprocess_chapter(chapter))
    _ => item
  }
}

///|
fn preprocess_chapter(chapter : @core.Chapter) -> @core.Chapter {
  let path = match chapter.path {
    Some(path) => Some(normalize_readme_path(path))
    None => None
  }
  @core.chapter(
    chapter.name,
    chapter.content,
    number=chapter.number,
    sub_items=chapter.sub_items,
    path~,
    source_path=chapter.source_path,
    parent_names=chapter.parent_names,
  )
}

///|
fn normalize_readme_path(path : String) -> String {
  let base = @path.Path(path)
  let ext = @pathx.ext(path).to_string()
  let stem = base.basename().to_string().replace(old=ext, new="").to_string()
  if stem.to_lower() == "readme" {
    @pathx.join(@pathx.dirname(path), "index" + ext)
  } else {
    path
  }
}

///|
async fn create_missing_items(
  items : Array[@summary.SummaryItem],
  src_dir : String,
) -> Unit {
  for item in items {
    match item {
      Link(link) => {
        match link.location {
          Some(location) => {
            let filename = @path.Path(src_dir)
              .join(@path.Path(location))
              .to_string()
            if !@fsx.exists(filename) {
              ensure_parent_dir(filename)
              write_text_file(filename, "# " + escape_html(link.name) + "\n")
            }
          }
          None => ()
        }
        create_missing_items(link.nested_items, src_dir)
      }
      _ => ()
    }
  }
}

///|
async fn ensure_dir(path : String) -> Unit {
  if @fsx.exists(path) {
    return
  }
  @fsx.make_directory(path, recursive=true, exists_ok=true)
}

///|
async fn ensure_parent_dir(path : String) -> Unit {
  let parent = @pathx.dirname(path).to_string()
  if parent != "." && parent != path {
    ensure_dir(parent)
  }
}

///|
async fn write_text_file(path : String, content : String) -> Unit {
  @fsx.write_to_file(path, content, create=0o666)
}

///|
fn config_to_toml(config : @core.Config) -> String {
  let builder = StringBuilder::new()
  builder.write_string("[book]\n")
  match config.book.title {
    Some(title) => builder.write_string("title = \"" + title + "\"\n")
    None => ()
  }
  builder.write_string("authors = [")
  for i = 0; i < config.book.authors.length(); i = i + 1 {
    if i > 0 {
      builder.write_string(", ")
    }
    builder.write_string("\"" + config.book.authors[i] + "\"")
  }
  builder.write_string("]\n")
  builder.write_string("src = \"" + config.book.src + "\"\n")
  builder.write_string("multilingual = ")
  builder.write_string(if config.book.multilingual { "true" } else { "false" })
  builder.write_string("\n\n[build]\n")
  builder.write_string("build-dir = \"" + config.build.build_dir + "\"\n")
  builder.write_string("create-missing = ")
  builder.write_string(
    if config.build.create_missing {
      "true"
    } else {
      "false"
    },
  )
  builder.write_string("\n")
  builder.write_string("use-default-preprocessors = ")
  builder.write_string(
    if config.build.use_default_preprocessors {
      "true"
    } else {
      "false"
    },
  )
  builder.write_string("\n")
  builder.to_string()
}

///|
fn fenced_code_block_count(content : String, language : String) -> Int {
  let mut count = 0
  let lines = content.split("\n").map(fn(line) { line.to_string() }).to_array()
  for line in lines {
    let trimmed = line.trim().to_string()
    if trimmed == "```" + language || trimmed == "```" + language + ",ignore" {
      count += 1
    }
  }
  count
}

///|
fn strip_utf8_bom(content : String) -> String {
  let bytes = @encoding/utf8.encode(content)
  if bytes.length() >= 3 &&
    bytes[0] == 0xEF &&
    bytes[1] == 0xBB &&
    bytes[2] == 0xBF {
    content[3:].to_string()
  } else {
    content
  }
}

///|
fn escape_html(text : String) -> String {
  text
  .replace(old="&", new="&amp;")
  .replace(old="<", new="&lt;")
  .replace(old=">", new="&gt;")
  .replace(old="\"", new="&quot;")
  .to_string()
}

///|
fn collect_clean_stats(path : String) -> CleanStats raise {
  if !@fs.path_exists(path) {
    return { files_removed: 0, directories_removed: 0, bytes_removed: 0 }
  }
  if @fs.is_file(path) {
    let bytes = @fs.read_file_to_bytes(path).length()
    return { files_removed: 1, directories_removed: 0, bytes_removed: bytes }
  }
  let mut files_removed = 0
  let mut directories_removed = 1
  let mut bytes_removed = 0
  for child in @fs.read_dir(path) {
    let child_path = @path.Path(path).join(@path.Path(child)).to_string()
    let nested = collect_clean_stats(child_path)
    files_removed += nested.files_removed
    directories_removed += nested.directories_removed
    bytes_removed += nested.bytes_removed
  }
  { files_removed, directories_removed, bytes_removed }
}

///|
test "normalize readme paths to index" {
  assert_eq(normalize_readme_path("./README.md"), "index.md")
  assert_eq(normalize_readme_path("guide/ReadMe.md"), "guide/index.md")
  assert_eq(normalize_readme_path("./chapter_1.md"), "./chapter_1.md")
}

///|
test "preprocess book rewrites chapter paths but preserves source paths" {
  let nested = @core.chapter(
    "Nested",
    "# Nested\n",
    path=Some("guide/README.md"),
    source_path=Some("guide/README.md"),
    parent_names=["Chapter 1"],
  )
  let chapter = @core.chapter(
    "Chapter 1",
    "# Chapter 1\n",
    path=Some("./README.md"),
    source_path=Some("./README.md"),
    sub_items=[@core.item_chapter(nested)],
  )
  let book = @core.new_with_items([@core.item_chapter(chapter)])
  let chapters = preprocess_book(book).chapters()
  assert_eq(chapters.length(), 2)
  assert_eq(chapters[0].path, Some("index.md"))
  assert_eq(chapters[0].source_path, Some("./README.md"))
  assert_eq(chapters[1].path, Some("guide/index.md"))
  assert_eq(chapters[1].source_path, Some("guide/README.md"))
}

///|
test "load chapter from absolute path stores source path relative to src dir" {
  let cwd = @env.current_dir().unwrap()
  let src_dir = @path.Path(cwd).join(@path.Path("summary")).to_string()
  let absolute = @path.Path(src_dir).join(@path.Path("summary.mbt")).to_string()
  let parsed = @summary.parse_summary("# Summary\n- [Summary](\{absolute})\n")
  let chapter = load_chapter(
    match parsed.numbered_chapters[0] {
      Link(link) => link
      _ => fail("expected numbered chapter link")
    },
    src_dir,
    [],
  )
  assert_eq(chapter.path, Some("summary.mbt"))
  assert_eq(chapter.source_path, Some("summary.mbt"))
  assert_true(chapter.content.contains("pub struct Summary"))
}

///|
test "load chapter preserves separators and nested parent names" {
  let cwd = @env.current_dir().unwrap()
  let src_dir = cwd
  let parsed = @summary.parse_summary(
    "# Summary\n- [Driver](driver/mdbook.mbt)\n  - [Summary](summary/summary.mbt)\n  ---\n  - [Core](core/book.mbt)\n",
  )
  let chapter = load_chapter(
    match parsed.numbered_chapters[0] {
      Link(link) => link
      _ => fail("expected numbered chapter link")
    },
    src_dir,
    [],
  )
  assert_eq(chapter.sub_items.length(), 3)
  match chapter.sub_items[0] {
    Chapter(nested) => assert_eq(nested.parent_names, ["Driver"])
    _ => fail("expected nested chapter")
  }
  assert_true(chapter.sub_items[1] is Separator)
  match chapter.sub_items[2] {
    Chapter(nested) => assert_eq(nested.parent_names, ["Driver"])
    _ => fail("expected nested chapter")
  }
}
