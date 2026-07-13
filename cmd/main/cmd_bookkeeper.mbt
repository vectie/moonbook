///|
async fn run_bookkeeper(args : Array[String]) -> Unit {
  match args {
    ["reflect", root, observation_path] => {
      let record = @wiki.reflect_bookkeeper_file(root, observation_path) catch {
        error => {
          println("moonbook bookkeeper reflect failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(record)
    }
    ["record-spatial", root, study_path] => {
      let record = @wiki.record_spatial_reference_file(root, study_path) catch {
        error => {
          println("moonbook bookkeeper record-spatial failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(record)
    }
    ["promote", root, reflection_id, review_ref] => {
      let paths = @wiki.promote_bookkeeper_procedures(
        root, reflection_id, review_ref,
      ) catch {
        error => {
          println("moonbook bookkeeper promote failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(paths)
    }
    ["reconcile-flow", root, projection_path, work_item_id, recorded_at] => {
      let record = @wiki.reconcile_flow_projection_file(
        root, projection_path, work_item_id, recorded_at,
      ) catch {
        error => {
          println("moonbook bookkeeper reconcile-flow failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(record)
    }
    ["reconcile-run", root, projection_path, recorded_at] => {
      let record = @wiki.reconcile_flow_run_file(
        root, projection_path, recorded_at,
      ) catch {
        error => {
          println("moonbook bookkeeper reconcile-run failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(record)
    }
    ["propose-revision", root, request_path] => {
      let record = @wiki.write_plan_revision(root, request_path) catch {
        error => {
          println("moonbook bookkeeper propose-revision failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(record)
    }
    ["metacognition", root] => {
      let status = @wiki.metacognition_status_json(root) catch {
        error => {
          println("moonbook bookkeeper metacognition failed: \{error}")
          @os.exit(1)
        }
      }
      print_json(status)
    }
    _ =>
      println(
        "moonbook bookkeeper usage:\n  moonbook bookkeeper reflect <book-root> <observation.json>\n  moonbook bookkeeper record-spatial <book-root> <study.json>\n  moonbook bookkeeper promote <book-root> <reflection-id> <review-receipt-ref>\n  moonbook bookkeeper reconcile-flow <book-root> <projection.json> <work-item-id> <recorded-at>\n  moonbook bookkeeper reconcile-run <book-root> <projection.json> <recorded-at>\n  moonbook bookkeeper propose-revision <book-root> <request.json>\n  moonbook bookkeeper metacognition <book-root>",
      )
  }
}
