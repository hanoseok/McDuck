# McDuck Agent Guide

이 파일은 McDuck 저장소의 **표준 작업 가이드**입니다. 장기적으로 유지할 규칙과 명령은 이 파일에 정리합니다. (`CLAUDE.md`는 이 파일을 가리키는 포인터입니다.)

## 기본 원칙

- 작업을 시작하기 전에 이 파일과 현재 git 상태를 확인합니다.
- 사용자가 요청하지 않은 리팩터링, 포맷 변경, 파일 이동은 피합니다.
- 기존 사용자 변경을 되돌리지 않습니다. 충돌이 있으면 먼저 상태를 설명합니다.
- 검증 없이 완료를 주장하지 않습니다. 변경 후 관련 테스트와 빌드를 실행합니다.

## 프로젝트 개요

McDuck은 `bunx ccusage` 출력을 읽어 macOS 상태바 팝오버에서 LLM token 사용량을 보여주는 네이티브 앱입니다.

- 앱 타깃: `Sources/McDuck`
- 테스트 가능한 코어 로직: `Sources/McDuckCore`
- 코어 테스트: `Tests/McDuckCoreTests`
- 앱 번들 스크립트: `scripts/build-app.sh`
- 릴리스 워크플로: `.github/workflows/release.yml`
- 릴리스 버전 파일: `RELEASE_VERSION`

## 기술 스택

- Swift Package Manager
- SwiftUI `MenuBarExtra`
- Swift Charts
- Liquid Glass: `GlassEffectContainer`, `glassEffect`
- Swift Testing
- 플랫폼: macOS 26 (`Package.swift`의 `.macOS(.v26)`)

## 로컬 빌드와 검증

macOS에서 작업할 때 기능 변경 후 최소한 아래 명령을 실행합니다.

```bash
swift test
swift build
scripts/build-app.sh
```

패키징 결과는 `dist/McDuck.app`에 생성됩니다. `dist/`는 git에 포함하지 않습니다.

`scripts/build-app.sh` 동작:

- `swift build -c release`로 `McDuck` 실행 파일을 빌드합니다.
- 바이너리와 `Resources/Info.plist`를 `dist/McDuck.app` 번들로 묶습니다.
- `MCDUCK_VERSION`(예: `1.2.0`)을 설정하면 `CFBundleShortVersionString`에, `MCDUCK_BUILD`는 `CFBundleVersion`에 기록합니다.
- `codesign --sign -`로 번들에 **ad-hoc 서명**을 넣습니다(다운로드 후 "손상됨" 차단을 일반 Gatekeeper 경고로 완화).

## Remote에서 빌드하고 바이너리로 실행하기

> **왜 remote인가:** McDuck은 macOS 26 네이티브 앱이라 Linux 컨테이너(클라우드 세션)에서는 직접 빌드할 수 없습니다. 그래서 GitHub Actions의 **macOS 러너**에서 빌드하고, 결과물 `.app`을 **GitHub Release**에 올려 내려받아 실행합니다.

### 1. 빌드 트리거 방법

릴리스 빌드는 `.github/workflows/release.yml`이 담당하며, 세 가지로 트리거됩니다. 모두 같은 결과(태그 + Release)를 만듭니다.

| 방법 | 사용 상황 |
| --- | --- |
| **`RELEASE_VERSION` 파일 수정 후 작업 브랜치에 push** | **remote 전용 흐름.** 클라우드 세션은 태그 push와 `workflow_dispatch`가 권한상 막혀 있어, 작업 브랜치 push가 유일하게 가능한 트리거입니다. |
| 버전 태그 push (`git tag v1.2.0 && git push origin v1.2.0`) | 로컬/CI에서 태그 push 권한이 있을 때 |
| Actions에서 `workflow_dispatch` 수동 실행(버전 입력) | 워크플로가 기본 브랜치에 있을 때(UI 버튼) |

> **remote 세션의 제약(중요):** 이 환경의 git 프록시는 **지정된 작업 브랜치 push만 허용**하고 태그 ref push는 `403`으로 막습니다. GitHub MCP 토큰에도 `actions: write`가 없어 `workflow_dispatch` 호출도 `403`입니다. 따라서 remote에서 릴리스를 내는 정식 방법은 아래 **`RELEASE_VERSION` 흐름**입니다.

### 2. remote에서 새 버전 릴리스하기 (`RELEASE_VERSION` 흐름)

```bash
# 1) 버전을 올린다 (예: v0.0.4 -> v0.0.5)
#    파일 내용은 'vX.Y.Z' 한 줄
printf 'v0.0.5\n' > RELEASE_VERSION

# 2) 작업 브랜치에 커밋 & push  → 이 push가 워크플로를 트리거
git add RELEASE_VERSION
git commit -m "Release v0.0.5"
git push -u origin <작업 브랜치>
```

push 이벤트로 워크플로가 macOS 러너(`runs-on: macos-26`)에서 다음 순서로 실행됩니다.

