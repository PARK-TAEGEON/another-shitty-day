# 김부장 발차기 비행 자세 · 2026-11-26

## 실행 대상 SHA

| 구분 | SHA |
| --- | --- |
| 작업 기준 (`integration/submission-1126`, 원격에서 재확인) | `aecd0f1354bddf93827263e8692c8d83b796e4f2` |
| 수정 후 검증한 코드 | `893dbaf3a7f17e517e1382184d4ea7f8bbe3418d` |
| 증거 커밋 | 이 문서를 추가한 커밋(`893dbaf`의 다음 커밋). 런타임 코드는 바꾸지 않는다 |

수정 전 결과는 `aecd0f1`을 별도 worktree에서 실행했다. 수정 후 결과는 `893dbaf`를 실행했다. 두 경우 모두 이 폴더의 같은 캡처 스크립트를 썼다.

## 실행 환경

- Ubuntu 24.04.5 x86-64
- Godot `4.7.2.stable.official.ed1daf0bf`(공식 Linux 바이너리), Jolt, GL Compatibility
- Mesa 25.2.8 llvmpipe(LLVM 20.1.2), Xvfb 1280×720
- 녹화는 `--fixed-fps 30 --write-movie`로 했고, 물리는 60틱이다.

통합 기록과 다른 점:
- 통합 기록은 내보낸 PCK로 실행했다. 이번에는 export template이 없어 `--path game`으로 실행했다.
- 고정 FPS 녹화라서 실시간 히트스톱, 타격감, 성능은 검증하지 않았다.
- Windows 실기는 미검증이다.

## 문제와 변경

**문제.** 50본 김부장은 발차기 후 0.1초 동안 실제 물리로 움직인 뒤 스크립트 비행으로 넘어간다. 이때 15개 물리 본의 상대 위치를 그대로 고정하고, 몸 전체를 한 각도(최대 −60°)로만 기울였다. 그 결과 0.7초 비행 동안 선 자세 그대로 이동했다.

**변경.** 런타임 파일은 `game/scripts/characters/kim_visual_adapter.gd` 하나다.

1. **비행 시작 시 저장.** `_capture_flight_fold()`가 본마다 다음 값을 저장한다.
   - 시작 transform, 부모 물리 본, 관절 피벗(본 원점)
   - 완전히 접혔을 때의 회전
2. **방향 기준.** 회전 방향은 전역 축이 아니라 김부장의 골반 프레임(좌우·앞)과 비행 방향에서 계산한다.
   - 몸통·머리·팔은 맞은 쪽으로 뒤처진다. 팔은 어깨에서 바깥쪽으로도 벌어진다.
   - 고관절은 타격 방향 중 앞뒤 성분으로만 굽힌다. 옆에서 맞았을 때 허벅지끼리 겹치지 않게 하기 위해서다.
   - 무릎·팔꿈치는 각 본의 좌우 축(경첩)으로 굽힌다.
3. **공통 자세 함수.** `_flight_body_transforms()`는 본 계층을 따라 각 관절을 자기 피벗 기준으로 회전시킨다(FK). 그래서 본 길이와 관절 연결이 바뀌지 않는다.
   - 표시(`_place_flight_pose`)와 예상 충돌 검사(`_flight_pose_points` → `_pose_hits_solid`, `_planned_burial`, `_room_shift`)가 이 함수 하나를 쓴다.
   - `_above_floor`는 50본에서만 실제 자세 점을 쓴다. 인계 뒤에는 실제 본 위치를 쓴다.
4. **접힘 시간 곡선.**
   - u 0→0.25 구간에서 접힌다.
   - u 0.35→1 구간에서 몸통 60%, 머리 60%, 다리 75%를 다시 편다. 팔과 팔꿈치는 벌린 채 유지한다.
   - 인계 직전에 선 자세로 강제로 되돌리지 않는다. 마지막으로 표시된 자세가 그대로 물리로 넘어간다.
