///|
priv struct ProductOutcomeWorkspace {
  request : Int
  pending : Bool
  operation : String
  preview : Json?
  selected : Json?
  items : Array[Json]
  notice : String
}

///|
priv enum ProductOutcomeMsg {
  Pick
  Picked(Int, Result[String, String])
  Run(String, Json)
  Read(Int, String, Json, Result[Json, String])
  Review(Json)
}

///|
fn initial_product_outcome_workspace() -> ProductOutcomeWorkspace {
  {
    request: 0,
    pending: false,
    operation: "",
    preview: None,
    selected: None,
    items: [],
    notice: "",
  }
}

///|
fn product_outcome_payload(source_pack : Json) -> Result[Json, String] {
  guard source_pack
    is {
      "contract_version": "moonbook.product-outcome-package.v1",
      "package_digest": String(_),
      "payload_json": String(text),
      ..
    } else {
    return Err("Choose the outcome package exported by the producing product")
  }
  let value = @json.parse(text) catch {
    _ => return Err("The retained package is not readable JSON")
  }
  guard value is { "submission": submission, "artifacts": Array(_), .. } &&
    outcome_review_preview(submission.stringify()) is Ok(_) else {
    return Err(
      "The package needs its completed outcome and retained source artifacts",
    )
  }
  Ok(value)
}

///|
fn product_outcome_response(
  operation : String,
  payload : Json,
  result : Json,
) -> Result[Unit, String] {
  if operation == "product-list" {
    guard result is { "items": Array(items), .. } &&
      items.all(item => {
        saved_lesson_reference(lesson_task_field(item, "submission")) is Some(_)
      }) else {
      return Err("The saved outcome list is not readable")
    }
    return Ok(())
  }
  guard result
    is {
      "contract_version": "moonbook.product-outcome-readback.v1",
      "package": source_pack,
      "package_digest": digest,
      "progress": progress,
      "reviews": Array(_),
      "activation_authorized": false,
      "external_side_effects_applied": false,
      ..
    } &&
    lesson_task_field(source_pack, "package_digest") == digest else {
    return Err(
      "Book did not confirm a retained, non-activating outcome receipt",
    )
  }
  let inner = match product_outcome_payload(source_pack) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let reference = lesson_task_field(
    lesson_task_field(inner, "submission"),
    "submission",
  )
  if lesson_task_field(progress, "submission") != reference ||
    (if operation == "product-import" {
      source_pack != payload
    } else {
      lesson_task_field(payload, "submission") != reference
    }) {
    return Err(
      "Book returned a different outcome; your current selection was kept",
    )
  }
  Ok(())
}

