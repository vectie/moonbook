///|
struct BookCollectionArchive {
  schema : String
  title : String
  purpose : String
  items : Array[BookCollectionItem]
  history : Array[BookCollectionItem]
} derive(Debug, ToJson, FromJson, Eq)

///|
fn book_collection_archive(state : BookCollectionState) -> String {
  let archive : BookCollectionArchive = {
    schema: "moonbook.research-collection.v2",
    title: state.title,
    purpose: state.purpose,
    items: state.items,
    history: state.history,
  }
  archive.to_json().stringify(indent=2) + "\n"
}

///|
fn book_collection_decode_archive(
  text : String,
) -> Result[BookCollectionArchive, String] {
  if text.length() > 8_388_608 {
    return Err(
      "Archive exceeds the 8 Mi code-unit import limit. Current collection kept.",
    )
  }
  let value = @json.parse(text) catch {
    _ =>
      return Err(
        "Not a research-collection JSON file. Current collection kept.",
      )
  }
  // Legacy archives have no history. Only this exact version receives the
  // explicit migration; a v2 archive missing history is malformed.
  let migrated = match value {
    { "schema": "moonbook.research-collection.v1", .. } => {
      guard value is Object(fields) else {
        return Err("Invalid archive. Current collection kept.")
      }
      guard !fields.contains("history") else {
        return Err(
          "Legacy archive unexpectedly contains history. Current collection kept.",
        )
      }
      let fields = fields.copy()
      fields["schema"] = "moonbook.research-collection.v2"
      fields["history"] = ([] : Array[Json]).to_json()
      fields.to_json()
    }
    _ => value
  }
  let archive : BookCollectionArchive = @json.from_json(migrated) catch {
    _ =>
      return Err(
        "Not a research-collection JSON file. Current collection kept.",
      )
  }
  guard archive.schema == "moonbook.research-collection.v2" else {
    return Err("Unsupported collection schema. Current collection kept.")
  }
  guard archive.title.length() <= 160 &&
    archive.purpose.length() <= 4000 &&
    archive.items.length() <= 12 &&
    archive.history.length() <= 48 else {
    return Err(
      "Collection title, synthesis or selection count exceeds the supported limits. Current collection kept.",
    )
  }
  let citations : Map[String, Bool] = {}
  for item in archive.items {
    guard !citations.contains(item.page.citation) else {
      return Err("Duplicate citation in archive. Current collection kept.")
    }
    citations[item.page.citation] = true
  }
  let mut size = 0
  for item in archive.items + archive.history {
    guard item.note.length() <= 4000 &&
      item.title.length() <= 16384 &&
      item.page.citation.length() > 0 &&
      item.page.citation.length() <= 4096 &&
      item.page.question.length() <= 16384 &&
      item.page.ok &&
      item.page.schema == "moonbook.search.v1" else {
      return Err(
        "A selection has invalid or oversized snapshot metadata. Current collection kept.",
      )
    }
    size += item.page.content.length()
    if item.page.page is Some(page) && page < 0 {
      return Err("Invalid search page in archive. Current collection kept.")
    }
    if item.page.retained_source is Some(source) &&
      (source.reference.length() > 4096 || source.page_digest.length() > 256) {
      return Err("Oversized retained-source label. Current collection kept.")
    }
  }
  guard size <= 1048576 else {
    return Err(
      "Snapshot text exceeds 1,048,576 code units. Current collection kept.",
    )
  }
  Ok(archive)
}

///|
extern "js" fn book_collection_archive_download(text : String) -> @js.Promise =
  #| async text => {
  #|   const blob = new Blob([text], {type:"application/json;charset=utf-8"});
  #|   const url = URL.createObjectURL(blob); const link = document.createElement("a");
  #|   link.href=url; link.download="moonbook-research-collection.json"; document.body.appendChild(link);
  #|   try {link.click();} finally {link.remove(); setTimeout(()=>URL.revokeObjectURL(url),1000);}
  #|   return "Collection JSON download requested. Keep it to resume your notes and snapshots later.";
  #| }

///|
extern "js" fn book_collection_archive_open() -> @js.Promise =
  #| () => new Promise((resolve,reject) => {
  #|   const input=document.createElement("input"); input.type="file"; input.accept=".json,application/json";
  #|   let done=false; const finish=(text,error)=>{if(done)return;done=true;clearTimeout(timer);error?reject(error):resolve(text);};
  #|   const timer=setTimeout(()=>finish(""),120000); input.oncancel=()=>finish("");
  #|   input.onchange=async()=>{try{const file=input.files?.[0];if(!file){finish("");return;}if(file.size>16777216){finish("",new Error("File too large"));return;}finish(await file.text());}catch(error){finish("",error);}};
  #|   input.click();
  #| })
