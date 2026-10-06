///|
priv struct NativeWenyuWrite {
  path : String
  before : String?
  after : String
} derive(Debug, ToJson, FromJson)

///|
priv struct NativeWenyuIntent {
  contract : String
  root : String
  identity : NativeWenyuImport
  payload_text : String
  outcome : PersistResultOutcome
  writes : Array[NativeWenyuWrite]
} derive(Debug, ToJson, FromJson)

///|
async fn native_wenyu_kind(path : String) -> @fs.FileKind? {
  Some(@fs.kind(path, follow_symlink=false)) catch {
    @os_error.OSError(_) as error if error.is_ENOENT() => None
    error => raise error
  }
}

///|
async fn native_wenyu_sync_directory(path : String) -> Unit {
  let directory = @fs.open(path, mode=ReadOnly)
  defer directory.close()
  directory.sync()
}

///|
// Walk only owner-chosen relative paths and reject symlinks, including dangling
// ones. No artifact named by the worker is ever used as a write destination here.
async fn native_wenyu_path(
  root : String,
  relative : String,
  create_parents? : Bool = false,
) -> String {
  guard !relative.is_empty() && !relative.has_prefix("/") else {
    fail("invalid native Wenyu store path")
  }
  let parts : Array[String] = []
  for part in relative.split("/") {
    parts.push(part.to_owned())
  }
  let mut current = root
  for index in 0..<parts.length() {
    let part = parts[index]
    guard part != "" && part != "." && part != ".." && !part.contains("\\") else {
      fail("invalid native Wenyu store path")
    }
    let parent = current
    current = parent + "/" + part
    let kind = native_wenyu_kind(current)
    if index < parts.length() - 1 {
      match kind {
        Some(Directory) => ()
        None =>
          if create_parents {
            @fs.mkdir(current, permission=0o755)
            native_wenyu_sync_directory(parent)
          }
        _ =>
          fail(
            "native Wenyu import refuses non-directory or symlink: \{current}",
          )
      }
    } else {
      match kind {
        Some(Regular) | None => ()
        _ => fail("native Wenyu import refuses non-file or symlink: \{current}")
      }
    }
  }
  current
}

///|
async fn native_wenyu_read(root : String, relative : String) -> String? {
  let path = native_wenyu_path(root, relative)
  match native_wenyu_kind(path) {
    None => None
    Some(Regular) => Some(@fsx.read_file(path))
    _ => fail("native Wenyu import requires regular file: \{path}")
  }
}

///|
// O_SYNC content, rename in the destination directory, then fsync that directory.
// A crash can leave the temporary file, but never a partial visible destination.
async fn native_wenyu_write(
  root : String,
  relative : String,
  text : String,
) -> Unit {
  let path = native_wenyu_path(root, relative, create_parents=true)
  let temporary = native_wenyu_path(root, relative + ".native-import.tmp")
  @fs.write_file(
    temporary,
    @utf8.encode(text),
    create_mode=CreateOrTruncate,
    permission=if relative.has_prefix(".moonbook/") { 0o600 } else { 0o644 },
    sync=Full,
  )
  @fsx.atomic_replace(temporary, path)
  native_wenyu_sync_directory(@pathx.dirname(path).to_owned())
}

///|
fn native_wenyu_checkpoint(actual : Int, fail_after : Int) -> Unit raise {
  if actual == fail_after {
    fail("injected native Wenyu import interruption at checkpoint \{actual}")
  }
}

///|
async fn native_wenyu_write_intent(
  root : String,
  writes : Array[NativeWenyuWrite],
  relative : String,
  default_text : String,
  transform : (String) -> String,
) -> Unit {
  let before = native_wenyu_read(root, relative)
  writes.push({
    path: relative,
    before,
    after: transform(before.unwrap_or(default_text)),
  })
}

///|
async fn persist_native_wenyu_import(
  root : String,
  payload : Json,
  fail_after? : Int = -1,
) -> PersistResultOutcome {
  let (identity, result, payload_text) = decode_native_wenyu_import(payload)
  let normalized_root = @pathx.normalize(root)
  guard normalized_root.has_prefix("/") &&
    normalized_root != "/" &&
    @fs.realpath(normalized_root) == normalized_root else {
    fail(
      "native Wenyu import requires an existing canonical non-symlink Book root",
    )
  }
  let store = ".moonbook/native-wenyu-imports"
  let key = native_wenyu_digest(identity.work_id)
  let intent_relative = "\{store}/\{key}.intent.json"
  let receipt_relative = "\{store}/\{key}.receipt.json"
  let lock_path = native_wenyu_path(
    normalized_root,
    "\{store}/import.lock",
    create_parents=true,
  )
  let lock = @fs.open(
    lock_path,
    mode=ReadWrite,
    create_mode=OpenOrCreate,
    permission=0o600,
  )
  defer lock.close()
  lock.lock(Exclusive)
  defer lock.unlock()
  let saved = native_wenyu_read(normalized_root, intent_relative)
  let intent : NativeWenyuIntent = match saved {
    Some(text) => {
      let previous : NativeWenyuIntent = @json.from_json(@json.parse(text))
      guard previous.contract == "moonbook.native-wenyu-intent.v1" &&
        previous.root == normalized_root &&
        previous.identity == identity &&
        previous.payload_text == payload_text else {
        fail(
          "native Wenyu import conflict: work identity already binds different request or payload",
        )
      }
      previous
    }
    None => {
      // Serialize native imports across crashes as well as processes. A later
      // work must not consume the half-applied shared pages of an earlier work.
      for path in @fsx.list_directory(normalized_root + "/" + store) {
        if path.has_suffix(".intent.json") {
          let receipt = path
            .replace(old=".intent.json", new=".receipt.json")
            .to_string()
          if !@fsx.exists(receipt) {
            fail(
              "native Wenyu import pending: resume the earlier import before another work",
            )
          }
        }
      }
      let prepared = prepare_native_wenyu_intent(
        normalized_root, identity, result, payload_text,
      )
      native_wenyu_write(
        normalized_root,
        intent_relative,
        prepared.to_json().stringify(indent=2),
      )
      prepared
    }
  }
  if native_wenyu_read(normalized_root, receipt_relative) is Some(text) {
    let outcome : PersistResultOutcome = @json.from_json(@json.parse(text))
    guard outcome.to_json() == intent.outcome.to_json() else {
      fail("native Wenyu import receipt does not match its immutable intent")
    }
    // Never rewrite pages or latest.json after commit, including after human
    // review or a later import has changed them.
    return outcome
  }
  native_wenyu_checkpoint(0, fail_after)
  // Check every destination before changing any. On recovery each file is
  // either exactly its old image or exactly its prepared image, otherwise stop.
  for write in intent.writes {
    let current = native_wenyu_read(normalized_root, write.path)
    guard current == write.before || current == Some(write.after) else {
      fail("native Wenyu import destination conflict: \{write.path}")
    }
  }
  for index in 0..<intent.writes.length() {
    let write = intent.writes[index]
    let current = native_wenyu_read(normalized_root, write.path)
    if current != Some(write.after) {
      guard current == write.before else {
        fail(
          "native Wenyu import destination changed during application: \{write.path}",
        )
      }
      native_wenyu_write(normalized_root, write.path, write.after)
    }
    native_wenyu_checkpoint(index + 1, fail_after)
  }
  native_wenyu_write(
    normalized_root,
    receipt_relative,
    intent.outcome.to_json().stringify(indent=2),
  )
  native_wenyu_checkpoint(intent.writes.length() + 1, fail_after)
  intent.outcome
}
