# Keeper Call Chain

This document traces the current MoonBook keeper workflow in detail, from `wiki ingest` packet emission to MoonClaw workflow execution.

It covers:

- the static call chain in MoonBook
- the cross-repo handoff into MoonClaw
- the workflow compilation and execution path in MoonClaw
- the current observed runtime state from the integration run on `2026-04-13`

It does not describe an idealized future design. It describes the code path that exists now.

## Scope

The call chain below is specifically for:

```bash
moon run cmd/main -- wiki ingest <root> <source>
moon run cmd/main -- wiki keeper submit <root> --latest --moonclaw <moonclaw-root> --home <home> --confirm
```

The example live workspace used during inspection was:

- workspace root: `/tmp/moonbook-confirm-check-3`
- packet: `/tmp/moonbook-confirm-check-3/keeper/jobs/ingest-confirm-demo-three.json`
- MoonClaw home: `/Users/kq/.moonclaw`
- MoonClaw repo: `/Users/kq/Workspace/moonclaw`

## High-Level Shape

The current runtime split is:

1. MoonBook ingests a source and emits a keeper packet.
2. MoonBook submit CLI shells out to MoonClaw `proposal import`.
3. MoonClaw imports the external packet into its proposal store.
4. MoonClaw applies the named profile from `moonclaw.jobs.json`.
5. MoonClaw compiles the proposal into a job definition plus workflow definition.
6. MoonClaw executes the controller workflow step by step.
7. Analysis steps produce `keeper.plan.packet.v1` outputs.
8. Delegate steps spawn child runs that edit or review the wiki.

MoonBook now owns the semantic ingest graph for the domain. For ingest, the intended phase graph is:

1. `bootstrap_gather`
2. `source_materialize`
3. `knowledge_revise`
4. `review_finalize`

MoonClaw still compiles the packet into the current executable workflow profile.

The current ingest workflow profile is seeded by MoonBook under `moonclaw.jobs.json` and still compiles into controller steps that look like:

1. `inspect_source`
2. `plan_revisions`
3. `apply_revisions`
4. `review_revisions`
5. `finalize_ingest`

## Phase 1: MoonBook CLI Dispatch

Entry point:

- `cmd/main/main.mbt`

Relevant call chain:

1. `main()`
2. `run_wiki(args)`
3. `run_wiki_ingest(root, source)` for ingest
4. `run_wiki_keeper_submit(args)` for submit

The keeper submit command is registered under:

- `moonbook wiki keeper submit [root] <packet.json> ...`
- `moonbook wiki keeper submit [root] --latest ...`

## Phase 2: MoonBook Defines the Semantic Ingest Phases

Source:

- `wiki/ingest.mbt`

Primary function:

- `ingest_source(root, source_path)`

What it does:

1. Resolves workspace directories with `workspace_paths(root)`.
2. Ensures `raw/`, `wiki/sources/`, `wiki/entities/`, `wiki/concepts/`, `wiki/synthesis/`, `wiki/queries/`, and `wiki/reviews/` exist.
3. Resolves and optionally imports the source into `raw/` or `raw/imported/`.
4. Detects a source title.
5. Decides the semantic phase graph for the domain:
   - `bootstrap_gather`
   - `source_materialize`
   - `knowledge_revise`
   - `review_finalize`
6. Creates the source page under `wiki/sources/<slug>.md`.
7. Runs `enrich_ingest(...)` to update maintained wiki pages.
8. Emits a keeper packet with `emit_ingest_keeper_packet(...)`.
9. Updates:
   - `wiki/SUMMARY.md`
   - `wiki/index.md`
   - `wiki/log.md`

The ingest result contains:

- `page_path`
- `raw_path`
- `title`
- `related_pages`
- `keeper_packet_path`

## Phase 3: MoonBook Emits the Keeper Packet With Phase Intent

Source:

- `wiki/ingest.mbt`

Function:

- `emit_ingest_keeper_packet(...)`

Output location:

- `<root>/keeper/jobs/ingest-<slug>.json`

Current live example:

- [`/tmp/moonbook-confirm-check-3/keeper/jobs/ingest-confirm-demo-three.json`](/tmp/moonbook-confirm-check-3/keeper/jobs/ingest-confirm-demo-three.json)

Packet fields currently written by MoonBook:

- `title`
- `request`
- `profile`
- `output_contract`
- `semantic_phases`
- `execution_mode`
- `max_parallel_workers`
- `gather_lanes`
- `source_path`
- `source_page`
- `context_pages`
- `related_pages`
- `skill_paths`
- `notes`

