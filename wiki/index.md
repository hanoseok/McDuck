---
okf_version: "0.1"
title: McDuck OKF Wiki
description: Open Knowledge Format style project wiki for McDuck development, progress, decisions, and retrospectives.
---
# McDuck OKF Wiki

McDuck 프로젝트의 개발 지식, 진행 상황, 의사결정, 회고를 **Open Knowledge Format(OKF) v0.1 스타일**로 관리하는 번들입니다.

OKF 원칙에 맞춰 이 폴더는 다음 규칙을 따릅니다.

- 모든 일반 문서는 Markdown + YAML frontmatter로 작성합니다.
- `index.md`는 해당 디렉터리의 목차와 progressive disclosure를 담당합니다.
- `log.md`는 해당 범위의 시간순 변경 이력을 담당합니다.
- 개념 간 관계는 일반 Markdown 링크로 표현합니다.
- 파일 경로가 곧 concept identity입니다.

# Start Here

* [Project Overview](project-overview.md) - McDuck의 목적, 제품 범위, 핵심 표면을 한눈에 봅니다.
* [Architecture](architecture/) - 앱, 코어, MCP, 플러그인, 릴리스 파이프라인의 구조를 정리합니다.
* [Modules](modules/) - 코드 모듈과 주요 책임을 파일 단위로 추적합니다.
* [Projects](projects/) - 진행 중인 기능/개선 프로젝트를 관리합니다.
* [Progress](progress/) - 개발 진행 상황, 작업 로그, 현재 상태를 누적합니다.
* [Decisions](decisions/) - 장기적으로 유지할 설계/제품/릴리스 의사결정을 기록합니다.
* [Retrospectives](retrospectives/) - 릴리스·스프린트·장애·작업 회고를 보관합니다.
* [Runbooks](runbooks/) - 반복 실행 절차와 검증 명령을 정리합니다.
* [References](references/) - 외부 사양, 글, 내부 문서에서 가져온 근거를 OKF concept으로 보관합니다.
* [Templates](templates/) - 새 문서를 만들 때 복사할 frontmatter와 섹션 템플릿입니다.

# Maintenance Rules

* 새 기능 작업을 시작하면 `/projects/` 또는 `/progress/`에 관련 concept을 만듭니다.
* 구조적 결정을 내리면 `/decisions/`에 ADR 형태로 기록합니다.
* 릴리스나 큰 작업이 끝나면 `/retrospectives/`에 회고를 남깁니다.
* 외부 자료를 근거로 삼으면 `/references/`에 concept을 만들고 문서의 `# Citations`에서 링크합니다.
* 문서를 추가/수정하면 가까운 `log.md`에 날짜별 항목을 남깁니다.
