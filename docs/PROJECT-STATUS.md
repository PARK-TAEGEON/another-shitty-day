> **2026-10-13 김 팀장 통합:** `integration/kim-ragdoll-office-v03`는 PR #8 위에 PR #1→#2의 실제 Blender/GLB와 하이브리드 래그돌을 결합한다. 새 김 팀장 기본 ON, 기존 모델 복귀 및 1회 발차기/체력 기준 비교 실행기를 제공한다. 3모드 회귀47개·Windows EXE GPU smoke·28초 통합 영상 VERIFIED. [통합 범위·의존성·증거·인간 검수](implementation/KIM-DEMO-INTEGRATION-2026-10-13.md). main 미병합, 최종 아트/재미와 장시간 성능 미승인. 아래 PR #2 기본 OFF 설명은 원래 슬라이스 시점의 기록이다.
> **2026-10-13 회사원 v0.3 구현 브랜치:** `implementation/office-scenario-v03`에서 기존 v0.2 결과물을 간소화했다. 사장 E 붙잡기/같은 층 물리 이동/목격 경찰 거리 유지/안전 해제, 경찰 Full·Short·Off와 기존 피해액 결과를 구현·검증했다. [실제 범위와 검증](implementation/OFFICE-SCENARIO-v0.3-2026-10-13.md). main 통합·최상층 접근·야구·다른 신규 시나리오·장시간 재미 검수는 완료하지 않았다. 아래 v0.2와 초기 main 감사는 해당 시점의 역사 정보다.

# Another Shitty Day | 실제 개발 현황 (Living Status)

## 2026-10-13 회사원 시나리오 구현 브랜치

