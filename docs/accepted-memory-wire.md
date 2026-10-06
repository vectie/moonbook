# Accepted-memory wire contract v1

`agent/memory_review_status.mbt` owns admission for portable procedures and
beliefs. `agent/testdata/accepted-memory-v1.json` freezes representative JSON,
Markdown and legacy decisions alongside full records produced by Desk and
imported by MoonBook. The contract test executes the actual private Book parser
and writes byte-digest/status results for consumer parity checks. Record bodies
are raw UTF-8, not an `AgentMemoryRecord` serialization requirement.

- JSON: only a top-level accepted/promoted string status admits. Other status
  values override a legacy accepted=true flag. Without status, that boolean flag
  admits. Nested fields and arrays do not
- Text: an initial closed metadata block, or the supported one-line status form,
  supplies admission. Duplicated fields, unclosed metadata, indented example
  markers, fenced examples and body prose do not admit
- Status comparison follows the parser's whitespace/quoting/case rules. Raw file
  content is never normalized as a consequence of deciding admission
- Accepted capability lessons stay ideas. Source answers/provenance remain
  historical evidence; admission grants no new execution authority

Current Claw consumer parity uses these same vectors and the Book-generated
results. Changes to admission semantics must update the version/fixtures and
both producer/consumer tests explicitly. The frozen imported marker,
installation and receipt files provide ancestry/byte evidence, not an assertion
that later mutable Book files remain identical to a published bundle.
