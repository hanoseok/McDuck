# McDuck 빌드 · 릴리스 · 설치 가이드

McDuck은 **macOS 26 네이티브 앱**(Swift / SwiftUI)입니다. macOS 전용이라 Linux 클라우드 세션에서는 직접 빌드할 수 없고, **GitHub Actions의 macOS 러너에서 빌드 → 버전 릴리스 → 다운로드/설치**하는 흐름을 사용합니다.

---

## 1. 사전 요구사항

**로컬 빌드(맥에서 직접):**
- macOS 15(Sequoia) 이상에서 실행 (`Package.swift`는 `.macOS(.v15)`). Liquid Glass는 macOS 26+에서만, 그 이전엔 material로 대체.
- 빌드 툴체인: Xcode 26 이상 (Swift 6.2+)
- 실행에는 Bun + `ccusage`가 필요하지만, 앱이 첫 실행 시 설치 버튼(SetupView)으로 안내합니다.

**원격(CI) 빌드:** `.github/workflows/release.yml`이 `runs-on: macos-26`에서 자동 처리하므로 별도 준비물 없음.

---

## 2. 로컬 빌드와 테스트

```bash
swift test            # McDuckCore 단위 테스트
swift build           # 실행 파일 빌드
scripts/build-app.sh  # dist/McDuck.app 번들 생성
open dist/McDuck.app  # 실행
```

`scripts/build-app.sh` 동작:
1. `swift build -c release`로 `McDuck` 실행 파일 빌드
2. 바이너리 + `Resources/Info.plist`를 `dist/McDuck.app`으로 묶음
3. `MCDUCK_VERSION`(예: `1.2.0`) → `CFBundleShortVersionString`, `MCDUCK_BUILD` → `CFBundleVersion`에 스탬프
4. `codesign --sign -`로 **ad-hoc 서명**(공증 아님)

```bash
MCDUCK_VERSION=1.2.0 MCDUCK_BUILD=42 scripts/build-app.sh
```

> `dist/`, `.build/`는 커밋하지 않습니다(`.gitignore`).

---

## 3. 버저닝 규칙

- `RELEASE_VERSION` 파일 한 줄은 **현재 개발 라인 `MAJOR.MINOR`**(예: `1.0`)입니다. `snapshot.yml`·`release.yml`이 이 값을 기준으로 동작합니다.
- **개발(`develop`)**: 라인 안에서 patch가 자동 증가하는 스냅샷 prerelease — `1.0.0-SNAPSHOT`, `1.0.1-SNAPSHOT`, ….
- **정식(`main` 머지)**: 현재 라인을 이동 릴리스 **`McDuck-<MAJOR.MINOR>`**(예: `McDuck-1.0`)로 게시. `releases/latest`가 이를 가리킵니다.
- **다음 사이클**: `RELEASE_VERSION`의 MINOR를 올리면(예: `1.0` → `1.1`) `develop`은 `1.1.0-SNAPSHOT`부터, `main`은 `McDuck-1.1`로 전환됩니다.
- 빌드 앱 번들엔 라인 버전이 스탬프되어 푸터에 `v1.0`처럼 표시됩니다.

---

## 4. 원격 릴리스 (권장 흐름)

정식 릴리스는 `.github/workflows/release.yml`이 `main` push마다 macOS 러너에서 처리합니다.

| 방법 | 사용 상황 |
| --- | --- |
| **`develop` → `main` 머지** | 권장. 현재 `RELEASE_VERSION` 라인을 `McDuck-<라인>`으로 (재)게시. 클라우드 세션에서도 PR 머지로 동작. |
| Actions에서 `workflow_dispatch` 수동 실행(릴리스명 입력, 예: `McDuck-1.1`) | 워크플로가 기본 브랜치에 있을 때. |

### 사이클 전환 흐름

