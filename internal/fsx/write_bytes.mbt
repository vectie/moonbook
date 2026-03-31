///|
pub async fn write_bytes(
  path : StringView,
  content : Bytes,
  create? : Int = 0o644,
) -> Unit {
  @fs.write_file(path.to_string(), content, create~, truncate=true)
}
