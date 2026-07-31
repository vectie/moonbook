///|
/// Stable wire contract for audience-oriented views derived from one
/// canonical MoonBook revision.
pub fn reader_projection_contract_version() -> String {
  "moonbook.reader_projection.v1"
}

///|
/// Human reading modes. Maintenance and provenance are deliberately not a
/// reader mode; they remain a separate operator surface.
pub(all) enum ReaderView {
  Learn
  Apply
  Research
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ReaderView::key(self : ReaderView) -> String {
  match self {
    Learn => "learn"
    Apply => "apply"
    Research => "research"
  }
}

///|
pub fn ReaderView::label(self : ReaderView) -> String {
  match self {
    Learn => "Learn"
    Apply => "Apply"
    Research => "Research"
  }
}

///|
pub fn reader_view_from_key(value : String) -> ReaderView? {
  match value.trim().to_lower() {
    "learn" => Some(Learn)
    "apply" => Some(Apply)
    "research" => Some(Research)
    _ => None
  }
}

///|
/// Review state for both canonical source material and derived projections.
pub(all) enum ReaderReviewStatus {
  Draft
  PendingReview
  Accepted
  Rejected
  Superseded
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ReaderReviewStatus::key(self : ReaderReviewStatus) -> String {
  match self {
    Draft => "draft"
    PendingReview => "pending-review"
    Accepted => "accepted"
    Rejected => "rejected"
    Superseded => "superseded"
  }
}

///|
pub fn reader_review_status_from_key(value : String) -> ReaderReviewStatus? {
  match value.trim().to_lower() {
    "draft" => Some(Draft)
    "pending-review" | "pending_review" | "pending" => Some(PendingReview)
    "accepted" => Some(Accepted)
    "rejected" => Some(Rejected)
    "superseded" => Some(Superseded)
    _ => None
  }
}

///|
/// Exact subject category for a review decision. Keeping the categories typed
/// prevents a valid receipt for an unrelated artifact from being reused.
pub(all) enum ReaderReviewSubjectKind {
  CanonicalBook
  ReaderProjectionArtifact
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Explicit decision vocabulary. Display status is derived from this value so
/// an accepted status cannot disagree with a rejected disposition.
pub(all) enum ReaderReviewDisposition {
  Pending
  Accept
  Reject
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) enum ReaderReviewerKind {
  Human
  Agent
  Automation
  System
} derive(Debug, Eq, ToJson, FromJson)

///|
pub struct ReaderReviewSubjectRef {
  kind : ReaderReviewSubjectKind
  subject_id : String
  version : String
  digest : String
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderReviewSubjectRef::new(
  kind~ : ReaderReviewSubjectKind,
  subject_id~ : String,
  version~ : String,
  digest~ : String,
) -> ReaderReviewSubjectRef {
  { kind, subject_id, version, digest }
}

///|
pub struct ReaderReviewReceiptRef {
  receipt_id : String
  version : String
  digest : String
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderReviewReceiptRef::new(
  receipt_id~ : String,
  version~ : String,
  digest~ : String,
) -> ReaderReviewReceiptRef {
  { receipt_id, version, digest }
}

///|
pub struct ReaderReviewerIdentity {
  reviewer_id : String
  kind : ReaderReviewerKind
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderReviewerIdentity::new(
  reviewer_id~ : String,
  kind~ : ReaderReviewerKind,
) -> ReaderReviewerIdentity {
  { reviewer_id, kind }
}

///|
pub struct ReaderAuthorityAttestationRef {
  attestation_id : String
  version : String
  digest : String
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderAuthorityAttestationRef::new(
  attestation_id~ : String,
  version~ : String,
  digest~ : String,
) -> ReaderAuthorityAttestationRef {
  { attestation_id, version, digest }
}

///|
pub struct ReaderReviewEvidenceRef {
  reference_id : String
  version : String
  digest : String
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderReviewEvidenceRef::new(
  reference_id~ : String,
  version~ : String,
  digest~ : String,
) -> ReaderReviewEvidenceRef {
  { reference_id, version, digest }
}

///|
/// Exact, non-applying review decision. It mirrors Bookkeeper's reference
/// semantics without importing Bookkeeper or an agent runtime.
pub struct ReaderReviewBinding {
  subject : ReaderReviewSubjectRef
  receipt : ReaderReviewReceiptRef
  disposition : ReaderReviewDisposition
  reviewer : ReaderReviewerIdentity
  authority : ReaderAuthorityAttestationRef
  evidence_refs : ReadOnlyArray[ReaderReviewEvidenceRef]
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderReviewBinding::new(
  subject~ : ReaderReviewSubjectRef,
  receipt~ : ReaderReviewReceiptRef,
  disposition~ : ReaderReviewDisposition,
  reviewer~ : ReaderReviewerIdentity,
  authority~ : ReaderAuthorityAttestationRef,
  evidence_refs~ : ArrayView[ReaderReviewEvidenceRef],
) -> ReaderReviewBinding {
  {
    subject,
    receipt,
    disposition,
    reviewer,
    authority,
    evidence_refs: ReadOnlyArray::from_array(evidence_refs),
  }
}

///|
pub fn ReaderReviewBinding::review_status(
  self : ReaderReviewBinding,
) -> ReaderReviewStatus {
  match self.disposition {
    Pending => PendingReview
    Accept => Accepted
    Reject => Rejected
  }
}

///|
/// Immutable locator for evidence used by the canonical book revision.
pub struct ReaderSourceRef {
  reference_id : String
  title : String
  locator : String
  revision : String
  digest : String
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderSourceRef::new(
  reference_id~ : String,
  title~ : String,
  locator~ : String,
  revision~ : String,
  digest~ : String,
) -> ReaderSourceRef {
  { reference_id, title, locator, revision, digest }
}

///|
/// One readable unit whose claims remain anchored to canonical source refs.
pub struct ReaderSection {
  section_id : String
  title : String
  plain_summary : String
  body_markdown : String
  source_ref_ids : ReadOnlyArray[String]
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderSection::new(
  section_id~ : String,
  title~ : String,
  plain_summary~ : String,
  body_markdown~ : String,
  source_ref_ids~ : ArrayView[String],
) -> ReaderSection {
  {
    section_id,
    title,
    plain_summary,
    body_markdown,
    source_ref_ids: ReadOnlyArray::from_array(source_ref_ids),
  }
}

///|
pub struct ReaderGlossaryEntry {
  term : String
  plain_definition : String
  source_ref_ids : ReadOnlyArray[String]
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderGlossaryEntry::new(
  term~ : String,
  plain_definition~ : String,
  source_ref_ids~ : ArrayView[String],
) -> ReaderGlossaryEntry {
  {
    term,
    plain_definition,
    source_ref_ids: ReadOnlyArray::from_array(source_ref_ids),
  }
}

///|
/// A concrete scenario is kept distinct from expository sections so quality
/// checks can detect abstract-only projections.
pub struct ReaderWorkedExample {
  title : String
  situation : String
  steps : ReadOnlyArray[String]
  takeaway : String
  source_ref_ids : ReadOnlyArray[String]
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderWorkedExample::new(
  title~ : String,
  situation~ : String,
  steps~ : ArrayView[String],
  takeaway~ : String,
  source_ref_ids~ : ArrayView[String],
) -> ReaderWorkedExample {
  {
    title,
    situation,
    steps: ReadOnlyArray::from_array(steps),
    takeaway,
    source_ref_ids: ReadOnlyArray::from_array(source_ref_ids),
  }
}

///|
/// Practice and retrieval are explicit deliverables, not prose suggestions.
pub struct ReaderExercise {
  prompt : String
  expected_artifact : String
  checkpoint_question : String
  checkpoint_answer : String
  self_explanation_prompt : String
  transfer_task : String
  revisit_prompt : String
  revisit_after_days : Int
  source_ref_ids : ReadOnlyArray[String]
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderExercise::new(
  prompt~ : String,
  expected_artifact~ : String,
  checkpoint_question~ : String,
  checkpoint_answer~ : String,
  self_explanation_prompt~ : String,
  transfer_task~ : String,
  revisit_prompt~ : String,
  revisit_after_days~ : Int,
  source_ref_ids~ : ArrayView[String],
) -> ReaderExercise {
  {
    prompt,
    expected_artifact,
    checkpoint_question,
    checkpoint_answer,
    self_explanation_prompt,
    transfer_task,
    revisit_prompt,
    revisit_after_days,
    source_ref_ids: ReadOnlyArray::from_array(source_ref_ids),
  }
}

///|
/// Apply-mode semantics remain explicit so a procedural view cannot degrade
/// into a renamed introductory course.
pub struct ReaderApplyFrame {
  procedure_steps : ReadOnlyArray[String]
  decision_points : ReadOnlyArray[String]
  tradeoffs : ReadOnlyArray[String]
  template_artifact : String
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderApplyFrame::new(
  procedure_steps~ : ArrayView[String],
  decision_points~ : ArrayView[String],
  tradeoffs~ : ArrayView[String],
  template_artifact~ : String,
) -> ReaderApplyFrame {
  {
    procedure_steps: ReadOnlyArray::from_array(procedure_steps),
    decision_points: ReadOnlyArray::from_array(decision_points),
    tradeoffs: ReadOnlyArray::from_array(tradeoffs),
    template_artifact,
  }
}

///|
/// Research-mode semantics expose how claims were produced and challenged,
/// including uncertainty and review lineage rather than only conclusions.
pub struct ReaderResearchFrame {
  research_method : String
  contradictions : ReadOnlyArray[String]
  uncertainties : ReadOnlyArray[String]
  limitations : ReadOnlyArray[String]
  review_lineage : ReadOnlyArray[String]
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderResearchFrame::new(
  research_method~ : String,
  contradictions~ : ArrayView[String],
  uncertainties~ : ArrayView[String],
  limitations~ : ArrayView[String],
  review_lineage~ : ArrayView[String],
) -> ReaderResearchFrame {
  {
    research_method,
    contradictions: ReadOnlyArray::from_array(contradictions),
    uncertainties: ReadOnlyArray::from_array(uncertainties),
    limitations: ReadOnlyArray::from_array(limitations),
    review_lineage: ReadOnlyArray::from_array(review_lineage),
  }
}

///|
pub struct ReaderViewLink {
  view : ReaderView
  href : String
  review_status : ReaderReviewStatus
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderViewLink::new(
  view~ : ReaderView,
  href~ : String,
  review_status~ : ReaderReviewStatus,
) -> ReaderViewLink {
  { view, href, review_status }
}

///|
/// Reader-mode navigation and maintenance navigation are structurally
/// separated so implementation metadata cannot masquerade as a learning mode.
pub struct ReaderNavigation {
  canonical_href : String
  maintenance_href : String
  view_links : ReadOnlyArray[ReaderViewLink]
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderNavigation::new(
  canonical_href~ : String,
  maintenance_href~ : String,
  view_links~ : ArrayView[ReaderViewLink],
) -> ReaderNavigation {
  {
    canonical_href,
    maintenance_href,
    view_links: ReadOnlyArray::from_array(view_links),
  }
}

///|
/// A human-readable projection. It never owns truth: `source_revision`,
/// `source_digest`, `source_review`, and `source_refs` bind it to the exact
/// canonical MoonBook material it explains.
pub struct ReaderProjection {
  contract_version : String
  projection_id : String
  projection_revision : String
  projection_digest : String
  book_id : String
  canonical_source_subject_id : String
  view : ReaderView
  language : String
  title : String
  estimated_minutes : Int
  audience : String
  outcome : String
  main_message : String
  next_action : String
  route_intro : String
  prerequisite_note : String
  prerequisites : ReadOnlyArray[String]
  learning_path : ReadOnlyArray[String]
  sections : ReadOnlyArray[ReaderSection]
  glossary : ReadOnlyArray[ReaderGlossaryEntry]
  worked_examples : ReadOnlyArray[ReaderWorkedExample]
  exercises : ReadOnlyArray[ReaderExercise]
  apply_frame : ReaderApplyFrame?
  research_frame : ReaderResearchFrame?
  navigation : ReaderNavigation
  source_revision : String
  source_digest : String
  source_review : ReaderReviewBinding
  source_refs : ReadOnlyArray[ReaderSourceRef]
  projection_review : ReaderReviewBinding
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderProjection::new(
  projection_id~ : String,
  projection_revision~ : String,
  projection_digest~ : String,
  book_id~ : String,
  canonical_source_subject_id~ : String,
  view~ : ReaderView,
  language~ : String,
  title~ : String,
  estimated_minutes~ : Int,
  audience~ : String,
  outcome~ : String,
  main_message~ : String,
  next_action~ : String,
  route_intro~ : String,
  prerequisite_note~ : String,
  prerequisites~ : ArrayView[String],
  learning_path~ : ArrayView[String],
  sections~ : ArrayView[ReaderSection],
  glossary~ : ArrayView[ReaderGlossaryEntry],
  worked_examples~ : ArrayView[ReaderWorkedExample],
  exercises~ : ArrayView[ReaderExercise],
  apply_frame~ : ReaderApplyFrame?,
  research_frame~ : ReaderResearchFrame?,
  navigation~ : ReaderNavigation,
  source_revision~ : String,
  source_digest~ : String,
  source_review~ : ReaderReviewBinding,
  source_refs~ : ArrayView[ReaderSourceRef],
  projection_review~ : ReaderReviewBinding,
) -> ReaderProjection {
  {
    contract_version: reader_projection_contract_version(),
    projection_id,
    projection_revision,
    projection_digest,
    book_id,
    canonical_source_subject_id,
    view,
    language,
    title,
    estimated_minutes,
    audience,
    outcome,
    main_message,
    next_action,
    route_intro,
    prerequisite_note,
    prerequisites: ReadOnlyArray::from_array(prerequisites),
    learning_path: ReadOnlyArray::from_array(learning_path),
    sections: ReadOnlyArray::from_array(sections),
    glossary: ReadOnlyArray::from_array(glossary),
    worked_examples: ReadOnlyArray::from_array(worked_examples),
    exercises: ReadOnlyArray::from_array(exercises),
    apply_frame,
    research_frame,
    navigation,
    source_revision,
    source_digest,
    source_review,
    source_refs: ReadOnlyArray::from_array(source_refs),
    projection_review,
  }
}
