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
- 플랫폼: macOS 15 (Sequoia) 이상 (`Package.swift`의 `.macOS(.v15)`). Liquid Glass는 macOS 26+에서만 적용되고, 이전 버전에선 `#available` 체크로 material로 대체됩니다.

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

### 0. 브랜치 전략과 릴리스 채널 (중요)

- **`main` = 정식 릴리스 채널.** 정식 Release는 `main`에서만 나옵니다(`.github/workflows/release.yml`). `releases/latest`가 가리키는 빌드입니다.
- **`develop` = 스냅샷(테스트) 빌드 채널.** `develop`에 push될 때마다 `.github/workflows/snapshot.yml`이 **prerelease**로 스냅샷을 게시합니다. prerelease라서 `main`의 `releases/latest`에 영향을 주지 않습니다.
- 일반 작업은 작업 브랜치 → `develop`(PR 머지) 흐름으로 합니다. 정식 릴리스는 `develop` → `main` 머지로 냅니다.
- `.github/workflows/ci.yml`은 PR(=`develop`/`main` 대상)에서 macOS 15·26 매트릭스로 `swift test`를 돌려 머지 전에 검증합니다.

### 0.5. 버저닝 모델 (중요)

`RELEASE_VERSION` 파일은 **현재 개발 라인 `MAJOR.MINOR`** 한 줄을 담습니다(예: `1.0`). `snapshot.yml`과 `release.yml`이 모두 이 값을 기준으로 동작합니다.

- **개발(snapshot, `develop`)**: 라인 안에서 patch가 자동 증가 → `1.0.0-SNAPSHOT`, `1.0.1-SNAPSHOT`, `1.0.2-SNAPSHOT`, …
- **정식(release, `main` 머지)**: 현재 라인을 단일 **이동 릴리스 `McDuck-<MAJOR.MINOR>`**(예: `McDuck-1.0`)로 게시. `main`에 머지될 때마다 이 릴리스를 최신 빌드로 재생성하며 `releases/latest`가 이를 가리킵니다.
- **다음 사이클**: `RELEASE_VERSION`의 MINOR를 올립니다(예: `1.0` → `1.1`). 그러면 `develop`은 `1.1.0-SNAPSHOT`부터 다시 시작하고, `main` 머지는 `McDuck-1.1`로 릴리스합니다.

즉 patch 자동 증가는 **스냅샷에만** 있고, 정식 릴리스는 라인 이름(`McDuck-1.0`)으로 고정되며 **MINOR 점프만 수동**입니다.

### 0.6. 한눈에 보는 흐름 + 치트시트

```
RELEASE_VERSION = 1.0   (현재 개발 라인 = MAJOR.MINOR)

  작업 브랜치 ──PR──▶ develop ──push──▶ snapshot.yml
                                         └▶ 1.0.0-SNAPSHOT, 1.0.1-SNAPSHOT, ...
                                            (prerelease + 이동 태그 snapshot-latest)
                          │
                          └──PR 머지──▶ main ──push──▶ release.yml
                                                        └▶ McDuck-1.0
                                                           (정식, releases/latest, 이동 릴리스)

RELEASE_VERSION = 1.1   ← MINOR만 올리면 다음 사이클로 전환
  develop ─▶ 1.1.0-SNAPSHOT, 1.1.1-SNAPSHOT, ...      main ─▶ McDuck-1.1
```

remote 세션은 브랜치 직접 push가 막혀 있으므로 **모두 "작업 브랜치 push → GitHub MCP로 PR 생성 → 머지"** 로 합니다.

**① 개발 스냅샷 내기** (테스트 빌드)
```
작업 브랜치 커밋 & push  →  PR (작업 브랜치 → develop)  →  머지
# 머지되면 snapshot.yml이 다음 1.0.x-SNAPSHOT을 자동 게시
```

**② 정식 릴리스 내기** (현재 라인을 McDuck-<라인>으로)
```
PR (develop → main)  →  머지
# 머지되면 release.yml이 McDuck-1.0을 (재)게시 = releases/latest
```

