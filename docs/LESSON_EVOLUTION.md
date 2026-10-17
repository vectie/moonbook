# Explore how a lesson evolved

Open **Bookkeeper → Lesson version history**, select a saved lesson, and choose
**Open selected lesson history**. The **Explore how this lesson evolved** panel
connects that family's stored versions, human reviews and retained teaching
examples in one comparison.

## A useful review journey

1. Choose **Use version … as baseline** and **Use version … as target** for two
   different saved versions. Pending and rejected alternatives are available
   alongside accepted versions, with their actual review state visible.
2. Read the complete guidance and scope side by side. The guidance section shows
   exact added, removed and unchanged lines. Applicability and invalidation
   conditions have separate added/removed/unchanged lists. A scope change is not
   labelled wider or safer automatically; the reviewer must interpret it.
3. Read the author's reason, named review history, and original outcome and
   assessment references. An explicit predecessor link is labelled when the
   target records the baseline as its predecessor. Otherwise this is simply
   your selected comparison; lexical version names do not establish chronology.
4. Explore **Teaching experience across versions**. The saved single-example and
   contrasting-revision formats are connected through exact complete input text.
   Each pair shows the original recorded output under each version and that
   version's required/forbidden literal fragments. A renamed case stays paired;
   changed input, including whitespace, stays separate. An absent example means
   only that this version's saved report does not contain it, not that behavior
   was forgotten. Unreadable reports remain a visible limitation.
5. **Swap comparison direction** when examining an older accepted version as a
   possible restore target. The ordinary version inspection, revision and restore
   controls remain the way to propose a change for named-human review.
6. Choose **Download printable lesson evolution HTML** for a standalone readable
   report, or **Download lesson evolution JSON** for a structured captured output.
   Inspect browser downloads before leaving. Neither output is an import format,
   an attestation or a way to accept/select a version.

For example, a source-citation lesson can evolve to preserve a useful direct
answer while adding an adverse example that refuses to promise a precise export
hour the source never stated. Comparing the retained output and new uncertainty
example makes that intended correction visible alongside its narrower source
conditions, rather than inferring learning from a changed digest.

## Preservation, bounds and interruptions

- This is a read-only projection of one loaded lesson family. It does not change
  journal records, accepted guidance, named reviews, authoring drafts, the decision
  notebook, current-version selection or task authority.
- Current labels mean current at the last successful history load. Refreshing
  disables comparisons and downloads until a successful read. A failed refresh
  does not restore the old snapshot's availability as fresh. Exact selections
  are retained, but a version missing from refreshed history must be chosen again.
- Detached controls bind the request generation and comparison revision. Changing
  a pair or starting a history refresh invalidates earlier callbacks. Downloads
  capture the chosen report; repeated clicks while pending do not duplicate the
  request. Failures keep the pair, and an old completion cannot relabel a new pair.
- Guidance alignment uses a longest-common-subsequence line comparison, bounded
  to 256 lines per side. Larger inputs retain complete before/after blocks. Lines
  are exact, including Unicode, whitespace and CR characters; conditions compare
  exact key/value pairs without interpreting them as policies.
- JSON and HTML outputs are independently bounded to 1 MiB UTF-8. Oversize
  outputs are refused without truncation. Original records remain in history.
- Exported fields are curated guidance, conditions, selected source/review
  references, reviewer summaries, author rationale and recorded examples. Unknown
  payload fields, grants and credentials are not included. Known fields can still
  contain private authored text; share downloaded files only with intended readers.
- HTML has no scripts or external resources and uses a restrictive content
  security policy. JSON is a captured report, not independently authenticated
  evidence. A named review does not make operator-reported output a fresh run,
  factual verification, generalized learning or a customer outcome.
- Pair selection is tab-local and is not automatically persisted. A downloaded
  report remains readable offline; it does not restore an editing session.

## PRD contribution and qualification

This is a bounded exploration/output contribution to **MOONBOOK-F03/R03**:
reviewing how a reusable rule changed without deleting its earlier evidence.
It also contributes to **MOONBOOK-F02/R02** by exposing applicability and recorded
experience when deciding whether to reuse a version. It does not establish the
complete cross-product receipt chain or Three-Gap closure. UC05's existing
named-human acceptance boundary is preserved and not requalified here.

Focused compiled MoonBit tests exercise the actual existing controller, rendered
click callbacks, history integration, exact comparisons and production Blob
download effects using synthetic fixtures. JS check/build, info and formatting
are separate evidence. No live browser, native host mutation, provider execution,
customer outcome, accepted knowledge, generalized model improvement or deployed
release qualification is implied.

The full UI aggregate remains a separate blocking gate. Its native collection
fixture needs `MOONBOOK_COLLECTION_WIRE` and later `MOONBOOK_ARCHIVE_EVIDENCE`.
An unset wire produces the known JSON EOF at
`book_collection_archive_wbtest.mbt:153`; focused passes do not waive that gate.
No fabricated fixture or substitute MoonLeaf dependency is supplied here.
