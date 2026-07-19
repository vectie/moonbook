///|
fn store_root(root : String) -> String {
  @pathx.join(root, ".moonbook/bookkeeper")
}

///|
fn journal_root(root : String) -> String {
  @pathx.join(store_root(root), "journal")
}

///|
pub fn bookkeeper_ui_state_path(root : String) -> String {
  @pathx.join(store_root(root), "ui-state.json")
}

///|
pub fn bookkeeper_snapshot_path(root : String) -> String {
  @pathx.join(store_root(root), "snapshot.json")
}

///|
pub fn bookkeeper_authority_registry_path(root : String) -> String {
  @pathx.join(store_root(root), "authorities.json")
}

///|
fn safe_record_key(value : String) -> String {
  value
  .replace(old="/", new="_")
  .replace(old="\\", new="_")
  .replace(old=":", new="_")
  .replace(old=" ", new="_")
  .to_string()
}

///|
/// Digest the canonical JSON representation persisted by the store. Producers
/// use the same helper before constructing a durable record reference.
pub fn bookkeeper_payload_digest(payload : Json) -> String {
  "sha256:" +
  @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(payload.stringify())),
  )
}

///|
fn journal_event_path(
  root : String,
  reference : @bookkeeper.VersionedRecordReference,
) -> String {
  @pathx.join(
    journal_root(root),
    safe_record_key(reference.record_id) +
    "--" +
    safe_record_key(reference.record_version) +
    ".json",
  )
}

///|
async fn ensure_store(root : String) -> Unit {
  @fsx.make_directory(journal_root(root), recursive=true, exists_ok=true)
}

///|
async fn acquire_store_lock(root : String) -> @fs.File {
  ensure_store(root)
  let lock = @fs.open(
    @pathx.join(store_root(root), "store.lock"),
    mode=@fs.ReadWrite,
    create=0o600,
    truncate=false,
  )
  lock.lock(@fs.Exclusive)
  lock
}

///|
fn release_store_lock(lock : @fs.File) -> Unit {
  lock.unlock()
  lock.close()
}

///|
async fn write_atomic_json(path : String, value : Json) -> Unit {
  let temporary = path + ".tmp-" + @async.now().to_int().to_string()
  @fsx.write_to_file(temporary, value.stringify(indent=2), create=0o644)
  @fsx.atomic_replace(temporary, path)
}

///|
fn empty_snapshot() -> BookkeeperStoreSnapshot {
  {
    contract_version: bookkeeper_store_contract_version(),
    last_sequence: 0,
    records: [],
    reviews: [],
    envelopes: [],
    replay_issues: [],
  }
}

///|
fn empty_authority_registry() -> BookkeeperAuthorityRegistry {
  { contract_version: bookkeeper_store_contract_version(), grants: [] }
}

///|
async fn read_authority_registry(root : String) -> BookkeeperAuthorityRegistry {
  let path = bookkeeper_authority_registry_path(root)
  if !@fsx.exists(path) {
    return empty_authority_registry()
  }
  let registry : BookkeeperAuthorityRegistry = @json.from_json(
    @json.parse(@fsx.read_file(path)),
  ) catch {
    _ => return empty_authority_registry()
  }
  if registry.contract_version != bookkeeper_store_contract_version() {
    empty_authority_registry()
  } else {
    registry
  }
}

///|
/// Read the CLI-installed reviewer grants for an operator-facing status view.
/// This does not install, activate, or otherwise mutate authority.
pub async fn bookkeeper_authority_registry(
  root : String,
) -> BookkeeperAuthorityRegistry {
  read_authority_registry(root)
}

///|
fn authority_grant_matches(
  grant : BookkeeperAuthorityGrant,
  reviewer_kind : @bookkeeper.ReviewerKind,
  reviewer : StoreReviewerAuthority,
) -> Bool {
  grant.active &&
  grant.contract_version == bookkeeper_store_contract_version() &&
  reference_complete(grant.grant) &&
  grant.grant == reviewer.grant &&
  grant.reviewer_id == reviewer.reviewer_id &&
  grant.reviewer_kind == reviewer_kind &&
  grant.authority_ref == reviewer.authority_ref &&
  grant.evidence_refs == reviewer.evidence_refs
}

