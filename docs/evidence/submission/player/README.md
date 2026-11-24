# 플레이어 팔 제출 검증 · 2026-11-24

## 기본 주먹 재조형 · 기준 `0a53fb3`

[본편·엄지 측면·손바닥 전후 비교](guard_revision/guard_comparison.jpg) · [펼치기·머그·펀치·책상 접촉](guard_revision/actions.jpg) · [Godot 동작 결과](guard_revision/events.json) · [메시 변형 검사](guard_revision/geometry.json)

비교판의 왼쪽은 기준 커밋, 오른쪽은 새 양손 GLB다. 같은 Windows PC와 Godot 4.7.2에서 1280×720으로 촬영했다. 각 행은 같은 카메라, 조명, 배율을 썼다. 측면에서 검지 안쪽으로 비치던 배경이 가려지고, 손바닥 방향에서 엄지 밑동과 평평한 끝마디가 구분된다. 확대하면 검지 안쪽의 접힌 윤곽은 여전히 보인다. Blender의 `fist_*.png` 역시 기본 주먹 자세를 보여준다.

같은 장면에서 양손·소매 점유율은 전후 각각 3.435%였다. 손을 숨긴 배경·HUD와 머그 단독 프레임은 각각 동일했다. 머그 운반 위치는 카메라 기준 (0.13, −0.14, −1.15) m, 대사창 좌상단은 (150, 574) px였다. 300프레임 실기 재생에서 양손 펼치기, 머그 집기·놓기·재집기·던지기, 오른손 펀치, 책상 첫 B와 반복 A 접촉을 확인했다. 리깅 팔의 손 동작 회귀 8항목을 통과했다.

## 이전 제출 기록 · `0a53fb3`

기준은 `art/kim-and-first-person-rig`의 `a449e6ab2467c65c704358de03e5a92b1e669d01`이다. 제출 브랜치는 `task/submission-player-1124`이다. 본편 시작 위치와 시선에서 팔의 기본 위치, 머그 운반 거리, 엄지의 형태와 굽힘을 조정했다.

[본편 전후 비교](framing.jpg) · [실제 양주먹 확대](guard_close.jpg) · [엄지 측면 전후](thumb_comparison.jpg) · [본편 대사창](native_dialogue.jpg) · [10초 Godot 영상](actions.mp4)

## 화면

| 1280×720에서 측정 | 본편 기존 팔 | 기준 커밋의 리깅 팔 | 제출용 팔 |
|---|---:|---:|---:|
| 양손과 소매 점유율 | 1.566% | 14.828% | 3.447% |
| 머그만의 점유율 | 0.960% | 4.100% | 0.960% |
| 머그 화면 경계 (좌상단 → 우하단, px) | (653,367) → (761,468) | (690,366) → (914,587) | (653,367) → (761,468) |
| 기존 팔과 배경·HUD 차이 (px) | 0 | 0 | 0 |

실제 본편 씬의 동일한 틱·시드·카메라에서 손을 숨긴 프레임과 보인 프레임을 각각 저장했다. RGB 한 채널이라도 차이가 8을 넘는 픽셀을 해당 물체로 집계했다. 배경·HUD 동일성은 허용 오차 없이 RGB를 비교했다. 머그 비교 컷은 본편 운반 계산을 같은 초기 조건에서 안정시킨 뒤 촬영했다. 영상에서는 실제 집기, 놓기, 재집기, 던지기를 실행했다.

새 팔의 기본 손목 위치는 카메라 로컬 좌표 (±0.37, −0.35, −0.46) m이다. 77° 수직 FOV와 near 0.045 m에서 양 손목은 (276,704)와 (1004,704) px에 투영된다. 운반 위치는 (0.13, −0.14, −1.15) m이다. 머그 로컬의 오른손 잡기 목표는 (0.15305, 0.01334, −0.01783) m이다. 손잡이까지의 최소 표본 거리는 0.28 mm이고 검사한 손 정점의 최대 관통량은 0 mm였다. 사물 쪽 계약 변경은 필요하지 않다.

검증 장면은 본편 대사창의 좌표를 읽어 기록한다. 영상 80번째 프레임에 게임 대사가 (150,574) px에 나타난다. 상단의 `QA /` 문구는 검증용 오버레이다. 원래 하단 대사창이 떠 있는 동안 주먹 일부가 가려지며, 대사창이 닫히면 양주먹이 온전히 읽힌다.

## 엄지와 변형

엄지 밑동과 손바닥 사이의 연결 면을 손바닥 쪽으로 옮기고, 엄지 길이와 끝쪽 두께를 줄였다. 엄지가 검지 바깥을 따라 접히도록 세 마디의 굽힘과 맞섬 회전을 조정하고 중간 회전 키를 넣었다. 팔 하나당 25,000 tris, 스킨 본 18개, 재질 5개, Grip 클립 1개다.

| 검사 | 기준 커밋 | 제출용 |
|---|---:|---:|
| 기본 주먹의 엄지 끝–검지·중지 최소 간격 | 5.566 mm | 1.969 mm |
| 단단한 주먹의 같은 간격 | 3.779 mm | 0.310 mm |
| 양손 각각 117개 자세 중 피부 자기 관통이 검출된 자세 | 0 | 0 |
| 엄지 본의 최대 1프레임 회전 | 3.33° | 8.52° |

간격은 Blender 메시의 로컬 단위이며, 본편의 균일 배율을 적용하기 전 값이다. 1~30프레임을 0.25프레임마다 평가하고 정점을 공유하지 않는 피부 삼각형끼리 검사했다. 최대 회전은 30fps의 정수 프레임 사이에서 측정했다. 극단적인 측면 확대에서는 접힌 네 손가락 안쪽에 작은 빈 공간이 보인다. 손등·손바닥·엄지 쪽 Blender 렌더와 별도의 Godot 검사 카메라 컷을 함께 제공한다.

