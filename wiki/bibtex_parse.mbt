///|
priv struct BibtexRecord {
  kind : String
  key : String
  title : String
  fields : Array[(String, String)]
}

///|
priv struct BibtexReader {
  text : String
  mut pos : Int32
  strings : Map[String, String]
}

///|
fn BibtexReader::error(self : BibtexReader, message : String) -> Unit raise {
  let line = self.text[:self.pos].split("\n").count()
  fail("BibTeX line \{line}: \{message}")
}

///|
fn BibtexReader::space(self : BibtexReader) -> Unit {
  while self.pos < self.text.length() &&
        (
          self.text[self.pos] == ' ' ||
          self.text[self.pos] == '\n' ||
          self.text[self.pos] == '\r' ||
          self.text[self.pos] == '\t'
        ) {
    self.pos += 1
  }
}

///|
fn BibtexReader::take(self : BibtexReader, character : UInt16) -> Bool {
  self.space()
  if self.pos < self.text.length() && self.text[self.pos] == character {
    self.pos += 1
    true
  } else {
    false
  }
}

///|
fn BibtexReader::expect(
  self : BibtexReader,
  character : UInt16,
  description : String,
) -> Unit raise {
  if !self.take(character) {
    self.error("expected " + description)
  }
}

///|
fn BibtexReader::identifier(self : BibtexReader) -> String raise {
  self.space()
  let start = self.pos
  while self.pos < self.text.length() &&
        (
          (self.text[self.pos] >= 'a' && self.text[self.pos] <= 'z') ||
          (self.text[self.pos] >= 'A' && self.text[self.pos] <= 'Z') ||
          (self.text[self.pos] >= '0' && self.text[self.pos] <= '9') ||
          self.text[self.pos] == '_' ||
          self.text[self.pos] == '-' ||
          self.text[self.pos] == ':'
        ) {
    self.pos += 1
  }
  if self.pos == start {
    self.error("expected a type, field name, or string abbreviation")
  }
  self.text[start:self.pos].to_owned()
}

///|
// Keep inner braces, TeX accents and commands verbatim. They are data, never
// interpreted or executed. Quotes inside brace groups do not end a value.
fn BibtexReader::literal(self : BibtexReader, quoted : Bool) -> String raise {
  let start = self.pos
  let mut depth = 0
  while self.pos < self.text.length() {
    let character = self.text[self.pos]
    if character == '{' {
      depth += 1
    } else if character == '}' {
      if depth == 0 {
        if quoted {
          self.error("unbalanced brace inside quoted value")
        }
        let value = self.text[start:self.pos].to_owned()
        self.pos += 1
        return value
      }
      depth -= 1
    } else if character == '"' && quoted && depth == 0 {
      let value = self.text[start:self.pos].to_owned()
      self.pos += 1
      return value
    }
    self.pos += 1
  }
  self.error("unterminated field value")
  ""
}

///|
fn BibtexReader::value(self : BibtexReader) -> String raise {
  let result = StringBuilder::new()
  let mut size = 0
  while true {
    self.space()
    let part = if self.take('{') {
      self.literal(false)
    } else if self.take('"') {
      self.literal(true)
    } else {
      let token = self.identifier()
      if token.iter().all(c => c >= '0' && c <= '9') {
        token
      } else {
        match self.strings.get(token.to_lower()) {
          Some(value) => value
          None => {
            self.error(
              "undefined string abbreviation " +
              token +
              "; expand it in the export or define it earlier with @string",
            )
            ""
          }
        }
      }
    }
    size += part.length()
    if size > 131072 {
      self.error("expanded value exceeds 131072 code units")
    }
    result.write_string(part)
    if !self.take('#') {
      break
    }
  }
  result.to_string()
}

