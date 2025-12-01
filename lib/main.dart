import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'kanana_llm.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LLMTestPage(),
  ));
}

// 메시지 데이터 구조 클래스
class ChatMessage {
  final String text;
  final bool isUser; // true: 나, false: 덴지

  ChatMessage({required this.text, required this.isUser});
}

class LLMTestPage extends StatefulWidget {
  const LLMTestPage({super.key});

  @override
  _LLMTestPageState createState() => _LLMTestPageState();
}

class _LLMTestPageState extends State<LLMTestPage> {
  String? _modelPath;
  String _status = "상단의 버튼을 눌러 모델을 로드하세요.";
  bool _modelLoaded = false;
  bool _loading = false;

  // 대화 내용을 저장할 리스트
  final List<ChatMessage> _messages = [];
  // 스크롤을 항상 아래로 내리기 위한 컨트롤러
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();

  // ==========================================
  // 파일 선택 및 모델 로드 (이전과 동일)
  // ==========================================
  Future<void> _pickModelFile() async {
    setState(() => _status = "파일 선택창 여는 중...");

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );

      if (result == null) {
        setState(() => _status = "파일 선택 취소됨.");
        return;
      }

      final String? path = result.files.single.path;
      if (path == null) {
        setState(() => _status = "[ERROR] 경로 없음.");
        return;
      }

      setState(() {
        _modelPath = path;
        _status = "파일 선택됨: ${path.split('/').last}";
      });

      await _loadModel();

    } catch (e) {
      setState(() => _status = "에러: $e");
    }
  }

  Future<void> _loadModel() async {
    if (_modelPath == null) return;

    setState(() {
      _loading = true;
      _status = "⏳ 모델 로딩 중...";
    });

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      bool ok = await LlamaLLM.loadModel(_modelPath!);

      if (!mounted) return;

      if (ok) {
        setState(() {
          _modelLoaded = true;
          _status = "✅ 덴지가 준비되었습니다!";
          // 덴지 첫 인사 추가
          
        });
      } else {
        setState(() {
          _modelLoaded = false;
          _status = "❌ 모델 로드 실패.";
        });
      }
    } catch (e) {
      setState(() => _status = "에러: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  // ==========================================
  // 메시지 전송 로직
  // ==========================================
  void _sendMessage() async {
    String text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();

    // 1. 내 메시지 화면에 추가 (오른쪽)
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });
    _scrollToBottom();

    // 2. 덴지의 '생성 중' 표시 추가 (왼쪽)
    setState(() {
      _messages.add(ChatMessage(text: "...", isUser: false)); // 임시 메시지
    });
    _scrollToBottom();

    // 3. 프롬프트 구성
    String prompt = """
### System:
너는 만화 '체인소맨'의 주인공 덴지다. 
말투는 반말을 쓰고, 거칠고 솔직하게 대답해라. 
길게 말하지 말고 1~2문장으로 짧게 핵심만 말해.

### User:
$text

### Assistant:
""";

    try {
      // 4. 생성 요청
      final reply = await LlamaLLM.generate(prompt);

      // 5. '...'을 실제 답변으로 교체
      setState(() {
        _messages.removeLast(); // '...' 제거
        _messages.add(ChatMessage(text: reply.trim(), isUser: false)); // 진짜 답변 추가
      });
      _scrollToBottom();

    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(text: "에러 터짐: $e", isUser: false));
      });
    }
  }

  void _scrollToBottom() {
    // 화면이 그려진 직후에 스크롤을 맨 아래로 내림
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
    return Scaffold(
      // 배경색 (카톡 느낌의 연한 색)
      backgroundColor: const Color(0xFFBACEE0),
      appBar: AppBar(
        title: const Text("덴지와의 채팅", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // 상단 상태바 (모델 로드 버튼 등)
          if (!_modelLoaded)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Text(_status, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (_loading)
                    const LinearProgressIndicator()
                  else
                    ElevatedButton.icon(
                      onPressed: _pickModelFile,
                      icon: const Icon(Icons.folder),
                      label: const Text("모델 불러오기"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE500), // 카톡 노란색 느낌
                        foregroundColor: Colors.black,
                      ),
                    ),
                ],
              ),
            ),

          // ==========================================
          // [핵심] 채팅 리스트 화면 (ListView)
          // ==========================================
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(15),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildChatBubble(msg);
              },
            ),
          ),

          // 하단 입력창
          if (_modelLoaded)
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: "메시지 입력...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 10
                        ),
                      ),
                      // 엔터 치면 전송
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEE500), // 전송 버튼 (노란색)
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.black),
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
  // [디자인] 말풍선 하나를 그리는 위젯
  // ==========================================
  Widget _buildChatBubble(ChatMessage msg) {
    return Align(
      // 나면 오른쪽(CenterRight), 덴지면 왼쪽(CenterLeft)
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7, // 화면 70%까지만 차지
        ),
        decoration: BoxDecoration(
          // 나는 노란색, 덴지는 흰색
          color: msg.isUser ? const Color(0xFFFEE500) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(msg.isUser ? 15 : 0), // 말꼬리 효과
            bottomRight: Radius.circular(msg.isUser ? 0 : 15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(1, 1),
              blurRadius: 2,
            )
          ],
        ),
        child: Text(
          msg.text,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),
    );
  }
}