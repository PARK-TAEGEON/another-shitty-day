# Another Shitty Day · 11월 26일 제출 통합

실행 대상은 [`e5d34d88e38a2278501acd87017eb3d3dc3c2b7f`](https://github.com/PARK-TAEGEON/another-shitty-day/commit/e5d34d88e38a2278501acd87017eb3d3dc3c2b7f)이다. 아래 사진·영상·검사 기록은 후속 증거 커밋에 있다. 최종 `game/` 트리는 `7c895537a9bf9e7f1db9d297c60ab4c800e4ea8a`, 그 안의 글꼴 트리는 `3ceefdd197e5f4d395c02cf96f313eacad1016ed`다. 촬영과 패키지에 저장소의 글꼴을 그대로 사용했다.

## 통합 기준

| 역할 | 입력 커밋 |
| --- | --- |
| 공통 기준 | `a449e6ab2467c65c704358de03e5a92b1e669d01` |
| main | `c6daaefd9c98a7b2a2f6eda6b38c3e511bec79f8` · 공통 기준의 조상 |
| A · 플레이어 | `4eeaf7cbbf2812e72dcfc382cdd3bc50ac4dc783` |
| B · 인물 | `b720b2b318e4f323432caac4c70f5c2808872b73` |
| C · 소품 | `af12642111985967fcbcef5dc276760b0db9a16e` |

| ProjectSettings | 기본값 | 시작 로그에서 확인한 에셋 |
| --- | --- | --- |
| `asd/assets/player_arms_v2_enabled` | `true` | `rigged_v2` 좌·우 손 GLB |
| `asd/characters/kim_visual_v2_enabled` | `true` | `boss_kim_game.glb` · 골격 50본, 물리본 15개 |
| `asd/characters/park_visual_v2_enabled` | `true` | `park_office.glb` · 기존 NPC 동작 제어 12개 |
| `asd/assets/office_props_v2_enabled` | `true` | 책상, 파티션, 모니터, 머그, 키보드, 서류, 바인더 v2 |

김부장 비교에서 `--kim-legacy`는 절차 모델을 선택한다. 그 인수가 없으면 명시적 `--kim-v2`, 명시적 `--kim-rig`(31본), 프로젝트 기본값 순으로 선택한다. `--kim-health-only`는 체력 기준 비교용으로 외형은 기본값을 따른다. `--park-legacy`는 박 대리의 절차 모델을 선택한다. `--rig-slice`와 `--office-props-v2`는 활성화 인수다. 물리 OFF/ON 검사는 소품 인수 없이 실행해 검사 내부에서 두 설정을 모두 적용했다.

## 본편 화면 및 실행

[기본 사무실](default-run.jpg) · [대사·HUD·일시정지·신문 결과](ui.jpg) · [김부장 빼꼼·접근·착지·정지](kim-playback.jpg)

| 최종 PCK에서 촬영한 영상 | 실행 결과 |
| --- | --- |
| [책상 첫 B와 반복 A · 2.97초](desk-b-a.mp4) | 기존 입력으로 첫 B 11/30초, 반복 A 9/30초에 접촉했다. 두 번 모두 양손 피부 최저점은 1.062m였고 가드로 돌아왔다. |
| [새 머그와 소품 · 6.27초](mug-and-props.mp4) | 원래 책상 위의 머그를 레이로 집고, 놓고, 다시 집어 던졌다. 머그는 파손 뒤 $10,000을 기록했다. 모니터에 정해진 세기의 피격 입력을 주어 $100,000 → $300,000의 두 단계를 확인했다. 재시작 뒤 머그·모니터 상태와 피해액이 초기화됐다. |
| [오프닝과 김부장 피격 · 26.10초](kim-opening-and-kick.mp4) | 앉은 김부장은 파티션에 가려지고 상체를 들어 빼꼼한다. 박 대리 놀람 → 김부장 빼꼼 → 접근 → 잔소리 세 줄 순서가 이어졌다. 18.67초 주먹, 19.97초 발차기 입력 뒤 실제 래그돌과 6초 관찰이 이어진다. |

영상은 최종 팩의 실제 본편과 자동 입력이다. 소품 영상 후반은 모니터 손상 단계를 보여 주는 시점 전환을 포함한다. UI 비교 사진의 점수·피해액과 대사는 기존 UI 캡처 장면에 입력한 값이다. 오프닝 영상의 대사와 피해액은 실제 플레이 흐름에서 발생했다. Godot 4.7.2 `ed1daf0bf`, Debian 13 x86-64, Jolt, GL Compatibility, Mesa 25.0.7 llvmpipe/Xvfb에서 고정 30fps로 촬영했다. Windows 하드웨어 성능은 측정하지 않았다.

### 통합 과정에서 수정한 문제

- 기본 시점 밖에서 머그를 집으면 손이 손잡이 안쪽으로 약 1.06cm 겹쳤다. 머그 쪽 기준으로 손목 회전을 계산해 컵을 향해 시점을 내리거나 좌우로 돌릴 때도 손이 실제 손잡이 방향을 따른다. 최종 촬영에서 안정 운반 34프레임의 소켓 최대 오차는 0.001mm 미만이었다. 정지 운반의 피부 정점 11,266개와 런타임 GLB를 비교해 최근접 간격 약 0.34mm, 표본 관통 0mm를 확인했다. 재생 중 머그 전환의 최대 손목 회전은 프레임당 18.16°였다.
- 사무실 초기화 때 새 책상 충돌체가 먼저 원점에 생성되면서 첫 물리 프레임에 플레이어를 약 14cm 밀어냈다. 충돌체를 최종 위치에 놓은 뒤 씬에 붙여 제자리에서 초기화한다. 정적 충돌 상자 74개, 소품 40개, 층별 내비게이션 목록은 소품 OFF/ON에서 일치했다.
- 층간 경찰 회귀는 부동소수점 반올림으로 출동 시각 경계 바로 아래에 머무를 수 있어 테스트의 경과 시간을 한 틱 넘겼다. 두 경찰의 실제 층, 출동 순서와 피해액 기대값은 유지했다.

## 검사 및 남은 한계

| 확인 범위 | 결과 |
| --- | --- |
| 김부장 50본 | 착석 시 머리 꼭대기 1.52m, 빼꼼 2.20m, 접근 2.95m. 주먹에 체력 40→20, 발차기에 쓰러짐. 별도 본편 회귀에서 물리본 재타격 3회에 추가 피해액 0, 치료 $300,000·업무 $200,000 한 번씩 기록. |
| 박 대리 | 근무·놀람 표정·고개 돌림, 실제 플레이어 발차기 피격과 피해액, 씬 재시작으로 새 GLB 재로딩 확인. 모델 선택 검사에서 표시 중인 새 메시 18개, 절차 메시 0개였다. |
| 소품 | 실제 투척·파손·피해액·재시작, 키보드·서류·바인더 6개 단계 검사 통과. |
| 기존 본편 | 1F↔2F, 사장 E 붙잡기·이동·해제, 경비 추적 및 밀침, 경찰 출동·목격과 제압, 일시정지·재개·재시작 회귀 통과. |
| 저장소 회귀 | 통합 설정 커밋 `cf30808e14d69dd84aef0693d52d514b086440d3`에서 기존 3모드 57회 및 31본·재시작·비행 3회 통과. 머그 손목 수정 후 최종 커밋에서 영향 범위 3모드 24회, 머그·책상 리플레이 및 내보낸 PCK 스모크를 다시 통과했다. 31본 검사의 본 수와 QA 자세 기대값은 유지했다. |

김부장 신발은 본편 영상의 낙하 구간 179개 자세에서 물리 바닥보다 순간 최대 8.52cm, 마지막 자세에서 0.61cm 낮았다. 같은 사무실 통로에 배우를 고정 배치한 별도 30fps 비교에서는 팔·박 대리·소품 설정 ON과 OFF가 모두 최대 8.11cm, 마지막 0.72cm로 일치했다. 본편에서는 기존 착지 한계가 남았고, 조작이나 진행을 막는 현상은 관찰되지 않았다. 쇼트마다 착지 자세가 달라질 수 있다.

대사창이 하단 손 일부를 덮는 구간과 기본 주먹의 엄지 윤곽은 영상과 Windows 실기에서 사용자 확인이 필요하다. 실제 Windows 실행, 목표 PC 성능과 사용자 조작감은 미검증이다.

## Windows 패키지

[Another-Shitty-Day-Windows-x64-1126.zip 다운로드](https://chatgpt.com/library?file_id=libfile_fc74a86961f081918d46470e82d441c5&account_id=personal)

1. ZIP 전체를 한 폴더에 푼다.
2. `DeskBreaker.exe`를 실행하고 **출근하기**를 누른다.
3. WASD와 마우스로 이동·시점 조작을 한다. 왼쪽 클릭은 주먹·던지기, F는 책상, Q는 발차기, E는 상호작용, Esc는 일시정지, R은 재시작이다.

| 단계 | 결과 |
| --- | --- |
| Windows Desktop EXE·PCK 내보내기 | **생성** · Windows x64 PE. EXE 내장 PCK와 별도 PCK의 바이트 일치. ZIP 풀기 검사 통과. |
| 다른 OS에서 PCK 실행 | **Linux 성공** · Godot 4.7.2 Linux release에서 동일한 PCK를 기본 리소스로 기동하고 본편 smoke 통과. 그래픽 재생은 Linux 공식 Godot 실행기로 촬영했다. |
| 실제 Windows에서 EXE 실행 | **미검증** |

```text
Windows ZIP SHA-256  95c093c8b4ec060c93fe8b74a2b45c1db0eb09e1100e57a8a811a59833031704
DeskBreaker.exe      0662f5270f99271fa8d290c980f1160b9c63ce8d1c8251e13d9e075fdc54533a
독립·내장 PCK         4d89610e8e8b77abb23daf8e536bbafb5d33c95f92909957cceb56448a33cdcd
```

## 재현 및 원본 측정

[실제 로딩 및 검사 기록](checks.txt) · [정량 측정](measurements.json)

저장소 루트에서 실행한다. 촬영에는 그래픽 디스플레이가 필요하다. Windows Desktop 프리셋의 실행 파일을 내보내려면 Godot 4.7.2의 동일 버전 export template이 필요하다.

```sh
godot --headless --path game --import
godot --headless --path game --export-release 'Windows Desktop' /tmp/DeskBreaker.exe
godot --headless --path game --export-pack 'Windows Desktop' /tmp/DeskBreaker.pck
D="$PWD/docs/evidence/submission/integration"
godot --main-pack /tmp/DeskBreaker.pck --fixed-fps 30 --write-movie /tmp/desk.avi --script "$D/desk-contact.gd"
godot --main-pack /tmp/DeskBreaker.pck --fixed-fps 30 --write-movie /tmp/mug.avi --script "$D/office-grip.gd"
godot --main-pack /tmp/DeskBreaker.pck --fixed-fps 30 --write-movie /tmp/kim.avi --script "$D/kim-landing.gd"
blender -b --python-exit-code 1 -P "$D/measure-mug.py"
godot --headless --main-pack /tmp/DeskBreaker.pck --fixed-fps 30 --script "$D/kim-landing-fixture.gd"
godot --headless --main-pack /tmp/DeskBreaker.pck --fixed-fps 30 --script "$D/kim-landing-fixture.gd" -- --legacy-ensemble
godot --headless --path game --script "$PWD/docs/evidence/submission/office/physics_check.gd"
```
