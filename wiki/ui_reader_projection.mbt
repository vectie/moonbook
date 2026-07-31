///|
// Adapter from existing MoonBook reader artifacts to the typed projection
// contract. Generated records remain drafts until exact source and projection
// review receipts exist; rendering a preview never promotes truth.

///|
priv struct UiReaderSectionSeed {
  id : String
  title : String
  body : String
  summary : String
}

///|
priv struct UiReaderProjectionBundle {
  canonical_candidate : @bookkeeper_store.DurableBookkeeperRecord
  learn_candidate : @bookkeeper_store.DurableBookkeeperRecord
  apply_candidate : @bookkeeper_store.DurableBookkeeperRecord
  research_candidate : @bookkeeper_store.DurableBookkeeperRecord
  learn : @reader_projection.ReaderProjection
  apply : @reader_projection.ReaderProjection
  research : @reader_projection.ReaderProjection
}

///|
async fn ui_reader_projections(
  root : String,
  bundle : ReaderArtifactBundle,
) -> UiReaderProjectionBundle {
  let canonical_candidate = reader_canonical_review_candidate(bundle)
  let source_review = load_reader_review_binding(
    root,
    CanonicalBook,
    canonical_candidate,
  )
  let learn_candidate = reader_projection_review_candidate(
    bundle.identity,
    bundle.learn,
    canonical_candidate.record,
  )
  let apply_candidate = reader_projection_review_candidate(
    bundle.identity,
    bundle.apply,
    canonical_candidate.record,
  )
  let research_candidate = reader_projection_review_candidate(
    bundle.identity,
    bundle.research,
    canonical_candidate.record,
  )
  let learn_review = load_reader_review_binding(
    root,
    ReaderProjectionArtifact,
    learn_candidate,
  )
  let apply_review = load_reader_review_binding(
    root,
    ReaderProjectionArtifact,
    apply_candidate,
  )
  let research_review = load_reader_review_binding(
    root,
    ReaderProjectionArtifact,
    research_candidate,
  )
  {
    canonical_candidate,
    learn_candidate,
    apply_candidate,
    research_candidate,
    learn: reader_contract_projection(
      bundle.identity,
      bundle.learn,
      source_review,
      learn_candidate.record,
      learn_review,
    ),
    apply: reader_contract_projection(
      bundle.identity,
      bundle.apply,
      source_review,
      apply_candidate.record,
      apply_review,
    ),
    research: reader_contract_projection(
      bundle.identity,
      bundle.research,
      source_review,
      research_candidate.record,
      research_review,
    ),
  }
}

///|
fn reader_bundle_projection_json(
  bundle : ReaderArtifactBundle,
  projections : UiReaderProjectionBundle,
) -> Json {
  {
    "contract_version": @reader_projection.reader_projection_contract_version(),
    "book_id": bundle.identity.book_id,
    "canonical_subject_id": bundle.identity.subject_id,
    "canonical_revision": bundle.identity.revision,
    "canonical_digest": bundle.identity.digest,
    "review_candidates": {
      "canonical_source": projections.canonical_candidate.to_json(),
      "projections": [
        projections.learn_candidate.to_json(),
        projections.apply_candidate.to_json(),
        projections.research_candidate.to_json(),
      ],
    },
    "projections": [
      projections.learn.to_json(),
      projections.apply.to_json(),
      projections.research.to_json(),
    ],
    "readiness": [
      projections.learn.readiness().to_json(),
      projections.apply.readiness().to_json(),
      projections.research.readiness().to_json(),
    ],
  }
}

