# 프로젝트 시작점 / 실제 현재 상태

기준일 **2026-10-12**, 게임은 **v0.2.2 소스 스냅샷**이다. 이 저장소 구성 작업으로 게임 실행 코드에 새 애니메이션·래그돌·모델을 추가하지 않았다.

| 범주 | 실제 상태 | 참고 |
|---|---|---|
| 1인칭 샷건·주먹·발차기·집기·던지기 | 구현 (v0.2.2) | `game/` |
| 같은 부서 5명 중 여성 2명 | 구현 (기존 절차적 3D 모델) | `docs/current-status.md` |
| 동료 놀람·상사 빼꼼/짧은 경로/잔소리 | 수용 및 기존 구현 | `docs/decisions.md` |
| 누적 피해액 달러 HUD, 경비·경찰 | 구현 | `docs/game-spec.md` |
| 5인 얄미운 풍자 만화형 라인업 | 사용자 수용 아트 시안, **게임 미적용** | `art/references/approved/` |
| 김 팀장 정면·측면·후면·표정 시트 | v1 **참고 시안**만 존재 | `art/references/concept-wip/` |
| 정교한 직교 A포즈 작업 설계도 v2 | 미제작 | `docs/art/BOSS-KIM-V2-MODEL-SPEC.md` |
| Blender 게임용 캐릭터 `.blend/.glb`, 리그 | 미제작 | `blender/README.md` |
| 피격·래그돌·물리 복귀 및 환경 충돌 | 이번 신규 설계, **미구현** | `docs/animation-ragdoll/HYBRID-RAGDOLL.md` |
| 사무실 3가지 구조의 실제 적용 | 미선택·미구현, 설계도 3안만 | `docs/design/office-layout-options.json` |
| GitHub 원격 저장소 | 미생성 | `docs/GITHUB-SETUP.md` |

**우선순위:** 새 게임플레이를 늘리지 말고, 김 팀장 원형의 몸체·표정·관절·물리 반응부터 일관된 품질로 구현한다. 현재 빌드의 첫 책상 내려치기와 인물 반응을 망가뜨리지 않는다.

## 보존된 유산

- 원 소스의 전체 문서·검증 기록은 `docs/`에서 보존했다.
- `studies/desk-slam/`은 독립 모션 연구 세 벌을 포함하며 실행 중인 `game/`과 별개다.
- 이전 실사풍 옵션과 초기 5인 라인업은 `art/references/exploration/`에 저장했으나 **제작 기준으로 사용하지 않는다.**
