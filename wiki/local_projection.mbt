///|
pub(all) struct LocalProjectionOutcome {
  contract : String
  generated_artifacts : Array[String]
  preserved_artifacts : Array[String]
  missing_artifacts : Array[String]
} derive(Debug, ToJson, FromJson)

///|
/// Fill missing local Book site outputs using the normal Book renderer.
/// Existing regular files are preserved without claiming they were generated
/// by this request. No provider or image generation is invoked.
///
/// ```mbt check
/// test {
///   ignore(@wiki.ensure_local_projection)
/// }
/// ```
pub async fn ensure_local_projection(root : String) -> LocalProjectionOutcome {
  let root = @fs.realpath(root)
  let site = root + "/book/site"
  let outcome : LocalProjectionOutcome = {
    contract: "moonbook.local_projection.v1",
    generated_artifacts: [],
    preserved_artifacts: [],
    missing_artifacts: [],
  }
  // A fill operation must never follow an authored output-directory symlink.
  for relative in ["book", "book/site", "book/site/generated"] {
    let path = root + "/" + relative
    if @fs.exists(path) {
      guard @fs.kind(path, follow_symlink=false) is Directory else {
        fail(
          "local projection output directory is not a directory: " + relative,
        )
      }
    } else {
      @fs.mkdir(path)
    }
  }
  ignore(
    render_marketing_projection(root, site, async fn(path, text) {
      let relative = path[root.length() + 1:].to_owned()
      let text = if relative.has_suffix(".html") {
        local_projection_available_links(root, text)
      } else {
        text
      }
      try @fs.write_file(path, text, create_mode=CreateNew) catch {
        _ => {
          let kind = @fs.kind(path, follow_symlink=false) catch { _ => Unknown }
          if kind is Regular {
            outcome.preserved_artifacts.push(relative)
          } else {
            outcome.missing_artifacts.push(relative)
          }
        }
      } noraise {
        _ => outcome.generated_artifacts.push(relative)
      }
    }),
  )
  outcome
}

///|
// Projection-only output does not render the full Book's chapters. Keep the
// normal renderer's links when their targets exist; visibly disable only its
// unavailable local Book destinations instead of publishing broken actions.
async fn local_projection_available_links(
  root : String,
  html : String,
) -> String {
  let parts = html.split("<a ").to_array()
  let output = StringBuilder::new()
  output.write_string(parts[0].to_owned())
  for part in parts[1:] {
    let original = "<a " + part.to_owned()
    let opening = part.find(">")
    let closing = part.find("</a>")
    guard opening is Some(opening) &&
      closing is Some(closing) &&
      closing > opening else {
      output.write_string(original)
      continue
    }
    let attributes = part[:opening]
    guard attributes.find("href=\"") is Some(start) else {
      output.write_string(original)
      continue
    }
    let value_start = start + 6
    guard attributes[value_start:].find("\"") is Some(length) else {
      output.write_string(original)
      continue
    }
    let href = attributes[value_start:value_start + length].to_owned()
    if !href.has_prefix("../../") {
      output.write_string(original)
      continue
    }
    let destination = href[6:].split("#").to_array()[0].split("?").to_array()[0].to_owned()
    let exists = try (
      @fs.kind(root + "/book/" + destination, follow_symlink=false) is Regular
    ) catch {
      _ => false
    }
    if exists {
      output.write_string(original)
    } else {
      output.write_string("<span ")
      output.write_string(attributes[:start].to_owned())
      output.write_string(
        "aria-disabled=\"true\" title=\"Available after a full Book build\"",
      )
      output.write_string(attributes[value_start + length + 1:].to_owned())
      output.write_string(">")
      output.write_string(part[opening + 1:closing].to_owned())
      output.write_string(" (full Book build pending)</span>")
      output.write_string(part[closing + 4:].to_owned())
    }
  }
  output.to_string()
}