///|
fn reader_contract_projection(
  identity : ReaderCanonicalBookIdentity,
  artifact : ReaderArtifactContent,
  source_review : @reader_projection.ReaderReviewBinding,
  projection_subject : @bookkeeper.VersionedRecordReference,
  projection_review : @reader_projection.ReaderReviewBinding,
) -> @reader_projection.ReaderProjection {
  let view = reader_contract_view(artifact.view)
  let book_id = identity.book_id
  let projection_id = projection_subject.record_id
  let projection_revision = projection_subject.record_version
  let projection_digest = projection_subject.record_digest
  let reference_id = "\{artifact.view}-source"
  let source_ref_ids : Array[String] = if artifact.available {
    [reference_id]
  } else {
    []
  }
  let section_seeds = reader_section_seeds(artifact)
  let sections = section_seeds.map(fn(seed) {
    @reader_projection.ReaderSection::new(
      section_id=seed.id,
      title=seed.title,
      plain_summary=seed.summary,
      body_markdown=seed.body,
      source_ref_ids~,
    )
  })
  let learning_path = section_seeds.map(seed => seed.id)
  let source_refs = if artifact.available {
    [
      @reader_projection.ReaderSourceRef::new(
        reference_id~,
        title=artifact.title,
        locator=artifact.source_path,
        revision=artifact.source_revision,
        digest=artifact.source_digest,
      ),
    ]
  } else {
    []
  }
  let navigation = @reader_projection.ReaderNavigation::new(
    canonical_href="../../Home.html",
    maintenance_href="./course.html#maintenance",
    view_links=[
      reader_contract_view_link(Learn),
      reader_contract_view_link(Apply),
      reader_contract_view_link(Research),
    ],
  )
  let prerequisites = reader_labeled_values(artifact.markdown, [
    "Prerequisite:", "Prerequisites:",
  ])
  let prerequisite_note = if prerequisites.is_empty() {
    ""
  } else {
    prerequisites.join(" ")
  }
  @reader_projection.ReaderProjection::new(
    projection_id~,
    projection_revision~,
    projection_digest~,
    book_id~,
    canonical_source_subject_id=identity.subject_id,
    view~,
    language="und",
    title=artifact.title,
    estimated_minutes=artifact.estimated_minutes,
    audience=reader_first_labeled_value(artifact.markdown, ["Audience:"]).unwrap_or(
      "",
    ),
    outcome=reader_projection_outcome(artifact),
    main_message=artifact.summary,
    next_action=artifact.next_action,
    route_intro=artifact.summary,
    prerequisite_note~,
    prerequisites~,
    learning_path~,
    sections~,
    glossary=reader_contract_glossary(artifact, source_ref_ids),
    worked_examples=reader_contract_examples(artifact, source_ref_ids),
    exercises=reader_contract_exercises(artifact, source_ref_ids),
    apply_frame=reader_contract_apply_frame(artifact),
    research_frame=reader_contract_research_frame(artifact),
    navigation~,
    source_revision=if artifact.available { identity.revision } else { "" },
    source_digest=if artifact.available { identity.digest } else { "" },
    source_review~,
    source_refs~,
    projection_review~,
  )
}

///|
fn reader_canonical_review_candidate(
  bundle : ReaderArtifactBundle,
) -> @bookkeeper_store.DurableBookkeeperRecord {
  let evidence_refs = [
    reader_artifact_evidence(bundle.identity.book_id, bundle.learn),
    reader_artifact_evidence(bundle.identity.book_id, bundle.apply),
    reader_artifact_evidence(bundle.identity.book_id, bundle.research),
  ]
  let issue_refs : Array[String] = if bundle.learn.available ||
    bundle.apply.available ||
    bundle.research.available {
    []
  } else {
    ["reader source snapshot has no available artifact"]
  }
  {
    contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
    record: reader_canonical_subject_reference(bundle.identity),
    stage: DeliverableAcceptance,
    subject: None,
    links: [],
    title: "Canonical reader source: \{bundle.identity.book_id}",
    summary: "Exact source snapshot shared by Learn, Apply, and Research.",
    owner_route: "moonbook://reader/review",
    status: if issue_refs.is_empty() {
      "awaiting review"
    } else {
      "blocked"
    },
    evidence_refs,
    issue_refs,
    requires_human_review: true,
    next_action: "Review this exact source snapshot in Bookkeeper.",
    source_product: "moonbook",
    recorded_at: 0,
    payload: bundle.identity.payload,
    side_effects_applied: false,
  }
}