최신: [Draft PR #8](https://github.com/PARK-TAEGEON/another-shitty-day/pull/8), `implementation/office-scenario-v03`, base=main. #7을 대체하는 독립 수정안이며 둘을 함께 병합하지 않는다. A/B 퀘스트/결과 후보/보상 UI를 제거하고 사장 한 명의 Free/Held 관계로 교체했다. 범용 사건 스트림과 NPC 대사 우선순위·TTL·once/reset, 원본 책상/전투/소품/경비/피해액은 재사용한다. Chaos 모듈과 단위 검사는 독립 선택 실험으로 보존하며 게임의 의존성·저장·결과에서 분리했다. 사장·경찰 전용 서브클래스로 `office_npc.gd`와 PR #2 캐릭터 작업을 보호한다. 코드/증거 커밋 `0895d6d`, 기존 회귀10+신규4 PASS 및 독립 리뷰 수정 후 미해결 P1/P2 없음.

실제 Windows GPU 31.6초 시연에서 기본 사장 위치의 E 잡기, 기존 가구를 우회하는 연결 통로 이동, 최초 경찰 Full, 목격 거리 유지, E 해제 후 정상 물리 제압과 기존 달러 결과를 확인했다. 자동 시연은 시작 위치·경찰 배치/출동을 구성했으며 인간의 자발적 자유 플레이 승인과 구분한다. 출시 목표 2026-11-30은 유지한다. 최상층/층간 접근과 건물 핵심 구역은 다음 구현 과제다.

### 이전 v0.2 구현 이력

제출: [Draft PR #7](https://github.com/PARK-TAEGEON/another-shitty-day/pull/7), base=main. 코드/증거 검토용이며 자동 병합하지 않는다.

`implementation/office-scenario-v02`에 기존 사무실과 연결된 임시 사장실, O-30~38 A/B 실제 행동 분기, 최소 공통 사건 연결, 별도 결과 Chaos/최고 기록, 최초 경찰 입구 카메라를 **IMPLEMENTED**했다. Godot4.7.2 Windows에서 기존 회귀10+신규3, 실제42초 렌더/제압 결과, standalone Windows smoke를 **VERIFIED**했다. [상세 범위·증거·변경 파일](implementation/OFFICE-SCENARIO-v0.2-2026-10-13.md).

PR #2는 미병합 그대로다. 임시 로컬 결합의 OFF/ON 회귀·native smoke 통과, 기존 Kim 재시작 검사의 NPC7→8 기대치 조정 필요를 기록했다. 최종 아트/인간 재미·장시간 성능 승인, 전체 회사 건물/신고·수색/상위 대응은 남아 있다. **main에 병합되었다거나 Release-P2가 완료됐다는 의미가 아니다.** 11월30일 목표 및 기존 출시 범위는 유지한다. 아래 표는 이번 구현 브랜치 이전 main 감사 이력이다.

**최초 감사일:** 2026-10-13 KST · **GitHub 연결: Private / main**
**상태 정의:** `IMPLEMENTED`=코드/자산 존재, `VERIFIED`=명시된 환경·범위에서 검사 성공, `APPROVED CONCEPT`=사용자가 기획 방향 결정, `PROPOSED`=미구현 설계안, `BLOCKED`=선행 조건 미충족.
**이 문서는 매 자동 작업마다 갱신되지 않는다.** 작업 담당자가 PR·검증과 함께 갱신해야 한다. v0.2.2의 과거 상세 기록은 [current-status.md](current-status.md), 미래 목표는 [RELEASE-ROADMAP.md](RELEASE-ROADMAP.md).

## 1. 확인한 저장소·PR 기준

| 항목 | 현재 상태 | 근거 |
|---|---|---|
| `main` | 안정 게임 `3fcdd04915153b53f596777e30f38c04a7bbe891` (이번 문서 변경 이전 HEAD). Godot v0.2.2 기반, 기존 `game/` 유지 | [main](https://github.com/PARK-TAEGEON/another-shitty-day/tree/main), `docs/current-status.md` |
| 무료 애니메이션/래그돌 연구 | **기술 실험 VERIFIED, Draft PR #1 미병합** | [PR #1](https://github.com/PARK-TAEGEON/another-shitty-day/pull/1), 브랜치 `research/asset-reuse-2026-10-13`. [E0 CI 성공](https://github.com/PARK-TAEGEON/another-shitty-day/actions/runs/38348850781), [E1 CI 성공](https://github.com/PARK-TAEGEON/another-shitty-day/actions/runs/38349124791) |
| 김 팀장 리그·하이브리드 래그돌 | **별도 브랜치 opt-in 구현·기술 CI VERIFIED, 사용자 외형/재미 승인 전, 미병합** | [Draft PR #2](https://github.com/PARK-TAEGEON/another-shitty-day/pull/2), HEAD `bca6968bd1f5b4fbd9427c67baa14664e0107255`. [최신 CI 성공](https://github.com/PARK-TAEGEON/another-shitty-day/actions/runs/38354520997) |
| PR 관계 | **PR #2 base = PR #1 연구 브랜치**, PR #1 base=main. PR #2가 `docs/START-HERE.md`도 수정함 | GitHub PR metadata 및 파일 목록 |
| 승인 아트 기준 | **5인 풍자 만화형 이미지 APPROVED**, 게임 전체 최종 모델로 적용된 것 아님 | `art/references/approved/five-staff-unlikable-approved.png` |
| 시나리오 v0.3 | **기획 방향 채택 / Godot 구현 NOT IMPLEMENTED**. 특별 루트 A/B와 Chaos Score 의무 삭제 | [v0.3 기준](design/SCENARIO-V0.3-BASELINE.md), [Issue #3](https://github.com/PARK-TAEGEON/another-shitty-day/issues/3) |
| 온라인·은행 협동 | **NOT IMPLEMENTED / NOT VERIFIED** | [Issue #6](https://github.com/PARK-TAEGEON/another-shitty-day/issues/6) |

**PR #2 세부:** 31본 A포즈 Blender/GLB, 15개 실제 Jolt 물리본의 Light/Medium/Heavy, 옵션 `--kim-rig` (기본 OFF). PR 문서에 28초 사무실/25초 실험실 영상, Windows GTX 1660 SUPER 스모크 및 회귀 기록이 존재. **CI success는 직접 확인했으나 이 답변에서 영상을 새로 플레이하거나 장시간 60fps를 검사하지 않았다.** 자동 일어나기, 다른 직원 4명의 동일 모델/래그돌, 최종 실루엣·코미디·물리 안정성의 사용자 승인은 남아 있음.

## 2. 안정 `main`에 실제로 존재하는 기능

**IMPLEMENTED / 과거 v0.2.2 구현 및 해당 버전의 검증 기록:**
- 1인칭 사무실의 주먹·발차기·책상 내려치기(첫 B/반복 A), 집기·던지기/물체 손상.
- 부서 직원 5명 + 타 부서 2명, 일상 업무·놀람·구경·회피/항의.
- **박 대리 "왜 그래?" → 김 팀장 가림막 빼꼼 → "뭐야 무슨 소리야?" → 접근·잔소리** 골든 장면.
- 유한 경비/경찰 대응, 제압/결과/재시작, 좌상단 Social Damage($) HUD 및 피해액 장부.
- 기존 v0.2.2의 자세한 통과/미검증 범위는 `docs/current-status.md` 참조. **이번 문서 작업은 게임 테스트를 재실행하지 않았다.**

**아직 main에 없거나 설계만 있는 것:**
- 층간 이동·건물 여러 구역의 실제 연결, 사장 E 붙잡기/실제로 목격한 경찰의 대응 변화/안전 해제, 시장·공무원·교통사고·야구의 신규 공간과 대사/고유 소품. 시나리오당 특별 루트는 요구하지 않음.
- 고급 목격·신고/수색, 경찰차 도착 카메라·자막, 특수부대/헬기. 기존 Social Damage($) 유지, Chaos Score 신규 개발은 Phase-P2 필수 아님.
- 실제 Steam 2PC·2계정, 호스트 공유 물리·은행 협동·동료 구조/가방·4인 부하.
- **Core Mechanics v0.1**과 **Scenario v0.1**은 이전 대화에서 전달·리뷰된 설계 산출물. 현재 main에 구현됐거나 최종 승인 문서가 들어갔다는 뜻이 아니다. 시나리오 **v0.3은 현재 기획 기준으로 채택**했으나 Godot 기능이나 사용자 실기 테스트 완료로 승격시키지 않는다.

## 3. 기한별 현재 위치

| 목표 게이트 | 오늘의 상태 | 다음 행동 |
|---|---|---|
| **Release-P0 / 10-25** | **IN PROGRESS:** 기존 게임 + PR #1/#2 기술 근거 있음. 외형/타격감 실기 승인과 v0.3 기준의 실제 구현·검증은 남음 | PR #2 영상/실기 2개 품질 게이트, [Issue #3](https://github.com/PARK-TAEGEON/another-shitty-day/issues/3) |
| **Release-P1 / 11-08** | **PLANNED:** 기존 NPC·경비/경찰 기반만 있음 | [Issue #4](https://github.com/PARK-TAEGEON/another-shitty-day/issues/4)에서 공통 사건·반응 로직 구현/테스트 |
| **Release-P2 / 11-30** | **PLANNED:** 현재 한 사무층 및 도면/확장 아이디어만 있음 | [Issue #5](https://github.com/PARK-TAEGEON/another-shitty-day/issues/5) 회사 건물/사장 잡기·경찰 반응·해제/검수 |
| **M0 Steam / 10-31** | **PLANNED:** 연결·공유 물리 미검증 | [Issue #6](https://github.com/PARK-TAEGEON/another-shitty-day/issues/6) 작은 별도 기술 스파이크 |
| **2026-12~2027-03** | **NOT STARTED:** 다른 싱글 시나리오와 은행 협동 | 현재 공통 시스템 게이트 후 재사용 생산 |
| **2027-06-30 정식 1.0** | **TARGET ONLY** | 제품/플랫폼/성능/실제 재미 모두 통과 후 사용자 승인 |

## 4. 미확정 사항과 다음 담당

- **Reviewer:** PR #2 시각적 스타일·타격감 수동 검수(한 인물), 무결한 병합 경로(PR #1 후 PR #2), 지속 부하 확인. 아직 승인·머지 아님.
- **Scenario/Astra:** 시나리오 v0.3 채택 완료. 구현자에게 도입·첫 행동/NPC 반응·태도 변화·사장 한 명 E 붙잡기 등 경량 고유 요소를 인계. 별도 A/B 루트와 Chaos Score 미션 보상 재도입 금지. 설계 변경만으로 game/를 수정했다고 주장 금지.
- **Codex Implementer:** 코어 사건의 단일 root/action ID, 기존 피해액 중복 방지, NPC 반응과 경비/경찰을 한 PR에서 소유; 진행 상태 기록. 최신 PR 내용 기준 중복 작업 금지.
- **별도 Codex:** Steam 2PC 스파이크. 실제 접속/물리 권한을 확인하기 전 은행 전체 제작 금지.
- **통합자:** Issue #5 달성에 필요한 건물/사장 E 잡기·해제/실제 목격 경찰 변화/대응 확대와 골든 회귀 및 Windows 테스트를 우선순위로 조정.

**v0.3에서 정한 기본:** 기존 Social Damage($) 유지, Chaos Score 및 사장실 A/B 필수 제외. **검증 필요:** 회사 건물 핵심 구역 수, 사장 붙잡기 유지시간/쿨다운(12초/6초는 가설), 헬기 연출 수준, Steam 2/4인 실기, 캐릭터 시각 승인. 공식 기한이나 출시 범위를 사용자 동의 없이 변경하지 않는다.

**업데이트 규칙:** 이 문서는 외부 도구를 통한 실시간 대시보드가 아니며, 마지막 갱신 당시 사실과 과거 SHA를 표시한다. 완료 주장마다 PR/commit/Actions URL과 테스트 날짜·환경을 추가한다.