5. **물리 인계.** 원래 원뿔 관절은 발차기 순간의 선 자세를 기준으로 만들어져 있다. 그대로 두면 굽힌 고관절·무릎이 인계 직후 펴지는 쪽으로 당겨진다. 이를 실험으로 확인했다(무릎 35°를 3스텝 만에 약 24°로 되돌림).
   - 충돌 종료와 정상 종료 모두 `_rebase_joints_to_flight_pose()`가 관절을 현재 자세로 다시 만든다(`joint_type` NONE→CONE).
   - 관절 허용 범위(swing/twist)는 원래 값을 그대로 쓴다.
6. **바꾸지 않은 것.**
   - 31본(`--kim-rig`)과 절차 모델(`--kim-legacy`)은 기존 경로를 그대로 탄다.
   - `flight_distance`, `flight_peak`, `flight_time`, `boost_delay`, 골반 포물선, 타격·피해·점수 처리는 바꾸지 않았다.

**튜닝 값(제안값).**

| 부위 | 몸통 | 머리 | 고관절 | 다리 벌림 | 무릎 | 어깨(맞은 쪽 방향) | 어깨(바깥쪽 벌림) | 팔꿈치 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 각도 | 20° | 14° | 35° | 8° | 24° | 35° | 55° | 30° |

처음 후보였던 35°·25°·70° 중 몸통은 측면 화면에서 공처럼 말려 보여 25°→20°로 낮췄다. 사용자 시각 승인 전이므로 **PROPOSED**다.

## 타임라인 (본편 오프닝 재생, 수정 전후 동일)

`movie_s`는 영상 프레임/30이다. 이 영상에서 점수가 바뀌는 프레임으로 맞는지 확인했다. 히트스톱 때문에 게임 시간은 영상 시간보다 짧다.

| 사건 | 영상 프레임 | 영상 시각 | 게임 시간 | u |
| --- | --- | --- | --- | --- |
| 발차기 입력(재생 스크립트 `kick_frame`) | 599 | 19.967s | — | — |
| 발 표시 | 600 | 20.000s | — | — |
| 발차기 접촉 | 602 | 20.067s | 20.0133 | — |
| 래그돌 시작 | 603 | 20.100s | 20.0147 | — |
| 스크립트 비행 시작 | 607 | 20.233s | 20.1267 | 0.024 |
| 정상 종료(u=1) → 물리 인계 | 628 | 20.933s | 20.8267 | 1.000 |

## 고정 장면

모든 고정 장면은 발차기 접촉 f24(0.800s), 래그돌 시작 f25, 비행 시작 f29(0.967s, 게임 0.9133, u 0.024)로 같다.

| 장면 | 조건 | 수정 전 종료 | 수정 후 종료 |
| --- | --- | --- | --- |
| front | `kim-landing-fixture.gd`와 같은 위치, 정면 타격 | 충돌 f44, u 0.738 | 충돌 f44, u 0.738 |
| side | 김부장을 −90° 돌려 왼쪽 옆구리 타격 | 충돌 f45, u 0.762 | 충돌 f45, u 0.762 |
| wall | 등 뒤 1.1m에 시험 벽(z=2.9) | 충돌 f41, u 0.571 | 충돌 f46, u 0.833 |
| open | x=−5.5 통로, 5.4m 이상 비어 있음 | 바닥 충돌 f49, u 0.952 | 바닥 충돌 f49, u 0.952 |
| ledge | 높이 1m 시험 받침대에서 차서 떨어뜨림 | 정상 종료 f50, u 1.0 | 정상 종료 f50, u 1.0 |

`open`은 수정 전에도 u 0.952에서 끝난다. 하강 중 `_sweep_flight`의 골반 아래 0.5m 구가 바닥에 닿기 때문이다. 평평한 바닥에서 정상 종료(u=1)를 확인하려고 `ledge`를 추가했다. 본편 오프닝 재생은 정상 종료로 끝난다.

## 결과

