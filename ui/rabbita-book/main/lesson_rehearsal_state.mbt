///|
/// This production preview runs literal checks on supplied text only. The Book
/// host independently recomputes them before immutable journal admission.
extern "js" fn lesson_rehearsal_preview_json(text : String) -> String =
  #| text => {
  #|   try {
  #|     const value = JSON.parse(text), strings = [value.example_input, value.baseline_output, value.corrected_output], required = value.required_text;
  #|     if (value.contract_version !== 'moonbook.outcome-lesson-rehearsal.v1' || strings.some(s => typeof s !== 'string' || !s.trim()) || !Array.isArray(required) || required.length < 1 || required.length > 20) throw Error('Rehearsal needs one example, two supplied outputs, and 1 to 20 literal checks');
  #|     if (strings.some(s => s.length > 16384)) throw Error('Rehearsal text exceeds 16384 characters; no content was truncated');
  #|     if (required.some(s => typeof s !== 'string' || !s.trim() || s.length > 512) || new Set(required).size !== required.length) throw Error('Literal checks must be non-blank, unique, and at most 512 characters');
  #|     const checks = required.map(text => ({text, baseline_passed: value.baseline_output.includes(text), corrected_passed: value.corrected_output.includes(text)}));
  #|     const before = checks.filter(c => c.baseline_passed).length, after = checks.filter(c => c.corrected_passed).length;
  #|     return JSON.stringify({contract_version:'moonbook.outcome-lesson-rehearsal-result.v1', evaluation_kind:'operator_supplied_literal_rehearsal', checks, baseline_passed:before, corrected_passed:after, total:checks.length, improved:after === checks.length && before < after, model_executed:false, activation_authorized:false});
  #|   } catch (error) { return JSON.stringify({error:String(error.message || error)}); }
  #| }

///|
fn lesson_rehearsal_request(
  state : OutcomeLessonWorkspace,
) -> Result[Json, String] {
  let lesson = match lesson_ui_payload(state, "prepare") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let checks = lesson_field(state, "rehearsal-checks")
    .split("\n")
    .map(line => line.trim().to_owned())
    .filter(line => !line.is_empty())
    .to_array()
  Ok({
    "contract_version": "moonbook.outcome-lesson-rehearsal.v1",
    "lesson": lesson,
    "example_input": lesson_field(state, "rehearsal-input"),
    "baseline_output": lesson_field(state, "rehearsal-baseline"),
    "corrected_output": lesson_field(state, "rehearsal-corrected"),
    "required_text": checks.to_json(),
  })
}

///|
fn lesson_rehearsal_try(
  state : OutcomeLessonWorkspace,
) -> OutcomeLessonWorkspace {
  if state.pending {
    return state
  }
  let request = match lesson_rehearsal_request(state) {
    Ok(value) => value
    Err(error) =>
      return {
        ..state,
        notice: error,
        rehearsal_request: None,
        rehearsal_result: None,
      }
  }
  let result = @json.parse(lesson_rehearsal_preview_json(request.stringify())) catch {
    _ =>
      return {
        ..state,
        notice: "Rehearsal preview could not be read.",
        rehearsal_request: None,
        rehearsal_result: None,
      }
  }
  if result is { "error": String(error), .. } {
    return {
      ..state,
      notice: error,
      rehearsal_request: None,
      rehearsal_result: None,
    }
  }
  {
    ..state,
    rehearsal_request: Some(request),
    rehearsal_result: Some(result),
    notice: "Rehearsal compared supplied outputs on literal checks. No model was run. Inspect each check before saving for human review.",
  }
}

///|
fn lesson_rehearsal_save_payload(
  state : OutcomeLessonWorkspace,
) -> Result[Json, String] {
  let current = match lesson_rehearsal_request(state) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if state.rehearsal_request != Some(current) ||
    !(state.rehearsal_result
    is Some(
      {
        "improved": true,
        "model_executed": false,
        "activation_authorized": false,
        ..
      }
    )) {
    return Err(
      "Run the same-example rehearsal for this exact draft first. Every corrected-output check must pass and at least one baseline check must fail.",
    )
  }
  Ok(current)
}

///|
fn lesson_rehearsal_has_inputs(state : OutcomeLessonWorkspace) -> Bool {
  [
    "rehearsal-input", "rehearsal-baseline", "rehearsal-corrected", "rehearsal-checks",
  ].any(key => !lesson_field(state, key).is_empty())
}

///|
fn lesson_rehearsal_clear(
  state : OutcomeLessonWorkspace,
) -> OutcomeLessonWorkspace {
  if state.pending {
    return state
  }
  let fields = state.fields.copy()
  for
    key in [
      "rehearsal-input", "rehearsal-baseline", "rehearsal-corrected", "rehearsal-checks",
    ] {
    fields[key] = ""
  }
  {
    ..state,
    fields,
    rehearsal_request: None,
    rehearsal_result: None,
    notice: "Rehearsal cleared. Your lesson guidance and scope are unchanged.",
  }
}
