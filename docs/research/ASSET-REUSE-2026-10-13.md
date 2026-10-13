# Another Shitty Day: 외부 에셋 재사용 실사 조사 및 통합 실험 규격

- 조사일: 2026-10-13 (KST)
- 비교 기준: GitHub main dcc6db7810ebf065f49ad23d4b037da5fa754302, v0.2.2 스냅샷
- 문서 상태: RESEARCH / PROPOSED. 초안 조사 이후 **별도 GitHub Actions 실측 E0(46/46 모션)과 E1(15/15 래그돌)이 통과**했다. 자세한 실제 검증 결과는 [기술 검증 기록](ASSET-TECH-VERIFICATION-2026-10-13.md)에 보존했다.
- 원칙: 게임 본체는 변경하지 않는다. 무료/CC0 우선, 사용자 검수는 핵심 아트와 타격감 단계에 집중.
- 별도 승인 없는 에셋 구매, main 병합, 코드 라이선스 변경, 원본 게임 기능 재설계 금지.

## 1. 기존 작업 중복 제거 결과

| 요소 | 실제 보유 | 새로 하지 않을 일 | 새 조사 및 개발 필요 |
|---|---|---|---|
| 메인 루프 | game/ v0.2.2: 주먹, 발차기, 집기/던지기, 책상 첫 B/반복 A, 피해액/경비/경찰 | 타격 입력·판정·게임 규칙 재작성 | 새 외형과 효과를 기존 신호에 연결 |
| 등장인물 | 같은 부서 5명 + 타 부서 2명의 절차적 메시/행동 | 임시 3D 재구성부터 반복, 캐릭터 숫자 확장 | 몸체 메시·리그·표정 |
| 시각 목표 | art/references/approved/five-staff-unlikable-approved.png | 직원 5명 캐릭터 재디자인 | 김 팀장 v2 직교 A포즈 및 최종 메시 |
| 리깅 | Blender .blend/.glb와 리그 없음; docs/art/BOSS-KIM-V2-MODEL-SPEC.md만 있음 | 이미 제작됐다고 보고 | 최초 1명 제작·변형 시험 |
| 래그돌 | docs/animation-ragdoll/HYBRID-RAGDOLL.md 설계만 있음 | 물리 시스템을 다시 기획 | 실제 PhysicalBone3D 테스트장 |
| 피격 | office_npc.gd는 CharacterBody3D, 사망/넉다운 시 박스 충돌체 및 몸 전체 옆으로 회전 | 기존 회계를 지우거나 중복 사건 추가 | 강한 타격의 진짜 골격 물리 전환 |
| 사무실 | 코드 생성된 책상·의자·8종 파손 집기; 3가지 맵 구조는 도면 단계 | 사무실 전체를 새 에셋 맵으로 교체 | 고정 외형 일부 품질 업그레이드 |
| 음향 | 코드 합성 자체 효과음 | 기존 B/A 모션 음향 전면 폐기 | 추가 CC0 충격 레이어 |
| 도구 | Godot 4.7.2, Compatibility 렌더링, 내장 Jolt Physics, 60 physics ticks | 물리 플러그인·렌더러 교체부터 착수 | Jolt 관절 동작/성능 직접 시험 |

관련 기존 문서: README.md, docs/START-HERE.md, docs/DECISIONS-2026-10-12.md, docs/ROADMAP-AND-GATES.md, docs/assets.md, docs/art/ART-BIBLE.md, docs/art-quality-plan.md. 해당 문서를 대체하지 않는다.

주의: 일부 기존 안내문에는 GitHub 원격 저장소가 없다고 적혔지만 현재는 private 저장소가 생성돼 있다. 과거 기록임을 구분한다.

## 2. 검증된 외부 후보 및 채택 우선순위

외부 배포 페이지의 명시적 라이선스·배포 형식·가격만 확인했다. 실제 Godot 4.7.2의 프로젝트별 로드·시각·성능 합격을 의미하지 않는다.

