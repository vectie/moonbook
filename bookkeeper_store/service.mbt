///|
fn rejected_result(
  root : String,
  issues : Array[String],
) -> BookkeeperMutationResult {
  {
    accepted: false,
    idempotent: false,
    event: None,
    review: None,
    issues,
    ui_state_path: bookkeeper_ui_state_path(root),
  }
}

///|
fn accepted_result(
  root : String,
  event : @bookkeeper.VersionedRecordReference,
  review? : GovernedReviewReceipt,
  idempotent? : Bool = false,
) -> BookkeeperMutationResult {
  {
    accepted: true,
    idempotent,
    event: Some(event),
    review,
    issues: [],
    ui_state_path: bookkeeper_ui_state_path(root),
  }
}

///|
pub async fn persist_bookkeeper_record(
  root : String,
  record : DurableBookkeeperRecord,
) -> BookkeeperMutationResult {
  let lock = acquire_store_lock(root)
  defer release_store_lock(lock)
  let snapshot = replay_bookkeeper_store(root)
  for existing in snapshot.records {
    if existing.record == record.record {
      if existing == record {
        ignore(rebuild_bookkeeper_projection_unlocked(root))
        return accepted_result(root, record.record, idempotent=true)
      }
      return rejected_result(root, [
        "same record reference has conflicting canonical content",
      ])
    }
  }
  let issues = validate_record(snapshot, record)
  if !issues.is_empty() {
    return rejected_result(root, issues)
  }
  let event : BookkeeperJournalEvent = {
    contract_version: bookkeeper_store_contract_version(),
    sequence: snapshot.last_sequence + 1,
    event: record.record,
    event_kind: "record",
    recorded_at: record.recorded_at,
    record: Some(record),
    review: None,
    envelope: None,
  }
  persist_event(root, event)
  ignore(rebuild_bookkeeper_projection_unlocked(root))
  accepted_result(root, event.event)
}

///|
pub async fn apply_governed_review(
  root : String,
  mutation : GovernedReviewMutation,
) -> BookkeeperMutationResult {
  let lock = acquire_store_lock(root)
  defer release_store_lock(lock)
  let snapshot = replay_bookkeeper_store(root)
  let authority_grant_valid = reviewer_has_active_grant(root, mutation)
  for existing in snapshot.reviews {
    if existing.receipt == mutation.receipt {
      let expected = review_receipt(snapshot, mutation, authority_grant_valid~)
      if existing == expected {
        ignore(rebuild_bookkeeper_projection_unlocked(root))
        return accepted_result(
          root,
          existing.receipt,
          review=existing,
          idempotent=true,
        )
      }
      return rejected_result(root, [
        "same review receipt reference has conflicting canonical content",
      ])
    }
  }
  let receipt = review_receipt(snapshot, mutation, authority_grant_valid~)
  if !receipt.issues.is_empty() {
    return {
      accepted: false,
      idempotent: false,
      event: None,
      review: Some(receipt),
      issues: receipt.issues,
      ui_state_path: bookkeeper_ui_state_path(root),
    }
  }
  let event : BookkeeperJournalEvent = {
    contract_version: bookkeeper_store_contract_version(),
    sequence: snapshot.last_sequence + 1,
    event: receipt.receipt,
    event_kind: "review",
    recorded_at: receipt.decided_at,
    record: None,
    review: Some(receipt),
    envelope: None,
  }
  persist_event(root, event)
  ignore(rebuild_bookkeeper_projection_unlocked(root))
  accepted_result(root, event.event, review=receipt)
}

///|
pub async fn persist_transport_envelope(
  root : String,
  envelope : BookkeeperTransportEnvelope,
) -> BookkeeperMutationResult {
  let lock = acquire_store_lock(root)
  defer release_store_lock(lock)
  let snapshot = replay_bookkeeper_store(root)
  for existing in snapshot.envelopes {
    if existing.envelope == envelope.envelope {
      if existing == envelope {
        ignore(rebuild_bookkeeper_projection_unlocked(root))
        return accepted_result(root, envelope.envelope, idempotent=true)
      }
      return rejected_result(root, [
        "same transport envelope reference has conflicting canonical content",
      ])
    }
  }
  let issues = validate_envelope(snapshot, envelope)
  if !issues.is_empty() {
    return rejected_result(root, issues)
  }
  let event : BookkeeperJournalEvent = {
    contract_version: bookkeeper_store_contract_version(),
    sequence: snapshot.last_sequence + 1,
    event: envelope.envelope,
    event_kind: "envelope",
    recorded_at: envelope.recorded_at,
    record: None,
    review: None,
    envelope: Some(envelope),
  }
  persist_event(root, event)
  ignore(rebuild_bookkeeper_projection_unlocked(root))
  accepted_result(root, event.event)
}