**③ 다음 MINOR 사이클 시작** (예: 1.0 → 1.1)
```
# develop 기준 작업 브랜치에서:
printf '1.1\n' > RELEASE_VERSION
git commit -am "Start 1.1 line"  →  push  →  PR(→develop) 머지
# 이후 스냅샷은 1.1.0-SNAPSHOT부터, main 머지는 McDuck-1.1
```

> `RELEASE_VERSION`은 **한 줄 `MAJOR.MINOR`**(예: `1.0`)만 둡니다. patch·`-SNAPSHOT`·`v`·`McDuck-` 같은 접두/접미는 워크플로가 알아서 붙입니다.

### 1. 정식 릴리스 (`main`)

`.github/workflows/release.yml`이 `main` push마다 실행되어 현재 라인을 `McDuck-<MAJOR.MINOR>`로 (재)게시합니다.

| 방법 | 사용 상황 |
| --- | --- |
| **`develop` → `main` 머지** | 권장. 현재 `RELEASE_VERSION` 라인을 `McDuck-<라인>`으로 게시. |
| Actions에서 `workflow_dispatch` 수동 실행(릴리스명 입력, 예: `McDuck-1.1`) | 워크플로가 기본 브랜치에 있을 때(UI 버튼) |

> **remote 세션의 제약(중요):** 이 환경의 git 프록시는 **지정된 작업 브랜치 push만 허용**하고, GitHub MCP 토큰엔 `actions: write`가 없어 `workflow_dispatch`도 막힙니다. 따라서 remote에서는 작업 브랜치를 push한 뒤 **GitHub MCP로 PR을 만들어 `develop`/`main`에 머지**하는 방식으로 빌드를 트리거합니다.

### 1.5. 스냅샷(테스트) 빌드와 설치 (`develop`)

`develop`에 변경이 들어올 때마다 `snapshot.yml`이 자동으로:

1. `RELEASE_VERSION` 라인(`MAJOR.MINOR`)의 기존 `MAJOR.MINOR.x-SNAPSHOT` 중 가장 높은 patch를 +1 (없으면 `.0`부터).
2. `swift test` → `scripts/build-app.sh`로 해당 버전을 스탬프해 빌드.
3. **버전 고정 prerelease**(예: `1.0.2-SNAPSHOT`)와 **이동 태그 `snapshot-latest`**(매 빌드 재생성)를 게시. 각 릴리스에 `McDuck-<버전>.pkg`, 안정 이름 `McDuck.pkg`, zip, 체크섬, `install-snapshot.sh`를 첨부.

GitHub은 `/snapshot/...` 경로를 제공하지 않으므로 설치는 `releases/...` 경로로 합니다.

```bash
# 최신 스냅샷
curl -fsSL https://github.com/hanoseok/McDuck/releases/download/snapshot-latest/install-snapshot.sh | bash

# 특정 스냅샷 버전
curl -fsSL https://github.com/hanoseok/McDuck/releases/download/1.0.0-SNAPSHOT/install-snapshot.sh | bash
```

`install-snapshot.sh`는 인자 없이 실행하면 `snapshot-latest`의 `McDuck.pkg`를, 태그 인자를 주면 `McDuck-<태그>.pkg`를 받아 설치합니다.

### 2. remote에서 릴리스 / 사이클 진행하기

**같은 라인을 정식 릴리스(또는 갱신):**

1. 작업 브랜치 → `develop` 머지(스냅샷 빌드로 검증).
2. `develop` → `main` 머지(PR) → `release.yml`이 `McDuck-<현재 라인>`을 (재)게시.

**다음 MINOR 사이클로 넘어가기:**

```bash
# develop 기준으로 라인을 올린다 (예: 1.0 -> 1.1). 파일 내용은 'MAJOR.MINOR' 한 줄.
printf '1.1\n' > RELEASE_VERSION
git add RELEASE_VERSION && git commit -m "Start 1.1 line"
# 작업 브랜치 → develop 머지: 이후 스냅샷은 1.1.0-SNAPSHOT부터 시작
# develop → main 머지: McDuck-1.1로 릴리스
```

