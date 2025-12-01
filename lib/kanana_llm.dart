import 'dart:async';
import 'package:flutter/services.dart';

class LlamaLLM {
  // MainActivity.java에 설정된 채널 이름과 정확히 일치해야 합니다.
  static const MethodChannel _channel = MethodChannel('kanana_llm');

  // ================================
  // 1) loadModel
  // ================================
  static Future<bool> loadModel(String path) async {
    try {
      // Dart -> Java (MainActivity) -> C++ (JNI) 순서로 호출
      // 인자 이름 'path'는 MainActivity.java에서 받는 키값과 같아야 함
      final bool result = await _channel.invokeMethod('loadModel', {'path': path});
      return result;
    } on PlatformException catch (e) {
      print("Failed to load model: '${e.message}'.");
      return false;
    }
  }

  // ================================
  // 2) generate
  // ================================
  static Future<String> generate(String prompt) async {
    try {
      // 인자 이름 'prompt' 확인
      final String result = await _channel.invokeMethod('generate', {'prompt': prompt});
      return result;
    } on PlatformException catch (e) {
      return "Error: ${e.message}";
    }
  }

  // ================================
  // 3) unload
  // ================================
  static Future<void> unload() async {
    try {
      await _channel.invokeMethod('unload');
    } on PlatformException catch (e) {
      print("Failed to unload: '${e.message}'.");
    }
  }
}