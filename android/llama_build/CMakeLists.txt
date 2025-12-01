cmake_minimum_required(VERSION 3.10)
project(llama_jni)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_C_STANDARD 11)

find_library(log-lib log)

# --- 1. 경로 설정 ---
set(LLAMA_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/llama_src)

include_directories(
    ${LLAMA_ROOT}/include
    ${LLAMA_ROOT}/src
    ${LLAMA_ROOT}/common
    ${LLAMA_ROOT}/ggml/include
    ${LLAMA_ROOT}/ggml/src
    ${LLAMA_ROOT}/ggml/src/ggml-cpu
    ${LLAMA_ROOT}/common/json/include
    ${LLAMA_ROOT}/common/minja/include
)

# --- 2. 소스 파일 수집 (전체 재귀 탐색) ---

# [GGML] ggml/src 밑의 모든 소스
file(GLOB_RECURSE GGML_SOURCES
    "${LLAMA_ROOT}/ggml/src/*.c"
    "${LLAMA_ROOT}/ggml/src/*.cpp"
)

# [LLAMA] src 밑의 모든 소스 (여기가 핵심 변경점!)
# 파일이 하위 폴더로 이동했더라도 찾을 수 있도록 GLOB_RECURSE 사용
file(GLOB_RECURSE LLAMA_SOURCES
    "${LLAMA_ROOT}/src/*.cpp"
    "${LLAMA_ROOT}/src/*.c"
)

# [COMMON] common 밑의 모든 소스
file(GLOB COMMON_SOURCES
    "${LLAMA_ROOT}/common/*.cpp"
)

# --- 3. 필터링 (불필요한 백엔드/파일 제거) ---

# GPU 및 기타 가속기 제거
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*ggml-cuda.*")
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*ggml-metal.*")
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*ggml-mpi.*")
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*ggml-rpc.*")
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*ggml-sycl.*")
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*ggml-vulkan.*")
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*ggml-blas.*")
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*ggml-kompute.*")
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*ggml-cann.*")
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*ggml-hip.*")
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*hexagon.*")
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*musa.*")

# 안드로이드 CPU 빌드 방해 요소 제거
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*opencl.*")
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*zdnn.*")
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*webgpu.*")
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*amx.*")

# 타사 라이브러리 래퍼 제거
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*spacemit.*")
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*kleidiai.*")
list(FILTER GGML_SOURCES EXCLUDE REGEX ".*llamafile.*")

# Common 불필요 파일 제거
list(FILTER COMMON_SOURCES EXCLUDE REGEX ".*main.cpp")
list(FILTER COMMON_SOURCES EXCLUDE REGEX ".*build-info.cpp")
list(FILTER COMMON_SOURCES EXCLUDE REGEX ".*chat.cpp")
list(FILTER COMMON_SOURCES EXCLUDE REGEX ".*speculative.cpp")

# [안전장치] 혹시 LLAMA_SOURCES에 테스트 코드나 불필요한 게 들어갔을 경우 대비
list(FILTER LLAMA_SOURCES EXCLUDE REGEX ".*tests/.*")

# --- 4. 라이브러리 빌드 ---
add_library(llama_engine STATIC
    ${GGML_SOURCES}
    ${LLAMA_SOURCES}
    ${COMMON_SOURCES}
)

# 컴파일 옵션 및 정의
target_compile_definitions(llama_engine PRIVATE
    _XOPEN_SOURCE=600
    _GNU_SOURCE
    GGML_USE_CPU
    GGML_VERSION="android-custom"
    GGML_COMMIT="unknown"
    GGML_SCHED_MAX_COPIES=4
    LLAMA_BUILD
    LLAMA_SHARED
    __ARM_NEON
    __ARM_FEATURE_DOTPROD
    __ARM_FEATURE_FP16_VECTOR_ARITHMETIC
)

target_compile_options(llama_engine PRIVATE
    -march=armv8.2-a+fp16+dotprod
    -Wno-unused-function
)

add_library(llama_jni SHARED llama_wrapper.cpp)

target_link_libraries(llama_jni
    PRIVATE
    llama_engine
    ${log-lib}
)