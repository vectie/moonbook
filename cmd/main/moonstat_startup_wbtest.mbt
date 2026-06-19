///|
test "moonstat startup messages describe suite telemetry and standalone mode" {
  assert_eq(
    moonstat_startup_ready_message("http://127.0.0.1:15721"),
    "Moonstat available at http://127.0.0.1:15721; suite telemetry endpoint enabled",
  )
  assert_eq(
    moonstat_startup_unavailable_message(
      "http://127.0.0.1:15721", "request error: connection refused",
    ),
    "Moonstat unavailable at http://127.0.0.1:15721; continuing as standalone Moonbook: request error: connection refused",
  )
}
