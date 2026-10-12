# Another Shitty Day (working title)

> 풍자 만화형 직장인들이 일하는 사무실에서 시작하는 1인칭 3D 물리 블랙코미디.

**기존 프로젝트명:** DESK BREAKER  
**현재 플레이 가능한 소스:** Godot `v0.2.2` (이 저장소에 코드 그대로 보존)  
**다음 목표:** 김 팀장 3D 제작 기준 v2 → Blender 리깅 → Godot 하이브리드 피격·래그돌 검증

![승인된 직원 5인 외형 콘셉트](art/references/approved/five-staff-unlikable-approved.png)

> **중요:** 이 이미지는 승인된 **목표 아트**다. 현재 게임 속 모델이 이미지처럼 완성됐다는 뜻이 아니다. 승인된 새 5인 외형과 김 팀장 v1 시트, 래그돌 시스템은 현재 v0.2.2 게임에 적용되지 않았다.

## 먼저 읽을 문서

| 용도 | 문서 |
|---|---|
| 지금 작동하는 것과 미완료 | [현재 개발 상태](docs/START-HERE.md) · [기존 v0.2.2 상태 기록](docs/current-status.md) |
| 확정한 캐릭터/게임 결정 | [확정·미결정 사항](docs/DECISIONS-2026-10-12.md) |
| 모델링 비주얼 목표 | [아트 바이블](docs/art/ART-BIBLE.md) · [레퍼런스 등록부](docs/art/REFERENCE-MANIFEST.md) |
| 김 팀장 v2 정식 작업 지시 | [캐릭터 v2 설계 기준](docs/art/BOSS-KIM-V2-MODEL-SPEC.md) |
| 피격, 날아감, 넘어짐 구현 | [애니메이션·래그돌 설계](docs/animation-ragdoll/HYBRID-RAGDOLL.md) |
| 실제 작업 순서 및 사용자 검수 | [로드맵과 품질 게이트](docs/ROADMAP-AND-GATES.md) |
| AI/에이전트 실행 규칙 | [AGENTS.md](AGENTS.md) |
| GitHub 연결 | [원격 저장소 설정](docs/GITHUB-SETUP.md) |

## 지금 게임에 있는 것 (v0.2.2)

- **한 부서 5명:** 김 팀장·박 대리·이 사원(여성)·최 과장·정 인턴(여성), 플레이어는 별도.
- **타 부서 2명**, 평소 업무·놀람·구경·겁먹음·회피와 경비의 짧은 경고·실제 제지, 후속 경찰 개입.
- 책상 양손 내려치기 **처음 B(묵직) / 반복 A(빠름)**, 주먹질·발차기·집기·던지기.
- 책상 충격 → 박 대리 “왜 그래?” → 김 팀장 가림막 빼꼼 → “뭐야 무슨 소리야?” → “이게 무슨 짓이지?” → 접근·잔소리.
- 화면 좌상단 **누적 피해액 $**, NPC 대사 자막, Esc 안의 설정/조작법.
- 물건 손상·피해액 누적·경비/경찰·제압·재시작.
- 사무실 구조 A(밀집)·B(중앙 복도)·C(순환)는 **비교 도면만 있음**. 실제 맵 교체는 미완료.

## 실행과 검사

프로젝트는 `game/project.godot`에 있다. 제작 당시 기준 엔진은 **Godot 4.7.2**이며 원본의 스크립트/리소스를 그대로 보존한다. 이 정리 작업에서는 Godot을 다시 실행하지 않았으므로 새 테스트 통과를 주장하지 않는다.

```sh
godot --path game
godot --headless --path game --editor --import
godot --headless --path game -- --smoke-test
```

Windows PowerShell 도우미: `tools/run.ps1`, `tools/test.ps1`, `tools/build.ps1`. 빌드에는 같은 버전의 Godot과 export templates가 필요하다. Windows 실행 파일은 기존 배포 ZIP에서 받을 수 있으며, **저장소에는 바이너리 배포본을 넣지 않는다.**

## 파일 구조

```text
game/                실제 Godot 게임 (기존 코드·씬 유지)
art/references/      사용자 승인/검토 중/폐기 시안 구분
blender/             향후 모델/리그 작업 규칙, 아직 .blend 없음
studies/desk-slam/   내려치기 A/B 모션 연구 (독립 Godot 스터디)
docs/                게임 설계, 아트, QA, 검증 로그, 진행 기록
tools/               기존 실행·테스트·빌드 보조 도구
licenses/            사용된 엔진·폰트의 제3자 라이선스
.github/             향후 Issue/PR 템플릿
```

## 변경·권리 상태

- 이 저장소의 **기본 Git 커밋은 v0.2.2 ZIP에서 재구성한 스냅샷**이다. 원 소스에 적힌 과거 커밋 SHA를 실제 Git 이력으로 복원한 것은 아니다. [원본 확인](docs/IMPORT-PROVENANCE.md)
- 승인된 외형 시안은 게임용 메시/리그가 아닌 이미지 자료다.
- 게임 코드의 공개·상업 재배포 라이선스는 아직 정하지 않았다. 외부 에셋의 권리·출처는 개별로 기록한다. [권리 및 배포 정책](licenses/PROJECT-LICENSE-STATUS.md)
- 현재 **GitHub 원격 저장소는 미생성**이다. 이 로컬 저장소에서 초기 Git 커밋을 만들고 업로드 지침을 준비했다. 빈 비공개 GitHub 저장소를 만든 후 push하면 된다.