Example packet semantics:

- `profile: "wiki_ingest_controller"`
- `output_contract: "keeper.plan.packet.v1"`
- `source_path: "raw/demo.md"`
- `source_page: "wiki/sources/confirm-demo-three.md"`

MoonBook's semantic intent for the packet is now:

- `bootstrap_gather`
  - gather high-signal source material and write `raw/bootstrap/*`
- `source_materialize`
  - turn raw packets into durable `wiki/sources/*`
- `knowledge_revise`
  - revise `wiki/entities/*`, `wiki/concepts/*`, and synthesis pages
- `review_finalize`
  - verify artifacts, blockers, and final promotion status

MoonBook's execution intent is now also explicit in the packet:

- `execution_mode: "parallel-lane-bootstrap"`
- `max_parallel_workers: 4`
- `gather_lanes`
  - docs
  - implementation
  - architecture

The keeper is expected to preserve these lane specs and ask MoonClaw to execute them as separate bounded workers when the source surface is broad.

MoonClaw may still compile these semantics into the current runtime steps, but the semantic owner is MoonBook.

Current packet context pages:

- `wiki/index.md`
- `wiki/log.md`
- `wiki/sources/<slug>.md`
- `wiki/synthesis/overview.md`
- `wiki/synthesis/claims.md`
- `wiki/synthesis/maintenance-plan.md`
- `wiki/reviews/pending.md`
- `RESOLVER.md`

Current packet skill paths:

- `skills/wiki-ingest/SKILL.md`
- `skills/source-diarize/SKILL.md`
- `skills/entity-revise/SKILL.md`
- `skills/concept-revise/SKILL.md`
- `skills/synthesis-revise/SKILL.md`
- `skills/claim-audit/SKILL.md`
- `skills/contradiction-review/SKILL.md`
- `skills/review-decision/SKILL.md`
- `skills/index-maintain/SKILL.md`

## Phase 4: MoonBook Submit CLI Normalizes Arguments and Seeds Runtime Files

Source:

- `cmd/main/main.mbt`

Functions:

- `parse_wiki_keeper_submit_args(...)`
- `ensure_wiki_keeper_submit_runtime(root)`
- `latest_keeper_packet_path(root)`
- `resolve_keeper_packet_path(root, packet_path)`
- `default_moonclaw_root()`

Detailed flow:

1. Parse flags:
   - `--confirm`
   - `--latest`
   - `--home`
   - `--cwd`
   - `--moonclaw`
2. Determine the workspace root.
3. Resolve the packet path:
   - explicit packet path, or
   - newest file under `<root>/keeper/jobs/`
4. Ensure MoonClaw runtime files exist in the workspace:
   - if `moonclaw.jobs.json` already exists, continue
   - otherwise call `@wiki.enable_extension(root, "moonclaw")`

This means `wiki keeper submit` is not purely a transport layer. It may mutate the workspace by seeding the MoonClaw extension pack before submission.

## Phase 5: MoonBook Extension Seeding

Source:

- `wiki/extensions.mbt`

Function:

- `enable_extension(root, "moonclaw")`

Current seeded files:

- `moonclaw.json`
- `moonclaw.jobs.json`
- `IDENTITY.md`
- `USER.md`
- `ROUTINES.md`
- `MEMORY.md`
- `KEEPER.md`
- `skills/wiki-maintainer/SKILL.md`
- `skills/wiki-review/SKILL.md`
- `.moonbook/extensions/moonclaw.json`

The current inspected workspace also contains a broader skill set under `skills/`, including:

- `wiki-ingest`
- `source-diarize`
- `entity-revise`
- `concept-revise`
- `synthesis-revise`
- `claim-audit`
- `contradiction-review`
- `review-decision`
- `index-maintain`

So the live workspace can satisfy the packet skill references.

## Phase 6: MoonBook Shells Out to MoonClaw

Source:

- `cmd/main/main.mbt`

Function:

- `run_wiki_keeper_submit(args)`

After argument parsing and runtime seeding, MoonBook executes:

```text
moon -C <moonclaw_root> run cmd/main -- proposal import <packet_path> --json --cwd <cwd> [--home <home>] [--confirm]
```

This is the actual cross-repo handoff boundary.

MoonBook does not import MoonClaw as a library here. It invokes MoonClaw as a separate CLI process.

## Phase 7: MoonClaw CLI Receives the Packet

Sources:

- `/Users/kq/Workspace/moonclaw/cmd/main/main.mbt`
- `/Users/kq/Workspace/moonclaw/cmd/main/proposal/main.mbt`

