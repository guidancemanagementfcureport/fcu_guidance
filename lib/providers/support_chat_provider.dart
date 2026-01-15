import 'package:flutter/material.dart';
import '../models/support_chat_model.dart';
import '../services/supabase_service.dart';
import '../services/openai_service.dart';
import 'dart:async';

class SupportChatProvider with ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();

  SupportSessionModel? _currentSession;
  List<SupportMessageModel> _messages = [];
  bool _isLoading = false;
  bool _isOpen = false;
  StreamSubscription? _messageSubscription;

  // AI Configuration
  static const String _systemPrompt = '''
You are the official AI Assistant for the FCU Guidance Management System at Fellowship of Christian University (FCU).
Your role is to listen, support, and gather information from students in a respectful, empathetic, and professional way.
You are part of the FCU Guidance Office services.
You must never provide medical or psychological diagnoses.
If a message suggests self-harm, suicide, or immediate danger, you must escalate the case by notifying guidance staff and respond with reassurance and encouragement to seek help.
Keep responses natural, supportive, and non-repetitive.
When students ask about the university or the app, identify yourself as the FCU Guidance AI.
''';

  // Emergency Keywords
  static const List<String> _emergencyKeywords = [
    'suicide',
    'kill myself',
    'self-harm',
    'i want to die',
    'call guidance',
    'emergency',
    'help me now',
    'end my life',
    'hurt myself',
    'want to disappear',
    'urgent matter',
    'contact support',
    'need to call',
    'call the guidance',
    'guidance office',
  ];

  bool _isAiThinking = false;
  VoidCallback? _onEmergencyCall;

  void setEmergencyCallHandler(VoidCallback handler) {
    _onEmergencyCall = handler;
  }

  SupportSessionModel? get currentSession => _currentSession;
  List<SupportMessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isOpen => _isOpen;
  bool get isAiThinking => _isAiThinking;

  void toggleChat() {
    _isOpen = !_isOpen;
    notifyListeners();
  }

  Future<void> initSession({String? userId, String? userName}) async {
    // If we have a session, check if it matches the current user status
    if (_currentSession != null) {
      if (_currentSession!.studentId == userId) return;

      // If user changed (e.g. logged in), reset or handle transition
      _messageSubscription?.cancel();
      _currentSession = null;
      _messages = [];
    }

    _isLoading = true;
    notifyListeners();

    try {
      _currentSession = await _supabase.createSupportSession(
        studentId: userId,
        studentName: userName,
      );

      _subscribeToMessages();
      await _loadMessages();

      // Send initial greeting if no messages exist
      if (_messages.isEmpty) {
        await _sendInitialGreeting();
      }
    } catch (e) {
      debugPrint('Error initializing support chat: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _sendInitialGreeting() async {
    _isAiThinking = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    const greeting =
        "Hello! I'm your Guidance AI Assistant. How can I help you today? Whether you have a concern, need someone to talk to, or have questions about our services, I'm here to listen and support you.";

    await sendMessage(
      greeting,
      senderId: null,
      senderRole: 'ai',
      messageType: 'ai_assistance',
    );

    _isAiThinking = false;
    notifyListeners();
  }

  Future<void> _loadMessages() async {
    if (_currentSession == null) return;
    try {
      _messages = await _supabase.getSupportMessages(_currentSession!.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading support messages: $e');
    }
  }

  void _subscribeToMessages() {
    if (_currentSession == null) return;
    _messageSubscription?.cancel();

    _messageSubscription = _supabase
        .streamSupportMessages(_currentSession!.id)
        .listen((newMessages) {
          _messages = newMessages;
          notifyListeners();
        });
  }

  Future<void> sendMessage(
    String text, {
    String? senderId,
    required String senderRole,
    String messageType = 'text',
  }) async {
    if (_currentSession == null) {
      debugPrint('Cannot send message: no active session');
      return;
    }

    // Add message locally for immediate feedback
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final localMessage = SupportMessageModel(
      id: tempId,
      sessionId: _currentSession!.id,
      senderId: senderId,
      senderRole: senderRole,
      message: text,
      messageType: messageType,
      isRead: false,
      createdAt: DateTime.now(),
    );

    _messages.add(localMessage);
    notifyListeners();

    try {
      await _supabase.sendSupportMessage(
        sessionId: _currentSession!.id,
        senderId: senderId,
        senderRole: senderRole,
        message: text,
        messageType: messageType,
      );
    } catch (e) {
      debugPrint('Error sending support message: $e');
      // Optionally remove local message or show error
      _messages.removeWhere((m) => m.id == tempId);
      notifyListeners();
    }

    // Trigger AI Response if applicable
    if (senderRole == 'student' &&
        _currentSession?.status == SupportSessionStatus.aiActive) {
      _processAIResponse(text);
    }
  }

  Future<void> _processAIResponse(String userMessage) async {
    _isAiThinking = true;
    notifyListeners();

    // 1. Check for emergency
    if (_checkForEmergency(userMessage)) {
      _onEmergencyCall?.call();
      await _handleEmergency();
      _isAiThinking = false;
      notifyListeners();
      return;
    }

    // 2. Simulate AI Typing delay (natural feel)
    await Future.delayed(const Duration(milliseconds: 800));

    // 3. Generate Response using OpenAI
    try {
      final recentMessages =
          _messages.reversed.take(10).toList().reversed.toList();
      final history =
          recentMessages.map((m) {
            return {
              'role': m.senderRole == 'ai' ? 'assistant' : 'user',
              'content': m.message,
            };
          }).toList();

      final response = await OpenAIService.generateResponse(
        systemPrompt: _systemPrompt,
        userMessage: userMessage,
        history: history,
      );

      await sendMessage(
        response,
        senderId: null,
        senderRole: 'ai',
        messageType: 'ai_assistance',
      );
    } finally {
      _isAiThinking = false;
      notifyListeners();
    }
  }

  bool _checkForEmergency(String message) {
    final lowerMsg = message.toLowerCase();
    return _emergencyKeywords.any((keyword) => lowerMsg.contains(keyword));
  }

  Future<void> _handleEmergency() async {
    // Log emergency status
    if (_currentSession != null) {
      await _supabase.markSessionUrgent(_currentSession!.id);
    }

    await Future.delayed(const Duration(seconds: 1));

    const emergencyResponse =
        "I’m really glad you reached out. You’re not alone. I’ve notified the guidance office so someone can help you as soon as possible. I’m here with you while we wait.\n\n[EMERGENCY_CALL]";

    await sendMessage(
      emergencyResponse,
      senderId: null,
      senderRole: 'ai',
      messageType: 'ai_assistance',
    );
  }

  Future<void> resolveSession() async {
    if (_currentSession == null) return;
    try {
      await _supabase.updateSupportSessionStatus(
        _currentSession!.id,
        SupportSessionStatus.resolved,
      );
      _currentSession = null;
      _messages = [];
      _isOpen = false;
      _messageSubscription?.cancel();
      notifyListeners();
    } catch (e) {
      debugPrint('Error resolving session: $e');
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