///|
async fn reviewer_has_active_grant(
  root : String,
  mutation : GovernedReviewMutation,
) -> Bool {
  let registry = read_authority_registry(root)
  let mut latest : BookkeeperAuthorityGrant? = None
  for grant in registry.grants {
    if grant.reviewer_id != mutation.reviewer.reviewer_id ||
      grant.authority_ref != mutation.reviewer.authority_ref {
      continue
    }
    match latest {
      None => latest = Some(grant)
      Some(current) =>
        if grant.granted_at > current.granted_at {
          latest = Some(grant)
        }
    }
  }
  match latest {
    Some(grant) =>
      authority_grant_matches(grant, mutation.reviewer_kind, mutation.reviewer)
    None => false
  }
}

///|
pub async fn install_bookkeeper_authority_grant(
  root : String,
  grant : BookkeeperAuthorityGrant,
) -> BookkeeperAuthorityRegistry {
  let lock = acquire_store_lock(root)
  defer release_store_lock(lock)
  if grant.contract_version != bookkeeper_store_contract_version() ||
    !reference_complete(grant.grant) ||
    grant.reviewer_id.is_blank() ||
    grant.authority_ref.is_blank() ||
    grant.evidence_refs.is_empty() ||
    grant.reviewer_kind != @bookkeeper.Human {
    fail("invalid Bookkeeper authority grant")
  }
  let registry = read_authority_registry(root)
  for existing in registry.grants {
    if existing.grant.record_id == grant.grant.record_id &&
      existing.grant.record_version == grant.grant.record_version {
      if existing == grant {
        return registry
      }
      fail("conflicting Bookkeeper authority grant identity/version")
    }
  }
  registry.grants.push(grant)
  write_atomic_json(
    bookkeeper_authority_registry_path(root),
    registry.to_json(),
  )
  registry
}

///|
fn reference_complete(reference : @bookkeeper.VersionedRecordReference) -> Bool {
  !reference.record_id.is_blank() &&
  !reference.record_version.is_blank() &&
  !reference.record_digest.is_blank()
}

///|
fn evidence_complete(
  reference : @bookkeeper.VersionedEvidenceReference,
) -> Bool {
  !reference.reference_id.is_blank() &&
  !reference.reference_version.is_blank() &&
  !reference.digest.is_blank() &&
  !reference.provenance_ref.is_blank()
}

///|
fn exact_reference(
  left : @bookkeeper.VersionedRecordReference,
  right : @bookkeeper.VersionedRecordReference,
) -> Bool {
  left == right
}

///|
fn exact_evidence(
  left : @bookkeeper.VersionedEvidenceReference,
  right : @bookkeeper.VersionedEvidenceReference,
) -> Bool {
  left == right
}

///|
fn snapshot_has_reference(
  snapshot : BookkeeperStoreSnapshot,
  reference : @bookkeeper.VersionedRecordReference,
) -> Bool {
  snapshot.records.any(fn(record) { exact_reference(record.record, reference) }) ||
  snapshot.reviews.any(fn(review) {
    exact_reference(review.receipt, reference) ||
    exact_reference(review.mutation, reference)
  }) ||
  snapshot.envelopes.any(fn(envelope) {
    exact_reference(envelope.envelope, reference)
  })
}

///|
fn snapshot_has_identity_conflict(
  snapshot : BookkeeperStoreSnapshot,
  reference : @bookkeeper.VersionedRecordReference,
) -> Bool {
  snapshot.records.any(fn(record) {
    record.record.record_id == reference.record_id &&
    !exact_reference(record.record, reference)
  }) ||
  snapshot.reviews.any(fn(review) {
    (
      review.receipt.record_id == reference.record_id &&
      !exact_reference(review.receipt, reference)
    ) ||
    (
      review.mutation.record_id == reference.record_id &&
      !exact_reference(review.mutation, reference)
    )
  }) ||
  snapshot.envelopes.any(fn(envelope) {
    envelope.envelope.record_id == reference.record_id &&
    !exact_reference(envelope.envelope, reference)
  })
}

///|
fn find_record(
  snapshot : BookkeeperStoreSnapshot,
  reference : @bookkeeper.VersionedRecordReference,
) -> DurableBookkeeperRecord? {
  for record in snapshot.records {
    if exact_reference(record.record, reference) {
      return Some(record)
    }
  }
  None
}

