# Compare reviewed approaches for a later task

MoonBook now connects the existing task-scoped reviewed-lesson results to a
comparative reuse workbench. A person can compare two to four accepted approaches
on the same supplied next-task example, inspect individual check differences,
and return one explicitly chosen exact version through the existing Proj guidance
handoff. This is useful when several learned approaches fit the task but their
tradeoffs are difficult to see across separate cards.

This extends outcome-linked memory (MOONBOOK-R02 and the founder/researcher job in
the 30 September 2026 MoonBook PRD). It preserves B05/R03's named-review boundary.
Unlike **Teach once**, which prepares a proposed correction from one original and
corrected example, this workflow compares already-reviewed approaches before
reusing one. It neither authors a new lesson nor changes which version is current.

## User path

1. Open Book guidance from the intended Proj task and receive its exact task
   snapshot. Add truthful scope conditions and choose **Find useful lessons**.
   Ordinary manually entered task queries can also use comparison, but returning
   guidance requires a real received Proj handoff.
2. Choose **Add to approach comparison** on two to four matching reviewed cards.
   The workbench shows their original guidance, applicability, invalidation,
   named reviewers and exact lesson/source references side by side.
3. Describe one fixed next-task example. Supply an output obtained or written
   using each approach for that same example, and shared required literal text,
   one check per line. There are no provider calls or hidden generated outputs.
4. Choose **Compare these supplied outputs**. Each column shows its pass count
   and every individual pass/failure in the same check order. A high total cannot
   hide a failed requirement. Multiple all-pass columns remain a tie; there is no
   ranking, recommendation or automatic winner.
5. Inspect the actual text, scope and evidence. Confirm the exact Proj destination
   using the existing handoff control. For an all-pass supplied output, choose
   **Use this compared guidance for [task]**. This invokes the existing host
   `guidance-select` revalidation and existing acknowledged Proj message bridge.
   A superseded, rejected or newly inapplicable lesson still fails at that boundary.
6. Return to Proj and decide whether to Start. Comparison itself never starts a
   task. The normal bounded selection contains the exact reviewed guidance and
   reference chain; the supplied example, outputs and check results are not sent.

The ordinary direct guidance-selection controls remain available for decisions
that do not use this optional comparison. Passing literal checks is not a new
product-wide acceptance rule or a substitute for human judgment.

## Honest evidence boundary

Checks are case-sensitive substring matching, not a factual or semantic evaluator.
MoonBook cannot verify that a person actually used a particular procedure to
produce a supplied output, that the example is novel, or that the same method
will succeed later. An output that contains the requested words can still be wrong.
The UI states these limits. The result is explicitly
`operator_supplied_comparative_reuse`, with `model_executed: false` and
`activation_authorized: false`.

The comparison is tab-local draft work, not a durable evaluation, journal event,
accepted memory, new human review, capability adoption, or portable-agent change.
Reloading the tab loses it. There is no provider, runtime, database or new network
operation for comparison; only an explicit final choice uses the existing
read-only host selection and previously confirmed Proj destination.

## Guards and recovery

- A shortlist entry binds the exact lesson ID/version/digest, reviewed guidance,
  applicability/invalidation, named reviewer and receipt, original source
  references and current-selection review observed in the task retrieval.
- Only a complete named-human accepted lesson within all query conditions and
  with no matching invalidation condition can enter. Unknown candidate schemas,
  duplicate exact results, wrong subjects and incomplete source references fail
  visibly rather than being treated as accepted approaches.
- The native retrieval's existing legacy-unselected behavior is unchanged. This
  UI does not call every legacy version “current” or invent a version order.
- Each edit to the shortlist, input, outputs or checks invalidates comparison.
  Changed task identity/scope or changed retrieved lesson/review/selection bytes
  makes the old comparison unusable while retaining supplied text for inspection.
  An identical exact retrieval can resume it. The final host always rechecks.
- Rendered commands carry a draft revision. Older commands cannot clear, compare,
  choose or remove newer work. While a host request is pending, comparison edits,
  clear, repeat compare and duplicate Use are blocked.
- **Remove this approach** and **Clear comparison and keep lesson draft** remain
  usable even when retrieval is unavailable or malformed. Clear removes only
  comparison state; authoring, source binding and task-handoff state remain intact.
- A host error preserves the entire comparison for recovery. No Proj return is
  claimed unless the existing exact-payload acknowledgement arrives.
- Use 1–20 unique nonblank checks, at most 512 UTF-16 code units each. Line-end
  whitespace is trimmed. Each input/output is at most 16,384 UTF-16 code units;
  over-limit input is rejected without truncation.

## Implementation

- `ui/rabbita-book/main/lesson_comparison_state.mbt`: production deterministic
  controller, exact-snapshot guard, event adapter to existing selection.
- `ui/rabbita-book/main/lesson_comparison_view.mbt`: responsive side-by-side
  comparison, inputs, evidence disclosure, per-check results and explicit Use.
- `outcome_lesson_state.mbt` and `outcome_lesson_workspace_view.mbt`: reachable
  ordinary Bookkeeper state/event/view integration.
- `lesson_rehearsal_view.mbt`: minimal adjacent repair of prior `Json.Bool`
  patterns to the pinned compiler's `True`/`False` cases. This pre-existing
  compile error was first exposed when the exact current UI was compiled here.

No host schemas, journal admission, currentness rules, source evidence or
portable memory semantics were changed.

## Verification

Cwd-independent production controller tests, requiring only Node:

```sh
node --test /absolute/path/to/source/scripts/lesson-comparison.test.mjs
```

Pinned-cloud reproducible focused runner:

```sh
/absolute/path/to/source/scripts/test-lesson-comparison.sh
```

The runner uses the exact saved toolchain environment, private HOME/XDG and an
absolute external target directory. It copies the current standalone Book UI
module and the approved Rabbita 0.12.4 cache without installing or upgrading
anything. It never creates a missing Leaf or changes the integrated workspace.
Each invocation creates a new evidence directory and preserves prior failures.

Author verification passed 18 new Node controller cases plus 9 prior rehearsal
cases; 4 new compiled UI tests; 3 prior compiled rehearsal tests; 7 prior lesson
state tests; 7 prior browser tests; and 4 prior guidance tests. The new compiled
UI test exercises the real comparison events/rendering and existing destination
confirmation, host fetch, bounded guidance wire and acknowledgement, using
synthetic host/browser fixtures. It also verifies host rejection without a
return. This is not a real browser or native-host run.

Standalone current UI `moon check`, `moon info` and `moon fmt` pass, with existing
warnings and no public interface changes. Integrated root check/info/fmt still
stop at missing `../moonleaf`. Native journal/runtime, real browser layout,
MoonProj service, providers and release acceptance remain unqualified. Previous
R562 source-only qualification and its original failures remain historical
records; these newer bounded results do not rewrite them.