///|
fn reader_projection_review_candidate(
  identity : ReaderCanonicalBookIdentity,
  artifact : ReaderArtifactContent,
  canonical_subject : @bookkeeper.VersionedRecordReference,
) -> @bookkeeper_store.DurableBookkeeperRecord {
  let payload : Json = {
    "contract_version": @bookkeeper.bookkeeper_contract_version(),
    "reader_contract_version": @reader_projection.reader_projection_contract_version(),
    "adapter_version": "moonbook.reader.adapter.v2",
    "subject_kind": "reader_projection",
    "book_id": identity.book_id,
    "canonical_subject": canonical_subject.to_json(),
    "view": artifact.view,
    "title": artifact.title,
    "summary": artifact.summary,
    "source_path": artifact.source_path,
    "source_revision": artifact.source_revision,
    "source_digest": artifact.source_digest,
    "estimated_minutes": artifact.estimated_minutes,
    "next_action": artifact.next_action,
    "markdown": artifact.markdown,
  }
  let digest = @bookkeeper_store.bookkeeper_payload_digest(payload)
  let subject : @bookkeeper.VersionedRecordReference = {
    record_id: "reader-projection:\{identity.book_id}:\{artifact.view}:\{digest[7:]}",
    record_version: digest,
    record_digest: digest,
  }
  let issue_refs : Array[String] = if artifact.available {
    []
  } else {
    ["reader projection source is unavailable"]
  }
  {
    contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
    record: subject,
    stage: DeliverableAcceptance,
    subject: None,
    links: [canonical_subject],
    title: "\{artifact.label} reader projection: \{artifact.title}",
    summary: "Exact \{artifact.view} projection generated from the canonical reader source.",
    owner_route: "moonbook://reader/review",
    status: if issue_refs.is_empty() {
      "awaiting review"
    } else {
      "blocked"
    },
    evidence_refs: [reader_artifact_evidence(identity.book_id, artifact)],
    issue_refs,
    requires_human_review: true,
    next_action: "Review this exact reader projection in Bookkeeper.",
    source_product: "moonbook",
    recorded_at: 0,
    payload,
    side_effects_applied: false,
  }
}

///|
fn reader_canonical_subject_reference(
  identity : ReaderCanonicalBookIdentity,
) -> @bookkeeper.VersionedRecordReference {
  {
    record_id: identity.subject_id,
    record_version: identity.revision,
    record_digest: identity.digest,
  }
}

///|
fn reader_artifact_evidence(
  book_id : String,
  artifact : ReaderArtifactContent,
) -> @bookkeeper.VersionedEvidenceReference {
  {
    reference_id: "reader-artifact:\{book_id}:\{artifact.view}",
    reference_version: artifact.source_revision,
    digest: artifact.source_digest,
    provenance_ref: "moonbook://\{artifact.source_path}",
  }
}

///|
async fn load_reader_review_binding(
  root : String,
  kind : @reader_projection.ReaderReviewSubjectKind,
  candidate : @bookkeeper_store.DurableBookkeeperRecord,
) -> @reader_projection.ReaderReviewBinding {
  let subject = @reader_projection.ReaderReviewSubjectRef::new(
    kind~,
    subject_id=candidate.record.record_id,
    version=candidate.record.record_version,
    digest=candidate.record.record_digest,
  )
  match
    @bookkeeper_store.load_exact_governed_acceptance(root, candidate.record) {
    Ok(receipt) => reader_accepted_review_binding(subject, receipt)
    Err(_) => pending_reader_review_binding(subject)
  }
}

///|
fn reader_accepted_review_binding(
  subject : @reader_projection.ReaderReviewSubjectRef,
  receipt : @bookkeeper_store.GovernedReviewReceipt,
) -> @reader_projection.ReaderReviewBinding {
  let grant = receipt.reviewer.grant
  @reader_projection.ReaderReviewBinding::new(
    subject~,
    receipt=@reader_projection.ReaderReviewReceiptRef::new(
      receipt_id=receipt.receipt.record_id,
      version=receipt.receipt.record_version,
      digest=receipt.receipt.record_digest,
    ),
    disposition=Accept,
    reviewer=@reader_projection.ReaderReviewerIdentity::new(
      reviewer_id=receipt.reviewer.reviewer_id,
      kind=Human,
    ),
    authority=@reader_projection.ReaderAuthorityAttestationRef::new(
      attestation_id=grant.record_id,
      version=grant.record_version,
      digest=grant.record_digest,
    ),
    evidence_refs=receipt.evidence_refs.map(fn(reference) {
      @reader_projection.ReaderReviewEvidenceRef::new(
        reference_id=reference.reference_id,
        version=reference.reference_version,
        digest=reference.digest,
      )
    }),
  )
}

