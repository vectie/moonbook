///|
priv struct ReaderReviewSubjectRefWire {
  kind : ReaderReviewSubjectKind
  subject_id : String
  version : String
  digest : String
} derive(FromJson)

///|
priv struct ReaderReviewReceiptRefWire {
  receipt_id : String
  version : String
  digest : String
} derive(FromJson)

///|
priv struct ReaderReviewerIdentityWire {
  reviewer_id : String
  kind : ReaderReviewerKind
} derive(FromJson)

///|
priv struct ReaderAuthorityAttestationRefWire {
  attestation_id : String
  version : String
  digest : String
} derive(FromJson)

///|
priv struct ReaderReviewEvidenceRefWire {
  reference_id : String
  version : String
  digest : String
} derive(FromJson)

///|
priv struct ReaderReviewBindingWire {
  subject : ReaderReviewSubjectRefWire
  receipt : ReaderReviewReceiptRefWire
  disposition : ReaderReviewDisposition
  reviewer : ReaderReviewerIdentityWire
  authority : ReaderAuthorityAttestationRefWire
  evidence_refs : Array[ReaderReviewEvidenceRefWire]
} derive(FromJson)

///|
priv struct ReaderSourceRefWire {
  reference_id : String
  title : String
  locator : String
  revision : String
  digest : String
} derive(FromJson)

///|
priv struct ReaderSectionWire {
  section_id : String
  title : String
  plain_summary : String
  body_markdown : String
  source_ref_ids : Array[String]
} derive(FromJson)

///|
priv struct ReaderGlossaryEntryWire {
  term : String
  plain_definition : String
  source_ref_ids : Array[String]
} derive(FromJson)

///|
priv struct ReaderWorkedExampleWire {
  title : String
  situation : String
  steps : Array[String]
  takeaway : String
  source_ref_ids : Array[String]
} derive(FromJson)

///|
priv struct ReaderExerciseWire {
  prompt : String
  expected_artifact : String
  checkpoint_question : String
  checkpoint_answer : String
  self_explanation_prompt : String
  transfer_task : String
  revisit_prompt : String
  revisit_after_days : Int
  source_ref_ids : Array[String]
} derive(FromJson)

///|
priv struct ReaderApplyFrameWire {
  procedure_steps : Array[String]
  decision_points : Array[String]
  tradeoffs : Array[String]
  template_artifact : String
} derive(FromJson)

///|
priv struct ReaderResearchFrameWire {
  research_method : String
  contradictions : Array[String]
  uncertainties : Array[String]
  limitations : Array[String]
  review_lineage : Array[String]
} derive(FromJson)

///|
priv struct ReaderViewLinkWire {
  view : ReaderView
  href : String
  review_status : ReaderReviewStatus
} derive(FromJson)

///|
priv struct ReaderNavigationWire {
  canonical_href : String
  maintenance_href : String
  view_links : Array[ReaderViewLinkWire]
} derive(FromJson)

///|
priv struct ReaderProjectionWire {
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
  prerequisites : Array[String]
  learning_path : Array[String]
  sections : Array[ReaderSectionWire]
  glossary : Array[ReaderGlossaryEntryWire]
  worked_examples : Array[ReaderWorkedExampleWire]
  exercises : Array[ReaderExerciseWire]
  apply_frame : ReaderApplyFrameWire?
  research_frame : ReaderResearchFrameWire?
  navigation : ReaderNavigationWire
  source_revision : String
  source_digest : String
  source_review : ReaderReviewBindingWire
  source_refs : Array[ReaderSourceRefWire]
  projection_review : ReaderReviewBindingWire
} derive(FromJson)

///|
/// Decode the stable JSON representation without making its mutable wire
/// arrays part of the public projection model.
pub fn reader_projection_from_json(value : Json) -> ReaderProjection raise {
  @json.from_json(value)
}

///|
/// `ReaderProjection` is a genuine round-trip wire type even though its public
/// collections are read-only. Decoding passes through a private mutable DTO
/// and freezes every collection before returning.
pub impl @json.FromJson for ReaderProjection with fn from_json(
  value : Json,
  path : @json.JsonPath,
) -> ReaderProjection raise @json.JsonDecodeError {
  let wire : ReaderProjectionWire = @json.FromJson::from_json(value, path)
  reader_projection_from_wire(wire)
}

///|
pub fn reader_projection_from_json_text(
  text : StringView,
) -> ReaderProjection raise {
  reader_projection_from_json(@json.parse(text))
}

///|
pub fn ReaderProjection::to_json_text(
  self : ReaderProjection,
  indent? : Int = 2,
) -> String {
  self.to_json().stringify(indent~)
}

