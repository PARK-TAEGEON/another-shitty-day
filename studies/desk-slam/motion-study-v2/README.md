# Desk-slam motion study v2

사용자 피드백을 반영한 **3D 모션 검토본**입니다. 자동 재생으로 `첫 동작 B → 이후 A → A` 순서를 보여줍니다. 플레이어 입력에 연결한 게임 빌드는 아니며, 캐릭터 외형은 아직 미정입니다.

## 변경 사항

- 화면에 길게 보이던 직선 소매를 팔꿈치 쪽에서 바깥으로 굽혔습니다. 손목과 소매는 연결되어 있으며 팔 끝은 화면 밖으로 이어집니다.
- 접촉 위치를 카메라 쪽으로 12.5 cm 옮기고, 들어 올리는 높이를 6.5 cm 낮췄습니다. 카메라 시야각 62도와 장면 색은 유지했습니다.
- 엄지를 접힌 손가락에 더 밀착하고 주먹 형태를 압축했습니다. 준비 동작에는 최대 2 mm 범위의 쥐는 변화와 작은 손목 회전을 더했습니다.
- 준비와 회수 궤적에 작은 곡선을 넣고, 접촉 뒤 카메라가 짧게 따라 움직이도록 했습니다. 원본의 소품 반응과 합성 충격음은 유지했습니다.

## 타이밍

30 fps 기준입니다. 원본 A 20프레임, B 28프레임을 유지했습니다.

| 동작 | 시작 | 준비 | 내려침 | 접촉 유지 | 복귀 | 전체 |
|---|---:|---:|---:|---:|---:|---:|
| 첫 B | 1.0초 | 8f | 3f | 4f | 13f | 28f / 0.933초 |
| 이후 A | 3.2초 | 6f | 3f | 2f | 9f | 20f / 0.667초 |
| 이후 A | 5.4초 | 6f | 3f | 2f | 9f | 20f / 0.667초 |

영상 길이는 8초이고 접촉 프레임은 41 / 105 / 171입니다. 각 접촉 시점에 같은 충격음이 들어갑니다. 수치는 제작 제안값이며 다른 게임에서 추출하지 않았습니다.

## 파일

- `renders/motion-sequence-v2.mp4`: 연속 모션 영상, 960×540, 30 fps.
- `renders/intro-lift.png`, `intro-contact.png`, `intro-recover.png`: 첫 B의 대표 프레임.
- `renders/repeat-lift.png`, `repeat-contact.png`, `repeat-recover.png`: 반복 A의 대표 프레임.
- `renders/motion-study-v2-manifest.json`: 타이밍·변경점·제작 방식·제한사항.
- `renders/verification.json`: 실제 검사 결과.

## 실행과 렌더

Godot 4.7.2에서 `project.godot`을 열면 자동 순서가 반복됩니다. Python 3와 FFmpeg가 있으면 아래 명령으로 PNG와 MP4를 다시 만듭니다.

```sh
python3 render_study.py --godot /path/to/godot
```

Linux에서 화면 서버가 없다면 동봉한 도구에 Xvfb 의존성 경로를 지정합니다.

```sh
python3 render_study.py --godot /path/to/godot --display-runner tools/with_display.py --xvfb /path/to/Xvfb --xauth /path/to/xauth --library-dir /path/to/x11/libs
```

기존 PNG에서 인코딩만 다시 하려면 `--skip-render`를 사용합니다. 실제 프로젝트 창에는 오디오가 재생되지 않으며, MP4 인코딩 때 합성 충격음을 추가합니다.

## 검증 범위와 한계

Godot import/parse, headless smoke, 실제 Linux OpenGL 프레임과 MP4 전체 디코딩을 확인했습니다. 독립 검토에서도 준비·접촉·회수의 팔 연결과 접촉 전후 소품 반응, B→A→A 표시 순서를 확인했습니다. 손·팔은 절차적 메시와 자세 보간으로 만든 검토용 모델이며, 본 리깅이나 최종 게임 아트가 아닙니다. 주먹 조이기는 작은 형태 변화이며 손가락 관절의 실제 굽힘을 구현한 것은 아닙니다. 소품 반응은 스크립트 응답입니다. 플레이 입력감, NPC 반응, Windows 실행이나 목표 PC 성능은 이 자료에서 검증하지 않습니다.

장면과 모션·효과음은 원본 제작물입니다. UI 폰트는 Nanum Gothic이고 라이선스는 `assets/OFL.txt`에 있습니다. 기존 `motion-study`와 `desk-breaker`의 코드에는 이 수정 사항을 적용하지 않았습니다.
