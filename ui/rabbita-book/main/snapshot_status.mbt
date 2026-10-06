///|
priv enum SnapshotStatus {
  Loading
  Current
  Stale
  Unavailable
} derive(Eq, Debug)

///|
fn snapshot_status(model : Model) -> SnapshotStatus {
  if model.loading {
    Loading
  } else if model.refresh_count == 0 {
    Unavailable
  } else if model.error is Some(_) {
    Stale
  } else {
    Current
  }
}

///|
fn snapshot_status_title(model : Model) -> String {
  interface_message(
    model.locale,
    match snapshot_status(model) {
      Loading => SidebarRefreshing
      Current => SidebarLoaded
      Stale => SnapshotStale
      Unavailable => SnapshotUnavailable
    },
  )
}

///|
fn snapshot_status_detail(model : Model) -> String {
  interface_message(
    model.locale,
    match snapshot_status(model) {
      Loading =>
        if model.refresh_count == 0 {
          SnapshotWaiting
        } else {
          SnapshotRetained
        }
      Stale => SnapshotRetained
      Unavailable => SnapshotMissing
      Current =>
        if model.live_reload_endpoint is Some(_) {
          SnapshotLiveMode
        } else {
          SnapshotStaticMode
        }
    },
  )
}

///|
/// Keep first-load and failed-first-load screens free of illustrative counts.
fn empty_snapshot_state() -> UiState {
  {
    ..demo_state(),
    summary: "Read chapters and review your knowledge workspace.",
    status_chips: [],
    metrics: [],
    workflow: [],
    review_queue: [],
    keeper_items: [],
    page_families: [],
    chapters: [],
    synthesis_preview: "Workspace snapshot has not loaded.",
  }
}

///|
/// User retries coalesce; a completed workspace operation may supersede an
/// earlier read. Its older callback must not overwrite the newer snapshot.
fn start_snapshot_read(
  emit : @rabbita.Emit[Msg],
  model : Model,
  force~ : Bool,
) -> (@rabbita.Cmd, Model) {
  if model.loading && !force {
    (@rabbita.none, model)
  } else {
    let request = model.snapshot_request + 1
    (
      fetch_ui_state_cmd(emit, request),
      { ..model, loading: true, snapshot_request: request, },
    )
  }
}

///|
fn finish_snapshot_read(
  model : Model,
  request : Int,
  result : Result[UiState, Error],
) -> Model {
  if !model.loading || request != model.snapshot_request {
    model
  } else {
    match result {
      Ok(state) =>
        {
          ..model,
          loading: false,
          state,
          error: None,
          refresh_count: model.refresh_count + 1,
        }
      Err(error) => { ..model, loading: false, error: Some("\{error}"), }
    }
  }
}

///|
fn snapshot_status_panel(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> @rabbita.Html {
  @html.article(
    id="snapshot-status",
    style=[
      "padding:18px", "border-radius:20px", "background:#eff6ff", "color:#0f172a",
      "display:grid", "gap:12px", "overflow-wrap:anywhere",
    ],
    [
      @html.div(attrs=@html.Attrs::build().role("status").aria_live("polite"), [
        @html.h3(
          style=["margin:0 0 8px", "font-size:18px"],
          snapshot_status_title(model),
        ),
        @html.p(
          style=["margin:0", "line-height:1.6"],
          snapshot_status_detail(model),
        ),
      ]),
      match model.error {
        Some(error) =>
          @html.p(
            attrs=@html.Attrs::build().role("alert"),
            style=["margin:0", "color:#991b1b", "line-height:1.5"],
            error,
          )
        None => @html.span("")
      },
      match model.bookkeeper_reads.store_error {
        Some(error) =>
          @html.p(
            attrs=@html.Attrs::build().role("alert"),
            error + " Use Refresh snapshot to retry. Your draft is retained.",
          )
        None => @html.span("")
      },
      match model.bookkeeper_reads.authorities_error {
        Some(error) =>
          @html.p(
            attrs=@html.Attrs::build().role("alert"),
            error + " Use Refresh snapshot to retry. Your draft is retained.",
          )
        None => @html.span("")
      },
      @html.button(
        id="snapshot-retry",
        disabled=model.loading,
        on_click=emit(RetrySnapshot),
        style=[
          "min-height:44px",
          "padding:12px 16px",
          "border:none",
          "border-radius:14px",
          "background:#0f172a",
          "color:#fff",
          "font-weight:700",
          if model.loading {
            "cursor:wait;opacity:.65"
          } else {
            "cursor:pointer"
          },
        ],
        interface_message(
          model.locale,
          if model.loading {
            SidebarRefreshing
          } else if model.error is Some(_) || model.refresh_count == 0 {
            SnapshotRetry
          } else {
            SnapshotRefresh
          },
        ),
      ),
    ],
  )
}

///|
fn snapshot_diagnostics(model : Model) -> @rabbita.Html {
  @html.details([
    @html.summary(interface_message(model.locale, SnapshotDetails)),
    @html.ul(
      style=["padding-left:18px", "line-height:1.6", "overflow-wrap:anywhere"],
      [
        @html.li("Snapshot source: moonbook-ui-state.json"),
        @html.li("Successful snapshot reads: \{model.refresh_count}"),
        @html.li(
          "Automatic updates refresh data in this page and retain your draft. Before manually reloading for application changes, use Save summary locally for review text. Technical JSON is kept in this tab only; copy it before leaving.",
        ),
        @html.li(
          match model.live_reload_endpoint {
            Some(endpoint) =>
              "Configured live update transport: SSE via \{endpoint}"
            None => "Live update transport: not configured"
          },
        ),
      ],
    ),
  ])
}
