# Handover outcome and Three-Gap binding

MoonBook Bookkeeper is the sole owner of accepted outcomes and Three-Gap
learning. MoonFlow owns collaboration/handover lifecycle; MoonClaw owns agent
execution. Bookkeeper joins their evidence without taking over either runtime.

`moonbook.accepted-handover-outcome.v1` is created only by
`accept_completed_handover_outcome_v1`. It binds:

- the exact MoonFlow handover envelope and portable bundle digests;
- a content-addressed completion receipt and terminal lifecycle head;
- a deliverable whose exact digest is present in the handover bundle;
- an outcome observation that exactly matches the accepted deliverable;
- a named human reviewer, fresh principal-bound authority decision, and
  content-addressed review evidence; and
- a Three-Gap assessment whose subject is the exact outcome version and whose
  finding evidence exists in that outcome.

An anchored comment cannot satisfy acceptance because this API has no comment
input: it requires explicit review evidence and authority. Failed bindings
return typed issues and no accepted record. The accepted record is immutable and
content-addressed; it records learning evidence but does not automatically
change source code, policy, skills, capabilities, or publish anything.
