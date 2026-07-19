///|
/// MoonBook is the durable lifecycle host for every MoonSuite pack. This
/// adapter deliberately accepts only the generic SDK contracts.
pub async fn inspect(source_root : String) -> @installer.SourceInspection {
  @installer.inspect_source(source_root)
}

///|
/// Install a capability-free pack and return the projection consumed by hosts.
pub async fn install(
  source_root : String,
  workspace : String,
) -> @host.HostActivationProjection {
  @installer.install(source_root, workspace) |> ignore
  project_active(workspace, @installer.load_source_manifest(source_root).id)
}

///|
/// Install with an explicit host capability profile. Authority is never
/// inferred from a product or pack identifier.
pub async fn install_authorized(
  source_root : String,
  workspace : String,
  profile_path : String,
) -> @host.HostActivationProjection {
  let profile = @installer.load_host_profile(profile_path)
  @installer.install_authorized(source_root, workspace, profile) |> ignore
  project_active(workspace, @installer.load_source_manifest(source_root).id)
}

///|
pub async fn list_active(
  workspace : String,
) -> Array[@installer.ActivePackPointer] {
  @installer.list_active(workspace)
}

///|
pub async fn verify(
  workspace : String,
  pack_id : String,
  version : String,
) -> @installer.InstalledVerification {
  @installer.verify_installed(workspace, pack_id, version)
}

///|
pub async fn project_active(
  workspace : String,
  pack_id : String,
) -> @host.HostActivationProjection {
  guard @installer.active_pack(workspace, pack_id) is Some(pointer) else {
    fail("pack is not active: " + pack_id)
  }
  guard @installer.active_manifest(workspace, pack_id) is Some(manifest) else {
    fail("active pack manifest is unavailable: " + pack_id)
  }
  @host.activation_projection(manifest, pointer)
}

///|
pub async fn activate(
  workspace : String,
  pack_id : String,
  version : String,
) -> @host.HostActivationProjection {
  @installer.activate_version(workspace, pack_id, version) |> ignore
  project_active(workspace, pack_id)
}

///|
/// Deactivation removes only the active pointer. The returned projection tells
/// runtime hosts what to withdraw and which user namespaces must be preserved.
pub async fn deactivate(
  workspace : String,
  pack_id : String,
) -> @host.HostDeactivationProjection {
  guard @installer.active_manifest(workspace, pack_id) is Some(manifest) else {
    fail("pack is not active: " + pack_id)
  }
  @installer.deactivate(workspace, pack_id) |> ignore
  @host.deactivation_projection(manifest)
}
