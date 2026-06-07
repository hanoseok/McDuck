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
- 릴리스 워크플로: `.github/workflows/release.yml`(정식, `MAJOR.MINOR` 태그), `.github/workflows/snapshot.yml`(스냅샷, `X.Y.Z-SNAPSHOT` 태그)

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

### 0. 브랜치 전략과 빌드 트리거 (중요)

빌드는 **태그 기반**입니다. 브랜치 push가 아니라 **태그를 만들면** GitHub Actions가 그 태그로 빌드합니다.

- **정식 릴리스** = `MAJOR.MINOR` 태그(예: `1.0`, `1.1`)를 `main` 커밋에 찍는다 → `release.yml`이 `McDuck-<태그>`(예: `McDuck-1.0`)를 게시. `releases/latest`가 이를 가리킵니다.
- **스냅샷(테스트)** = `X.Y.Z-SNAPSHOT` 태그(예: `1.0.4-SNAPSHOT`)를 `develop` 커밋에 찍는다 → `snapshot.yml`이 **prerelease** + 이동 태그 `snapshot-latest`로 게시. prerelease라 `releases/latest`에 영향 없음.
- 코드 흐름은 작업 브랜치 → `develop` → `main`(PR 머지). 빌드는 그 위에 태그를 찍어 트리거합니다.
- `.github/workflows/ci.yml`은 PR에서 macOS 15·26 매트릭스로 `swift test`만 돌립니다(게시 없음).

### 0.5. 한눈에 보는 흐름

```
코드:  작업 브랜치 ──PR──▶ develop ──PR──▶ main

태그(빌드 트리거):
  develop 커밋에  X.Y.Z-SNAPSHOT  ──▶ snapshot.yml ──▶ 1.0.4-SNAPSHOT (prerelease) + snapshot-latest
  main 커밋에     MAJOR.MINOR      ──▶ release.yml  ──▶ McDuck-1.0 (정식, releases/latest)
```

### 0.6. 태그로 빌드하기 (치트시트)

> 태그 push는 **태그 push 권한이 있는 곳**(로컬 등)에서 합니다. 이 클라우드 remote 세션은 태그 ref push가 `403`으로 막혀 있고 `workflow_dispatch`도 `403`이라, **에이전트는 코드 PR 머지까지만 하고 태그는 사람이 찍습니다.**

**① 정식 릴리스** (예: 1.0)
```bash
git checkout main && git pull
git tag 1.0           # MAJOR.MINOR (= 버전)
git push origin 1.0   # → release.yml → McDuck-1.0
```

**② 스냅샷(테스트) 빌드** (예: 1.0.4-SNAPSHOT)
```bash
git checkout develop && git pull
git tag 1.0.4-SNAPSHOT
git push origin 1.0.4-SNAPSHOT   # → snapshot.yml → prerelease + snapshot-latest
```

- **태그 이름이 곧 버전**입니다(`v`/`McDuck-` 접두사 없이). 정식은 `MAJOR.MINOR`, 스냅샷은 `X.Y.Z-SNAPSHOT`.
- 태그는 **워크플로가 들어 있는 커밋**(이 태그 기반 전환 이후의 커밋)에 찍어야 빌드됩니다.
- 대안: Actions UI의 **Run workflow**(`workflow_dispatch`)에 태그명을 입력해도 동일하게 빌드됩니다(태그가 없으면 워크플로가 생성).

### 0.7. 클라우드 에이전트용 브리지 (`cut.yml`)

클라우드 remote 세션은 태그 push·`workflow_dispatch`가 모두 `403`이라 에이전트가 직접 빌드를 못 냅니다. 그래서 **에이전트가 할 수 있는 동작(작업브랜치 push → PR 머지)** 으로 빌드를 트리거하는 브리지를 둡니다. Actions 러너의 토큰은 샌드박스 밖이라 태그 생성·dispatch가 가능합니다.

마커 파일에 버전을 적고 해당 채널 브랜치로 머지하면, `cut.yml`이 실제 빌드 워크플로를 `workflow_dispatch`로 호출합니다(빌드가 태그를 생성·게시).

