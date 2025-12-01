import 'dart:async';
import 'dart:io';
import 'dart:ui'; // 블러 효과(ImageFilter)용
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'kanana_llm.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    themeMode: ThemeMode.dark, // 다크 모드 기반
    home: LLMTestPage(),
  ));
}

// 메시지 데이터 구조
class ChatMessage {
  final String text;
  final bool isUser;
  final String time; // 시간 표시용

  ChatMessage({required this.text, required this.isUser, required this.time});
}

class LLMTestPage extends StatefulWidget {
  const LLMTestPage({super.key});

  @override
  _LLMTestPageState createState() => _LLMTestPageState();
}

class _LLMTestPageState extends State<LLMTestPage> {
  String? _modelPath;
  String _status = "시스템 대기 중...";
  bool _modelLoaded = false;
  bool _loading = false;

  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();

  // ==========================================
  // 파일 선택 및 로드 (기능은 동일)
  // ==========================================
  Future<void> _pickModelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );

      if (result == null) return;
      final String? path = result.files.single.path;
      if (path == null) return;

      setState(() {
        _modelPath = path;
        _status = "파일 확인됨: ${path.split('/').last}";
      });

      await _loadModel();
    } catch (e) {
      setState(() => _status = "Error: $e");
    }
  }

  Future<void> _loadModel() async {
    if (_modelPath == null) return;
    setState(() { _loading = true; _status = "시스템 초기화 중..."; });
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      bool ok = await LlamaLLM.loadModel(_modelPath!);
      if (!mounted) return;

      if (ok) {
        setState(() {
          _modelLoaded = true;
          _status = "SYSTEM ONLINE";
        });
      } else {
        setState(() { _modelLoaded = false; _status = "LOAD FAILED"; });
      }
    } catch (e) {
      setState(() => _status = "Error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  // ==========================================
  // 메시지 전송
  // ==========================================
  void _sendMessage() async {
    String text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();

    String now = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true, time: now));
    });
    _scrollToBottom();

    // 덴지 로딩 메시지
    setState(() {
      _messages.add(ChatMessage(text: "...", isUser: false, time: ""));
    });
    _scrollToBottom();
    //프롬프트 수정 12월1일
    // 프롬프트 (덴지 페르소나)
    String prompt = """
<|begin_of_text|><|start_header_id|>system<|end_header_id|>

너는 만화 '체인소맨'의 주인공 덴지다.
말투는 반말을 쓰고, 거칠고 솔직하게 대답해라.
귀찮은 듯이 말하거나, 먹을 거나 여자 이야기를 좋아한다.
길게 말하지 말고 1~2문장으로 짧게 대답해.<|eot_id|>
<|start_header_id|>user<|end_header_id|>

$text<|eot_id|>
<|start_header_id|>assistant<|end_header_id|>
""";

    try {
      final reply = await LlamaLLM.generate(prompt);
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(text: reply.trim(), isUser: false, time: now));
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(text: "Error: $e", isUser: false, time: now));
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    if (_modelLoaded) LlamaLLM.unload();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 배경 이미지가 없으면 기본 단색 처리
    return Scaffold(
      extendBodyBehindAppBar: true, // 앱바 뒤로 배경 확장
      appBar: AppBar(
        title: const Text("Chat Channel",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, // 투명 앱바
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(onPressed: (){}, icon: const Icon(Icons.settings, color: Colors.white70)),
        ],
      ),
      // [핵심] 배경 + 블러 + 채팅창 Stack 구조
      body: Stack(
        children: [
          // 1. 배경 이미지 (원하는 이미지 경로로 수정하세요)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                // 이미지가 없으면 NetworkImage로 테스트, 있으면 AssetImage 사용
                image: AssetImage("assets/images/background.jpg"),
                //image: NetworkImage("https://i.pinimg.com/736x/1c/54/f7/1c54f7b06d7723c21afc5035bf88a5ef.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. 전체 화면 흐림 효과 (Blur)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
            child: Container(
              color: Colors.black.withOpacity(0.2), // 약간 어둡게
            ),
          ),

          // 3. 메인 컨텐츠
          SafeArea(
            child: Column(
              children: [
                // 상단 상태 표시줄 (유리창 효과)
                if (!_modelLoaded)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      children: [
                        Text(_status, style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 10),
                        if (_loading)
                          const LinearProgressIndicator(color: Colors.cyan)
                        else
                          ElevatedButton.icon(
                            onPressed: _pickModelFile,
                            icon: const Icon(Icons.download),
                            label: const Text("Load System Core"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan.withOpacity(0.7),
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),

                // 채팅 리스트
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildGlassMessage(_messages[index]);
                    },
                  ),
                ),

                // 입력창 (하단 유리창 스타일)
                if (_modelLoaded)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6), // 하단은 좀 더 어둡게
                      border: const Border(top: BorderSide(color: Colors.white10)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "메시지를 입력하세요...",
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: _sendMessage,
                          icon: const Icon(Icons.send, color: Colors.cyan),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // [디자인] 이미지 속 스타일 (리스트 타일 형태)
  // ==========================================
  // ==========================================
  // [디자인] 이미지 속 스타일 (리스트 타일 형태)
  // ==========================================
  Widget _buildGlassMessage(ChatMessage msg) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==============================================
          // [수정됨] 1. 프로필 이미지 영역 (아이콘 -> 이미지)
          // ==============================================
          Container(
            width: 45, // 크기 살짝 키움 (이미지가 잘 보이게)
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10), // 모서리 둥글게
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1), // 테두리 살짝 추가
              image: DecorationImage(
                // msg.isUser가 true면 내 사진, false면 덴지 사진
                image: AssetImage(msg.isUser
                    ? "assets/images/user.png"   // 내 프사 파일명
                    : "assets/images/denji.png"  // 덴지 프사 파일명
                ),
                fit: BoxFit.cover, // 네모 칸에 꽉 차게 조절
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 2. 텍스트 내용 (오른쪽) - 기존과 동일
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      msg.isUser ? "User" : "Denji",
                      style: TextStyle(
                        color: msg.isUser ? Colors.purpleAccent : Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      msg.time,
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  msg.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}