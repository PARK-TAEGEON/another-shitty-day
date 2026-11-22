# 김부장 손 외형 검수

기준은 [외형 실험 01](../boss_kim_atelier)의 커밋 `2a3dad6`이다. 모델의 왼손은 늘어뜨리고 오른손은 허리에 얹었다.

[Blender 원본](boss_kim_hands.blend) · [늘어뜨린 손 비교](relaxed_comparison.jpg) · [허리에 얹은 손 비교](hip_comparison.jpg) · [재킷 접점 비교](waist_context_comparison.jpg) · [전신 비교](body_comparison.jpg)

## 손 확대에서 발견한 문제와 수정

- 기존 손바닥의 아래 단면이 수평으로 끊기고, 손가락 네 개가 단면에 따로 붙어 보였다. 엄지 몸통과 손바닥 경계에도 깊은 틈이 있었다. 손목 단면에서 시작해 손바닥의 중앙 오목면·엄지 두덩·새끼손가락 쪽 두덩을 만들고, 손가락과 엄지를 한 피부 메시로 결합했다.
- 늘어뜨린 손을 먼저 렌더했다. 중지가 가장 길고, 약지와 소지는 더 일찍 굽는다. 손허리뼈 머리를 따라 손가락의 시작 높이를 달리하고, 마디마다 굵기와 굽힘을 조절했다. 손톱판은 마지막 마디의 피부 곡면에 밀착시켰다.
- 허리 쪽 손에는 같은 손바닥 형상을 사용했다. 손 전체의 위치와 방향, 각 손가락의 벌어짐·굽힘을 바꿨다. 처음 배치했을 때 겹친 주머니 덮개와 손바닥은 재킷의 실제 표면에 맞춰 간격을 조정했다. 최종 정적 자세에서 재킷·주머니 표면이 있는 구간의 피부 정점을 바깥쪽 측면 축으로 검사했을 때 최소 간격은 약 1.3mm였다. 실제 접촉에 의한 옷감 변형은 이번 실험 범위 밖이다.

## 검증

확대판은 손바닥, 손등, 새끼손가락 쪽 옆면, 엄지 쪽 순서다. 각 열에서 수정 전후의 카메라 위치·방향·직교 배율, 조명, 노출을 동일하게 고정했다. 손바닥을 가리는 몸통은 손 확대에서 숨겼고 소매와 커프스는 함께 표시했다. 허리 접점과 전신 렌더에서는 몸 전체가 보인다.

같은 소매 끝 기준점에서 가장 먼 손 표면까지 거리를 측정했다. 늘어뜨린 손은 19.49cm에서 19.59cm, 허리 쪽 손은 19.80cm에서 19.78cm가 됐다. 손을 제외한 128개 메시(스튜디오 포함)의 평가 정점, 면의 정점 연결 순서, 월드 변환, 재질 슬롯 이름을 대조해 일치를 확인했다. 기존 카메라와 조명의 배치·설정도 대조했다. 저장한 결과를 다시 열어 Blender Cycles에서 검수 이미지를 렌더했다. Armature 0개, Action 0개다.

## 재생성

Blender 4.3.2에서 이 폴더를 기준으로 실행한다.

```bash
blender -b ../boss_kim_atelier/boss_kim.blend --python-exit-code 1 --python refine_hands.py -- ./rebuilt.blend
blender -b ../boss_kim_atelier/boss_kim.blend --python-exit-code 1 --python render_comparison.py -- ./before
blender -b ./rebuilt.blend --python-exit-code 1 --python render_comparison.py -- ./after
```
