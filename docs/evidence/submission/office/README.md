# 사무실 소품 v2 검증

기준 커밋 `a449e6ab2467c65c704358de03e5a92b1e669d01`. 첫 구현 커밋 `f7f08a7e70884fba1f4548aad7c97a0698bece65`. Godot 4.7.2 공식 Linux 빌드, Jolt, Blender 4.3.2. 화면은 Xvfb와 Mesa llvmpipe OpenGL Compatibility에서 캡처했다. Windows 실기와 다른 담당자의 새 손·김부장을 합친 빌드는 별도 확인 대상이다. 촬영 환경의 Noto Serif KR Bold/Black은 같은 작업 공간의 로컬 사본을 사용했다. 두 파일의 Git 해시는 기준 커밋과 다르며 제출 범위에서 제외했다.

## 첫 묶음

| GLB | 삼각형 | 재질 | 검증한 동작 |
| --- | ---: | ---: | --- |
| desk | 616 | 6 | 시작 상판 Y=1.061 m, B·A 내려치기 최저 손 높이 각각 1.062 m |
| partition | 396 | 4 | 시작 가림판과 동료 책상 2곳의 패널 교체. 기존 상단 몰딩·기둥·메모 보존 |
| monitor | 968 | 6 | 화면 깨짐·깜빡임·부분 기울어짐 → 화면 꺼짐·받침대 기울어짐, 누적 피해액 100,000 → 300,000 |
| mug | 1,020 | 3 | 몸통·커피·손잡이 숨김 → 기존 도자기 파편, 누적 피해액 10,000 |

삼각형 수는 GLB 인덱스를 삼각형으로 환산한 단일 모델 기준, 재질 수는 GLB에 담긴 재질 슬롯의 고유 정의 수다. 설정 `asd/assets/office_props_v2_enabled`이 없으면 기존 사물을 사용한다. 사용자 인수 `--office-props-v2`로 켠다. 적용 시 종류마다 `OFFICE_PROP model=… version=2`가 한 번 출력된다.

- [같은 시작 프레임 · 기존](before.jpg) / [첫 묶음 적용](after-first.jpg)
- [김 팀장 빼꼼](boss-peek.jpg) / [가림막을 돌아 접근](boss-approach.jpg)
- [모니터·머그 손상 상태](damage-stages.jpg)
- [5.67초 본편 영상](office-replay.mp4). 집기 → 놓기 → 다시 집기 → 투척·파손 → 모니터 손상 단계 → 재시작. 이동하는 머그는 카메라 레이와 실제 물리 입력으로 처리한다. 모니터 단계 비교에는 정해진 세기의 receive_hit 입력을 사용했다. 근접 컷만 관찰 카메라로 전환한다.

머그는 기존 세 손잡이 부품과 동일한 외곽·피벗에 3 mm 모따기를 적용했다. 기존 리그의 손잡이 목표 (0.15305, 0.01334, -0.01783)에서 실제 잡기 포즈의 손 피부 정점 10,682개를 컵·커피·손잡이 메시와 비교했다. 내부로 들어간 표본의 깊이는 0 mm, 손잡이 표면과 최소 거리는 2.635 mm였다. 판정은 기존 리그의 고정 포즈에 대한 정점 표본이다.

## 재현 명령

저장소 루트에서 실행한다. 화면과 영상을 얻으려면 그래픽 디스플레이가 필요하다. Blender 원본과 내보낸 파일은 각 사물 이름을 공유한다.

```sh
blender -b --python-exit-code 1 -P blender/submission/office/build.py
godot --headless --path game --editor --import
godot --path game -- --office-props-v2
godot --headless --path game --fixed-fps 60 -- --smoke-test --office-props-v2
godot --headless --path game --fixed-fps 30 -- --capture-office --office-props-v2 --capture-dir /tmp/office-route
godot --path game --fixed-fps 30 -- --capture-opening --capture-dir /tmp/office-before
godot --path game --fixed-fps 30 -- --capture-opening --office-props-v2 --capture-dir /tmp/office-after
D="$PWD/docs/evidence/submission/office"
godot --path game --fixed-fps 30 --write-movie /tmp/office-review.avi --script "$D/replay.gd" -- --office-props-v2
godot --headless --path game --fixed-fps 30 --script "$D/grip_sample.gd" -- --office-props-v2
blender -b blender/submission/office/mug.blend --python-exit-code 1 -P "$D/grip_mesh_check.py"
```

본편 smoke 통과. 리플레이의 머그 입력·장부·재시작 9개 검사 통과. 시나리오 리플레이는 김 팀장의 세 접근·대사 제스처, 모니터 투척 파손, 경비 접근과 접촉, 결과 진입을 확인했다. 리그 검증에서 첫 B와 반복 A 순서 및 양손 접촉 높이 통과.
