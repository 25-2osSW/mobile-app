package com.example.kanana_llm_app;

public class LlamaBridge {
    static {
        System.loadLibrary("llama_jni");
    }

    public static native boolean loadModel(String path);
    public static native String generate(String prompt);
    public static native void unload();
}
