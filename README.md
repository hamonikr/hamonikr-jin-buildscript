# HamoniKR Build Script
## 2020.10.05 작성
- 하모니카 4.0 베타버전 릴리즈

## config - hamonikr.conf
- work_path:프로젝트 경로. start.sh 스크립트 실행시 자동 재설정
- down_url:베이스 iso 파일 다운로드 URL
- input_iso:베이스 iso 파일
- output_iso:제작될 iso 파일명

## Build 순서
- 중간에 서명을 해야 하는 부분이 있어서 다음과 같이 변경
- 각종 패키지 인스톨 > 서명 > iso생성
- sudo ./1-start.sh
- sudo ./2-update-iso-repo.sh
- sudo ./3-end.sh

## directory
- conf:빌드를 하기위한 주소 설정 파일
- resource:빌드시 필요한 리소스 파일
- script:빌드시 사용되는 스크립트

## check_added_large_file.py
- 대용량 파일의 커밋 방지
- ln -s check_added_large_files.py .git/hooks/pre-commit.py 심볼릭 링크 생성

