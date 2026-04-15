---
name: wiki-query
description: Answer a question from the maintained wiki, then decide whether the answer should become durable wiki knowledge.
---

# Wiki Query

Parameters:

- QUESTION: the user question

Method:

1. Read `wiki/index.md` first, then the highest-signal related pages.
2. Prefer maintained wiki pages over raw sources unless you are checking a gap or contradiction.
3. Answer with citations to page paths.
4. If the answer creates durable value, add or update a maintained page instead of leaving the insight in chat only.