///|
// Explicit typed input boundary for a future durable Bookkeeper receipt adapter.
// Until an exact receipt is returned by that adapter, generated views stay
// pending; Markdown metadata can never promote them.
fn pending_reader_review_binding(
  subject : @reader_projection.ReaderReviewSubjectRef,
) -> @reader_projection.ReaderReviewBinding {
  @reader_projection.ReaderReviewBinding::new(
    subject~,
    receipt=@reader_projection.ReaderReviewReceiptRef::new(
      receipt_id="",
      version="",
      digest="",
    ),
    disposition=Pending,
    reviewer=@reader_projection.ReaderReviewerIdentity::new(
      reviewer_id="",
      kind=System,
    ),
    authority=@reader_projection.ReaderAuthorityAttestationRef::new(
      attestation_id="",
      version="",
      digest="",
    ),
    evidence_refs=[],
  )
}

///|
fn reader_contract_view(view : String) -> @reader_projection.ReaderView {
  match view {
    "apply" => Apply
    "research" => Research
    _ => Learn
  }
}

///|
fn reader_contract_view_link(
  view : @reader_projection.ReaderView,
) -> @reader_projection.ReaderViewLink {
  @reader_projection.ReaderViewLink::new(
    view~,
    href="./course.html?view=\{view.key()}",
    review_status=Draft,
  )
}

///|
fn reader_section_seeds(
  artifact : ReaderArtifactContent,
) -> Array[UiReaderSectionSeed] {
  if !artifact.available {
    return []
  }
  let result : Array[UiReaderSectionSeed] = []
  let body : Array[String] = []
  let mut title = "Overview"
  for raw in artifact.markdown.split("\n") {
    let line = raw.trim().to_owned()
    if line.has_prefix("## ") {
      add_reader_section_seed(result, title, body)
      body.clear()
      title = strip_inline_markup(line[3:].trim().to_owned())
    } else if !line.has_prefix("# ") {
      body.push(raw.to_owned())
    }
  }
  add_reader_section_seed(result, title, body)
  if result.is_empty() {
    [
      {
        id: "section-1",
        title: artifact.title,
        body: artifact.markdown,
        summary: artifact.summary,
      },
    ]
  } else {
    result
  }
}

///|
fn add_reader_section_seed(
  result : Array[UiReaderSectionSeed],
  title : String,
  body : Array[String],
) -> Unit {
  let markdown = body.join("\n").trim().to_owned()
  if !markdown.is_empty() {
    result.push({
      id: "section-\{result.length() + 1}",
      title,
      body: markdown,
      summary: markdown_excerpt(markdown, 240),
    })
  }
}

///|
fn reader_projection_outcome(artifact : ReaderArtifactContent) -> String {
  match
    reader_named_markdown_block(artifact.markdown, [
      "course goal", "learning outcome", "outcome",
    ]).get(0) {
    Some(block) => markdown_excerpt(block, 260)
    None => artifact.summary
  }
}

///|
fn reader_contract_glossary(
  artifact : ReaderArtifactContent,
  source_ref_ids : Array[String],
) -> Array[@reader_projection.ReaderGlossaryEntry] {
  let entries : Array[@reader_projection.ReaderGlossaryEntry] = []
  for block in reader_named_markdown_block(artifact.markdown, ["glossary"]) {
    for raw in block.split("\n") {
      let mut line = raw.trim().to_owned()
      if line.has_prefix("- ") {
        line = line[2:].trim().to_owned()
      }
      match line.find(":") {
        Some(index) if index > 0 && index < line.length() - 1 =>
          entries.push(
            @reader_projection.ReaderGlossaryEntry::new(
              term=strip_inline_markup(line[:index].trim().to_owned()),
              plain_definition=strip_inline_markup(
                line[index + 1:].trim().to_owned(),
              ),
              source_ref_ids~,
            ),
          )
        _ => ()
      }
    }
  }
  entries
}

///|
fn reader_contract_examples(
  artifact : ReaderArtifactContent,
  source_ref_ids : Array[String],
) -> Array[@reader_projection.ReaderWorkedExample] {
  let examples : Array[@reader_projection.ReaderWorkedExample] = []
  let blocks = reader_named_markdown_block(artifact.markdown, [
    "worked example", "concrete example",
  ])
  for index, block in blocks {
    let situation_parts : Array[String] = []
    let steps : Array[String] = []
    let mut takeaway = ""
    for raw in block.split("\n") {
      let line = raw.trim().to_owned()
      if line.is_empty() {
        continue
      }
      if reader_numbered_item(line) is Some(step) {
        steps.push(step)
      } else if line.to_lower().has_prefix("takeaway:") {
        takeaway = line[9:].trim().to_owned()
      } else {
        situation_parts.push(line)
      }
    }
    examples.push(
      @reader_projection.ReaderWorkedExample::new(
        title="Worked example \{index + 1}",
        situation=situation_parts.join(" "),
        steps~,
        takeaway~,
        source_ref_ids~,
      ),
    )
  }
  examples
}

