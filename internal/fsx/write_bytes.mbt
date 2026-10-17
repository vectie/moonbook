///|
pub async fn write_bytes(
  path : StringView,
  content : Bytes,
  create~ : Int32 = 0o644,
) -> Unit {
  @fs.write_file(
    path.to_owned(),
    content,
    create_mode=@fs.CreateOrTruncate,
    permission=create,
  )
}
