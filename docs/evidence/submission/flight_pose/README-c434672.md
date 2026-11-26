# 김부장 발차기 비행 자세 · 2차 기록(`c434672`) · 2026-11-26

> 3차(착지 바닥 침투 수정, `ee08dbb`)는 [README.md](README.md)에 있다. 이 문서는 2차 시점 기록이다.

## SHA와 실행 환경

| 구분 | SHA | 내용 |
| --- | --- | --- |
| 작업 기준 (`integration/submission-1126`, 원격 재확인) | `aecd0f1` | 수정 전 |
| 1차 비행 자세 | `893dbaf` | 런타임(비행 자세·인계) + 신규 검사 |
| 1차 증거 | `48356e3` | 증거만. 신발 침투 회귀가 이 커밋의 기록에서 확인됨 |
| **검증한 코드** | **`c434672`** | 발 충돌체가 신발을 감싸도록 수정, 신규 검사 착지 항목 추가, `test-kim-integration.ps1` 연결 |
| 증거 커밋 | 이 문서를 추가한 커밋(`c434672`의 다음 커밋) | 런타임 코드는 바꾸지 않는다 |

**로컬 실행 환경**
- Ubuntu 24.04.5 x86-64
- Godot `4.7.2.stable.official.ed1daf0bf`(공식 Linux 바이너리), Jolt
- Mesa 25.2.8 llvmpipe, Xvfb 1280×720
- 녹화는 `--fixed-fps 30 --write-movie`, 물리는 60틱이다.
- `--path game`으로 실행했다. 내보낸 PCK가 아니다.

**CI 실행 환경(실제 로그)**
- Linux: GitHub Actions `ubuntu-22.04`, workflow *Kim vertical slice*, run 45819643169
- Windows: GitHub Actions `windows-latest`, workflow *Office scenario v0.3*, run 45819643263
- 둘 다 `c434672`에서 실행했다.

**검증하지 않은 것:** 고정 FPS 녹화라서 실시간 히트스톱, 타격감, 성능은 검증하지 않았다. Windows 실기 화면도 미검증이다.

## 변경 요약

**`893dbaf` — 비행 자세.** 대상은 50본이다.
- 본 계층 FK로 각 관절이 자기 피벗을 기준으로 회전한다.
- 몸통·머리·팔은 맞은 쪽으로 뒤처지고, 무릎·팔꿈치는 경첩 축으로 굽는다. 내려오는 동안 몸통·머리·다리를 일부 다시 편다.
- 표시와 예상 충돌 검사가 같은 자세 함수를 쓴다.
- 인계 시 관절을 마지막 표시 자세 기준으로 다시 만든다.
- 각도(제안값, **PROPOSED**): 몸통 20°, 머리 14°, 고관절 35°, 다리 벌림 8°, 무릎 24°, 어깨(맞은 쪽) 35°, 어깨(바깥쪽) 55°, 팔꿈치 30°. 펴는 시점은 u 0.35부터다.

**`c434672` — 신발 침투 회귀 수정.** 비행 각도·방향·시간 곡선은 그대로다.
- 50본 발 상자 충돌체(`V2_BOX_SIZE`, `V2_CENTER_SHIFT`의 `Foot`)를 신발 메시 위로 옮겼다.
  - 바깥쪽 1.6cm, 뒤꿈치 쪽 0.95cm 이동. 좌우 대칭으로 오른발은 x를 반전한다.
  - 폭 0.279 → 0.29m. 높이와 길이는 그대로다.
- 결과: 신발 정점 1,719개 중 상자 밖에 있던 163개가 0개가 됐다.
- 다른 부위의 충돌체, 관절 제한, 질량, 물리 설정은 바꾸지 않았다.

## 신발 침투 원인 확인

요청에 있던 확인 지점별 결과다.

