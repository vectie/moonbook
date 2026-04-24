///|
// Doctor command handler.

async fn run_doctor(args : Array[String]) -> Unit {
  let root = match args {
    [root] => root
    [] => "."
    _ => {
      println("moonbook doctor usage: moonbook doctor [root]")
      return
    }
  }
  let skill_report = @wiki.doctor_skills(root) catch {
    error => {
      println("moonbook doctor failed: \{error}")
      return
    }
  }
  println("MoonBook doctor for \{root}")
  println("skills: \{skill_report.total_count}")
  if skill_report.warnings.is_empty() &&
    skill_report.duplicate_names.is_empty() &&
    skill_report.missing_reference_paths.is_empty() {
    println("skill status: clean")
  } else {
    println("skill status: attention needed")
  }
  if @fsx.exists(@path.Path(root).join(@path.Path("wiki")).to_string()) {
    let health = @wiki.report_health(root) catch {
      error => {
        println("wiki health failed: \{error}")
        return
      }
    }
    println("wiki health: \{health.level}")
    println("summary: \{health.summary}")
    println(
      "coverage: sources=\{health.source_page_count} entities=\{health.entity_page_count} concepts=\{health.concept_page_count} queries=\{health.query_note_count}",
    )
  } else {
    println("wiki health: skipped (no wiki workspace detected)")
  }
}

///|
