///|
fn test_digest(fill : String) -> String {
  "sha256:" + fill.repeat(64)
}

///|
fn accepted_review(
  subject_kind : @reader_projection.ReaderReviewSubjectKind,
  subject_id : String,
  subject_version : String,
  subject_digest : String,
  review_key : String,
  receipt_fill : String,
  authority_fill : String,
  evidence_fill : String,
) -> @reader_projection.ReaderReviewBinding {
  @reader_projection.ReaderReviewBinding::new(
    subject=@reader_projection.ReaderReviewSubjectRef::new(
      kind=subject_kind,
      subject_id~,
      version=subject_version,
      digest=subject_digest,
    ),
    receipt=@reader_projection.ReaderReviewReceiptRef::new(
      receipt_id="receipt-\{review_key}",
      version="1",
      digest=test_digest(receipt_fill),
    ),
    disposition=Accept,
    reviewer=@reader_projection.ReaderReviewerIdentity::new(
      reviewer_id="bookkeeper-human",
      kind=Human,
    ),
    authority=@reader_projection.ReaderAuthorityAttestationRef::new(
      attestation_id="authority-\{review_key}",
      version="1",
      digest=test_digest(authority_fill),
    ),
    evidence_refs=[
      @reader_projection.ReaderReviewEvidenceRef::new(
        reference_id="review-evidence-\{review_key}",
        version="1",
        digest=test_digest(evidence_fill),
      ),
    ],
  )
}

///|
fn complete_projection(
  view : @reader_projection.ReaderView,
  apply_frame : @reader_projection.ReaderApplyFrame?,
  research_frame : @reader_projection.ReaderResearchFrame?,
  source_revision : String,
) -> @reader_projection.ReaderProjection {
  let projection_id = "book-1-\{view.key()}"
  let projection_revision = "3"
  let projection_digest = test_digest("d")
  let source_digest = test_digest("c")
  let canonical_source_subject_id = "book-1-canonical-r\{source_revision}"
  let source = @reader_projection.ReaderSourceRef::new(
    reference_id="src-1",
    title="Canonical evidence",
    locator="wiki/sources/source-1.md",
    revision="7",
    digest=test_digest("a"),
  )
  let section = @reader_projection.ReaderSection::new(
    section_id="concept",
    title="The central concept",
    plain_summary="A plain-language summary.",
    body_markdown="The maintained explanation cites canonical evidence.",
    source_ref_ids=["src-1"],
  )
  let glossary = @reader_projection.ReaderGlossaryEntry::new(
    term="Projection",
    plain_definition="A reader view derived from canonical book truth.",
    source_ref_ids=["src-1"],
  )
  let example = @reader_projection.ReaderWorkedExample::new(
    title="Choose a reading view",
    situation="A new reader opens a technically dense book.",
    steps=[
      "Open Learn for the plain explanation.", "Switch to Apply when a reusable artifact is needed.",
    ],
    takeaway="Views change presentation depth without copying truth.",
    source_ref_ids=["src-1"],
  )
  let exercise = @reader_projection.ReaderExercise::new(
    prompt="Explain the concept in your own words.",
    expected_artifact="A two-sentence explanation and one worked decision.",
    checkpoint_question="Where does accepted truth live?",
    checkpoint_answer="In the canonical reviewed MoonBook revision.",
    self_explanation_prompt="Why is the projection not a second book?",
    transfer_task="Apply the same view split to another domain book.",
    revisit_prompt="Re-explain the source binding without notes.",
    revisit_after_days=3,
    source_ref_ids=["src-1"],
  )
  @reader_projection.ReaderProjection::new(
    projection_id~,
    projection_revision~,
    projection_digest~,
    book_id="book-1",
    canonical_source_subject_id~,
    view~,
    language="en",
    title="A human-readable MoonBook view",
    estimated_minutes=12,
    audience="A reader who is new to this domain.",
    outcome="The reader can explain and use the central concept.",
    main_message="One canonical book can support several reading depths.",
    next_action="Read the concept section, then complete the exercise.",
    route_intro="Start with the idea, inspect the example, then practise it.",
    prerequisite_note="No prior domain knowledge is required.",
    prerequisites=[],
    learning_path=["concept"],
    sections=[section],
    glossary=[glossary],
    worked_examples=[example],
    exercises=[exercise],
    apply_frame~,
    research_frame~,
    navigation=@reader_projection.ReaderNavigation::new(
      canonical_href="../Home.html",
      maintenance_href="../maintenance.html",
      view_links=[
        @reader_projection.ReaderViewLink::new(
          view~,
          href="./\{view.key()}.html",
          review_status=Accepted,
        ),
      ],
    ),
    source_revision~,
    source_digest~,
    source_review=accepted_review(
      CanonicalBook,
      canonical_source_subject_id,
      source_revision,
      source_digest,
      "source",
      "e",
      "f",
      "1",
    ),
    source_refs=[source],
    projection_review=accepted_review(
      ReaderProjectionArtifact,
      projection_id,
      projection_revision,
      projection_digest,
      "projection",
      "2",
      "3",
      "4",
    ),
  )
}

