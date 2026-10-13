# Office Scenario v0.2 구현 결과

2026-10-13 KST. 기존 사무실 옆 임시 사장실에서 플레이어가 A/B 특별 결과를 만드는 최소 구현이다. 전체 회사 건물이나 Release-P2 완료를 뜻하지 않는다. 기준 main은 `1244b54d56c774c78160d044f667872cbb1b66d4`, 구현 브랜치는 `implementation/office-scenario-v02`다.

설계 기준 ZIP: `Another-Shitty-Day-Scenario-Design-v0.2.zip`, SHA256 `4270DDF730B1E39155585DEA7E41DBFD9607F682328984501B3FDBB145BA6053`. AGENTS, 최신 상태/출시 로드맵/결정/공통 규격, ZIP 전체와 열린 PR #1/#2를 확인했다.

## 플레이 방법

기존 출근 메뉴와 조작을 그대로 사용한다. 동쪽 책장 옆 밝은 바닥 통로로 임시 사장실에 들어갈 수 있다. 기존 책장은 유지하며 그 옆의 실제 통로를 이동 입력으로 검증했다. 구경만 하면 사건과 특별 점수는 발생하지 않는다.

- **A 대표자 현장 배치:** 사장실 책상을 F로 치거나 근처에서 유효 충격을 낸다. 대표 기념패/결재함 등 권위 소품을 E로 들어 공용 서류 앞쪽으로 옮기고 놓는다. 이를 본 사장이 공용 자리까지 실제 이동해 명령을 멈추고 서류를 바라보면 확정한다. 공용 자리 가까이에서 사장에게 직접 가한 유효 타격도 대체 경로다.
- **B 사장실 영업 종료:** 대표 의자를 Q로 실제 사용 불능으로 만들거나, E로 들어 지휘 자리에서 충분히 옮긴다. 사장이 방문객 자리까지 실제 후퇴하고 명령을 멈추면 확정한다. 이미 망가진 가구를 다시 치는 것은 B 원인이 아니다.
- 이탈은 `suspended`이며 돌아오면 새 행동으로 재개한다. 사장 행동 불능은 특별 루트만 실패시킨다. A/B 뒤에도 경비/경찰, 난동, 제압, 결과, R 재시작이 이어진다.

사장은 기존 절차적 성인 NPC를 상속한 임시 모델이다. 최종 외형 승인이나 김 팀장 신규 래그돌의 사장 적용을 주장하지 않는다.

## 기존 시스템과 설계 연결

| v0.2 요구 | 재사용 및 최소 확장 |
|---|---|
| 행동 사건/원인 | 기존 유효 타격·집기·놓기·투척 접촉에 world 소유 round/event/root 어댑터 연결. 허공 입력으로 완료하지 않음 |
| 반응/인터럽트 | 기존 NPC concern/flee/spectate, 표정·피격·단일 평면 AStar 재사용. 김 팀장/박 대리 원본 골든은 기존 채널과 시각을 보존 |
| 신규 대사 | 현재 자막+예약1개, 유한 once, 우선도/3초 TTL. 대응 경고90, 골든70, 루트60~65, 발견20. 배우 무력화/부재/이탈 시 취소 |
| 특별 상태 | O-30~38 available/active/suspended/resolved/failed/interrupted 및 허세/회유/지원/체면 붕괴. 경비가 실제 대응 자리 도달해 관측됐을 때만 지원 태도 |
| 결과 원인 | 새 행동+실제 CEO 도달/역할 변경. 후보 최대4초, 2초 진전 없음/새 피격/목적지 교체/이탈/무력화 취소. 자동 도주/시간/경찰 출동 완료0 |
| 물리 원인 | 기존 소품 손상/충격 활성 시간은 보존. 신규 사건 근거 전달은 별도2초/3전달 제한. held 소품 충돌 OFF를 보호 |
| 대응/달러 | heat8/18/32, 유한 경비/경찰, 기존 property/care/work/response 증가분 장부를 그대로 사용. 루트 완료의 허구 달러 없음 |

Chaos는 결과 전용이다. 일반400+특별600=최대1000, A/B 종결 각각400. 같은 원인의 개입100→종결400은 차액300이며, 고유 행동/배우/전환/결과 중복 보상을 막는다. 균형 수치는 `game/data/scenario/chaos_score_v1.json`에 분리했다. 새 최고 기록과 A/B 달성 키는 `office_scenario_v0_2_chaos_v1`이며 기존 `social_damage_usd_v1` 최고액 키를 덮어쓰지 않는다.

최초 경찰 도착은 기존 실제 경찰 생성 신호에 연결된다. 1.85초 입구 카메라, `POLICE ARRIVED!`, Space 스킵, 원래 카메라/입력 복귀를 구현했다. 메뉴/제압/재시작은 연출을 취소한다. 기존 수락 공격을 지우지 않는다. 미래 온라인 peer는 비차단 자막 경계로 분기한다. 차량/하차 애니메이션과 세계 전체 시간 정지는 구현하지 않았다. 현재 연출 중에도 세계 물리와 대응은 진행한다.

## 검증과 증거

