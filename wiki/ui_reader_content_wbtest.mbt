///|
fn reader_course_fixture() -> String {
  "# Practical Robotics: Beginner Course\n\n" +
  "Audience: a product designer new to robotics\n\n" +
  "Prerequisites: no robotics experience; basic product vocabulary\n\n" +
  "This course explains how a robot turns a goal into a safe physical action.\n\n" +
  "## Lesson 1: Sense Before Moving\n\n" +
  "### Objective\n\nName the observations required before motion.\n\n" +
  "### Plain explanation\n\nA robot should inspect its surroundings before choosing a path.\n\n" +
  "### Worked example\n\nA warehouse robot needs to reach shelf B.\n\n" +
  "1. Read the aisle map.\n2. Detect a stopped cart.\n3. Choose the clear route.\n\n" +
  "Takeaway: sensing changes which action is safe.\n\n" +
  "### Exercise\n\nLabel the obstacles in a simple aisle sketch.\n\n" +
  "### Output artifact\n\n`aisle-obstacles.json`\n\n" +
  "### Self-explanation\n\nWhy must sensing happen before planning?\n\n" +
  "### Retrieval checkpoint\n\nName the three observations without looking back.\n\n" +
  "<details><summary>Reveal answer</summary>Map, obstacle, and destination.\nThe answer stays hidden until requested.</details>\n\n" +
  "### Transfer task\n\nApply the same sequence to a delivery robot outdoors.\n\n" +
  "### Common mistake\n\nTreating the map as proof that the aisle is still clear.\n\n" +
  "### Revisit\n\nRepeat the checkpoint after one week.\n\n" +
  "Revisit after days: 7\n"
}

///|
test "practice projection keeps heading-form exercise bodies and learning loop" {
  let practice = practice_markdown_from_course(
    "Practical Robotics",
    reader_course_fixture(),
  )
  assert_true(practice.contains("## Lesson 1: Sense Before Moving"))
  assert_true(practice.contains("### Exercise"))
  assert_true(practice.contains("Label the obstacles"))
  assert_true(practice.contains("### Output artifact"))
  assert_true(practice.contains("aisle-obstacles.json"))
  assert_true(practice.contains("### Self-explanation"))
  assert_true(practice.contains("Why must sensing happen before planning?"))
  assert_true(practice.contains("### Retrieval checkpoint"))
  assert_true(practice.contains("Name the three observations"))
  assert_true(practice.contains("<details><summary>Reveal answer</summary>"))
  assert_true(practice.contains("The answer stays hidden until requested."))
  assert_true(practice.contains("### Transfer task"))
  assert_true(practice.contains("delivery robot outdoors"))
  assert_true(practice.contains("### Revisit"))
  assert_true(practice.contains("Revisit after days: 7"))
  assert_false(practice.contains("### Plain explanation"))
}

///|
test "reader markdown turns answer markup into a concealed disclosure" {
  let html = markdown_report_html(reader_course_fixture(), "reader-learn")
  assert_true(html.contains("<details class=\"reader-answer\">"))
  assert_true(html.contains("<summary>Reveal answer</summary>"))
  assert_true(html.contains("Map, obstacle, and destination."))
  assert_true(html.contains("<ol>"))
  assert_false(html.contains("&lt;details&gt;"))
  assert_true(
    html.contains("reader-section-heading reader-section-heading-checkpoint"),
  )
  assert_true(html.contains("id=\"reader-learn-sec-1\""))
  assert_true(
    report_toc_html(reader_course_fixture(), "reader-learn").contains(
      "href=\"#reader-learn-sec-1\"",
    ),
  )
}

///|
test "reader summary prefers an explicit main message and skips headings" {
  let labeled = "# Robot Safety\n\n**Audience:** a new robotics operator\n\n**Prerequisites:** none\n\n**Main message:** Observe the workspace before commanding motion.\n\n## Method\n\nCompare the planned path with live observations.\n"
  assert_eq(
    reader_artifact_summary(labeled),
    "Observe the workspace before commanding motion.",
  )
  let research = "# Robot Safety Research\n\n## Method\n\nCompare the planned path with live observations.\n"
  assert_eq(
    reader_artifact_summary(research),
    "Compare the planned path with live observations.",
  )
}

