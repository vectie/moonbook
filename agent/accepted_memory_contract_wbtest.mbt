///|
async test "accepted memory wire contract matches frozen Desk import bytes" {
  let contract = @json.parse(
    @fs.read_file("agent/testdata/accepted-memory-v1.json").text(),
  )
  guard contract
    is {
      "vectors": Array(vectors),
      "desk_imported_records": Array(records),
      ..
    } else {
    fail("Invalid fixture")
  }
  let results : Array[Json] = []
  for vector in vectors {
    guard vector
      is { "content": String(content), "status": String(expected), .. } else {
      fail("Invalid vector")
    }
    let status = agent_memory_review_status(content)
    assert_eq(status, expected)
    results.push({
      "sha256": agent_sha256_bytes(@utf8.encode(content)),
      "status": status,
    })
  }
  for record in records {
    guard record is { "content": String(content), "sha256": String(sha256), .. } else {
      fail("Invalid producer record")
    }
    assert_eq(agent_sha256_bytes(@utf8.encode(content)), sha256)
    assert_eq(agent_memory_review_status(content), "accepted")
    results.push({ "sha256": sha256, "status": "accepted" })
  }
  @fs.write_file(
    "agent/testdata/accepted-memory-v1-results.json",
    Json::array(results).stringify(indent=2),
    create_mode=CreateOrTruncate,
  )
}
