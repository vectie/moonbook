///|
#borrow(root, relative, output)
extern "c" fn retained_read_native(
  root : Bytes,
  relative : Bytes,
  output : FixedArray[Byte],
  capacity : Int32,
) -> Int32 = "moonbit_moonbook_retained_read"

///|
/// Bounded descriptor-relative read. Reject every symlink, nonregular file,
/// unsafe component, oversized file, and observed concurrent modification.
pub fn read_retained_bytes(root : String, relative : String) -> Bytes raise {
  guard relative.has_prefix("raw/") else {
    fail("invalid retained source reference")
  }
  read_book_regular_bytes(root, relative)
}

///|
pub fn read_maintained_bytes(root : String, relative : String) -> Bytes raise {
  guard relative.has_prefix("wiki/") && relative.has_suffix(".md") else {
    fail("invalid maintained page reference")
  }
  read_book_regular_bytes(root, relative)
}

///|
fn read_book_regular_bytes(root : String, relative : String) -> Bytes raise {
  guard !root.contains("\u0000") &&
    !relative.contains("\\") &&
    !relative.contains("\u0000") &&
    relative.split("/").all(part => part != "" && part != "." && part != "..") else {
    fail("invalid retained source reference")
  }
  let output = FixedArray::make(2097153, b'0')
  let count = retained_read_native(
    @encoding/utf8.encode(root + "\u0000"),
    @encoding/utf8.encode(relative + "\u0000"),
    output,
    output.length(),
  )
  if count < 0 {
    fail("retained source unavailable or exceeds 2 MiB")
  }
  output.unsafe_reinterpret_as_bytes()[:count].to_owned()
}