///|
test "exercise extraction stays inside each lesson" {
  let markdown = "# Practice\n\n## Lesson 1: Observe\n\n### Exercise\n\nMark the first obstacle.\n\n### Output artifact\n\nfirst.json\n\n### Retrieval checkpoint\n\nWhat must be observed first?\n\n<details><summary>Reveal answer</summary>The obstacle.</details>\n\n### Revisit\n\nRepeat the observation check.\n\nRevisit after days: 2\n\n## Lesson 2: Plan\n\n### Exercise\n\nChoose a safe route.\n\n### Output artifact\n\nroute.json\n\n### Retrieval checkpoint\n\nWhat makes a route safe?\n\n<details><summary>Reveal answer</summary>It avoids the obstacle.</details>\n\n### Self-explanation\n\nExplain why the route changed.\n\n### Transfer task\n\nPlan around a moving obstacle.\n\n### Revisit\n\nRe-plan without notes.\n\nRevisit after days: 7\n"
  let artifact = reader_artifact_content(
    "apply", "Apply", "wiki/course/exercises.md", markdown, "Try the first exercise",
  )
  let exercises = reader_contract_exercises(artifact, ["source"])
  assert_eq(exercises.length(), 2)
  assert_eq(exercises[0].expected_artifact, "first.json")
  assert_eq(exercises[0].self_explanation_prompt, "")
  assert_eq(exercises[0].transfer_task, "")
  assert_eq(exercises[0].revisit_after_days, 2)
  assert_eq(exercises[1].expected_artifact, "route.json")
  assert_true(exercises[1].self_explanation_prompt.contains("route changed"))
  assert_true(exercises[1].transfer_task.contains("moving obstacle"))
  assert_eq(exercises[1].revisit_after_days, 7)
}

///|
test "only an exercise schema turns a Markdown table into practice" {
  let unrelated = "| Model | Cost | Notes |\n| --- | --- | --- |\n| A | 10 | fast |\n"
  assert_true(reader_contract_table_exercises(unrelated, ["source"]).is_empty())
  let recognized = "| Task | Output Artifact | Acceptance Criteria |\n| --- | --- | --- |\n| Compare routes | route.md | names the safer route |\n"
  let exercises = reader_contract_table_exercises(recognized, ["source"])
  assert_eq(exercises.length(), 1)
  assert_eq(exercises[0].prompt, "Compare routes")
  assert_eq(exercises[0].expected_artifact, "route.md")
}

///|
test "reader heading ids are isolated by view" {
  let markdown = "# One\n\n## Two\n\nBody.\n"
  let learn = markdown_report_html(markdown, "reader-learn")
  let apply = markdown_report_html(markdown, "reader-apply")
  let research = markdown_report_html(markdown, "reader-research")
  assert_true(learn.contains("id=\"reader-learn-sec-1\""))
  assert_true(apply.contains("id=\"reader-apply-sec-1\""))
  assert_true(research.contains("id=\"reader-research-sec-1\""))
  assert_false((learn + apply + research).contains("id=\"report-sec-1\""))
}

