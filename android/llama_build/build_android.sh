#!/bin/bash
set -e

# 1. 환경 변수 설정
export ANDROID_NDK_HOME="$HOME/android_ndk/android-ndk-r26d"
export ANDROID_SDK_ROOT="/mnt/c/Users/muyer/AppData/Local/Android/Sdk"

echo "ANDROID_NDK_HOME = $ANDROID_NDK_HOME"

# 2. 경로 설정 (WSL 절대경로 활용)
BUILD_DIR=build
# 타겟 폴더: Flutter 프로젝트의 jniLibs 폴더
JNI_LIBS_DIR="/mnt/c/Users/muyer/StudioProjects/kanana_llm_app/android/app/src/main/jniLibs/arm64-v8a"

# 3. 청소 및 폴더 생성
echo "Cleaning up..."
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR
mkdir -p $JNI_LIBS_DIR  # 타겟 폴더가 없으면 생성

cd $BUILD_DIR

# 4. CMake 설정 (Configure)
echo "Running CMake..."
cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-28 \
  -DCMAKE_BUILD_TYPE=Release \
  -DANDROID_NDK=$ANDROID_NDK_HOME \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
  ../

# 5. 빌드 (Compile) - 중요: -j 옵션으로 병렬 빌드 (속도 빨라짐)
echo "Building library..."
# $(nproc)는 CPU 코어 수만큼 스레드를 씀
cmake --build . --config Release -j$(nproc)

# 6. 결과물 복사
echo "Copying libllama_jni.so to $JNI_LIBS_DIR"
cp libllama_jni.so "$JNI_LIBS_DIR/"

echo "---------------------------------------"
echo "Build complete!"
echo "Files in target dir:"
ls -l "$JNI_LIBS_DIR/"
echo "---------------------------------------"