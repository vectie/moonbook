///|
/// Typed quality failures for MoonBook's nine-step human reading loop:
/// Orient, Explain, Show, Practice, Self-explain, Retrieve, Transfer, Prove,
/// and Revisit. Navigation and review remain explicit release gates.
pub(all) enum ReaderProjectionIssue {
  InvalidContract(String)
  MissingIdentity(String)
  InvalidEstimatedMinutes(Int)
  MissingAudience
  GenericAudience(String)
  MissingOutcome
  MissingMainMessage
  MainMessageSentenceCount(Int)
  MissingNextAction
  MissingRoute
  MissingPrerequisiteStatement
  MissingSection
  DuplicateSectionId(String)
  UnknownLearningPathSection(String)
  MissingGlossary
  MissingIllustration
  IncompleteIllustration(String)
  MissingExercise
  IncompletePractice(String)
  IncompleteCheckpoint(String)
  MissingSelfExplanation(String)
  MissingTransferTask(String)
  MissingRevisitPlan(String)
  MissingApplyFrame
  IncompleteApplyFrame(String)
  MissingResearchFrame
  IncompleteResearchFrame(String)
  UnexpectedViewFrame(String)
  MissingCanonicalLink
  MissingMaintenanceLink
  MissingCurrentViewLink(ReaderView)
  DuplicateViewLink(ReaderView)
  MissingSourceRevision
  MissingSourceDigest
  MissingProjectionDigest
  InvalidDigest(String)
  MissingSourceReference
  IncompleteSourceReference(String)
  DuplicateSourceReference(String)
  MissingCitation(String)
  UnknownSourceReference(String)
  ReviewSubjectIncomplete(String)
  ReviewSubjectMismatch(String)
  ReviewReceiptIncomplete(String)
  ReviewReceiptReused
  ReviewReviewerMissing(String)
  ReviewReviewerNotHuman(String, ReaderReviewerKind)
  ReviewAuthorityMissing(String)
  ReviewEvidenceMissing(String)
  ReviewEvidenceIncomplete(String)
  DuplicateReviewEvidence(String)
  SourceNotAccepted(ReaderReviewStatus)
  ProjectionNotAccepted(ReaderReviewStatus)
} derive(Debug, Eq, ToJson)

///|
/// Measurable structural quality for the nine reader-loop dimensions. The
/// score is a percentage and `quality_dimensions_ready` is a count out of
/// nine. These deterministic checks do not claim to measure comprehension;
/// user observation and review must supply that evidence.
/// `content_ready` does not imply publication authority; `publishable`
/// additionally requires an accepted projection review receipt.
pub struct ReaderProjectionReadiness {
  orient_ready : Bool
  explain_ready : Bool
  show_ready : Bool
  practice_ready : Bool
  self_explain_ready : Bool
  retrieve_ready : Bool
  transfer_ready : Bool
  prove_ready : Bool
  revisit_ready : Bool
  quality_dimensions_ready : Int
  reader_quality_score : Int
  navigation_ready : Bool
  structurally_valid : Bool
  content_ready : Bool
  review_ready : Bool
  publishable : Bool
  issues : ReadOnlyArray[ReaderProjectionIssue]
} derive(Debug, Eq, ToJson)

///|
pub fn ReaderProjection::validate(
  self : ReaderProjection,
) -> ReadOnlyArray[ReaderProjectionIssue] {
  self.readiness().issues
}