///|
fn parse_bibtex(content : String) -> Array[BibtexRecord] raise {
  if content.length() > 2097152 {
    fail("BibTeX text exceeds 2 Mi code units")
  }
  let reader : BibtexReader = {
    text: content,
    pos: 0,
    strings: {
      "jan": "January",
      "feb": "February",
      "mar": "March",
      "apr": "April",
      "may": "May",
      "jun": "June",
      "jul": "July",
      "aug": "August",
      "sep": "September",
      "oct": "October",
      "nov": "November",
      "dec": "December",
    },
  }
  let records : Array[BibtexRecord] = []
  let keys : Map[String, Unit] = {}
  let mut definitions = 0
  while reader.pos < content.length() {
    // BibTeX permits free text between entries. The next @ starts a block.
    if content[reader.pos] != '@' {
      reader.pos += 1
      continue
    }
    reader.pos += 1
    let kind = reader.identifier().to_lower()
    let close : UInt16 = if reader.take('{') {
      '}'
    } else if reader.take('(') {
      ')'
    } else {
      reader.error("expected { or ( after entry type")
      '}'
    }
    if kind == "comment" {
      if close != '}' {
        reader.error("@comment requires a brace-delimited block")
      }
      ignore(reader.literal(false))
      continue
    }
    if kind == "preamble" {
      reader.error(
        "@preamble TeX commands are unsupported; export a plain bibliography without a preamble",
      )
    }
    if kind == "string" {
      definitions += 1
      if definitions > 500 {
        reader.error("at most 500 string definitions are supported")
      }
      let name = reader.identifier().to_lower()
      reader.expect('=', "= after string name")
      let value = reader.value()
      ignore(reader.take(','))
      reader.expect(close, "closing string delimiter")
      if reader.strings.contains(name) {
        reader.error("duplicate string abbreviation " + name)
      }
      reader.strings[name] = value
      continue
    }
    if records.length() >= 500 {
      reader.error("at most 500 references are supported; split the export")
    }
    reader.space()
    let start = reader.pos
    while reader.pos < content.length() &&
          content[reader.pos] != ',' &&
          content[reader.pos] != close {
      reader.pos += 1
    }
    let key = content[start:reader.pos].trim().to_owned()
    if key.is_empty() ||
      key.length() > 400 ||
      key
      .iter()
      .any(c => {
        c == ' ' ||
        c == '\t' ||
        c == '\r' ||
        c == '\n' ||
        c == '{' ||
        c == '}' ||
        c == '(' ||
        c == ')' ||
        c == '"' ||
        c == '=' ||
        c == '#' ||
        c == '@'
      }) {
      reader.error(
        "citation key must contain 1–400 non-delimiter, non-whitespace code units",
      )
    }
    if keys.contains(key.to_lower()) {
      reader.error("duplicate citation key " + key)
    }
    keys[key.to_lower()] = ()
    reader.expect(',', "comma after citation key")
    let fields : Array[(String, String)] = []
    let names : Map[String, Unit] = {}
    let mut record_size = 0
    let mut title = ""
    while !reader.take(close) {
      let name = reader.identifier().to_lower()
      if names.contains(name) {
        reader.error("duplicate field " + name + " in " + key)
      }
      names[name] = ()
      reader.expect('=', "= after field name")
      let value = reader.value()
      record_size += value.length()
      if fields.length() >= 1000 || record_size > 131072 {
        reader.error("record exceeds 1000 fields or 131072 expanded code units")
      }
      fields.push((name, value))
      if name == "title" {
        title = value
          .split("\n")
          .map(s => s.trim().to_owned())
          .join(" ")
          .trim()
          .to_owned()
      }
      if reader.take(close) {
        break
      }
      reader.expect(',', "comma between fields")
    }
    if title.is_empty() || title.length() > 400 {
      reader.error("reference " + key + " needs a title of 1–400 code units")
    }
    records.push({ kind, key, title, fields, })
  }
  if records.is_empty() {
    fail("BibTeX input contains no references")
  }
  records
}

///|
fn bibtex_record_text(record : BibtexRecord) -> String {
  "Entry type: " +
  record.kind +
  "\n\nCitation key: " +
  record.key +
  "\n\n" +
  record.fields.map(field => field.0 + ": " + field.1).join("\n\n")
}