///|
fn exact_links_present(
  snapshot : BookkeeperStoreSnapshot,
  links : ArrayView[@bookkeeper.VersionedRecordReference],
  issues : Array[String],
) -> Unit {
  for link in links {
    if !reference_complete(link) {
      issues.push("incomplete link reference")
    } else if !snapshot_has_reference(snapshot, link) {
      issues.push(
        "missing exact link \{link.record_id}@\{link.record_version}:\{link.record_digest}",
      )
    }
  }
}

///|
fn accepted_review_for(
  snapshot : BookkeeperStoreSnapshot,
  subject : @bookkeeper.VersionedRecordReference,
  stage : BookkeeperStage,
) -> Bool {
  snapshot.reviews.any(fn(review) {
    review.stage == stage &&
    exact_reference(review.subject, subject) &&
    review.review_complete &&
    review.disposition == @bookkeeper.Accept
  })
}

///|
fn has_linked_record_stage(
  snapshot : BookkeeperStoreSnapshot,
  links : ArrayView[@bookkeeper.VersionedRecordReference],
  stage : BookkeeperStage,
) -> Bool {
  links.any(fn(link) {
    match find_record(snapshot, link) {
      Some(record) => record.stage == stage
      None => false
    }
  })
}

///|
fn has_linked_accepted_stage(
  snapshot : BookkeeperStoreSnapshot,
  links : ArrayView[@bookkeeper.VersionedRecordReference],
  stage : BookkeeperStage,
) -> Bool {
  links.any(fn(link) { accepted_review_for(snapshot, link, stage) })
}

///|
fn has_linked_mooncode_result_ingress(
  snapshot : BookkeeperStoreSnapshot,
  links : ArrayView[@bookkeeper.VersionedRecordReference],
) -> Bool {
  snapshot.envelopes.any(fn(envelope) {
    envelope.direction == Ingress &&
    envelope.source_product == "mooncode" &&
    envelope.destination_product == "moonbook" &&
    envelope.message_kind == "mooncode.result" &&
    links.any(fn(link) { link == envelope.envelope })
  })
}