///|
pub fn ReaderProjection::readiness(
  self : ReaderProjection,
) -> ReaderProjectionReadiness {
  let structural = self.structural_issues()
  let orient = self.orient_issues()
  let explain = self.explain_issues()
  let show = self.show_issues()
  let practice = self.practice_issues()
  let self_explain = self.self_explain_issues()
  let retrieve = self.retrieve_issues()
  let transfer = self.transfer_issues()
  let prove = self.prove_issues()
  let revisit = self.revisit_issues()
  let navigation = self.navigation_issues()
  let review = self.projection_review_issues()
  let issues : Array[ReaderProjectionIssue] = []
  for
    group in [
      structural, orient, explain, show, practice, self_explain, retrieve, transfer,
      prove, revisit, navigation, review,
    ] {
    for issue in group {
      issues.push(issue)
    }
  }
  let orient_ready = orient.is_empty()
  let explain_ready = explain.is_empty()
  let show_ready = show.is_empty()
  let practice_ready = practice.is_empty()
  let self_explain_ready = self_explain.is_empty()
  let retrieve_ready = retrieve.is_empty()
  let transfer_ready = transfer.is_empty()
  let prove_ready = prove.is_empty()
  let revisit_ready = revisit.is_empty()
  let mut quality_dimensions_ready = 0
  for
    ready in [
      orient_ready, explain_ready, show_ready, practice_ready, self_explain_ready,
      retrieve_ready, transfer_ready, prove_ready, revisit_ready,
    ] {
    if ready {
      quality_dimensions_ready += 1
    }
  }
  let structurally_valid = structural.is_empty()
  let navigation_ready = navigation.is_empty()
  let content_ready = structurally_valid &&
    navigation_ready &&
    quality_dimensions_ready == 9
  let review_ready = review.is_empty()
  {
    orient_ready,
    explain_ready,
    show_ready,
    practice_ready,
    self_explain_ready,
    retrieve_ready,
    transfer_ready,
    prove_ready,
    revisit_ready,
    quality_dimensions_ready,
    reader_quality_score: quality_dimensions_ready * 100 / 9,
    navigation_ready,
    structurally_valid,
    content_ready,
    review_ready,
    publishable: content_ready && review_ready,
    issues: ReadOnlyArray::from_array(issues),
  }
}

///|
fn ReaderProjection::structural_issues(
  self : ReaderProjection,
) -> Array[ReaderProjectionIssue] {
  let issues : Array[ReaderProjectionIssue] = []
  if self.contract_version != reader_projection_contract_version() {
    issues.push(InvalidContract(self.contract_version))
  }
  if self.projection_id.is_blank() {
    issues.push(MissingIdentity("projection_id"))
  }
  if self.projection_revision.is_blank() {
    issues.push(MissingIdentity("projection_revision"))
  }
  if self.projection_digest.is_blank() {
    issues.push(MissingProjectionDigest)
  } else if !valid_digest(self.projection_digest) {
    issues.push(InvalidDigest("projection_digest"))
  }
  if self.book_id.is_blank() {
    issues.push(MissingIdentity("book_id"))
  }
  if self.canonical_source_subject_id.is_blank() {
    issues.push(MissingIdentity("canonical_source_subject_id"))
  }
  if self.language.is_blank() {
    issues.push(MissingIdentity("language"))
  }
  if self.title.is_blank() {
    issues.push(MissingIdentity("title"))
  }
  if self.estimated_minutes <= 0 {
    issues.push(InvalidEstimatedMinutes(self.estimated_minutes))
  }
  issues
}

///|
fn ReaderProjection::orient_issues(
  self : ReaderProjection,
) -> Array[ReaderProjectionIssue] {
  let issues : Array[ReaderProjectionIssue] = []
  if self.audience.is_blank() {
    issues.push(MissingAudience)
  } else if generic_audience(self.audience) {
    issues.push(GenericAudience(self.audience))
  }
  if self.outcome.is_blank() {
    issues.push(MissingOutcome)
  }
  if self.main_message.is_blank() {
    issues.push(MissingMainMessage)
  } else {
    let count = sentence_count(self.main_message)
    if count < 1 || count > 3 {
      issues.push(MainMessageSentenceCount(count))
    }
  }
  if self.next_action.is_blank() {
    issues.push(MissingNextAction)
  }
  issues
}

///|
fn ReaderProjection::explain_issues(
  self : ReaderProjection,
) -> Array[ReaderProjectionIssue] {
  let issues : Array[ReaderProjectionIssue] = []
  if self.route_intro.is_blank() || self.learning_path.is_empty() {
    issues.push(MissingRoute)
  }
  if self.prerequisite_note.is_blank() {
    issues.push(MissingPrerequisiteStatement)
  }
  if self.sections.is_empty() {
    issues.push(MissingSection)
  }
  if self.glossary.is_empty() {
    issues.push(MissingGlossary)
  }
  let section_ids : Array[String] = []
  for section in self.sections {
    if section.section_id.is_blank() ||
      section.title.is_blank() ||
      section.plain_summary.is_blank() ||
      section.body_markdown.is_blank() {
      issues.push(MissingSection)
    }
    if section_ids.contains(section.section_id) {
      issues.push(DuplicateSectionId(section.section_id))
    } else {
      section_ids.push(section.section_id)
    }
  }
  for section_id in self.learning_path {
    if !section_ids.contains(section_id) {
      issues.push(UnknownLearningPathSection(section_id))
    }
  }
  add_view_specific_issues(issues, self)
  issues
}

