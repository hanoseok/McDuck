---
name: mcduck-release
description: Use when the user invokes "/McDuck:release", "/Mcduck:release", "/mcduck:release", or asks to prepare, confirm, or cut a formal McDuck release from develop to main.
---

# McDuck Release

Use this skill to prepare a formal McDuck release. It compares the previous release tag with current `develop`, summarizes intervening snapshots into Korean release notes, asks the user to approve or cancel, and only after approval merges `develop` to `main` and triggers the release.

## Hard Gates

- Before doing anything, read `AGENTS.md`, fetch `origin`, fetch tags, and confirm the worktree is clean.
- Until the user explicitly chooses "진행", perform only read-only commands. Do not create commits, tags, PRs, branches, or release markers.
- If the user chooses "끝내기" or cancellation, stop with no repository changes.
- Formal release tags must match `^[0-9]+\.[0-9]+$`, for example `1.1`.
- Stop and ask if there is no previous formal release tag, if `develop` is not ahead of the previous release, if `main` and `develop` have unexpected divergence, or if release notes cannot be justified from commits/snapshots.
- Do not edit snapshot releases while preparing a formal release.

## Release Context

Use the host-qualified repo:

```bash
REPO="${MCDUCK_GITHUB_REPO:-github.com/hanoseok/McDuck}"
git fetch origin main develop --tags --prune
git status --short --branch
```

Find the previous formal release and current release candidate:

```bash
LAST_RELEASE_TAG="$(git tag -l | grep -E '^[0-9]+\.[0-9]+$' | sort -V | tail -1)"
LAST_RELEASE_SHA="$(git rev-list -n 1 "$LAST_RELEASE_TAG")"
DEVELOP_SHA="$(git rev-parse origin/develop)"
git merge-base --is-ancestor origin/main origin/develop
git log --oneline "$LAST_RELEASE_TAG"..origin/develop
git diff --stat "$LAST_RELEASE_TAG"..origin/develop
```

If the user did not provide a target version, default to the next minor version after the latest formal release:

```bash
IFS=. read -r MAJOR MINOR <<EOF
$LAST_RELEASE_TAG
EOF
NEXT_RELEASE="$MAJOR.$((MINOR + 1))"
```

Validate an explicit user-provided version with:

```bash
printf '%s\n' "$NEXT_RELEASE" | grep -Eq '^[0-9]+\.[0-9]+$'
```

## Snapshot Review

List snapshot tags whose tagged commits are between the previous formal release and current `develop`:

```bash
git tag -l '*-SNAPSHOT' | sort -V | while read -r tag; do
  sha="$(git rev-list -n 1 "$tag")"
  if git merge-base --is-ancestor "$LAST_RELEASE_SHA" "$sha" &&
     git merge-base --is-ancestor "$sha" "$DEVELOP_SHA"; then
    printf '%s %s\n' "$tag" "$sha"
  fi
done
```

For each included snapshot, inspect the GitHub release if it exists:

```bash
gh release view "$SNAPSHOT_TAG" \
  --repo "$REPO" \
  --json tagName,name,body,publishedAt,url
```

Also inspect commits and merged PRs between the previous release and `develop`:

```bash
git log --first-parent --reverse --format='%h %s' "$LAST_RELEASE_TAG"..origin/develop
gh pr list --repo "$REPO" --state merged --base develop --limit 100 \
  --json number,title,mergedAt,mergeCommit,url
```

Use snapshots as the primary storyline and commits/PRs as evidence. Do not copy raw commit messages into the release note when a user-facing Korean summary is clearer.

## Release Notes

Draft the release note in this exact style:

```text
RELEASE-<version>
1. ~~ 가 변경되었어요.
2. ~~~ 가 수정 되었어요.
3. ~~~ 가 더 좋아졌어요.
   : ~ 를 하면 사용할 수 있어요.
```

Rules:

- Use `RELEASE-<NEXT_RELEASE>` as the title.
- Write in Korean, user-facing product language.
- Prefer "변경되었어요", "수정 되었어요", "더 좋아졌어요", or similarly plain phrases.
- Add an indented `: ...` usage hint only when it helps the user understand how to use the change.
- Omit internal-only details unless they affect installation, operation, or visible behavior.
- Include enough items to cover meaningful changes, but merge tiny internal commits into one readable item.

## Confirmation Stop

After drafting the release note, show:

- previous release tag and commit SHA
- current `develop` commit SHA
- included snapshot tags and release URLs, if any
- target formal release version
- exact release note text
- intended trigger path: direct tag push or `.github/cut-release.txt` bridge

Then stop and ask the user to choose:

```text
이 릴리즈 노트로 RELEASE-<version>을 진행할까요?
- 진행: develop -> main 머지와 릴리즈 트리거를 진행합니다.
- 끝내기: 아무 일도 하지 않고 현재 릴리즈 계획을 취소합니다.
- 수정: 원하는 문구를 알려주시면 릴리즈 노트를 다시 정리합니다.
```

Do not proceed from ambiguous approval. Treat "좋아", "진행", "go", "release" as approval only when it clearly refers to this exact release note and version.

## Proceed Path

When the user approves, re-check state before making changes:

```bash
git fetch origin main develop --tags --prune
git status --short --branch
git rev-parse origin/develop
git rev-parse origin/main
```

If the commit SHAs changed since confirmation, regenerate the release context and ask for confirmation again.

Follow repository policy: release code flows from `develop` to `main` through a PR unless the user explicitly instructs a different allowed method.

### Trigger Selection

Prefer direct release tags only when tag push permission is known to work:

```bash
git switch main
git pull --ff-only origin main
# after develop -> main merge is complete
git tag "$NEXT_RELEASE"
git push origin "$NEXT_RELEASE"
```

In Codex/cloud sessions where tag push or workflow dispatch can be blocked, use the release bridge. Before the `develop` -> `main` merge, make sure `develop` contains the release marker:

```bash
git switch develop
git pull --ff-only origin develop
printf '%s\n' "$NEXT_RELEASE" > .github/cut-release.txt
git add .github/cut-release.txt
git commit -m "ci: cut $NEXT_RELEASE"
git push origin develop
```

Then create or reuse a PR from `develop` to `main`:

```bash
RELEASE_NOTES_FILE="$(mktemp)"
# Write the exact approved release notes into "$RELEASE_NOTES_FILE" before creating the PR.
gh pr list --repo "$REPO" --head develop --base main
gh pr create --repo "$REPO" --base main --head develop \
  --title "RELEASE-$NEXT_RELEASE" \
  --body-file "$RELEASE_NOTES_FILE"
gh pr checks <pr-number-or-url> --repo "$REPO" --watch
gh pr merge <pr-number-or-url> --repo "$REPO" --merge --delete-branch=false
```

If repository settings require squash/rebase or manual merge, follow the setting and record the method. Do not delete `develop`.

## Release Confirmation

After `main` contains the release trigger, monitor the release:

```bash
gh run list --repo "$REPO" --limit 20
gh release view "$NEXT_RELEASE" --repo "$REPO" --json tagName,name,url,isPrerelease,publishedAt,assets
```

If the bridge was used, confirm `cut.yml` completed and dispatched `release.yml`. If direct tag push was used, confirm `release.yml` completed for the tag.

When confirmed, report the install commands:

```bash
curl -fsSL https://github.com/hanoseok/McDuck/releases/latest/download/install.sh | bash
curl -fsSL https://github.com/hanoseok/McDuck/releases/download/<version>/install.sh | bash
```

Replace `<version>` with the target release tag.

## Cancel Path

If the user chooses "끝내기", "취소", or equivalent cancellation at the confirmation stop:

- Do not create commits, tags, PRs, release markers, or branch changes.
- Report that `RELEASE-<version>` planning was canceled.
- Leave the repository state as it was before confirmation.