| 마커 파일 | 머지 대상 | 결과 |
| --- | --- | --- |
| `.github/cut-release.txt` = `1.0` | `main` | `release.yml` → `McDuck-1.0` (+ 태그 `1.0`) |
| `.github/cut-snapshot.txt` = `1.0.4-SNAPSHOT` | `develop` | `snapshot.yml` → prerelease (+ 태그) |

- 같은 태그가 이미 있으면 `cut.yml`은 스킵합니다(멱등).
- **로컬 사용자에겐 불필요** — 권한 있는 곳에선 `git push origin <태그>`가 곧바로 빌드를 트리거합니다(`cut.yml`은 에이전트 전용 레버).

**스냅샷 버전 규칙:** 스냅샷은 **다음 미출시 버전**을 가리킵니다. 즉 최신 정식 릴리스가 `X.Y`이면 스냅샷 라인은 `X.(Y+1)` 입니다 — `X.(Y+1).0-SNAPSHOT`부터 시작하고, 같은 라인에서 추가 빌드는 patch +1 합니다. 정식 `X.(Y+1)`이 릴리스되면 `X.(Y+2).0-SNAPSHOT`로 넘어갑니다. (예: `1.0` 릴리스됨 → `1.1.0-SNAPSHOT`, `1.1.1-SNAPSHOT`, …)

**에이전트가 스냅샷 빌드 내는 절차** (예: 다음 스냅샷)
```bash
# 1) 다음 버전 정하기
git fetch origin --tags
git tag -l        | grep -E '^[0-9]+\.[0-9]+$'        | sort -V | tail -1   # 최신 정식 릴리스, 예: 1.0
git tag -l '*-SNAPSHOT' | sort -V | tail -1                                 # 최신 스냅샷
#   - 최신 릴리스 X.Y 보다 높은 라인의 스냅샷이 없으면 → X.(Y+1).0-SNAPSHOT (예: 1.1.0-SNAPSHOT)
#   - 같은 라인에 스냅샷이 이미 있으면 → 그 patch +1

# 2) 작업 브랜치를 develop에 맞추고 마커만 변경
git checkout -B <작업브랜치> origin/develop
printf '1.1.0-SNAPSHOT\n' > .github/cut-snapshot.txt
git commit -am "ci: cut 1.1.0-SNAPSHOT" && git push -u origin <작업브랜치> --force-with-lease

# 3) PR(작업브랜치 → develop) 머지
#    → cut.yml 이 snapshot.yml 을 dispatch → 빌드가 태그 1.1.0-SNAPSHOT 생성 + prerelease/snapshot-latest 게시
```

**에이전트가 정식 릴리스 내는 절차**는 동일하되 `.github/cut-release.txt`에 `MAJOR.MINOR`(예: `1.1`)를 적고 **`main`** 으로 머지합니다(→ `McDuck-1.1` + 태그 `1.1`).

> 확인: 머지 후 `cut.yml`(브리지) → `snapshot.yml`/`release.yml` 런이 성공하고, 해당 태그의 Release가 생겼는지 본다. 빌드는 macOS 러너에서 ~1분.

> **스냅샷을 냈으면 설치 주소를 알려준다.** 스냅샷 빌드를 트리거(또는 게시 확인)한 뒤에는 항상 사용자에게 설치 명령을 함께 안내한다.
> ```bash
> # 최신 스냅샷
> curl -fsSL https://github.com/hanoseok/McDuck/releases/download/snapshot-latest/install-snapshot.sh | bash
> # 특정 버전 (예: 1.1.0-SNAPSHOT)
> curl -fsSL https://github.com/hanoseok/McDuck/releases/download/1.1.0-SNAPSHOT/install-snapshot.sh | bash
> ```

### 1. release.yml 단계 (정식)

`MAJOR.MINOR` 태그 push(또는 Actions UI의 `workflow_dispatch`) 시 macOS 러너(`runs-on: macos-26`)에서:

1. **버전 확인** — 태그명(`1.0`)이 버전, 릴리스명은 `McDuck-1.0`.
2. **중복 게이트** — 같은 태그의 Release가 이미 있으면 스킵.
3. **테스트** — `swift test`.
4. **빌드** — `scripts/build-app.sh`(버전 스탬프 + ad-hoc 서명).
5. **패키징** — `McDuck-<버전>.pkg`, 안정 이름 `McDuck.pkg`, `McDuck-<버전>-macos.zip`, `.sha256`.
6. **게시** — `gh release create`로 자산 첨부(자동 릴리스 노트). in-workflow `GITHUB_TOKEN`이 release 생성 권한을 가집니다.

### 1.5. snapshot.yml 단계 + 설치 (스냅샷)

`X.Y.Z-SNAPSHOT` 태그 push(또는 `workflow_dispatch`) 시:

1. **버전 확인** — 태그명(`1.0.4-SNAPSHOT`)이 버전.
2. `swift test` → `scripts/build-app.sh`로 스탬프해 빌드.
3. **버전 고정 prerelease**(예: `1.0.4-SNAPSHOT`)와 **이동 태그 `snapshot-latest`**(매 빌드 재생성)를 게시. 각 릴리스에 `McDuck-<버전>.pkg`, 안정 이름 `McDuck.pkg`, zip, 체크섬, `install-snapshot.sh`를 첨부.

GitHub은 `/snapshot/...` 경로를 제공하지 않으므로 설치는 `releases/...` 경로로 합니다.

```bash
# 최신 스냅샷
curl -fsSL https://github.com/hanoseok/McDuck/releases/download/snapshot-latest/install-snapshot.sh | bash

# 특정 스냅샷 버전
curl -fsSL https://github.com/hanoseok/McDuck/releases/download/1.0.4-SNAPSHOT/install-snapshot.sh | bash
```

`install-snapshot.sh`는 인자 없이 실행하면 `snapshot-latest`의 `McDuck.pkg`를, 태그 인자를 주면 `McDuck-<태그>.pkg`를 받아 설치합니다.

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

- **앱 아이콘(Finder/설치 마법사):** `Resources/McDuck-title.png`(팝오버 헤더와 동일 이미지) → `build-app.sh`가 `iconutil`로 `AppIcon.icns` 생성, `Info.plist`의 `CFBundleIconFile=AppIcon`.
- **타이틀(팝오버 헤더) 아이콘:** `Resources/McDuck-title.png` → `Contents/Resources/`로 복사, 앱이 `Bundle.main`으로 로드(`AppImages.titleIcon`).
- **메뉴바 아이콘:** `Resources/McDuck-menubar.png` → `build-app.sh`가 `sips`로 `Resources/Assets.xcassets/MenuBarIcon.imageset`의 1x/2x/3x(현재 24pt = 24/48/72px)를 재생성하고, `actool`로 `Assets.car`(메인 번들)로 컴파일. 앱은 `MenuBarExtra("McDuck", image: "MenuBarIcon")`로 표시.
- 메뉴바 아이콘 크기를 바꾸려면 imageset의 px(=point×scale)만 조정합니다. macOS 메뉴바 높이(~22pt) 한계가 있어 그 이상은 줄여서 표시될 수 있습니다.

## 에셋/리소스 로딩 주의 (중요)

