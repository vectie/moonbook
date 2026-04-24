///|
// Extension installation file-copy and seed-tree helpers.

async fn install_moonclaw_extension(
  root : String,
  extensions_dir : String,
) -> ExtensionInstallResult {
  let manifest_path = @path.Path(extensions_dir)
    .join(@path.Path("moonclaw.json"))
    .to_string()
  let config_path = @path.Path(root)
    .join(@path.Path("moonclaw.json"))
    .to_string()
  let jobs_path = @path.Path(root)
    .join(@path.Path("moonclaw.jobs.json"))
    .to_string()
  let runtime_dir = @path.Path(root).join(@path.Path(".moonclaw")).to_string()
  let providers_path = @path.Path(runtime_dir)
    .join(@path.Path("providers.json"))
    .to_string()
  let identity_path = @path.Path(root)
    .join(@path.Path("IDENTITY.md"))
    .to_string()
  let user_path = @path.Path(root).join(@path.Path("USER.md")).to_string()
  let routines_path = @path.Path(root)
    .join(@path.Path("ROUTINES.md"))
    .to_string()
  let memory_path = @path.Path(root).join(@path.Path("MEMORY.md")).to_string()
  let keeper_path = @path.Path(root).join(@path.Path("KEEPER.md")).to_string()
  let skills_dir = @path.Path(root).join(@path.Path("skills")).to_string()
  let maintainer_dir = @path.Path(skills_dir)
    .join(@path.Path("wiki-maintainer"))
    .to_string()
  let review_dir = @path.Path(skills_dir)
    .join(@path.Path("wiki-review"))
    .to_string()
  let maintainer_skill_path = @path.Path(maintainer_dir)
    .join(@path.Path("SKILL.md"))
    .to_string()
  let review_skill_path = @path.Path(review_dir)
    .join(@path.Path("SKILL.md"))
    .to_string()
  @fsx.make_directory(skills_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(runtime_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(maintainer_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(review_dir, recursive=true, exists_ok=true)
  write_extension_file_if_missing(config_path, moonclaw_config_text(root))
  write_extension_file_if_missing(jobs_path, moonclaw_jobs_text())
  write_extension_file_if_missing(providers_path, moonclaw_providers_text(root))
  write_extension_file_if_missing(identity_path, identity_text(root))
  write_extension_file_if_missing(user_path, user_text())
  write_extension_file_if_missing(routines_path, routines_text())
  write_extension_file_if_missing(memory_path, memory_text())
  write_extension_file_if_missing(keeper_path, keeper_text())
  copy_extension_seed_tree_if_missing(
    maintainer_dir, "seed/extensions/moonclaw/skills/wiki-maintainer",
  )
  copy_extension_seed_tree_if_missing(
    review_dir, "seed/extensions/moonclaw/skills/wiki-review",
  )
  write_extension_file_if_missing(manifest_path, moonclaw_manifest_text())
  {
    root,
    extension: "moonclaw",
    manifest_path,
    installed_files: [
      config_path, jobs_path, providers_path, identity_path, user_path, routines_path,
      memory_path, keeper_path, maintainer_skill_path, review_skill_path,
    ],
  }
}

///|
async fn install_moontown_extension(
  root : String,
  extensions_dir : String,
) -> ExtensionInstallResult {
  let manifest_path = @path.Path(extensions_dir)
    .join(@path.Path("moontown.json"))
    .to_string()
  let book_api_path = @path.Path(root)
    .join(@path.Path("moontown.book.json"))
    .to_string()
  let bridge_path = @path.Path(root).join(@path.Path("BOOK_API.md")).to_string()
  write_extension_file_if_missing(book_api_path, moontown_book_text(root))
  write_extension_file_if_missing(bridge_path, book_api_text())
  write_extension_file_if_missing(manifest_path, moontown_manifest_text())
  {
    root,
    extension: "moontown",
    manifest_path,
    installed_files: [book_api_path, bridge_path],
  }
}

///|
async fn write_extension_file_if_missing(
  path : String,
  content : String,
) -> Unit {
  if !@fsx.exists(path) {
    @fsx.write_to_file(path, content, create=0o644)
  }
}

///|
async fn copy_extension_seed_tree_if_missing(
  destination_path : String,
  seed_relative_path : String,
) -> Unit {
  let source_path = @path.Path(detect_moonbook_module_root())
    .join(@path.Path(seed_relative_path))
    .to_string()
  if !@fsx.exists(source_path) {
    fail("missing extension seed file: \{source_path}")
  }
  copy_extension_seed_tree(source_path, destination_path)
}

///|
async fn copy_extension_seed_tree(
  source_path : String,
  destination_path : String,
) -> Unit {
  match @fs.kind(source_path, follow_symlink=false) {
    @fs.FileKind::Directory => {
      @fsx.make_directory(destination_path, recursive=true, exists_ok=true)
      for child in @fsx.list_directory(source_path) {
        let child_name = @path.Path(child).basename().to_string()
        copy_extension_seed_tree(
          child,
          @path.Path(destination_path).join(@path.Path(child_name)).to_string(),
        )
      }
    }
    _ =>
      if !@fsx.exists(destination_path) {
        @fsx.write_to_file(
          destination_path,
          @fsx.read_file(source_path),
          create=0o644,
        )
      }
  }
}

///|