**자동 검증 VERIFIED:** Godot 4.7.2 stable Windows, 본편 import/smoke 및 기존 회귀10개, 신규 Chaos/사장실/경찰3개. `tools/test.ps1`과 `tools/test-scenario.ps1`로 재현한다. 사장실 독립 검사는 실제 slam/raycast 집기/충돌 검사 운반/놓기/발차기와 CEO 이동을 사용한다. 시작 위치·일부 소품 배치·막힌 경로·경과시간은 명시된 검사 fixture다.

확인 항목: 90 게임초 구경0/자율 이동 완료0, A/B 실제 도달, 운반 및 발차기 B, 이탈9초/재개/새 행동, 4초 만료/2초 막힘/목적지 변경, 비치명 새 피격/무력화/배우 부재, 사전 파괴 재보상0, 실제 사실10회 재전송, 최고 기록/분기 기록/달러 키 보존, 실제 씬 reload 재시작과 이전 round 사건 거부, 결과 freeze, 최초 경찰1회/메뉴/제압/비차단/기존 수락 공격 보존.

**화면/Windows VERIFIED:** 실제 GTX 1660 SUPER, OpenGL 3.3, NVIDIA617.14에서 본편 1280×720 렌더, 1250프레임/30fps/약42초 시연과 7개 캡처를 확인했다. 별도 Windows export 실행에서도 본편 smoke 성공. 영상은 자동 입력 재생이고 시작 위치와 경찰 출동은 검사용 설정이다. 타격/물리/운반/결말/제압/결과는 게임 코드 판정이며 A/B 상태·금액·NPC 포즈를 직접 주입하지 않는다. 경찰 자연 heat 상승 전체를 영상에서 증명하지 않으며 그 연결은 회귀 검사로 확인했다. 영화 기록의 렌더 시간은 장시간 성능 벤치마크가 아니다.

- [42초 실제 렌더 시연](../evidence/office-scenario-2026-10-13/office-scenario-v02-42s.mp4)
- [A 캡처](../evidence/office-scenario-2026-10-13/03-route-A.png), [B 캡처](../evidence/office-scenario-2026-10-13/04-route-B.png), [결과 화면](../evidence/office-scenario-2026-10-13/07-result.png)
- [기존 회귀 로그](../evidence/office-scenario-2026-10-13/baseline-final.txt), [신규 회귀 로그](../evidence/office-scenario-2026-10-13/scenario-final.txt), [재생 판정](../evidence/office-scenario-2026-10-13/replay-report.json)

**PR #2 로컬 결합 VERIFIED:** PR #2 HEAD `bca6968bd1f5b4fbd9427c67baa14664e0107255`에 임시 복사 프로젝트로 적용, 코드 충돌 없음. PR #2 `office_npc.gd`/`project.godot` 그대로 유지. 기존10+신규3 OFF/ON, 김 팀장 30회 방향/단계 물리 검사, native `--smoke-test --kim-rig` 통과. PR #2 원본 kim_restart는 고정 NPC7 기대치로 실패했으며 **기대치만8로 조정한 별도 검사본**에서 실제 reload5회/장부/활성 물리 전환 통과했다. 원본 실패와 조정본을 둘 다 보존했다. PR #1/#2나 main을 병합/수정하지 않았다. 이후 통합자는 해당 인원수 검사를 갱신해야 한다.

## 변경 파일

- `game/scripts/world.gd`: 사건 연결, 동쪽 출입구/임시 방, 기존 대응 신호 연결, 제한된 신규 대사 예약.
- `game/scripts/player.gd`, `prop.gd`: 기존 판정을 유지한 접촉/조작 사실 훅.
- `game/scripts/main.gd`: 결과 Chaos/분기/기록, 연출 연결/취소. 실시간 달러 HUD 보존.
- `game/scripts/scenario/{event_stream,ceo_npc,office_route,chaos_score,police_arrival}.gd` 및 UID: 신규 최소 모듈.
- `game/data/scenario/chaos_score_v1.json`, `game/export_presets.cfg`: 점수 데이터, export JSON 포함.
- `tools/tests/{chaos_score,office_scenario,police_arrival}_regression.gd`, `tools/test-scenario.ps1`: 신규 자동 검증.
- `tools/tests/{wall_throw,office_layout}_regression.gd`: 열린 출입구 대신 실제 남은 벽 검사, 보호 직원5+2와 신규 사장1 검증.
- `tools/capture_office_scenario.gd`, `.github/workflows/office-scenario.yml`: 재현 시연, Windows CI.
- 이 기록, `PROJECT-STATUS.md`, 증거 파일. 기존 김 팀장/래그돌 파일은 수정하지 않음.

## 출시 영향과 다음 스프린트

**Release-P1/P2의 사건 연결·사장실 A/B·Chaos·최초 경찰 연출 최소 구현을 앞당긴 상태**다. 2026-11-30 Release-P2 목표는 그대로이며 완료로 표시하지 않는다.

남은 작업: 실제 사람의 A/B 자유 플레이와 인과관계/재플레이 의향 검수, 10~15분 자발적 플레이/지속 성능, 핵심 공간2~3종과 층 연결, 정식 목격/신고/수색/대응 역할, 더 다양한 직원 태도, 차량/상위 대응 연출, 점수 밸런스 및 소품/사장 가독성, PR #2 외형/타격감 승인과 순차 통합. 시장/공무원, 전용 인질·협상 AI, 멀티 구현은 이번 범위에 포함하지 않았다. Windows 실행 파일은 로컬 검수 산출물이며 Git에는 넣지 않는다.