| 우선 | 후보 / 공식 페이지 | 가격 및 권리 표기 | 확인된 내용 | 사용 방침 / 리스크 |
|---|---|---|---|---|
| P0 | Quaternius Universal Animation Library: https://quaternius.itch.io/universal-animation-library | Standard 무료, CC0 1.0; Pro $9.99; Source $14.99 | Standard 15MB; Pro 41MB; Source 46MB (2026-09-16 갱신). full line 120+ 모션, Godot GLB/휴머노이드 지원; free에는 일부만 포함 | Standard 모션 2~3종으로 보행/밀기 시험. 전체 120+가 무료라고 오해하지 말 것. root motion 없는 파일 먼저 사용 |
| P0 | Quaternius Universal Base Characters: https://quaternius.itch.io/universal-base-characters | Standard 무료, CC0 1.0; Source $19.99 | 6가지 휴머노이드 비율, 20 헤어, 범용 리그; 무료 Standard 122MB | 리그/리타게팅 실험용 대역. 승인된 5인 캐릭터의 최종 외형으로 사용 금지 |
| P0 | Godot Foundation Ragdoll Physics Demo: https://store.godotengine.org/asset/godot-foundation/ragdoll-physics-demo/ | 무료 MIT (원문에 명시); 2.66MB | 2026-07-08, 최소 Godot 4.7, PhysicalBone 적용·초기 충격·충돌음 샘플 | 엔진 내장 물리 기반 참조. Forward+ 전용 시각 효과/씬 전체 이식 금지. 배포판은 unstable 표시, 실제 검증 필요 |
| P1 | Kenney Furniture Kit: https://kenney.nl/assets/furniture-kit | 무료 CC0 | 140개 3D 가구, 2018년 공개 | 의자/선반 등 형태 맞는 정적 외형만 선별. 기존 집기 물리 몸체와 손상 판정 유지 |
| P1 | Kenney Impact Sounds: https://kenney.nl/assets/impact-sounds | 무료 CC0 | 130개 충격·폴리 음향 | 책상 충돌 및 바닥 착지 음향의 추가 레이어. 기존 게임 오디오 전체 삭제 금지 |
| P2 | Kay Lousberg Furniture Bits: https://kaylousberg.com/game-assets/furniture-bits | 무료 CC0 | 50+ 저폴리 모델, FBX/GLTF/OBJ, 단일 gradient atlas | Kenney에 맞는 모델이 부족할 때만 보조 후보 |
| P2 | Kenney Particle Pack: https://kenney.nl/assets/particle-pack | 무료 CC0 | 80개 2D VFX 스프라이트 | 서류 먼지·충돌 강조 후보. 물리 파편을 무분별하게 증식시키지 않음 |
| P2 | Simple Ragdoll Wizard: https://godotengine.org/asset-library/asset/5077 | 무료 MIT, Godot 4.6 대상으로 표시 | 2026-04-24 공개된 물리본 생성 보조 도구 | 기본 래그돌 수동 설정이 병목일 때만 분리 브랜치에서 비교. 처음부터 설치 불필요 |
| P3 | Omie's Assets Office Set: https://omies-assets.itch.io/omies-assets-office-set | 무료 선택 가능 / CC0 | 502MB FBX/Blender+2K PBR 텍스처, 파티션·컴퓨터·모니터·키보드 포함 | 다소 사실적이고 무겁다. 부족한 사무용 모델만 필요할 때 후순위 |
| HOLD | Adobe Mixamo: https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html | Adobe ID 무료, 상업 게임 로열티 프리 | 인간형만 자동 리깅 가능; 큰 비율 왜곡과 분리 메시에는 제약 | CC0가 아님. Quaternius로 필요한 동작을 충당하지 못할 때만 검토. 원본 동작 데이터 재배포 권한 별도 확인 후 사용 |

**공식 래그돌 데모 권리 예외:** Godot Foundation의 데모 프로젝트는 MIT로 게시돼 있지만 그 안의 `characters/mannequiny.glb`는 **GDQuest의 CC BY 4.0**이다. 확인 원문: https://github.com/godotengine/godot-demo-projects/blob/master/3d/ragdoll_physics/characters/mannequiny.LICENSE.md . E1은 이 모델을 임시 GitHub Actions 러너에서만 사용하며, `game/` 또는 저장소의 출시용 에셋으로 복제하지 않는다. MIT 표기만 믿고 모델을 자유 라이선스로 취급하지 않는다.

라이선스 지침: CC0는 통상 상업적 사용·수정에 별도 표시가 필요하지 않지만 출처 기록은 유지한다. MIT 코드를 가져오면 저작권/라이선스 고지를 동봉해야 한다. 저작자 배포 페이지의 라이선스가 최종 다운로드에 실린 파일 전부를 포괄하는지 외부 파일 도입 시 다시 확인한다. Mixamo는 상업적 게임 사용과 원본 데이터 재배포 허용이 같은 뜻이 아니다. 혼합 라이선스 파일을 무심코 오픈소스/공개 저장소에 커밋하지 않는다. 자세한 출처 등록 정책은 docs/assets.md 와 licenses/PROJECT-LICENSE-STATUS.md.

