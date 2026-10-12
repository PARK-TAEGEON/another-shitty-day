# Desk-slam timing study

이 폴더는 기존 게임과 분리된 **3D 타이밍 비교용 프로젝트**입니다. 최종 손 모델, 완성된 캐릭터 애니메이션 또는 새 게임 빌드가 아닙니다.

## 비교 조건

동일한 손·셔츠·책상·카메라·조명·소품 반응·충격음을 사용합니다. 30 fps 기준으로 입력 시작은 1.0 / 3.2 / 5.4초에 고정했습니다. 각 영상은 8초입니다.

| 단계 | A 빠른 동작 | B 무게를 더 남기는 동작 |
|---|---:|---:|
| 준비 | 6프레임 / 0.200초 | 8프레임 / 0.267초 |
| 내려침 | 3프레임 / 0.100초 | 3프레임 / 0.100초 |
| 접촉 유지 | 2프레임 / 0.067초 | 4프레임 / 0.133초 |
| 복귀 | 9프레임 / 0.300초 | 13프레임 / 0.433초 |
| 전체 | 20프레임 / 0.667초 | 28프레임 / 0.933초 |

수치는 이번 비교를 위해 자체 제안한 값입니다. 참고 게임에서 측정하거나 추출하지 않았습니다. 입력에 해당하는 준비 동작 시작은 동일하고 B의 접촉은 A보다 약 0.067초 뒤입니다.

## 결과물

- `renders/motion-a.mp4`: A 단독, 가운데 충격음.
- `renders/motion-b.mp4`: B 단독, 동일한 충격음과 음량.
- `renders/motion-comparison.mp4`: 두 영상을 같은 시간으로 나란히 비교. A 소리는 왼쪽, B 소리는 오른쪽입니다.
- `renders/motion-study-manifest.json`: 실제 프레임·시간, 제작 방식과 제한사항.
- `renders/rest.png`, `lift.png`, `contact-a.png`, `contact-b.png`: Godot에서 직접 캡처한 프레임.

## 실행

Godot 4.7.2에서 `project.godot`을 열면 A가 반복됩니다. 명령줄로 `godot --path . -- --variant=B`를 실행하면 B가 반복됩니다. 실행 중인 프로젝트의 소리는 재생하지 않고 MP4 인코딩 단계에서 동일한 합성 효과음을 접촉 프레임에 넣습니다.

일반 데스크톱에서 렌더하려면 Python 3, Godot 4.7.2, FFmpeg가 필요합니다.

```sh
python render_study.py --godot /path/to/godot
```

Linux CI에서는 동봉한 `tools/with_display.py`에 Xvfb·xauth 경로를 지정할 수 있습니다. `render_study.py --help`를 확인하세요. 이미 PNG를 렌더했으면 `--skip-render`로 인코딩만 다시 실행합니다.

```sh
python render_study.py --godot /path/to/godot --display-runner tools/with_display.py --xvfb /path/to/Xvfb --xauth /path/to/xauth --library-dir /path/to/x11/libs
```

## 제작 및 검증 범위

손·소매는 이 비교용으로 직접 만든 절차적 메시입니다. 모션은 자세 간 보간이며, 본 애니메이션과 리깅의 완성도가 검증된 것은 아닙니다. 소품의 흔들림도 같은 타이밍 비교 조건을 만들기 위한 스크립트 응답입니다. NPC 반응·입력감·게임 물리·Windows 실행을 검증하는 자료가 아닙니다.

텍스트는 Nanum Gothic을 사용합니다. 폰트 라이선스는 `assets/OFL.txt`에 있습니다.