1. **버전 확인** — `workflow_dispatch`면 입력값, 태그 push면 태그명, 브랜치 push면 `RELEASE_VERSION` 내용을 버전으로 사용.
2. **중복 게이트** — 해당 버전의 Release가 이미 있으면 빌드를 건너뜁니다(무관한 커밋 push가 재릴리스되지 않도록).
3. **테스트** — `swift test`.
4. **빌드** — `scripts/build-app.sh` (버전 스탬프 + ad-hoc 서명).
5. **패키징** — `ditto`로 `McDuck-<tag>-macos.zip` 압축 + `.sha256` 체크섬 생성.
6. **게시** — `gh release create`로 zip과 체크섬을 Release에 첨부(자동 릴리스 노트 포함). in-workflow `GITHUB_TOKEN`이 release/tag 생성 권한을 가집니다.

테스트가 실패하면 빌드/게시 단계가 실행되지 않으므로 Release가 생기지 않습니다. 즉 **Release 존재 여부 = 빌드·테스트 통과**입니다.

### 3. 빌드 결과(바이너리) 다운로드

- 저장소 **Releases** 페이지에서 `McDuck-<tag>-macos.zip` 다운로드, 또는
- CLI:
  ```bash
  gh release download <tag> --repo <owner>/<repo>
  ```
- 직접 URL:
  ```
  https://github.com/<owner>/<repo>/releases/download/<tag>/McDuck-<tag>-macos.zip
  ```

### 4. 다운로드한 앱 실행

`.app`은 macOS 번들(폴더)이라 zip으로 배포합니다. 압축을 풀면 `McDuck.app`이 됩니다.

```bash
unzip McDuck-<tag>-macos.zip       # → McDuck.app
```

앱은 ad-hoc 서명만 되어 있고 **공증(notarization)은 안 됨**이라, 브라우저로 받으면 macOS가 quarantine을 붙여 Gatekeeper가 막습니다. 다음 중 하나로 실행합니다.

```bash
# quarantine 속성 제거 후 실행 (가장 확실)
xattr -dr com.apple.quarantine McDuck.app
open McDuck.app
```

또는 **시스템 설정 → 개인정보 보호 및 보안 → "그래도 열기"** 로 통과합니다. (macOS 15/26부터 우클릭 → 열기 우회는 막혔습니다.)

> 다운로드 후 경고 없이 바로 실행되게 하려면 유료 Apple Developer ID로 정식 서명 + 공증이 필요합니다. 필요 시 워크플로에 `codesign`(Developer ID) → `xcrun notarytool submit` → `xcrun stapler staple` 단계를 추가하고, 인증서/암호를 GitHub Secrets에 등록합니다.

### 5. 무결성 확인 (선택)

```bash
shasum -a 256 -c McDuck-<tag>-macos.zip.sha256
```

## 의존성 처리

- 앱은 시작 시 Bun과 `ccusage` 실행 가능 여부를 검사합니다.
- 의존성이 없으면 자동 설치하지 않고, 사용자가 팝오버의 설치 버튼을 눌렀을 때만 진행합니다.
- `ccusage`는 글로벌 설치보다 `bunx ccusage` 실행을 우선합니다.

## 구현 규칙

- JSON 파싱, 명령 실행, 상태 판정은 `McDuckCore`에 둡니다.
- SwiftUI 뷰와 macOS 앱 진입점은 `Sources/McDuck`에 둡니다.
- 코어 동작을 바꾸는 경우 테스트를 먼저 추가하거나 갱신합니다.
- UI는 상태바 유틸리티에 맞게 작고 명확하게 유지합니다.
- macOS 최신 API를 사용할 때는 빌드 가능한 fallback 또는 availability check를 둡니다.
- ccusage 출력 스키마는 버전에 따라 다릅니다(예: 날짜 필드가 `date` 또는 `period`, per-model이 `breakdown` 딕셔너리 또는 `modelBreakdowns` 배열). 파서는 누락 필드에 관대해야 하며, 디코딩 실패 시 원본 출력 일부를 담은 명확한 에러를 던집니다.

## Git 규칙

- 기능 작업은 지정된 작업 브랜치에서 진행합니다.
- 의미 있는 단위로 커밋합니다.
- push 전에 `git status --short`로 의도하지 않은 파일이 없는지 확인합니다.
- 생성물(`dist/`), 캐시, 임시 파일은 커밋하지 않습니다.
- remote(클라우드) 세션에서는 태그 push가 막혀 있으므로, 릴리스는 `RELEASE_VERSION`을 바꿔 작업 브랜치에 push하는 방식으로 냅니다.

## 문서 규칙

- **표준 가이드는 이 `AGENTS.md` 파일입니다.** `CLAUDE.md`는 이 파일을 읽으라는 포인터 역할만 합니다.
- 새로운 장기 규칙은 이 파일에 추가합니다.
- 도구별 지침을 중복 작성하지 않습니다.
- README는 사용자용 설명, 이 파일은 작업 에이전트용 설명으로 유지합니다.