| 확인 지점 | 결과 | 근거 |
| --- | --- | --- |
| `_above_floor()`가 본 중심점만 확인해 회전한 밑창을 놓치는가 | 실제 침투 원인이 아니다 | 스크립트 비행 2번째 프레임부터 끝까지, 세 버전 2,442프레임에서 신발 바닥 침투 **0cm**(headless 분산 실행). 비행 첫 프레임 f29의 약 4.4cm는 아직 물리 자세(발차기 직후 0.1s)를 그린 프레임이며, 수정 전후가 같다. 함수는 바꾸지 않았다 |
| `_sole_points`를 비행 예상 자세와 실제 물리 자세에서 올바르게 변환할 수 있는가 | 가능하다 | 렌더 본(`skeleton.get_bone_global_pose`)과 물리 본(`body.global_transform * body_offset⁻¹`)으로 변환한 값이 모든 프레임에서 같았다. 신규 검사가 이 변환을 쓴다 |
| 발 충돌체가 실제 밑창을 충분히 감싸는가 | **감싸지 못했다 → 정지 후 침투 회귀의 원인** | 발 본 기준 휴지 자세에서 상자가 신발보다 1.6cm 안쪽에 있었다. 바깥 밑창 모서리가 **2.0cm**, 뒤꿈치가 **0.7cm** 상자 밖으로 나왔다(발당 1,719개 중 163개). 새 비행 자세로 착지하면 발이 바깥 모서리로 눕는다. 그때 정지 후 신발이 상자 바닥보다 1.4–1.8cm 아래에 있었다(wall 왼발: 상자 2.48cm, 신발 4.29cm, 밑창점 4.22cm 침투) |
| 물리 전환 순간의 침투인가, 전환 후 관절·접촉 상태 때문인가 | **전환 후**다 | 인계 직후 3프레임의 자세 변화는 0°이고, 인계 전 침투는 수정 전후가 같다. 증가분은 모두 착지 이후다. 큰 최대값은 착지 충격 중 발 상자 자체가 바닥에 한두 물리 스텝 묻히는 현상이다(아래 "남은 문제" 1) |

**정지 상태 판정.** 각 장면 마지막 측정 프레임에서 가장 빠른 물리 본 속도와 잠든 본 수를 함께 기록했다.
- 모든 본이 0.05m/s 미만일 때만 "정지 후" 값으로 부른다.
- 그렇지 않으면 "마지막 측정(정지 아님)"으로 표시한다.

## 같은 조건 수정 전후 비교 (렌더 실행)

같은 고정 장면·입력·Godot·환경에서 녹화했다. 로그는 [`logs/`](logs/)의 SHA별 폴더에, 요약은 [`compare.json`](compare.json)(수정 전 대 `c434672`)과 [`compare-48356e3.json`](compare-48356e3.json)에 있다.

### 신발 바닥 침투 (cm)

| 장면 | 최대: 수정 전 | 최대: 48356e3 | **최대: c434672** | 마지막: 수정 전 | 마지막: 48356e3 | **마지막: c434672** | c434672 마지막 프레임 정지? |
| --- | --- | --- | --- | --- | --- | --- | --- |
| office(본편) | 8.45 | 1.09 | **1.10** | 0.78 | 0.00 | **0.00** | 정지(15본 모두 수면) |
| front | 11.27 | 4.44 | **4.21** | 1.04 | 1.63 | **1.98** | 정지 |
| side | 6.73 | 4.62 | **4.52** | 1.66 | 1.88 | **0.76** | 정지 아님(최고 0.97m/s, 수정 전 1.25m/s) |
| wall | 5.46 | 7.74 | **4.21** | 3.57 | 4.29 | **2.13** | 정지(수정 전은 정지 아님 0.16m/s) |
| open | 4.44 | 4.44 | **5.78** | 2.72 | 3.82 | **2.39** | 정지 |
| ledge | 2.80 | 3.01 | **13.16** | 1.29 | 2.85 | **1.07** | 정지 아님(0.050m/s) |

**최대값을 인계 전후로 나눈 값**(c434672)
- 인계 전 최대는 모든 장면에서 수정 전과 같거나 작다: front 4.21 / side 4.52 / wall 4.21 / open 4.21 / ledge 0.00 / office 1.09.
- 인계 후(착지) 최대는 다음과 같다.

| 장면 | 수정 전 | c434672 |
| --- | --- | --- |
| front | 11.27 | **3.64** |
| side | 6.73 | **1.32** |
| wall | 5.46 | **3.15** |
| open | 4.41 | **5.78** |
| ledge | 2.80 | **13.16** |
| office | 8.45 | **1.10** |

