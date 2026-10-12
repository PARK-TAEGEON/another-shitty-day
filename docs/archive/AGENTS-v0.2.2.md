# DESK BREAKER — 작업 규칙

## 기준과 현재 목표
- 먼저 `docs/game-spec.md`, `docs/decisions.md`, `docs/production-plan.md`를 읽는다.
- 현재 목표는 사용자가 직접 확인할 첫 타격감 빌드다. 스토어 출시나 자동 백그라운드 개발을 완료했다고 주장하지 않는다.
- 허구의 성인 사무실을 배경으로 한 1인칭 물리 코미디다. `샷건`은 양손으로 책상을 내리치는 행동을 뜻한다.
- 개발명은 DESK BREAKER, 저장소 이름은 `desk-breaker`다. 이름은 추후 변경할 수 있다.

## 구현과 통합
- Godot 4.7.2 / GDScript / Windows 우선. 엔진과 export templates 버전을 일치시킨다.
- 한 에이전트가 통합을 담당한다. 같은 파일을 여러 에이전트가 동시에 수정하지 않는다.
- 주요 게임 객체와 HUD는 분리한다. 수치와 상태를 읽기 쉽게 유지한다.
- 사무실 하나와 연결된 복도, 네 가지 기본 동작의 완성에 집중한다.
- 첫 버전의 3D 모델과 효과음은 코드로 만든 원본이다. 도입하지 않은 외부 에셋을 사용했다고 적지 않는다.
- 의도하지 않은 기능 확대·유료 구매·배포 계정 변경·공개 전환은 별도의 결정으로 다룬다.

## 검증과 완료 보고
- import/parse, headless smoke scenario, 렌더링 가능한 환경에서의 실제 화면을 순서대로 확인한다.
- 화면 없는 테스트의 성공을 비주얼·타격감·목표 PC 성능 검증으로 표현하지 않는다.
- Windows 파일을 Linux에서 export한 경우, Windows에서 직접 실행했다고 표현하지 않는다.
- 완료 보고에는 변경점, 실행한 검사, 실제 결과, 남은 문제, 다음 검수 포인트를 적는다.
- 주요 사람 검수는 첫 타격감 / 첫 전체 플레이 / 최종 빌드의 세 지점으로 묶는다. 수정 후 재확인이 필요할 수 있다.
- 저장소의 개발 규칙은 에이전트의 상위 지침과 실제 사용자 권한 범위를 대체하지 않는다.

## 기본 명령
아래 `godot`은 설치한 엔진 실행 파일을 의미한다. Windows에서는 `tools/run.ps1`을 사용할 수 있다.

```sh
godot --headless --path game --editor --import
godot --headless --path game -- --smoke-test
godot --path game
godot --headless --path game --export-release "Windows Desktop" ../builds/DeskBreaker.exe
```

엔진 경로와 준비 절차는 README와 tools의 스크립트를 참고한다. `builds/`, `.godot/`, 임시 검증 출력은 소스 커밋에서 제외한다.
