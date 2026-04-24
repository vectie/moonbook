///|
// Skill paths, copy/sync helpers, slugs, and scaffold text generation.

fn skill_module_root() -> String {
  @env.current_dir().unwrap_or(".")
}

///|
fn workspace_skill_dir(root : String, name : String) -> String {
  @path.Path(root)
  .join(@path.Path("skills"))
  .join(@path.Path(skill_slug(name)))
  .to_string()
}

///|
fn skill_candidate_dir(root : String, name : String) -> String {
  @path.Path(root)
  .join(@path.Path("skill-candidates"))
  .join(@path.Path(skill_slug(name)))
  .to_string()
}

///|
fn parse_skill_selector(name : String) -> (String, String?) {
  let normalized = name.trim().to_lower().to_string()
  match normalized.find("@") {
    Some(index) =>
      (
        normalized[:index].to_string(),
        Some(normalized[index + 1:].trim().to_string()),
      )
    None => (normalized, None)
  }
}

///|
async fn copy_skill_tree(
  source_path : String,
  destination_path : String,
) -> Unit {
  match @fs.kind(source_path, follow_symlink=false) {
    @fs.FileKind::Directory => {
      @fsx.make_directory(destination_path, recursive=true, exists_ok=true)
      for child in @fsx.list_directory(source_path) {
        let child_name = @path.Path(child).basename().to_string()
        copy_skill_tree(
          child,
          @path.Path(destination_path).join(@path.Path(child_name)).to_string(),
        )
      }
    }
    _ =>
      @fsx.write_to_file(
        destination_path,
        @fsx.read_file(source_path),
        create=0o644,
      )
  }
}

///|
async fn copy_skill_tree_replace(
  source_path : String,
  destination_path : String,
) -> Unit {
  match @fs.kind(source_path, follow_symlink=false) {
    @fs.FileKind::Directory => {
      @fsx.make_directory(destination_path, recursive=true, exists_ok=true)
      for child in @fsx.list_directory(source_path) {
        let child_name = @path.Path(child).basename().to_string()
        copy_skill_tree_replace(
          child,
          @path.Path(destination_path).join(@path.Path(child_name)).to_string(),
        )
      }
    }
    _ =>
      @fsx.write_to_file(
        destination_path,
        @fsx.read_file(source_path),
        create=0o644,
      )
  }
}

///|
fn skill_slug(name : String) -> String {
  let builder = StringBuilder::new()
  let mut wrote_dash = false
  let mut wrote_any = false
  for rune in name.to_lower() {
    let ch = rune.to_int()
    if (ch >= 97 && ch <= 122) || (ch >= 48 && ch <= 57) {
      builder.write_char(rune)
      wrote_dash = false
      wrote_any = true
    } else if !wrote_dash && wrote_any {
      builder.write_char('-')
      wrote_dash = true
    }
  }
  let slug = builder.to_string()
  if slug.has_suffix("-") {
    slug[0:slug.length() - 1].to_string()
  } else {
    slug
  }
}

///|
fn scaffold_skill_text(name : String) -> String {
  "---\n" +
  "name: \{name}\n" +
  "description: \"Explain when this skill should be used, what domain it owns, and what outcome it should produce.\"\n" +
  "---\n" +
  "\n" +
  "# \{name}\n" +
  "\n" +
  "This skill owns one narrow capability. Keep the harness thin and put the domain judgment here.\n" +
  "\n" +
  "## Use this skill when\n" +
  "\n" +
  "- the task repeatedly appears in this workspace\n" +
  "- the model needs domain-specific process, not just generic reasoning\n" +
  "- the desired output has a stable shape that should compound over time\n" +
  "- bundled references or scripts materially improve accuracy or speed\n" +
  "\n" +
  "## Do not use this skill when\n" +
  "\n" +
  "- a deterministic CLI command is enough\n" +
  "- the task belongs to another skill with a narrower domain boundary\n" +
  "- the request is one-off and should not become permanent operating procedure\n" +
  "\n" +
  "## Inputs\n" +
  "\n" +
  "- objective: the concrete user or system goal\n" +
  "- workspace root: where files should be read or written\n" +
  "- relevant constraints: quality bar, safety limits, scope limits, approval rules\n" +
  "- available evidence: pages, files, APIs, logs, or artifacts that should anchor the work\n" +
  "\n" +
  "## Outputs\n" +
  "\n" +
  "- durable output paths that were created or updated\n" +
  "- a compact summary of what changed and why\n" +
  "- unresolved risks, gaps, or follow-up needs\n" +
  "- explicit blocker language if the task cannot be completed safely\n" +
  "\n" +
  "## Workflow\n" +
  "\n" +
  "1. Confirm the domain boundary.\n" +
  "   Refuse to sprawl into adjacent concerns. Say what this skill owns and what it does not own.\n" +
  "2. Load only the minimum supporting context.\n" +
  "   Read the exact workspace files or bundled references that materially change the answer.\n" +
  "3. Separate latent and deterministic work.\n" +
  "   Use judgment for synthesis, classification, prioritization, and gap detection. Use code, scripts, or CLI commands for repeatable file work.\n" +
  "4. Produce durable artifacts.\n" +
  "   Prefer updating real files over leaving useful work trapped in prose.\n" +
  "5. Validate the result.\n" +
  "   Check that paths exist, links resolve, formatting is sane, and the output contract was satisfied.\n" +
  "6. Report with precision.\n" +
  "   Name the exact files touched, what changed, and what still needs review.\n" +
  "\n" +
  "## Quality bar\n" +
  "\n" +
  "- do not claim success without durable artifacts or a verified deterministic result\n" +
  "- keep summaries specific enough to debug later\n" +
  "- preserve source-of-truth boundaries\n" +
  "- make contradictions and uncertainty explicit\n" +
  "- avoid hidden side effects outside the declared write scope\n" +
  "\n" +
  "## Suggested references\n" +
  "\n" +
  "- put detailed domain rules under `references/`\n" +
  "- keep examples under `references/examples.md` if they help future runs\n" +
  "- add scripts under `scripts/` only when deterministic repetition justifies them\n" +
  "\n" +
  "## Example invocation\n" +
  "\n" +
  "Objective: explain a repeated domain task and materialize the correct files.\n" +
  "\n" +
  "Expected behavior:\n" +
  "\n" +
  "- inspect the minimum required inputs\n" +
  "- apply the domain workflow above\n" +
  "- write or update the intended files\n" +
  "- return a concise summary with explicit output paths\n" +
  "\n" +
  "## Maintenance notes\n" +
  "\n" +
  "- if this skill grows past a lean operating guide, split detailed material into `references/`\n" +
  "- if the same code is being repeated, move it into `scripts/`\n" +
  "- if the domain boundary changes, update the description first so the resolver still triggers correctly\n"
}