///|
fn product_outcome_update(
  emit : @rabbita.Emit[Msg],
  model : Model,
  message : ProductOutcomeMsg,
) -> (@rabbita.Cmd, Model) {
  let state = model.outcome_lessons.products
  let busy = state.pending ||
    model.bookkeeper_busy ||
    model.outcome_lessons.pending
  let (cmd, next) = match message {
    Pick if !busy => {
      let request = state.request + 1
      (
        @rabbita.perform(
          result => emit(OutcomeLesson(ProductOutcome(Picked(request, result)))),
          async fn() noraise {
            let value : String = product_outcome_pick_file().wait().cast() catch {
                error => return Err("Could not read outcome: \{error}")
              }
            if value.is_empty() {
              Err("No file read. Choose an outcome package up to 16 MiB")
            } else {
              Ok(value)
            }
          },
        ),
        {
          ..state,
          request,
          pending: true,
          operation: "pick",
          notice: "Choose a completed outcome package. Inspect it before saving.",
        },
      )
    }
    Picked(request, result) if state.pending &&
      state.operation == "pick" &&
      request == state.request => {
      let parsed = match result {
        Err(error) => Err(error)
        Ok(text) => {
          let value = @json.parse(text) catch {
            _ =>
              return (
                @rabbita.none,
                {
                  ..model,
                  outcome_lessons: {
                    ..model.outcome_lessons,
                    products: {
                      ..state,
                      pending: false,
                      notice: "Unreadable JSON; your current outcome and preview were kept.",
                    },
                  },
                },
              )
          }
          match product_outcome_payload(value) {
            Ok(_) => Ok(value)
            Err(error) => Err(error)
          }
        }
      }
      (
        @rabbita.none,
        {
          ..state,
          pending: false,
          preview: match parsed {
            Ok(value) => Some(value)
            Err(_) => state.preview
          },
          notice: match parsed {
            Ok(_) =>
              "Preview only. Inspect the interpretation and original sources, then save for Book review."
            Err(error) => error
          },
        },
      )
    }
    Run(operation, payload) if !busy => {
      if !["product-import", "product-list", "product-read", "product-continue"].contains(
          operation,
        ) {
        return (@rabbita.none, model)
      }
      if operation == "product-import" && state.preview != Some(payload) {
        return (@rabbita.none, model)
      }
      let request = state.request + 1
      (
        @rabbita.perform(
          result => {
            emit(
              OutcomeLesson(
                ProductOutcome(Read(request, operation, payload, result)),
              ),
            )
          },
          async fn() noraise { post_outcome_lesson(operation, payload) },
        ),
        {
          ..state,
          request,
          pending: true,
          operation,
          notice: "Reading the exact saved outcome and next review step…",
        },
      )
    }
    Read(request, operation, payload, result) if state.pending &&
      state.request == request &&
      state.operation == operation => {
      let checked = match result {
        Ok(value) =>
          match product_outcome_response(operation, payload, value) {
            Ok(_) => Ok(value)
            Err(error) => Err(error)
          }
        Err(error) => Err(error)
      }
      match checked {
        Err(error) =>
          (
            @rabbita.none,
            {
              ..state,
              pending: false,
              notice: "Could not confirm outcome: " +
              error +
              ". Preview, saved selection and review drafts were kept. Refresh or retry the exact action.",
            },
          )
        Ok(value) => {
          let download = lesson_task_text(payload, "download")
          let command = if download == "receipt" || download == "package" {
            @cmd.custom_cmd(_ => {
              product_outcome_download(
                (if download == "receipt" {
                  value
                } else {
                  lesson_task_field(value, "package")
                }).stringify(indent=2),
                "moonbook-product-outcome-" + download + ".json",
              )
            })
          } else {
            @rabbita.none
          }
          let next = {
            ..state,
            pending: false,
            selected: if operation == "product-list" {
              state.selected
            } else {
              Some(value)
            },
            items: if operation == "product-list" {
              match lesson_task_field(value, "items") {
                Array(items) => items
                _ => []
              }
            } else {
              state.items
            },
            preview: if operation == "product-import" {
              None
            } else {
              state.preview
            },
            notice: if download.is_empty() {
              "Saved outcome read back. Follow the next step below; prior review drafts remain available."
            } else {
              "Downloaded the selected outcome after a fresh Book journal read. Import its receipt in the producing product to reopen the original result."
            },
          }
          let updated = {
            ..model,
            outcome_lessons: { ..model.outcome_lessons, products: next, },
          }
          let (read, updated) = start_bookkeeper_read(emit, updated)
          return (
            @rabbita.batch([
              command,
              read,
              if operation == "product-import" ||
                operation == "product-continue" {
                emit(RefreshSnapshot)
              } else {
                @rabbita.none
              },
            ]),
            updated,
          )
        }
      }
    }
    Review(reference) if !busy => {
      guard product_outcome_review_record(model, reference) is Some(record) else {
        return (@rabbita.none, model)
      }
      let (command, next) = update(
        emit,
        SelectBookkeeperItem(lesson_record_item(record)),
        model,
      )
      return (
        @rabbita.batch([
          command,
          @cmd.custom_cmd(_ => outcome_review_scroll(), kind=@cmd.after_render),
        ]),
        next,
      )
    }
    _ => (@rabbita.none, state)
  }
  (
    cmd,
    { ..model, outcome_lessons: { ..model.outcome_lessons, products: next, }, },
  )
}

///|
fn product_outcome_review_record(
  model : Model,
  reference : Json,
) -> BookkeeperRawRecord? {
  guard !model.bookkeeper_busy &&
    !model.bookkeeper_reads.store_loading &&
    model.bookkeeper_reads.store_error is None &&
    model.bookkeeper_store is Some(snapshot) &&
    snapshot.replay_issues.is_empty() &&
    model.outcome_lessons.products.selected is Some(selected) &&
    lesson_task_field(lesson_task_field(selected, "progress"), "next_record") ==
    reference else {
    return None
  }
  let records = snapshot.records.filter(record => {
    record.record.to_json() == reference
  })
  match records {
    [record] => Some(record)
    _ => None
  }
}

///|
fn product_outcome_can_defer(model : Model) -> Bool {
  guard !model.outcome_lessons.products.pending &&
    model.outcome_lessons.products.selected is Some(receipt) &&
    model.selected_bookkeeper_record is Some(selected) &&
    model.bookkeeper_store is Some(snapshot) else {
    return false
  }
  let next = lesson_task_field(
    lesson_task_field(receipt, "progress"),
    "next_record",
  )
  selected.to_json() == next &&
  product_outcome_review_record(model, next) is Some(_) &&
  !snapshot.reviews.any(review => {
    review.subject == selected &&
    review.review_complete &&
    bookkeeper_enum_is(review.reviewer_kind, "Human") &&
    (review.disposition == "Accept" || review.disposition == "Reject")
  })
}

///|
extern "js" fn product_outcome_pick_file() -> @js.Promise =
  #| () => new Promise((resolve,reject) => {const input=document.createElement('input');input.type='file';input.accept='application/json,.json';input.onchange=async()=>{try{const f=input.files?.[0];resolve(f&&f.size<=16777216?await f.text():'')}catch(error){reject(error)}};input.oncancel=()=>resolve('');input.click()})

///|
extern "js" fn product_outcome_download(text : String, name : String) =
  #| (text,name) => {const url=URL.createObjectURL(new Blob([text],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)}