```bash
# develop 기준으로 라인을 올린다 (예: 1.0 -> 1.1). 파일 내용은 'MAJOR.MINOR' 한 줄.
printf '1.1\n' > RELEASE_VERSION
git add RELEASE_VERSION
git commit -m "Start 1.1 line"
# 작업 브랜치 → develop 머지(스냅샷 1.1.0-SNAPSHOT~) → develop → main 머지(McDuck-1.1)
```

### 워크플로 단계

1. **버전 확인** — dispatch면 입력값(예: `McDuck-1.1`), `main` push면 `RELEASE_VERSION` 라인 → `McDuck-<라인>`.
2. **테스트** — `swift test`.
3. **빌드** — `scripts/build-app.sh` (라인 버전 스탬프 + ad-hoc 서명).
4. **패키징**
   - `.pkg` — `pkgbuild`로 `/Applications` 설치 패키지 생성. `postinstall`이 실행 중 McDuck 종료 → quarantine 제거 → 콘솔 사용자로 실행.
   - `.zip` — `McDuck.app` + `Install McDuck.command`(관리자 암호로 설치/실행).
   - 체크섬(`.sha256`).
5. **게시** — 기존 `McDuck-<라인>` 릴리스/태그를 지우고(`gh release delete --cleanup-tag`) 이번 커밋에서 재생성(`gh release create`). `McDuck-<라인>`은 라인 내 최신 main 빌드를 가리키는 이동 릴리스입니다.

### 릴리스 자산

| 자산 | 용도 |
| --- | --- |
| `McDuck-<버전>.pkg` | 버전 표기된 설치 패키지 |
| `McDuck.pkg` | **고정 이름** — `releases/latest/download/McDuck.pkg`로 API 없이 받기 위함 |
| `McDuck-<버전>-macos.zip` | 앱 + `Install McDuck.command` |
| `install.sh` | 한 줄 설치 스크립트 |
| `McDuck-<버전>-checksums.sha256` | 체크섬 |

---

## 5. 설치 방법

### A. 한 줄 설치 (권장, 경고 없음)

```bash
# 최신
curl -fsSL https://github.com/hanoseok/McDuck/releases/latest/download/install.sh | bash

# 특정 버전(태그를 인자로 전달)
curl -fsSL https://github.com/hanoseok/McDuck/releases/download/v0.0.20/install.sh | bash -s -- v0.0.20
```

`curl`로 받은 파일에는 quarantine이 붙지 않아 Gatekeeper가 막지 않습니다. `xattr`·시스템 설정 불필요, **관리자 암호만** 한 번 입력(`sudo installer`). 스크립트는 GitHub API를 호출하지 않고 `releases/latest/download/McDuck.pkg`를 직접 받습니다(익명 레이트리밋 403 회피).

### B. `.pkg` 더블클릭

`McDuck-<버전>.pkg`(또는 `McDuck.pkg`) 더블클릭 → 설치 마법사 → 설치 + 자동 실행.

> 브라우저로 받은 pkg는 공증이 없어 첫 실행 시 Gatekeeper가 막을 수 있습니다. **우클릭 → 열기**, 또는 한 번만 `xattr -dr com.apple.quarantine <pkg>` 후 열기.

### C. `.zip` + 설치 스크립트

```bash
cd ~/Downloads
unzip -o McDuck-<버전>-macos.zip
bash "McDuck-<버전>/Install McDuck.command"   # 관리자 암호로 설치 + quarantine 제거
```

### D. 수동

```bash
xattr -dr com.apple.quarantine McDuck.app
open McDuck.app
```

### 무결성 확인(선택)

```bash
shasum -a 256 -c McDuck-<버전>-checksums.sha256
```

---

## 6. 코드 서명 / 공증

현재 앱·pkg는 **ad-hoc 서명만** 되어 있고 **공증(notarization)은 하지 않습니다**. 그래서 브라우저 다운로드 시 Gatekeeper 경고가 날 수 있으며, 위 A(curl) 또는 C(install.command) 방식이 이를 우회합니다.

**경고 없이 순수 더블클릭만으로** 열리게 하려면 유료 **Apple Developer Program**의 Developer ID 인증서로 서명 + 공증이 필요합니다. 추가하려면 워크플로에:

