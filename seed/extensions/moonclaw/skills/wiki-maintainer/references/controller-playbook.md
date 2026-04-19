# Controller Playbook

## Stage order

1. fan out gather lanes
2. prepare materials
3. revise durable pages
4. review output

## Preferred gather lanes

When the task spans several repos, systems, or evidence types, split gather into:

1. docs lane
2. implementation lane
3. architecture lane
4. optional cross-project lane

Each lane should stay narrow and produce explicit packet-ready evidence.
If the imported keeper proposal already includes lane specs, preserve them as the default fan-out plan.

## Split tasks when

- multiple repos are involved
- the gather phase needs different evidence types
- one worker can gather while another revises
- the controller needs a review pass before final persistence

## Do not split tasks when

- the task is too small to justify delegation
- later stages depend on artifacts that do not exist yet

## Required intermediate artifacts

Before the revise stage starts, the controller should be able to point to:

- one or more `raw/bootstrap/*` packets
- concrete inspected source paths
- candidate entities and concepts

If those do not exist, keep the run in gather/blocker mode.

## Anti-pattern

Do not assign one gather worker to "research the whole system" and hope the runtime will recover.
If gather is broad, split before prepare.
