///|
pub async fn read_bytes(path : StringView) -> Bytes {
  @fs.read_file(path.to_string()).binary()
}
