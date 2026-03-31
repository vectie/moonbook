///|
extern "c" fn fs_stat_sizeof() -> Int = "moonbit_moonbook_fs_stat_sizeof"

///|
#borrow(path, stat)
extern "c" fn fs_stat_sync(path : Bytes, stat : FixedArray[Byte]) -> Int = "moonbit_moonbook_fs_stat_sync"

///|
#borrow(stat)
extern "c" fn fs_stat_get_mtime(stat : Bytes) -> Int64 = "moonbit_moonbook_fs_stat_get_mtime"

///|
pub fn mtime(path : StringView) -> Int64? {
  let buf : FixedArray[Byte] = FixedArray::make(fs_stat_sizeof(), 0)
  let result = fs_stat_sync(@encoding/utf8.encode(path), buf)
  if result == 0 {
    Some(fs_stat_get_mtime(buf.unsafe_reinterpret_as_bytes()))
  } else {
    None
  }
}
