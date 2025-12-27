import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bangkah Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16, fontFamily: 'Roboto'),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const ChatHomePage(),
    );
  }
}

class ChatHomePage extends StatelessWidget {
  const ChatHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatPage();
  }
}

class ChatSession {
  final String id;
  final String name;
  final List<_ChatMessage> messages;
  ChatSession({
    required this.id,
    required this.name,
    List<_ChatMessage>? messages,
  }) : messages = messages ?? [];
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatSession> _sessions = [ChatSession(id: '1', name: 'Sesi 1')];
  int _selectedSession = 0;
  bool _isLoading = false;
  bool _isAddingSession = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await OllamaService.fetchSessions();
      setState(() {
        _sessions.clear();
        _sessions.addAll(sessions);
        _selectedSession = 0;
      });
    } catch (e) {
      // Handle error (show snackbar, etc)
    }
  }

  void _addSession() async {
    setState(() {
      _isAddingSession = true;
    });
    final name = 'Sesi ${_sessions.length + 1}';
    try {
      final newSession = await OllamaService.createSession(name);
      setState(() {
        _sessions.add(newSession);
        _selectedSession = _sessions.length - 1;
      });
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isAddingSession = false;
      });
    }
  }

  void _deleteSession(int index) async {
    if (_sessions.length == 1) return;
    final id = _sessions[index].id;
    try {
      await OllamaService.deleteSession(id);
      setState(() {
        _sessions.removeAt(index);
        if (_selectedSession >= _sessions.length) {
          _selectedSession = _sessions.length - 1;
        }
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadChatHistory(int sessionIndex) async {
    final id = _sessions[sessionIndex].id;
    try {
      final messages = await OllamaService.fetchChatHistory(id);
      setState(() {
        _sessions[sessionIndex].messages.clear();
        _sessions[sessionIndex].messages.addAll(messages);
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _sessions[_selectedSession].messages.add(
        _ChatMessage(text: text, isUser: true),
      );
      _isLoading = true;
      _controller.clear();
    });
    final response = await OllamaService.sendMessage(
      text,
      _sessions[_selectedSession].id,
    );
    setState(() {
      _sessions[_selectedSession].messages.add(
        _ChatMessage(text: response, isUser: false),
      );
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 700;
    final chatArea = Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              itemCount: _sessions[_selectedSession].messages.length,
              itemBuilder: (context, index) {
                final msg = _sessions[_selectedSession].messages[index];
                return Row(
                  mainAxisAlignment: msg.isUser
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: msg.isUser
                              ? Colors.deepPurple[300]
                              : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(msg.isUser ? 16 : 0),
                            bottomRight: Radius.circular(msg.isUser ? 0 : 16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          msg.text,
                          style: TextStyle(
                            color: msg.isUser ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(hintText: 'Ketik pesan...'),
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.deepPurple,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final sidebar = Container(
      width: isDesktop ? 220 : 0,
      decoration: BoxDecoration(
        color: Colors.deepPurple[50],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'Bangkah Chat',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: 'Roboto',
                  ),
                ),
                const Spacer(),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.deepPurple),
                      onPressed: _isAddingSession ? null : _addSession,
                      tooltip: 'Tambah Sesi',
                    ),
                    if (_isAddingSession)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final selected = index == _selectedSession;
                return Material(
                  color: selected ? Colors.deepPurple[100] : Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedSession = index;
                      });
                      _loadChatHistory(index);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _sessions[index].name,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (_sessions.length > 1)
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                size: 18,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _deleteSession(index),
                              tooltip: 'Hapus Sesi',
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ollama Chat'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 2,
      ),
      drawer: isDesktop ? null : Drawer(child: sidebar),
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  sidebar,
                  Expanded(child: chatArea),
                ],
              )
            : chatArea,
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}

class OllamaService {
  static const String backendUrl = 'http://localhost:8080';

  static Future<List<ChatSession>> fetchSessions() async {
    final url = Uri.parse('$backendUrl/session');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data
          .map(
            (s) => ChatSession(
              id: s['id'],
              name: s['name'],
              messages:
                  (s['messages'] as List?)
                      ?.map(
                        (m) => _ChatMessage(
                          text: m['message'],
                          isUser: m['sender'] == 'user',
                        ),
                      )
                      .toList() ??
                  [],
            ),
          )
          .toList();
    } else {
      throw Exception('Failed to fetch sessions');
    }
  }

  static Future<ChatSession> createSession(String name) async {
    final url = Uri.parse('$backendUrl/session');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 200) {
      final s = jsonDecode(response.body);
      return ChatSession(id: s['id'], name: s['name'], messages: []);
    } else {
      throw Exception('Failed to create session');
    }
  }

  static Future<void> deleteSession(String id) async {
    final url = Uri.parse('$backendUrl/session/$id');
    final response = await http.delete(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete session');
    }
  }

  static Future<List<_ChatMessage>> fetchChatHistory(String sessionId) async {
    final url = Uri.parse('$backendUrl/chat/$sessionId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data
          .map(
            (m) =>
                _ChatMessage(text: m['message'], isUser: m['sender'] == 'user'),
          )
          .toList();
    } else {
      throw Exception('Failed to fetch chat history');
    }
  }

  static Future<String> sendMessage(String message, String sessionId) async {
    final url = Uri.parse('$backendUrl/chat/$sessionId');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['message'] ?? '';
    } else {
      return 'Error: ${response.body}';
    }
  }
}