///|
fn ReaderProjection::show_issues(
  self : ReaderProjection,
) -> Array[ReaderProjectionIssue] {
  let issues : Array[ReaderProjectionIssue] = []
  if self.worked_examples.is_empty() {
    issues.push(MissingIllustration)
  }
  for example in self.worked_examples {
    if example.title.is_blank() ||
      example.situation.is_blank() ||
      example.steps.is_empty() ||
      example.takeaway.is_blank() {
      issues.push(IncompleteIllustration(example.title))
    }
  }
  issues
}

///|
fn ReaderProjection::practice_issues(
  self : ReaderProjection,
) -> Array[ReaderProjectionIssue] {
  let issues : Array[ReaderProjectionIssue] = []
  if self.exercises.is_empty() {
    issues.push(MissingExercise)
  }
  for exercise in self.exercises {
    if exercise.prompt.is_blank() || exercise.expected_artifact.is_blank() {
      issues.push(IncompletePractice(exercise.prompt))
    }
  }
  issues
}

///|
fn ReaderProjection::self_explain_issues(
  self : ReaderProjection,
) -> Array[ReaderProjectionIssue] {
  let issues : Array[ReaderProjectionIssue] = []
  if self.exercises.is_empty() {
    issues.push(MissingSelfExplanation("exercise"))
  }
  for exercise in self.exercises {
    if exercise.self_explanation_prompt.is_blank() {
      issues.push(MissingSelfExplanation(exercise.prompt))
    }
  }
  issues
}

///|
fn ReaderProjection::retrieve_issues(
  self : ReaderProjection,
) -> Array[ReaderProjectionIssue] {
  let issues : Array[ReaderProjectionIssue] = []
  if self.exercises.is_empty() {
    issues.push(IncompleteCheckpoint("exercise"))
  }
  for exercise in self.exercises {
    if exercise.checkpoint_question.is_blank() ||
      exercise.checkpoint_answer.is_blank() {
      issues.push(IncompleteCheckpoint(exercise.prompt))
    }
  }
  issues
}

///|
fn ReaderProjection::transfer_issues(
  self : ReaderProjection,
) -> Array[ReaderProjectionIssue] {
  let issues : Array[ReaderProjectionIssue] = []
  if self.exercises.is_empty() {
    issues.push(MissingTransferTask("exercise"))
  }
  for exercise in self.exercises {
    if exercise.transfer_task.is_blank() {
      issues.push(MissingTransferTask(exercise.prompt))
    }
  }
  issues
}

///|
fn ReaderProjection::revisit_issues(
  self : ReaderProjection,
) -> Array[ReaderProjectionIssue] {
  let issues : Array[ReaderProjectionIssue] = []
  if self.exercises.is_empty() {
    issues.push(MissingRevisitPlan("exercise"))
  }
  for exercise in self.exercises {
    if exercise.revisit_prompt.is_blank() || exercise.revisit_after_days <= 0 {
      issues.push(MissingRevisitPlan(exercise.prompt))
    }
  }
  issues
}

///|
fn add_view_specific_issues(
  issues : Array[ReaderProjectionIssue],
  projection : ReaderProjection,
) -> Unit {
  match projection.view {
    Learn => {
      if projection.apply_frame is Some(_) {
        issues.push(UnexpectedViewFrame("apply"))
      }
      if projection.research_frame is Some(_) {
        issues.push(UnexpectedViewFrame("research"))
      }
    }
    Apply => {
      match projection.apply_frame {
        None => issues.push(MissingApplyFrame)
        Some(frame) => {
          if frame.procedure_steps.is_empty() {
            issues.push(IncompleteApplyFrame("procedure_steps"))
          }
          if frame.decision_points.is_empty() {
            issues.push(IncompleteApplyFrame("decision_points"))
          }
          if frame.tradeoffs.is_empty() {
            issues.push(IncompleteApplyFrame("tradeoffs"))
          }
          if frame.template_artifact.is_blank() {
            issues.push(IncompleteApplyFrame("template_artifact"))
          }
        }
      }
      if projection.research_frame is Some(_) {
        issues.push(UnexpectedViewFrame("research"))
      }
    }
    Research => {
      match projection.research_frame {
        None => issues.push(MissingResearchFrame)
        Some(frame) => {
          if frame.research_method.is_blank() {
            issues.push(IncompleteResearchFrame("research_method"))
          }
          if frame.contradictions.is_empty() {
            issues.push(IncompleteResearchFrame("contradictions"))
          }
          if frame.uncertainties.is_empty() {
            issues.push(IncompleteResearchFrame("uncertainties"))
          }
          if frame.limitations.is_empty() {
            issues.push(IncompleteResearchFrame("limitations"))
          }
          if frame.review_lineage.is_empty() {
            issues.push(IncompleteResearchFrame("review_lineage"))
          }
        }
      }
      if projection.apply_frame is Some(_) {
        issues.push(UnexpectedViewFrame("apply"))
      }
    }
  }
}

