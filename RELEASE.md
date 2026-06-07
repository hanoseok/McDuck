# McDuck 기능 목차

추가된 기능을 영역별로 한 줄씩 정리합니다.

## 목차

- [앱 기능](#앱-기능)
- [빌드·릴리스 파이프라인](#빌드릴리스-파이프라인)
- [버전별 추가 기능](#버전별-추가-기능)

## 앱 기능

- **메뉴바 앱**: macOS 메뉴바 아이콘에서 SwiftUI 팝오버로 `ccusage` 토큰 사용량을 표시합니다.
- **메뉴바 사용량 라벨**: 아이콘 옆에 선택한 기간(None/Today/Week/Month/Total)의 지표(Token/Cost/Both)를 표시합니다.
- **Claude Code 연동**: 사용량을 MCP 서버(`mcduck-mcp`)로 제공하고, `usage-report` 스킬과 플러그인으로 묶어 배포합니다.
- **사용량 히트맵**: 일별 토큰 사용량을 GitHub 스타일 12개월 히트맵(토큰박스)으로 시각화합니다.
- **일별 상세**: 선택한 날의 토큰·비용·캐시·모델별 분해를 보여줍니다.
- **연도 선택**: 최근 12개월 보기와 특정 연도 보기를 토글합니다.
- **범위 요약 + 차트**: 일/주/월/커스텀 범위의 합계와 Swift Charts 막대 그래프를 제공합니다.
- **활동 시간**: `ccusage blocks` 기반으로 일별 활성 사용 시간을 표시합니다.
- **자동 새로고침**: 백그라운드에서 10분 간격으로 조용히 데이터를 갱신합니다.
- **로그인 시 자동 실행**: 헤더 기어 버튼의 설정에서 `SMAppService`로 로그인 항목 등록/해제를 토글합니다.
- **셋업 화면**: Bun·`ccusage`가 없으면 설치 안내와 원클릭 설치를 제공합니다.
- **Liquid Glass UI**: macOS 26+에서 Liquid Glass, 이전 버전은 머티리얼로 폴백합니다.

## 빌드·릴리스 파이프라인

- **태그 기반 빌드**: 태그를 만들면 GitHub Actions가 그 버전으로 빌드·게시합니다.
- **정식 릴리스 채널**: `main`에 `MAJOR.MINOR` 태그(예: `1.0`) → `McDuck-1.0` 게시(`releases/latest`).
- **스냅샷 채널**: `develop`에 `X.Y.Z-SNAPSHOT` 태그 → prerelease + 이동 `snapshot-latest`.
- **스냅샷 버전 규칙**: 정식 `X.Y`가 릴리스되면 다음 스냅샷은 `X.(Y+1).0-SNAPSHOT`부터 시작합니다(예: `1.0` 릴리스 → `1.1.0-SNAPSHOT`).
- **원라이너 설치**: `install.sh`/`install-snapshot.sh`로 quarantine 경고 없이 `.pkg`를 설치합니다.
- **릴리스 자산**: `.pkg`, 안정 이름 `McDuck.pkg`, `.zip`, `.sha256` 체크섬, 자동 릴리스 노트를 첨부합니다.
- **CI 매트릭스**: PR에서 macOS 15·26 매트릭스로 `swift test`를 실행합니다.
- **클라우드 에이전트 브리지(`cut.yml`)**: 마커 파일 변경 + PR 머지로 태그 빌드를 트리거합니다(태그 push 불가 환경용).

## 버전별 추가 기능

### 1.1 (Stable)

McDuck을 Claude Code 생태계와 연동하고, 메뉴바 사용량 표시·시스템 통합·개발 워크플로를 강화한 릴리스입니다.

**Claude Code 연동 (MCP · 스킬 · 플러그인)**

- **MCP 서버 `mcduck-mcp`**: 사용량을 stdio MCP 서버로 제공 — 툴 `usage_summary` / `daily_usage` / `model_breakdown`. `McDuckCore`의 ccusage 파싱을 재사용합니다.
- **`usage-report` 스킬 + Claude Code 플러그인**: MCP 서버와 스킬을 하나의 플러그인으로 묶어 마켓플레이스로 배포합니다. `/plugin marketplace add hanoseok/McDuck` → `/plugin install mcduck@mcduck`.
- **앱 번들에 플러그인 동봉**: `McDuck.app`에 마켓플레이스·플러그인·프리빌트 `mcduck-mcp` 바이너리를 포함해, 네트워크·Swift 툴체인 없이 로컬에서 설치할 수 있습니다.
- **설정에서 등록/제거**: 설정 패널에서 미설치면 "Add to Claude Code", 설치돼 있으면 "Remove from Claude Code". `claude` CLI를 먼저 시도하고, 실패 시 `~/.claude/settings.json`의 마켓플레이스·`enabledPlugins`를 안전 병합으로 추가/제거합니다.
- **릴리스 자산 + 런처**: release/snapshot이 `mcduck-mcp` 바이너리를 첨부하고, 플러그인 런처가 이를 받아 씁니다(없으면 소스 빌드 폴백).

**메뉴바 사용량 라벨**

- **기간 + 지표 선택**: 기간(None / Today / Week / Month / Total, 기본 Today)과 지표(Token / Cost / Both, 기본 Both)를 설정에서 각각 고릅니다. 비용은 소수점 없이, Both는 2줄로 표시하며 아이콘 크기는 고정됩니다.
- **실행 즉시 프리페치**: 앱이 켜지면 팝오버를 열지 않아도 ccusage를 바로 가져와 메뉴바 숫자를 준비합니다.

**시스템 통합**

- **로그인 시 자동 실행**: 설정에서 `SMAppService`로 로그인 항목을 토글합니다(`.notFound`일 때도 등록을 시도하고 실패 시 에러 표시).
- **앱 아이콘 통일**: Finder/Dock 아이콘을 팝오버 헤더 이미지(`McDuck-title.png`)와 동일하게 생성합니다.

**설치 · 빌드 · 개발**

- **설치 스크립트 버전 표시**: `install.sh`/`install-snapshot.sh`가 다운로드·설치·완료 메시지에 버전을 표시합니다(latest는 `releases/latest` 리다이렉트로 실제 버전 해석).
- **자정 날짜 롤오버**: 토큰박스를 직접 클릭하지 않았으면 00시에 기본 선택일이 다음 날로 이동합니다.
- **TDD + 리그레션 스위트**: 앱 타깃(`McDuckTests`)·MCP(`McDuckMCPTests`) 테스트를 추가하고 테스트 우선 워크플로를 채택했습니다.
- **빌드 파이프라인**: 태그 기반 빌드, 스냅샷 채널, 클라우드 에이전트 브리지(`cut.yml`)를 정비했습니다.

### 1.0 (Stable)

- **초기 정식 릴리스**: 메뉴바 토큰 사용량 앱 — 사용량 히트맵, 일별 상세, 범위 요약/차트, 활동 시간, 셋업 화면, Liquid Glass UI (세부는 [앱 기능](#앱-기능) 참조).