- **`Bundle.module`을 쓰지 않습니다.** SwiftPM의 리소스 번들 접근자는 수동 조립된 `.app`에서 번들을 못 찾아 **실행 즉시 `Fatal error`로 크래시**합니다(`McDuck_McDuck.bundle`를 `.app` 최상위에서 찾음). 이미지는 `Bundle.main`(=`Contents/Resources`) 또는 컴파일된 `Assets.car`에서 로드합니다.
- **`swift build`는 `.xcassets`를 컴파일하지 않습니다.** 에셋 카탈로그는 `build-app.sh`에서 `actool`로 `Assets.car`를 만들어 메인 번들에 넣습니다.
- **메뉴바 커스텀 아이콘은 "이름 있는 에셋 이미지"** 를 씁니다(`MenuBarExtra(image:)` / `Image("name")`). `Image(nsImage:)`는 메뉴바 라벨에서 표시되지 않을 수 있습니다.
- **백그라운드 새로고침은 라벨에서 시작합니다.** `MenuBarExtra(.window)`의 content(팝오버)는 **열릴 때만** 생성되므로, content의 `.task`에 둔 `startAutoRefresh()`는 첫 클릭 전까지 실행되지 않습니다. 그래서 자동 새로고침은 **항상 떠 있는 `label`(MenuBarLabel)의 `.task`** 에서 시작해 앱 실행 즉시 ccusage를 가져옵니다(`startAutoRefresh()`는 멱등). `MenuBarExtra` 라벨에 `VStack`으로 **라이브 텍스트** 2줄을 넣으면 아래 줄이 클리핑됩니다. 2줄을 보이려면 `ImageRenderer`로 **템플릿 `NSImage`로 렌더링**해 `Image(nsImage:)`로 넣습니다(이미지는 바 높이에 맞춰 축소되어 두 줄 모두 표시). `MenuBarLabel`이 아이콘+토큰/비용을 이렇게 렌더링합니다. (참고: 실제 표시는 macOS에서 육안 확인 필요 — 안 보이면 커스텀 `NSStatusItem`으로 전환.)

## 구현 규칙

- JSON 파싱, 명령 실행, 상태 판정은 `McDuckCore`에 둡니다.
- SwiftUI 뷰와 macOS 앱 진입점은 `Sources/McDuck`에 둡니다.
- 코어 동작을 바꾸는 경우 테스트를 먼저 추가하거나 갱신합니다.
- UI는 상태바 유틸리티에 맞게 작고 명확하게 유지합니다.
- macOS 최신 API를 사용할 때는 빌드 가능한 fallback 또는 availability check를 둡니다(예: Liquid Glass `glassEffect`/`.glass` 버튼 스타일은 macOS 26+, 그 이전은 material/`.bordered`로 대체).
- 버튼은 `mcDuckGlass`/`mcDuckGlassButton`으로 Liquid Glass를 적용합니다. 차트 호버 툴팁은 차트 annotation이 아니라 **최상위 `.overlay`** 로 그려 범례 위에 불투명하게 표시합니다.
- ccusage 출력 스키마는 버전에 따라 다릅니다(예: 날짜 필드가 `date` 또는 `period`, per-model이 `breakdown` 딕셔너리 또는 `modelBreakdowns` 배열). 파서는 누락 필드에 관대해야 하며, 디코딩 실패 시 원본 출력 일부를 담은 명확한 에러를 던집니다.

## MCP 서버 (`mcduck-mcp`)

McDuck은 사용량 데이터를 **MCP(stdio) 서버**로도 제공합니다. ccusage 파싱은 `McDuckCore`를 재사용하므로 로직 중복이 없습니다.

- `Sources/McDuckMCP` — 라이브러리. JSON-RPC 2.0 타입, `MCPRequestHandler`(initialize/tools/list/tools/call), 툴 정의·집계(`MCPTools`). I/O가 없어 단위 테스트 가능. 데이터원은 `UsageProviding` 프로토콜로 추상화(테스트는 fake 주입).
- `Sources/mcduck-mcp` — 실행파일. 줄단위 JSON-RPC stdio 루프, 실제 provider는 `CcusageClient` 래핑.
- `Tests/McDuckMCPTests` — 핸들러·와이어 포맷 리그레션 테스트.
- 노출 툴(1차): `usage_summary`, `daily_usage`, `model_breakdown`(인자: 선택적 `start`/`end`, `yyyy-MM-dd`).
- SwiftUI에 의존하지 않아 macOS·Linux 모두 컴파일됩니다(앱 타깃과 달리).
- 플러그인(`plugin/`)이 이 바이너리를 MCP 서버로 선언합니다(아래 참고).

## Claude Code 플러그인 (`plugin/`)

MCP 서버와 스킬을 하나의 Claude Code 플러그인으로 묶어 배포합니다.

