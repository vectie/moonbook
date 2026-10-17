///|
priv struct LessonEvolutionCase {
  name : String
  input : String
  output : String
  required : Array[String]
  forbidden : Array[String]
} derive(ToJson)

///|
priv struct LessonEvolutionLine {
  kind : String
  text : String
} derive(Debug, Eq, ToJson)

///|
/// Exact line comparison, with a bounded fallback that preserves all text.
fn lesson_evolution_lines(
  before : String,
  after : String,
) -> Array[LessonEvolutionLine] {
  if before == after {
    return [{ kind: "unchanged", text: before, }]
  }
  let a = before.split("\n").map(s => s.to_owned()).collect()
  let b = after.split("\n").map(s => s.to_owned()).collect()
  if a.length() > 256 || b.length() > 256 {
    return [
      { kind: "removed block", text: before, },
      { kind: "added block", text: after, },
    ]
  }
  let table = Array::makei(a.length() + 1, _ => Array::make(b.length() + 1, 0))
  for i = a.length() - 1; i >= 0; i = i - 1 {
    for j = b.length() - 1; j >= 0; j = j - 1 {
      table[i][j] = if a[i] == b[j] {
        table[i + 1][j + 1] + 1
      } else {
        Int::max(table[i + 1][j], table[i][j + 1])
      }
    }
  }
  let lines = []
  for i = 0, j = 0; i < a.length() || j < b.length(); {
    if i < a.length() && j < b.length() && a[i] == b[j] {
      lines.push({ kind: "unchanged", text: a[i], })
      continue i + 1, j + 1
    }
    if i < a.length() && (j == b.length() || table[i + 1][j] >= table[i][j + 1]) {
      lines.push({ kind: "removed", text: a[i], })
      continue i + 1, j
    }
    lines.push({ kind: "added", text: b[j], })
    continue i, j + 1
  }
  lines
}

///|
fn lesson_evolution_array(value : Json) -> Array[Json] {
  match value {
    Array(values) => values
    _ => []
  }
}

///|
fn lesson_evolution_conditions(value : Json) -> Result[Json, String] {
  guard value is Array(items) else {
    return Err("A lesson's conditions are unreadable.")
  }
  let clean : Array[Json] = []
  for item in items {
    guard item is { "key": String(key), "value": String(value), .. } else {
      return Err("A lesson's condition is unreadable.")
    }
    clean.push({ "key": key, "value": value })
  }
  Ok(clean.to_json())
}

///|
fn lesson_evolution_reference(value : Json) -> Result[Json, String] {
  let reference : BookkeeperRecordReference = @json.from_json(value) catch {
    _ =>
      return Err("An original outcome or assessment reference is unreadable.")
  }
  if reference.record_id.is_blank() ||
    reference.record_version.is_blank() ||
    reference.record_digest.is_blank() {
    return Err("An original outcome or assessment reference is incomplete.")
  }
  Ok(ToJson::to_json(reference))
}