## 동작과 실행 환경

| 영상 구간 | 확인한 동작 |
|---|---|
| 0.0~1.7초 | 양주먹 기본 자세, 오른손 펀치 준비·전진·회수 |
| 1.8~4.4초 | 책상 첫 B, 성공 후 반복 A. 양쪽 모두 새끼손가락 쪽이 먼저 닿음 |
| 4.5~6.7초 | 양손 펼치기 → 느슨한 주먹 → 단단한 주먹 |
| 6.7~10.0초 | 머그 집기, 놓기, 다시 집어 던지기 |

기존 `hand_motion_regression`은 기존 팔과 제출용 팔에서 모두 `HAND_MOTION_REGRESSION_OK`로 종료했다. 빗나간 첫 시도 뒤에는 B를 유지하고 유효 타격 확인 뒤 A로 전환한다. B는 28프레임 중 11번째, A는 20프레임 중 9번째에 이벤트를 보냈다. 양쪽 접촉 자세와 이벤트가 일치했다. 본편 영상에서 실제 접촉점은 B·A 모두 왼쪽 x≈−0.200 m, 오른쪽 x≈+0.200 m, y≈1.062 m였다.

Debian 13, Godot 4.7.2 stable ed1daf0bf, Jolt, GL Compatibility, Mesa 25.0.7 llvmpipe/Xvfb, Blender 4.3.2에서 검증했다. 영상은 1280×720, 고정 30fps, 300프레임 H.264다. 고정 프레임 영상으로 실시간 성능을 측정할 수 없다. Windows, 하드웨어 GPU는 미검증이다. 실행 작업본의 한국어 Serif Bold·Black 글꼴은 같은 계열의 로컬 사본을 사용했다. 세 비교 조건에 동일하게 적용했으며 글꼴은 제출 변경에 포함되지 않는다.

## 재현

저장소 루트에서 실행한다. `asd/assets/player_arms_v2_enabled`의 키가 없으면 기존 팔이 선택된다. 설정을 true로 읽거나 `--rig-slice`를 지정하면 새 팔을 쓴다. 시작 로그의 `ASD player arms loaded: legacy` 또는 `rigged_v2`로 확인한다.

```sh
blender -b --python-exit-code 1 --python blender/submission/player/build_player.py -- "$PWD"
blender -b blender/rig_slice/player_arms.blend --python-exit-code 1 --python blender/submission/player/check_thumb.py -- /tmp/thumb-check.json
godot --headless --editor --path game --import
godot --headless --path game --script "$PWD/tools/tests/hand_motion_regression.gd"
godot --headless --path game --script "$PWD/tools/tests/hand_motion_regression.gd" -- --rig-slice
godot --path game --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 30 res://rig_slice/verify.tscn -- --capture=/tmp/asd-player-movie
ffmpeg -framerate 30 -start_number 1 -i /tmp/asd-player-movie/%04d.jpg -c:v libx264 -pix_fmt yuv420p -movflags +faststart /tmp/asd-player.mp4
```

화면 비교에는 디스플레이 또는 Xvfb가 필요하다. 아래에서 `BASE_GAME`은 기준 커밋 독립 checkout의 game 디렉터리 절대 경로다. 양쪽 프로젝트에 동일한 Godot import를 먼저 실행한다. 설정을 켜는 테스트 옵션은 비교 프로세스 안에서만 적용한다.

```sh
QA="$PWD/blender/submission/player"
godot --path "$BASE_GAME" --rendering-method gl_compatibility --fixed-fps 30 --script "$QA/compare.gd" -- --out=/tmp/asd-legacy
godot --path "$BASE_GAME" --rendering-method gl_compatibility --fixed-fps 30 --script "$QA/compare.gd" -- --rig-slice --out=/tmp/asd-previous
godot --path game --rendering-method gl_compatibility --fixed-fps 30 --script "$QA/compare.gd" -- --setting-on --out=/tmp/asd-final
python "$QA/measure_frames.py" /tmp/asd-legacy /tmp/asd-previous /tmp/asd-final
```

빈 출력 폴더에서도 제작 스크립트를 다시 실행했다. 양쪽 GLB의 모든 37개 정점 속성 스트림이 각각 일치했고, Blender 렌더 4장의 RGB 차이가 0이었다.

## 변경 파일

| 위치 | 파일 |
|---|---|
| game/scripts, game/rig_slice | player.gd, director.gd |
| game/assets/rig_slice | player_left.glb, player_right.glb |
| blender/rig_slice | player_arms.blend |
| blender/submission/player | build_player.py, check_thumb.py, compare.gd, measure_frames.py |
| 이 문서와 검증 데이터 | README.md, [framing.json](framing.json), [regression.json](regression.json), [events.json](events.json), [thumb_geometry.json](thumb_geometry.json) |
| 본편 1280×720 원본 | [guard_legacy.png](guard_legacy.png), [guard_previous.png](guard_previous.png), [game_guard.png](game_guard.png), [carry_legacy.png](carry_legacy.png), [carry_previous.png](carry_previous.png), [game_carry.png](game_carry.png) |
| 비교·검증 | [framing.jpg](framing.jpg), [guard_close.jpg](guard_close.jpg), [game_thumb_side.png](game_thumb_side.png), [thumb_comparison.jpg](thumb_comparison.jpg), [native_dialogue.jpg](native_dialogue.jpg), [actions.mp4](actions.mp4) |
| Blender 렌더 | [player_projection.png](player_projection.png), [fist_dorsal.png](fist_dorsal.png), [fist_thumb.png](fist_thumb.png), [fist_palm.png](fist_palm.png) |