`compare.py`로 산출했다. 원본 값은 [`compare.json`](compare.json)과 [`logs/`](logs/)에 있다(프레임별 JSON, gzip).

| 장면 | 둘 이상 그룹 5° 이상 변화(비행 시작 후 게임 시간) | 비행 중 관절 간격 변화 | 인계 후 3프레임 최대 관절 회전 | 인계 후 10프레임 관절 간격 변화 | 신발 최대 바닥 침투 | 정지 후 바닥 침투 |
| --- | --- | --- | --- | --- | --- | --- |
| office 전 | 없음 | 0.6mm | 0.9° | 95.9mm | 8.45cm | 0.78cm |
| office 후 | **0.067s** | 0.0mm | 0.0° | 15.6mm | 1.09cm | 0.00cm |
| front 전 | 없음 | 0.0mm | 8.2° | 15.9mm | 11.27cm | 1.04cm |
| front 후 | **0.067s** | 0.0mm | 0.0° | 0.0mm | 4.44cm | 1.63cm |
| side 전 | 없음 | 2.2mm | 7.0° | 15.1mm | 6.73cm | 1.66cm |
| side 후 | **0.067s** | 0.0mm | 0.0° | 1.0mm | 4.62cm | 1.88cm |
| wall 전 | 없음 | 2.8mm | 6.5° | 13.1mm | 5.46cm | 3.57cm |
| wall 후 | **0.067s** | 0.0mm | 0.0° | 0.6mm | 7.74cm | 4.29cm |
| open 전 | 없음 | 2.8mm | 40.5° | 16.0mm | 4.44cm | 2.72cm |
| open 후 | **0.067s** | 0.0mm | 16.0° | 1.6mm | 4.44cm | 3.82cm |
| ledge 전 | 없음 | 3.4mm | 7.3° | 15.1mm | 2.80cm | 1.29cm |
| ledge 후 | **0.067s** | 0.0mm | 0.0° | 2.0mm | 3.01cm | 2.85cm |

- **그룹 변화.** 그룹은 몸통·머리·팔·다리·무릎·팔꿈치다. 각 본의 부모 본 대비 회전을 비행 시작 시점과 비교했다.
  - 수정 후에는 비행 2프레임째(게임 0.067s)부터 둘 이상 그룹이 5° 넘게 움직인다. 0.1s 시점의 본편 값은 팔 37°, 몸통 12°, 다리 21°다(f610).
  - 수정 전에는 비행 전체 13–22프레임이 선 자세 그대로였다.
- **관절 간격.** 비행 시작 때의 부모 본 기준 관절 위치와 비교했다.
  - 수정 후 비행 중 변화는 0.0mm다. 팔다리가 늘거나 관절이 벌어지지 않는다.
  - 인계 직후 간격이 벌어지는 정도도 줄었다. 본편 기준 95.9mm에서 15.6mm다.
- **인계 연속성.** 수정 후에는 정상 종료와 조기 충돌 모두 인계 후 3프레임 동안 자세 변화가 0°다. 낙하 중에는 접힌 자세를 유지한다.
  - `open`의 16.0°는 바닥 충돌로 끝나 인계 3프레임 안에 착지한 값이다. 수정 전에는 같은 상황에서 40.5°였다.
- **벽·가구 관통.** 비행 중 벽·가구와 겹친 프레임은 모든 장면에서 0이다.
  - `wall` 수정 후 본 중심의 최소 z는 3.378이다(벽 면은 z=3.0, 수정 전은 3.156).
  - 인계 뒤 착지 중 발이 2프레임 접촉했다(f55, f59).

### 착지 비교와 악화 항목

| 장면 | 신발 최대 침투 | 정지 후 침투 |
| --- | --- | --- |
| office | 8.45 → **1.09cm** (개선) | 0.78 → **0.00cm** (개선) |
| front | 11.27 → **4.44cm** (개선) | 1.04 → 1.63cm (+0.59cm) |
| side | 6.73 → **4.62cm** (개선) | 1.66 → 1.88cm (+0.22cm) |
| wall | 5.46 → 7.74cm (**+2.28cm**) | 3.57 → 4.29cm (+0.72cm) |
| open | 4.44 → 4.44cm | 2.72 → 3.82cm (**+1.10cm**) |
| ledge | 2.80 → 3.01cm | 1.29 → 2.85cm (**+1.56cm**) |