///|
fn reader_projection_from_wire(wire : ReaderProjectionWire) -> ReaderProjection {
  {
    contract_version: wire.contract_version,
    projection_id: wire.projection_id,
    projection_revision: wire.projection_revision,
    projection_digest: wire.projection_digest,
    book_id: wire.book_id,
    canonical_source_subject_id: wire.canonical_source_subject_id,
    view: wire.view,
    language: wire.language,
    title: wire.title,
    estimated_minutes: wire.estimated_minutes,
    audience: wire.audience,
    outcome: wire.outcome,
    main_message: wire.main_message,
    next_action: wire.next_action,
    route_intro: wire.route_intro,
    prerequisite_note: wire.prerequisite_note,
    prerequisites: ReadOnlyArray::from_array(wire.prerequisites),
    learning_path: ReadOnlyArray::from_array(wire.learning_path),
    sections: ReadOnlyArray::from_array(
      wire.sections.map(fn(item) {
        ReaderSection::new(
          section_id=item.section_id,
          title=item.title,
          plain_summary=item.plain_summary,
          body_markdown=item.body_markdown,
          source_ref_ids=item.source_ref_ids,
        )
      }),
    ),
    glossary: ReadOnlyArray::from_array(
      wire.glossary.map(fn(item) {
        ReaderGlossaryEntry::new(
          term=item.term,
          plain_definition=item.plain_definition,
          source_ref_ids=item.source_ref_ids,
        )
      }),
    ),
    worked_examples: ReadOnlyArray::from_array(
      wire.worked_examples.map(fn(item) {
        ReaderWorkedExample::new(
          title=item.title,
          situation=item.situation,
          steps=item.steps,
          takeaway=item.takeaway,
          source_ref_ids=item.source_ref_ids,
        )
      }),
    ),
    exercises: ReadOnlyArray::from_array(
      wire.exercises.map(fn(item) {
        ReaderExercise::new(
          prompt=item.prompt,
          expected_artifact=item.expected_artifact,
          checkpoint_question=item.checkpoint_question,
          checkpoint_answer=item.checkpoint_answer,
          self_explanation_prompt=item.self_explanation_prompt,
          transfer_task=item.transfer_task,
          revisit_prompt=item.revisit_prompt,
          revisit_after_days=item.revisit_after_days,
          source_ref_ids=item.source_ref_ids,
        )
      }),
    ),
    apply_frame: wire.apply_frame.map(fn(frame) {
      ReaderApplyFrame::new(
        procedure_steps=frame.procedure_steps,
        decision_points=frame.decision_points,
        tradeoffs=frame.tradeoffs,
        template_artifact=frame.template_artifact,
      )
    }),
    research_frame: wire.research_frame.map(fn(frame) {
      ReaderResearchFrame::new(
        research_method=frame.research_method,
        contradictions=frame.contradictions,
        uncertainties=frame.uncertainties,
        limitations=frame.limitations,
        review_lineage=frame.review_lineage,
      )
    }),
    navigation: ReaderNavigation::new(
      canonical_href=wire.navigation.canonical_href,
      maintenance_href=wire.navigation.maintenance_href,
      view_links=wire.navigation.view_links.map(fn(link) {
        ReaderViewLink::new(
          view=link.view,
          href=link.href,
          review_status=link.review_status,
        )
      }),
    ),
    source_revision: wire.source_revision,
    source_digest: wire.source_digest,
    source_review: review_binding_from_wire(wire.source_review),
    source_refs: ReadOnlyArray::from_array(
      wire.source_refs.map(fn(source) {
        ReaderSourceRef::new(
          reference_id=source.reference_id,
          title=source.title,
          locator=source.locator,
          revision=source.revision,
          digest=source.digest,
        )
      }),
    ),
    projection_review: review_binding_from_wire(wire.projection_review),
  }
}

///|
fn review_binding_from_wire(
  wire : ReaderReviewBindingWire,
) -> ReaderReviewBinding {
  ReaderReviewBinding::new(
    subject=ReaderReviewSubjectRef::new(
      kind=wire.subject.kind,
      subject_id=wire.subject.subject_id,
      version=wire.subject.version,
      digest=wire.subject.digest,
    ),
    receipt=ReaderReviewReceiptRef::new(
      receipt_id=wire.receipt.receipt_id,
      version=wire.receipt.version,
      digest=wire.receipt.digest,
    ),
    disposition=wire.disposition,
    reviewer=ReaderReviewerIdentity::new(
      reviewer_id=wire.reviewer.reviewer_id,
      kind=wire.reviewer.kind,
    ),
    authority=ReaderAuthorityAttestationRef::new(
      attestation_id=wire.authority.attestation_id,
      version=wire.authority.version,
      digest=wire.authority.digest,
    ),
    evidence_refs=wire.evidence_refs.map(fn(evidence) {
      ReaderReviewEvidenceRef::new(
        reference_id=evidence.reference_id,
        version=evidence.version,
        digest=evidence.digest,
      )
    }),
  )
}
