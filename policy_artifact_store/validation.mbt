///|
fn string_field(value : Json, key : String) -> String raise {
  guard value is Object(object) &&
    object.get(key) is Some(String(text)) &&
    !text.trim().is_empty() else {
    fail("missing nonempty field: " + key)
  }
  text
}

///|
fn field(value : Json, key : String) -> Json raise {
  guard value is Object(object) && object.get(key) is Some(item) else {
    fail("missing field: " + key)
  }
  item
}

///|
fn validate_batch(
  batch : ArtifactBatch,
  journal : ArtifactJournal,
) -> Unit raise {
  guard batch.contract_id == "moonbook.policy-artifact-batch.v1" &&
    batch.execution_mode == "deterministic-local-fixture.v1" &&
    !batch.batch_id.is_empty() &&
    !batch.book_id.is_empty() &&
    !batch.case_id.is_empty() &&
    batch.expected_book_version == journal.version.to_string() &&
    (
      journal.version == 0 ||
      (batch.book_id == journal.book_id && batch.case_id == journal.case_id)
    ) else {
    fail("batch contract, scope, or expected version mismatch")
  }
  guard batch.requests.length() > 0 &&
    batch.requests.length() <= 8 &&
    batch.payloads.length() == batch.requests.length() else {
    fail("partial or oversized artifact batch")
  }
  let expected_kinds = match batch.context {
    {
      "contract_id": "moonpoly.editor-quality-run-request.v1",
      "execution_mode": "deterministic-local-fixture.v1",
      ..
    } => ["DraftVersion"]
    {
      "contract_id": "moonpoly.policy-quality-transition-request.v2",
      "event_type": "writer-completed",
      ..
    } => ["DraftVersion", "ClaimTrace"]
    {
      "contract_id": "moonpoly.policy-quality-transition-request.v2",
      "event_type": "review-completed",
      ..
    } => ["ReviewResult"]
    {
      "contract_id": "moonpoly.policy-quality-transition-request.v2",
      "event_type": "rewrite-completed",
      ..
    } => ["DraftVersion", "RewriteReceipt"]
    _ => fail("unsupported local-fixture batch context")
  }
  let kinds = batch.requests.map(request => {
    string_field(field(request, "artifact"), "kind")
  })
  guard kinds.length() == expected_kinds.length() &&
    expected_kinds.all(kind => kinds.filter(item => item == kind).length() == 1) else {
    fail("partial or wrong-role artifact set")
  }
  guard !journal.batches.any(item => item.batch.batch_id == batch.batch_id) else {
    fail("replayed batch refused; inspect the acknowledged journal to resume")
  }
  let operations : Array[String] = []
  let records : Array[String] = []
  for request in batch.requests {
    let artifact = field(request, "artifact")
    let envelope = field(artifact, "envelope")
    let id = string_field(envelope, "id")
    let operation = string_field(request, "operation_id")
    let key = string_field(request, "idempotency_key")
    guard string_field(request, "contract_id") ==
      "moonpoly.moonbook-append-request.v1" &&
      string_field(request, "book_id") == batch.book_id &&
      string_field(request, "case_id") == batch.case_id &&
      string_field(request, "expected_book_version") ==
      batch.expected_book_version &&
      string_field(request, "gate_receipt_id") ==
      "local-fixture:workspace-write" &&
      string_field(envelope, "case_id") == batch.case_id &&
      string_field(envelope, "authority") == "Advisory" &&
      string_field(envelope, "standing") == "Proposed" &&
      ["HumanRecorded", "LocalFixtureProduced"].contains(
        string_field(envelope, "origin"),
      ) &&
      [
        "DraftVersion", "ClaimTrace", "ReviewResult", "RewriteReceipt", "AnalysisVersion",
      ].contains(string_field(artifact, "kind")) else {
      fail("artifact is outside the explicit advisory local-fixture scope")
    }
    ignore(string_field(envelope, "version"))
    ignore(string_field(request, "requested_at"))
    ignore(string_field(envelope, "recorded_at"))
    ignore(string_field(envelope, "subject_actor_id"))
    ignore(string_field(envelope, "created_by_actor_id"))
    guard !operations.contains(operation) &&
      !records.contains(id) &&
      operation == key else {
      fail("duplicate or inconsistent operation identity")
    }
    guard string_field(artifact, "content_uri") ==
      "moonbook://" + batch.book_id + "/artifacts/" + id else {
      fail("artifact URI does not bind its record")
    }
    let payloads = batch.payloads.filter(item => item.record_id == id)
    guard payloads.length() == 1 &&
      @utf8.encode(payloads[0].content).length() <= 1048576 &&
      string_field(artifact, "content_digest") ==
      content_digest(payloads[0].content) else {
      fail(
        "missing, duplicate, oversized, or digest-mismatched artifact payload",
      )
    }
    for prior in journal.batches {
      for old in prior.batch.requests {
        guard string_field(old, "operation_id") != operation &&
          string_field(old, "idempotency_key") != key &&
          string_field(field(field(old, "artifact"), "envelope"), "id") != id else {
          fail("operation or artifact replay refused")
        }
      }
    }
    operations.push(operation)
    records.push(id)
  }
}

///|
fn receipts(batch : ArtifactBatch, version : Int32) -> Array[Json] raise {
  batch.requests.map(request => {
    let artifact = field(request, "artifact")
    let envelope = field(artifact, "envelope")
    {
      "contract_id": "moonpoly.moonbook-append-receipt.v1",
      "operation_id": string_field(request, "operation_id"),
      "idempotency_key": string_field(request, "idempotency_key"),
      "status": "AppendAccepted",
      "provider_id": "moonbook",
      "book_id": batch.book_id,
      "case_id": batch.case_id,
      "record_id": string_field(envelope, "id"),
      "record_version": string_field(envelope, "version"),
      "content_digest": string_field(artifact, "content_digest"),
      "book_version": version.to_string(),
      "responded_at": string_field(request, "requested_at"),
      "rejection_code": "",
      "rejection_message": "",
    }
  })
}

///|
pub fn validate_journal(journal : ArtifactJournal) -> Unit raise {
  guard journal.contract_id == "moonbook.policy-artifact-journal.v1" &&
    journal.version == journal.batches.length() else {
    fail("corrupt artifact journal")
  }
  let mut prefix = empty_journal()
  for entry in journal.batches {
    validate_batch(entry.batch, prefix)
    guard entry.receipts == receipts(entry.batch, prefix.version + 1) else {
      fail("corrupt journal receipt")
    }
    prefix = {
      ..prefix,
      book_id: entry.batch.book_id,
      case_id: entry.batch.case_id,
      version: prefix.version + 1,
      batches: prefix.batches + [entry],
    }
  }
  guard prefix == journal else { fail("journal identity mismatch") }
}
