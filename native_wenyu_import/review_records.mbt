///|
priv struct NativeWenyuReviewBlock {
  heading : String
  fields : Map[String, Array[String]]
}

///|
// Parse complete level-three blocks. A higher-level heading also ends a block;
// a neighboring section cannot supply a missing identity or resolution field.
fn native_wenyu_review_blocks(text : String) -> Array[NativeWenyuReviewBlock] {
  let blocks : Array[NativeWenyuReviewBlock] = []
  let mut current : NativeWenyuReviewBlock? = None
  for raw in text.split("\n") {
    let line = raw.to_owned()
    if line.has_prefix("### ") ||
      line.has_prefix("## ") ||
      line.has_prefix("# ") {
      if current is Some(block) {
        blocks.push(block)
      }
      current = if line.has_prefix("### ") {
        Some({ heading: line, fields: Map([]), })
      } else {
        None
      }
      continue
    }
    if current is Some(block) && line.has_prefix("- ") {
      if line.find(":") is Some(index) {
        let name = line[2:index].trim().to_owned()
        let value = line[index + 1:].trim().to_owned()
        match block.fields.get(name) {
          Some(values) => values.push(value)
          None => block.fields[name] = [value]
        }
      }
    }
  }
  if current is Some(block) {
    blocks.push(block)
  }
  blocks
}

///|
fn native_wenyu_review_has(
  block : NativeWenyuReviewBlock,
  name : String,
  value : String,
) -> Bool {
  match block.fields.get(name) {
    Some(values) => values.contains("`\{value}`") || values.contains(value)
    None => false
  }
}

///|
fn native_wenyu_review_field(
  block : NativeWenyuReviewBlock,
  name : String,
) -> String raise {
  guard block.fields.get(name) is Some([value]) else {
    fail("missing or duplicate native review field: \{name}")
  }
  value
}

///|
fn native_wenyu_review_expect(
  block : NativeWenyuReviewBlock,
  name : String,
  value : String,
) -> Unit raise {
  guard native_wenyu_review_field(block, name) == "`\{value}`" else {
    fail("native review field mismatch: \{name}")
  }
}

///|
fn native_wenyu_review_unique_fields(
  block : NativeWenyuReviewBlock,
) -> Unit raise {
  for name, values in block.fields {
    guard values.length() == 1 else {
      fail("duplicate native review field: \{name}")
    }
  }
}

///|
fn native_wenyu_bound_review_blocks(
  text : String,
  binding : NativeWenyuReviewResolution,
) -> Array[NativeWenyuReviewBlock] {
  native_wenyu_review_blocks(text).filter(block => {
    native_wenyu_review_has(block, "Review ID", binding.review_id) ||
    native_wenyu_review_has(block, "Native work", binding.work_id) ||
    native_wenyu_review_has(block, "Evidence ID", binding.evidence_id)
  })
}

///|
fn native_wenyu_bound_evidence_blocks(
  text : String,
  binding : NativeWenyuReviewResolution,
) -> Array[NativeWenyuReviewBlock] {
  native_wenyu_review_blocks(text).filter(block => {
    block.heading == "### \{binding.evidence_id}" ||
    native_wenyu_review_has(block, "Native work", binding.work_id)
  })
}

///|
fn native_wenyu_check_review_identity(
  block : NativeWenyuReviewBlock,
  binding : NativeWenyuReviewResolution,
) -> Unit raise {
  native_wenyu_review_unique_fields(block)
  guard block.heading == "### Result review | \{binding.result_id}" else {
    fail("native review result heading mismatch")
  }
  native_wenyu_review_expect(block, "Review ID", binding.review_id)
  native_wenyu_review_expect(block, "Evidence ID", binding.evidence_id)
  native_wenyu_review_expect(block, "Native work", binding.work_id)
  native_wenyu_review_expect(block, "Request digest", binding.request_digest)
  native_wenyu_review_expect(block, "Payload digest", binding.payload_digest)
  guard native_wenyu_review_field(block, "Result page") ==
    "[\{binding.result_id}](../synthesis/observations.md)" else {
    fail("native review result page mismatch")
  }
}

