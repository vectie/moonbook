///|
fn bookkeeper_profile_step(profile : Json, step_id : String) -> Json raise {
  guard profile is { "steps": Array(steps), .. } else {
    fail("Bookkeeper profile is missing steps")
  }
  for step in steps {
    if step is { "id": String(id), .. } && id == step_id {
      return step
    }
  }
  fail("Bookkeeper profile is missing step " + step_id)
}

///|
fn generated_bookkeeper_profile() -> Json raise {
  guard @json.parse(moonclaw_jobs_text())
    is {
      "jobs": {
        "profiles": { "bookkeeper_three_gap_controller": profile, .. },
        ..
      },
      ..
    } else {
    fail("generated MoonClaw jobs omit the Bookkeeper profile")
  }
  profile
}

///|
async test "Bookkeeper analysis step carries the exact single-finding result contract" {
  let analyze = bookkeeper_profile_step(
    generated_bookkeeper_profile(),
    "analyze_three_gaps",
  )
  guard analyze
    is {
      "prompt_template": String(prompt),
      "metadata": {
        "model": "gpt-5.6-sol",
        "output_contract": "moonbook.bookkeeper.moonclaw-result.v1",
        "result_contract": result_contract,
        ..
      },
      ..
    } else {
    fail("analysis step does not expose the canonical result contract")
  }
  let fixture_path = moonbook_wiki_path(detect_moonbook_module_root())
    .join(
      moonbook_wiki_path(
        "wiki/fixtures/bookkeeper-three-gap-result-contract.golden.json",
      ),
    )
    .to_string()
  let golden = @json.parse(@fsx.read_file(fixture_path))
  assert_true(result_contract == golden)
  assert_true(
    prompt.contains("exactly one moonbook.bookkeeper.moonclaw-result.v1"),
  )
  assert_true(
    prompt.contains(
      "exactly one lowercase ```json fenced block containing only that canonical object",
    ),
  )
  assert_true(
    prompt.contains(
      "candidate.stage must be the lowercase value three_gap_finding",
    ),
  )
  assert_true(prompt.contains("learning_key, gap_class, transition, severity"))
  assert_true(
    prompt.contains(
      "payload.learning_key exactly from packet metadata.result_contract.learning_key",
    ),
  )
  assert_true(
    prompt.contains(
      "evidence_refs exactly from packet metadata.canonical_evidence_refs",
    ),
  )
  assert_true(prompt.contains("Do not emit three findings"))
  assert_true(prompt.contains("MoonBook alone validates and durably records"))
}

///|
test "Bookkeeper handoff emits directly ingestible standard MoonClaw content" {
  let handoff = bookkeeper_profile_step(
    generated_bookkeeper_profile(),
    "prepare_moonbook_handoff",
  )
  guard handoff
    is {
      "prompt_template": String(prompt),
      "metadata": { "model": "gpt-5.6-sol", .. },
      ..
    } else {
    fail("handoff step does not preserve the canonical model")
  }
  assert_true(
    prompt.contains(
      "exactly one lowercase ```json fenced block containing only the canonical object",
    ),
  )
  assert_true(prompt.contains("with no other fenced blocks"))
  assert_true(
    prompt.contains(
      "metadata.result_contract.learning_key exactly from the packet",
    ),
  )
  assert_true(
    prompt.contains(
      "evidence_refs exactly from packet metadata.canonical_evidence_refs",
    ),
  )
  assert_true(
    prompt.contains("ingest-result <root> <packet.json> <result.json>"),
  )
  assert_true(
    prompt.contains("named-human `moonbook bookkeeper review` remains later"),
  )
}

///|
test "Outcome binding bypasses capability aggregation without weakening review gates" {
  let aggregate = bookkeeper_profile_step(
    generated_bookkeeper_profile(),
    "aggregate_capability_proposal",
  )
  guard aggregate
    is {
      "prompt_template": String(prompt),
      "metadata": {
        "model": "gpt-5.6-sol",
        "disable_waiting_for_input": True,
        "best_effort_on_missing_input": True,
        ..
      },
      ..
    } else {
    fail("capability aggregation lacks bounded missing-input semantics")
  }
  assert_true(prompt.contains("applicability exactly not_applicable"))
  assert_true(prompt.contains("outcome_binding_requires_three_gap_handoff"))
  assert_true(prompt.contains("Do not request input"))
  assert_true(prompt.contains("exact named-human Accept receipts"))
  assert_true(prompt.contains("do not fabricate acceptance"))
}
