# 김 팀장 × Office Scenario v0.3 통합

2026-10-13 KST. **IMPLEMENTED / 아래 범위 VERIFIED / 인간의 최종 아트·재미 승인 전.**
통합 브랜치: `integration/kim-ragdoll-office-v03`. main 자동 병합 없음.

## 기준과 의존성

- AGENTS → PROJECT-STATUS → RELEASE-ROADMAP → START-HERE → 10/12·10/13 결정 → SCENARIO-V0.3-BASELINE → SCENARIO-FRAMEWORK → ROADMAP-AND-GATES 및 두 구현 보고서를 읽었다.
- PR #1 `fb76ac4ecf86c58375490a70c8c46e102173e372`: 에셋 연구, base=main.
- PR #2 `bca6968bd1f5b4fbd9427c67baa14664e0107255`: Blender/GLB·31본·5모션·15본 Jolt, base=PR #1 연구 브랜치. 독립 main PR이 아니다.
- PR #8 `1be084a10a97bcb877c07e58eef58946dfe7f87f`: 최신 Office Scenario v0.3, base=main. 이전 #7과 함께 병합하지 않는다.
- #8의 커밋된 상태를 별도 clone/통합 브랜치로 복제하고 #2를 로컬 merge했다. #1 이력도 함께 포함된다. 자동 충돌 없음. 다른 작업자의 checkout/index/미커밋 파일은 수정하지 않았다.
- 통합 PR은 #8 브랜치를 base로 제안한다. 최종 main 반영은 **#1 → #2, #8 → 통합 변경** 순서로 검토하며, #8 main 반영 뒤 이 PR의 base를 main으로 변경하고 diff/CI를 다시 확인한다. squash/rebase로 선행 SHA가 바뀌면 이번 merge를 그대로 중복 적용하지 말고 통합 증분을 재적용·재검증한다.

## 실제 변경

| 파일 | 변경 |
|---|---|
| `game/project.godot` | 김 팀장 리그와 강한 충격 넉다운을 기본 ON |
| `game/scripts/office_npc.gd` | 명시적 `--kim-legacy` 우선 복귀, 기존 receive_hit에서 어댑터의 넉다운 정책 호출 |
| `game/scripts/characters/kim_visual_adapter.gd` | `--kim-health-only` / `--kim-one-kick` 및 프로젝트 설정 비교. 살아남은 강한 충격은 기존 Medium 휘청임, 체력 0은 기존 래그돌 |
| `tools/tests/kim_demo_integration.gd` | 실제 main 씬의 모델 범위·모션 선택·주먹/발차기·Medium 회복·중복 회계 검사 |
| `tools/tests/kim_restart_regression.gd` | NPC 기대치 7→8: 기존 5+2와 #8의 사장, 실제 reload 5회 유지 |
| `tools/test-kim-integration.ps1` | 기본/체력 기준/기존 모델 3모드 회귀·증거·실패 종료 |
| `tools/demo-launchers/` | 비교 실행기 3종과 한국어 조작·검수 안내 |
| `.github/workflows/kim-slice.yml`, `office-scenario.yml` | Linux·Windows 통합 행렬 및 로그 artifact |

모델/모션/물리본은 PR #2의 실제 파일을 재사용했다. 새 캐릭터를 다시 제작하거나 다른 네 직원으로 확장하지 않았다. #8 기준 `main.gd`, `world.gd`, `player.gd`, `prop.gd`, 모든 `scripts/scenario/` 파일은 이번 통합에서 변경하지 않았다. 기존 NPC 이동/대사/피해액·경비·경찰·사장 E 잡기·해제 이벤트를 그대로 사용한다. 특별 퀘스트·추가 시나리오·점수 보상을 만들지 않았다.

Idle/Walk/Idle_Talking과 Light/Medium/Heavy는 PR #2 어댑터를 통한다. 승인된 빼꼼·접근·잔소리의 기존 계산 포즈를 골격에 전달하는 구조도 유지한다. 접근 보행은 원본 골든 동작과 동기화되며 별도 보행 AI를 추가하지 않는다.

## 실행과 밸런스 비교

Windows ZIP을 풀고 `AnotherShittyDay-KimDemo.exe`를 실행하면 새 김 팀장이 켜진다. 실행 중인 게임을 닫고 원하는 `.cmd`를 연다.

| 모드 | 실행 옵션 | 실제 체력 40에서 Q 발차기(피해28) |
|---|---|---|
| 기본 / 01 | `-- --kim-rig --kim-one-kick` | 1회 래그돌 |
| 체력 기준 / 02 | `-- --kim-rig --kim-health-only` | 1회 후 체력12·Medium, 2회 래그돌 |
| 기존 모델 / 03 | `-- --kim-legacy` | 1회 후 체력12, 2회 기존 넘어짐 |

기존 F 책상, 왼쪽 클릭 주먹, Q 발차기, E 소품/사장 잡기, R 재시작, Esc 설정을 유지한다. `asd/characters/kim_rig_enabled=false`로 소스 기본값을 되돌릴 수 있다. `asd/characters/kim_heavy_knockdown=false`는 체력 기준이다. CLI의 legacy는 리그 ON보다 우선, health-only는 one-kick보다 우선한다. 비교 설정은 사용자 설정 파일을 쓰지 않는다.