///|
fn complete_reader_fixture() -> String {
  "# Safe Robot Motion\n\n" +
  "Audience: a warehouse operator learning robot supervision\n\n" +
  "Prerequisites: no robotics experience is required\n\n" +
  "Main message: Observe current conditions before selecting a motion.\n\n" +
  "## Learning outcome\n\nExplain and apply an observe-plan-check loop.\n\n" +
  "## Glossary\n\n- Observation: a current measurement of the workspace.\n\n" +
  "## Worked example\n\nA robot finds a cart in its planned aisle.\n\n" +
  "1. Observe the cart.\n2. Plan a clear route.\n3. Check the route before motion.\n\n" +
  "Takeaway: current evidence can invalidate an old plan.\n\n" +
  "## Lesson 1: Observe and plan\n\n" +
  "### Plain explanation\n\nUse live observations instead of assuming the map is current.\n\n" +
  "### Exercise\n\nChoose a route around the recorded obstacle.\n\n" +
  "### Output artifact\n\nroute-decision.md\n\n" +
  "### Retrieval checkpoint\n\nWhat happens before motion planning?\n\n" +
  "<details><summary>Reveal answer</summary>Observe the current workspace.</details>\n\n" +
  "### Self-explanation\n\nExplain why an old map is not enough.\n\n" +
  "### Transfer task\n\nApply the loop to an outdoor delivery robot.\n\n" +
  "### Revisit\n\nRecreate the loop without notes.\n\nRevisit after days: 3\n"
}

///|
fn reader_review_test_ref(id : String) -> @bookkeeper.VersionedRecordReference {
  let payload : Json = {
    "contract_version": @bookkeeper_store.bookkeeper_store_contract_version(),
    "fixture_id": id,
  }
  {
    record_id: id,
    record_version: "1",
    record_digest: @bookkeeper_store.bookkeeper_payload_digest(payload),
  }
}

///|
async fn accept_reader_candidate(
  root : String,
  candidate : @bookkeeper_store.DurableBookkeeperRecord,
  id : String,
  grant : @bookkeeper.VersionedRecordReference,
  authority_evidence_id : String,
) -> Unit {
  let result = @bookkeeper_store.apply_governed_review(root, {
    contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
    mutation: reader_review_test_ref("reader-mutation-\{id}"),
    receipt: reader_review_test_ref("reader-receipt-\{id}"),
    stage: DeliverableAcceptance,
    subject: candidate.record,
    requested: Accept,
    reviewer_kind: Human,
    reviewer: {
      grant,
      reviewer_id: "reader-reviewer",
      authority_ref: "authority://reader-reviewer",
      authorized: true,
      evidence_refs: [authority_evidence_id],
    },
    evidence_refs: candidate.evidence_refs,
    summary: "Accept the exact reader artifact.",
    decided_at: 2,
  })
  assert_true(result.accepted)
}

///|
async test "exact Bookkeeper receipts close the reader publication loop" {
  let root = "/tmp/moonbook-reader-review-\{@async.now().to_int()}"
  let markdown = complete_reader_fixture()
  let learn = reader_artifact_content(
    "learn", "Learn", "wiki/course/beginner-course.md", markdown, "Start the lesson",
  )
  let apply = reader_artifact_content(
    "apply", "Apply", "wiki/course/exercises.md", markdown, "Try the exercise",
  )
  let research = reader_artifact_content(
    "research", "Research", "wiki/synthesis/report.md", markdown, "Trace the evidence",
  )
  let bundle : ReaderArtifactBundle = {
    identity: reader_canonical_book_identity(root, learn, apply, research),
    learn,
    apply,
    research,
  }
  let before = ui_reader_projections(root, bundle)
  assert_eq(before.learn.source_review_status(), PendingReview)
  assert_eq(before.learn.projection_review_status(), PendingReview)
  assert_eq(
    before.canonical_candidate.record.record_digest,
    @bookkeeper_store.bookkeeper_payload_digest(
      before.canonical_candidate.payload,
    ),
  )
  assert_eq(
    before.learn_candidate.record.record_digest,
    @bookkeeper_store.bookkeeper_payload_digest(before.learn_candidate.payload),
  )
  assert_eq(before.learn.canonical_subject_id(), bundle.identity.subject_id)
  assert_eq(before.learn.source_revision, before.apply.source_revision)
  assert_eq(before.learn.source_digest, before.research.source_digest)
  assert_true(
    before.learn.source_refs[0].digest != before.apply.source_refs[0].digest ||
    before.learn.source_refs[0].reference_id !=
    before.apply.source_refs[0].reference_id,
  )
  assert_true(
    @bookkeeper_store.persist_bookkeeper_record(
      root,
      before.canonical_candidate,
    ).accepted,
  )
  assert_true(
    @bookkeeper_store.persist_bookkeeper_record(root, before.learn_candidate).accepted,
  )
  let grant = reader_review_test_ref("reader-human-grant")
  let authority_evidence_id = before.learn_candidate.evidence_refs[0].reference_id
  ignore(
    @bookkeeper_store.install_bookkeeper_authority_grant(root, {
      contract_version: @bookkeeper_store.bookkeeper_store_contract_version(),
      grant,
      reviewer_id: "reader-reviewer",
      reviewer_kind: Human,
      authority_ref: "authority://reader-reviewer",
      evidence_refs: [authority_evidence_id],
      active: true,
      granted_at: 1,
    }),
  )
  accept_reader_candidate(
    root,
    before.canonical_candidate,
    "canonical",
    grant,
    authority_evidence_id,
  )
  accept_reader_candidate(
    root,
    before.learn_candidate,
    "learn",
    grant,
    authority_evidence_id,
  )
  let after = ui_reader_projections(root, bundle)
  assert_eq(after.learn.source_review_status(), Accepted)
  assert_eq(after.learn.projection_review_status(), Accepted)
  assert_true(after.learn.readiness().publishable)
}

