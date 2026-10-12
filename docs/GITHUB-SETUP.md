# GitHub 비공개 저장소 연결

**현재 상태:** 로컬 Git repository는 준비했지만 GitHub 원격 저장소는 생성/푸시하지 못했다. 연결된 GitHub 도구가 기존 저장소 읽기·수정은 지원하지만 새 저장소 생성 기능을 제공하지 않았다.

1. 계정 `PARK-TAEGEON`에서 <https://github.com/new> 접속.
2. Repository name: `another-shitty-day`, Visibility: **Private**.
3. **Initialize with README / .gitignore / LICENSE 체크 해제** (이미 로컬에 있음).
4. 로컬 프로젝트 경로에서 다음 명령 실행:

```sh
cd another-shitty-day
git remote add origin https://github.com/PARK-TAEGEON/another-shitty-day.git
git push -u origin main
```

기존에 같은 이름이 있으면 덮어쓰지 말고 확인한다. GitHub 인증이 요구될 수 있다. 저장소 URL을 알려주면 GitHub 연결 범위에서 파일/이슈 연동을 진행할 수 있다. 라이선스 파일은 사용자가 확정하기 전 자동으로 생성하지 않는다.