///|
fn reader_contract_exercises(
  artifact : ReaderArtifactContent,
  source_ref_ids : Array[String],
) -> Array[@reader_projection.ReaderExercise] {
  let exercises : Array[@reader_projection.ReaderExercise] = []
  for scope in reader_lesson_scopes(artifact.markdown) {
    for exercise in reader_contract_exercises_in_scope(scope, source_ref_ids) {
      exercises.push(exercise)
    }
  }
  if exercises.is_empty() {
    reader_contract_table_exercises(artifact.markdown, source_ref_ids)
  } else {
    exercises
  }
}

///|
fn reader_contract_exercises_in_scope(
  scope : String,
  source_ref_ids : Array[String],
) -> Array[@reader_projection.ReaderExercise] {
  let prompts = reader_named_markdown_block(scope, ["exercise"])
  let outputs = reader_named_markdown_block(scope, ["output artifact"])
  let questions = reader_named_markdown_block(scope, [
    "retrieval checkpoint", "checkpoint",
  ])
  let answers = reader_concealed_answers(scope)
  let self_explanations = reader_named_markdown_block(scope, [
    "self-explanation",
  ])
  let transfers = reader_named_markdown_block(scope, [
    "transfer task", "transfer",
  ])
  let revisits = reader_named_markdown_block(scope, ["revisit"])
  let exercises : Array[@reader_projection.ReaderExercise] = []
  for index, prompt in prompts {
    exercises.push(
      @reader_projection.ReaderExercise::new(
        prompt=markdown_excerpt(prompt, 360),
        expected_artifact=reader_array_value(outputs, index),
        checkpoint_question=reader_checkpoint_value(questions, index),
        checkpoint_answer=reader_array_value(answers, index),
        self_explanation_prompt=reader_array_value(self_explanations, index),
        transfer_task=reader_array_value(transfers, index),
        revisit_prompt=reader_revisit_value(revisits, index),
        revisit_after_days=reader_revisit_days(scope),
        source_ref_ids~,
      ),
    )
  }
  exercises
}

///|
fn reader_lesson_scopes(markdown : String) -> Array[String] {
  let scopes : Array[String] = []
  let current : Array[String] = []
  let mut in_lesson = false
  for raw in markdown.split("\n") {
    let line = raw.trim().to_owned()
    let depth = reader_markdown_heading_depth(line)
    let heading = if depth > 0 {
      line[depth:].trim().to_lower().to_owned()
    } else {
      ""
    }
    if depth > 0 && heading.has_prefix("lesson ") {
      if in_lesson && !current.is_empty() {
        scopes.push(current.join("\n"))
        current.clear()
      }
      in_lesson = true
    }
    if in_lesson {
      current.push(raw.to_owned())
    }
  }
  if in_lesson && !current.is_empty() {
    scopes.push(current.join("\n"))
  }
  if scopes.is_empty() {
    [markdown]
  } else {
    scopes
  }
}

///|
fn reader_checkpoint_value(values : Array[String], index : Int) -> String {
  match values.get(index) {
    Some(value) => markdown_excerpt(reader_without_details(value), 360)
    None => ""
  }
}

///|
fn reader_without_details(markdown : String) -> String {
  let visible : Array[String] = []
  let mut in_details = false
  for raw in markdown.split("\n") {
    let lower = raw.trim().to_lower()
    if lower.has_prefix("<details") {
      in_details = !lower.contains("</details>")
      continue
    }
    if in_details {
      if lower.contains("</details>") {
        in_details = false
      }
      continue
    }
    visible.push(raw.to_owned())
  }
  visible.join("\n").trim().to_owned()
}

///|
fn reader_revisit_value(values : Array[String], index : Int) -> String {
  match values.get(index) {
    Some(value) => {
      let lines : Array[String] = []
      for raw in value.split("\n") {
        let lower = strip_inline_markup(raw.trim().to_owned()).to_lower()
        if !lower.has_prefix("revisit after days:") &&
          !lower.has_prefix("revisit in days:") {
          lines.push(raw.to_owned())
        }
      }
      markdown_excerpt(lines.join("\n"), 360)
    }
    None => ""
  }
}