- **본편 오프닝은 개선, 시험 장면 일부는 악화.** 시험 장면 중 정지 후 침투가 가장 크게 늘어난 것은 ledge +1.56cm, open +1.10cm다.
- **추정 원인.** 인계 때 관절 기준을 접힌 자세로 다시 잡아서, 정지 자세가 이전(곧게 펴고 엎드림)보다 다리를 약간 굽힌 상태로 남는다. 이 때문에 신발 밑창 끝이 바닥 아래로 더 내려간다.
- **완화한 과정.** 처음에는 접힌 자세를 끝까지 유지했고, 그때 정지 후 침투는 최대 3.8cm였다. u 0.35부터 다리를 다시 펴도록 바꿔 줄였다.
- **wall 충돌 시점 변화(u 0.571 → 0.833).** 새 자세에서는 다리가 맞은 쪽(뒤)으로 굽어 비행 방향 앞쪽에 오는 점이 줄었다. 그래서 `_pose_hits_solid`와 `_planned_burial`이 더 늦게 벽을 감지한다. 벽은 통과하지 않았다.

## 검사

| 검사 | 결과 |
| --- | --- |
| `tools/test-kim-integration.ps1` 구성(3모드×19 + 31본 `--kim-rig`, 재시작, 비행 장애물) | 수정 전 60/60, 수정 후 60/60 통과. [후](checks/matrix-after-893dbaf.txt) · [전](checks/matrix-before-aecd0f1.txt) |
| 신규 `tools/tests/kim_flight_pose_regression.gd` | 수정 후 기본값·`--kim-rig` 통과. 수정 전 코드에 같은 파일을 넣으면 기본값에서 실패한다(초반 상대 움직임 없음, ledge 인계 8.5° 튐). [기록](checks/kim_flight_pose_regression.txt) |
| 본편 오프닝 재생(`kim-landing.gd` 동일 흐름) | 수정 전후 모두 `valid:true`. 대사, 빼꼼·접근, 주먹 뒤 `concern`, 발차기 뒤 `down` 확인 |

- **matrix 실행 방식.** PowerShell을 쓸 수 없어 같은 검사 목록·인수·통과 표식을 그대로 옮긴 [`run-kim-matrix.sh`](run-kim-matrix.sh)로 실행했다. 기존 기대값은 바꾸지 않았다.
- **신규 검사 항목.**
  - 비행 0.1s 안에 몸통·팔·다리 중 둘 이상이 5° 이상 상대 회전한다.
  - 비행 중 관절이 2mm 넘게 벌어지지 않는다.
  - 인계 후 3스텝 자세 변화가 6° 미만이다.
  - ledge는 정상 종료하고, 1.9m 벽은 충돌하며 통과하지 않는다.
  - 31본은 50본 비행 자세 상태를 쓰지 않는다.

## 영상과 연속 프레임