`main` push 시 `release.yml`이 macOS 러너(`runs-on: macos-26`)에서 다음 순서로 실행됩니다.

1. **버전 확인** — `workflow_dispatch`면 입력값(예: `McDuck-1.1`), `main` push면 `RELEASE_VERSION` 라인 → `McDuck-<라인>`.
2. **테스트** — `swift test`.
3. **빌드** — `scripts/build-app.sh` (라인 버전 스탬프 + ad-hoc 서명).
4. **패키징** — `ditto`로 `McDuck-<버전>-macos.zip` 압축 + `.sha256` 체크섬 생성.
5. **게시** — 기존 `McDuck-<라인>` 릴리스/태그를 지우고 이번 커밋에서 재생성(`gh release delete --cleanup-tag` → `gh release create`, 자동 릴리스 노트). 즉 `McDuck-<라인>`은 라인 내 최신 main 빌드를 가리키는 **이동 릴리스**입니다.

테스트가 실패하면 게시 단계가 실행되지 않습니다.

### 3. 빌드 결과(바이너리) 다운로드

- 저장소 **Releases** 페이지에서 `McDuck-<버전>-macos.zip` 다운로드, 또는
- CLI:
  ```bash
  gh release download <tag> --repo <owner>/<repo>
  ```
- 직접 URL:
  ```
  https://github.com/<owner>/<repo>/releases/download/<tag>/McDuck-<버전>-macos.zip
  ```

### 4. 설치 / 실행

**가장 쉬운 방법 — 터미널 원라이너(경고 없음):** `curl`로 받은 파일에는 quarantine이 붙지 않아 Gatekeeper가 막지 않습니다. `xattr`·시스템 설정 없이 관리자 암호만 입력하면 됩니다.

```bash
curl -fsSL https://github.com/hanoseok/McDuck/releases/latest/download/install.sh | bash
```

이 스크립트(`scripts/install.sh`)는 최신 릴리스의 `.pkg`를 curl로 받아 `sudo installer`로 설치합니다(설치 후 postinstall이 quarantine 제거·실행).

릴리스에는 네 가지가 첨부됩니다: `McDuck-<버전>.pkg`(설치 패키지), `McDuck-<버전>-macos.zip`(앱 + 설치 스크립트), `install.sh`(원라이너), `McDuck-<버전>-checksums.sha256`.

**권장: `.pkg` 더블클릭.** `McDuck-<버전>.pkg`를 더블클릭하면 macOS 설치 마법사 창이 떠서 `/Applications`에 설치하고, `postinstall`(`scripts/pkg-scripts/postinstall`)이 실행 중인 McDuck 종료 → quarantine 제거 → 실행까지 처리합니다.

> 앱·pkg 모두 공증(notarization)이 안 되어 있어, 다운로드한 pkg를 처음 열 때 Gatekeeper가 막을 수 있습니다. 그때는 **우클릭 → 열기**, 또는 한 번만 `xattr -dr com.apple.quarantine McDuck-<버전>.pkg` 후 더블클릭하세요.

**대안: zip + 설치 스크립트.** zip 안에는 `McDuck.app`과 `Install McDuck.command`가 들어 있습니다.

```bash
cd ~/Downloads
unzip -o McDuck-<버전>-macos.zip
bash "McDuck-<버전>/Install McDuck.command"   # 관리자 암호로 설치 + quarantine 제거
```

> 설치 스크립트와 `.pkg`의 `postinstall`은 모두 **관리자 권한(암호)** 으로 `xattr -dr com.apple.quarantine`을 실행해 Gatekeeper 차단을 풉니다.

수동으로 하려면 ad-hoc 서명만 된 앱이라 quarantine을 직접 제거해야 합니다.

```bash
xattr -dr com.apple.quarantine McDuck.app
open McDuck.app
```

또는 **시스템 설정 → 개인정보 보호 및 보안 → "그래도 열기"** (macOS 15/26부터 우클릭 → 열기 우회는 막힘).

