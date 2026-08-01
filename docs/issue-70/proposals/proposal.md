---
files:
  - coding/hooks/hunt-guard.sh
  - coding/hooks/hunt-state.sh
  - coding/hooks/state.sh
  - coding/hooks/tests/hunt-guard-tests.sh
  - coding/hooks/tests/hunt-state-tests.sh   # new
  - README.md
---

## Request

이슈 #70: 2026-08-01 인증 감사가 A+ 인증을 막은 3개 사유를 해소한다.
(1) hunt-guard.sh:10 / hunt-state.sh:21의 core `gate-lib.sh` source에
가드가 없어 core 플러그인이 없는 환경에서 실패 모드가 서로 다르게(하나는
fail-closed, 하나는 조용히 fail-open) 나타남 + 이를 고정하는 missing-core
테스트 부재. (2) state.sh의 SessionStart 훅이 `CLAUDE_ROLE=coding` /
브랜치 `issue-*/coding`을 찾는데 실제 role/브랜치 이름은
`implementation`이라 항상 죽은 코드로 no-op됨. (3) README.md 제목의
레포명이 `coding-agent-rulebook`으로 오기되어 있음(실제
`implementation-rulebook`).

## Constraints

- 코드 변경 후 관련 테스트는 배송 상태·clean clone 기준으로 green
  유지(이슈 요구 1).
- sales 트랙의 core #78(stub-check 공인 조합 형식) 랜딩 후 착수 —
  implementation 트랙인 이 이슈에는 해당 없음(이슈 본문 "sales만 해당"
  명시).
- record에 해소 확인용 테스트/프로브 실행 로그를 남긴다(이슈 요구 3).
- core 플러그인(`gate-lib.sh`)은 이 레포 밖(tokenmaxxxer-core)에
  있으므로, 수정은 이 레포의 소비 측(source 가드)에 한정하고 core
  자체는 손대지 않는다.

## Rationale

**hunt-guard.sh/hunt-state.sh 가드 방식**: source 실패를 사전에
`[ -f ... ]`로 검사해 사람이 읽을 수 있는 메시지와 함께 명시적으로
분기하는 방식을 선택한다. 대안으로 "두 스크립트 모두 hunt-guard.sh와
동일한 EXIT trap(비정상 종료 시 무조건 exit 2)을 붙여 통일한다"를
considered and rejected — rejected instead of adopted, for this reason:
hunt-state.sh는 PreToolUse 게이트가 아니라 SessionStart/SubagentStop의
상태 유지 스크립트이고, `directive.sh` 주석이 명시하듯 이쪽은
"informing only; never blocks"가 설계 의도다. hunt-state.sh를
hunt-guard.sh처럼 fail-closed로 만들면 SubagentStop 훅이 차단성 종료
코드를 반환하게 되어 core 플러그인이 없을 때 정상 작업(서브에이전트
완료)까지 막을 위험이 생긴다. 대신 hunt-state.sh는 source 실패를 명시
감지해 release/reset 로직을 core 없이도 최대한 수행(lock/count 파일은
core 함수에 의존하지 않는 순수 rm이므로 kill-switch 체크만 건너뛰고
본연의 정리 작업은 그대로 실행)하도록 고친다. hunt-guard.sh는 기존
fail-closed trap은 유지하되, source 실패 시 stderr 메시지를 "core
플러그인 누락"으로 명확화한다.

**state.sh coding 분기**: "정정" 대 "제거" 중 정정(문자열을
`implementation`/`issue-*/implementation`으로 교체)을 선택한다. "아예
제거"를 considered and rejected: state.sh가 제공하는 기능(직전 이슈/PR
승인 상태를 SessionStart에 요약) 자체는 유효하고 다른 파일 어디에도
중복 구현이 없다 — rejected because 제거하면 기능 손실이지만, 정정은
기존 로직을 그대로 살리면서 버그만 고친다. README가 이미 "role name
used everywhere else" = `implementation`이라고 명시하므로 정정 방향이
기존 문서와 일치한다.

