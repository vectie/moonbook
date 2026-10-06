///|
fn lesson_nullable_reference(
  reference : @bookkeeper.VersionedRecordReference?,
) -> Json {
  reference.map(value => value.to_json()).unwrap_or(Json::null())
}

///|
fn[T : @json.FromJson] lesson_version_field(
  fields : Map[String, Json],
  key : String,
  path : @json.JsonPath,
) -> T raise @json.JsonDecodeError {
  guard fields.get(key) is Some(value) else {
    raise @json.JsonDecodeError((path, "missing version-choice field: " + key))
  }
  @json.from_json(value, path~)
}

///|
fn lesson_version_head(
  fields : Map[String, Json],
  path : @json.JsonPath,
) -> @bookkeeper.VersionedRecordReference? raise @json.JsonDecodeError {
  match fields.get("expected_head") {
    Some(Null) => None
    Some(value) if value is Object(_) => Some(@json.from_json(value, path~))
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected_head requires an exact reference object or null"),
      )
  }
}

///|
pub impl ToJson for OutcomeLessonRevision with fn to_json(self) {
  {
    "contract_version": self.contract_version,
    "lesson": self.lesson.to_json(),
    "supersedes": self.supersedes.to_json(),
    "expected_head": lesson_nullable_reference(self.expected_head),
    "accepted_reviews": self.accepted_reviews.to_json(),
    "reason": self.reason,
  }
}

///|
pub impl @json.FromJson for OutcomeLessonRevision with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "expected lesson revision object"))
  }
  {
    contract_version: lesson_version_field(fields, "contract_version", path),
    lesson: lesson_version_field(fields, "lesson", path),
    supersedes: lesson_version_field(fields, "supersedes", path),
    expected_head: lesson_version_head(fields, path),
    accepted_reviews: lesson_version_field(fields, "accepted_reviews", path),
    reason: lesson_version_field(fields, "reason", path),
  }
}

///|
pub impl ToJson for OutcomeLessonSelection with fn to_json(self) {
  {
    "contract_version": self.contract_version,
    "selection_id": self.selection_id,
    "lesson_id": self.lesson_id,
    "target": self.target.to_json(),
    "expected_head": lesson_nullable_reference(self.expected_head),
    "accepted_reviews": self.accepted_reviews.to_json(),
    "reason": self.reason,
    "recorded_at": self.recorded_at,
  }
}

///|
pub impl @json.FromJson for OutcomeLessonSelection with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "expected lesson selection object"))
  }
  {
    contract_version: lesson_version_field(fields, "contract_version", path),
    selection_id: lesson_version_field(fields, "selection_id", path),
    lesson_id: lesson_version_field(fields, "lesson_id", path),
    target: lesson_version_field(fields, "target", path),
    expected_head: lesson_version_head(fields, path),
    accepted_reviews: lesson_version_field(fields, "accepted_reviews", path),
    reason: lesson_version_field(fields, "reason", path),
    recorded_at: lesson_version_field(fields, "recorded_at", path),
  }
}
