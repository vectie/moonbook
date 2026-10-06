///|
// Absence means no proposed capability change, never a placeholder identity.
// Validate here as well as in FromJson because native callers construct records.
fn validate_outcome_capability(
  id : String?,
  version : String?,
  digest : String?,
  summary : String?,
  information : ProductOutcomeGapStatement,
  recognition : ProductOutcomeGapStatement,
  decisiveness : ProductOutcomeGapStatement,
) -> Unit raise {
  match (id, version, digest, summary) {
    (Some(id), Some(version), Some(digest), Some(summary)) =>
      if id.is_blank() ||
        version.is_blank() ||
        !product_outcome_digest_valid(digest) ||
        summary.is_blank() {
        fail("The supplied capability descriptor must be complete and nonblank")
      }
    (None, None, None, None) =>
      if ![information, recognition, decisiveness].all(gap => {
          !gap.present && gap.severity == 0
        }) {
        fail(
          "Capability metadata may be omitted only when all three gaps are explicitly absent with severity zero",
        )
      }
    _ =>
      fail(
        "Supply all four capability descriptor fields together, or omit all four for an explicitly no-gap outcome",
      )
  }
}

///|
fn outcome_capability_json(value : String?) -> Json {
  match value {
    Some(text) => Json::string(text)
    None => Json::null()
  }
}

///|
// The complete object is constructed in legacy field order before absent keys
// are removed. Each Some value remains a plain string, not Option's array wire.
fn outcome_omit_absent_capability(
  value : Json,
  id : String?,
  version : String?,
  digest : String?,
  summary : String?,
) -> Json {
  if value is Object(fields) {
    for
      (key, field) in [
        ("capability_id", id),
        ("capability_version", version),
        ("capability_change_digest", digest),
        ("capability_summary", summary),
      ] {
      if field is None {
        ignore(fields.remove(key))
      }
    }
  }
  value
}

///|
fn[T : @json.FromJson] outcome_json_required(
  fields : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> T raise @json.JsonDecodeError {
  guard fields.get(key) is Some(value) else {
    raise @json.JsonDecodeError((path, "Missing outcome field " + key))
  }
  @json.from_json(value, path~)
}

///|
fn outcome_json_capability(
  fields : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> String? raise @json.JsonDecodeError {
  match fields.get(key) {
    None => None
    Some(String(value)) => Some(value)
    _ =>
      raise @json.JsonDecodeError(
        (
          path,
          "Outcome field " +
          key +
          " must be a string when supplied; null is not omission",
        ),
      )
  }
}