Call chain:

1. `main()`
2. `@proposal.start(rest)`
3. `import_packet(args, packet_path)`

Inside `import_packet(...)`:

1. Resolve `home`
2. Resolve `cwd`
3. Instantiate `WorkspaceRuntime`
4. Instantiate `GatewayJobApp`
5. `app.load()`
6. `app.import_external_proposal_packet_file(packet_path, confirm=...)`

## Phase 8: MoonClaw Parses and Normalizes the External Packet

Source:

- `/Users/kq/Workspace/moonclaw/job/external_proposal_packet.mbt`

Main functions:

- `parse_external_proposal_packet_text(...)`
- `import_external_proposal_packet_file(...)`
- `import_external_proposal_packet(...)`
- `proposal_with_external_packet(...)`
- `external_packet_job_intake(...)`
- `external_proposal_packet_metadata(...)`
- `external_packet_step_metadata(...)`

Important normalization behavior:

1. Packet is parsed into `ExternalProposalPacket`.
2. The requested profile is looked up with:
   - `load_job_profile(self.home, self.cwd, packet.profile)`
3. Relative packet paths are resolved against the external workspace root:
   - `context_pages`
   - `skill_paths`
   - `source_path`
   - `source_page`
   - `related_pages`

This path-resolution step matters because the old failure mode was resolving packet paths against the MoonClaw repo instead of the wiki workspace.

The normalized metadata injected into the proposal includes:

- `external_packet.source_path`
- `external_packet.profile`
- `external_packet.context_pages`
- `external_packet.skill_paths`
- `external_packet.resolved_context_pages`
- `external_packet.resolved_skill_paths`
- `external_packet.related_pages`
- `external_packet.workspace_root`

The normalized step metadata also injects:

- resolved `context_pages`
- resolved `skill_paths`
- resolved `related_pages`
- `source_path`
- `source_page`
- `output_contract`
- merged `preferred_skills`

## Phase 9: MoonClaw Applies the Named Profile

Source:

- `/Users/kq/Workspace/moonclaw/job/external_proposal_packet.mbt`
- seeded `moonclaw.jobs.json` from `wiki/extensions.mbt`

Profile in this flow:

- `wiki_ingest_controller`

This profile is controller-shaped and defines the step graph:

1. `inspect_source`
2. `plan_revisions`
3. `apply_revisions`
4. `review_revisions`
5. `finalize_ingest`

Key design properties of this profile:

- controller role
- planner-first analysis for the first two steps
- delegate steps for revision and review
- worker profiles:
  - `wiki_revision_worker`
  - `wiki_review_worker`

The controller metadata declares:

- `planning_layer: domain`
- `runtime_mode: planner_only`
- `tool_access: limited`
- `allow_delegate: true`
- `allow_workspace_write: false`
- `output_contract: keeper.plan.packet.v1`

The worker profiles declare execution-oriented metadata, including:

- `planning_layer: execution`
- `runtime_mode: executor`
- `tool_access: full`
- `allow_workspace_write: true` for `wiki_revision_worker`
- `allow_workspace_write: false` for `wiki_review_worker`

## Phase 10: MoonClaw Compiles Proposal to Runtime Workflow

Source:

- `/Users/kq/Workspace/moonclaw/job/compiler.mbt`

Primary functions:

- `compile_job_proposal(...)`
- `workflow_steps_for_proposal(...)`
- `workflow_step_definition_for_proposal_step(...)`

Compilation behavior:

1. Create a `JobDefinition`
2. Create a `WorkflowDefinition`
3. Convert profile steps to runtime workflow steps

Step conversion rules:

- `job.analysis` becomes `AnalysisStepConfig`
- `job.delegate` becomes `SubjobStepConfig`

For analysis steps, the compiler sets:

- `prompt`
- `cwd`
- `home`
- `workspace`
- `preferred_skills`
- `enable_tools`
- `web_search`
- `policy`
- artifact config
- metadata

For delegate steps, the compiler sets:

- `request_text`
- `cwd`
- `home`
- `child_profile`
- `execution_mode`
- `execution_target`
- `include_parent_outputs`
- `max_depth`

Important current detail:

- analysis steps are compiled with `AnalysisPolicy::new(skip_if_artifact_exists=false)`
- no timeout is injected by this compiler path unless added elsewhere

## Phase 11: MoonClaw Confirms Proposal and Starts the Run

Source:

- `/Users/kq/Workspace/moonclaw/job/external_proposal_packet.mbt`

