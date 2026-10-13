# Scenario Framework | v0.3 적용 규칙

**2026-10-13 현재 기준: [SCENARIO-V0.3-BASELINE.md](SCENARIO-V0.3-BASELINE.md).** 이전 프레임워크의 '시나리오당 특별 루트 한 개 + A/B 결과 + 완료/고득점 점수'는 폐기. [이전 내용](../archive/SCENARIO-FRAMEWORK-pre-v03.md)은 역사 기록.

## 시나리오별 필수 항목
1. 짜증나는 일상 도입과 NPC 성격, 짧은 대사·몸짓, 시작 소품/장소.
2. 자유로운 대표 첫 행동 및 직접 공격·투척·파손·무행동/이탈의 대체 반응.
3. 사건을 실제 인지한 NPC들의 연쇄 반응(행동·대사·시선·접근/회피), 인터럽트·우선순위·발화 횟수와 상태 초기화.
4. 경비·경찰의 실제 등장/경고를 목격한 인물만 태도 변환. 물리·신고·피해액은 공유 Core가 처리.
5. **고유 상호작용은 선택**: 하나의 시작 방망이 또는 사장 잡기 하나면 충분. A/B 엔딩, 루트 목표, 전용 완료 UI가 기본 요구가 아님.

## 골든 기준
첫 B/반복 A 책상 내려치기와 박 대리 놀람 → 김 팀장 빼꼼/항의/접근/잔소리, 5+2 배역과 손 방향·HUD는 보존. 첫 행동이 다른 경우 오래된 평온 대사를 재생하지 않음.

## 반응 데이터와 게임 코어
`beat_id, trigger/facts, actor/target/perception, priority, delay/TTL, behavior/dialogue, interrupt/fallback, once/reset/authority`를 최소 데이터로 사용. 기존 `round/event/root_action` 사건 계약·피해액 증가분·중복 방지 재사용. 실시간 피격/위험/제지 우선, 대사 예약은 필요 시 삭제.

## 점수 및 출시
기존 Social Damage($) 장부 유지; 별도 Chaos Score와 특별 루트 고득점은 Phase-P2 필수 **아님**. 경찰 최초 출동 짧은 시점 연출 유지(협동은 비차단). 회사원 사장 붙잡기 + 실제 경찰 반응/해제, 야구 방망이 보유 시작은 [v0.3](SCENARIO-V0.3-BASELINE.md) 참조. 미구현 항목을 VERIFIED로 표시하지 않는다.