///|
async test "generated reader uses real artifacts and emits typed draft state" {
  let root = "/tmp/moonbook-reader-artifact-projection"
  ignore(init_workspace(root))
  let course_dir = moonbook_wiki_path(root)
    .join(moonbook_wiki_path("wiki/course"))
    .to_string()
  @fsx.make_directory(course_dir, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    moonbook_wiki_path(course_dir)
    .join(moonbook_wiki_path("beginner-course.md"))
    .to_string(),
    reader_course_fixture(),
    create=0o644,
  )
  @fsx.write_to_file(
    moonbook_wiki_path(course_dir)
    .join(moonbook_wiki_path("exercises.md"))
    .to_string(),
    "# Robotics Exercises\n\n| Exercise | Artifact | Pass Condition |\n| --- | --- | --- |\n| Label one aisle | aisle map | obstacles are separated |\n",
    create=0o644,
  )
  @fsx.write_to_file(
    moonbook_wiki_path(root)
    .join(moonbook_wiki_path("raw/bootstrap/deep-report.md"))
    .to_string(),
    "# Robotics Research\n\n## Method\n\nCompare navigation policies against recorded obstacle observations.\n\n## Limitations\n\nThe fixture does not represent outdoor weather.\n",
    create=0o644,
  )
  let site_root = moonbook_wiki_path(root)
    .join(moonbook_wiki_path("book/site"))
    .to_string()
  ignore(write_marketing_projection(root, site_root))
  let generated = moonbook_wiki_path(site_root)
    .join(moonbook_wiki_path("generated"))
    .to_string()
  let html = @fsx.read_file(
    moonbook_wiki_path(generated)
    .join(moonbook_wiki_path("course.html"))
    .to_string(),
  )
  let reader_state = @fsx.read_file(
    moonbook_wiki_path(generated)
    .join(moonbook_wiki_path("reader-state.json"))
    .to_string(),
  )
  assert_true(html.contains("Practical Robotics: Beginner Course"))
  assert_true(html.contains("Robotics Exercises"))
  assert_true(html.contains("Robotics Research"))
  assert_true(html.contains("data-reader-choice=\"learn\""))
  assert_true(html.contains("How this book is maintained"))
  assert_true(html.contains("Draft"))
  assert_false(html.contains("Meet the operating stages"))
  assert_false(html.contains("Coverage readiness"))
  assert_true(reader_state.contains("moonbook.reader_projection.v1"))
  assert_true(reader_state.contains("wiki/course/beginner-course.md"))
  assert_true(reader_state.contains("sha256:"))
  assert_true(reader_state.to_lower().contains("draft"))
}
