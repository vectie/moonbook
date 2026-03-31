///|
pub struct BookConfig {
  title : String?
  authors : Array[String]
  src : String
  language : String?
  multilingual : Bool
  description : String?
} derive(Show, ToJson)

///|
pub struct BuildConfig {
  build_dir : String
  create_missing : Bool
  use_default_preprocessors : Bool
} derive(Show, ToJson)

///|
pub struct RustConfig {
  edition : String?
} derive(Show, ToJson)

///|
pub struct Config {
  book : BookConfig
  build : BuildConfig
  rust : RustConfig
  output : Json
  preprocessor : Json
} derive(Show, ToJson)

///|
pub fn default() -> Config {
  {
    book: {
      title: None,
      authors: [],
      src: "src",
      language: None,
      multilingual: false,
      description: None,
    },
    build: {
      build_dir: "book",
      create_missing: false,
      use_default_preprocessors: true,
    },
    rust: { edition: None },
    output: {},
    preprocessor: {},
  }
}

///|
pub fn from_toml(src : String) -> Config raise {
  let parsed = parse_toml_like(src)
  from_json(parsed)
}

///|
pub fn from_json(json : Json) -> Config raise {
  let object = match json {
    Object(object) => object
    _ => fail("Config root must be a TOML table")
  }
  {
    book: decode_book_config(object.get("book")),
    build: decode_build_config(object.get("build")),
    rust: decode_rust_config(object.get("rust")),
    output: object.get("output").unwrap_or(Json::object({})),
    preprocessor: object.get("preprocessor").unwrap_or(Json::object({})),
  }
}

///|
fn decode_book_config(value : Json?) -> BookConfig {
  let object = json_object(value)
  {
    title: json_string(object, "title"),
    authors: json_string_array(object, "authors"),
    src: json_string(object, "src").unwrap_or("src"),
    language: json_string(object, "language"),
    multilingual: json_bool(object, "multilingual").unwrap_or(false),
    description: json_string(object, "description"),
  }
}

///|
fn decode_build_config(value : Json?) -> BuildConfig {
  let object = json_object(value)
  {
    build_dir: json_string(object, "build-dir").unwrap_or("book"),
    create_missing: json_bool(object, "create-missing").unwrap_or(false),
    use_default_preprocessors: json_bool(object, "use-default-preprocessors").unwrap_or(
      true,
    ),
  }
}

///|
fn decode_rust_config(value : Json?) -> RustConfig {
  let object = json_object(value)
  { edition: json_string(object, "edition") }
}

///|
fn json_object(value : Json?) -> Map[String, Json] {
  match value {
    Some(Object(object)) => object
    _ => {}
  }
}

///|
fn json_string(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ =>
      if key.contains("-") {
        json_string(object, key.replace(old="-", new="_").to_string())
      } else {
        None
      }
  }
}

///|
fn json_bool(object : Map[String, Json], key : String) -> Bool? {
  match object.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ =>
      if key.contains("-") {
        json_bool(object, key.replace(old="-", new="_").to_string())
      } else {
        None
      }
  }
}

///|
fn json_string_array(object : Map[String, Json], key : String) -> Array[String] {
  match object.get(key) {
    Some(Array(values)) =>
      values.filter_map(fn(value) {
        match value {
          String(value) => Some(value)
          _ => None
        }
      })
    _ => []
  }
}

///|
pub fn Config::contains_key(self : Config, name : String) -> Bool {
  self.read(name) is Some(_)
}

///|
pub fn Config::read(self : Config, name : String) -> Json? {
  match name.strip_prefix("output.") {
    Some(key) => read_json_path(self.output, split_dotted_path(key.to_string()))
    None =>
      match name.strip_prefix("preprocessor.") {
        Some(key) =>
          read_json_path(self.preprocessor, split_dotted_path(key.to_string()))
        None => None
      }
  }
}

///|
pub fn Config::set(self : Config, name : String, value : Json) -> Config {
  match name.strip_prefix("output.") {
    Some(key) =>
      {
        ..self,
        output: write_json_path(
          self.output,
          split_dotted_path(key.to_string()),
          value,
        ),
      }
    None =>
      match name.strip_prefix("preprocessor.") {
        Some(key) =>
          {
            ..self,
            preprocessor: write_json_path(
              self.preprocessor,
              split_dotted_path(key.to_string()),
              value,
            ),
          }
        None => self
      }
  }
}

