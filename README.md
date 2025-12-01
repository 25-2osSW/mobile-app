Kanana LLM (Denji Persona) - On-Device Chatbot 📱
이 프로젝트는 서버 연결 없이 안드로이드 기기 내에서(On-Device) 대규모 언어 모델(LLM)을 구동하는 챗봇 애플리케이션입니다. 카카오의 Kanana 2.1B 모델을 기반으로 만화 '체인소맨'의 주인공 '덴지' 페르소나를 학습(LoRA Fine-tuning)시켰으며, Flutter와 C++(JNI)을 연동하여 구현했습니다.

✨ Key Features (핵심 기능)
100% On-Device Inference: 인터넷 연결 없이 안드로이드 CPU(NPU)만으로 LLM을 구동합니다.

Custom C++ Wrapper: llama.cpp 라이브러리를 JNI로 직접 포팅하여 메모리 안정성을 확보했습니다.

불안정한 Sampler 대신 Manual Greedy Search 구현.

Repetition Penalty(반복 방지) 로직 자체 구현.

Stop Word(출력 제어) 감지 로직으로 환각(Hallucination) 및 자문자답 방지.

Context Cache Management로 연속된 대화 처리.

Persona Tuning: '덴지' 캐릭터의 말투와 성격을 반영한 LoRA 파인튜닝 모델 적용.

Optimized Performance: ARM NEON, FP16, DotProduct 가속을 적용한 Native 빌드.

🛠️ Tech Stack
Frontend: Flutter (Dart)

Native Interface: Java (MethodChannel) ↔ C++ (JNI)

Inference Engine: llama.cpp (Custom Build)

Model: Kanana-2.1B-Instruct (GGUF Quantized q4_0)

Build System: CMake, Android NDK

🚀 Installation & Build Guide
이 프로젝트는 대용량 파일(모델, 빌드 부산물)을 제외하고 소스코드만 업로드되어 있습니다. 실행을 위해서는 C++ 라이브러리 빌드와 모델 파일 준비가 필요합니다.

1. Prerequisites (준비사항)
Flutter SDK

Android Studio & Android SDK

Android NDK (r26d 권장)

CMake

Linux 환경 (WSL2 또는 Mac/Linux) - 빌드 스크립트 실행용

2. Build Native Library (중요!)
앱을 실행하기 전에 llama.cpp 엔진을 안드로이드용 공유 라이브러리(.so)로 컴파일해야 합니다.

android/llama_build 디렉토리로 이동합니다.

Bash

cd android/llama_build
빌드 스크립트를 실행합니다. (NDK 경로가 환경변수에 설정되어 있거나 스크립트 내 경로를 수정해야 함)

Bash

# WSL 또는 Linux 터미널에서 실행
chmod +x build_android.sh
./build_android.sh
빌드가 성공하면 android/app/src/main/jniLibs/arm64-v8a/libllama_jni.so 파일이 생성됩니다.

3. Prepare Model File
학습된 .gguf 모델 파일(약 1.2GB)은 용량 문제로 깃허브에 포함되지 않았습니다.

kanana2.1b-q4_0.gguf 파일을 준비하여 스마트폰의 저장소(Download 폴더 등)에 넣습니다.

앱 실행 후 "GGUF 모델 파일 선택" 버튼을 눌러 해당 파일을 로드합니다.

4. Run App
Bash

flutter pub get
flutter run
📂 Project Structure
kanana_llm_app/
├── lib/
│   ├── main.dart          # 채팅 UI 및 비즈니스 로직
│   └── kanana_llm.dart    # MethodChannel을 통한 JNI 통신
├── android/
│   ├── app/src/main/java/ # Java Native Interface (JNI) Bridge
│   └── llama_build/       # [핵심] C++ 소스 및 빌드 스크립트
│       ├── llama_src/     # llama.cpp 코어 소스 (최적화됨)
│       ├── llama_wrapper.cpp # JNI 구현체 (메모리 관리, 추론 로직)
│       ├── CMakeLists.txt # NDK 빌드 설정
│       └── build_android.sh # 자동 빌드 스크립트
└── ...
📝 Troubleshooting History
개발 과정에서 발생했던 주요 이슈와 해결 방법입니다.

Android 13+ 권한 문제: Permission.storage가 작동하지 않는 문제를 시스템 기본 FilePicker를 사용하여 권한 요청 없이 파일 접근이 가능하도록 해결.

App Crash (Segmentation Fault): llama.cpp의 최신 API 변경으로 인한 메모리 충돌을 확인. llama_batch_get_one 대신 수동으로 배치를 할당하고 logits 플래그를 직접 제어하여 해결.

무한 반복 생성: 모델이 같은 말을 반복하는 현상을 C++ 레벨에서 Repetition Penalty 로직을 추가하여 해결.

Self-Conversation (자문자답): 모델이 User 역할까지 수행하려는 문제를 Stop Word 감지 로직으로 해결.

📄 License
This project is based on llama.cpp and uses a fine-tuned version of Kanana model.

llama.cpp: MIT License

Kanana Model: Follows Kakao Corp's License Policy.
