///|
// Extension installation file-copy and seed-tree helpers.

async fn install_moonclaw_extension(
  root : String,
  extensions_dir : String,
) -> ExtensionInstallResult {
  let manifest_path = moonbook_wiki_path(extensions_dir)
    .join(moonbook_wiki_path("moonclaw.json"))
    .to_string()
  let config_path = @moonsuite.product_artifact_for_workspace_root(
    root, "moonclaw", "moonclaw.json",
  )
  let jobs_path = moonbook_wiki_path(root)
    .join(moonbook_wiki_path("moonclaw.jobs.json"))
    .to_string()
  let runtime_dir = moonclaw_product_state_dir_for_root(root)
  let providers_path = moonbook_wiki_path(runtime_dir)
    .join(moonbook_wiki_path("providers.json"))
    .to_string()
  let identity_path = moonbook_wiki_path(root)
    .join(moonbook_wiki_path("IDENTITY.md"))
    .to_string()
  let user_path = moonbook_wiki_path(root)
    .join(moonbook_wiki_path("USER.md"))
    .to_string()
  let routines_path = moonbook_wiki_path(root)
    .join(moonbook_wiki_path("ROUTINES.md"))
    .to_string()
  let memory_path = moonbook_wiki_path(root)
    .join(moonbook_wiki_path("MEMORY.md"))
    .to_string()
  let keeper_path = moonbook_wiki_path(root)
    .join(moonbook_wiki_path("KEEPER.md"))
    .to_string()
  let skills_dir = moonbook_wiki_path(root)
    .join(moonbook_wiki_path("skills"))
    .to_string()
  let maintainer_dir = moonbook_wiki_path(skills_dir)
    .join(moonbook_wiki_path("wiki-maintainer"))
    .to_string()
  let review_dir = moonbook_wiki_path(skills_dir)
    .join(moonbook_wiki_path("wiki-review"))
    .to_string()
  let maintainer_skill_path = moonbook_wiki_path(maintainer_dir)
    .join(moonbook_wiki_path("SKILL.md"))
    .to_string()
  let review_skill_path = moonbook_wiki_path(review_dir)
    .join(moonbook_wiki_path("SKILL.md"))
    .to_string()
  @fsx.make_directory(skills_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(runtime_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(maintainer_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(review_dir, recursive=true, exists_ok=true)
  write_extension_file_if_missing(config_path, moonclaw_config_text(root))
  write_generated_extension_file(jobs_path, moonclaw_jobs_text())
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
fn moonclaw_product_state_dir_for_root(root : String) -> String {
  @moonsuite.product_home_for_workspace_root(root, "moonclaw").state_path
}

///|
async fn install_moontown_extension(
  root : String,
  extensions_dir : String,
) -> ExtensionInstallResult {
  let manifest_path = moonbook_wiki_path(extensions_dir)
    .join(moonbook_wiki_path("moontown.json"))
    .to_string()
  let extension_manifest_path = moonbook_wiki_path(root)
    .join(moonbook_wiki_path("moontown.book.json"))
    .to_string()
  let extension_guide_path = moonbook_wiki_path(root)
    .join(moonbook_wiki_path("EXTENSION_API.md"))
    .to_string()
  write_extension_file_if_missing(
    extension_manifest_path,
    moontown_book_text(root),
  )
  write_extension_file_if_missing(extension_guide_path, extension_api_text())
  write_extension_file_if_missing(manifest_path, moontown_manifest_text())
  {
    root,
    extension: "moontown",
    manifest_path,
    installed_files: [extension_manifest_path, extension_guide_path],
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
async fn write_generated_extension_file(
  path : String,
  content : String,
) -> Unit {
  @fsx.write_to_file(path, content, create=0o644)
}

///|
async fn copy_extension_seed_tree_if_missing(
  destination_path : String,
  seed_relative_path : String,
) -> Unit {
  let source_path = moonbook_wiki_path(detect_moonbook_module_root())
    .join(moonbook_wiki_path(seed_relative_path))
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
    Directory => {
      @fsx.make_directory(destination_path, recursive=true, exists_ok=true)
      for child in @fsx.list_directory(source_path) {
        let child_name = moonbook_wiki_path(child).basename().to_owned()
        copy_extension_seed_tree(
          child,
          moonbook_wiki_path(destination_path)
          .join(moonbook_wiki_path(child_name))
          .to_string(),
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
