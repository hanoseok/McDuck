# McDuck 빌드 · 릴리스 · 설치 가이드

McDuck은 **macOS 26 네이티브 앱**(Swift / SwiftUI)입니다. macOS 전용이라 Linux 클라우드 세션에서는 직접 빌드할 수 없고, **GitHub Actions의 macOS 러너에서 빌드 → 버전 릴리스 → 다운로드/설치**하는 흐름을 사용합니다.

---

## 1. 사전 요구사항

**로컬 빌드(맥에서 직접):**
- macOS 26 이상
- Xcode 26 이상 (Swift 6.2+ 툴체인)
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

- 버전은 **저장소 루트의 `RELEASE_VERSION` 파일** 한 줄(`vX.Y.Z`)로 관리합니다.
- semver를 사용하고, **한 번 게시한 버전은 재사용하지 않습니다.**
- 빌드된 앱 번들에는 이 버전이 스탬프되며, 앱 팝오버 푸터에 `vX.Y.Z`로 표시됩니다.

---

## 4. 원격 릴리스 (권장 흐름)

릴리스는 `.github/workflows/release.yml`이 macOS 러너에서 처리합니다. **세 가지 트리거** 모두 같은 결과(태그 + GitHub Release)를 만듭니다.

| 방법 | 사용 상황 |
| --- | --- |
| **`RELEASE_VERSION` 수정 후 작업 브랜치 push** | 권장. 태그 push 권한이 없는 클라우드 세션에서도 동작. |
| 버전 태그 push (`git tag v1.2.0 && git push origin v1.2.0`) | 로컬/CI에서 태그 push 권한이 있을 때. |
| Actions에서 `workflow_dispatch` 수동 실행(버전 입력) | 워크플로가 기본 브랜치에 있을 때. |

### `RELEASE_VERSION` 흐름

```bash
printf 'v1.2.0\n' > RELEASE_VERSION
git add RELEASE_VERSION
git commit -m "Release v1.2.0"
git push origin <branch>     # 이 push가 워크플로를 트리거
```

### 워크플로 단계

1. **버전 확인** — dispatch면 입력값, 태그 push면 태그명, 브랜치 push면 `RELEASE_VERSION` 내용.
2. **중복 게이트** — 해당 버전 Release가 이미 있으면 빌드 스킵(무관한 커밋 push가 재릴리스되지 않도록). 즉 **Release 존재 = 빌드·테스트 통과**.
3. **테스트** — `swift test`.
4. **빌드** — `scripts/build-app.sh` (버전 스탬프 + ad-hoc 서명).
5. **패키징**
   - `.pkg` — `pkgbuild`로 `/Applications` 설치 패키지 생성. `postinstall`이 실행 중 McDuck 종료 → quarantine 제거 → 콘솔 사용자로 실행.
   - `.zip` — `McDuck.app` + `Install McDuck.command`(관리자 암호로 설치/실행).
   - 체크섬(`.sha256`).
6. **게시** — `gh release create`로 자산 첨부(in-workflow `GITHUB_TOKEN`이 release/tag 생성).

### 릴리스 자산

| 자산 | 용도 |
| --- | --- |
| `McDuck-<tag>.pkg` | 버전 표기된 설치 패키지 |
| `McDuck.pkg` | **고정 이름** — `releases/latest/download/McDuck.pkg`로 API 없이 받기 위함 |
| `McDuck-<tag>-macos.zip` | 앱 + `Install McDuck.command` |
| `remote-install.sh` | 한 줄 설치 스크립트 |
| `McDuck-<tag>-checksums.sha256` | 체크섬 |

---

## 5. 설치 방법

### A. 한 줄 설치 (권장, 경고 없음)

```bash
curl -fsSL https://github.com/hanoseok/McDuck/releases/latest/download/remote-install.sh | bash
```

`curl`로 받은 파일에는 quarantine이 붙지 않아 Gatekeeper가 막지 않습니다. `xattr`·시스템 설정 불필요, **관리자 암호만** 한 번 입력(`sudo installer`). 스크립트는 GitHub API를 호출하지 않고 `releases/latest/download/McDuck.pkg`를 직접 받습니다(익명 레이트리밋 403 회피).

### B. `.pkg` 더블클릭

`McDuck-<tag>.pkg`(또는 `McDuck.pkg`) 더블클릭 → 설치 마법사 → 설치 + 자동 실행.

> 브라우저로 받은 pkg는 공증이 없어 첫 실행 시 Gatekeeper가 막을 수 있습니다. **우클릭 → 열기**, 또는 한 번만 `xattr -dr com.apple.quarantine <pkg>` 후 열기.

### C. `.zip` + 설치 스크립트

```bash
cd ~/Downloads
unzip -o McDuck-<tag>-macos.zip
bash "McDuck-<tag>/Install McDuck.command"   # 관리자 암호로 설치 + quarantine 제거
```

### D. 수동

```bash
xattr -dr com.apple.quarantine McDuck.app
open McDuck.app
```

### 무결성 확인(선택)

```bash
shasum -a 256 -c McDuck-<tag>-checksums.sha256
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
</content>
