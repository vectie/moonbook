///|
fn disposition_label(disposition : @bookkeeper.BookkeeperDisposition) -> String {
  match disposition {
    @bookkeeper.Accept => "accepted"
    @bookkeeper.Reject => "rejected"
    @bookkeeper.Revise => "revision required"
    @bookkeeper.Escalate => "escalated"
  }
}

///|
fn disposition_tone(disposition : @bookkeeper.BookkeeperDisposition) -> String {
  match disposition {
    @bookkeeper.Accept => "healthy"
    @bookkeeper.Reject | @bookkeeper.Revise => "alert"
    @bookkeeper.Escalate => "review"
  }
}

///|
fn latest_review_for_record(
  snapshot : BookkeeperStoreSnapshot,
  record : DurableBookkeeperRecord,
) -> GovernedReviewReceipt? {
  let mut latest : GovernedReviewReceipt? = None
  for review in snapshot.reviews {
    if review.stage != record.stage || review.subject != record.record {
      continue
    }
    match latest {
      None => latest = Some(review)
      Some(current) =>
        if review.decided_at > current.decided_at {
          latest = Some(review)
        }
    }
  }
  latest
}

///|
fn record_ui_item(
  snapshot : BookkeeperStoreSnapshot,
  record : DurableBookkeeperRecord,
) -> @bookkeeper.BookkeeperUiItem {
  let review = latest_review_for_record(snapshot, record)
  let status = match review {
    Some(receipt) => disposition_label(receipt.disposition)
    None => record.status
  }
  let tone = match review {
    Some(receipt) => disposition_tone(receipt.disposition)
    None =>
      if record.issue_refs.is_empty() {
        if record.requires_human_review {
          "review"
        } else {
          "info"
        }
      } else {
        "alert"
      }
  }
  let review_issue_count = match review {
    Some(receipt) => receipt.issues.length()
    None => 0
  }
  {
    stage: record.stage.id(),
    title: record.title,
    record_id: record.record.record_id,
    record_version: record.record.record_version,
    status,
    tone,
    summary: record.summary,
    owner_route: record.owner_route,
    evidence_count: record.evidence_refs.length(),
    issue_count: record.issue_refs.length() + review_issue_count,
    requires_human_review: match review {
      Some(receipt) =>
        !receipt.review_complete || receipt.disposition != @bookkeeper.Accept
      None => record.requires_human_review
    },
    next_action: match review {
      Some(receipt) =>
        if receipt.disposition == @bookkeeper.Accept {
          record.next_action
        } else {
          "resolve governed review"
        }
      None => record.next_action
    },
  }
}

///|
fn review_ui_item(
  review : GovernedReviewReceipt,
  stage : String,
  title : String,
  next_action : String,
) -> @bookkeeper.BookkeeperUiItem {
  {
    stage,
    title,
    record_id: review.receipt.record_id,
    record_version: review.receipt.record_version,
    status: disposition_label(review.disposition),
    tone: disposition_tone(review.disposition),
    summary: review.summary,
    owner_route: review.reviewer.reviewer_id,
    evidence_count: review.evidence_refs.length(),
    issue_count: review.issues.length(),
    requires_human_review: !review.review_complete ||
    review.disposition != @bookkeeper.Accept,
    next_action,
  }
}

///|
pub fn project_bookkeeper_ui_state(
  root : String,
  snapshot : BookkeeperStoreSnapshot,
) -> @bookkeeper.BookkeeperUiState {
  let deliverable_acceptance : Array[@bookkeeper.BookkeeperUiItem] = []
  let outcome_binding : Array[@bookkeeper.BookkeeperUiItem] = []
  let three_gap_findings : Array[@bookkeeper.BookkeeperUiItem] = []
  let three_gap_review : Array[@bookkeeper.BookkeeperUiItem] = []
  let capability_proposal : Array[@bookkeeper.BookkeeperUiItem] = []
  let capability_review : Array[@bookkeeper.BookkeeperUiItem] = []
  let mooncode_work_order : Array[@bookkeeper.BookkeeperUiItem] = []
  let evaluation : Array[@bookkeeper.BookkeeperUiItem] = []
  let adoption : Array[@bookkeeper.BookkeeperUiItem] = []
  for record in snapshot.records {
    let item = record_ui_item(snapshot, record)
    match record.stage {
      DeliverableAcceptance => deliverable_acceptance.push(item)
      OutcomeBinding => outcome_binding.push(item)
      ThreeGapFinding => three_gap_findings.push(item)
      CapabilityProposal => capability_proposal.push(item)
      MoonCodeWorkOrder => mooncode_work_order.push(item)
      Evaluation => evaluation.push(item)
      Adoption => adoption.push(item)
      ThreeGapReview | CapabilityReview | MoonCodeResult => ()
    }
  }
  for review in snapshot.reviews {
    match review.stage {
      ThreeGapFinding =>
        three_gap_review.push(
          review_ui_item(
            review,
            "three_gap_review",
            "Three-Gap finding review",
            if review.disposition == @bookkeeper.Accept {
              "aggregate capability proposal"
            } else {
              "resolve review"
            },
          ),
        )
      CapabilityProposal =>
        capability_review.push(
          review_ui_item(
            review,
            "capability_review",
            "Capability proposal review",
            if review.disposition == @bookkeeper.Accept {
              "project MoonCode work order"
            } else {
              "resolve review"
            },
          ),
        )
      _ => ()
    }
  }
  {
    contract_version: @bookkeeper.bookkeeper_contract_version(),
    projection_version: "moonbook.bookkeeper.ui.v1",
    source_path: bookkeeper_ui_state_path(root),
    loaded: true,
    deliverable_acceptance,
    outcome_binding,
    three_gap_findings,
    three_gap_review,
    capability_proposal,
    capability_review,
    mooncode_work_order,
    evaluation,
    adoption,
  }
}

///|
async fn rebuild_bookkeeper_projection_unlocked(
  root : String,
) -> BookkeeperStoreSnapshot {
  let snapshot = replay_bookkeeper_store(root)
  write_atomic_json(bookkeeper_snapshot_path(root), snapshot.to_json())
  write_atomic_json(
    bookkeeper_ui_state_path(root),
    project_bookkeeper_ui_state(root, snapshot).to_json(),
  )
  snapshot
}

///|
pub async fn rebuild_bookkeeper_projection(
  root : String,
) -> BookkeeperStoreSnapshot {
  let lock = acquire_store_lock(root)
  defer release_store_lock(lock)
  rebuild_bookkeeper_projection_unlocked(root)
}