- `plugin/.claude-plugin/plugin.json` — 플러그인 매니페스트. `mcpServers.mcduck.command = ${CLAUDE_PLUGIN_ROOT}/bin/mcduck-mcp`.
- `plugin/skills/usage-report/SKILL.md` — 사용량 리포트 스킬(MCP 툴 사용 안내).
- `plugin/bin/mcduck-mcp` — 런처 스크립트. 바이너리 탐색 순서: `MCDUCK_MCP_BIN` → `bin/mcduck-mcp-bin` → `.build/release/mcduck-mcp` → 캐시 → **릴리스에서 다운로드**(`mcduck-mcp-macos`, arm64) → `swift build` 소스 빌드. **빌드/진단 출력은 stderr로만** 보내 JSON-RPC stdout을 오염시키지 않습니다.
- `.claude-plugin/marketplace.json`(레포 루트) — 마켓플레이스. 플러그인 소스 `./plugin`.
- 설치: `/plugin marketplace add hanoseok/McDuck` → `/plugin install mcduck@mcduck`.
- `release.yml`·`snapshot.yml`이 `mcduck-mcp` 바이너리(`mcduck-mcp-macos`, arm64)를 릴리스 자산으로 첨부합니다(빌드 실패해도 릴리스는 계속 — `continue-on-error`, 파일 존재 시에만 첨부). 그래서 Apple Silicon에서는 런처가 이 바이너리를 받아 **Swift 툴체인 없이** 동작하고, Intel/툴체인 보유 환경은 소스 빌드로 폴백합니다.
- **앱 번들에 마켓플레이스 동봉:** `build-app.sh`가 마켓플레이스+플러그인+프리빌트 `mcduck-mcp` 바이너리를 `McDuck.app/Contents/Resources/ClaudePlugin/`(`.claude-plugin/marketplace.json` + `plugin/` + `plugin/bin/mcduck-mcp-bin`)에 넣습니다. 빌드 크리티컬 패스를 막지 않도록 가드(서브셸)로 감쌌습니다. 설치된 앱이 있으면 네트워크·툴체인 없이 로컬에서 등록·설치할 수 있습니다:
  ```
  /plugin marketplace add /Applications/McDuck.app/Contents/Resources/ClaudePlugin
  /plugin install mcduck@mcduck
  ```
  런처는 설치된 `McDuck.app` 안의 바이너리도 직접 탐색합니다(GitHub 마켓플레이스로 설치했더라도 앱이 있으면 그 바이너리 사용).
  > 주의: 비-git 로컬 디렉터리 마켓플레이스에서 `marketplace.json`의 `source: "./plugin"`(상대경로)이 해석되는지는 Claude Code 버전에 따라 다를 수 있습니다(공식 문서상 상대경로는 git 기반에서 보장, 로컬 디렉터리 테스트 add는 예시로 동작). 실제 Claude Code에서 검증 필요. 미해석 시 source를 절대경로/`github` 등으로 전환합니다.
- **앱 내 등록/제거(설정 패널):** 헤더 기어 설정의 버튼이 플러그인을 등록·활성화하거나 제거합니다(`PluginInstaller`). 설치 여부는 `~/.claude/settings.json`의 `enabledPlugins["mcduck@mcduck"]` 또는 `extraKnownMarketplaces.mcduck` 존재로 판정해, 미설치면 "Add to Claude Code", 설치돼 있으면 "Remove from Claude Code"를 노출합니다. 1순위로 `claude` CLI(add/install, uninstall/marketplace remove)를 시도하고 **실패하면 `~/.claude/settings.json`을 직접 수정**(fallback): 등록은 `extraKnownMarketplaces.mcduck = { source: { source: "directory", path: <ClaudePlugin 절대경로> } }` + `enabledPlugins["mcduck@mcduck"] = true`, 제거는 두 항목을 삭제(다른 키는 보존 병합·멱등). 적용은 Claude Code 재시작/`/reload-plugins`. 핵심 로직(JSON 병합/제거·판정·오케스트레이션)은 `Tests/McDuckTests`로 커버.
  > 참고: 비대화형 `claude plugin` 셸 서브커맨드는 공식 문서에 없어 CLI 1순위는 실패할 수 있고, 그 경우 settings.json fallback이 실제 동작 경로가 됩니다.