///|
test "accepted Learn projection is publishable and JSON round-trips" {
  let original = complete_projection(Learn, None, None, "7")
  let readiness = original.readiness()
  assert_eq(readiness.quality_dimensions_ready, 9)
  assert_eq(readiness.reader_quality_score, 100)
  assert_true(readiness.content_ready)
  assert_true(readiness.review_ready)
  assert_true(readiness.publishable)
  assert_true(readiness.issues.is_empty())
  assert_true(original.canonical_subject_id() != original.book_id)
  assert_eq(
    original.source_review.subject.subject_id,
    original.canonical_subject_id(),
  )
  assert_true(
    original.source_review.receipt.receipt_id !=
    original.projection_review.receipt.receipt_id,
  )
  let decoded : @reader_projection.ReaderProjection = @json.from_json(
    original.to_json(),
  )
  assert_eq(decoded, original)
  assert_eq(decoded.view_mode(), Learn)
  assert_eq(
    decoded.reader_sections()[0].markdown(),
    original.sections[0].body_markdown,
  )
  let text = original.to_json_text()
  assert_eq(@reader_projection.reader_projection_from_json_text(text), original)
}

///|
test "missing canonical revision fails the Prove and publication gates" {
  let projection = complete_projection(Learn, None, None, "")
  let readiness = projection.readiness()
  assert_false(readiness.prove_ready)
  assert_false(readiness.content_ready)
  assert_false(readiness.publishable)
  assert_true(readiness.issues.contains(MissingSourceRevision))
}

///|
test "Apply and Research views enforce their own semantics" {
  let missing_apply = complete_projection(Apply, None, None, "7").readiness()
  assert_false(missing_apply.explain_ready)
  assert_true(missing_apply.issues.contains(MissingApplyFrame))
  let apply = complete_projection(
    Apply,
    Some(
      @reader_projection.ReaderApplyFrame::new(
        procedure_steps=["Choose the reader outcome.", "Produce the artifact."],
        decision_points=["Select depth from the reader's intended action."],
        tradeoffs=["More detail costs reading time."],
        template_artifact="templates/reader-projection.md",
      ),
    ),
    None,
    "7",
  ).readiness()
  assert_true(apply.explain_ready)
  assert_true(apply.publishable)
  let incomplete_research = complete_projection(
    Research,
    None,
    Some(
      @reader_projection.ReaderResearchFrame::new(
        research_method="Compare the accepted claims against their sources.",
        contradictions=["One source disagrees about the optimal reading order."],
        uncertainties=["Transfer quality has not been measured longitudinally."],
        limitations=[],
        review_lineage=["review-1"],
      ),
    ),
    "7",
  ).readiness()
  assert_false(incomplete_research.explain_ready)
  assert_true(
    incomplete_research.issues.contains(IncompleteResearchFrame("limitations")),
  )
}

///|
test "generic audience, long main message, and malformed digest fail closed" {
  let encoded = complete_projection(Learn, None, None, "7").to_json()
  guard encoded is Object(fields) else {
    fail("projection JSON must be an object")
  }
  fields["audience"] = Json::string("everyone")
  fields["main_message"] = Json::string("One. Two. Three. Four.")
  fields["source_digest"] = Json::string("sha256:not-a-real-digest")
  let projection : @reader_projection.ReaderProjection = @json.from_json(
    encoded,
  )
  let readiness = projection.readiness()
  assert_false(readiness.orient_ready)
  assert_false(readiness.prove_ready)
  assert_false(readiness.publishable)
  assert_true(readiness.issues.contains(GenericAudience("everyone")))
  assert_true(readiness.issues.contains(MainMessageSentenceCount(4)))
  assert_true(readiness.issues.contains(InvalidDigest("source_digest")))
}

