# 김부장 전신과 플레이어 1인칭 팔

기준 게임은 main의 `c6daaefd9c98a7b2a2f6eda6b38c3e511bec79f8`이다. 김부장은 `d4f7f13791fe73b405a3b3c76a8ae17b0db212e5`의 `blender/studies/boss_kim_hands/boss_kim_hands.blend`에서 출발했다. 원본 Git blob은 `e3113e9f4d534fee34ed1ffd6c0989810f331045`다.

## 결과 확인

- [Godot 영상 · 10초](../../docs/evidence/rig_slice/rig_verification.mp4)에서 기본 양주먹, 오른손 펀치, 책상 첫 B와 반복 A, 손 펴고 쥐기, 머그잔 잡기·놓기·다시 잡아 던지기를 확인할 수 있다. 사무실과 NPC, HUD는 본편을 실행했다. 검증 장면은 반복 측정을 위해 머그잔을 집을 수 있는 위치에 둔다.
- [게임 기본 시점](../../docs/evidence/rig_slice/game_idle.jpg)과 [Blender 카메라](../../docs/evidence/rig_slice/player_projection.png)는 수직 FOV 77°, near 0.045m, 1280×720이다. 정지 자세에서 왼손목은 (328.483, 581.001)px, 오른손목은 (951.517, 581.001)px로 두 엔진에서 일치했다.
- [주먹의 손등·엄지·손바닥](../../docs/evidence/rig_slice/fist_views.jpg), [김부장 관절과 확대](../../docs/evidence/rig_slice/kim_joints.jpg), [김부장 GLB의 Godot 화면](../../docs/evidence/rig_slice/kim_godot.jpg), [정면·측면·후면을 포함한 원본 이미지와 측정값](../../docs/evidence/rig_slice).
- [boss_kim_game.blend](boss_kim_game.blend)의 1·20·40·60 프레임이 A포즈·어깨 들기·팔꿈치와 손목 굽힘·손가락 굽힘이다. [player_arms.blend](player_arms.blend)의 1·10·20·30 프레임에 펼친 손·소품용·기본 주먹·단단한 주먹이 있다. 게임은 그 사이를 보간한다. Blender에서 본을 보려면 뷰포트 오버레이를 켠다.
- [리깅된 GLB 세 파일](../../game/assets/rig_slice). 플레이어 Blender 원본에는 양팔이 함께 있고, 게임은 좌우 에셋을 각각 기존 손의 위치·회전 트랙에 연결한다.

| 최고 상세도 | 삼각형 | 본 | 재질 | 메시 | 정점당 최대 영향 본 |
|---|---:|---:|---:|---:|---:|
| 김부장 | 63,495 | 50 | 4 | 1 | 3 |
| 플레이어 왼팔 | 25,000 | 18 | 5 | 9 | 2 |
| 플레이어 오른팔 | 25,000 | 18 | 5 | 9 | 2 |

양팔은 같은 다섯 재질 구성을 각각 보유한다. `audit.py`가 내보낸 인덱스, 스킨 조인트 및 정점 웨이트 합을 검사한다. 세 파일의 최대 정규화 오차는 1e-7 미만이다. 빈 출력 폴더에서 두 에셋을 다시 생성했다. 김부장 GLB는 바이트까지 일치했고, 좌우 팔은 단추 삼각형의 기록 순서만 달랐다. 정점, 삼각형 집합, 웨이트와 애니메이션은 일치했다.

## 조형과 변형

김부장은 원래 얼굴의 각진 턱, 치켜올린 눈썹, 빗어 넘긴 머리, 넓은 몸통과 정장 패널을 살렸다. 얼굴·머리·의상은 원본 메시를 부위별로 감면했다. 편히 내린 소매를 공통 A포즈로 옮겨 좌우를 구성했고, 손은 관절에서 굽힐 수 있도록 새 메시로 만들었다. 쇄골과 어깨, 전완과 상완 경계에 가중치를 나눴다. 피부·머리·옷 색은 정점 색에 담았다. Godot Compatibility에서 피부가 흰색으로 보이는 문제를 가져오기 단계에서 수정했다.

플레이어 손은 손바닥에서 네 손가락과 엄지 밑동까지 붙어 있다. 손가락별 길이와 마디 간격이 다르고, 엄지에는 대립 회전을 줬다. 손톱은 끝마디와 함께 움직인다. 중간 자세에서 발견한 엄지·검지 겹침과 마디 안쪽 접힘을 수정했다. Blender에서 양손의 최종 피부 메시를 1–30 각 정수 프레임에 평가해, 정점을 공유하지 않는 삼각형끼리의 교차가 모두 0건임을 확인했다. 팔꿈치 주변 소매는 상완과 전완에 나눠 묶었고, 펀치·잡기 중에는 손목 궤적을 유지하며 팔꿈치 방향을 계산한다. 실제 렌더를 보면서 오른손만 덜 쥐어지던 애니메이션 내보내기와 펀치 시 소매 단면이 화면을 가리던 팔 자세를 수정했다.