한 번에 쓰러지는 밸런스는 **비교 후보**이며 재미가 승인되었다는 뜻이 아니다. 건강한 김 팀장에게 첫 Q를 쓰는 조건으로 비교한다. 주먹을 먼저 맞히면 체력이 줄어 두 모드 모두 다음 Q에 쓰러질 수 있다. 어느 모드도 발차기 피해량·기존 달러 산식을 바꾸지 않는다.

## 검증

환경: Godot 4.7.2 stable / Jolt / Windows x64 / OpenGL 3.3 / GTX 1660 SUPER / NVIDIA 617.14.

- **47 검사 PASS:** 3모드 × (기존 회귀10 + v0.3 회귀4 + 새 통합1) + 물리1 + 재시작1. [전체 요약](../evidence/kim-integration-2026-10-13/summary.json).
- 골든 첫 B/반복 A, 박 대리·빼꼼·접근·세 잔소리, 소품/손/업무/배치/HUD/피해액, 사장 E·실제 충돌·경찰 개별 시야·Full/Short/Off·동일 공격 사건/장부 보존을 모든 모드에서 확인했다.
- 실제 main의 Q 판정: 기본 1회, 체력 기준/기존 2회. Kim 치료300000/복귀불가 업무200000 및 KNOCKDOWN 각 1회. 물리본 재타격3회에 중복 장부 없음. 살아있는 원본40HP에서 실제 주먹 Light와 생산 receive_hit의 Medium·회복 확인.
- 공격 비교 자동검사의 위치/AI 정지는 같은 광선 표적을 유지하는 fixture다. 실제 Player windup/raycast/receive_hit와 장부를 사용한다. Light는 실제 주먹, Medium은 임펄스(9,1,0)/피해18을 직접 전달한다. 인간 자유 플레이나 투척으로 Medium을 만들었다고 주장하지 않는다.
- 30회 전/측/후 실제 물리 낙하, 바닥·책상·의자 접촉/유한 변환/폭발 한계/중복 회계; active/deferred 래그돌 포함 실제 main reload5회 PASS.
- 최종 EXE 110824944 bytes, SHA256 `196BC5711DFB461BA0D8626550A1B0E90ECA71A79FED02B1010C641FA5EC5986`. 실제 Windows GPU에서 3모드 모두 native smoke PASS. [기본](../evidence/kim-integration-2026-10-13/native-default.txt), [체력 기준](../evidence/kim-integration-2026-10-13/native-health-only.txt), [기존](../evidence/kim-integration-2026-10-13/native-legacy.txt).
- [28초 실제 통합 인게임 영상](../evidence/kim-integration-2026-10-13/kim-office-integrated-28s.mp4): 첫 책상→빼꼼→접근→question/admonish/insist→실제 주먹·발차기→래그돌. Windows GPU, 1280×720/30fps, 자동 입력 재생과 촬영 카메라 추적. AI 생성 영상·프레임 보간 없음. 캡처 보고의 실제 impact2, 최종 down/ragdoll=true.
- 일부 기존 회귀 및 새 main 종료에서 ObjectDB 누수 경고가 남는다. PASS는 0 종료·성공 마커·SCRIPT ERROR/ERROR 없음이며 경고가 전혀 없다는 의미가 아니다. 최초 sandbox 임포트의 인증서/에디터 설정 접근 오류 뒤, 격리된 APPDATA의 정상 Windows 프로세스로 재검증했다.

재현: `tools/test-kim-integration.ps1 -GodotPath <4.7.2 console exe> -EvidencePath <로그 폴더>`. 빌드는 기존 `tools/build.ps1`. Blender/GLB 원본과 CC0 모션·접촉음의 권리 고지를 그대로 보존하고 Windows ZIP에도 동봉한다.

## 인간이 확인할 항목과 남은 한계

1. 얼굴·실루엣·가림막 빼꼼·가까운 접근·손짓의 스타일과 자연스러움.
2. 처음부터 Q 한 번에 넘어지는 모드와 체력 기준 중 코미디·타격감·플레이 지속에 더 맞는 것.
3. 가구 접촉·반복 타격의 시각적 관통·관절 뒤틀림·떨림 및 효과음 청감.
4. 10~15분 자유 플레이, 사장 잡기·경찰 대응·결과·R 재시작 체감.

PR #2의 최종 표면/관절 미술 마감·자동 일어나기는 여전히 미완료다. Movie Maker 수치는 실시간60fps 벤치마크가 아니며 장시간 성능/인간 재미 승인도 미검증이다. UI 자동화로 별도 시작/일시정지 검수를 추가하려 했으나 앱 실행 승인 요청이 timeout되어 그 추가 검수는 완료로 기록하지 않는다. EXE 3모드 GPU smoke와 실제 인게임 렌더는 별도로 완료했다.

2026-11-30 Release-P2 / 2027-06-30 정식1.0 목표는 유지한다. 이 통합은 한 명의 모델·애니메이션·래그돌 검수 빌드이며 건물 전체·층간 이동·최상층·신규 시나리오·멀티플레이 완료가 아니다.