## 3. 기본 선택

- **당장 구매: 0원.** 무료 Quaternius UAL Standard + Base Characters Standard + Godot 공식 래그돌 데모를 기술 검증용으로, Kenney Furniture/Impact를 비주얼·음향 검증용으로 선정.
- **캐릭터 소유권: 승인된 원본 미술 시안 기준.** 외부 캐릭터는 리그 동작 테스트용이고 완성된 김 팀장의 대체품이 아니다.
- **물리: 기존 Jolt와 Godot PhysicalBoneSimulator3D/PhysicalBone3D 재사용.** 고유 플러그인이나 새 물리엔진 불필요.
- **기존 1인칭 손/책상 내려치기 유지.** 범용 애니메이션을 플레이어 손에 덮어씌우지 않는다.
- **사무실 맵 선택은 기존 미결정 상태 유지.** 어떤 구조 A/B/C도 임의로 채택하지 않는다.

## 4. 안전한 통합 경계 (구체적인 코드 진입점)

1. game/scripts/office_npc.gd: Actor의 CharacterBody3D 이동과 업무·대화·경비 상태/회계 시그널은 유지. 현재 _visual=CaricatureVisual 아래의 절차적 메시만 김 팀장부터 선택적 Skeleton3D/SkinnedMesh 시각 어댑터로 교체한다. 기능 플래그는 기본값 false로 두고 기존 원형을 보존한다.
2. 동작 번역 어댑터: 기존 _animate_pose, begin_boss_lecture_gesture, _advance_boss_gait 의 상태/시간 데이터를 AnimationTree 또는 AnimationPlayer의 리그 포즈로 매핑한다. 수용된 박 대리 놀람 → 김 팀장 빼꼼 → 접근 → 세 가지 잔소리 제스처의 순서와 중단 조건은 그대로 유지한다.
3. game/scripts/player.gd: _commit_hit_later에서 receive_hit(impulse, point, damage)를 부른다. 해당 인터페이스를 그대로 사용하며 카메라/손/판정 타이밍은 수정하지 않는다.
4. game/scripts/office_npc.gd receive_hit: 기존 체력/상해·업무중단·소동·피해액·KNOCKDOWN 신호는 단 한 번만 발생하게 둔다. 새 물리 어댑터는 다운 시 **시각/물리 반응**만 교체. 현행 다운 시 납작한 BoxShape3D와 몸 전체 90도 회전 처리와 새 PhysicalBone 시뮬레이션이 동시에 발생하지 않게 별도 가드가 필요하다.
5. Ragdoll 상호작용: Skeleton3D + PhysicalBoneSimulator3D + PhysicalBone3D는 기존 CharacterBody3D 캡슐 충돌과 독립 레이어를 사용한다. 피격 직전 포즈를 물리본에 전달하고 그 다음 impulse를 주며, 기존 NPC 캡슐이 몸을 다시 밀어내는 현상을 막는다. 장면 복귀는 실험에서만 하고 v1은 쓰러진 상태 유지도 허용한다.
6. game/scripts/prop.gd: 이미 RigidBody3D, 손상 단계, 누적 비용 및 한 번만 보고하는 충돌 가드를 가진다. 외형 갱신만 구현하고 기존 collision/mass/_on_body_entered 및 집기/던지기 판정을 보존한다. 시각 모델과 물리충돌 메시를 자동으로 동일시하지 않는다.
7. game/scripts/world.gd: _npc(...)에서 생성 및 신호 연결, _prop(...) 집기 생성, _build_furniture에서 공간 배치 유지. 새 구조/새 출동 동선/새 화폐 계산은 범위 제외.
8. Godot 4.x 리타게팅: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html 의 BoneMap + SkeletonProfileHumanoid를 우선 검토. 뼈대 이름만 같아도 rest pose가 다르면 실패할 수 있으므로 A포즈와 T포즈, 로컬 스케일, 루트 모션을 각각 테스트한다.
9. 렌더링: demo Forward+와 본편 Compatibility는 상이. 데모 쉐이더/윤곽선 효과를 무심코 이식하지 않는다. 정적 모델 재질은 무광·색 팔레트 기준으로 재작성 가능.
10. Jolt 관절 제한: https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html 의 미지원 soft limit 속성을 피하고 Hinge/ConeTwist hard angle부터 조정한다.

## 5. 첫 통합 이전의 실험 순서와 중단 조건

