# 사무실 김부장 50본 모델

게임 안 대사창에는 이 인물이 **김 팀장**으로 표시된다. `task/submission-kim-1124`는 `art/kim-and-first-person-rig`의 `a449e6ab2467c65c704358de03e5a92b1e669d01`에서 분기했다.

[오프닝·주먹·발차기 영상](office-opening-and-hit.mp4) · [접근 장면](office-walk.jpg)

## 플레이

저장소 루트에서 다음과 같이 실행한다.

```bash
godot --headless --path game --import
godot --path game -- --kim-v2
```

| 선택 | 본편에서 보이는 김부장 |
|---|---|
| 인수 없이 실행 | 기준 브랜치의 31본 김부장 |
| `--kim-v2` 또는 `asd/characters/kim_visual_v2_enabled=true` | 새 50본 김부장. 1회 발차기·체력 기준은 기존 설정 적용 |
| `--kim-v2 --kim-health-only` | 새 외형으로 체력 기준 비교 |
| `--kim-legacy` | 기존 절차적 김부장. v2 플래그나 프로젝트 설정과 함께 주더라도 우선 적용 |

통합 담당자는 `asd/characters/kim_visual_v2_enabled`로 빌드 기본값을 선택할 수 있다. 키를 생략하면 `false`다. `KIM_VISUAL`은 인스턴스 경로, 골격·물리본 수와 클립 목록을 출력하고 `KIM_MOTION`은 클립 전환을 기록한다.

## 연결과 원본

- [편집용 Blender 원본](../../../../blender/rig_slice/boss_kim_game.blend), [Godot 본편용 GLB](../../../../game/assets/rig_slice/boss_kim_game.glb). 기존 모델과 같은 +Z 전방, Y 위쪽, 미터 단위다. 크기 보정은 메시와 골격 데이터에 함께 적용했다. 물리 시뮬레이터 위의 노드 배율은 1이다.
- [모션 제작 스크립트](../../../../blender/submission/kim/bake_office_motion.py)가 기존 본편 GLB의 `Idle`, `Walk`, `Idle_Talking`, `Hit_Head`, `Hit_Chest`를 표본화한다. 각 본이 원래 기준 자세에서 회전한 양을 구하고, 새 부모·쇄골을 따라 자식의 로컬 회전을 계산한다. 손가락 세 마디를 가진 새 손은 전용 굽힘을 쓰며, `Joint_review`는 계속 독립 재생할 수 있다.
- [NPC 선택부](../../../../game/scripts/office_npc.gd)에서 사무실의 우두머리 배역 한 명에게 어댑터를 연결한다. [시각 어댑터](../../../../game/scripts/characters/kim_visual_adapter.gd)는 기존 오프닝 제어 노드의 앉기·머리 돌리기·잔소리 손짓을 사용한다. 새 모델에 턱·눈썹 본이 없어 입·눈썹은 고정된다.
- 골반·가슴·머리와 양쪽의 상완·전완·손·허벅지·정강이·발을 이름으로 연결한다. 물리본 15개의 질량·조인트 한계·피해 인터페이스를 이어받고, 새 체형에 맞춰 충돌체 크기와 중심을 잡았다. [물리본](../../../../game/scripts/characters/kim_physical_bone.gd)은 발차기의 연출 구간에도 v2의 본별 방향을 시각 골격과 맞춘다.

## 검증 재현

```bash
godot --headless --path game --fixed-fps 60 --script res://rig_slice/kim_submission_verify.gd -- --kim-v2
godot --headless --path game --fixed-fps 60 --script ../tools/tests/kim_demo_integration.gd -- --kim-v2
blender -b -t 2 --factory-startup --python-exit-code 1 --python blender/submission/kim/check_deformation.py
```

원본과 GLB를 다시 내보낼 때는 `blender -b --python-exit-code 1 --python blender/submission/kim/bake_office_motion.py`를 쓴다. 김부장 한 명의 파일만 내보낸다.

## 본편에서 확인한 결과

[회귀·본편 측정값](verification.json)과 [GLB 클립 변형 측정값](deformation.json)은 실행에 사용한 파일의 SHA-256을 포함한다. GLB는 `ece7fe126680aa258f4ae4df353b16413da53c05bc17de668c7e8f4abb2bb91a`다. 1개 메시, 63,495개 삼각형, 4개 재질, 50본이며 정점당 최대 4본의 영향을 받는다. 납품용 Blender 원본에서 GLB를 다시 생성해 바이트가 일치하는 것을 확인했다.

