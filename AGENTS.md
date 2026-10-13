# Another Shitty Day — 에이전트 개발 원칙

작업 시작 전 반드시 다음 순서로 읽는다: `docs/START-HERE.md` → `docs/DECISIONS-2026-10-12.md` → `docs/DECISIONS-2026-10-13.md` → `docs/design/SCENARIO-FRAMEWORK.md` → `docs/ROADMAP-AND-GATES.md` → 관련 폴더의 상세 설계.

1. **안정된 게임 보존:** 기준 게임은 `game/`의 v0.2.2. 아트 이미지/래그돌 문서를 넣었다고 구현된 것으로 쓰지 않는다. 큰 리팩터링은 별도 브랜치에서 한다.
2. **수용 장면 보호:** 박 대리의 놀람과 구도, 김 팀장 빼꼼/가까운 접근/대사/잔소리, 첫 B→반복 A, 왼손·오른손 방향, 5인 부서 및 2인 타 부서 유지.
3. **그래픽 목표:** `art/references/approved/five-staff-unlikable-approved.png`가 최신 5인 기준. 실사풍, 귀여운 아동형, 잔혹한 물리 고어로 회귀하지 않는다.
4. **재사용 골격:** 김 팀장의 Blender A포즈·Armature·변형 테스트·Godot 래그돌 테스트를 통과한 뒤 나머지 인물로 확장한다.
5. **시각 검증 필수:** `godot --headless` 통과는 화면 품질이나 타격감 검증이 아니다. 실제 장면·프레임·Windows 목표 PC 테스트를 분리 기록한다.
6. **상태 구분:** IMPLEMENTED / VERIFIED / APPROVED CONCEPT / PROPOSED / BLOCKED 를 엄격히 구분한다. 사용자 승인 없는 설계 가정은 PROPOSED로 남긴다.
7. **작업 소유:** 메인 통합 에이전트 하나가 코드를 병합하고, 여러 에이전트가 같은 파일을 병렬 수정하지 않는다. 각 작업은 변경 범위·검사 결과·남은 문제를 남긴다.
8. **권리/보안:** 라이선스 확인되지 않은 외부 모델을 게임에 넣지 않는다. 토큰, 개인정보, 큰 빌드 바이너리, `.godot/` 캐시를 커밋하지 않는다. 외부 배포와 공개 전환은 사용자의 별도 결정이 필요하다.
9. **GitHub:** 원격 `PARK-TAEGEON/another-shitty-day`가 연결되어 있다. 변경은 실제 파일·커밋 결과로 확인하며, 큰 게임 코드 변경은 브랜치/PR로 분리한다.

10. **시나리오 설계:** 2026-10-13 승인 방향은 `docs/DECISIONS-2026-10-13.md`가 기준이다. 각 시나리오에 평상시 마찰/대표 첫 행동/전용 NPC 반응/폴백/선택형 특별 루트를 설계한다. 원본 책상 내려치기 장면과 기존 누적 피해액($) 장부를 보호한다. 장기 구상을 IMPLEMENTED로 표시하지 않는다.

기존 v0.2.2 가이드는 `docs/archive/AGENTS-v0.2.2.md`에 보존했다.
