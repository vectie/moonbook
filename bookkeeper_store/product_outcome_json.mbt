///|
pub impl ToJson for ProductOutcomeSubmission with fn to_json(self) {
  outcome_omit_absent_capability(
    {
      "contract_version": self.contract_version,
      "submission": self.submission.to_json(),
      "source_product": self.source_product,
      "deliverable_title": self.deliverable_title,
      "deliverable_summary": self.deliverable_summary,
      "outcome_summary": self.outcome_summary,
      "owner_route": self.owner_route,
      "evidence_refs": self.evidence_refs.to_json(),
      "decision_evidence_id": self.decision_evidence_id,
      "observed_at": self.observed_at,
      "recorded_at": self.recorded_at,
      "information_gap": self.information_gap.to_json(),
      "recognition_gap": self.recognition_gap.to_json(),
      "decisiveness_gap": self.decisiveness_gap.to_json(),
      "capability_id": outcome_capability_json(self.capability_id),
      "capability_version": outcome_capability_json(self.capability_version),
      "capability_change_digest": outcome_capability_json(
        self.capability_change_digest,
      ),
      "capability_summary": outcome_capability_json(self.capability_summary),
    },
    self.capability_id,
    self.capability_version,
    self.capability_change_digest,
    self.capability_summary,
  )
}

///|
pub impl @json.FromJson for ProductOutcomeSubmission with fn from_json(
  json,
  path,
) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError(
      (path, "Expected product outcome submission object"),
    )
  }
  let submission : ProductOutcomeSubmission = {
    contract_version: outcome_json_required(fields, "contract_version", path),
    submission: outcome_json_required(fields, "submission", path),
    source_product: outcome_json_required(fields, "source_product", path),
    deliverable_title: outcome_json_required(fields, "deliverable_title", path),
    deliverable_summary: outcome_json_required(
      fields, "deliverable_summary", path,
    ),
    outcome_summary: outcome_json_required(fields, "outcome_summary", path),
    owner_route: outcome_json_required(fields, "owner_route", path),
    evidence_refs: outcome_json_required(fields, "evidence_refs", path),
    decision_evidence_id: outcome_json_required(
      fields, "decision_evidence_id", path,
    ),
    observed_at: outcome_json_required(fields, "observed_at", path),
    recorded_at: outcome_json_required(fields, "recorded_at", path),
    information_gap: outcome_json_required(fields, "information_gap", path),
    recognition_gap: outcome_json_required(fields, "recognition_gap", path),
    decisiveness_gap: outcome_json_required(fields, "decisiveness_gap", path),
    capability_id: outcome_json_capability(fields, "capability_id", path),
    capability_version: outcome_json_capability(
      fields, "capability_version", path,
    ),
    capability_change_digest: outcome_json_capability(
      fields, "capability_change_digest", path,
    ),
    capability_summary: outcome_json_capability(
      fields, "capability_summary", path,
    ),
  }
  validate_outcome_capability(
    submission.capability_id,
    submission.capability_version,
    submission.capability_change_digest,
    submission.capability_summary,
    submission.information_gap,
    submission.recognition_gap,
    submission.decisiveness_gap,
  ) catch {
    error => raise @json.JsonDecodeError((path, error.to_string()))
  }
  submission
}

///|
pub impl ToJson for ProductOutcomeClosureRequest with fn to_json(self) {
  outcome_omit_absent_capability(
    {
      "contract_version": self.contract_version,
      "request": self.request.to_json(),
      "source_product": self.source_product,
      "deliverable": self.deliverable.to_json(),
      "result": self.result.to_json(),
      "deliverable_review": self.deliverable_review.to_json(),
      "observed_at": self.observed_at,
      "recorded_at": self.recorded_at,
      "outcome_summary": self.outcome_summary,
      "owner_route": self.owner_route,
      "evidence_refs": self.evidence_refs.to_json(),
      "information_gap": self.information_gap.to_json(),
      "recognition_gap": self.recognition_gap.to_json(),
      "decisiveness_gap": self.decisiveness_gap.to_json(),
      "capability_id": outcome_capability_json(self.capability_id),
      "capability_version": outcome_capability_json(self.capability_version),
      "capability_change_digest": outcome_capability_json(
        self.capability_change_digest,
      ),
      "capability_summary": outcome_capability_json(self.capability_summary),
    },
    self.capability_id,
    self.capability_version,
    self.capability_change_digest,
    self.capability_summary,
  )
}

///|
pub impl @json.FromJson for ProductOutcomeClosureRequest with fn from_json(
  json,
  path,
) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError(
      (path, "Expected product outcome closure object"),
    )
  }
  let request : ProductOutcomeClosureRequest = {
    contract_version: outcome_json_required(fields, "contract_version", path),
    request: outcome_json_required(fields, "request", path),
    source_product: outcome_json_required(fields, "source_product", path),
    deliverable: outcome_json_required(fields, "deliverable", path),
    result: outcome_json_required(fields, "result", path),
    deliverable_review: outcome_json_required(
      fields, "deliverable_review", path,
    ),
    observed_at: outcome_json_required(fields, "observed_at", path),
    recorded_at: outcome_json_required(fields, "recorded_at", path),
    outcome_summary: outcome_json_required(fields, "outcome_summary", path),
    owner_route: outcome_json_required(fields, "owner_route", path),
    evidence_refs: outcome_json_required(fields, "evidence_refs", path),
    information_gap: outcome_json_required(fields, "information_gap", path),
    recognition_gap: outcome_json_required(fields, "recognition_gap", path),
    decisiveness_gap: outcome_json_required(fields, "decisiveness_gap", path),
    capability_id: outcome_json_capability(fields, "capability_id", path),
    capability_version: outcome_json_capability(
      fields, "capability_version", path,
    ),
    capability_change_digest: outcome_json_capability(
      fields, "capability_change_digest", path,
    ),
    capability_summary: outcome_json_capability(
      fields, "capability_summary", path,
    ),
  }
  validate_outcome_capability(
    request.capability_id,
    request.capability_version,
    request.capability_change_digest,
    request.capability_summary,
    request.information_gap,
    request.recognition_gap,
    request.decisiveness_gap,
  ) catch {
    error => raise @json.JsonDecodeError((path, error.to_string()))
  }
  request
}
