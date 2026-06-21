---
name: mcduck-finish
description: Use when the user invokes "/McDuck:finish", "/mcduck:finish", or asks to finish a McDuck issue branch after /McDuck:go reached development complete.
---

# McDuck Finish

Use this skill to finish a McDuck issue after `/McDuck:go` has produced `개발완료`. It verifies the final branch, pushes remaining work, merges the feature branch to `develop`, writes wiki task cleanup, pushes wiki changes, removes the feature worktree/branches, creates a develop snapshot, closes the GitHub issue, reports install shell commands, and sets the session title to `(완)`.

## Issue Key Discovery

Identify exactly one issue number from the current branch first:

1. Current branch: `codex/mcduck-45-slug`, `mcduck-45`, `MCDUCK-45`.
2. Current session title or context: `McDuck-45: ...`, `MCDUCK-45`.
3. Explicit user argument if branch context is absent.
4. GitHub issue managed summary if available.

If zero or conflicting issue numbers are found, stop and ask for the issue number. Use task key `McDuck-<number>` for titles and `[MCDUCK-<number>]` for commits.

## Hard Gates

- Fetch and read the GitHub issue before doing cleanup.
- The latest Codex managed status in the GitHub issue body must be exactly `개발완료`. Do not accept `{기획중}`, `기획중`, `개발중`, `완료`, missing status, or ambiguous old logs.
- Never edit the `original` block between `<!-- mcduck:original:start -->` and `<!-- mcduck:original:end -->`.
- Only rewrite the Codex managed summary between `<!-- mcduck:codex-summary:start -->` and `<!-- mcduck:codex-summary:end -->`.
- Do not remove the feature worktree or local/remote branches until the feature PR is merged into `develop` and wiki changes have been pushed.
- Do not close the GitHub issue until the final required merge is complete, wiki cleanup is pushed, snapshot is confirmed, and the final Codex managed summary is written.
- Do not use destructive cleanup commands if uncommitted or unpushed work remains.
- Stop and report blockers for failed checks, merge conflicts, permission errors, or ambiguous branch state.

## GitHub Issue Check

Use the full host-qualified repo:

```bash
REPO="${MCDUCK_GITHUB_REPO:-github.com/hanoseok/McDuck}"
gh issue view "$ISSUE_NUMBER" \
  --repo "$REPO" \
  --json number,title,body,state,url,labels,assignees,milestone
```

Parse the issue body:

- Verify original markers exist and are well-formed.
- Verify Codex summary markers exist and are well-formed.
- Find the latest status line inside the current Codex summary block.
- Continue only when it is exactly `- 상태: 개발완료`.

## Session Title

Discover a thread title tool with `tool_search` using at least two queries such as `set_thread_title`, `rename thread title`, `thread title`, or `session title`.

- At cleanup start, set `(정리중)McDuck-<number>: {GitHub issue title}`.
- At the end, set `(완)McDuck-<number>: {GitHub issue title}`.
- If title changes fail or cannot be verified, continue only when cleanup can still be done safely. Record the target title and failure/unknown reason in the issue summary and final report.

## Final Verification And Diff

Work from the feature worktree/branch identified by the issue summary or current branch.

Run:

```bash
git status --short --branch
git diff --check
swift test
swift build
scripts/build-app.sh
```

If the issue summary lists additional focused tests or checks, run those first. Record every command and result.

If build artifacts or caches appear, do not commit them. Confirm `.gitignore` excludes generated output such as `dist/`, `.build/`, and DerivedData.

## Commit And Push Feature Branch

If meaningful tracked changes remain after verification:

1. Inspect `git status --short` and `git diff`.
2. Stage only intended feature files.
3. Commit with:

```text
[MCDUCK-<number>] 한국어 요약
```

4. Push the feature branch:

```bash
git push -u origin HEAD
```

If no changes remain, push the branch anyway if it has unpushed commits. Confirm:

```bash
git status --short --branch
git log --oneline origin/$(git branch --show-current)..HEAD
```

## Develop PR

Create or reuse a PR from the feature branch to `develop`.

```bash
gh pr list --repo "$REPO" --head "$(git branch --show-current)" --base develop
gh pr create --repo "$REPO" --base develop --head "$(git branch --show-current)" --title "[MCDUCK-<number>] {GitHub issue title}" --body "..."
```

Check status:

```bash
gh pr checks <pr-number-or-url> --repo "$REPO" --watch
```

Merge only when checks are acceptable and branch state is clear:

```bash
gh pr merge <pr-number-or-url> --repo "$REPO" --squash --delete-branch=false
```

If merge policy requires a different method, follow repository policy and record it. Do not delete branches during PR merge; cleanup happens after wiki and snapshot work.

## Wiki Cleanup On Develop

After feature PR merges:

1. Switch the main checkout to `develop` and update it:

```bash
MAIN_ROOT="$(git rev-parse --show-toplevel)"
git -C "$MAIN_ROOT" switch develop
git -C "$MAIN_ROOT" pull --ff-only origin develop
```

