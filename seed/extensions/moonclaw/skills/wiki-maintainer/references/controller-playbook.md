# Controller Playbook

## Stage order

1. discover sources
2. prepare materials
3. revise durable pages
4. review output

## Split tasks when

- multiple repos are involved
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