///|
pub fn Config::with_build_dir(self : Config, build_dir : String) -> Config {
  {
    book: self.book,
    build: {
      build_dir,
      create_missing: self.build.create_missing,
      use_default_preprocessors: self.build.use_default_preprocessors,
    },
    rust: self.rust,
    output: self.output,
    preprocessor: self.preprocessor,
  }
}

///|
fn split_dotted_path(path : String) -> Array[String] {
  let parts : Array[String] = []
  for piece in path.split(".") {
    let text = piece.to_string()
    if !text.is_empty() {
      parts.push(text)
    }
  }
  parts
}

///|
fn read_json_path(json : Json, path : Array[String]) -> Json? {
  if path.is_empty() {
    return Some(json)
  }
  match json {
    Object(object) =>
      match object.get(path[0]) {
        Some(value) => read_json_path(value, path[1:].to_array())
        None => None
      }
    _ => None
  }
}

///|
fn write_json_path(json : Json, path : Array[String], value : Json) -> Json {
  if path.is_empty() {
    return value
  }
  let object = match json {
    Object(object) => object
    _ => {}
  }
  let key = path[0]
  let tail = path[1:].to_array()
  object[key] = match object.get(key) {
    Some(existing) => write_json_path(existing, tail, value)
    None => write_json_path(Json::object({}), tail, value)
  }
  Json::object(object)
}

///|
fn parse_toml_like(src : String) -> Json raise {
  let mut root = Json::object({})
  let mut section : Array[String] = []
  for raw_line in src.split("\n") {
    let line = trim_comment(raw_line.to_string()).trim().to_string()
    if line.is_empty() {
      continue
    }
    if line.has_prefix("[") && line.has_suffix("]") {
      let body = line[1:line.length() - 1].to_string()
      section = split_dotted_path(body)
      continue
    }
    let equals = match line.find("=") {
      Some(index) => index
      None => continue
    }
    if equals <= 0 {
      continue
    }
    let key = line[:equals].trim().to_string()
    let value = parse_toml_value(line[equals + 1:].trim().to_string())
    let path = section.copy()
    path.push(key)
    root = write_json_path(root, path, value)
  }
  root
}

///|
fn trim_comment(line : String) -> String {
  let mut quoted = false
  let builder = StringBuilder::new()
  for c in line {
    if c == '"' {
      quoted = !quoted
    }
    if c == '#' && !quoted {
      break
    }
    builder.write_char(c)
  }
  builder.to_string()
}

///|
fn parse_toml_value(value : String) -> Json raise {
  if value.has_prefix("\"") && value.has_suffix("\"") && value.length() >= 2 {
    return Json::string(value[1:value.length() - 1].to_string())
  }
  if value == "true" {
    return Json::boolean(true)
  }
  if value == "false" {
    return Json::boolean(false)
  }
  if value.has_prefix("[") && value.has_suffix("]") {
    let items = value[1:value.length() - 1].to_string()
    if items.trim().is_empty() {
      return Json::array([])
    }
    let result : Array[Json] = []
    for item in items.split(",") {
      result.push(parse_toml_value(item.trim().to_string()))
    }
    return Json::array(result)
  }
  Json::string(value)
}

///|
test "config dotted read and write" {
  let cfg = default().set("output.html.theme", Json::string("theme"))
  assert_true(cfg.contains_key("output.html.theme"))
  assert_eq(cfg.read("output.html.theme"), Some(Json::string("theme")))
}

///|
test "config parses simple toml" {
  let cfg = from_toml(
    "# comment\n[book]\ntitle = \"MoonBook\"\nauthors = [\"kq\"]\n[build]\nbuild-dir = \"dist\"\n",
  )
  assert_eq(cfg.book.title, Some("MoonBook"))
  assert_eq(cfg.book.authors, ["kq"])
  assert_eq(cfg.build.build_dir, "dist")
}