Functions:

- `confirm_proposal_and_execute(...)`
- `execute_definition(...)`

Execution flow:

1. Confirm proposal
2. Register definition and workflow in runtime storage
3. Trigger a run with `trigger_definition(...)`
4. Start workflow execution with `execute_run_lifecycle(...)`

The current inspected controller run is:

- run id: `run-20260413-205053-usersk`
- job id: `job.proposal.20260413-205053-run-the-skill-driven-wiki-ingest-usersk`

Run metadata file:

- [`/Users/kq/.moonclaw/jobs/runs/run-20260413-205053-usersk/meta.json`](/Users/kq/.moonclaw/jobs/runs/run-20260413-205053-usersk/meta.json)

## Phase 12: Workflow Engine Executes Steps

Source:

- `/Users/kq/Workspace/moonclaw/job/workflow_engine.mbt`

Primary function:

- `WorkflowEngine::execute_run(...)`

Detailed loop:

1. Load run
2. Load job definition
3. Load workflow definition
4. Mark run started or resumed
5. For each workflow step:
   - resolve handler by `step.kind`
   - mark step `Running`
   - emit `step.started`
   - build `WorkflowStepContext`
   - run step handler
   - on success:
     - save succeeded step record
     - checkpoint workspace
     - emit `step.succeeded`
     - record controller decision from output
     - store step output in `outputs`
   - on waiting-for-input:
     - mark step and run `WaitingForInput`
   - on error:
     - mark step and run failed

Current event log for the controller run:

- [`/Users/kq/.moonclaw/jobs/runs/run-20260413-205053-usersk/events.jsonl`](/Users/kq/.moonclaw/jobs/runs/run-20260413-205053-usersk/events.jsonl)

## Phase 13: Analysis Step Handling

Source:

- `/Users/kq/Workspace/moonclaw/job/analysis.mbt`
- `/Users/kq/Workspace/moonclaw/job/adaptive_policy.mbt`

Entry:

- `analysis_step_handler(...)`

Important behavior:

1. Decode `AnalysisStepConfig`
2. Build `AnalysisRequest`
3. Run analysis executor
4. Persist artifacts
5. Pass result through adaptive policy

Relevant adaptive rule:

- `resolved_adaptive_envelope(...)`

Special-case logic:

- if the analysis content is already a completed keeper packet, adaptive follow-up is skipped

That special case is implemented by:

- `is_completed_keeper_plan_packet(execution.content)`

This is why the controller can accept raw `keeper.plan.packet.v1` JSON from planner steps without trying to force another adaptive subplan.

## Phase 14: Delegate Step Handling

Source:

- `/Users/kq/Workspace/moonclaw/job/subjob.mbt`

Entry:

- `subjob_step_handler(...)`

Detailed flow:

1. Decode `SubjobStepConfig`
2. Build child request text with `compiled_subjob_request(...)`
3. If `include_parent_outputs=true`, append parent step outputs to the child request
4. Produce a child proposal:
   - planner route, or
   - provider-backed route
5. Apply named child profile
6. Apply isolation metadata
7. Apply execution override if present
8. Compile child proposal into child job + workflow
9. Save child proposal
10. Register child definition + workflow
11. Trigger child run
12. Execute child run locally unless an external child executor handles it
13. Return a parent step result containing:
   - `child_job_id`
   - `child_run_id`
   - `child_family`
   - `child_outputs`

This is the execution boundary used by:

- `apply_revisions`
- `review_revisions`

## Phase 15: Current Observed Live Run

This section records the actual inspected run state on `2026-04-13`, not the intended future state.

Controller run:

- `run-20260413-205053-usersk`

Observed step status:

1. `inspect_source`
   - succeeded
   - produced a valid `keeper.plan.packet.v1`
2. `plan_revisions`
   - succeeded
   - produced a valid `keeper.plan.packet.v1`
3. `apply_revisions`
   - succeeded
   - spawned child run `run-20260413-205403-usersk`
4. `review_revisions`
   - still running at inspection time
5. `finalize_ingest`
   - not started yet at inspection time

Relevant step files:

- [`inspect_source.json`](/Users/kq/.moonclaw/jobs/runs/run-20260413-205053-usersk/steps/inspect_source.json)
- [`plan_revisions.json`](/Users/kq/.moonclaw/jobs/runs/run-20260413-205053-usersk/steps/plan_revisions.json)
- [`apply_revisions.json`](/Users/kq/.moonclaw/jobs/runs/run-20260413-205053-usersk/steps/apply_revisions.json)
- [`review_revisions.json`](/Users/kq/.moonclaw/jobs/runs/run-20260413-205053-usersk/steps/review_revisions.json)