2. Follow AGENTS.md and OKF wiki rules.
3. Add or update a task cleanup/progress page under `wiki/progress/` using date and issue number, for example:

```text
wiki/progress/YYYY-MM-DD-mcduck-<number>-<short-slug>.md
```

4. Link it from `wiki/progress/index.md` if that index is used for navigation.
5. Update the nearest `wiki/log.md`.

The cleanup document should include:

- issue number/title and GitHub URL
- merged feature branch and PR URL
- implementation summary
- verification commands/results
- snapshot version/status
- notable decisions, follow-ups, and files changed

Commit wiki changes on `develop`:

```bash
git status --short
git add wiki
git commit -m "[MCDUCK-<number>] 작업 정리 문서화"
git push origin develop
```

Do not mix unrelated files into the wiki cleanup commit.

## Branch And Worktree Cleanup

Only after feature PR is merged and wiki changes are pushed:

1. Identify the feature worktree path:

```bash
git worktree list
```

2. Ensure the worktree is clean and no commits are unmerged:

```bash
git -C "$FEATURE_WORKTREE" status --short --branch
git branch --merged develop
```

3. Remove the worktree:

```bash
git worktree remove "$FEATURE_WORKTREE"
```

4. Delete the local feature branch after it is merged:

```bash
git branch -d "$FEATURE_BRANCH"
```

5. Delete the remote feature branch only after confirming the PR is merged:

```bash
git push origin --delete "$FEATURE_BRANCH"
```

If any command says work is not merged or the worktree is dirty, stop and report exactly what remains.

## Develop Snapshot

Create a snapshot from current `develop` after wiki cleanup is pushed.

1. Determine the next snapshot version:

```bash
git fetch origin --tags
git tag -l | grep -E '^[0-9]+\.[0-9]+$' | sort -V | tail -1
git tag -l '*-SNAPSHOT' | sort -V | tail -1
```

Apply AGENTS.md snapshot rules: latest release `X.Y` means snapshot line `X.(Y+1)`. Start at `X.(Y+1).0-SNAPSHOT`; increment patch on that line.

2. Trigger snapshot on `develop`. Prefer direct tag push only when permissions allow:

```bash
git tag <next-version>
git push origin <next-version>
```

If tag push is blocked, use the bridge on `develop`:

```bash
printf '<next-version>\n' > .github/cut-snapshot.txt
git add .github/cut-snapshot.txt
git commit -m "[MCDUCK-<number>] 스냅샷 빌드 요청"
git push origin develop
```

3. Monitor `cut.yml` and `snapshot.yml` if bridge is used. Confirm release:

```bash
gh release view <next-version> --repo "$REPO"
gh release view snapshot-latest --repo "$REPO"
```

Always report install shell commands when snapshot is created or confirmed:

```bash
curl -fsSL https://github.com/hanoseok/McDuck/releases/download/snapshot-latest/install-snapshot.sh | bash
curl -fsSL https://github.com/hanoseok/McDuck/releases/download/<next-version>/install-snapshot.sh | bash
```

## Close GitHub Issue

After the final required merge into `develop`, wiki cleanup push, develop snapshot confirmation, and final Codex managed summary update, close the GitHub issue:

```bash
gh issue close "$ISSUE_NUMBER" --repo "$REPO" --comment "완료: develop 반영, wiki 정리, snapshot <next-version> 확인."
```

If close fails because of permissions or API errors, keep the session title and managed summary accurate, report the blocker, and do not claim the issue is closed.

## Issue Summary And Completion

After snapshot is confirmed:

1. Rewrite only the Codex managed summary block.
2. Preserve `original` unchanged.
3. Set status to `완료`.
4. Close the GitHub issue after the summary update.
5. Set final session title to `(완)McDuck-<number>: {GitHub issue title}`.

Managed summary shape:

```text
[Codex 작업 요약 - YYYY-MM-DD HH:mm KST]
- 작업 제목: McDuck-<number>: {GitHub issue title}
- 상태: 완료
- GitHub issue: #<number> {url}
- 세션 제목: (완)McDuck-<number>: {GitHub issue title}
- original 보호: 유지
- develop PR:
- wiki 정리:
- feature 정리:
- snapshot:
- GitHub issue close: 성공 또는 실패/확인불가(사유)
- 설치:
  - 최신: curl -fsSL https://github.com/hanoseok/McDuck/releases/download/snapshot-latest/install-snapshot.sh | bash
  - 특정: curl -fsSL https://github.com/hanoseok/McDuck/releases/download/<version>/install-snapshot.sh | bash
- 검증:
- 진행 상태:
  - [x] 개발완료 확인
  - [x] 최종 검증
  - [x] develop PR merge
  - [x] wiki 정리 push
  - [x] feature branch/worktree 정리
  - [x] develop snapshot
  - [x] GitHub issue close
  - [x] 완료
```

Final report to the user:

- issue/title
- merged PR URL
- wiki cleanup file
- snapshot version
- install shell commands
- branch/worktree cleanup result
- GitHub issue close result
- status `완료`
