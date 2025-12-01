package com.example.kanana_llm_app;

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    private static final String CHANNEL = "kanana_llm";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "loadModel":
                    String path = call.argument("path");
                    boolean ok = LlamaBridge.loadModel(path);
                    result.success(ok);
                    break;

                case "generate":
                    String prompt = call.argument("prompt");
                    String out = LlamaBridge.generate(prompt);
                    result.success(out);
                    break;

                case "unload":
                    LlamaBridge.unload();
                    result.success(null);
                    break;

                default:
                    result.notImplemented();
                    break;
            }
        });
    }
}
