import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../providers/anonymous_chat_provider.dart';
import '../utils/toast_utils.dart';
import 'package:intl/intl.dart';

class AnonymousChatbox extends StatefulWidget {
  const AnonymousChatbox({super.key});

  @override
  State<AnonymousChatbox> createState() => _AnonymousChatboxState();
}

class _AnonymousChatboxState extends State<AnonymousChatbox> {
  final SupabaseService _supabase = SupabaseService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isSending = false;
  String? _currentCaseCode;
  String? _currentReportId;
  List<Map<String, dynamic>> _messages = [];
  bool _caseCodeEntered = false;
  AnonymousChatProvider? _chatProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProvider?.removeListener(_onNewChat);
    _chatProvider = Provider.of<AnonymousChatProvider>(context, listen: false);
    _chatProvider?.addListener(_onNewChat);
  }

  @override
  void dispose() {
    _chatProvider?.removeListener(_onNewChat);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onNewChat() {
    final chatProvider = Provider.of<AnonymousChatProvider>(
      context,
      listen: false,
    );
    if (chatProvider.caseCode != null && chatProvider.reportId != null) {
      setState(() {
        _currentCaseCode = chatProvider.caseCode;
        _currentReportId = chatProvider.reportId.toString();
        _caseCodeEntered = true;
      });
      _loadMessages();
      chatProvider.clearChat();
    }
  }

  Future<void> _loadMessages() async {
    if (_currentReportId == null) return;

    setState(() => _isLoading = true);
    try {
      final messages = await _supabase.getAnonymousMessages(_currentReportId!);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.showError(context, 'Error loading messages: $e');
      }
    }
  }

  Future<void> _resumeChat(String caseCode) async {
    setState(() => _isLoading = true);
    try {
      final report = await _supabase.getAnonymousReportByCaseCode(caseCode);
      if (report == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ToastUtils.showError(
            context,
            'Case code not found. Please check and try again.',
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _currentCaseCode = caseCode;
          _currentReportId = report['id'] as String;
          _caseCodeEntered = true;
          _isLoading = false;
        });
        await _loadMessages();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.showError(context, 'Error resuming chat: $e');
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _currentReportId == null) {
      return;
    }

    final message = _messageController.text.trim();
    _messageController.clear();

    setState(() => _isSending = true);
    try {
      await _supabase.sendAnonymousMessage(
        reportId: _currentReportId!,
        senderType: 'anonymous',
        message: message,
      );
      await _loadMessages();
      if (mounted) {
        setState(() => _isSending = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ToastUtils.showError(context, 'Error sending message: $e');
      }
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
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<AnonymousChatProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (!chatProvider.isOpen) return const SizedBox.shrink();

    if (isMobile) {
      // Full screen on mobile
      return Scaffold(body: _buildChatWindow());
    }

    return Positioned(
      bottom: isMobile ? 16 : 20,
      right: isMobile ? 16 : 20,
      child: _buildChatWindow(),
    );
  }

  Widget _buildChatWindow() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: isMobile ? double.infinity : 400,
      height: isMobile ? double.infinity : 600,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(24),
        boxShadow:
            isMobile
                ? []
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
        border:
            isMobile
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: ClipRRect(
        borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(24),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.deepBlue,
                    AppTheme.mediumBlue,
                    AppTheme.skyBlue,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.skyBlue.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anonymous Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Secure & Confidential',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    splashRadius: 24,
                    onPressed: () {
                      Provider.of<AnonymousChatProvider>(
                        context,
                        listen: false,
                      ).toggleChat(open: false);
                    },
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Container(
                color: const Color(0xFFF9FAFB), // Very light gray background
                child:
                    _caseCodeEntered
                        ? _buildChatInterface()
                        : _buildCaseCodeEntry(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaseCodeEntry() {
    final TextEditingController caseCodeController = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_person_outlined,
              size: 48,
              color: AppTheme.skyBlue,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Continue Conversation',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Enter your Case Code below to resume your anonymous session.',
            style: TextStyle(color: AppTheme.mediumGray, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          TextField(
            controller: caseCodeController,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
            decoration: InputDecoration(
              labelText: 'Case Code',
              hintText: 'AR-XXXXXX',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              prefixIcon: const Icon(Icons.key_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.lightGray),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.lightGray),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.skyBlue, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) {
              if (!_isLoading && caseCodeController.text.trim().isNotEmpty) {
                _resumeChat(caseCodeController.text.trim().toUpperCase());
              }
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _isLoading
                      ? null
                      : () {
                        if (caseCodeController.text.trim().isNotEmpty) {
                          _resumeChat(
                            caseCodeController.text.trim().toUpperCase(),
                          );
                        }
                      },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.skyBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                elevation: 4,
                shadowColor: AppTheme.skyBlue.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Resume Chat',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInterface() {
    return Column(
      children: [
        // Warning banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.warningOrange.withValues(alpha: 0.1),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.warningOrange.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.warningOrange,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Case Code: $_currentCaseCode',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warningOrange,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 64,
                          color: AppTheme.mediumGray.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Start the conversation',
                          style: TextStyle(
                            color: AppTheme.mediumGray,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Messages are secure and anonymous.',
                          style: TextStyle(
                            color: AppTheme.mediumGray.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isFromAnonymous =
                          message['sender_type'] == 'anonymous';
                      return _buildMessageBubble(message, isFromAnonymous);
                    },
                  ),
        ),
        // Input area
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.transparent),
                  ),
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      isDense: true,
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: _isSending ? AppTheme.lightGray : AppTheme.skyBlue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.skyBlue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _isSending ? null : _sendMessage,
                  icon:
                      _isSending
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  tooltip: 'Send Message',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> message,
    bool isFromAnonymous,
  ) {
    final timestamp = DateTime.parse(message['created_at'] as String);
    final timeStr = DateFormat('HH:mm').format(timestamp);

    return Align(
      alignment: isFromAnonymous ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          crossAxisAlignment:
              isFromAnonymous
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isFromAnonymous ? AppTheme.skyBlue : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft:
                      isFromAnonymous
                          ? const Radius.circular(20)
                          : const Radius.circular(4),
                  bottomRight:
                      isFromAnonymous
                          ? const Radius.circular(4)
                          : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border:
                    isFromAnonymous
                        ? null
                        : Border.all(
                          color: AppTheme.lightGray.withValues(alpha: 0.5),
                        ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isFromAnonymous)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message['sender_type'] == 'counselor'
                            ? 'Counselor'
                            : 'Teacher',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.deepBlue,
                        ),
                      ),
                    ),
                  Text(
                    message['message'] as String,
                    style: TextStyle(
                      color: isFromAnonymous ? Colors.white : AppTheme.deepBlue,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment:
                  isFromAnonymous
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    color: AppTheme.mediumGray.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                ),
                if (isFromAnonymous) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 12,
                    color: AppTheme.skyBlue.withValues(alpha: 0.8),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
