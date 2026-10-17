# Build an agent teaching brief from reviewed lessons

Use **Bookkeeper → Reviewed lessons** to turn saved experience into an ordered,
agent-readable learning sequence. This is an output/authoring workflow: it neither
executes a learner nor changes accepted knowledge, reviews, task guidance or
permissions.

## Complete journey

1. Browse or search reviewed lessons. Inspect each lesson's scope and choose
   **Add lesson to agent teaching brief**. Selections persist across searches;
   each lesson family may appear once, up to twelve lessons.
2. In **Agent teaching brief**, write a learning objective. Move lessons up/down
   to choose the teaching order. Write an optional fresh practice task for each
   lesson. These are authored instructions, not reviewed Book knowledge or fresh
   model results.
3. Expand **Inspect captured scope, reviews and source-linked examples**. The
   capture includes exact guidance, applicability, invalidation, reviewer/review
   references, source outcome and assessment references. Supported remembered
   examples retain exact inputs, earlier successful outputs, literal checks and
   source case identity under that exact lesson and review.
4. Choose **Recheck all teaching lessons**. The browser reloads all current
   reviewed lessons. Changed, absent, superseded or unreadable captures remain
   visible as old captures. They are never replaced silently. Inspect the current
   lesson/history, explicitly remove an old selection, and add the desired current
   lesson again if appropriate. Keep any exercise text you want before removing.
5. **Download agent teaching brief Markdown** becomes available only when the
   objective is nonblank, at least one lesson is selected, and every captured
   guidance/review/example matches the loaded current host result. Markdown is a
   portable briefing for a human-controlled learning session; sharing it with an
   agent/provider is a separate action. It does not grant tools or operational
   authority, resolve conflicting scopes, or assert actual training.
6. **Save editable teaching-brief JSON** keeps unfinished work even when its
   selections are stale. After a cold reload, paste that JSON under **Resume a
   saved teaching brief**, preview the complete replacement, then explicitly
   replace the open brief. Download the open draft first if you want to retain it.
   A resumed draft must receive a newer host read before Markdown export. A file's
   claimed review labels and digests are not independently authenticated evidence.
7. Study the ordered guidance and examples, try the authored practice tasks in a
   separately authorized session, and return any resulting correction through the
   existing contrasting-case revision and named-human review workflow. The brief
   creates no alternate acceptance lane and records no outcome automatically.

## Examples and exactness

Supported examples use the existing single-example rehearsal and contrasting-case
revision readers. Stored literal results are recomputed before retaining cases.
The cases are still earlier operator reports, not fresh runs or proof of factual
correctness/generalization. An ordinary lesson with no supported example remains
usable guidance and clearly says that no example was captured. Unreadable or
over-limit examples remain in the original record; nothing invents or truncates
a replacement. Retained excerpts are bounded by the existing workbench limits:
six cases, 8192 UTF-16 code units for each input/output, 256 for names/fragments,
and at most twenty total literal fragments per case.

Only curated lesson/review fields and supported examples enter the brief. Raw
payload fields, authority grants, credentials and unrelated records are not
copied. Authored fields and retained text can still be private. Share deliberately.

The JSON schema is `moonbook.agent-teaching-brief.v1`. Its known fields must
round-trip exactly; unsupported fields and schemas are rejected. The objective
and each exercise are bounded to 16384 UTF-16 code units. Complete input and each
download are limited to 1 MiB UTF-8 without truncation. Unmatched Unicode
surrogates are rejected so UTF-8 downloads cannot silently replace characters.
Markdown fences are longer than every backtick run in their literal content, so
captured Markdown/HTML-looking text remains an example. JSON is the editable,
exact field representation; Markdown adds readable headings and fences.

## Interruptions and limitations

For recording fresh responses and feedback beside fixed exercises, continue
into the [agent practice workbook](AGENT_PRACTICE_WORKBOOK.md) below the brief.
Its separate JSON retains observed practice without changing this brief or
accepted lessons.

- The draft and intake are tab-local. Save JSON before closing/reloading.
- An invalid import keeps the open draft. Every new intake invalidates its old
  preview. Edits invalidate detached callbacks and pending replacement controls.
- A pending/failed search or missing current capture blocks Markdown export but
  keeps selections and exercises. Search absence is not proof of deletion.
- Download errors keep the complete draft and report the error. Check browser
  downloads before leaving the tab; requesting a download cannot prove it was
  saved by the browser.
- The export's matching status is current only at the last successful host load.
  Reopen Book and recheck scope/history before later reuse. Order does not infer
  applicability, agreement, prerequisite satisfaction or evidence strength.

## Development evidence boundary

The R661 reproducible synthetic workflow exercises the compiled production
controller, current lesson/case capture, edits/order, strict resumption, source
matching, rendered callbacks and actual Blob contents/cleanup. Its generated
Markdown and JSON use synthetic lessons and reviewer identities. They cannot be
imported into an unrelated real host and treated as freshly reviewed lessons.

Focused JS tests and the learning regression closure pass. The full UI aggregate
still fails at its inherited missing native `MOONBOOK_COLLECTION_WIRE` fixture
(`book_collection_archive_wbtest.mbt:153`, JSON EOF); a later archive evidence
destination is also required by that workflow. No fixture was fabricated. Native
host lifecycle, real browser interaction, providers, customer outcomes, general
learning efficacy and release qualification remain separate blocking/unrun gates.
