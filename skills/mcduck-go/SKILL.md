---
name: mcduck-go
description: Use when the user invokes "/McDuck:go", "/mcduck:go", or asks to implement planned McDuck GitHub issue work after /mcduck:start.
---

# McDuck Go

Use this skill to implement a planned McDuck GitHub issue. It starts only when the issue's managed Codex status is `{기획중}`/`기획중` or `개발완료`, preserves the issue body's `original`, updates only the Codex managed summary, follows TDD, commits meaningful units, creates a snapshot build, and stops at `개발완료`.

## Issue Key Discovery

Identify exactly one GitHub issue number from these sources, in order:

1. Explicit user argument, if present.
2. Current branch name: `codex/mcduck-45-slug`, `mcduck-45`, `MCDUCK-45`.
3. Current session title or visible context: `McDuck-45: ...`, `MCDUCK-45`.
4. Current GitHub issue managed summary in nearby context.

If zero or multiple conflicting issue numbers are found, stop and ask for the issue number. Use task key `McDuck-<number>` for titles and `[MCDUCK-<number>]` for commit messages.

## Hard Rules

- Do not start unless GitHub issue Codex managed status is `{기획중}`, `기획중`, or `개발완료`.
- If status is `개발완료`, treat this as redevelopment before `/McDuck:finish`; resume from "Development Start" and update the managed summary again.
- Never edit, summarize, reorder, rewrap, or normalize text between `<!-- mcduck:original:start -->` and `<!-- mcduck:original:end -->`.
- If original markers are missing or malformed, stop and ask the user to run `/mcduck:start` or repair the issue body.
- Only replace text between `<!-- mcduck:codex-summary:start -->` and `<!-- mcduck:codex-summary:end -->`.
- Do not commit unrelated changes. Do not revert user changes.
- Use TDD for every behavior change: failing test first, verify failure, minimal implementation, verify green, refactor.
- Keep working until implementation, verification, snapshot, issue summary update, and final title update are complete or blocked by an external permission/service failure.

## GitHub Issue Check

Prefer structured GitHub tooling if already available. Otherwise use `gh` with the full host-qualified repo:

```bash
REPO="${MCDUCK_GITHUB_REPO:-github.com/hanoseok/McDuck}"
gh issue view "$ISSUE_NUMBER" \
  --repo "$REPO" \
  --json number,title,body,state,url,labels,assignees,milestone
```

If `gh` routes to the wrong host, inspect `git remote get-url origin`, force `--repo github.com/hanoseok/McDuck`, and report authentication blockers. Do not scrape HTML.

Parse the body:

- `original`: immutable block between `mcduck:original` markers.
- `Codex managed summary`: block between `mcduck:codex-summary` markers.
- Status line: accept `- 상태: {기획중}`, `- 상태: 기획중`, or `- 상태: 개발완료`.
- Plan: use `전체 계획`, `기획/정책 요약`, `변경 후보 파일`, `TDD 계획`, `검증 계획`, and unresolved decision sections as the implementation contract.

If unresolved decisions remain, stop and ask before coding.

## Session Title

Discover a thread title tool with `tool_search` using at least two queries such as `set_thread_title`, `rename thread title`, `thread title`, or `session title`.

- Before coding, set title to `(개발중)McDuck-<number>: {GitHub issue title}`.
- After successful snapshot and summary update, set title to `(개발완료)McDuck-<number>: {GitHub issue title}`.
- If title changes fail or cannot be verified, continue. Record target title and failure/unknown reason in the GitHub issue managed summary and final report.

## Development Start

1. Confirm current branch/worktree matches the issue. Prefer the branch/worktree recorded in the issue summary.
2. If the current branch is not the issue branch, find a worktree whose branch matches `codex/mcduck-<number>-*`. Use that worktree for all development commands.
3. If no branch/worktree exists, create one from latest `origin/develop` only after confirming this will not overwrite user changes.
4. Update the Codex managed summary to `개발중` before coding:

```text
[Codex 작업 요약 - YYYY-MM-DD HH:mm KST]
- 작업 제목: McDuck-<number>: {GitHub issue title}
- 상태: 개발중
- GitHub issue: #<number> {url}
- 세션 제목: (개발중)McDuck-<number>: {GitHub issue title}
- original 보호: 유지
- feature branch:
- worktree:
- 구현 기준 계획:
- 진행 상태:
  - [x] 개발 시작
  - [ ] 실패 테스트
  - [ ] 구현
  - [ ] 검증
  - [ ] snapshot
  - [ ] 개발완료
```

Preserve existing plan content in the managed summary while changing status and progress. Do not rewrite original.

## TDD Implementation

For each planned behavior:

1. Add or update the smallest focused test first.
2. Run the focused test and confirm it fails for the expected missing behavior.
3. Implement the minimal code to pass.
4. Run the focused test again and confirm it passes.
5. Refactor only after green.
6. Repeat for the next behavior.