### Observed `inspect_source` output

The first planner step produced a packet that:

- identified what was new in the source
- assessed affected pages
- recommended:
  - revisions to source and synthesis pages
  - new entity pages
  - a new concept page
  - claim capture

Artifact:

- [`step-inspect_source-inspect-source.json`](/Users/kq/Workspace/moonclaw-workspace/moonclaw-jobs/run-20260413-205053-usersk/outputs/step-inspect_source-inspect-source.json)

### Observed `plan_revisions` output

The second planner step produced a more explicit revision plan covering:

- `wiki/entities/moonbook.md`
- `wiki/entities/moonclaw-keeper.md`
- `wiki/concepts/workflow.md`
- updates to:
  - `wiki/sources/confirm-demo-three.md`
  - `wiki/synthesis/overview.md`
  - `wiki/synthesis/claims.md`
  - `wiki/synthesis/maintenance-plan.md`
  - `wiki/synthesis/map.md`
  - `wiki/index.md`
  - `wiki/log.md`

Artifact:

- [`step-plan_revisions-plan-revisions.json`](/Users/kq/Workspace/moonclaw-workspace/moonclaw-jobs/run-20260413-205053-usersk/outputs/step-plan_revisions-plan-revisions.json)

### Observed `apply_revisions` output

The delegate step completed and returned:

- child job id: `job.proposal.20260413-205350-apply-the-approved-wiki-revision-usersk`
- child run id: `run-20260413-205403-usersk`

The returned summary states that the child run edited the wiki and created:

- [`/tmp/moonbook-confirm-check-3/wiki/entities/moonbook.md`](/tmp/moonbook-confirm-check-3/wiki/entities/moonbook.md)
- [`/tmp/moonbook-confirm-check-3/wiki/entities/moonclaw-keeper.md`](/tmp/moonbook-confirm-check-3/wiki/entities/moonclaw-keeper.md)
- [`/tmp/moonbook-confirm-check-3/wiki/concepts/workflow.md`](/tmp/moonbook-confirm-check-3/wiki/concepts/workflow.md)

These files do exist in the target workspace now.

So the current state is stronger than the earlier failure diagnosis:

- the handoff works
- planner steps work
- revision delegation also works
- the remaining open step is review/finalization

## Phase 16: Data Boundaries

Current ownership by phase:

- MoonBook owns:
  - workspace layout
  - source ingestion
  - initial wiki maintenance
  - keeper packet emission
  - extension seeding
  - durable `wiki/*` materialization from raw research envelopes
- MoonClaw owns:
  - proposal import
  - packet normalization
  - runtime metadata merge
  - workflow compilation
  - controller execution
  - delegate child runs
  - bounded research/tool execution that writes `raw/bootstrap/*` artifacts
- The wiki workspace itself is the shared state boundary:
  - MoonClaw writes raw research artifacts under `raw/bootstrap/`
  - MoonBook promotes complete envelopes into `wiki/sources/`, `wiki/entities/`, `wiki/concepts/`, and synthesis pages

This is currently a process boundary plus shared-filesystem integration, not a linked in-process API.

## Current Gaps Exposed by the Call Chain

The call chain is functional, but still exposes some important realities:

1. The integration is CLI-mediated, not library-mediated.
2. The workspace may be mutated during submit if runtime files are missing.
3. The controller run is still open until review and finalization complete.
4. Analysis steps are compiled without a default timeout in this path.
5. The revision child run should now finalize the raw research envelope instead of claiming durable wiki ownership.

## Short Summary

Today’s keeper call chain is:

1. MoonBook ingests source.
2. MoonBook writes a keeper packet.
3. MoonBook ensures extension runtime files exist.
4. MoonBook shells out to MoonClaw `proposal import`.
5. MoonClaw parses packet and resolves workspace-relative paths.
6. MoonClaw applies `wiki_ingest_controller`.
7. MoonClaw compiles controller steps into a workflow.
8. Controller planner steps emit `keeper.plan.packet.v1`.
9. Delegate steps spawn child runs that gather and finalize `raw/bootstrap/` research artifacts.
10. MoonBook persists the result and materializes complete research envelopes into durable wiki pages.
11. Review step validates the result before finalization.

At inspection time, the desired chain is no longer “MoonClaw edits wiki pages.” It is “MoonClaw returns a strict research envelope; MoonBook decides what becomes durable wiki state.”