///|
fn ReaderProjection::navigation_issues(
  self : ReaderProjection,
) -> Array[ReaderProjectionIssue] {
  let issues : Array[ReaderProjectionIssue] = []
  if self.navigation.canonical_href.is_blank() {
    issues.push(MissingCanonicalLink)
  }
  if self.navigation.maintenance_href.is_blank() {
    issues.push(MissingMaintenanceLink)
  }
  let seen : Array[ReaderView] = []
  for link in self.navigation.view_links {
    if seen.contains(link.view) {
      issues.push(DuplicateViewLink(link.view))
    } else {
      seen.push(link.view)
    }
  }
  if !self.navigation.view_links.any(fn(link) {
      link.view == self.view && !link.href.is_blank()
    }) {
    issues.push(MissingCurrentViewLink(self.view))
  }
  issues
}

///|
fn ReaderProjection::prove_issues(
  self : ReaderProjection,
) -> Array[ReaderProjectionIssue] {
  let issues : Array[ReaderProjectionIssue] = []
  if self.source_revision.is_blank() {
    issues.push(MissingSourceRevision)
  }
  if self.source_digest.is_blank() {
    issues.push(MissingSourceDigest)
  } else if !valid_digest(self.source_digest) {
    issues.push(InvalidDigest("source_digest"))
  }
  if self.source_refs.is_empty() {
    issues.push(MissingSourceReference)
  }
  let ids : Array[String] = []
  for source in self.source_refs {
    if source.reference_id.is_blank() ||
      source.locator.is_blank() ||
      source.revision.is_blank() ||
      source.digest.is_blank() {
      issues.push(IncompleteSourceReference(source.reference_id))
    }
    if !source.digest.is_blank() && !valid_digest(source.digest) {
      issues.push(InvalidDigest("source_refs.\{source.reference_id}.digest"))
    }
    if ids.contains(source.reference_id) {
      issues.push(DuplicateSourceReference(source.reference_id))
    } else {
      ids.push(source.reference_id)
    }
  }
  for section in self.sections {
    if section.source_ref_ids.is_empty() {
      issues.push(MissingCitation("section:\{section.section_id}"))
    }
    add_unknown_refs(issues, ids, section.source_ref_ids)
  }
  for term in self.glossary {
    if term.source_ref_ids.is_empty() {
      issues.push(MissingCitation("glossary:\{term.term}"))
    }
    add_unknown_refs(issues, ids, term.source_ref_ids)
  }
  for example in self.worked_examples {
    if example.source_ref_ids.is_empty() {
      issues.push(MissingCitation("example:\{example.title}"))
    }
    add_unknown_refs(issues, ids, example.source_ref_ids)
  }
  for exercise in self.exercises {
    if exercise.source_ref_ids.is_empty() {
      issues.push(MissingCitation("exercise:\{exercise.prompt}"))
    }
    add_unknown_refs(issues, ids, exercise.source_ref_ids)
  }
  add_review_binding_issues(
    issues,
    "source_review",
    self.source_review,
    CanonicalBook,
    self.canonical_source_subject_id,
    self.source_revision,
    self.source_digest,
    true,
  )
  issues
}

///|
fn ReaderProjection::projection_review_issues(
  self : ReaderProjection,
) -> Array[ReaderProjectionIssue] {
  let issues : Array[ReaderProjectionIssue] = []
  add_review_binding_issues(
    issues,
    "projection_review",
    self.projection_review,
    ReaderProjectionArtifact,
    self.projection_id,
    self.projection_revision,
    self.projection_digest,
    false,
  )
  if !self.source_review.receipt.receipt_id.is_blank() &&
    self.source_review.receipt.receipt_id ==
    self.projection_review.receipt.receipt_id {
    issues.push(ReviewReceiptReused)
  }
  issues
}

