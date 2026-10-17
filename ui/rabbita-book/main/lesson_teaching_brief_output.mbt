///|
/// Use a fence longer than every authored backtick run. Retained text remains
/// literal, including Markdown/HTML-looking examples, rather than instructions
/// to a Markdown renderer. Exact editable bytes also live in the companion JSON.
extern "js" fn lesson_teaching_block(text : String) -> String =
  #| text => { let width=3,run=0;for(let i=0;i<text.length;i++){if(text.charCodeAt(i)===96){run++;if(run>=width)width=run+1;}else run=0;}const fence='`'.repeat(width);return fence+'text\n'+text+'\n'+fence+'\n'; }

///|
fn lesson_teaching_markdown(draft : LessonTeachingBrief) -> String {
  let parts = [
    "# MoonBook agent teaching brief\n",
    "A human-curated learning sequence. The objective, order and fresh practice tasks are authored choices. Read each lesson only within its recorded scope. This file does not authorize tools, activation, factual acceptance or a model-training run. Captures matched loaded reviewed lessons at export, not continuously after export.\n",
    "## Learning objective · authored\n" +
    lesson_teaching_block(draft.objective),
    "## How to use\n1. Inspect scope and invalidation conditions before applying each lesson.\n2. Study the captured guidance and earlier operator-reported examples in order.\n3. Try the authored practice task separately; record fresh observations outside this file. Expected outputs below are historical examples, not fresh results.\n4. Return any proposed correction to the existing Bookkeeper revision and named-human review workflow. Recheck current guidance in Book before reuse.\n",
  ]
  for index, item in draft.items {
    let snapshot = item.snapshot
    parts.push("## Lesson " + (index + 1).to_string() + "\n")
    parts.push("### Title\n" + lesson_teaching_block(snapshot.title))
    parts.push(
      "### Captured guidance\n" + lesson_teaching_block(snapshot.guidance),
    )
    parts.push(
      "### Required scope\n" +
      lesson_teaching_block(snapshot.applicability.stringify(indent=2)),
    )
    parts.push(
      "### Do not apply when\n" +
      lesson_teaching_block(snapshot.invalidation.stringify(indent=2)),
    )
    parts.push(
      "### Review and exact source references\n" +
      lesson_teaching_block(
        (
          {
            "lesson_id": snapshot.lesson_id,
            "lesson": ToJson::to_json(snapshot.reference),
            "accepted_review": ToJson::to_json(snapshot.accepted_review),
            "selection_review": snapshot.selection_review,
            "reviewer": snapshot.reviewer,
            "review_summary": snapshot.review_summary,
            "outcome": snapshot.outcome,
            "assessment": snapshot.assessment,
          } : Json).stringify(indent=2),
      ),
    )
    parts.push(
      "### Retained practice examples · operator reports\n" +
      lesson_teaching_block(item.example_notice),
    )
    if item.examples.is_empty() {
      parts.push(
        "No supported retained examples were captured. Do not invent a successful example.\n",
      )
    }
    for case_index, example in item.examples {
      parts.push(
        "#### Example " +
        (case_index + 1).to_string() +
        "\n" +
        lesson_teaching_block(example.name),
      )
      parts.push("Input:\n" + lesson_teaching_block(example.input))
      parts.push(
        "Earlier expected output, not a fresh model run:\n" +
        lesson_teaching_block(example.expected_output),
      )
      parts.push(
        "Literal checks and exact source case (under the lesson/review above):\n" +
        lesson_teaching_block(
          (
            {
              "required": ToJson::to_json(example.required),
              "forbidden": ToJson::to_json(example.forbidden),
              "source_case_id": example.source_case_id,
              "source_kind": example.source_kind,
              "source_lesson": ToJson::to_json(snapshot.reference),
              "source_review": ToJson::to_json(snapshot.accepted_review),
            } : Json).stringify(indent=2),
        ),
      )
    }
    parts.push(
      "### Fresh practice task · authored, not executed\n" +
      (if item.exercise.is_blank() {
        "No fresh practice task authored.\n"
      } else {
        lesson_teaching_block(item.exercise)
      }),
    )
  }
  parts.push(
    "---\nEnd of captured learning material. Literal matches do not prove factual correctness or generalization. Keep the separate teaching-brief JSON to resume editing. Files may contain private guidance and examples; share deliberately.\n",
  )
  parts.join("\n")
}

///|
extern "js" fn lesson_teaching_download(
  text : String,
  markdown : Bool,
) -> @js.Promise =
  #| async (text, markdown) => {
  #|   const blob=new Blob([text],{type:markdown?'text/markdown;charset=utf-8':'application/json;charset=utf-8'});
  #|   const url=URL.createObjectURL(blob);let link;
  #|   try{link=document.createElement('a');link.href=url;link.download=markdown?'moonbook-agent-teaching-brief.md':'moonbook-agent-teaching-brief.json';document.body.appendChild(link);link.click();}
  #|   finally{try{link?.remove();}finally{setTimeout(()=>URL.revokeObjectURL(url),1000);}}
  #|   return markdown?'Agent teaching brief download requested. Check browser downloads. No learner was run.':'Editable teaching-brief JSON download requested. Check browser downloads before leaving this tab.';
  #| }