**요청한 회귀 항목의 결과**
- wall 최대 7.74 → **4.21** (수정 전 5.46보다 낮음)
- wall 마지막 4.29 → **2.13** (수정 전 3.57보다 낮음)
- open 마지막 3.82 → **2.39** (수정 전 2.72보다 낮음)
- ledge 마지막 2.85 → **1.07** (수정 전 1.29보다 낮음)
- side 마지막 1.88 → **0.76** (수정 전 1.66보다 낮음)
- front 마지막 1.63 → **1.98**: 해결 안 됨. 수정 전 1.04보다 0.94cm 높다(아래 "남은 문제" 2)

### 착지 분산 (headless, 장면당 시작 위치 11개)

렌더 1회 결과는 발이 어디에 닿느냐에 크게 흔들린다. 그래서 김부장과 플레이어를 옆으로 −0.10–0.10m 옮긴 11회씩을 세 버전에서 돌렸다.
- headless는 히트스톱 실시간 계산이 렌더 실행과 달라서 렌더 표와 같은 조건이 아니다. 분포 비교용이다.
- 전체 표는 [`spread-table.txt`](spread-table.txt), 실행별 값은 [`spread-summary.json`](spread-summary.json), 산출 스크립트는 [`spread.py`](spread.py)다.

| 장면 | 착지 최대 중앙값 cm (전 → 48356e3 → c434672) | 마지막 중앙값 cm (전 → 48356e3 → c434672) |
| --- | --- | --- |
| front | 7.57 → 3.35 → **3.34** | 3.09 → 1.90 → **1.86** |
| side | 4.40 → 2.84 → **1.90** | 1.33 → 2.33 → **0.74** |
| wall | 5.78 → 3.30 → **3.38** | 3.51 → 2.39 → **2.20** |
| open | 7.02 → 9.16 → **9.03** | 1.23 → 3.43 → **2.19** |
| ledge | 3.35 → 6.77 → **7.89** | 1.09 → 0.00 → **0.00** |

### 유지 확인

c434672 기준 모든 렌더 장면에서 다음을 확인했다.

- **비행 초반 움직임:** 비행 시작 후 게임 0.067s에 둘 이상 부위가 5° 넘게 움직인다. 비행 중 관절 간격 변화는 0mm, 벽·가구 관통은 0프레임이다.
- **정상 종료와 충돌 종료:** ledge·office는 u=1 정상 종료, front·side·wall·open은 충돌 종료다. 수정 전과 종료 시점이 같다. 단, wall은 48356e3과 같은 u 0.833이다(수정 전 0.571, 원인은 1차 README 참고).
- **인계 직후:** 3프레임 자세 변화는 0°다. 예외는 open의 12.8°로, 바닥 충돌 종료 직후 착지가 겹친 값이다(수정 전 40.5°).
- **본편 오프닝:** 수정 전후 모두 `valid:true`다. 발차기 입력 f599(19.967s) → 비행 시작 f607(20.233s) → 정상 종료 f628(20.933s).

## 검사

| 검사 | 결과 |
| --- | --- |
| 로컬: `test-kim-integration.ps1`과 같은 구성 | `run-kim-matrix.sh`로 62/62 통과. ps1과 같은 종료 코드·`ERROR` 줄·표식 규칙을 적용했다. [기록](checks/matrix-after-c434672.txt) |
| CI Linux(`ubuntu-22.04`) | `pwsh tools/test-kim-integration.ps1` 62개 실행·통과. `RUN default kim_flight_pose_regression`, `RUN rig-31 kim_flight_pose_regression`, `KIM_INTEGRATION_MATRIX_OK` 확인. [발췌](checks/ci-c434672/linux-ubuntu-22.04-kim-slice-45819643169.txt) |
| CI Windows(`windows-latest`) | 같은 62개 실행·통과. 착지 수치는 Linux와 같고 ledge 정지 시간만 1.30s 대 1.32s로 다름. [발췌](checks/ci-c434672/windows-latest-office-scenario-45819643263.txt) |
| 실패 종료 확인 | `48356e3` 코드에 새 검사를 넣으면 `ERROR: KIM_FLIGHT_POSE_CHECK` 3건이 나오고 종료 코드 1로 끝난다. ps1 helper는 0이 아닌 종료 코드나 `ERROR:` 줄에서 `throw`한다. [기록](checks/kim_flight_pose_regression-on-48356e3-fails.txt) |