///|
fn add_review_binding_issues(
  issues : Array[ReaderProjectionIssue],
  label : String,
  binding : ReaderReviewBinding,
  expected_kind : ReaderReviewSubjectKind,
  expected_id : String,
  expected_version : String,
  expected_digest : String,
  source_review : Bool,
) -> Unit {
  let subject = binding.subject
  if subject.subject_id.is_blank() ||
    subject.version.is_blank() ||
    subject.digest.is_blank() {
    issues.push(ReviewSubjectIncomplete(label))
  }
  if subject.kind != expected_kind ||
    subject.subject_id != expected_id ||
    subject.version != expected_version ||
    subject.digest != expected_digest {
    issues.push(ReviewSubjectMismatch(label))
  }
  if !subject.digest.is_blank() && !valid_digest(subject.digest) {
    issues.push(InvalidDigest("\{label}.subject.digest"))
  }
  let receipt = binding.receipt
  if receipt.receipt_id.is_blank() ||
    receipt.version.is_blank() ||
    receipt.digest.is_blank() {
    issues.push(ReviewReceiptIncomplete(label))
  }
  if !receipt.digest.is_blank() && !valid_digest(receipt.digest) {
    issues.push(InvalidDigest("\{label}.receipt.digest"))
  }
  if binding.reviewer.reviewer_id.is_blank() {
    issues.push(ReviewReviewerMissing(label))
  }
  if binding.reviewer.kind != Human {
    issues.push(ReviewReviewerNotHuman(label, binding.reviewer.kind))
  }
  if binding.authority.attestation_id.is_blank() ||
    binding.authority.version.is_blank() ||
    binding.authority.digest.is_blank() {
    issues.push(ReviewAuthorityMissing(label))
  }
  if !binding.authority.digest.is_blank() &&
    !valid_digest(binding.authority.digest) {
    issues.push(InvalidDigest("\{label}.authority.digest"))
  }
  if binding.evidence_refs.is_empty() {
    issues.push(ReviewEvidenceMissing(label))
  }
  let evidence_ids : Array[String] = []
  for evidence in binding.evidence_refs {
    if evidence.reference_id.is_blank() ||
      evidence.version.is_blank() ||
      evidence.digest.is_blank() {
      issues.push(ReviewEvidenceIncomplete(label))
    }
    if !evidence.digest.is_blank() && !valid_digest(evidence.digest) {
      issues.push(
        InvalidDigest("\{label}.evidence_refs.\{evidence.reference_id}.digest"),
      )
    }
    if evidence_ids.contains(evidence.reference_id) {
      issues.push(DuplicateReviewEvidence(evidence.reference_id))
    } else {
      evidence_ids.push(evidence.reference_id)
    }
  }
  let status = binding.review_status()
  if status != Accepted {
    if source_review {
      issues.push(SourceNotAccepted(status))
    } else {
      issues.push(ProjectionNotAccepted(status))
    }
  }
}

///|
fn add_unknown_refs(
  issues : Array[ReaderProjectionIssue],
  known : Array[String],
  cited : ReadOnlyArray[String],
) -> Unit {
  for reference_id in cited {
    if !known.contains(reference_id) {
      issues.push(UnknownSourceReference(reference_id))
    }
  }
}

///|
fn generic_audience(audience : String) -> Bool {
  let normalized = audience.trim().to_owned().to_lower()
  [
    "everyone", "anyone", "general public", "the general public", "all users", "all readers",
    "people", "users", "readers", "所有人", "任何人", "大众", "普通大众",
    "用户", "读者",
  ].contains(normalized)
}

///|
fn sentence_count(text : String) -> Int {
  let mut count = 0
  let mut has_content = false
  for character in text.trim() {
    if character == '.' ||
      character == '!' ||
      character == '?' ||
      character == '。' ||
      character == '！' ||
      character == '？' {
      if has_content {
        count += 1
        has_content = false
      }
    } else if character != ' ' && character != '\n' && character != '\t' {
      has_content = true
    }
  }
  if has_content {
    count += 1
  }
  count
}

///|
fn valid_digest(value : String) -> Bool {
  let normalized = value.trim().to_lower()
  let (prefix_length, payload_length) = if normalized.has_prefix("sha256:") {
    (7, 64)
  } else if normalized.has_prefix("blake3:") {
    (7, 64)
  } else if normalized.has_prefix("sha512:") {
    (7, 128)
  } else {
    return false
  }
  let payload = normalized[prefix_length:]
  if payload.length() != payload_length {
    return false
  }
  for character in payload {
    if !(character >= '0' && character <= '9') &&
      !(character >= 'a' && character <= 'f') {
      return false
    }
  }
  true
}