///|
fn native_wenyu_check_evidence_identity(
  block : NativeWenyuReviewBlock,
  binding : NativeWenyuReviewResolution,
) -> Unit raise {
  native_wenyu_review_unique_fields(block)
  guard block.heading == "### \{binding.evidence_id}" else {
    fail("native review evidence heading mismatch")
  }
  native_wenyu_review_expect(block, "Task ID", binding.result_id)
  native_wenyu_review_expect(block, "Native work", binding.work_id)
  native_wenyu_review_expect(block, "Request digest", binding.request_digest)
  native_wenyu_review_expect(block, "Payload digest", binding.payload_digest)
}

///|
fn native_wenyu_resolution_timestamp(
  block : NativeWenyuReviewBlock,
  disposition : String,
) -> String raise {
  let value = native_wenyu_review_field(block, "Resolution")
  let prefix = "`\{disposition}` at `"
  guard value.has_prefix(prefix) && value.has_suffix("`") else {
    fail("native review resolution does not match its status")
  }
  let timestamp = value[prefix.length():value.length() - 1].to_owned()
  guard !timestamp.is_empty() && timestamp.length() <= 24 else {
    fail("native review resolution timestamp is missing or malformed")
  }
  // Preserve the writer's integer timestamp verbatim, including older signed
  // Int output. Do not invent a new resolution time during observation.
  let digits = timestamp.strip_prefix("-").unwrap_or(timestamp)
  guard !digits.is_empty() else {
    fail("native review resolution timestamp is malformed")
  }
  for index in 0..<digits.length() {
    guard digits[index] >= '0' && digits[index] <= '9' else {
      fail("native review resolution timestamp is malformed")
    }
  }
  timestamp
}

///|
fn native_wenyu_classify_review(
  binding : NativeWenyuReviewResolution,
  pending : String,
  finalized : String,
  evidence : String,
) -> NativeWenyuReviewResolution raise {
  let pending_blocks = native_wenyu_bound_review_blocks(pending, binding)
  let final_blocks = native_wenyu_bound_review_blocks(finalized, binding)
  let evidence_blocks = native_wenyu_bound_evidence_blocks(evidence, binding)
  guard evidence_blocks is [support] else {
    fail("native review evidence is missing, duplicate, or conflicting")
  }
  native_wenyu_check_evidence_identity(support, binding)
  match (pending_blocks, final_blocks) {
    ([review], []) => {
      native_wenyu_check_review_identity(review, binding)
      native_wenyu_review_expect(review, "Status", "pending")
      native_wenyu_review_expect(support, "Status", "pending-review")
      guard !review.fields.contains("Resolution") &&
        !support.fields.contains("Review note") else {
        fail("native pending review has partial resolution fields")
      }
      {
        ..binding,
        status: Pending,
        reason: "exact committed Book result awaits human review; original-task acceptance unevaluated",
      }
    }
    ([], [review]) => {
      native_wenyu_check_review_identity(review, binding)
      let (status, disposition) = match
        native_wenyu_review_field(review, "Status") {
        "`approved`" => (Approved, "approved")
        "`rejected`" => (Rejected, "rejected")
        _ => fail("native finalized review has no supported disposition")
      }
      let timestamp = native_wenyu_resolution_timestamp(review, disposition)
      native_wenyu_review_expect(support, "Status", disposition)
      guard native_wenyu_review_field(support, "Review note") ==
        "review \{disposition} for \{binding.review_id}" else {
        fail("native review evidence resolution note mismatch")
      }
      {
        ..binding,
        status,
        resolution_timestamp: Some(timestamp),
        reason: "Book review \{disposition}; original-task acceptance unevaluated; reviewer identity unauthenticated",
      }
    }
    _ =>
      fail(
        "native review is missing, duplicate, conflicting, or partially moved",
      )
  }
}