**ps1 변경:** `kim_flight_pose_regression`을 기존 3모드 반복 배열에 넣지 않았다. 별도 블록에서 두 모드로만 명시 실행한다.
- `default`: 50본
- `rig-31`: `--kim-rig`, 31본

**`kim_flight_pose_regression` 착지 항목(이번 추가)**
- **정적:** 양발의 신발 정점(신발 재질, 발 본 주 가중치)이 모두 발 상자 안에 있다. 허용 1mm, 정점 100개 이상이어야 한다. 이번 회귀 원인을 직접 잡는다(48356e3에서 2.0cm 밖으로 나와 실패).
- **동적:** ledge 정상 종료와 1.9m 벽 충돌 착지 뒤 확인한다.
  - 모든 본이 0.5초 연속 0.05m/s 미만이 될 때까지 진행한다(최대 8초).
  - 김부장이 실제로 정지해야 한다.
  - 착지 동안 밑창점이 발 상자 바닥보다 5mm 넘게 내려가지 않아야 한다.
  - 정지 후와 최대 밑창 침투를 출력한다: ledge 2.35/2.17cm, wall 2.00/1.72cm.
- **기존 항목:** 비행 초반 움직임, 관절 연결, 인계 연속성, 벽 관통, 31본 경로 유지는 그대로 검사한다.

## 남은 문제 (해결되지 않은 회귀)

### 1. ledge·open의 착지 최대 침투

렌더 기준 ledge 2.80 → 13.16cm, open 4.41 → 5.78cm다. 분산 중앙값도 ledge 3.35 → 7.89, open 7.02 → 9.03으로 높다.

**원인(확인)**
- 침투가 계속 쌓이는 것이 아니다. 착지 후 한 물리 스텝 동안 발 상자 자체가 바닥으로 7–10cm 내려갔다가 다음 프레임에 돌아온다.
- 그 스텝에서 Jolt가 보고한 발–바닥 접촉 법선이 **(0, −1, 0)**이고, 접촉점은 바닥 위 0.35–0.44m다.
  - 바닥은 두께 0.3m 상자 하나뿐이고, 우리 `_integrate_forces`는 비스크립트 상태에서 발을 건드리지 않는다.
  - 같은 스텝에 발목 관절 간격이 30mm에서 78–91mm로 벌어진다.
- **수정 전 코드에서도 같은 현상이 나온다.** 예: open 분산의 수정 전 실행, 거의 정지한 f157에서 발목 간격 22 → 78mm, 발 7cm 하강.
- ledge에서는 착지 지점 옆 낮은 가구(상판 밑면 y=0.45m) 아래로 발이 들어간 경우가 큰 값을 만든다. 분산의 5cm 초과 8/8건이 모두 이 경우다.
- 새 비행 자세는 착지 위치와 발 방향을 바꿔서, 이 두 레인에서 이 현상을 더 자주 일으킨다. 48356e3에서도 같은 경향이었다.
- **확인한 실험:** 발목 비틀기 제한을 10°에서 30°로 넓히면 ledge는 줄었지만 open이 13cm로 커졌다. 원인 해결이 아니어서 넣지 않았다.

**다음 후보(범위 밖, PROPOSED)**
- 발 충돌체 형태 변경(상자 → 캡슐 등)
- Jolt 반복 횟수 등 물리 설정

둘 다 모든 래그돌에 영향을 주므로 별도 작업으로 다뤄야 한다.

### 2. front 마지막 측정

렌더 1회 기준 1.04 → 1.98cm다. 분산 중앙값은 3.09 → 1.86으로 낮아졌다.

**원인:** 신발은 이제 발 상자 안에 있다. 남은 침투는 정지한 발 상자 자체가 바닥에 약 2.5cm 묻혀 있는 상태다(Jolt 접촉 여유, 모든 버전 공통 2–4cm). 렌더 1회의 착지 방향에 따라 값이 달라진다.

