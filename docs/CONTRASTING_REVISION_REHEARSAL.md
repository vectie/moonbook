# Rehearse an accepted lesson revision against contrasting cases

This local workbench is inside the existing **Lesson version history → Revise
this accepted version** editor. It is available only when that exact version is
the single current, named-human accepted lesson. Legacy history with no single
current choice still supports its ordinary revision and reviewed selection
flows; choose a current version before using this workbench.

## Operator journey

1. Open current lesson history and start a revision. Inspect the immutable original
   guidance, outcome evidence, and scope. Set the intended revised scope in the
   ordinary editor before beginning a rehearsal.
2. Choose **Start contrasting-case rehearsal**. The revision's guidance and reason
   seed a separate local draft. Edit **Guidance to rehearse** and explain the
   correction in **Your reason for the correction**.
3. Keep two to six distinct example inputs. Include at least one known-useful case
   whose original behavior should remain useful, and one adverse case whose
   original behavior should improve. Add/remove cases using the workbench controls.
4. For every case, supply the output attributed to the original guidance and the
   output attributed to the revised guidance. Supply required and/or forbidden
   literal fragments, one per line, with 1–20 total checks per case.
5. **Compare supplied outputs and literal checks** shows every case and every
   fragment's original/revised pass or fail. Regressions remain visible. Revise
   guidance, supplied outputs, examples, rationale, or checks and compare again.
   Any edit invalidates the old preview.
6. **Stage exact guidance and operator-reported rationale** is available only when
   all known-useful original outputs pass, every revised output passes, and at
   least one adverse original check fails. Staging copies the exact guidance and
   a clearly unverified report into the ordinary revision fields. It sends no
   request and does not change current guidance.
7. Supply an unused version and title if needed, then **Save revision for review**.
   This uses the existing `moonbook.outcome-lesson-revision.v1` request and its
   immutable review-pending candidate. Open that saved change and use the existing
   named-human review controls. No new authority, candidate schema, automatic
   promotion, or current-version selection is introduced.

## Limits and recovery

Guidance, rationale, example input, and each output are limited to 8192 JavaScript
UTF-16 code units. Case names are limited to 256; each literal fragment is limited
to 256. A fragment-list field is limited to 5140. Oversize input is rejected without
truncation. Blank/duplicate fragments, repeated example inputs, malformed cases,
and required fragments that contain a forbidden fragment are rejected.

Drafts survive tab-local navigation, a failed save, and history refresh. Use
[Save and resume correction](SAVED_CORRECTION_DRAFTS.md) to explicitly keep an
unfinished browser-local copy across reload or tab closure; otherwise it is lost.
Resuming requires fresh matching accepted history and a new comparison/staging.
Refreshing to changed current
lesson/reviews, or editing revision guidance, scope, or reason outside the workbench,
keeps the captured cases but blocks stale staging and save. Discard the rehearsal
and begin again from refreshed current history. Title/version metadata can be edited
after staging without changing the sampled guidance. An unchanged transport retry
uses the same ordinary revision identity and payload.

**Discard local rehearsal** removes only the workbench and keeps ordinary revision
fields, including any already-staged text. **Close this change draft** discards the
entire unsaved revision and its local cases. Existing manual lesson drafts,
comparative reuse, scope repair, Proj context, source artifacts, and accepted
history remain unchanged. Pending requests and stale/repeated controls cannot
change a different rehearsal.

## Evidence boundary

The case labels, outputs, and explanation are operator reports. The only computation
is case-sensitive literal inclusion/exclusion on supplied text. No model runs;
there is no automatic causal attribution, factual verification, customer outcome,
generalization claim, or authority grant. The saved reason retains exact supplied
cases, original/revised guidance, fragment results, source lesson reference, and
explicit false model-executed/factual-review/activation flags for human inspection.

This is a narrow local correction-authoring contribution toward MOONBOOK-UC05,
MOONBOOK-F03 and MOONBOOK-R03. It does not qualify all Three-Gap closure, rollback,
provider execution, deployment, or production review behavior.

Tests execute the production embedded JavaScript reducer and compiled MoonBit
controller, payload, save dispatch, and rendered UI. Native host mutation and live
browser interaction are outside this round's verification.
