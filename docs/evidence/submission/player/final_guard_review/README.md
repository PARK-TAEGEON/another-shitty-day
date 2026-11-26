# 플레이어 손목 최종 검증 · 2026-11-26

[본편 1280×720 원본](game_guard.png) · [가드 회전 전후](guard_comparison.jpg) · [머그 전환 전후 정지 화면](mug_comparison.jpg) · [머그 전후 1/3배속 영상](mug_comparison.mp4) · [전체 10초 영상](actions.mp4) · [엄지 측면·손바닥 3자세](grip_views.jpg)

## 확인된 문제와 수정

수정 전 `6e44282`의 본편과 기존 300프레임 재생을 깨끗한 체크아웃에서 새로 촬영했다. F209→210에서 오른손이 가드에서 손잡이로, F231→232에서 손잡이에서 가드로 한 프레임 만에 이동하고 회전했다. 두 번째 집기에서도 같은 현상이 보였다. 전후 영상은 두 실행의 F204–285를 같은 640×480 영역으로 잘라 나란히 배치했다. 화면 바깥의 제목·프레임 번호가 편집 자막이다.

리깅 팔로 머그를 잡거나 놓을 때 직전 렌더 자세에서 0.20초 동안 전환한다. 소켓 위치와 손목 회전에 같은 진행률을 쓰고 매 프레임 그 회전으로 손목 위치를 역산한다. 머그는 집기 입력에서 고정되고 손이 닿은 뒤 기존 충돌 검사와 운반 이동을 시작한다. 놓기와 던지기에서는 물리를 즉시 해제한다. 가까운 손잡이에 손을 올릴 때 소매 방향은 가드에서 손목까지의 실제 이동량을 따른다.

## 화면과 동작

| 30fps 원본 프레임 | 관찰·측정 |
|---|---|
| F1–26 · 가드 | 손과 소매가 좌우 하단에 있고 조준점은 비어 있다. 회전 직전 `19967ec`와 최종 화면은 같은 시드·시작 카메라·조명·해상도에서 재촬영했다. 양손·소매 면적은 31,787→22,759 px였다. RGB 한 채널이라도 손을 숨긴 컷과 8 초과 차이인 픽셀을 센 값이다. 이번 머그 수정 전후의 기본 주먹 원본은 바이트까지 일치했다. |
| F27–53 · 오른손 펀치 | 짧게 당기고 전진한 뒤 가드로 회수한다. 소매가 손목을 따라오고 접히거나 뒤집히는 프레임은 보이지 않았다. 동작 이벤트는 swing 1회였다. |
| F54–134 · 책상 B→A | 첫 B의 접촉은 F72(동작 11/30초), 반복 A는 F110(9/30초). 두 번 모두 양손 지점 x=±0.205 m, 피부 최저 y=1.062 m였다. 들기·양손 접촉·가드 복귀를 확인했다. |
| F135–201 · 펼치기→기본→단단한 주먹 | 기본 자세 강도 0.55를 재생해 F169에서 양손 검지 끝마디 본 좌표가 시작 가드와 일치했다. 고정된 두 검사 시점에서도 엄지와 손바닥의 연결이 유지된다. |
| F209–231 · 첫 집기와 놓기 | F210부터 접근해 F215에 손잡이에 닿았다. F232부터 손을 펴며 복귀해 F237에 가드 손목 위치에 도달했다. |
| F254–300 · 재집기와 던지기 | F260에 재접촉했다. F275의 던지기 입력 뒤 컵이 손을 떠나고 오른팔이 투척 동작을 마쳤다. 두 번의 접촉 이후 해제 전까지 모든 렌더 프레임에서 소켓–목표 오차가 0.001 mm 미만이었다. F208–283 최대 프레임 간 손목 회전은 13.02° 미만이었다. |