### 3. 기존 한계(1차와 같음)

- 골반–가슴 관절이 발차기 직후 약 9cm 벌어진다.
- 시험 장면 wall·ledge는 시험용 정적 박스를 쓴다.
- 각도는 사용자 시각 승인 전이다.

## 영상과 연속 프레임 (수정 전 `aecd0f1` 대 `c434672`)

| 장면 | 전후 비교 영상 | 30fps 연속 프레임(위: 전, 아래: 후) |
| --- | --- | --- |
| 본편 오프닝 발차기 | [office-kick-before-after.mp4](video/office-kick-before-after.mp4) | [office-f604-635.jpg](frames/office-f604-635.jpg) |
| 정면 타격, 플레이어 시점 | [front-before-after.mp4](video/front-before-after.mp4) | — |
| 정면 타격, 측면 카메라 | [front-sideview-before-after.mp4](video/front-sideview-before-after.mp4) | [front-sideview-f28-51.jpg](frames/front-sideview-f28-51.jpg) |
| 정상 종료(ledge), 측면 카메라, 착지 후까지 6s | [ledge-normal-end-sideview-before-after.mp4](video/ledge-normal-end-sideview-before-after.mp4) | [ledge-normal-end-sideview-f28-59.jpg](frames/ledge-normal-end-sideview-f28-59.jpg) |
| 조기 충돌(wall), 측면 카메라 | [wall-early-crash-sideview-before-after.mp4](video/wall-early-crash-sideview-before-after.mp4) | [wall-early-crash-sideview-f28-51.jpg](frames/wall-early-crash-sideview-f28-51.jpg) |
| 측면 타격 | [side-hit-before-after.mp4](video/side-hit-before-after.mp4) | [side-hit-f28-51.jpg](frames/side-hit-f28-51.jpg) |
| 본편 재생 전체 | [전](video/office-replay-before.mp4) · [후](video/office-replay-after.mp4) | — |

`48356e3` 기준 영상·프레임은 그 커밋의 같은 경로에 남아 있다.

ledge 착지 스파이크(f66, f69)는 측면 카메라에서 발이 화면 밖·HUD 뒤에 있어 영상으로 보여 줄 수 없다. 프레임별 수치로만 기록했다(`logs/c434672/A-ledge.json.gz`).

## 변경 파일 (`c434672` + 증거 커밋)

- `game/scripts/characters/kim_visual_adapter.gd`: 발 상자 크기·위치, 오른발 x 반전
- `tools/tests/kim_flight_pose_regression.gd`: 신발 상자 포함, 착지 정지·밑창 검사
- `tools/test-kim-integration.ps1`: 신규 검사 2모드 명시 실행
- 증거 폴더
  - `flight-capture.gd`: 신발 최저점·정지 기록, `--kim-offset`, headless 프레임 번호
  - `compare.py`: 인계 전후 최대, 정지 판정
  - `spread.py`, `run-kim-matrix.sh`: 종료 코드·ERROR 규칙, 신규 2모드
  - 로그·영상·프레임·검사 기록 갱신

## 재현

```sh
godot --headless --path game --import
D="$PWD/docs/evidence/submission/flight_pose"
# 렌더 비교 (Xvfb 가능): office는 --fixture 없이, 고정 장면은 front|side|wall|open|ledge
godot --path game --audio-driver Dummy --fixed-fps 30 --write-movie /tmp/A-front.avi --script "$D/flight-capture.gd" -- --log=/tmp/A-front.json --fixture=front
python3 "$D/compare.py" /tmp /tmp/compare.json
# 착지 분산 (headless): 시작 위치를 옆으로 이동
godot --headless --path game --fixed-fps 30 --script "$D/flight-capture.gd" -- --log=/tmp/<tree>-ledge-0.04.json --fixture=ledge --kim-offset=0.04
python3 "$D/spread.py" /tmp <tree> ...
# 검사
pwsh tools/test-kim-integration.ps1 -GodotPath "$(command -v godot)"     # CI와 같은 실행
bash "$D/run-kim-matrix.sh" "$(command -v godot)" "$PWD" /tmp/matrix    # PowerShell이 없을 때
```
