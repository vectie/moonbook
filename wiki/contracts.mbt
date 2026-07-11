///|
// Shared wiki contracts for research-bootstrap artifacts and provider handoff.

///|
fn required_research_artifacts() -> Array[String] {
  [
    "raw/bootstrap/research-question.md", "raw/bootstrap/search-log.md", "raw/bootstrap/source-screen.md",
    "raw/bootstrap/evidence-matrix.md", "raw/bootstrap/local-sources.md", "raw/bootstrap/synthesis-brief.md",
    "raw/bootstrap/deep-report.md",
  ]
}

///|
fn research_artifact_contract_block() -> String {
  let required_files = required_research_artifacts().join("`, `")
  "\n\nResearch artifact contract:\n" +
  "- Required files: `\{required_files}`.\n" +
  "- `research-question.md`: state the question, scope, keywords, and exclusion boundaries.\n" +
  "- `search-log.md`: record search attempts, local paths inspected, web search/fetch attempts, and tool availability or denial.\n" +
  "- `source-screen.md`: list included/excluded sources with reasons and confidence.\n" +
  "- `evidence-matrix.md`: compare accepted sources by claim/theme/path and quote-free evidence notes.\n" +
  "- `local-sources.md`: digest inspected local repo files with exact paths and why each matters.\n" +
  "- `synthesis-brief.md`: summarize what is verified, what is provisional, and what remains blocked.\n" +
  "- `deep-report.md`: follow `skills/research-report/SKILL.md` and write a long-form article with executive summary, ecosystem context, project-specific sections, integration relationships, comparison, maturity assessment, diagrams/tables where useful, source IDs, and explicit limits.\n" +
  "- Product or marketing projection is a separate, explicit task; do not add promotional copy to the evidence envelope unless the goal requests it.\n" +
  "- MoonClaw returns the raw research envelope; MoonBook will decide and write durable `wiki/*` pages from that envelope.\n" +
  "- If any required artifact cannot be written, return a structured blocker instead of generic completion text.\n"
}
