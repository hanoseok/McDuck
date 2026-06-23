---
type: Module
title: Codex Skills
description: Repository-owned Codex workflow skills with thin installed personal pointers.
resource: https://github.com/hanoseok/McDuck/tree/develop/skills
tags: [module, codex, skills, workflow]
timestamp: 2026-06-23T01:02:55Z
---
# Responsibility

`skills/` stores McDuck-specific Codex workflow skills so their real instructions are versioned with the project.

Installed personal skill directories should remain thin pointers that tell Codex to open the matching repository skill. This prevents the installed copy from drifting away from the project-owned workflow.

# Current Skills

* `skills/mcduck-start/SKILL.md` - `/mcduck:start <issue-number>` planning workflow for GitHub issue driven work. It freezes the issue body's original text, rewrites only the managed plan block, stores status as `{기획중}`, and keeps updating the plan until `/McDuck:go`.
* `skills/mcduck-go/SKILL.md` - `/McDuck:go` development workflow for planned GitHub issue work. It gates on `{기획중}` or `개발완료`, preserves original issue text, updates only the managed summary, enforces TDD, commits meaningful units, verifies, creates a snapshot, and ends at `개발완료`.
* `skills/mcduck-finish/SKILL.md` - `/McDuck:finish` cleanup workflow for `개발완료` issue work. It verifies final state, merges the feature branch to `develop`, writes wiki cleanup, removes feature worktrees/branches, creates a develop snapshot, closes the GitHub issue, and ends at `(완)`.
* `skills/mcduck-release/SKILL.md` - `/McDuck:release` formal release workflow. It compares the previous formal release with current `develop`, reviews intervening snapshots, drafts Korean release notes, asks the user to proceed or cancel, and only after approval merges `develop` to `main` and triggers the formal release.

# Related Concepts

* [Source Map](/architecture/source-map.md)
* [Build, Test, Release Runbook](/runbooks/build-test-release.md)
