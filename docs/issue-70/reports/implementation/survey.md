# Survey — issue-70 (A+ 인증 마감)

scout skip condition: 이 이슈는 감사에서 이미 확정된 3개 차단 사유를 그대로
해소하는 작업이다(버그성 정정 + 문서 오타 수준) — 새로운 설계 결정이 없다.
scout-directive의 skip 조건 "spec leaves no design decision open"에 해당하여
scout sweep 생략.

## 대상 1: hunt-guard.sh:10 / hunt-state.sh:21 — source 가드 부재

두 파일 모두 core 플러그인의 `gate-lib.sh`를 다음 패턴으로 source 한다:

```
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
```

`gate-lib.sh`는 이 레포에 존재하지 않는다(별도 레포
`tokenmaxxxer-core`에서 옴, `find . -iname gate-lib.sh` 결과 없음). 즉
`CLAUDE_PLUGIN_ROOT_CORE`가 설정되지 않고 상대경로 fallback
(`../../core`)도 존재하지 않는 clean clone/테스트 환경에서는 `cd`가
실패해 fallback이 빈 문자열이 되고, `. "/hooks/lib/gate-lib.sh"` source가
실패한다.

- **hunt-guard.sh**: 3번째 줄에서 `trap __fc EXIT`를 먼저 설치했으므로,
  source 실패(rc≠0, rc≠2) 시 trap이 강제로 exit 2(DENY)로 재매핑한다.
  fail-closed 자체는 이미 동작하지만, 사용자에게는 raw bash 에러
  (`No such file or directory`)만 보이고 "core 플러그인 누락"이라는 원인은
  드러나지 않는다. 이 gap과 그 회귀를 고정하는 테스트가 없다는 점이
  차단 사유다.
- **hunt-state.sh**: EXIT trap이 전혀 없다. 21번째 줄 source 실패 시
  `set -e`가 없으므로 스크립트는 계속 실행되어 22번째 줄
  `gate_kill_switch_active ...`를 호출하는데, 이 함수는 (source 실패로)
  정의되지 않아 "command not found"로 비정상 종료(rc=127)한다. 이는
  `gate_kill_switch_active ... || exit 0` 표현식의 `||`를 그대로
  트리거하여 **release/reset 로직 실행 전에 exit 0으로 조용히
  종료**한다. 실제 영향: core 플러그인이 없는 환경에서
  hunt-guard.sh가 한 번이라도 lock을 쓰면, hunt-state.sh가 그 lock을
  절대 해제하지 못해 워런트 헌터가 영구적으로 잠기는 실패 모드가
  생긴다. hunt-guard.sh의 fail-closed 의도와 정반대로 hunt-state.sh는
  fail-open(그것도 핵심 동작을 건너뛰며) 상태다.

기존 테스트(`coding/hooks/tests/hunt-guard-tests.sh`)는 `CLAUDE_PLUGIN_ROOT_CORE`가
없으면 홈 디렉터리/상대경로에서 core를 찾아 **주입**하는 방식이라,
core가 아예 없는 케이스는 한 번도 실행되지 않는다 — missing-core 테스트가
없다는 감사 사유와 일치.

## 대상 2: state.sh — coding 분기 오류

`coding/hooks/state.sh:9`는 `CLAUDE_ROLE`이 `"coding"`인지 확인하고,
`state.sh:14`는 브랜치가 `issue-*/coding` 패턴인지 확인한다. 그러나
README.md 자체가 명시하듯 "The plugin directory is still named `coding` —
... the `implementation` role name used everywhere else" — 실제 role은
`implementation`이고, 브랜치는 이 세션이 바로 그 예시이듯
`issue-<n>/implementation`이다 (`git symbolic-ref --short HEAD` →
`issue-70/implementation`). 즉 state.sh의 두 조건은 실제 환경에서
**절대 참이 될 수 없다** — SessionStart에 항상 등록되지만 항상
조용히 no-op으로 종료되는 죽은 코드다. 이 SessionStart 훅이 만들어내려는
동작(직전 이슈/PR 상태 안내)은 실제로는 한 번도 실행되지 않는다.

`hunt-guard.sh` 등 다른 hunt 관련 hook에는 이런 role/branch 이름 문제가
없다(그쪽은 `CLAUDE_ROLE`/브랜치 패턴을 참조하지 않음). state.sh만
해당.

## 대상 3: README.md — 레포명 오기

`README.md:2` 제목이 `# tokenmaxxxer / coding-agent-rulebook`으로 되어
있으나, `git remote -v` 확인 결과 실제 레포는
`github.com/tokenmaxxxer/implementation-rulebook`이다. 세션 작업
디렉터리명(`implementation-rulebook-issue-70-implementation`)과도
일치한다. 단순 오기.

## 영향받는 테스트

- `coding/hooks/tests/hunt-guard-tests.sh` — 현재 core를 찾아 주입하므로
  green 유지 확인 대상(변경 후에도 계속 통과해야 함).
- hunt-state.sh에는 전용 테스트 파일이 없음 — 이번에 신설 필요
  (missing-core 케이스 포함).
