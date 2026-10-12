///|
pub(all) struct ArtifactPayload {
  record_id : String
  content : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A deliberately separate local-fixture port. It cannot accept decisions,
/// impersonate a reviewer, or authorize a real MoonGate operation.
pub(all) struct ArtifactBatch {
  contract_id : String
  execution_mode : String
  batch_id : String
  book_id : String
  case_id : String
  expected_book_version : String
  requests : Array[Json]
  payloads : Array[ArtifactPayload]
  context : Json
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct StoredBatch {
  batch : ArtifactBatch
  receipts : Array[Json]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ArtifactJournal {
  contract_id : String
  book_id : String
  case_id : String
  version : Int
  batches : Array[StoredBatch]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn capability() -> Json {
  {
    "contract_id": "moonbook.policy-artifact-capability.v1",
    "provider_id": "moonbook",
    "capability_ref": "moonbook.policy-artifact-batch.local-fixture.v1",
    "execution_mode": "deterministic-local-fixture.v1",
    "atomic_batch": true,
    "max_batch_artifacts": 8,
    "max_journal_bytes": 8388608,
    "human_acceptance_implied": false,
    "official_authority": false,
  }
}

///|
pub fn content_digest(content : String) -> String {
  "sha256:" + @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(content)))
}