1. `codesign`(Developer ID Application)으로 앱 서명
2. `productsign`/`pkgbuild --sign`(Developer ID Installer)으로 pkg 서명
3. `xcrun notarytool submit` → `xcrun stapler staple`

인증서와 App-specific password는 **GitHub Secrets**에 등록합니다.

---

## 7. 트러블슈팅

- **한 줄 설치가 403** → 구버전 스크립트가 GitHub API를 호출하던 문제. 최신 릴리스 스크립트는 API를 쓰지 않습니다. `releases/latest/download/...`를 사용하세요.
- **"손상되어 열 수 없음" / "확인되지 않은 개발자"** → 공증 미적용 때문. A·C 방식 또는 수동 `xattr`로 해결.
- **첫 실행 시 ccusage 못 찾음** → GUI 앱은 PATH가 최소화됩니다. 앱은 `~/.bun/bin`, `/opt/homebrew/bin` 등을 탐색하고 서브프로세스 PATH를 보강합니다. 그래도 없으면 팝오버의 Install 버튼으로 설치하세요.
- **사용량이 안 뜨거나 파싱 오류** → ccusage 출력 스키마는 버전마다 다릅니다(`date`/`period`, `breakdown`/`modelBreakdowns`). 파서는 누락에 관대하며, 디코딩 실패 시 원본 출력 일부를 담은 에러를 표시합니다.
- **앱이 실행 즉시 종료(메뉴바에 안 뜸)** → `Bundle.module`(SwiftPM 리소스 번들)이 수동 조립 `.app`에서 번들을 못 찾아 `Fatal error`로 크래시한 사례. 리소스는 `Bundle.main`/`Assets.car`에서 로드해야 합니다(아래 8장). 진단: `/Applications/McDuck.app/Contents/MacOS/McDuck`을 터미널에서 직접 실행해 에러 출력 확인.

---

## 8. 아이콘 / 에셋 / 리소스 로딩

이미지는 `Resources/`에 두고 `build-app.sh`가 앱 번들에 넣습니다. **`Bundle.module`은 사용하지 않습니다.**

| 용도 | 소스 | 처리 | 런타임 로드 |
| --- | --- | --- | --- |
| 앱 아이콘(Finder/설치 마법사) | `Resources/AppIcon.png` | `iconutil` → `AppIcon.icns` | `Info.plist`의 `CFBundleIconFile=AppIcon` |
| 타이틀(팝오버 헤더) | `Resources/McDuck-title.png` | `Contents/Resources/`로 복사 | `Bundle.main` (`AppImages.titleIcon`) |
| 메뉴바 | `Resources/McDuck-menubar.png` | `sips`로 imageset(1x/2x/3x) 재생성 → `actool`로 `Assets.car` 컴파일 | `MenuBarExtra("McDuck", image: "MenuBarIcon")` |

핵심 주의:

- **`Bundle.module` 금지** — SwiftPM 접근자가 수동 `.app`에서 번들을 못 찾아 크래시. `Bundle.main`(=`Contents/Resources`) 또는 컴파일된 `Assets.car`에서 로드.
- **`swift build`는 `.xcassets`를 컴파일하지 않음** — `build-app.sh`에서 `actool`로 `Assets.car` 생성.
- **메뉴바 커스텀 아이콘은 이름 있는 에셋 이미지**(`MenuBarExtra(image:)`)를 사용. `Image(nsImage:)`는 메뉴바 라벨에서 안 보일 수 있음.
- **메뉴바 아이콘 크기 조정**: `build-app.sh`의 imageset 생성 px(= point × scale)만 변경. 현재 24pt(24/48/72px). macOS 메뉴바 높이(~22pt) 한계로 그 이상은 줄여서 표시될 수 있음.
- **버튼 Liquid Glass**: `mcDuckGlassButton()`(macOS 26 `.glass`, 이전 `.bordered`). 차트 호버 툴팁은 차트 annotation이 아니라 최상위 `.overlay`로 그려 범례 위에 불투명 표시.
