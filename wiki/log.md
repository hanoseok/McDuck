# McDuck Wiki Update Log

## 2026-06-21
* **Initialization**: Created the OKF-style `wiki/` bundle for McDuck project knowledge.
* **Creation**: Added root navigation, project overview, architecture/module maps, progress, decisions, retrospectives, runbooks, references, and templates.
* **Reference**: Captured the Open Knowledge Format source material in [Open Knowledge Format](references/open-knowledge-format.md).
* **Workflow**: Added repository-owned Codex workflow skills under `skills/`, starting with `/mcduck:start`, and documented the thin personal pointer rule in [Codex Skills](modules/codex-skills.md).
* **Workflow update**: Clarified `/mcduck:start` lifecycle: freeze original issue body, write the full plan to GitHub issue body, store managed status as `{기획중}`, and keep updating the plan until `/McDuck:go`.
* **Workflow**: Added `/McDuck:go` as the TDD implementation, verification, snapshot, and `개발완료` workflow paired with `/mcduck:start`.
* **Workflow**: Added `/McDuck:finish` for final verification, develop PR merge, wiki cleanup, feature branch/worktree cleanup, develop snapshot, and `(완)` session completion.
