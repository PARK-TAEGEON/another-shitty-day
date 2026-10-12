# Blender 작업 공간 (미제작)

현재 모델용 `.blend` 및 `.glb` 파일은 **없다.** 이 폴더는 작업 규격과 향후 저장 위치를 정의한다.

1. `docs/art/BOSS-KIM-V2-MODEL-SPEC.md`의 A포즈 직교 참고판 제작.
2. **메시**: Boss_Kim의 얼굴, 몸통, 배, 의상, 팔·손을 스타일에 맞게 연결.
3. **리깅**: 공통 이름의 휴머노이드 Armature, 스킨 웨이트, 표정/눈썹/턱 애니메이션.
4. **모션**: idle, walk, peek, admonish, hit_light, stagger, sit/fall response.
5. **내보내기**: 모델·스켈레톤·애니메이션을 glTF 2.0 `.glb`로; 텍스처/머티리얼을 문서화.
6. **Godot 적용**: 임시 테스트장에 import한 뒤 인체 변형·스케일·좌우·피격 물리 확인.

추천 이름 `blender/characters/boss_kim/boss_kim.blend`, `game/assets/characters/boss_kim.glb`. 실제 만들어진 뒤 커밋한다. 적용 전에는 v0.2.2 코드의 절차적 캐릭터를 보존한다.
