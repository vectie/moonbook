///|
async fn write_fixture(root : String) -> Unit {
  let manifest : @pack.MoonPackManifest = {
    id: "fixture",
    version: "1.0.0",
    display_name: "Fixture",
    product_id: "fixture",
    kind: DomainPack,
    required_runtime_extensions: [],
    book_templates: [],
    schemas: [],
    tools: [],
    workflows: [],
    skills: [],
    policies: [],
    provider_ports: [],
    schedules: [],
    app_entrypoints: [],
    migrations: [],
    evaluations: [],
    uninstall_contract: Some(
      @pack.contract_ref("uninstall", "1.0.0", "UNINSTALL.md"),
    ),
  }
  @fs.write_file(
    root + "/pack.json",
    @utf8.encode(@pack.encode_manifest(manifest)),
    create=0o644,
    truncate=true,
  )
  @fs.write_file(
    root + "/UNINSTALL.md",
    @utf8.encode("Preserve user data.\n"),
    create=0o644,
    truncate=true,
  )
}

///|
async test "MoonBook projects a generic pack lifecycle" {
  let source = @fs.tmpdir(prefix="moonbook-pack-source")
  let workspace = @fs.tmpdir(prefix="moonbook-pack-workspace")
  write_fixture(source)
  assert_true(inspect(source).issues.is_empty())
  let projection = install(source, workspace)
  assert_eq(projection.pack_id, "fixture")
  assert_eq(list_active(workspace).length(), 1)
  assert_true(verify(workspace, "fixture", "1.0.0").ok)
  let removed = deactivate(workspace, "fixture")
  assert_eq(removed.pack_id, "fixture")
  assert_eq(list_active(workspace).length(), 0)
  @fs.rmdir(source, recursive=true)
  @fs.rmdir(workspace, recursive=true)
}