///|
fn reader_contract_table_exercises(
  markdown : String,
  source_ref_ids : Array[String],
) -> Array[@reader_projection.ReaderExercise] {
  let exercises : Array[@reader_projection.ReaderExercise] = []
  let table : Array[String] = []
  for raw in markdown.split("\n") {
    let line = raw.trim().to_owned()
    if line.has_prefix("|") {
      table.push(line)
      continue
    }
    if !table.is_empty() {
      add_reader_exercise_table(exercises, table, source_ref_ids)
      table.clear()
    }
  }
  if !table.is_empty() {
    add_reader_exercise_table(exercises, table, source_ref_ids)
  }
  exercises
}

///|
fn add_reader_exercise_table(
  exercises : Array[@reader_projection.ReaderExercise],
  lines : Array[String],
  source_ref_ids : Array[String],
) -> Unit {
  if lines.is_empty() {
    return
  }
  let header = reader_table_cells(lines[0])
  if !reader_exercise_table_header(header) {
    return
  }
  for raw in lines[1:] {
    if raw.contains("---") {
      continue
    }
    let cells = reader_table_cells(raw)
    if cells.length() >= 3 {
      exercises.push(
        @reader_projection.ReaderExercise::new(
          prompt=cells[0],
          expected_artifact=cells[1],
          checkpoint_question="Does the artifact satisfy the recorded pass condition?",
          checkpoint_answer=cells[2],
          self_explanation_prompt="",
          transfer_task="",
          revisit_prompt="",
          revisit_after_days=0,
          source_ref_ids~,
        ),
      )
    }
  }
}

///|
fn reader_table_cells(line : String) -> Array[String] {
  let cells : Array[String] = []
  for part in line.split("|") {
    let cell = part.trim().to_owned()
    if !cell.is_empty() {
      cells.push(strip_inline_markup(cell))
    }
  }
  cells
}

///|
fn reader_exercise_table_header(cells : Array[String]) -> Bool {
  if cells.length() < 3 {
    return false
  }
  let first = cells[0].trim().to_lower().to_owned()
  let second = cells[1].trim().to_lower().to_owned()
  let third = cells[2].trim().to_lower().to_owned()
  ["exercise", "task", "practice"].contains(first) &&
  ["artifact", "output", "output artifact"].contains(second) &&
  ["pass condition", "checkpoint", "acceptance criteria", "success criterion"].contains(
    third,
  )
}

///|
fn reader_contract_apply_frame(
  artifact : ReaderArtifactContent,
) -> @reader_projection.ReaderApplyFrame? {
  if artifact.view != "apply" {
    return None
  }
  let procedure_steps : Array[String] = []
  for raw in artifact.markdown.split("\n") {
    match reader_numbered_item(raw.trim().to_owned()) {
      Some(step) => procedure_steps.push(step)
      None => ()
    }
  }
  let table_exercises = reader_contract_table_exercises(artifact.markdown, [])
  if procedure_steps.is_empty() {
    for exercise in table_exercises {
      procedure_steps.push(exercise.prompt)
    }
  }
  let decision_points = reader_block_excerpts(artifact.markdown, [
    "decision", "decision points",
  ])
  let tradeoffs = reader_block_excerpts(artifact.markdown, [
    "trade-off", "trade-offs", "tradeoff", "tradeoffs",
  ])
  let template_block = reader_named_markdown_block(artifact.markdown, [
      "output artifact", "template",
    ])
    .get(0)
    .unwrap_or("")
  let template_artifact = if template_block.is_empty() {
    match table_exercises.get(0) {
      Some(exercise) => exercise.expected_artifact
      None => ""
    }
  } else {
    template_block
  }
  Some(
    @reader_projection.ReaderApplyFrame::new(
      procedure_steps~,
      decision_points~,
      tradeoffs~,
      template_artifact~,
    ),
  )
}

///|
fn reader_contract_research_frame(
  artifact : ReaderArtifactContent,
) -> @reader_projection.ReaderResearchFrame? {
  if artifact.view != "research" {
    return None
  }
  let research_method = reader_named_markdown_block(artifact.markdown, [
      "method", "methods", "methodology", "research method",
    ])
    .get(0)
    .unwrap_or("")
  Some(
    @reader_projection.ReaderResearchFrame::new(
      research_method~,
      contradictions=reader_block_excerpts(artifact.markdown, [
        "contradictions", "conflicting evidence",
      ]),
      uncertainties=reader_block_excerpts(artifact.markdown, [
        "uncertainty", "uncertainties",
      ]),
      limitations=reader_block_excerpts(artifact.markdown, [
        "limitations", "sources and limitations", "sources / limitations",
      ]),
      review_lineage=reader_block_excerpts(artifact.markdown, ["review lineage"]),
    ),
  )
}