## 검증

Debian 13, Blender 4.3.2 Cycles CPU, Godot 4.7.2 공식 Linux 빌드, GL Compatibility, Mesa 25.0.7 llvmpipe에서 확인했다. 영상은 실제 뷰포트 300프레임을 30fps로 인코딩했다. 이 수치는 녹화 재생 속도다. 한국어 HUD에는 로컬에서 사용할 수 있는 동일 계열 Noto Serif KR 글꼴을 사용했다.

| 검사 | 측정과 관찰 |
|---|---|
| 본편 회귀 | 기본 팔과 새 팔 모두 기존 hand_motion_regression 통과. 첫 B 28프레임, 반복 A 20프레임. 무효 시도 후 B 유지, 중단과 일반 펀치 포함 |
| 시작 책상 | B 11/30초, A 9/30초에 실제 게임 이벤트를 받았다. 양손 최저 피부 정점 Y=1.062m, 상판 Y=1.061m. 좌우 접촉점 X는 약 −0.200m와 +0.200m. 양손 모두 새끼손가락 쪽이 먼저 닿는다 |
| 손 펴기 | 검지 끝마디 본의 손 로컬 세로 좌표가 양쪽 모두 펼친 손 0.164m, 느슨한 주먹 0.120m, 단단한 주먹 0.090m로 이동했다. 좌우 대칭과 중간 자세를 실행 화면에서 확인했다 |
| 머그잔 | 실제 집기·놓기·던지기 경로를 사용했다. 손잡이와 손 표면 정점의 최소 간격은 2.64mm, 최대 관통은 0mm였다. 컵 몸통과 손잡이 상자 세 개 기준 |
| 화면 | 양주먹은 하단 좌우에 있고 기본 자세에서 조준점과 NPC 얼굴이 보인다. 인물 대사 HUD는 일부 동작에서 손 아래쪽과 겹친다 |

김부장이 팔을 크게 들면 재킷의 어깨와 소매가 만나는 경계가 드러난다. 플레이어 주먹은 확대 시 손등 마디가 둥글고, 엄지 쪽에서 보면 접힌 손가락 안쪽에 작은 빈틈이 보인다. 시작 책상·머그잔·지정 상지 자세를 검증했다. Windows 목표 PC의 프레임 시간, 다른 체형으로의 리타기팅과 래그돌은 미검증이다.

## 재현

저장소 루트에서 Bash로 실행한다. 두 에셋 중 하나만 재생성하려면 `build.py`의 마지막 인수로 `kim` 또는 `player`를 추가한다.

```bash
git fetch origin d4f7f13791fe73b405a3b3c76a8ae17b0db212e5
git show d4f7f13791fe73b405a3b3c76a8ae17b0db212e5:blender/studies/boss_kim_hands/boss_kim_hands.blend > /tmp/boss_kim_source.blend
blender -b --python-exit-code 1 --python blender/rig_slice/build.py -- /tmp/boss_kim_source.blend "$PWD"
blender -b blender/rig_slice/boss_kim_game.blend --python-exit-code 1 --python blender/rig_slice/detail.py -- "$PWD/docs/evidence/rig_slice"
blender -b blender/rig_slice/player_arms.blend --python-exit-code 1 --python blender/rig_slice/check_grip.py -- "$PWD/docs/evidence/rig_slice/grip_intersections.json"
python3 blender/rig_slice/audit.py
godot --headless --path game --import
godot --headless --path game --script ../tools/tests/hand_motion_regression.gd
godot --headless --path game --script ../tools/tests/hand_motion_regression.gd -- --rig-slice
```

새 팔로 직접 플레이하려면 `godot --path game -- --rig-slice`로 시작한다. 새 김부장은 별도 검증 장면에서 숫자 1–4로 자세를 전환한다. 사무실 영상에 나오는 김부장은 기존 NPC다.

```bash
godot --path game res://rig_slice/kim_review.tscn
godot --path game --fixed-fps 30 res://rig_slice/verify.tscn -- --capture="$PWD/frames"
ffmpeg -framerate 30 -i frames/%04d.jpg -c:v libx264 -crf 19 -preset fast -pix_fmt yuv420p -movflags +faststart -an rig_verification.mp4
```

Linux에서 모니터 없이 실제 화면을 캡처할 때는 Godot 실행 명령 앞에 `python3 tools/with_display.py --timeout 300 --`을 붙인다. 김부장 엔진 캡처는 `kim_review.tscn` 명령 뒤에 `-- --capture-kim="$PWD/kim-frames"`를 붙이면 된다.
