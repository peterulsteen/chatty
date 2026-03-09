# RATIONALE.md

Running log of decisions made during operationalization of the chatty backend.
Updated with each task. Never delete entries.

---

## Task 0 — Bootstrap

### Commented out drop_all
`Base.metadata.drop_all` in `main.py` was active in the initial commit — nukes the
DB on every restart. Commented out to prevent data loss in any environment beyond
solo local iteration.

---

## AI Use

This project uses Claude Code (claude-sonnet-4-6) as a pair-programming assistant
throughout the operationalization work. All code changes are reviewed and approved
by the engineer before commit. Claude is used to:

- Draft and refine implementation within task scope
- Catch deprecated patterns and surface trade-offs
- Keep RATIONALE.md, TASKS.md, and README.md consistent with actual changes
- Enforce the atomic change rule (flag when a change touches too many files)

Claude does not autonomously push, merge, or open PRs without explicit instruction.
Commit messages and branch names are chosen by the engineer.
