#include <jni.h>
#include <string>
#include <vector>
#include <cstring>
#include <android/log.h>
#include <algorithm>
#include <cmath>

#include "llama.h"

#define TAG "LLAMA_JNI"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

static llama_model *g_model = nullptr;
static llama_context *g_ctx = nullptr;
static bool g_is_backend_init = false;

// UTF-8 정화 함수
std::string sanitize_utf8(const std::string& str) {
    std::string safe_str = "";
    for (size_t i = 0; i < str.length(); ) {
        unsigned char c = str[i];
        int len = 0;
        if (c < 128) len = 1;
        else if ((c & 0xE0) == 0xC0) len = 2;
        else if ((c & 0xF0) == 0xE0) len = 3;
        else if ((c & 0xF8) == 0xF0) len = 4;
        
        if (len == 0 || i + len > str.length()) { safe_str += '?'; i++; continue; }
        
        bool valid = true;
        for (int j = 1; j < len; j++) {
            if ((str[i + j] & 0xC0) != 0x80) { valid = false; break; }
        }
        if (valid) { safe_str.append(str, i, len); i += len; }
        else { safe_str += '?'; i++; }
    }
    return safe_str;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_kanana_1llm_1app_LlamaBridge_loadModel(JNIEnv *env, jclass clazz, jstring jpath) {
    const char *path = env->GetStringUTFChars(jpath, nullptr);
    LOGD("Step 1: Start loading model from %s", path);
    
    try {
        if (!g_is_backend_init) {
            llama_backend_init(); 
            g_is_backend_init = true;
        }

        if (g_ctx) { llama_free(g_ctx); g_ctx = nullptr; }
        if (g_model) { llama_model_free(g_model); g_model = nullptr; }

        llama_model_params model_params = llama_model_default_params();
        model_params.use_mmap = true;

        g_model = llama_model_load_from_file(path, model_params);
        if (!g_model) {
            LOGE("Failed to load model");
            env->ReleaseStringUTFChars(jpath, path);
            return JNI_FALSE;
        }

        llama_context_params ctx_params = llama_context_default_params();
        ctx_params.n_ctx = 2048;
        ctx_params.n_threads = 4;
        ctx_params.n_threads_batch = 4;

        g_ctx = llama_init_from_model(g_model, ctx_params);
        if (!g_ctx) return JNI_FALSE;
        
        LOGD("Model Load Complete!");
        env->ReleaseStringUTFChars(jpath, path);
        return JNI_TRUE;
        
    } catch (...) {
        return JNI_FALSE;
    }
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_kanana_1llm_1app_LlamaBridge_generate(JNIEnv *env, jclass clazz, jstring jprompt) {
    if (!g_model || !g_ctx) return env->NewStringUTF("Error: Model not loaded");

    const char *prompt = env->GetStringUTFChars(jprompt, nullptr);
    std::string result = "";
    char buf[1024]; 
    
    try {
        // 이전 대화 기억 지우기
        if (g_ctx) {
            llama_free(g_ctx);
            g_ctx = nullptr;
        }
        llama_context_params ctx_params = llama_context_default_params();
        ctx_params.n_ctx = 2048; 
        ctx_params.n_threads = 4;
        ctx_params.n_threads_batch = 4;
        g_ctx = llama_init_from_model(g_model, ctx_params);
        if (!g_ctx) return env->NewStringUTF("Error: Context re-init failed");

        const llama_vocab *vocab = llama_model_get_vocab(g_model);
        int n_vocab = llama_vocab_n_tokens(vocab);
        int n_past = 0; 

        std::vector<llama_token> last_tokens;
        int repeat_window = 64; 

        // 1. Tokenize
        int max_tokens = strlen(prompt) + 16; 
        std::vector<llama_token> tokens_list(max_tokens);
        int n_tokens = llama_tokenize(vocab, prompt, strlen(prompt), tokens_list.data(), tokens_list.size(), true, true);
        if (n_tokens < 0) {
            tokens_list.resize(-n_tokens);
            n_tokens = llama_tokenize(vocab, prompt, strlen(prompt), tokens_list.data(), tokens_list.size(), true, true);
        }
        tokens_list.resize(n_tokens);

        for(auto t : tokens_list) {
            last_tokens.push_back(t);
            if(last_tokens.size() > repeat_window) last_tokens.erase(last_tokens.begin());
        }

        // 2. Initial Decode
        llama_batch batch = llama_batch_init(n_tokens, 0, 1);
        batch.n_tokens = n_tokens;
        for (int i = 0; i < n_tokens; i++) {
            batch.token[i] = tokens_list[i];
            batch.pos[i] = i;
            batch.n_seq_id[i] = 1;
            batch.seq_id[i][0] = 0;
            batch.logits[i] = false;
        }
        batch.logits[n_tokens - 1] = true;

        if (llama_decode(g_ctx, batch) != 0) {
            llama_batch_free(batch);
            return env->NewStringUTF("Error: Decode failed");
        }
        n_past += n_tokens;

        // 3. Generation Loop
        int n_predict = 128; 
        
        // [강력해진 정지 단어 목록]
        // 이 단어들이 나오면 즉시 자르고 종료합니다.
        std::vector<std::string> stop_words = {
            "User:", "User", "USER:", "USER",
            "Assistant:", "Assistant", "ASSISTANT:", "ASSISTANT",
            "###", "<|start_header_id|>"
        };

        for (int i = 0; i < n_predict; i++) {
            float* logits = llama_get_logits_ith(g_ctx, batch.n_tokens - 1);
            if (!logits) break;

            // Repetition Penalty
            float penalty_weight = 1.2f;
            for (llama_token t : last_tokens) {
                if (logits[t] > 0) logits[t] /= penalty_weight;
                else logits[t] *= penalty_weight;
            }

            // Greedy Sampling
            int best_token_id = 0;
            float max_val = -1e9;
            for (int k = 0; k < n_vocab; k++) {
                if (logits[k] > max_val) {
                    max_val = logits[k];
                    best_token_id = k;
                }
            }

            if (llama_vocab_is_eog(vocab, best_token_id)) break;

            memset(buf, 0, sizeof(buf));
            int n = llama_token_to_piece(vocab, best_token_id, buf, sizeof(buf) - 1, 0, true);
            if (n > 0) {
                if (n >= sizeof(buf)) n = sizeof(buf) - 1;
                buf[n] = '\0';
                
                std::string piece(buf);
                result += piece;

                // [강화된 Stop Word Check]
                // 목록에 있는 단어가 하나라도 발견되면 루프 탈출
                bool stop_triggered = false;
                for (const auto& word : stop_words) {
                    size_t pos = result.find(word);
                    if (pos != std::string::npos) {
                        result = result.substr(0, pos); // 해당 단어 앞까지만 자름
                        stop_triggered = true;
                        break;
                    }
                }
                if (stop_triggered) break;
            }

            last_tokens.push_back(best_token_id);
            if(last_tokens.size() > repeat_window) last_tokens.erase(last_tokens.begin());

            batch.n_tokens = 1;
            batch.token[0] = best_token_id;
            batch.pos[0] = n_past;
            batch.n_seq_id[0] = 1;
            batch.seq_id[0][0] = 0;
            batch.logits[0] = true; 

            if (llama_decode(g_ctx, batch) != 0) break;
            n_past++;
        }
        
        llama_batch_free(batch);

    } catch (const std::exception& e) {
        env->ReleaseStringUTFChars(jprompt, prompt);
        return env->NewStringUTF(e.what());
    }

    env->ReleaseStringUTFChars(jprompt, prompt);
    std::string safe_result = sanitize_utf8(result);
    return env->NewStringUTF(safe_result.c_str());
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_kanana_1llm_1app_LlamaBridge_unload(JNIEnv *env, jclass clazz) {
    if (g_ctx) { llama_free(g_ctx); g_ctx = nullptr; }
    if (g_model) { llama_model_free(g_model); g_model = nullptr; }
    if (g_is_backend_init) { llama_backend_free(); g_is_backend_init = false; }
}