///|
fn validate_record(
  snapshot : BookkeeperStoreSnapshot,
  record : DurableBookkeeperRecord,
) -> Array[String] {
  let issues : Array[String] = []
  if record.contract_version != bookkeeper_store_contract_version() {
    issues.push("invalid store contract: \{record.contract_version}")
  }
  let expected_payload_contract = match record.stage {
    DeliverableAcceptance => @bookkeeper.bookkeeper_contract_version()
    OutcomeBinding | ThreeGapFinding | MoonCodeWorkOrder =>
      @bookkeeper.three_gap_contract_version()
    CapabilityProposal => @bookkeeper.bookkeeper_contract_version()
    MoonCodeResult | Evaluation | Adoption =>
      @bookkeeper.capability_adoption_contract_version()
    ThreeGapReview | CapabilityReview => bookkeeper_store_contract_version()
  }
  let payload_contract = match record.payload {
    Object(fields) =>
      match fields.get("contract_version") {
        Some(String(value)) => value
        _ => ""
      }
    _ => ""
  }
  if payload_contract != expected_payload_contract {
    issues.push(
      "stage payload must declare canonical contract \{expected_payload_contract}",
    )
  }
  if !reference_complete(record.record) {
    issues.push("record identity, version, and digest are required")
  }
  if record.record.record_digest != bookkeeper_payload_digest(record.payload) {
    issues.push("record digest does not match canonical payload JSON")
  }
  if snapshot_has_identity_conflict(snapshot, record.record) {
    issues.push(
      "conflicting durable record identity: \{record.record.record_id}",
    )
  }
  if record.title.is_blank() || record.summary.is_blank() {
    issues.push("record title and summary are required")
  }
  if record.owner_route.is_blank() || record.source_product.is_blank() {
    issues.push("owner route and source product are required")
  }
  if record.side_effects_applied {
    issues.push("Bookkeeper durable records cannot claim applied side effects")
  }
  if record.stage.is_reviewable() && !record.requires_human_review {
    issues.push("reviewable stages must remain explicitly human-review gated")
  }
  if record.stage.is_reviewable() &&
    (
      record.status == "accepted" ||
      record.status == "authorized" ||
      record.status == "adopted"
    ) {
    issues.push("a durable subject cannot self-declare a reviewed disposition")
  }
  if record.evidence_refs.is_empty() {
    issues.push("record evidence is required")
  }
  for evidence in record.evidence_refs {
    if !evidence_complete(evidence) {
      issues.push("incomplete evidence reference: \{evidence.reference_id}")
    }
  }
  match record.subject {
    Some(subject) =>
      if !snapshot_has_reference(snapshot, subject) {
        issues.push("subject does not exactly match a durable record")
      }
    None => ()
  }
  exact_links_present(snapshot, record.links, issues)
  match record.stage {
    DeliverableAcceptance => ()
    OutcomeBinding =>
      if !has_linked_accepted_stage(
          snapshot,
          record.links,
          DeliverableAcceptance,
        ) {
        issues.push("outcome binding requires an accepted deliverable link")
      }
    ThreeGapFinding =>
      if !has_linked_record_stage(snapshot, record.links, OutcomeBinding) {
        issues.push("Three-Gap finding requires an outcome binding link")
      }
    ThreeGapReview | CapabilityReview =>
      issues.push("review stages must be created as governed review receipts")
    CapabilityProposal =>
      if !has_linked_accepted_stage(snapshot, record.links, ThreeGapFinding) {
        issues.push("capability proposal requires a reviewed Three-Gap finding")
      }
    MoonCodeWorkOrder =>
      if !has_linked_accepted_stage(snapshot, record.links, CapabilityProposal) {
        issues.push(
          "MoonCode work order requires an accepted capability proposal",
        )
      }
    MoonCodeResult =>
      if record.source_product != "mooncode" ||
        !has_linked_accepted_stage(snapshot, record.links, MoonCodeWorkOrder) ||
        !has_linked_mooncode_result_ingress(snapshot, record.links) {
        issues.push(
          "MoonCode result requires source_product=mooncode, an accepted work-order link, and an exact mooncode.result ingress envelope",
        )
      }
    Evaluation =>
      if !has_linked_record_stage(snapshot, record.links, MoonCodeResult) {
        issues.push("evaluation requires an exact MoonCode result link")
      }
    Adoption =>
      if !has_linked_accepted_stage(snapshot, record.links, Evaluation) {
        issues.push("adoption requires an accepted evaluation link")
      }
  }
  issues
}

///|
fn review_subject_evidence_exact(
  record : DurableBookkeeperRecord,
  review_evidence : ArrayView[@bookkeeper.VersionedEvidenceReference],
) -> Bool {
  !review_evidence.is_empty() &&
  review_evidence.all(fn(reference) {
    evidence_complete(reference) &&
    record.evidence_refs.any(fn(subject_reference) {
      exact_evidence(reference, subject_reference)
    })
  }) &&
  record.evidence_refs.all(fn(reference) {
    review_evidence.any(fn(review_reference) {
      exact_evidence(reference, review_reference)
    })
  })
}

