---
name: commit
description: Commit changes following the project's gerrit commit conventions
---

# Before writing

- Review `git diff` and `git diff --staged` first.
- One commit per logical unit of work — split unrelated changes.

# Message format

`topic: subject` — lowercase topic, imperative subject. The topic is the area touched: `call`, `conversation`, `settings`, `build`, …
- Subject ≤50 chars
- Body lines ≤72 chars, blank line between subject and body; keep the body concise and to the point