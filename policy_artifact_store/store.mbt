///|
fn empty_journal() -> ArtifactJournal {
  {
    contract_id: "moonbook.policy-artifact-journal.v1",
    book_id: "",
    case_id: "",
    version: 0,
    batches: [],
  }
}

///|
async fn ensure_directory(path : String) -> Unit {
  if @fs.exists(path) {
    guard @fs.kind(path, follow_symlink=false) == Directory else {
      fail("store path is not a real directory")
    }
  } else {
    @fs.mkdir(path, permission=0o700, recursive=true)
  }
}

///|
pub async fn read_journal(root : String) -> ArtifactJournal {
  let path = root + "/snapshot.json"
  if !@fs.exists(path) {
    return empty_journal()
  }
  guard @fs.kind(path, follow_symlink=false) == Regular else {
    fail("journal is not a regular file")
  }
  let file = @fs.open(path, mode=ReadOnly, create_mode=OpenExisting)
  let size = file.size()
  file.close()
  guard size <= 8388608L else { fail("artifact journal exceeds 8 MiB") }
  let journal : ArtifactJournal = @json.from_json(
    @json.parse(@fs.read_file(path).text()),
  )
  validate_journal(journal)
  journal
}

///|
/// One lock and one atomic rename publish all payloads and receipts together.
/// The old journal survives validation/write failure. No external DB or power-
/// failure durability beyond the operating system's local file sync is claimed.
pub async fn append_batch(root : String, batch : ArtifactBatch) -> StoredBatch {
  ensure_directory(root)
  let lock_path = root + "/store.lock"
  if @fs.exists(lock_path) {
    guard @fs.kind(lock_path, follow_symlink=false) == Regular else {
      fail("invalid store lock")
    }
  }
  let lock = @fs.open(
    lock_path,
    mode=ReadWrite,
    create_mode=OpenOrCreate,
    permission=0o600,
  )
  lock.lock(Exclusive)
  defer {
    lock.unlock()
    lock.close()
  }
  let journal = read_journal(root)
  validate_batch(batch, journal)
  let entry = { batch, receipts: receipts(batch, journal.version + 1), }
  let next = {
    ..journal,
    book_id: batch.book_id,
    case_id: batch.case_id,
    version: journal.version + 1,
    batches: journal.batches + [entry],
  }
  let encoded = next.to_json().stringify()
  guard @utf8.encode(encoded).length() <= 8388608 else {
    fail("artifact journal capacity exceeded")
  }
  let temporary = root +
    "/pending-" +
    content_digest(batch.batch_id).replace_all(old=":", new="-") +
    ".json"
  if @fs.exists(temporary) {
    guard @fs.kind(temporary, follow_symlink=false) == Regular &&
      @fs.read_file(temporary).text() == encoded else {
      fail(
        "incomplete or conflicting temporary journal preserved for inspection",
      )
    }
  } else {
    @fs.write_file(
      temporary,
      encoded,
      create_mode=CreateNew,
      permission=0o600,
      sync=Full,
    )
  }
  @fs.rename(temporary, root + "/snapshot.json", replace=true)
  let confirmed = read_journal(root)
  guard confirmed == next else {
    fail("post-write journal verification failed")
  }
  entry
}