**missing-core 테스트 신설 방식**: 기존 `hunt-guard-tests.sh`의 주입
로직(13-17번 줄, `CLAUDE_PLUGIN_ROOT_CORE` 자동 탐색)을 건드리지 않고,
새 테스트 파일(`hunt-state-tests.sh`)과 `hunt-guard-tests.sh`에 케이스를
추가하는 두 갈래로 간다. "기존 파일 하나에 헌트가드+헌트스테이트 전부
합친다"를 considered and rejected, instead of a single combined file:
두 스크립트는 서로 다른 실패 모드(deny vs 상태 정리 스킵)를 검증하므로
파일을 분리해야 어느 스크립트가 회귀했는지 테스트 실패 지점만으로 바로
식별된다는 것이 rejected 사유다.

## What will be done

1. `hunt-guard.sh` — source 줄 앞에 `gate-lib.sh` 존재 여부를
   `[ -f ... ]`로 검사하고, 없으면 trap이 잡는 raw 에러 대신
   "core 플러그인을 찾을 수 없음"이라는 명시적 stderr 메시지 후 fail-closed
   (exit 2) 유지.
2. `hunt-state.sh` — 동일하게 `gate-lib.sh` 존재를 사전 검사; core가
   없으면 kill-switch 체크만 건너뛰고 release/reset(lock·count 파일
   rm)은 그대로 수행한 뒤 exit 0. core가 있으면 기존 동작 유지.
3. `state.sh` — `CLAUDE_ROLE` 비교값과 브랜치 패턴을
   `implementation`/`issue-*/implementation`으로 정정. 기존 SessionStart
   출력 로직(PR 상태 조회, record 존재 안내)은 그대로 둔다.
4. `README.md` — 제목의 `coding-agent-rulebook` → `implementation-rulebook`
   정정(실제 원격 저장소명과 일치).
5. `coding/hooks/tests/hunt-guard-tests.sh`에 missing-core 케이스
   추가(core를 주입하지 않고 `CLAUDE_PLUGIN_ROOT_CORE`를 존재하지 않는
   경로로 강제해 fail-closed(exit 2)를 확인).
6. `coding/hooks/tests/hunt-state-tests.sh` 신설 — missing-core에서도
   release/reset이 lock·count 파일을 실제로 지우는지, core가 있을 때
   기존 동작(kill switch 존중)이 유지되는지 검증.
7. 두 테스트 스위트를 실행해 green을 record에 로그로 남긴다(phase 2).

## Out of scope

- core 레포(`tokenmaxxxer-core`)의 `gate-lib.sh` 자체 수정 — 이 레포가
  소유하지 않음.
- sales 트랙 core #78 관련 작업 — 이슈 본문이 sales 전용이라고 명시.
- hunt-guard.sh의 세션 캡/lock 로직 자체 변경 — 감사 사유에 없음, 이번
  범위는 source 가드와 테스트에 한정.
- state.sh 외 다른 훅의 role/branch 명명 재검토 — 서베이 결과 다른
  hunt 관련 훅은 role/branch 이름을 참조하지 않아 해당 없음.

## How you'll know it worked

- `hunt-guard-tests.sh`가 기존 케이스 + 신규 missing-core 케이스 모두
  통과(exit 0, 전부 `ok`).
- `hunt-state-tests.sh`(신규)가 missing-core에서도 lock/count 파일
  삭제를 확인하고, core 정상 시 기존 kill-switch 동작을 확인하며 통과.
- `state.sh`를 `issue-70/implementation` 브랜치 + `CLAUDE_ROLE=implementation`
  환경에서 직접 실행해 더 이상 no-op 하지 않고 PR 상태 안내 줄을
  출력하는지 수동 확인.
- `README.md`에 `implementation-rulebook` 문자열이 등장하고
  `coding-agent-rulebook` 문자열이 더 이상 남아있지 않음(grep 확인).
- 위 실행 로그를 phase 2 record(`docs/issue-70/reports/implementation.md`)에
  남긴다.
