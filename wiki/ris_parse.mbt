///|
priv struct RisField {
  tag : String
  mut value : String
}

///|
priv struct RisRecord {
  fields : Array[RisField]
  title : String
}

///|
// A deliberately bounded, local UTF-8 RIS reader. Preserve every field, even
// those without a friendly label; publication metadata is supplied evidence.
fn parse_ris(content : String) -> Array[RisRecord] raise {
  if content.length() > 2097152 {
    fail("RIS text exceeds 2 Mi code units")
  }
  let records : Array[RisRecord] = []
  let mut fields : Array[RisField] = []
  let mut record_size = 0
  let mut line_number = 0
  for raw_line in content.split("\n") {
    line_number += 1
    let line = raw_line.trim_end(chars="\r").to_owned()
    if line.trim().is_empty() {
      continue
    }
    let tagged = line.length() >= 5 &&
      line[2:5] == "  -" &&
      (line.length() == 5 || line[5] == ' ')
    if tagged {
      let tag = line[:2].to_owned()
      if !tag.iter().all(c => (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) {
        fail("RIS line \{line_number}: expected an uppercase two-character tag")
      }
      let value = if line.length() > 5 {
        line[6:].trim().to_owned()
      } else {
        ""
      }
      if tag == "TY" {
        if !fields.is_empty() {
          fail("RIS line \{line_number}: previous record is missing ER")
        }
        if value.is_empty() {
          fail("RIS line \{line_number}: TY needs a record type")
        }
        if records.length() >= 500 {
          fail("RIS import supports at most 500 records; split the export")
        }
        fields = [{ tag, value, }]
        record_size = line.length()
      } else if tag == "ER" {
        if fields.is_empty() || !value.is_empty() {
          fail(
            "RIS line \{line_number}: ER must close a record and have no value",
          )
        }
        let title = ris_first(fields, ["TI", "T1", "CT"]).replace_all(
          old="\n",
          new=" ",
        )
        if title.is_empty() || title.length() > 400 {
          fail(
            "RIS record \{records.length() + 1}: provide TI, T1 or CT title of 1–400 code units",
          )
        }
        records.push({ fields, title, })
        fields = []
        record_size = 0
      } else {
        if fields.is_empty() {
          fail("RIS line \{line_number}: record must begin with TY")
        }
        if fields.length() >= 1000 {
          fail("RIS record exceeds 1000 fields")
        }
        fields.push({ tag, value, })
        record_size += line.length()
      }
    } else {
      if fields.is_empty() || fields.length() == 1 {
        fail("RIS line \{line_number}: expected a tagged field inside a record")
      }
      let previous = fields[fields.length() - 1]
      previous.value += "\n" + line.trim().to_owned()
      record_size += line.length()
    }
    if record_size > 131072 {
      fail("RIS record exceeds 131072 code units; shorten or split the export")
    }
  }
  if !fields.is_empty() {
    fail("RIS input ends before the final ER record terminator")
  }
  if records.is_empty() {
    fail("RIS input contains no records")
  }
  records
}

///|
fn ris_first(fields : Array[RisField], tags : Array[String]) -> String {
  for tag in tags {
    for field in fields {
      if field.tag == tag && !field.value.trim().is_empty() {
        return field.value
      }
    }
  }
  ""
}

///|
fn ris_field_label(tag : String) -> String {
  match tag {
    "TY" => "Type"
    "TI" | "T1" | "CT" => "Title"
    "AU" | "A1" => "Author"
    "A2" | "ED" => "Editor / secondary creator"
    "PY" | "Y1" => "Date"
    "T2" | "JO" | "JF" | "JA" => "Publication / container"
    "AB" | "N2" => "Abstract"
    "DO" => "DOI"
    "UR" => "URL"
    "KW" => "Keyword"
    "VL" => "Volume"
    "IS" => "Issue"
    "SP" => "First page"
    "EP" => "Last page"
    "PB" => "Publisher"
    "SN" => "ISSN / ISBN"
    "N1" => "Note"
    "ID" => "Export identifier"
    _ => "Additional field"
  }
}

///|
fn ris_record_text(record : RisRecord) -> String {
  record.fields
  .map(field => {
    ris_field_label(field.tag) + " [" + field.tag + "]: " + field.value
  })
  .join("\n\n")
}

///|
fn ris_fenced_text(text : String) -> String {
  let mut longest = 2
  let mut run = 0
  for character in text {
    if character == '`' {
      run += 1
      if run > longest {
        longest = run
      }
    } else {
      run = 0
    }
  }
  let fence = "`".repeat(longest + 1)
  fence + "text\n" + text + "\n" + fence + "\n"
}

///|
fn ris_markdown_title(title : String) -> String {
  title
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="[", new="\\[")
  .replace_all(old="]", new="\\]")
  .replace_all(old="*", new="\\*")
  .replace_all(old="_", new="\\_")
  .replace_all(old="`", new="\\`")
}
