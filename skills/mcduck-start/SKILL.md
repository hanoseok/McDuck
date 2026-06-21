---
name: mcduck-start
description: Use when the user invokes "/mcduck:start issue-number", "/mcduck:start #45", or asks to start McDuck planning from a GitHub issue before implementation.
---

# McDuck Start

Use this skill for `/mcduck:start <number>`. It plans McDuck work from a GitHub issue, prepares a feature worktree from latest `develop`, preserves the issue's pre-start body as immutable original text, writes the current full plan back to the GitHub issue body, and stores the management status as `{기획중}`. Do not implement code, run feature tests, commit, push, or open PRs in this skill.

## Input

- Accept one GitHub issue number. Valid forms include `45`, `#45`, `/issue/45`, `/issues/45`, and a GitHub issue URL ending in the number.
- If the input cannot be reduced to one positive integer, stop and ask for the issue number.
- The task title is `McDuck-<number>: {GitHub issue title}`.
- The Codex session title starts as `(기획중)McDuck-<number>: {GitHub issue title}` and finishes as `(기획완료)McDuck-<number>: {GitHub issue title}`.

## Hard Rules

- Treat the GitHub issue body as Task notes.
- Before changing any issue body text, freeze the entire pre-start issue body as `original`. After that, never edit, summarize, reorder, rewrap, or normalize the original block.
- Only rewrite the McDuck Codex summary block after original has been frozen. The block must contain the current full plan and management summary. Do not keep appending new logs.
- Do not edit the GitHub issue title, close/reopen the issue, add labels, or change milestones unless the user explicitly asks.
- Do not revert user changes. If local changes block `develop` checkout or pull, fetch `origin/develop`, create the worktree from `origin/develop`, and report the main checkout blocker.
- Use latest `origin/develop` as the feature base.
- `/mcduck:start` ends at management status `{기획중}`. Implementation starts only after `/McDuck:go`.
- Until `/McDuck:go` starts, continue updating the plan in the GitHub issue body whenever the user changes requirements or asks to revise the plan. Never change `original`; reread the issue, wiki, code, tests, and policies, then rewrite the entire Codex summary block with the updated plan.

## Session Title

1. After reading the issue title, discover a thread title tool with `tool_search` using at least two queries such as `set_thread_title`, `rename thread title`, `thread title`, or `session title`.
2. If a suitable tool exists, set the title to `(기획중)McDuck-<number>: {title}`.
3. If title change fails or cannot be verified, continue the workflow. Record the failure/unknown result and target title in the Task notes summary and final report.
4. When planning is complete, try again with `(기획완료)McDuck-<number>: {title}` before writing the final plan to the GitHub issue body, and record the result.

## GitHub Issue

Prefer structured GitHub tooling if already available. Otherwise use `gh` with the full host-qualified repo so local enterprise defaults do not misroute:

```bash
REPO="${MCDUCK_GITHUB_REPO:-github.com/hanoseok/McDuck}"
gh issue view "$ISSUE_NUMBER" \
  --repo "$REPO" \
  --json number,title,body,state,url,labels,assignees,milestone
```

If `gh` still targets the wrong host, inspect `git remote get-url origin`, force the host in `--repo`, and report any authentication blocker. Do not scrape HTML.

## Original Preservation

Use these exact marker comments in the GitHub issue body:

```markdown
<!-- mcduck:original:start -->
...the exact issue body as it existed before /mcduck:start...
<!-- mcduck:original:end -->

---
<!-- mcduck:codex-summary:start -->
[Codex 작업 요약 - YYYY-MM-DD HH:mm KST]
...
<!-- mcduck:codex-summary:end -->
```

Rules:

- If `mcduck:original` markers are absent, immediately write a new body that wraps the entire current body between the original markers, preserving its content exactly. It is okay for the original block to be empty if the issue body was empty.
- If original markers already exist, treat that block as immutable. Never replace it with the current issue body.
- If a Codex summary block exists, replace only the text between `mcduck:codex-summary` markers with the full current plan.
- If no Codex summary block exists, add one after the original block.
- If marker boundaries are malformed, stop and ask before editing the issue body.
- Use `gh issue edit "$ISSUE_NUMBER" --repo "$REPO" --body-file <file>` for body updates.

## Wiki Search

Before planning, search the OKF wiki and cite the paths used:

1. Read `AGENTS.md`, `wiki/index.md`, and `wiki/architecture/source-map.md`.
2. Use the issue title/body keywords to inspect relevant `wiki/modules/`, `wiki/architecture/`, `wiki/runbooks/`, `wiki/decisions/`, and `wiki/progress/` pages.
3. If indexes are not enough, run `rg -n "<keyword>" wiki`.
4. If wiki guidance conflicts with source code, tests, or `AGENTS.md`, prefer the source of truth and record `검증 필요`.
5. If nothing relevant exists, record `관련 wiki page 없음`.

## Develop And Worktree

Prepare a branch and worktree without disturbing unrelated local changes.