### E0: 에셋 적합성 벤치 (본편 미수정)
별도 research 브랜치/실험 폴더에서 무료 Quaternius humanoid 1종과 UAL Standard를 glTF/GLB로 읽는다. idle, walk, push/sit 중 다운로드 안에 **실제로 존재하는** 동작만 2~3개 선정한다. 걷기의 경우 **root motion 없는 버전**을 우선 사용해 기존 NPC 경로 이동과 중복 이동을 방지한다. import 오류, 뼈 이름/골반 높이, 접지, 손목/무릎 뒤집힘을 캡처한다.

합격: 캐릭터와 2종 이상의 모션을 깨진 뼈/재질 없이 재생, 지면 침몰과 이중 이동이 없는 장면 확보. 실패: FBX/GLB 포맷 및 BoneMap 교정 1회 뒤에도 접지·골격 어긋남 해결 안 되면 다른 리그 전략 검토.

### E1: 김 팀장 외형 제작 전 래그돌 기술 벤치
Godot 공식 MIT demo 물리본·임펄스 계산을 참고해 독립 테스트장 game/tests/ragdoll_lab.tscn 을 만든다(현재 없음). 무료 humanoid 테스트 모델로 정면·측면·후면을 타격하고, 바닥·의자·책상과 접촉시킨다. 기존 NPC와 유사한 Jolt 충돌 설정을 사용한다. 김 팀장 최종 아트가 없어도 기술 검증 가능하지만, 승인 시안의 체형을 반영한 물리본 재조정은 후속 필수다.

합격: 세 방향 각각 10회 반복해 캐릭터가 전혀 날아가지 않거나, 관절이 꺾여 뒤집히거나, 폭발적으로 흔들리는 실패가 없을 것. 가구 접촉을 통과하지 않을 것. 효과가 과장되되 현실적 고어로 흐르지 않을 것. 부하 상황의 프레임 저하는 별도 숫자로 기록.

### E2: 김 팀장 1명만 본편 시각 어댑터를 연결
docs/art/BOSS-KIM-V2-MODEL-SPEC.md 의 R1 아트 게이트를 거쳐 사용자 승인 비율을 반영한 Blender 메시/공통 골격을 제작한다. Blender .blend / .glb 의 바인드/웨이트 테스트를 통과한 후 본편의 _visual 부분을 기능 플래그로 치환한다. 기존 행동/회계 코드는 먼저 건드리지 않는다. 표정은 오버라이드해 눈꺼풀·눈썹·입 우선, 보행·빼꼼·잔소리는 기존 타이밍 우선으로 붙인다.

합격: 기존 통합 회귀(첫 B→반복 A, 박 대리 반응, 김 팀장 빼꼼/접근/세 대사/중단, 점수, 제압, 재시작)가 유지되고, 별도 15~20초 영상에서 실제 게임 카메라로 본 손/상사 비율 확인 가능. 실패 시 플래그를 끄면 즉시 v0.2.2 외형으로 돌아가야 한다.

### E3: 사무실 외형만 부분 대체
Kenney/Kay 모델 중 플레이 중 반복 노출되는 의자·서류함·컵 주변 3종을 우선 선별. 기존 씬 배치/물리 shape/가격 로직을 보존하며 일부만 교체한다. Kenney 효과음은 현재 합성 SFX에 레이어링하되 반복 주파수와 음량을 비교한다.

합격: 기존 prop 회귀 및 피해액 차액 계산과 3개 실제 비주얼 비교를 통과. 외부 소품 비율·재질이 NPC 미술 규칙과 충돌하면 미채택.

## 6. AI 자동 검증과 사람 검수 최소화

| 분류 | AI/테스트 담당 | 사람 판단 |
|---|---|---|
| 라이선스/출처 | URL, 원문, 파일 내 LICENSE, 다운로드 날짜, SHA-256 및 수정 기록을 Asset Ledger에 등록 | 구매나 권리 불명 요소 발생 시에만 |
| 리그/모션 | GLB import 로그; BoneMap; 2가지 포즈; 본/메시 변형 비교 이미지·비디오 | 원칙적으로 없음 |
| 래그돌 | 정면/측면/후면 반복 타격, 관절 충돌, 경비·NPC 다수 프레임과 카메라 포착 | 대표 15초 타격 영상의 재미만 |
| 게임 안정성 | scripts 회귀, 점수/업무 피해액 중복 없음, 초기화, 모션 종료 후 상태 검증, 60fps 목표 PC 측정 | 개발 내용 단계별 코드 검수 없음 |
| 아트 | 승인 콘셉트 ↔ 뷰포트 3방향/표정 검수 비교판 자동 제작 | 김 팀장 실루엣 1회, 최종 5인 1회 |
| 외부 공개 | 릴리스 패키지 에셋 고지 점검, 실제 Windows 네이티브 실행 | 출시 결정 최종 1회 |