///|
fn reader_block_excerpts(
  markdown : String,
  names : Array[String],
) -> Array[String] {
  reader_named_markdown_block(markdown, names).map(block => {
    markdown_excerpt(block, 360)
  })
}

///|
fn reader_revisit_days(markdown : String) -> Int {
  match
    reader_first_labeled_value(markdown, [
      "Revisit after days:", "Revisit in days:",
    ]) {
    Some(value) => reader_decimal_int(value)
    None => 0
  }
}

///|
fn reader_decimal_int(value : String) -> Int {
  let mut parsed = 0
  let mut seen = false
  for ch in value {
    if ch >= '0' && ch <= '9' {
      parsed = parsed * 10 + (ch.to_int() - '0'.to_int())
      seen = true
    } else if seen {
      break
    }
  }
  if seen {
    parsed
  } else {
    0
  }
}

///|
fn reader_named_markdown_block(
  markdown : String,
  names : Array[String],
) -> Array[String] {
  let blocks : Array[String] = []
  let body : Array[String] = []
  let mut capture_depth = 0
  for raw in markdown.split("\n") {
    let line = raw.trim().to_owned()
    let depth = reader_markdown_heading_depth(line)
    if depth > 0 {
      if capture_depth > 0 && depth <= capture_depth {
        let block = body.join("\n").trim().to_owned()
        if !block.is_empty() {
          blocks.push(block)
        }
        body.clear()
        capture_depth = 0
      }
      let heading = line[depth:].trim().to_lower().to_owned()
      if names.contains(heading) {
        body.clear()
        capture_depth = depth
      } else if capture_depth > 0 {
        body.push(raw.to_owned())
      }
    } else if capture_depth > 0 {
      body.push(raw.to_owned())
    }
  }
  if capture_depth > 0 {
    let block = body.join("\n").trim().to_owned()
    if !block.is_empty() {
      blocks.push(block)
    }
  }
  blocks
}

///|
fn reader_numbered_item(line : String) -> String? {
  match line.find(". ") {
    Some(index) if index > 0 => {
      let prefix = line[:index]
      if prefix.all(fn(ch) { ch >= '0' && ch <= '9' }) {
        Some(line[index + 2:].trim().to_owned())
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn reader_concealed_answers(markdown : String) -> Array[String] {
  let answers : Array[String] = []
  let prefix = "<details><summary>reveal answer</summary>"
  let mut current : Array[String]? = None
  for raw in markdown.split("\n") {
    let line = raw.trim().to_owned()
    if line.to_lower().has_prefix(prefix) {
      let first = line[prefix.length():]
        .replace(old="</details>", new="")
        .to_owned()
        .trim()
        .to_owned()
      current = Some(if first.is_empty() { [] } else { [first] })
      if line.to_lower().has_suffix("</details>") {
        answers.push(first)
        current = None
      }
    } else {
      match current {
        Some(parts) => {
          let closed = line.to_lower().has_suffix("</details>")
          let part = line
            .replace(old="</details>", new="")
            .to_string()
            .trim()
            .to_owned()
          if !part.is_empty() {
            parts.push(part)
          }
          if closed {
            answers.push(parts.join(" "))
            current = None
          }
        }
        None => ()
      }
    }
  }
  answers
}

///|
fn reader_first_labeled_value(
  markdown : String,
  labels : Array[String],
) -> String? {
  reader_labeled_values(markdown, labels).get(0)
}

///|
fn reader_labeled_values(
  markdown : String,
  labels : Array[String],
) -> Array[String] {
  let values : Array[String] = []
  for raw in markdown.split("\n") {
    let line = strip_inline_markup(raw.trim().to_owned()).trim().to_owned()
    let lower = line.to_lower()
    for label in labels {
      if lower.has_prefix(label.to_lower()) {
        let value = line[label.length():].trim().to_owned()
        if !value.is_empty() {
          values.push(value)
        }
      }
    }
  }
  values
}

///|
fn reader_array_value(values : Array[String], index : Int) -> String {
  values.get(index).unwrap_or("")
}