```bash
MAIN_ROOT="$(git rev-parse --show-toplevel)"
git -C "$MAIN_ROOT" status --short --branch
git -C "$MAIN_ROOT" worktree list
git -C "$MAIN_ROOT" fetch origin --prune
```

If the main checkout is clean, update local `develop`:

```bash
git -C "$MAIN_ROOT" switch develop
git -C "$MAIN_ROOT" pull --ff-only origin develop
```

If the main checkout is dirty or switching would risk user work, do not stash or reset. Continue from fetched `origin/develop` and record the blocker.

Create deterministic names:

- Branch: `codex/mcduck-<issue-number>-<short-slug>`
- Worktree: `$HOME/.codex/worktrees/mcduck/mcduck-<issue-number>-<short-slug>`

If the branch/worktree already exists, inspect `git status --short --branch` there and reuse it unless it is unsafe. If the branch does not exist:

```bash
mkdir -p "$HOME/.codex/worktrees/mcduck"
git -C "$MAIN_ROOT" worktree add \
  -b "$BRANCH" \
  "$WORKTREE" \
  origin/develop
```

## Plan

Build the plan from the GitHub issue, wiki, code, tests, and policy:

- Read relevant source and tests with `rg`/targeted file reads. Start from `Package.swift`, `Sources/`, `Tests/`, `scripts/`, and workflow files only when relevant.
- Separate product policy, user flow, data/model behavior, UI states, release/installation effects, and test strategy.
- Include target files, TDD steps, verification commands, release/snapshot implications when relevant, and risks.
- Keep the user-facing plan focused on planning, policy, and flow. Put implementation detail in Task notes, not in the visible summary's `개발 계획` section.
- If this is a plan update before `/McDuck:go`, read the existing Codex summary for context but recompute the whole plan from current inputs. Do not patch only the changed bullet.

## Unclear Requirements

If requirements are ambiguous enough that planning would encode a risky assumption, stop and ask with choices:

```text
설명: <무엇이 왜 불명확한지 한 문장>

1. <추천안> (추천)
   - 이유: <정책, 위험, 사용자 동선 기준>
2. <차선책> (차선책)
   - 이유: <비용이나 제약>
3. <비추천안> (비추천)
   - 이유: <회귀, 복잡도, 정책 위반 위험>
```

Do not save `{기획중}` until the answer is reflected. If no user decision is needed, continue without asking for approval.

## User-Facing Summary

When the plan is clear, show this before saving the final Task notes summary:

```text
1. 제목:
   McDuck-<number>: {GitHub issue title}

2. 개발 계획:
   - <기획/정책/사용자 동선 중심>
   - <화면 상태, 운영 규칙, 대표 검증 시나리오>

3. 변경되는 사항:
   - <기존 동작/정책에서 무엇이 달라지는지>
   - <사용자나 운영자가 체감할 변화>

4. 수정되는 파일:
   - path: <변경 이유>
   - path: <변경 이유>
```

Do not ask "진행해도 될까요?" when there are no unresolved decisions. Immediately set the session title to `(기획완료)McDuck-<number>: {GitHub issue title}` and write the plan to the GitHub issue body.

## Final GitHub Issue Plan

When planning is clear, rewrite only the Codex summary block in the GitHub issue body with this shape:

```text
[Codex 작업 요약 - YYYY-MM-DD HH:mm KST]
- 작업 제목: McDuck-<number>: {GitHub issue title}
- 상태: {기획중}
- GitHub issue: #<number> {url}
- 세션 제목: (기획완료)McDuck-<number>: {GitHub issue title}
- 세션 제목 변경: 성공 또는 실패/확인불가(사유, 목표 제목)
- feature branch: codex/mcduck-<number>-<short-slug>
- worktree: /absolute/path
- original 보호: 유지
- 목표:
- wiki 참고사항:
- 전체 계획:
- 기획/정책 요약:
- 변경되는 사항:
- 변경 후보 파일:
- TDD 계획:
- 검증 계획:
- 릴리스/스냅샷 영향:
- 미확정/결정 사항:
- 사용자 질문 필요 여부: 없음 또는 반영 완료
- 계획 업데이트 정책: /McDuck:go 전까지 original은 유지하고 이 Codex 요약 블록 전체를 최신 계획으로 재작성
- 진행 상태:
  - [x] GitHub issue 조회
  - [x] original 보호
  - [x] wiki 참고사항 검색
  - [x] develop 최신화 또는 origin/develop fetch
  - [x] feature branch/worktree 준비
  - [x] 개발계획 요약 보고
  - [x] {기획중}
  - [ ] 구현
  - [ ] 검증
  - [ ] 커밋
```

This block is the managed plan. On every plan update before `/McDuck:go`, replace the whole block with the newly confirmed plan and keep `- 상태: {기획중}`.

After saving, report the same user-facing summary plus:

```text
상태: {기획중}
다음 단계: /McDuck:go
```