///|
/// Read only supported recorded observations. No output is executed or scored.
fn lesson_evolution_cases(
  record : BookkeeperRawRecord,
) -> Result[Array[LessonEvolutionCase], String] {
  let payload = record.payload
  let lesson = lesson_task_field(payload, "outcome_lesson")
  let schema = lesson_task_text(payload, "candidate_schema")
  if schema == "outcome_lesson.rehearsed.v1" {
    let rehearsal = lesson_task_field(payload, "rehearsal")
    guard rehearsal
      is {
        "contract_version": "moonbook.outcome-lesson-rehearsal.v1",
        "example_input": String(input),
        "corrected_output": String(output),
        "required_text": required,
        ..
      } else {
      return Err("The saved single-example report cannot be read.")
    }
    if lesson_task_field(rehearsal, "lesson") != lesson {
      return Err("The saved example describes a different lesson payload.")
    }
    let checks : Array[String] = @json.from_json(required) catch {
      _ => return Err("The saved single-example checks cannot be read.")
    }
    return Ok([
      {
        name: "Original teaching example",
        input,
        output,
        required: checks,
        forbidden: [],
      },
    ])
  }
  if schema != "outcome_lesson.v2" {
    return Ok([])
  }
  let reason = lesson_task_text(
    lesson_task_field(payload, "revision"),
    "reason",
  )
  let marker = "Operator-reported contrasting-case rehearsal. Supplied outputs and case labels are unverified; literal matches do not demonstrate generalization or a model run. Named-human review is still required.\n"
  if !reason.has_prefix(marker) {
    return Ok([])
  }
  let report = @json.parse(reason[marker.length():].to_owned()) catch {
    _ => return Err("The saved contrasting-case report cannot be read.")
  }
  guard report
    is {
      "evaluation_kind": "operator_supplied_literal_revision_rehearsal",
      "model_executed": false,
      "factual_review_complete": false,
      "activation_authorized": false,
      "cases": Array(cases),
      ..
    } else {
    return Err("The saved case report has an unsupported format.")
  }
  let revision = lesson_task_field(payload, "revision")
  if lesson_task_field(revision, "lesson") != lesson ||
    lesson_task_text(report, "revised_guidance") !=
    lesson_task_text(lesson, "guidance") ||
    lesson_task_field(report, "source_lesson") !=
    lesson_task_field(revision, "supersedes") {
    return Err(
      "The saved case report does not describe this exact revision and guidance.",
    )
  }
  if cases.length() < 2 || cases.length() > 6 {
    return Err("The saved report has an unsupported case count.")
  }
  let output : Array[LessonEvolutionCase] = []
  for case in cases {
    guard case
      is {
        "name": String(name),
        "input": String(input),
        "revised_output": String(result),
        "checks": Array(checks),
        ..
      } else {
      return Err("A saved case is unreadable.")
    }
    if output.any(c => c.input == input) {
      return Err("Saved case inputs repeat; matching would be ambiguous.")
    }
    let required = []
    let forbidden = []
    for check in checks {
      match check {
        { "kind": "required", "text": String(text), .. } => required.push(text)
        { "kind": "forbidden", "text": String(text), .. } =>
          forbidden.push(text)
        _ => return Err("A saved case check is unreadable.")
      }
    }
    output.push({ name, input, output: result, required, forbidden, })
  }
  Ok(output)
}

///|
fn lesson_evolution_rationale(record : BookkeeperRawRecord) -> String {
  let reason = lesson_task_text(
    lesson_task_field(record.payload, "revision"),
    "reason",
  )
  let marker = "Operator-reported contrasting-case rehearsal. Supplied outputs and case labels are unverified; literal matches do not demonstrate generalization or a model run. Named-human review is still required.\n"
  if !reason.has_prefix(marker) {
    return reason
  }
  let report = @json.parse(reason[marker.length():].to_owned()) catch {
    _ =>
      return "Stored rehearsal rationale is unreadable; inspect the original artifact."
  }
  lesson_task_text(report, "operator_rationale")
}

///|
fn lesson_evolution_capture(
  version : LessonHistoryVersion,
  current : BookkeeperRecordReference?,
) -> Result[Json, String] {
  guard lesson_record_value(version.lesson) is Some(lesson) else {
    return Err("This version is not a supported outcome lesson.")
  }
  let applicability = match
    lesson_evolution_conditions(lesson_task_field(lesson, "applicability")) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let invalidation = match
    lesson_evolution_conditions(lesson_task_field(lesson, "invalidation")) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let references : Map[String, Json] = Map([])
  for key in ["outcome", "assessment", "assessment_review"] {
    references[key] = match
      lesson_evolution_reference(lesson_task_field(lesson, key)) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
  }
  let completed = version.reviews.filter(r => {
    r.subject == version.lesson.record &&
    r.review_complete &&
    (r.disposition == "Accept" || r.disposition == "Reject")
  })
  let status = if lesson_history_accepted(version) {
    "accepted"
  } else if completed.length() > 1 {
    "ambiguous review history"
  } else if completed.length() == 1 && completed[0].disposition == "Reject" {
    "rejected"
  } else if completed.length() == 1 {
    "acceptance not established"
  } else {
    "pending or incomplete review"
  }
  let reviews = version.reviews.map(r => {
    (
      {
        "receipt": ToJson::to_json(r.receipt),
        "subject": ToJson::to_json(r.subject),
        "reviewer": r.reviewer.reviewer_id,
        "disposition": r.disposition,
        "complete": r.review_complete,
        "summary": r.summary,
      } : Json)
  })
  let (cases, cases_notice) = match lesson_evolution_cases(version.lesson) {
    Ok(cases) =>
      (
        cases,
        if cases.is_empty() {
          "No supported saved teaching cases in this version."
        } else {
          "Recorded operator-supplied observations. These are not fresh executions or a measure of generalized improvement."
        },
      )
    Err(error) => ([], error)
  }
  let revision = lesson_task_field(version.lesson.payload, "revision")
  let supersedes = match
    lesson_evolution_reference(lesson_task_field(revision, "supersedes")) {
    Ok(value) => value
    Err(_) => Json::null()
  }
  Ok({
    "reference": ToJson::to_json(version.lesson.record),
    "lesson_id": lesson_task_text(lesson, "lesson_id"),
    "title": version.lesson.title,
    "guidance": lesson_task_text(lesson, "guidance"),
    "applicability": applicability,
    "invalidation": invalidation,
    "source_references": Json::object(references),
    "review_status": status,
    "current_at_load": current == Some(version.lesson.record),
    "reviews": reviews.to_json(),
    "supersedes": supersedes,
    "author_rationale": lesson_evolution_rationale(version.lesson),
    "cases": cases.to_json(),
    "cases_notice": cases_notice,
  })
}

