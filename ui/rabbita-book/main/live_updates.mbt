///|
priv struct BookkeeperReads {
  request : Int
  store_loading : Bool
  authorities_loading : Bool
  store_error : String?
  authorities_error : String?
}

///|
fn initial_bookkeeper_reads() -> BookkeeperReads {
  {
    request: 1,
    store_loading: true,
    authorities_loading: true,
    store_error: None,
    authorities_error: None,
  }
}

///|
fn start_bookkeeper_read(
  emit : @rabbita.Emit[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let request = model.bookkeeper_reads.request + 1
  (
    @rabbita.batch([
      fetch_bookkeeper_store_cmd(emit, request),
      fetch_bookkeeper_authorities_cmd(emit, request),
    ]),
    {
      ..model,
      bookkeeper_reads: {
        ..model.bookkeeper_reads,
        request,
        store_loading: true,
        authorities_loading: true,
      },
    },
  )
}

///|
/// A live update reads data only. Drafts, bindings and mutation ownership stay
/// in the current model; the read reducers accept only their newest generation.
fn start_workspace_read(
  emit : @rabbita.Emit[Msg],
  model : Model,
  force~ : Bool,
) -> (@rabbita.Cmd, Model) {
  if model.loading && !force {
    return (@rabbita.none, model)
  }
  let (snapshot_cmd, snapshot) = start_snapshot_read(emit, model, force~)
  let (bookkeeper_cmd, next) = start_bookkeeper_read(emit, snapshot)
  let (wiki_review, effects) = wiki_review_reduce(next.wiki_review, LiveRefresh)
  (
    @rabbita.batch(
      [snapshot_cmd, bookkeeper_cmd] +
      effects.map(effect => wiki_review_effect_cmd(emit, effect)),
    ),
    { ..next, wiki_review, },
  )
}

///|
fn finish_bookkeeper_store_read(
  model : Model,
  request : Int,
  result : Result[BookkeeperStoreSnapshot, Error],
) -> Model {
  let reads = model.bookkeeper_reads
  if request != reads.request || !reads.store_loading {
    return model
  }
  match result {
    Ok(snapshot) =>
      {
        ..model,
        bookkeeper_store: Some(snapshot),
        bookkeeper_reads: { ..reads, store_loading: false, store_error: None, },
      }
    Err(error) =>
      {
        ..model,
        bookkeeper_reads: {
          ..reads,
          store_loading: false,
          store_error: Some(
            "Store state may be out of date or unavailable: \{error}",
          ),
        },
      }
  }
}

///|
fn finish_bookkeeper_authority_read(
  model : Model,
  request : Int,
  result : Result[BookkeeperAuthorityRegistry, Error],
) -> Model {
  let reads = model.bookkeeper_reads
  if request != reads.request || !reads.authorities_loading {
    return model
  }
  match result {
    Ok(registry) => {
      let mut selected = model.selected_bookkeeper_authority
      if selected is None {
        for grant in registry.grants {
          if grant.active && selected is None {
            selected = Some(grant.authority_ref)
          }
        }
      }
      {
        ..model,
        bookkeeper_authorities: Some(registry),
        selected_bookkeeper_authority: selected,
        bookkeeper_reads: {
          ..reads,
          authorities_loading: false,
          authorities_error: None,
        },
      }
    }
    Err(error) =>
      {
        ..model,
        bookkeeper_reads: {
          ..reads,
          authorities_loading: false,
          authorities_error: Some(
            "Authority status may be out of date or unavailable: \{error}",
          ),
        },
      }
  }
}

///|
extern "js" fn install_live_reload(endpoint : String, notify : () -> Unit) =
  #| (endpoint, notify) => {
  #|   if (typeof window === "undefined") return;
  #|   const existing = window.__moonbookLiveReload;
  #|   if (existing && existing.endpoint === endpoint && endpoint) {
  #|     existing.notify = notify;
  #|     return;
  #|   }
  #|   window.__moonbookLiveReload = null;
  #|   if (existing && existing.source) { try { existing.source.close(); } catch (_) {} }
  #|   if (!endpoint || !window.EventSource) return;
  #|   const source = new window.EventSource(endpoint);
  #|   const subscription = { endpoint, source, notify, token: null };
  #|   window.__moonbookLiveReload = subscription;
  #|   const changed = event => {
  #|     if (window.__moonbookLiveReload !== subscription) return;
  #|     const token = String(event.data || "");
  #|     if (token && token === subscription.token) return;
  #|     subscription.token = token;
  #|     subscription.notify();
  #|   };
  #|   source.addEventListener("reload", changed);
  #|   // The ready token also catches changes missed while disconnected.
  #|   source.addEventListener("ready", changed);
  #|   source.onerror = () => {};
  #| }

///|
fn subscribe_live_reload_cmd(
  emit : @rabbita.Emit[Msg],
  endpoint : String,
) -> @rabbita.Cmd {
  @cmd.custom_cmd(
    scheduler => {
      install_live_reload(endpoint, () => {
        scheduler.add(emit(LiveDataChanged(endpoint)))
      })
    },
    kind=@cmd.after_render,
  )
}