## 테스트 규칙 (TDD + 리그레션)

- **TDD가 기본입니다.** 모든 코드 변경은 **실패하는 테스트를 먼저 작성**하고, 그 테스트를 통과시키는 최소 구현을 넣은 뒤 리팩터링합니다(red → green → refactor).
- **리그레션 스위트를 유지합니다.** 버그를 고치거나 기능을 추가하면 회귀를 막는 테스트를 스위트에 남깁니다. 테스트는 절대 삭제로 "통과"시키지 않습니다.
- **테스트 타깃 배치:**
  - 플랫폼 무관 코어 로직(JSON 파싱, 명령 실행, 상태 판정) → `Tests/McDuckCoreTests` (`McDuckCore`).
  - 앱 로직(설정 저장소, 메뉴바 텍스트, 로그인 항목 상태 등) → `Tests/McDuckTests` (`@testable import McDuck`). 시스템 연동은 프로토콜(예: `LoginItemControlling`)로 추상화하고 fake를 주입해 테스트합니다.
- **테스트 용이성을 위해 설계합니다.** 시스템/네트워크 의존은 프로토콜 경계 뒤로 숨기고, 순수 로직은 주입 가능한 입력(`UserDefaults`, fake 러너, fake 로케이터)으로 분리합니다. SwiftUI 뷰 자체보다 그 뷰가 읽는 관찰 가능한 상태/계산 프로퍼티를 테스트합니다.
- **검증:** `swift test`는 macOS에서 실행합니다(Linux 클라우드 세션은 앱 타깃을 빌드할 수 없어, 앱 타깃 테스트는 PR의 macOS CI 매트릭스로 검증합니다).

## Git 규칙

- **모든 신규 개발은 `develop`에서 분기**해 시작합니다(작업 브랜치를 항상 최신 `develop` HEAD 기준으로 만든다).
- 코드 흐름은 작업 브랜치 → `develop` → `main`(PR 머지)입니다.
- 기능 작업은 지정된 작업 브랜치에서 진행합니다.
- 의미 있는 단위로 커밋합니다.
- push 전에 `git status --short`로 의도하지 않은 파일이 없는지 확인합니다.
- 생성물(`dist/`), 캐시, 임시 파일은 커밋하지 않습니다.
- 빌드는 **태그 기반**입니다. 정식은 `main`에 `MAJOR.MINOR` 태그(`1.0`), 스냅샷은 `develop`에 `X.Y.Z-SNAPSHOT` 태그(`1.0.4-SNAPSHOT`)를 찍어 트리거합니다. remote(클라우드) 세션은 태그 ref push가 막혀 있어, 에이전트는 코드 PR 머지까지만 하고 **태그는 사람이 찍습니다**.
- **`develop` 머지 = 스냅샷 빌드**: 작업이 `develop`에 머지되면 곧바로 스냅샷을 빌드합니다. 에이전트는 develop 머지 PR에서 `.github/cut-snapshot.txt`를 다음 `X.Y.Z-SNAPSHOT`으로 올려 `cut.yml`이 스냅샷 빌드를 띄우게 합니다(태그 직접 push가 가능한 로컬은 `git push origin <태그>`).
- **정식 릴리스 = `main` 태그**: 정식 릴리스는 `main`에서만 만들 수 있습니다. `main`에 `MAJOR.MINOR` 태그를 찍어야(또는 `.github/cut-release.txt`를 `main`에 머지) `release.yml`이 빌드합니다.

## 문서 규칙

- **표준 가이드는 이 `AGENTS.md` 파일입니다.** `CLAUDE.md`는 이 파일을 읽으라는 포인터 역할만 합니다.
- 새로운 장기 규칙은 이 파일에 추가합니다.
- 도구별 지침을 중복 작성하지 않습니다.
- README는 사용자용 설명, 이 파일은 작업 에이전트용 설명으로 유지합니다.