| 장면 | 전후 비교 영상 | 30fps 연속 프레임(위: 전, 아래: 후) |
| --- | --- | --- |
| 본편 오프닝 발차기 | [office-kick-before-after.mp4](video/office-kick-before-after.mp4) (19.8s부터 4.2s) | [office-f604-635.jpg](frames/office-f604-635.jpg) |
| 정면 타격, 플레이어 시점 | [front-before-after.mp4](video/front-before-after.mp4) | — |
| 정면 타격, 측면 카메라 | [front-sideview-before-after.mp4](video/front-sideview-before-after.mp4) | [front-sideview-f28-51.jpg](frames/front-sideview-f28-51.jpg) |
| 정상 종료(ledge), 측면 카메라 | [ledge-normal-end-sideview-before-after.mp4](video/ledge-normal-end-sideview-before-after.mp4) | [ledge-normal-end-sideview-f28-59.jpg](frames/ledge-normal-end-sideview-f28-59.jpg) |
| 조기 충돌(wall), 측면 카메라 | [wall-early-crash-sideview-before-after.mp4](video/wall-early-crash-sideview-before-after.mp4) | [wall-early-crash-sideview-f28-51.jpg](frames/wall-early-crash-sideview-f28-51.jpg) |
| 측면 타격 | [side-hit-before-after.mp4](video/side-hit-before-after.mp4) | [side-hit-f28-51.jpg](frames/side-hit-f28-51.jpg) |
| 본편 재생 전체 | [전](video/office-replay-before.mp4) · [후](video/office-replay-after.mp4) | — |

- 연속 프레임 이미지의 라벨은 영상 프레임, 영상 시각, 게임 시간, u, 비행 여부다. 빨간 띠는 사건(비행 시작·종료)이다.
- 측면 카메라는 증거용 별도 Camera3D다(`--side-view`). 게임 카메라와 물리는 바꾸지 않는다.

## 남은 한계

- **골반–가슴 관절 간격(기존 문제).** 발차기 직후 0.1s 실제 물리 구간에서 골반–가슴 관절 간격이 약 92–95mm로 벌어진다. 수정 전후 같으며, 비행 중에는 그 값이 유지된다. 이번 범위(비행 자세·인계) 밖이라 고치지 않았다.
- **정지 후 신발 침투.** 시험 장면 일부(ledge, open, wall)에서 정지 후 침투가 0.7–1.6cm 늘었다. 본편 오프닝은 개선됐다.
- **접힘 속도.** 30fps 기준 접히는 3–4프레임 동안 팔이 프레임당 최대 약 20° 회전한다. 의도한 빠른 반응이지만, 실시간 화면에서 끊겨 보이는지는 사용자 확인이 필요하다.
- **미검증.** 각도 값은 제안값이다. 실시간 타격감, Windows 실기, 내보낸 PCK 실행은 확인하지 않았다.
- **고정 장면 구성.** `wall`·`ledge`는 시험용 정적 박스를 추가한 고정 장면이다. 본편 레벨 구성이 아니다.

## 변경 파일

- `game/scripts/characters/kim_visual_adapter.gd`(런타임)
- `tools/tests/kim_flight_pose_regression.gd`(신규 검사)
- `docs/evidence/submission/flight_pose/` 증거 일체
  - 스크립트: `flight-capture.gd`, `compare.py`, `frames.py`, `run-kim-matrix.sh`
  - 결과: `compare.json`, `logs/`, `video/`, `frames/`, `checks/`

## 재현

저장소 루트에서 실행한다. 캡처에는 디스플레이(Xvfb 가능)가 필요하다.

```sh
godot --headless --path game --import
D="$PWD/docs/evidence/submission/flight_pose"
# 본편 오프닝 재생 (kim-landing.gd와 같은 흐름 + 프레임 로그)
godot --path game --audio-driver Dummy --fixed-fps 30 --write-movie /tmp/office.avi --script "$D/flight-capture.gd" -- --log=/tmp/A-office.json
# 고정 장면: front | side | wall | open | ledge, 측면 카메라는 --side-view
godot --path game --audio-driver Dummy --fixed-fps 30 --write-movie /tmp/front.avi --script "$D/flight-capture.gd" -- --log=/tmp/A-front.json --fixture=front
python3 "$D/compare.py" /tmp /tmp/compare.json   # B-*/A-* 로그 비교
bash "$D/run-kim-matrix.sh" "$(command -v godot)" "$PWD" /tmp/matrix
godot --headless --fixed-fps 60 --path game --script "$PWD/tools/tests/kim_flight_pose_regression.gd"
godot --headless --fixed-fps 60 --path game --script "$PWD/tools/tests/kim_flight_pose_regression.gd" -- --kim-rig
```