///|
fn lesson_evolution_set_delta(before : Json, after : Json) -> Json {
  let a = lesson_evolution_array(before)
  let b = lesson_evolution_array(after)
  {
    "removed": a.filter(v => !b.contains(v)).to_json(),
    "added": b.filter(v => !a.contains(v)).to_json(),
    "unchanged": a.filter(v => b.contains(v)).to_json(),
  }
}

///|
fn lesson_evolution_case_delta(before : Json, after : Json) -> Array[Json] {
  let a = lesson_evolution_array(before)
  let b = lesson_evolution_array(after)
  let rows : Array[Json] = []
  for item in a {
    let input = lesson_task_text(item, "input")
    let found = b.search_by(c => lesson_task_text(c, "input") == input)
    rows.push(
      match found {
        Some(index) =>
          {
            "kind": if item == b[index] {
              "unchanged"
            } else {
              "changed observation or checks"
            },
            "input": input,
            "before": item,
            "after": b[index],
          }
        None =>
          {
            "kind": "only in baseline",
            "input": input,
            "before": item,
            "after": Json::null(),
          }
      },
    )
  }
  for item in b {
    let input = lesson_task_text(item, "input")
    if !a.any(c => lesson_task_text(c, "input") == input) {
      rows.push({
        "kind": "only in target",
        "input": input,
        "before": Json::null(),
        "after": item,
      })
    }
  }
  rows
}

///|
fn lesson_evolution_report(
  history : LessonHistory,
  baseline : BookkeeperRecordReference,
  target : BookkeeperRecordReference,
) -> Result[Json, String] {
  if baseline == target {
    return Err("Choose two different saved versions to compare.")
  }
  let choose = fn(reference) {
    let versions = history.versions.filter(v => v.lesson.record == reference)
    if versions.length() != 1 {
      return Err(
        "The selected exact version is missing or ambiguous. Choose it again from refreshed history.",
      )
    }
    lesson_evolution_capture(versions[0], history.current)
  }
  let before = match choose(baseline) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let after = match choose(target) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if lesson_task_text(before, "lesson_id") != history.lesson_id ||
    lesson_task_text(after, "lesson_id") != history.lesson_id {
    return Err("Both versions must belong to this exact lesson family.")
  }
  let report : Json = {
    "schema": "moonbook.lesson-evolution-comparison.v1",
    "lesson_id": history.lesson_id,
    "baseline": before,
    "target": after,
    "relationship": if lesson_task_field(after, "supersedes") ==
      ToJson::to_json(baseline) {
      "Target records baseline as its explicit predecessor."
    } else {
      "Reader-selected comparison; no direct predecessor relationship is asserted. Version names are not chronological ordering."
    },
    "guidance_lines": lesson_evolution_lines(
      lesson_task_text(before, "guidance"),
      lesson_task_text(after, "guidance"),
    ).to_json(),
    "required_conditions": lesson_evolution_set_delta(
      lesson_task_field(before, "applicability"),
      lesson_task_field(after, "applicability"),
    ),
    "invalidation_conditions": lesson_evolution_set_delta(
      lesson_task_field(before, "invalidation"),
      lesson_task_field(after, "invalidation"),
    ),
    "teaching_cases": lesson_evolution_case_delta(
      lesson_task_field(before, "cases"),
      lesson_task_field(after, "cases"),
    ).to_json(),
    "model_executed": false,
    "activation_authorized": false,
    "interpretation": "A read-only comparison of captured records. Text changes, named review and operator-reported examples do not by themselves demonstrate improvement, factual truth, customer outcome or new authority. Current labels apply only to the loaded history.",
  }
  if !lesson_notebook_fits(report.stringify(indent=2)) {
    return Err(
      "This comparison exceeds the 1 MiB output limit. Original records remain available in history; nothing was truncated.",
    )
  }
  Ok(report)
}
