///|
#borrow(source, destination)
extern "c" fn fs_atomic_replace(source : Bytes, destination : Bytes) -> Int = "moonbit_moonbook_fs_atomic_replace"

///|
/// Atomically replace `destination` with a completely written file from the
/// same filesystem. Callers must create the temporary file in the destination
/// directory so POSIX rename atomicity applies.
pub fn atomic_replace(
  source : StringView,
  destination : StringView,
) -> Unit raise {
  let result = fs_atomic_replace(
    @encoding/utf8.encode(source),
    @encoding/utf8.encode(destination),
  )
  if result != 0 {
    fail("atomic replace failed with errno \{result}: \{destination}")
  }
}