Test placement:

- Core parsing, command execution, dependency checks, status logic: `Tests/McDuckCoreTests`.
- App logic, settings, menu-bar text, plugin installer orchestration: `Tests/McDuckTests`.
- MCP handler/tool behavior: `Tests/McDuckMCPTests`.

Use `rg` and targeted reads before editing. Keep SwiftUI/system dependencies behind existing protocol or pure-state boundaries where possible.

## Commits

Commit meaningful units as soon as each unit is green and coherent.

Before each commit:

```bash
git status --short
git diff --check
```

Stage only intended files and commit with:

```text
[MCDUCK-<number>] 한국어 요약
```

Examples:

- `[MCDUCK-45] 사용량 파서 회귀 테스트 추가`
- `[MCDUCK-45] 메뉴바 상태 갱신 정책 구현`
- `[MCDUCK-45] 스냅샷 빌드 요청`

Do not include `dist/`, `.build/`, DerivedData, caches, or unrelated user changes.

## Verification

Run verification in this order and record commands/results in the issue summary:

1. Focused test for the changed behavior, for example `swift test --filter McDuckCoreTests` or a narrower test filter.
2. Swift typecheck/build equivalent: `swift build`.
3. Full test suite: `swift test`.
4. Required app/package build: `scripts/build-app.sh`.

If a command is unavailable or fails due to environment constraints, do not claim it passed. Record the exact blocker and use the strongest available fallback.

## Snapshot

After implementation commits and local verification pass, create a snapshot build for user installation.

1. Determine the next snapshot version from tags:

```bash
git fetch origin --tags
git tag -l | grep -E '^[0-9]+\.[0-9]+$' | sort -V | tail -1
git tag -l '*-SNAPSHOT' | sort -V | tail -1
```

Use AGENTS.md snapshot rules: if latest release is `X.Y`, snapshot line is `X.(Y+1)`. Start at `X.(Y+1).0-SNAPSHOT`; increment patch if that line already has snapshots.

2. Prefer the repository bridge unless direct tag push is explicitly available:

```bash
printf '<next-version>\n' > .github/cut-snapshot.txt
git add .github/cut-snapshot.txt
git commit -m "[MCDUCK-<number>] 스냅샷 빌드 요청"
git push -u origin HEAD
```

3. Open or update a PR from the feature branch to `develop`, merge it when checks are acceptable, and monitor `cut.yml` then `snapshot.yml`.
4. Confirm the release exists:

```bash
gh release view <next-version> --repo github.com/hanoseok/McDuck
gh release view snapshot-latest --repo github.com/hanoseok/McDuck
```

If permissions block push, PR, merge, workflow dispatch, or release confirmation, report the blocker and leave the managed summary in the most accurate state. If snapshot is created, always provide both install commands:

```bash
curl -fsSL https://github.com/hanoseok/McDuck/releases/download/snapshot-latest/install-snapshot.sh | bash
curl -fsSL https://github.com/hanoseok/McDuck/releases/download/<next-version>/install-snapshot.sh | bash
```

## Completion

After snapshot release is confirmed:

1. Update only the Codex managed summary to `개발완료`.
2. Preserve the plan and add concise implementation, commits, verification, snapshot, and install command results.
3. Set session title to `(개발완료)McDuck-<number>: {GitHub issue title}`.
4. Final report must include:
   - issue number/title
   - commits made
   - verification commands and results
   - snapshot version and install shell
   - status `개발완료`
   - next step: `/McDuck:finish`

Managed summary shape:

```text
[Codex 작업 요약 - YYYY-MM-DD HH:mm KST]
- 작업 제목: McDuck-<number>: {GitHub issue title}
- 상태: 개발완료
- GitHub issue: #<number> {url}
- 세션 제목: (개발완료)McDuck-<number>: {GitHub issue title}
- original 보호: 유지
- feature branch:
- worktree:
- 구현 요약:
- 커밋:
- 검증:
- snapshot:
- 설치:
  - 최신: curl -fsSL https://github.com/hanoseok/McDuck/releases/download/snapshot-latest/install-snapshot.sh | bash
  - 특정: curl -fsSL https://github.com/hanoseok/McDuck/releases/download/<version>/install-snapshot.sh | bash
- 다음 단계: /McDuck:finish
- 진행 상태:
  - [x] 실패 테스트
  - [x] 구현
  - [x] 검증
  - [x] snapshot
  - [x] 개발완료
```

## Redevelopment Before Finish

Until `/McDuck:finish` runs, `/McDuck:go` may be invoked again on an issue whose status is `개발완료`.

When redeveloping:

1. Keep original unchanged.
2. Re-read the current managed summary, issue, wiki, code, tests, and policies.
3. Set title back to `(개발중)...`.
4. Update managed summary to `개발중`.
5. Follow TDD, commit, verify, snapshot, and return to `개발완료` again.