///|
fn review_receipt(
  snapshot : BookkeeperStoreSnapshot,
  mutation : GovernedReviewMutation,
  authority_grant_valid? : Bool = true,
) -> GovernedReviewReceipt {
  let issues : Array[String] = []
  if mutation.contract_version != bookkeeper_store_contract_version() {
    issues.push("invalid review mutation contract")
  }
  if !mutation.stage.is_reviewable() {
    issues.push("stage is not reviewable through the governed mutation API")
  }
  if !reference_complete(mutation.mutation) ||
    !reference_complete(mutation.receipt) {
    issues.push("mutation and receipt references must be complete")
  }
  if snapshot_has_identity_conflict(snapshot, mutation.mutation) ||
    snapshot_has_identity_conflict(snapshot, mutation.receipt) {
    issues.push("mutation or receipt identity conflicts with durable history")
  }
  let subject = find_record(snapshot, mutation.subject)
  match subject {
    None => issues.push("review subject does not exist with exact linkage")
    Some(record) => {
      if record.stage != mutation.stage {
        issues.push("review stage does not match subject stage")
      }
      if !review_subject_evidence_exact(record, mutation.evidence_refs) {
        issues.push("review evidence is not an exact subject evidence snapshot")
      }
      if mutation.requested == @bookkeeper.Accept &&
        (
          !record.issue_refs.is_empty() ||
          record.status == "blocked" ||
          record.status == "failed" ||
          record.status == "invalid"
        ) {
        issues.push(
          "accepted review requires a clean, non-failing subject state",
        )
      }
    }
  }
  if mutation.reviewer_kind != @bookkeeper.Human {
    issues.push("only a named human can submit a governed review")
  }
  if !reference_complete(mutation.reviewer.grant) || !authority_grant_valid {
    issues.push("reviewer authority grant is missing, inactive, or mismatched")
  }
  if mutation.reviewer.reviewer_id.is_blank() ||
    mutation.reviewer.authority_ref.is_blank() ||
    !mutation.reviewer.authorized {
    issues.push("named authorized reviewer authority is required")
  }
  if mutation.reviewer.evidence_refs.is_empty() ||
    !mutation.reviewer.evidence_refs.all(fn(reference_id) {
      mutation.evidence_refs.any(fn(reference) {
        reference.reference_id == reference_id
      })
    }) {
    issues.push(
      "reviewer authority evidence must be present in review evidence",
    )
  }
  let complete = issues.is_empty()
  let disposition = if mutation.requested == @bookkeeper.Accept && !complete {
    @bookkeeper.Revise
  } else {
    mutation.requested
  }
  {
    contract_version: bookkeeper_store_contract_version(),
    mutation: mutation.mutation,
    receipt: mutation.receipt,
    stage: mutation.stage,
    subject: mutation.subject,
    requested: mutation.requested,
    disposition,
    reviewer_kind: mutation.reviewer_kind,
    reviewer: mutation.reviewer,
    evidence_refs: mutation.evidence_refs,
    summary: mutation.summary,
    decided_at: mutation.decided_at,
    issues,
    review_complete: complete,
    side_effects_applied: false,
  }
}

///|
fn validate_envelope(
  snapshot : BookkeeperStoreSnapshot,
  envelope : BookkeeperTransportEnvelope,
) -> Array[String] {
  let issues : Array[String] = []
  if envelope.contract_version != bookkeeper_transport_contract_version() {
    issues.push("invalid transport contract")
  }
  if !reference_complete(envelope.envelope) ||
    !reference_complete(envelope.subject) {
    issues.push("envelope and subject references must be complete")
  }
  if snapshot_has_identity_conflict(snapshot, envelope.envelope) {
    issues.push("transport envelope identity conflicts with durable history")
  }
  if envelope.message_kind.is_blank() || envelope.authority_ref.is_blank() {
    issues.push("message kind and authority reference are required")
  }
  if envelope.external_activation_allowed || envelope.side_effects_applied {
    issues.push(
      "transport envelopes cannot authorize or apply external activation",
    )
  }
  if !snapshot_has_reference(snapshot, envelope.subject) {
    issues.push("transport subject is not an exact durable reference")
  }
  exact_links_present(snapshot, envelope.links, issues)
  if envelope.evidence_refs.is_empty() ||
    !envelope.evidence_refs.all(evidence_complete) {
    issues.push("complete transport evidence is required")
  }
  match envelope.direction {
    Ingress =>
      if envelope.destination_product != "moonbook" ||
        envelope.source_product.is_blank() ||
        envelope.source_product == "moonbook" {
        issues.push(
          "ingress must originate outside MoonBook and target moonbook",
        )
      }
    Egress =>
      if envelope.source_product != "moonbook" ||
        envelope.destination_product.is_blank() ||
        envelope.destination_product == "moonbook" {
        issues.push(
          "egress must originate in MoonBook and target another product",
        )
      }
  }
  if envelope.message_kind == "mooncode.work_order" {
    match find_record(snapshot, envelope.subject) {
      Some(record) =>
        if envelope.direction != Egress ||
          record.stage != MoonCodeWorkOrder ||
          !accepted_review_for(snapshot, record.record, MoonCodeWorkOrder) {
          issues.push(
            "mooncode.work_order egress requires an accepted MoonCode work-order subject",
          )
        }
      None => ()
    }
  }
  if envelope.message_kind == "mooncode.result" {
    match find_record(snapshot, envelope.subject) {
      Some(record) =>
        if envelope.direction != Ingress ||
          envelope.source_product != "mooncode" ||
          record.stage != MoonCodeWorkOrder ||
          !accepted_review_for(snapshot, record.record, MoonCodeWorkOrder) {
          issues.push(
            "mooncode.result ingress requires an accepted MoonCode work-order subject",
          )
        }
      None => ()
    }
  }
  issues
}

