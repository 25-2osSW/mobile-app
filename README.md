1단계: .gitignore 설정 (가장 중요)
프로젝트 루트 폴더(C:\Users\muyer\StudioProjects\kanana_llm_app)에 있는 .gitignore 파일을 메모장이나 VS Code로 여세요. 그리고 맨 아래에 다음 내용들을 추가해서 저장하세요. (무거운 파일들이 깃에 추적되지 않게 막는 설정입니다.)

코드 스니펫

# --- 기존 내용 아래에 추가하세요 ---

# 1. 모델 파일 제외 (너무 큼)
*.gguf
assets/models/

# 2. C++ 빌드 결과물 제외 (우리가 수동 빌드한 것들)
android/llama_build/build/
android/llama_build/llama_src/
# 단, 소스코드는 올려야 하니 필요한 파일만 남기고 빌드 부산물은 빼야 함
# (만약 llama.cpp 전체 소스를 다 올리기 부담스러우면 위처럼 제외하고
# 나중에 clone 받을 때 submodule 등을 쓰는 게 정석이지만,
# 일단 편하게 하려면 build 폴더만이라도 꼭 제외하세요.)

# 3. 안드로이드 네이티브 빌드 캐시 제외
android/.cxx/
android/app/build/
android/build/
2단계: 용량 다이어트 (청소)
터미널(PowerShell 또는 CMD)에서 프로젝트 폴더로 이동한 뒤, 아래 명령어로 찌꺼기 파일들을 삭제합니다.

Flutter 빌드 파일 삭제:

Bash

flutter clean
(이 명령어를 치면 build 폴더가 사라지고 프로젝트가 엄청 가벼워집니다.)

C++ 빌드 파일 수동 삭제: 탐색기를 열어서 android/llama_build/build 폴더가 있다면 삭제하세요. (나중에 build_android.sh 돌리면 다시 생기니까요.)

이렇게 하면 8GB였던 프로젝트가 소스코드만 남아서 아마 50MB~100MB 내외로 확 줄어들 겁니다. android 폴더도 flutter clean을 하고 나면 확 줄어듭니다.

3단계: 깃허브에 올리기 (명령어)
이제 가벼워진 프로젝트를 깃허브에 올립니다. 보여주신 깃허브 화면의 명령어를 참고하여 진행합니다.

VS Code 터미널이나 PowerShell에서 순서대로 입력하세요.

PowerShell

# 1. 깃 초기화 (이미 되어있을 수도 있지만 확실하게)
git init

# 2. 모든 파일 스테이징 (이제 .gitignore 덕분에 무거운 건 안 들어감)
git add .

# 3. 커밋 (저장)
git commit -m "Initial commit - Kanana LLM Chatbot Finished"

# 4. 브랜치 이름 설정 (main)
git branch -M main

# 5. 원격 저장소 연결 (님 깃허브 주소)
git remote add origin https://github.com/25-2osSW/mobile-app.git

# 6. 푸시 (업로드)
git push -u origin main
(만약 remote origin already exists 에러가 나면 5번은 건너뛰고 6번만 하세요.)

💡 주의사항 (다른 사람이 받을 때)
이렇게 올리면 **모델 파일(.gguf)**과 **C++ 빌드 결과물(.so)**은 깃허브에 안 올라갑니다. (이게 정상입니다.)

나중에 다른 사람(또는 교수님)이 이 코드를 받아서 실행하려면:

assets/models/ 폴더에 kanana2.1b-q4_0.gguf 파일을 직접 넣어줘야 하고,

android/llama_build/ 폴더에서 ./build_android.sh를 한 번 실행해줘야 한다고 README.md 파일에 적어두시면 완벽합니다.

이제 업로드 진행해보세요!
