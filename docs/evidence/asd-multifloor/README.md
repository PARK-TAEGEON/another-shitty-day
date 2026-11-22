# ASD 사무실 다층 v1 실행 증거

Godot 4.7.2의 실제 메인 씬을 Linux에서 OpenGL Compatibility와 Jolt Physics로 실행했다. 영상은 이동 키와 E를 입력하는 자동 재생으로 녹화했다.

| 증거 | 장면 |
| --- | --- |
| [층간 왕복 영상](floor-round-trip.mp4) | 20.6초. 1층 시작 지점에서 걸어서 엘리베이터 진입, 2층 사장 붙잡기·이동·해제, 1층 복귀 |
| [2층 사장실](executive-office.jpg) | 2층 복도에서 걸어서 도달한 사장실과 기본 배치 |
| [1층 오프닝](office-opening.jpg) | 책상 타격 뒤 원래 구도에서 가림막 너머로 등장하는 김 팀장 |
| [2층 타격](executive-kick.jpg) | 사장실에서 피격 전 상대 위치를 잡은 뒤 실제 Q 입력으로 발생한 넉백과 피해액 |

엘리베이터 고정 도착 좌표는 1층 `(6.65, 0.08, -1.60)`, 2층 `(6.65, 4.68, -1.60)`이다. 동일한 E를 사용하며 사장을 붙잡은 중에는 첫 E가 해제만 처리한다. 합류 중인 경비·경찰은 현재 층의 엘리베이터로 걸어가고, 5초 안에 도착하지 못하면 같은 인원이 플레이어 층의 빈 출동 지점에 합류한다.

헤드리스 재현은 저장소 루트에서 실행한다.

```powershell
./tools/test.ps1 -GodotPath <Godot>
./tools/test-scenario.ps1 -GodotPath <Godot> -IncludeLegacyChaos
./tools/test-kim-integration.ps1 -GodotPath <Godot>
```
