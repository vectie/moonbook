///|
/// Stable, domain-neutral view model for the MoonBook-owned Bookkeeper UI.
/// It contains presentation facts only and never grants review or mutation
/// authority.
pub(all) struct BookkeeperUiItem {
  stage : String
  title : String
  record_id : String
  record_version : String
  status : String
  tone : String
  summary : String
  owner_route : String
  evidence_count : Int
  issue_count : Int
  requires_human_review : Bool
  next_action : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// One complete Bookkeeper closed-loop snapshot. Arrays allow the projection
/// producer to expose queues without introducing pack- or domain-specific
/// fields into MoonBook.
pub(all) struct BookkeeperUiState {
  contract_version : String
  projection_version : String
  source_path : String
  loaded : Bool
  deliverable_acceptance : Array[BookkeeperUiItem]
  outcome_binding : Array[BookkeeperUiItem]
  three_gap_findings : Array[BookkeeperUiItem]
  three_gap_review : Array[BookkeeperUiItem]
  capability_proposal : Array[BookkeeperUiItem]
  capability_review : Array[BookkeeperUiItem]
  mooncode_work_order : Array[BookkeeperUiItem]
  evaluation : Array[BookkeeperUiItem]
  adoption : Array[BookkeeperUiItem]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn empty_bookkeeper_ui_state(source_path : String) -> BookkeeperUiState {
  {
    contract_version: bookkeeper_contract_version(),
    projection_version: "moonbook.bookkeeper.ui.v1",
    source_path,
    loaded: false,
    deliverable_acceptance: [],
    outcome_binding: [],
    three_gap_findings: [],
    three_gap_review: [],
    capability_proposal: [],
    capability_review: [],
    mooncode_work_order: [],
    evaluation: [],
    adoption: [],
  }
}

///|
pub fn BookkeeperUiState::item_count(self : BookkeeperUiState) -> Int {
  self.deliverable_acceptance.length() +
  self.outcome_binding.length() +
  self.three_gap_findings.length() +
  self.three_gap_review.length() +
  self.capability_proposal.length() +
  self.capability_review.length() +
  self.mooncode_work_order.length() +
  self.evaluation.length() +
  self.adoption.length()
}

///|
pub fn BookkeeperUiState::pending_human_review_count(
  self : BookkeeperUiState,
) -> Int {
  let mut count = 0
  for
    lane in [
      self.deliverable_acceptance,
      self.outcome_binding,
      self.three_gap_findings,
      self.three_gap_review,
      self.capability_proposal,
      self.capability_review,
      self.mooncode_work_order,
      self.evaluation,
      self.adoption,
    ] {
    for item in lane {
      if item.requires_human_review {
        count = count + 1
      }
    }
  }
  count
}

///|
fn disposition_ui_status(disposition : BookkeeperDisposition) -> String {
  match disposition {
    Accept => "accepted"
    Reject => "rejected"
    Revise => "revision required"
    Escalate => "escalated"
  }
}

///|
fn disposition_ui_tone(disposition : BookkeeperDisposition) -> String {
  match disposition {
    Accept => "healthy"
    Reject | Revise => "alert"
    Escalate => "review"
  }
}

///|
/// Project a finalization decision without exposing a pack-specific payload.
pub fn project_deliverable_acceptance_ui(
  decision : BookkeeperDecision,
) -> BookkeeperUiItem {
  {
    stage: "deliverable_acceptance",
    title: "Deliverable acceptance",
    record_id: decision.decision_id,
    record_version: decision.candidate_version,
    status: disposition_ui_status(decision.disposition),
    tone: disposition_ui_tone(decision.disposition),
    summary: if decision.is_deliverable() {
      "All declared acceptance bindings passed; the immutable bundle is available."
    } else {
      "The candidate remains non-deliverable until the recorded issues are resolved."
    },
    owner_route: decision.reviewer_id,
    evidence_count: match decision.bundle {
      Some(bundle) => bundle.evidence_refs.length()
      None => 0
    },
    issue_count: decision.issues.length(),
    requires_human_review: decision.disposition != Accept,
    next_action: if decision.is_deliverable() {
      "bind outcome"
    } else {
      "review decision"
    },
  }
}

///|
pub fn project_outcome_binding_ui(
  decision : OutcomeEvidenceBindingDecision,
) -> BookkeeperUiItem {
  let bound = decision.is_bound()
  {
    stage: "outcome_binding",
    title: "Outcome binding",
    record_id: match decision.binding {
      Some(binding) => binding.binding.record_id
      None => "unbound"
    },
    record_version: match decision.binding {
      Some(binding) => binding.binding.record_version
      None => ""
    },
    status: if bound {
      "bound"
    } else {
      "blocked"
    },
    tone: if bound {
      "healthy"
    } else {
      "alert"
    },
    summary: if bound {
      "Outcome evidence is linked to one exact accepted bundle and candidate version."
    } else {
      "Outcome evidence failed exact-link or completeness validation."
    },
    owner_route: "moonbook.bookkeeper",
    evidence_count: match decision.binding {
      Some(binding) => binding.records.length()
      None => 0
    },
    issue_count: decision.issues.length(),
    requires_human_review: !bound,
    next_action: if bound {
      "assess gaps"
    } else {
      "repair evidence binding"
    },
  }
}

///|
pub fn project_three_gap_finding_ui(
  finding : CanonicalGapFinding,
) -> BookkeeperUiItem {
  {
    stage: "three_gap_finding",
    title: match finding.gap_class {
      InformationGap => "Information gap"
      RecognitionGap => "Recognition gap"
      DecisivenessGap => "Decisiveness gap"
    },
    record_id: finding.finding.record_id,
    record_version: finding.finding.record_version,
    status: "awaiting human review",
    tone: "review",
    summary: finding.summary,
    owner_route: finding.owner_route,
    evidence_count: finding.evidence_refs.length(),
    issue_count: 0,
    requires_human_review: true,
    next_action: "review finding",
  }
}

///|
pub fn project_three_gap_review_ui(
  decision : GapFindingReviewDecision,
) -> BookkeeperUiItem {
  let reviewed = decision.is_reviewed()
  {
    stage: "three_gap_review",
    title: "Three-Gap finding review",
    record_id: decision.receipt.receipt.record_id,
    record_version: decision.receipt.receipt.record_version,
    status: if reviewed {
      "reviewed"
    } else {
      "review blocked"
    },
    tone: if reviewed {
      "healthy"
    } else {
      "alert"
    },
    summary: if reviewed {
      "A named human accepted the exact finding and evidence without applying changes."
    } else {
      "The finding is not eligible for slow-loop aggregation."
    },
    owner_route: decision.receipt.owner_route,
    evidence_count: decision.receipt.evidence_refs.length(),
    issue_count: decision.issues.length(),
    requires_human_review: !reviewed,
    next_action: if reviewed {
      "aggregate proposal"
    } else {
      "resolve review issues"
    },
  }
}

///|
pub fn project_capability_proposal_ui(
  decision : CapabilityAggregationDecision,
) -> BookkeeperUiItem {
  let promoted = decision.is_promoted()
  {
    stage: "capability_proposal",
    title: "Capability proposal",
    record_id: match decision.proposal {
      Some(proposal) => proposal.proposal_id
      None => decision.policy.record_id
    },
    record_version: match decision.proposal {
      Some(proposal) => proposal.proposal_version
      None => decision.policy.record_version
    },
    status: if promoted {
      "policy promoted"
    } else {
      "threshold not met"
    },
    tone: if promoted {
      "review"
    } else {
      "info"
    },
    summary: match decision.proposal {
      Some(proposal) => proposal.summary
      None =>
        "Reviewed findings remain below the deterministic promotion policy."
    },
    owner_route: match decision.proposal {
      Some(proposal) => proposal.owner_route
      None => "moonbook.bookkeeper"
    },
    evidence_count: decision.source_finding_refs.length(),
    issue_count: decision.non_promotion_reasons.length(),
    requires_human_review: promoted,
    next_action: if promoted {
      "review proposal"
    } else {
      "collect reviewed findings"
    },
  }
}

///|
pub fn project_capability_review_ui(
  receipt : LearningReceipt,
) -> BookkeeperUiItem {
  let accepted = receipt.review_complete && receipt.disposition == Accept
  {
    stage: "capability_review",
    title: "Capability proposal review",
    record_id: receipt.receipt_id,
    record_version: receipt.receipt_version,
    status: disposition_ui_status(receipt.disposition),
    tone: if accepted {
      "healthy"
    } else {
      disposition_ui_tone(receipt.disposition)
    },
    summary: if accepted {
      "The proposal review is complete; no capability mutation was applied."
    } else {
      "The proposal cannot be projected to MoonCode until review is accepted."
    },
    owner_route: receipt.owner_route,
    evidence_count: receipt.evidence_refs.length(),
    issue_count: if receipt.review_complete {
      0
    } else {
      1
    },
    requires_human_review: !accepted,
    next_action: if accepted {
      "project MoonCode work order"
    } else {
      "complete review"
    },
  }
}

///|
pub fn project_mooncode_work_order_ui(
  decision : WorkOrderProjectionDecision,
) -> BookkeeperUiItem {
  let ready = decision.is_ready()
  {
    stage: "mooncode_work_order",
    title: "MoonCode work-order projection",
    record_id: match decision.work_order {
      Some(order) => order.work_order.record_id
      None => "not-projected"
    },
    record_version: match decision.work_order {
      Some(order) => order.work_order.record_version
      None => ""
    },
    status: if ready {
      "ready for MoonCode"
    } else {
      "projection denied"
    },
    tone: if ready {
      "healthy"
    } else {
      "alert"
    },
    summary: if ready {
      "A human-attested, non-executing work-order value is ready for MoonCode."
    } else {
      "The work order remains unavailable until exact review and evidence checks pass."
    },
    owner_route: match decision.work_order {
      Some(order) => order.owner_route
      None => "moonbook.bookkeeper"
    },
    evidence_count: match decision.work_order {
      Some(order) => order.evidence_refs.length()
      None => 0
    },
    issue_count: decision.issues.length(),
    requires_human_review: !ready,
    next_action: if ready {
      "send through MoonFlow"
    } else {
      "repair projection"
    },
  }
}

///|
pub fn project_capability_evaluation_ui(
  evaluation : CapabilityEvaluation,
) -> BookkeeperUiItem {
  let passing = evaluation.is_passing()
  {
    stage: "capability_evaluation",
    title: "Capability evaluation",
    record_id: evaluation.evaluation.record_id,
    record_version: evaluation.evaluation.record_version,
    status: if passing {
      "passed"
    } else {
      "not passing"
    },
    tone: if passing {
      "healthy"
    } else {
      "alert"
    },
    summary: if passing {
      "Tests, metrics, evidence, rollback, and exact links passed evaluation."
    } else {
      "The capability result cannot enter adoption review."
    },
    owner_route: "moonbook.bookkeeper",
    evidence_count: evaluation.evidence_refs.length(),
    issue_count: evaluation.issues.length(),
    requires_human_review: passing,
    next_action: if passing {
      "review adoption"
    } else {
      "repair and re-evaluate"
    },
  }
}

///|
pub fn project_capability_adoption_ui(
  decision : CapabilityAdoptionDecision,
) -> BookkeeperUiItem {
  let authorized = decision.is_authorized()
  {
    stage: "capability_adoption",
    title: "Capability adoption",
    record_id: decision.decision.record_id,
    record_version: decision.decision.record_version,
    status: if authorized {
      "authorized"
    } else {
      disposition_ui_status(decision.disposition)
    },
    tone: if authorized {
      "healthy"
    } else {
      disposition_ui_tone(decision.disposition)
    },
    summary: if authorized {
      "A reviewed capability-version receipt is available; no deployment side effect was applied."
    } else {
      "Capability adoption remains blocked or awaits an authorized human decision."
    },
    owner_route: "moonbook.bookkeeper",
    evidence_count: match decision.version_receipt {
      Some(receipt) => receipt.adoption_evidence_refs.length()
      None => 0
    },
    issue_count: decision.issues.length(),
    requires_human_review: !authorized,
    next_action: if authorized {
      "authorize external adoption"
    } else {
      "review adoption"
    },
  }
}

///|
test "empty Bookkeeper UI projection is explicit and JSON round-trippable" {
  let state = empty_bookkeeper_ui_state(
    "/workspace/.moonbook/bookkeeper/ui-state.json",
  )
  inspect(state.item_count(), content="0")
  inspect(state.pending_human_review_count(), content="0")
  let decoded : BookkeeperUiState = @json.from_json(state.to_json())
  inspect(decoded.loaded, content="false")
  inspect(decoded.contract_version, content="moonbook.bookkeeper.v1")
  inspect(decoded.projection_version, content="moonbook.bookkeeper.ui.v1")
}