성능 목표 60fps는 기존 설계 지향점이며 현재 보장하는 수치가 아니다. Windows 네이티브 테스트와 사람의 재미 판단은 자동/리눅스 headless 테스트로 대체하지 않는다.

## 7. 고비용/중복 후보 보류 결정

- 완성형 인물·사무실 팩을 통째로 교체하거나 전체 맵을 새로 생성하는 일은 현재 프로젝트의 미술·행동 자산을 훼손하므로 보류.
- Quaternius Source/Pro 구매, paid procedural animator, 유료 ragdoll add-on 도입 보류. E0/E1 실패나 확실한 작업량 절감이 확인되기 전에는 지출 불필요.
- Mixamo는 상업 사용은 가능하나 자유 라이선스(CC0)는 아니므로 기본 파이프라인에 포함하지 않는다.
- 대규모 502MB 실사풍 사무실 세트는 파일 크기·텍스처·화풍 맞춤 비용 때문에 P3.
- 애니메이션 라이브러리의 루트모션을 NPC CharacterBody3D 움직임과 동시에 켜지 않는다.
- 기존 표정/잔소리 동작을 기본 범용 동작으로 무조건 대체하지 않는다.

## 8. 첫 PR/개발 작업 완료 정의

연구 단계 완료: 이 문서가 기본 브랜치와 구별되는 초안 PR에 있고 외부 에셋 다운로드/구매/코드 변경은 없음.

후속 별도 구현 단계 완료: E0 무료 에셋 실제 다운로드→라이선스 고지 확인→E1 래그돌 테스트장의 Godot 4.7.2 import 및 반복 물리 시험→리포트와 재현 영상 공개(사유지 private 저장소)까지. E2/E3는 기술 증명과 R1 미술 게이트 이후 착수. **이미 구현된 것처럼 보고 금지.**

최소 사람 검수: 최종 김 팀장 외형(원 승인 시안과의 정면/측면 비교), 코믹 타격감(반복 영상) 2개만. 문제 없으면 나머지 단순 에셋 선정·라이선스·기술 회귀는 개발자가 처리.

## 9. 외부 공식 근거

- Quaternius UAL: https://quaternius.itch.io/universal-animation-library
- Quaternius Base Characters: https://quaternius.itch.io/universal-base-characters
- Godot Foundation 2026 Ragdoll demo: https://store.godotengine.org/asset/godot-foundation/ragdoll-physics-demo/
- Godot ragdoll guide: https://docs.godotengine.org/en/stable/tutorials/physics/ragdoll_system.html
- Godot retargeting: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- Godot Jolt notes: https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html
- Kenney Furniture Kit: https://kenney.nl/assets/furniture-kit
- Kenney Impact Sounds: https://kenney.nl/assets/impact-sounds
- Kay Lousberg Furniture Bits: https://kaylousberg.com/game-assets/furniture-bits
- Kenney Particle Pack: https://kenney.nl/assets/particle-pack
- Simple Ragdoll Wizard: https://godotengine.org/asset-library/asset/5077
- Omie's Office Set: https://omies-assets.itch.io/omies-assets-office-set
- Adobe Mixamo FAQ: https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html

## 10. 실제 기술 검증 결과 (추가 기록)

- E0 Godot 4.7.2 Compatibility: 무료 Quaternius Standard GLB 1개, Skeleton3D 1개, skinned mesh 1개, **46/46 재생**, 오류 0. [실행 기록](https://github.com/PARK-TAEGEON/another-shitty-day/actions/runs/38348850781)
- E1 Godot 4.7.2 Compatibility + Jolt: 공식 데모 골격(18 PhysicalBone3D)으로 전·측·후 5회씩 **15/15 안정성 기준 통과**, 위치/속도 비정상 0. [실행 기록](https://github.com/PARK-TAEGEON/another-shitty-day/actions/runs/38349124791)
- 이 통과는 **테스트 모델 기준의 headless 기술 증명**이며, 최종 김 팀장 외형/리타게팅/물리 복귀/물체 충돌/재미/FPS를 인증하지 않는다. [수치·로그·라이선스 예외 기록](ASSET-TECH-VERIFICATION-2026-10-13.md)을 참조.