F230의 머그는 카메라 기준 (0.130, −0.140, −1.150) m였다. 손 피부 표본과 손잡이 표면의 최소 간격은 0.340 mm, 최대 표본 관통은 0 mm였다. 카메라는 수직 FOV 77°, near 0.045 m, 손목 투영은 (276, 704)·(1004, 704) px였다. 본편 대사창은 F80에 (150, 574) px로 표시됐다. 검증 장면은 입력을 재현하기 위해 두 번 모두 기존 머그를 조준선 위에 놓는다.

**남은 시각적 한계.** 기본 주먹을 확대하면 접힌 손가락 사이로 책상색이 조금 보이고, 기본 주먹과 단단한 주먹의 엄지 윤곽 차이는 작다. 본편 대사창이 떠 있는 동안 하단의 손 일부가 가려진다. 손 메시와 HUD는 이번에 수정하지 않았다.

## 실행 환경과 출처

Debian 13 x86-64, Godot 4.7.2.stable.official.ed1daf0bf, Jolt, GL Compatibility, Mesa 25.0.7 llvmpipe, Xvfb. 실제 시작 로그는 `ASD player arms loaded: rigged_v2`였다. 본편 비교에는 `--rig-slice`를 지정했고, 재생 장면은 기존 rig_slice 설정으로 같은 팔을 불렀다. 브랜치에서 옵션 없이 본편을 시작하면 legacy가 기본이다.

| 항목 | SHA |
|---|---|
| 수정 전 코드 커밋 | `6e442828d6c0e806d1fe4f4e91b3652cd66dbb0e` |
| 검증한 코드·에셋 커밋 (원격) | `c7db8724002fa64791bea48505a93f9c922716af` |
| 녹화 작업본 커밋 (원격과 전체 Git 트리 동일) | `48f11a9f4dd480562c62cbc26483e8013e888229` |
| 실제 재생·회귀에 사용한 game 트리 | `9456b7b2e96e759b051f83bf123d5fc940c088e2`  |
| 좌·우 GLB Git blob | `3a0f6ebd11e28d3bb00db3b84d01237037fb5079` · `bda319167281c823f7e2035715a5c0ddb668736f` |
| game/assets/fonts Git 트리 | `3ceefdd197e5f4d395c02cf96f313eacad1016ed` |
| 녹화한 Windows Desktop PCK의 SHA-256 | `55d4412a37f8dad17662a97d0d3e77ba1fcd97d8fc113dc52734ae42d3bd635f` |

Windows Desktop 프리셋의 리소스를 PCK로 내보낸 뒤 Linux Godot에서 이 팩으로 최종 300프레임을 녹화했다. 같은 Godot import와 저장소의 글꼴·GLB를 썼고, 작업본과 PCK에서 별도로 촬영한 가드·운반·검사 자세 등 PNG 11장이 바이트 단위로 같았다. 영상은 고정 30fps 재생 기록이다. Windows 실기와 하드웨어 GPU의 실시간 성능은 미검증이다.

[새 팔 회귀 원본](hand_motion_rigged_v2.txt) · [기존 팔 회귀 원본](hand_motion_legacy.txt) · [접촉 이벤트와 전환 프레임별 소켓 오차·손목 회전](events.json)

## 재현

저장소 루트에서 실행한다. 화면 캡처에는 디스플레이가 필요하다. 리눅스 가상 디스플레이 사용법은 상위 검증 README에 있다.

```sh
godot --headless --path game --import
godot --headless --path game --script "$PWD/tools/tests/hand_motion_regression.gd" -- --rig-slice
godot --headless --path game --script "$PWD/tools/tests/hand_motion_regression.gd"
godot --headless --path game --export-pack 'Windows Desktop' /tmp/player-review.pck
godot --main-pack /tmp/player-review.pck --audio-driver Dummy --fixed-fps 30 --script "$PWD/blender/submission/player/compare.gd" -- --rig-slice --out=/tmp/player-review-shots
godot --main-pack /tmp/player-review.pck --audio-driver Dummy --fixed-fps 30 res://rig_slice/verify.tscn -- --capture=/tmp/player-review-frames
```