| 검사 | 확인한 결과 |
|---|---|
| 실제 사무실 오프닝 | 박 대리 “왜 그래?” → 김 팀장 “뭐야 무슨 소리야?” → “이게 무슨 짓이지?” → 잔소리 3줄. 가림막에 앉아 있을 때 머리 꼭대기 1.52m, 빼꼼할 때 2.20m. 기존 경로로 2.95m 접근 |
| 대기·걷기·잔소리 | 원래 스폰 위치에서 시작한 측정 구간에 Idle 367틱, Walk 164틱, Idle_Talking 531틱. 걷는 동안 왼쪽 허벅지가 약 54°, 잔소리 중 왼쪽 전완이 약 47°, 머리가 약 7° 움직임 |
| 피격·물리 인계 | 실제 플레이어 주먹에 체력 40→20, 발차기 후 down. 물리 시뮬레이션 316프레임 동안 표시 골격과 15개 물리본 중심 사이 최대 오차 0.002mm 미만. 같은 김부장을 때렸을 때의 점수·피해액 중복 청구 검사 통과 |
| 가구·재시작 | 실제 재시작 뒤 기존 의자는 그대로 두고 두 인물만 정렬한 비교 실행에서 골반·가슴·왼발의 접촉 ID 확인. 의자 약 6cm 이동. 별도의 기존 재시작 5회 회귀 통과 |
| 선택·회귀 | 플래그와 설정 8가지 조합 통과. 기존 테스트를 관련 모드에서 67회 실행해 66회 통과. `kim_rig_regression.gd -- --kim-v2`는 31본과 옛 QA 자세 4개를 찾으므로 실패. 동일 원본 테스트는 기본 31본에서 통과. v2에서도 30회 낙하 측정은 끝났으며 별도 50본 본편 검사는 통과 |
| 편집 클립과 본편 변형 | Blender에서는 6개 클립 291자세에서 1mm보다 긴 95,925개 모서리를 검사. 두 배 초과로 늘면서 10mm 넘게 길어진 모서리 0개. 실제 사무실의 개별 표본에서는 이 조건을 넘는 삼각형 변이 착석 12건·걷기 2건이며 빼꼼·잔소리·주먹·해당 정지 자세는 0건. Godot 수치는 인접 삼각형이 공유하는 변을 중복 집계 |
| 내보낸 게임 리소스 | Windows Desktop 프리셋으로 만든 PCK를 Linux Godot에서 열었고, 별도 소스 프로젝트 없이 본편이 v2·물리본 15개·Idle을 로드함 |

검증 환경은 Linux x86-64, Blender 4.3.2, Godot 4.7.2 `ed1daf0bf`, Jolt Physics다. 영상은 GL Compatibility와 Mesa 25.0.7 llvmpipe에서 녹화했다. 화면의 한국어 제목 글꼴 두 개는 같은 Noto Serif KR 계열의 로컬 파일을 사용했다. 실제 Windows PC 성능은 측정하지 않았다. 일부 기존 테스트 종료 시 ObjectDB 잔여 인스턴스 경고가 발생했다. 해당 테스트는 회귀 결과 파일에 기록했다.


## 영상 구간과 착지 한계

영상은 실제 사무실에서 플레이어의 입력과 시선만 재생한 26.10초짜리 연속 녹화다. 1280×720, 30fps, 783프레임이며 게임의 스테레오 오디오가 들어 있다. 2.73초에 빼꼼, 5.20초에 접근, 8.93초에 첫 잔소리 손짓, 18.67초에 주먹 입력, 19.97초에 발차기 입력이 나온다. 화면 하단 대사는 실제 본편에서 재생됐다. 마지막에는 플레이어가 쓰러진 김부장에게 걸어가 옆에서 6초 관찰 구간의 끝을 보여준다.

```bash
godot --path game --fixed-fps 30 --write-movie /tmp/kim-office.avi --script res://rig_slice/kim_submission_capture.gd -- --kim-v2
ffmpeg -i /tmp/kim-office.avi -c:v libx264 -crf 20 -pix_fmt yuv420p -c:a aac -movflags +faststart office-opening-and-hit.mp4
```

[동일한 녹화 스크립트를 별도의 30fps headless 실행에서 측정한 380개 자세](office-skin.json)에서 걷는 동안 신발은 물리 바닥 위에 있었다. 발차기 착지 순간 한 프레임에서 오른쪽 밑창이 바닥에 최대 12.7cm 들어갔다. 같은 순간 발 충돌체도 들어갔으며 스킨과 물리본의 위치는 일치했다. 마지막 자세에서 밑창 0.8cm와 왼손 엄지 4.7cm가 바닥에 남았다. 이 경로의 쓰러짐 구간에서 몸과 외벽의 최소 간격은 48cm였다. 별도 60fps 본편 검사에서 얻은 정지 자세의 최저점은 물리 바닥보다 0.65mm 낮았다. 착지 방향과 접촉 순서에 따라 결과가 달라진다.

## 변경 파일

| 용도 | 저장소 경로 |
|---|---|
| 편집 원본·런타임 모델 | `blender/rig_slice/boss_kim_game.blend`, `game/assets/rig_slice/boss_kim_game.glb` |
| 모델 재생성·변형 검사 | `blender/submission/kim/bake_office_motion.py`, `blender/submission/kim/check_deformation.py` |
| NPC 선택·본편 연결 | `game/scripts/office_npc.gd`, `game/scripts/characters/kim_visual_adapter.gd`, `game/scripts/characters/kim_physical_bone.gd` |
| 본편 검증·녹화 | `game/rig_slice/kim_submission_verify.gd`, `game/rig_slice/kim_submission_capture.gd`와 각 Godot `.uid` |
| 결과 | 이 폴더의 `README.md`, `verification.json`, `deformation.json`, `office-skin.json`, `office-walk.jpg`, `office-opening-and-hit.mp4` |