///|
test "learning loop fields independently gate readiness" {
  let encoded = complete_projection(Learn, None, None, "7").to_json()
  guard encoded is Object(fields) else {
    fail("projection JSON must be an object")
  }
  guard fields.get("exercises") is Some(Array(exercises)) else {
    fail("projection JSON must contain exercises")
  }
  guard exercises.get(0) is Some(Object(exercise)) else {
    fail("projection JSON must contain one exercise")
  }
  exercise["checkpoint_question"] = Json::string("")
  exercise["self_explanation_prompt"] = Json::string("")
  exercise["transfer_task"] = Json::string("")
  exercise["revisit_after_days"] = Json::number(0.0)
  let projection : @reader_projection.ReaderProjection = @json.from_json(
    encoded,
  )
  let readiness = projection.readiness()
  assert_false(readiness.self_explain_ready)
  assert_false(readiness.retrieve_ready)
  assert_false(readiness.transfer_ready)
  assert_false(readiness.revisit_ready)
  assert_eq(readiness.quality_dimensions_ready, 5)
  assert_false(readiness.content_ready)
}

///|
test "unrelated review subject and reused receipt fail exact binding" {
  let encoded = complete_projection(Learn, None, None, "7").to_json()
  guard encoded is Object(fields) else {
    fail("projection JSON must be an object")
  }
  guard fields.get("source_review") is Some(Object(source_review)) else {
    fail("projection JSON must contain source review")
  }
  guard source_review.get("subject") is Some(Object(subject)) else {
    fail("source review must contain a subject")
  }
  subject["subject_id"] = Json::string("unrelated-book")
  guard fields.get("projection_review") is Some(Object(projection_review)) else {
    fail("projection JSON must contain projection review")
  }
  guard projection_review.get("receipt") is Some(Object(receipt)) else {
    fail("projection review must contain a receipt")
  }
  receipt["receipt_id"] = Json::string("receipt-source")
  let projection : @reader_projection.ReaderProjection = @json.from_json(
    encoded,
  )
  let readiness = projection.readiness()
  assert_false(readiness.prove_ready)
  assert_false(readiness.review_ready)
  assert_false(readiness.publishable)
  assert_true(readiness.issues.contains(ReviewSubjectMismatch("source_review")))
  assert_true(readiness.issues.contains(ReviewReceiptReused))
}

///|
test "review trust rejects non-human reviewer and missing authority evidence" {
  let encoded = complete_projection(Learn, None, None, "7").to_json()
  guard encoded is Object(fields) else {
    fail("projection JSON must be an object")
  }
  guard fields.get("projection_review") is Some(Object(review)) else {
    fail("projection JSON must contain projection review")
  }
  guard review.get("reviewer") is Some(Object(reviewer)) else {
    fail("projection review reviewer must be an object")
  }
  guard review.get("authority") is Some(Object(authority)) else {
    fail("projection review trust records must be objects")
  }
  reviewer["kind"] = Json::string("Agent")
  authority["attestation_id"] = Json::string("")
  review["evidence_refs"] = Json::array([])
  let projection : @reader_projection.ReaderProjection = @json.from_json(
    encoded,
  )
  let readiness = projection.readiness()
  assert_false(readiness.review_ready)
  assert_false(readiness.publishable)
  assert_true(
    readiness.issues.contains(
      ReviewReviewerNotHuman("projection_review", Agent),
    ),
  )
  assert_true(
    readiness.issues.contains(ReviewAuthorityMissing("projection_review")),
  )
  assert_true(
    readiness.issues.contains(ReviewEvidenceMissing("projection_review")),
  )
}

///|
test "rejected disposition derives rejected status and cannot publish" {
  let encoded = complete_projection(Learn, None, None, "7").to_json()
  guard encoded is Object(fields) else {
    fail("projection JSON must be an object")
  }
  guard fields.get("projection_review") is Some(Object(review)) else {
    fail("projection JSON must contain projection review")
  }
  review["disposition"] = Json::string("Reject")
  let projection : @reader_projection.ReaderProjection = @json.from_json(
    encoded,
  )
  let readiness = projection.readiness()
  assert_eq(projection.projection_review_status(), Rejected)
  assert_false(readiness.review_ready)
  assert_false(readiness.publishable)
  assert_true(readiness.issues.contains(ProjectionNotAccepted(Rejected)))
}
