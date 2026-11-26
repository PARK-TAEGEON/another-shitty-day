# 박 대리 선택 모델

첫 책상 옆에서 타이핑하다가 “왜 그래?”라고 반응하는 박 대리 한 명에게 적용한다. 승인된 [5인 시트](../../../../../art/references/approved/five-staff-unlikable-approved.png)의 두 번째 인물을 기준으로 긴 턱, 기울어진 사각 안경, 옆으로 넘긴 머리, 마른 체형, 걷어 올린 푸른 셔츠 소매와 사원증을 제작했다.

[업무 중 비교](office-work.jpg) · [책상 소리에 놀란 순간](office-startle.jpg) · [피격 뒤 도주](office-move.jpg)

## 실행과 채택

```bash
godot --headless --path game --import
godot --path game -- --kim-v2 --park-v2
```

박 대리만 비교하려면 `--park-v2`를 단독으로 쓴다. `asd/characters/park_visual_v2_enabled`는 지정하지 않으면 false이고, `--park-legacy`가 우선해 원래 박 대리로 복귀한다. 김부장만 통합하려는 경우 [김부장 최종 커밋](https://github.com/PARK-TAEGEON/another-shitty-day/commit/d5b2ebbf3e07a17247df6bc4a391c2f7fd6b4f62)까지 채택하면 된다.

## 모델과 동작

[Blender 원본](../../../../../blender/submission/kim/park/park_office.blend)과 [런타임 GLB](../../../../../game/assets/rig_slice/park_office.glb)에 얼굴·안경·옷·신발과 관절 피벗을 넣었다. 편집 원본의 옷과 얼굴 부품은 분리돼 있고, GLB는 함께 움직이는 부품을 합친다. [어댑터](../../../../../game/scripts/characters/park_visual_adapter.gd)는 기존 NPC의 머리·넥타이와 좌우 상완·팔꿈치·허벅지·정강이·발을 담당하는 12개 제어 노드의 위치와 회전을 복사한다. 양쪽 눈·눈썹과 입은 기존 표정값으로 움직인다. 박 대리의 일상 동작과 쓰러짐은 기존 NPC 제어기가 구동한다. GLB에는 별도 동작 클립이나 스킨 골격이 없다.

[본편 회귀 측정](verification.json)에서 7가지 모델 선택·재시작 조합과 기존 회귀 12건이 통과했다. 같은 사무실에서 박 대리의 평소·놀란 표정은 두 모델 모두 눈 높이 0.52→1.00, 입 열림 0.20→0.82였고 고개가 약 60° 돌아갔다. 박 대리는 오프닝 동안 원래 자리에서 반응했고, 이후 위협을 받은 실행에서 기존 AI가 4.32m 이동했다. 해당 측정은 Godot 4.7.2·Jolt·Linux에서 수행했다. Windows Desktop 프리셋의 PCK를 Linux Godot에서 단독 실행해 김부장 50본과 박 대리 GLB 12개 동작 제어가 함께 로드되는 것도 확인했다.

놀람 자세에서는 플레이어 책상 쪽 손이 상판에 걸쳐 손끝 일부가 위로 보인다. 같은 카메라로 기존 모델에서도 관찰되는 겹침이다. 모델별 비교 화면은 업무·놀람·이동 시점과 촬영 입력을 맞췄다.

```bash
blender -b --python-exit-code 1 --python blender/submission/kim/park/build.py
godot --headless --path game --fixed-fps 60 --script res://rig_slice/park_submission_verify.gd -- --kim-v2 --park-v2
```

실제 사무실 비교 화면은 디스플레이가 연결된 상태에서 아래 두 번의 실행으로 다시 촬영할 수 있다. 각 실행은 같은 입력 순서로 업무·놀람·이동 원본 3장을 저장한다.

```bash
godot --path game --fixed-fps 30 --script res://rig_slice/park_submission_capture.gd -- --kim-v2 --park-legacy --park-frames=/tmp/park-office-legacy
godot --path game --fixed-fps 30 --script res://rig_slice/park_submission_capture.gd -- --kim-v2 --park-v2 --park-frames=/tmp/park-office-v2
```

최종 GLB의 SHA-256은 `97fda35bdee16d68ef82909a570268e7a4f0d1ff28d58bc13367f14cdcf255b3`이며 18개 메시·28개 재질·64,084개 삼각형을 사용한다. Blender 4.3.2에서 제작 스크립트로 다시 만든 GLB와 비교해 정점·노멀·UV·삼각형의 방향과 구성이 일치했다. 벨트 메시의 두 재질에서 삼각형 저장 순서가 달라 파일 해시는 다르다.

## 추가 커밋의 파일

| 용도 | 경로 |
|---|---|
| 편집 원본과 제작 | `blender/submission/kim/park/park_office.blend`, `build.py`, `face.py` |
| 게임용 모델 | `game/assets/rig_slice/park_office.glb`와 `.glb.import` |
| NPC 선택·연결 | `game/scripts/office_npc.gd`, `game/scripts/characters/park_visual_adapter.gd`와 `.uid` |
| 본편 검사·캡처 | `game/rig_slice/park_submission_verify.gd`, `game/rig_slice/park_submission_capture.gd`와 각 `.uid` |
| 증거 | 이 폴더의 결과 JSON·비교 화면·작업 설명 |
