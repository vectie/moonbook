///|
pub(all) struct PlanDeclarationChange {
  declaration_id : String
  owner_product_id : String
  previous_acceptance_criteria : Array[String]
  proposed_acceptance_criteria : Array[String]
  reason : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PlanRevisionRequest {
  request_id : String
  book_id : String
  parent_revision : String
  proposed_revision : String
  invalid_assumption : String
  reason : String
  evidence_refs : Array[String]
  changed_declarations : Array[PlanDeclarationChange]
  unchanged_declarations : Array[String]
  recorded_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PlanRevisionProposal {
  contract_id : String
  proposal_id : String
  book_id : String
  parent_revision : String
  proposed_revision : String
  invalid_assumption : String
  reason : String
  evidence_refs : Array[String]
  changed_declarations : Array[PlanDeclarationChange]
  unchanged_declarations : Array[String]
  source_digest : String
  recorded_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PlanRevisionLineage {
  contract_id : String
  book_id : String
  parent_revision : String
  revision : String
  proposal_id : String
  proposal_ref : String
  changed_declaration_ids : Array[String]
  unchanged_declaration_ids : Array[String]
  evidence_refs : Array[String]
  source_digest : String
  recorded_at : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PlanRevisionRecord {
  proposal_path : String
  lineage_path : String
  proposal_ref : String
  proposal : PlanRevisionProposal
  lineage : PlanRevisionLineage
} derive(Debug, Eq, ToJson)

///|
fn revision_artifact_ref_is_safe(value : String) -> Bool {
  let normalized = value.trim().replace(old="\\", new="/")
  !normalized.is_empty() &&
  !normalized.has_prefix("/") &&
  !normalized.split("/").any(segment => segment == ".." || segment == "")
}

///|
pub fn PlanRevisionRequest::quality_issues(
  self : PlanRevisionRequest,
) -> Array[String] {
  let issues : Array[String] = []
  for
    pair in [
      ("request_id", self.request_id),
      ("book_id", self.book_id),
      ("parent_revision", self.parent_revision),
      ("proposed_revision", self.proposed_revision),
      ("invalid_assumption", self.invalid_assumption),
      ("reason", self.reason),
      ("recorded_at", self.recorded_at),
    ] {
    let (field, value) = pair
    if value.trim().is_empty() {
      issues.push("\{field} is required")
    }
  }
  if self.parent_revision == self.proposed_revision {
    issues.push("a revision must not rewrite its parent")
  }
  if self.evidence_refs.is_empty() {
    issues.push("revision evidence is required")
  }
  for evidence in self.evidence_refs {
    if !revision_artifact_ref_is_safe(evidence) {
      issues.push("revision evidence reference is invalid: \{evidence}")
    }
  }
  if self.changed_declarations.is_empty() {
    issues.push("at least one declaration must change")
  }
  let changed_ids : Array[String] = []
  for change in self.changed_declarations {
    if change.declaration_id.trim().is_empty() ||
      change.owner_product_id.trim().is_empty() ||
      change.reason.trim().is_empty() {
      issues.push(
        "changed declaration identity, owner, and reason are required",
      )
    }
    if change.previous_acceptance_criteria.is_empty() ||
      change.proposed_acceptance_criteria.is_empty() {
      issues.push(
        "changed declaration requires previous and proposed criteria: \{change.declaration_id}",
      )
    }
    if change.previous_acceptance_criteria ==
      change.proposed_acceptance_criteria {
      issues.push("changed criteria are identical: \{change.declaration_id}")
    }
    if changed_ids.contains(change.declaration_id) {
      issues.push("duplicate changed declaration: \{change.declaration_id}")
    } else {
      changed_ids.push(change.declaration_id)
    }
  }
  for unchanged in self.unchanged_declarations {
    if changed_ids.contains(unchanged) {
      issues.push(
        "declaration cannot be both changed and unchanged: \{unchanged}",
      )
    }
  }
  issues
}

///|
pub fn compile_plan_revision(
  request : PlanRevisionRequest,
) -> (PlanRevisionProposal, PlanRevisionLineage) raise {
  let issues = request.quality_issues()
  if !issues.is_empty() {
    fail("invalid plan revision request: \{issues.join("; ")}")
  }
  let source_digest = executable_sha256(request.to_json().stringify(indent=2))
  let proposal = PlanRevisionProposal::{
    contract_id: "moonbook.plan-revision-proposal.v1",
    proposal_id: "proposal-\{request.request_id}",
    book_id: request.book_id,
    parent_revision: request.parent_revision,
    proposed_revision: request.proposed_revision,
    invalid_assumption: request.invalid_assumption,
    reason: request.reason,
    evidence_refs: request.evidence_refs.copy(),
    changed_declarations: request.changed_declarations.copy(),
    unchanged_declarations: request.unchanged_declarations.copy(),
    source_digest,
    recorded_at: request.recorded_at,
  }
  let lineage = PlanRevisionLineage::{
    contract_id: "moonbook.plan-revision-lineage.v1",
    book_id: request.book_id,
    parent_revision: request.parent_revision,
    revision: request.proposed_revision,
    proposal_id: proposal.proposal_id,
    proposal_ref: "flow/revisions/\{request.proposed_revision}/proposal.json",
    changed_declaration_ids: request.changed_declarations.map(change => {
      change.declaration_id
    }),
    unchanged_declaration_ids: request.unchanged_declarations.copy(),
    evidence_refs: request.evidence_refs.copy(),
    source_digest,
    recorded_at: request.recorded_at,
  }
  (proposal, lineage)
}

///|
pub async fn write_plan_revision(
  root : String,
  request_path : String,
) -> PlanRevisionRecord {
  let normalized_root = @pathx.normalize(root)
  let request : PlanRevisionRequest = @json.from_json(
    @json.parse(@fsx.read_file(request_path)),
  )
  ignore(safe_observation_id(request.request_id))
  ignore(safe_observation_id(request.parent_revision))
  ignore(safe_observation_id(request.proposed_revision))
  let (proposal, lineage) = compile_plan_revision(request)
  for evidence in proposal.evidence_refs {
    if !@fsx.exists(@pathx.join(normalized_root, evidence)) {
      fail("plan revision evidence does not exist: \{evidence}")
    }
  }
  let revision_dir = moonbook_wiki_path(normalized_root)
    .join(moonbook_wiki_path("flow/revisions/\{proposal.proposed_revision}"))
    .to_string()
  @fsx.make_directory(revision_dir, recursive=true, exists_ok=true)
  let proposal_path = @pathx.join(revision_dir, "proposal.json")
  let lineage_path = @pathx.join(revision_dir, "lineage.json")
  let proposal_json = proposal.to_json().stringify(indent=2) + "\n"
  let lineage_json = lineage.to_json().stringify(indent=2) + "\n"
  if @fsx.exists(proposal_path) {
    if @fsx.read_file(proposal_path) != proposal_json {
      fail(
        "plan revision identity already exists with different proposal content",
      )
    }
  }
  if @fsx.exists(lineage_path) {
    if @fsx.read_file(lineage_path) != lineage_json {
      fail(
        "plan revision identity already exists with different lineage content",
      )
    }
  }
  if !@fsx.exists(proposal_path) {
    @fsx.write_to_file(proposal_path, proposal_json, create=0o644)
  }
  if !@fsx.exists(lineage_path) {
    @fsx.write_to_file(lineage_path, lineage_json, create=0o644)
  }
  {
    proposal_path,
    lineage_path,
    proposal_ref: lineage.proposal_ref,
    proposal,
    lineage,
  }
}