> 다운로드 후 경고 없이 바로 실행되게 하려면 유료 Apple Developer ID로 정식 서명 + 공증이 필요합니다. 필요 시 워크플로에 `codesign`(Developer ID) → `xcrun notarytool submit` → `xcrun stapler staple` 단계를 추가하고, 인증서/암호를 GitHub Secrets에 등록합니다.

### 5. 무결성 확인 (선택)

```bash
shasum -a 256 -c McDuck-<버전>-macos.zip.sha256
```

## 의존성 처리

- 앱은 시작 시 Bun과 `ccusage` 실행 가능 여부를 검사합니다.
- 의존성이 없으면 자동 설치하지 않고, 사용자가 팝오버의 설치 버튼을 눌렀을 때만 진행합니다.
- `ccusage`는 글로벌 설치보다 `bunx ccusage` 실행을 우선합니다.

## 아이콘과 에셋

이미지는 `Resources/`에 두고, `build-app.sh`가 앱 번들에 넣습니다. (SwiftPM `Bundle.module`은 사용하지 않습니다 — 아래 "에셋/리소스 로딩 주의" 참고.)

- **앱 아이콘(Finder/설치 마법사):** `Resources/AppIcon.png` → `build-app.sh`가 `iconutil`로 `AppIcon.icns` 생성, `Info.plist`의 `CFBundleIconFile=AppIcon`.
- **타이틀(팝오버 헤더) 아이콘:** `Resources/McDuck-title.png` → `Contents/Resources/`로 복사, 앱이 `Bundle.main`으로 로드(`AppImages.titleIcon`).
- **메뉴바 아이콘:** `Resources/McDuck-menubar.png` → `build-app.sh`가 `sips`로 `Resources/Assets.xcassets/MenuBarIcon.imageset`의 1x/2x/3x(현재 24pt = 24/48/72px)를 재생성하고, `actool`로 `Assets.car`(메인 번들)로 컴파일. 앱은 `MenuBarExtra("McDuck", image: "MenuBarIcon")`로 표시.
- 메뉴바 아이콘 크기를 바꾸려면 imageset의 px(=point×scale)만 조정합니다. macOS 메뉴바 높이(~22pt) 한계가 있어 그 이상은 줄여서 표시될 수 있습니다.

## 에셋/리소스 로딩 주의 (중요)

- **`Bundle.module`을 쓰지 않습니다.** SwiftPM의 리소스 번들 접근자는 수동 조립된 `.app`에서 번들을 못 찾아 **실행 즉시 `Fatal error`로 크래시**합니다(`McDuck_McDuck.bundle`를 `.app` 최상위에서 찾음). 이미지는 `Bundle.main`(=`Contents/Resources`) 또는 컴파일된 `Assets.car`에서 로드합니다.
- **`swift build`는 `.xcassets`를 컴파일하지 않습니다.** 에셋 카탈로그는 `build-app.sh`에서 `actool`로 `Assets.car`를 만들어 메인 번들에 넣습니다.
- **메뉴바 커스텀 아이콘은 "이름 있는 에셋 이미지"** 를 씁니다(`MenuBarExtra(image:)` / `Image("name")`). `Image(nsImage:)`는 메뉴바 라벨에서 표시되지 않을 수 있습니다.

## 구현 규칙

- JSON 파싱, 명령 실행, 상태 판정은 `McDuckCore`에 둡니다.
- SwiftUI 뷰와 macOS 앱 진입점은 `Sources/McDuck`에 둡니다.
- 코어 동작을 바꾸는 경우 테스트를 먼저 추가하거나 갱신합니다.
- UI는 상태바 유틸리티에 맞게 작고 명확하게 유지합니다.
- macOS 최신 API를 사용할 때는 빌드 가능한 fallback 또는 availability check를 둡니다(예: Liquid Glass `glassEffect`/`.glass` 버튼 스타일은 macOS 26+, 그 이전은 material/`.bordered`로 대체).
- 버튼은 `mcDuckGlass`/`mcDuckGlassButton`으로 Liquid Glass를 적용합니다. 차트 호버 툴팁은 차트 annotation이 아니라 **최상위 `.overlay`** 로 그려 범례 위에 불투명하게 표시합니다.
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
