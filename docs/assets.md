# DESK BREAKER — 자산 출처

기록일: 2026-10-11. 현재는 v0.2.1 로컬 프로젝트이며 원격 저장소 생성·업로드는 보류 상태다.

## 한국어 UI 폰트

| 항목 | 기록 |
|---|---|
| 원본 이름 | NanumGothic Regular |
| 원본 파일 | `NanumGothic-Regular.ttf` |
| 프로젝트 파일 | `game/assets/fonts/KoreanUI.ttf` |
| Godot 경로 | `res://assets/fonts/KoreanUI.ttf` |
| 원본 저장소 | [Google Fonts — Nanum Gothic](https://github.com/google/fonts/tree/main/ofl/nanumgothic) |
| 다운로드 출처 | [공식 저장소의 TTF 원본](https://raw.githubusercontent.com/google/fonts/main/ofl/nanumgothic/NanumGothic-Regular.ttf) |
| 저작권 고지 | Copyright (c) 2010, NHN Corporation |
| 라이선스 | SIL Open Font License 1.1 |
| 라이선스 출처 | [공식 저장소의 OFL.txt](https://raw.githubusercontent.com/google/fonts/main/ofl/nanumgothic/OFL.txt) |
| 동봉 원문 | `game/assets/fonts/OFL.txt`, 배포용 사본 `licenses/NANUMGOTHIC-OFL.txt` |
| 수정 | 파일명만 변경. 글리프·내부 폰트 이름·메트릭은 변경하지 않음. 서브셋하지 않음 |
| 파일 크기 | 2,054,744바이트, 약 1.96MiB |
| SHA-256 | `76f45ef4a6bcff344c837c95a7dcc26e017e38b5846d5ae0cdcb5b86be2e2d31` |

폰트와 라이선스는 공식 Google Fonts 저장소에서 일반 HTTPS 다운로드로 확보했다. 다운로드한 폰트의 메타데이터가 NanumGothic / Regular이며, 현대 한글 음절 11,172자를 포함하는 것을 확인했다. 게임의 한국어 UI에 연결했으며, 실제 화면의 가독성은 플레이 검수에서 확인한다.

폰트를 포함해 배포할 때 위 저작권 고지와 OFL 원문을 함께 보존한다. 폰트의 라이선스는 프로젝트의 다른 코드·자산 라이선스와 구분한다.

## 모델·효과음·아이콘

| 자산 | 제작 방식 | 외부 원본 |
|---|---|---|
| 사무실·책상·의자·소품 | 프로젝트 코드에서 기본 3D 형태와 재질로 생성 | 외부 모델 팩 미사용 |
| NPC와 플레이어 손발 | 프로젝트 코드에서 단순한 형태와 동작을 생성 | 외부 캐릭터·애니메이션 팩 미사용 |
| 초기 타격·충돌 효과음 | 프로젝트 코드에서 합성하는 원본 효과음 | 외부 음원 미사용 |
| 프로젝트 아이콘 | 프로젝트용 SVG | 외부 아이콘 팩 미사용 |

이 목록은 제작 방식과 출처를 기록한다. 실제 표현 품질이나 재생 검증 완료를 뜻하지 않는다. 추후 외부 자산을 채택하면 출처·라이선스·변경·적용 경로를 이 문서에 추가한다.

### v0.1.1 첫 반응 장면의 제작 자산

- `game/scripts/office_npc.gd`: 기준 시안(D012)을 참고해 프로젝트 코드에서 만든 얼굴·체형·눈·눈썹·안경·넥타이와 관절별 자세. 상사와 동료는 절차적 3D 첫 제작본이며 외부 캐릭터 팩이나 Blender 모델을 사용하지 않았다.
- `game/scripts/hand_model.gd`: 같은 프로젝트의 독립 모션 스터디 v3 원본 손 기하를 수정 없이 이식했다. 실제 왼손·오른손의 엄지와 바깥으로 굽는 소매를 유지한다. 적용 위치와 균일 배율, B/A 타이밍·판정 연결은 `player.gd`가 소유한다.
- 상사·동료의 세 대사는 사용자가 지정한 문장이다. 이 버전의 전달 방식은 자막이며 음성 녹음·TTS 음원을 추가하지 않았다.
- `docs/preview/opening-*.png`와 검수 영상은 실제 Godot 장면의 촬영 결과다. 기준 콘셉트 이미지와 제작·생성 방식을 구분한다.

### v0.2.1 외형·구조도·검수 화면

- 캐릭터 외형 보강은 `game/scripts/office_npc.gd`의 프로젝트 원본 절차적 메시를 편집했다. 얼굴 윤곽·눈꺼풀·코·헤어·의상 구조를 변경했으며 새 외부 모델·텍스처·애니메이션은 없다.
- `docs/preview/characters-refresh-*.png`는 `tools/capture_character_lineup.gd`가 실제 게임 모델을 고정 카메라·조명에서 렌더한 결과다. 얼굴 비교판은 렌더를 나란히 배치하고 이름을 붙인 검수 이미지이며 AI가 새로 그린 콘셉트가 아니다.
- `docs/preview/ui-refresh-*.png`는 실제 Godot UI 촬영이다. `tools/capture_ui_refresh.gd`에서 실제 F 입력과 설정/조작법 전환을 사용한다. 결과 스틸만 UI 검수 목적으로 종료 함수를 호출한다.
- `docs/design/office-layout-options.json`과 `tools/draw_office_layouts.py`는 이번 비교를 위해 만든 좌표 설계와 도면 코드다. `docs/preview/office-layout-*.png`는 그 좌표를 그린 2D 도면이며 실제 게임 맵이나 생성형 이미지가 아니다.

## 채택한 외형 콘셉트 이미지

| 항목 | 기록 |
|---|---|
| 이름 | 풍자 만화형 · 외형 시안 |
| 생성 방식 | 프로젝트 요청으로 ChatGPT의 기본 이미지 생성 기능을 사용한 AI 콘셉트 |
| 생성·사용자 채택일 | 2026-10-11 |
| 프로젝트 파일 | [office-caricature-approved.png](../art/references/office-caricature-approved.png) |
| 원본 식별 | `generated_images/exec-10bf5450-06c5-415d-8220-cf3624138611.png` |
| 수정 | 채택한 원본의 바이트를 그대로 복사. 재생성·자르기·색 보정 없음 |
| 용도 | 후속 캐릭터·플레이어 손·사무실의 미술 제작 기준. 현재 게임의 런타임 모델이나 실제 플레이 화면은 아님 |
| 파일 사양 | PNG, 1672 × 941, 1,804,624바이트 |
| SHA-256 | `d2bca9e3b29ea92a66118eb8d9e2418381e3932623b7f566af786d6e54953f2d` |
| 제작 기록 | [생성·채택 메타데이터](../art/references/office-caricature-approved.json), [D012](decisions.md), [캐릭터 제작 기준](character-production.md) |

이 기록은 생성 경위와 사용 목적을 나타낸다. 함께 동봉한 폰트·Godot의 라이선스는 해당 자산에만 적용된다.

## Godot 런타임

Godot 4.7.2-stable 공식 소스의 `LICENSE.txt`와 `COPYRIGHT.txt`를 수정 없이 확보해 `licenses/`에 동봉했다. 원본 URL·저장 경로·해시는 [라이선스 출처](../licenses/SOURCES.md)에 기록한다.