///|
fn event_identity_conflict(
  events : ArrayView[BookkeeperJournalEvent],
  reference : @bookkeeper.VersionedRecordReference,
) -> Bool {
  events.any(fn(event) {
    event.event.record_id == reference.record_id && event.event != reference
  })
}

///|
fn apply_replayed_event(
  snapshot : BookkeeperStoreSnapshot,
  event : BookkeeperJournalEvent,
) -> Unit {
  if event.contract_version != bookkeeper_store_contract_version() {
    snapshot.replay_issues.push(
      "event \{event.event.record_id} has an invalid store contract",
    )
    return
  }
  if event.sequence > snapshot.last_sequence {
    snapshot.last_sequence = event.sequence
  }
  match event.event_kind {
    "record" =>
      match event.record {
        Some(record) => {
          let issues = validate_record(snapshot, record)
          if issues.is_empty() {
            snapshot.records.push(record)
          } else {
            for issue in issues {
              snapshot.replay_issues.push(
                "record \{record.record.record_id}: \{issue}",
              )
            }
          }
        }
        None =>
          snapshot.replay_issues.push("record event has no record payload")
      }
    "review" =>
      match event.review {
        Some(review) => {
          let replayed = review_receipt(snapshot, {
            contract_version: review.contract_version,
            mutation: review.mutation,
            receipt: review.receipt,
            stage: review.stage,
            subject: review.subject,
            requested: review.requested,
            reviewer_kind: review.reviewer_kind,
            reviewer: review.reviewer,
            evidence_refs: review.evidence_refs,
            summary: review.summary,
            decided_at: review.decided_at,
          })
          if replayed == review {
            snapshot.reviews.push(review)
          } else {
            snapshot.replay_issues.push(
              "review \{review.receipt.record_id} failed exact receipt replay",
            )
          }
        }
        None =>
          snapshot.replay_issues.push("review event has no review payload")
      }
    "envelope" =>
      match event.envelope {
        Some(envelope) => {
          let issues = validate_envelope(snapshot, envelope)
          if issues.is_empty() {
            snapshot.envelopes.push(envelope)
          } else {
            for issue in issues {
              snapshot.replay_issues.push(
                "envelope \{envelope.envelope.record_id}: \{issue}",
              )
            }
          }
        }
        None =>
          snapshot.replay_issues.push("envelope event has no envelope payload")
      }
    other => snapshot.replay_issues.push("unknown event kind: \{other}")
  }
}

///|
pub async fn replay_bookkeeper_store(root : String) -> BookkeeperStoreSnapshot {
  ensure_store(root)
  let events : Array[BookkeeperJournalEvent] = []
  let issues : Array[String] = []
  for path in @fsx.list_directory(journal_root(root)) {
    if !path.has_suffix(".json") {
      continue
    }
    let event : BookkeeperJournalEvent = @json.from_json(
      @json.parse(@fsx.read_file(path)),
    ) catch {
      _ => {
        issues.push("unreadable journal event: \{path}")
        continue
      }
    }
    if events.any(fn(existing) { existing.event == event.event }) {
      continue
    }
    if event_identity_conflict(events, event.event) {
      issues.push(
        "conflicting journal event identity: \{event.event.record_id}",
      )
      continue
    }
    events.push(event)
  }
  events.sort_by(fn(left, right) {
    let sequence = left.sequence.compare(right.sequence)
    if sequence == 0 {
      left.event.record_id.compare(right.event.record_id)
    } else {
      sequence
    }
  })
  let snapshot = empty_snapshot()
  for issue in issues {
    snapshot.replay_issues.push(issue)
  }
  for event in events {
    apply_replayed_event(snapshot, event)
  }
  snapshot
}

///|
async fn persist_event(root : String, event : BookkeeperJournalEvent) -> Unit {
  ensure_store(root)
  write_atomic_json(journal_event_path(root, event.event), event.to_json())
}
