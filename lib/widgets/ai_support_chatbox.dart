import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/support_chat_model.dart';
import '../providers/support_chat_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class AiSupportChatbox extends StatefulWidget {
  const AiSupportChatbox({super.key});

  @override
  State<AiSupportChatbox> createState() => _AiSupportChatboxState();
}

class _AiSupportChatboxState extends State<AiSupportChatbox> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showDisclaimer = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSession();
    });
  }

  Future<void> _initializeSession() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<SupportChatProvider>(
      context,
      listen: false,
    );

    final user = authProvider.currentUser;
    chatProvider.setEmergencyCallHandler(_triggerCall);
    await chatProvider.initSession(
      userId: user?.id,
      userName: user?.fullName ?? 'Anonymous Reporter',
    );
  }

  Future<void> _triggerCall() async {
    final Uri launchUri = Uri(scheme: 'tel', path: '6210471');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<SupportChatProvider>(
      context,
      listen: false,
    );

    final user = authProvider.currentUser;
    await chatProvider.sendMessage(
      text,
      senderId: user?.id,
      senderRole: 'student', // Students use the homepage chat
    );

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<SupportChatProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (!chatProvider.isOpen) return const SizedBox.shrink();

    // Detect user mismatch (e.g. just signed out or signed in)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final sessionStudentId = chatProvider.currentSession?.studentId;

    if (sessionStudentId != currentUser?.id && !chatProvider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeSession();
      });
    }

    if (chatProvider.isAiThinking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }

    return _buildChatWindow(chatProvider, isMobile);
  }

  Widget _buildChatWindow(SupportChatProvider provider, bool isMobile) {
    return Positioned(
      bottom: isMobile ? 0 : 20,
      right: isMobile ? 0 : 20,
      child: Material(
        elevation: 20,
        borderRadius: BorderRadius.circular(isMobile ? 0 : 24),
        child: Container(
          width: isMobile ? MediaQuery.of(context).size.width : 400,
          height: isMobile ? MediaQuery.of(context).size.height : 600,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 0 : 24),
            border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              _buildHeader(provider, isMobile),
              if (_showDisclaimer) _buildDisclaimer(),
              Expanded(child: _buildMessageList(provider)),
              _buildInputArea(provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(SupportChatProvider provider, bool isMobile) {
    final status =
        provider.currentSession?.status ?? SupportSessionStatus.aiActive;
    final isAi = status == SupportSessionStatus.aiActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.deepBlue, AppTheme.skyBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isMobile ? 0 : 24),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Icon(
              isAi ? Icons.smart_toy_outlined : Icons.person_outline,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Guidance Support Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isAi ? Colors.yellow : Colors.greenAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isAi ? Colors.yellow : Colors.greenAccent)
                                .withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status.displayName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => provider.toggleChat(),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.skyBlue.withValues(alpha: 0.05),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppTheme.skyBlue),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'This chat may be temporarily handled by an AI assistant until a counselor responds.',
              style: TextStyle(fontSize: 11, color: AppTheme.mediumGray),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showDisclaimer = false),
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppTheme.mediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(SupportChatProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.messages.isEmpty && !provider.isAiThinking) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: AppTheme.lightGray,
            ),
            const SizedBox(height: 16),
            const Text(
              'How can we help you today?',
              style: TextStyle(
                color: AppTheme.mediumGray,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: provider.messages.length + (provider.isAiThinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == provider.messages.length) {
          return _buildThinkingBubble();
        }
        final message = provider.messages[index];
        final isMe = message.senderRole == 'student';
        return _buildMessageBubble(message, isMe);
      },
    );
  }

  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.smart_toy, size: 12, color: AppTheme.skyBlue),
                const SizedBox(width: 4),
                const Text(
                  'Guidance Assistant (Automated)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.skyBlue,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.zero,
                bottomRight: Radius.circular(16),
              ),
            ),
            child: SizedBox(
              width: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (index) {
                  return _ThinkingDot(index: index);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(SupportMessageModel message, bool isMe) {
    final isAi = message.senderRole == 'ai';
    final timeStr = DateFormat('h:mm a').format(message.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAi ? Icons.smart_toy : Icons.support_agent,
                    size: 12,
                    color: AppTheme.skyBlue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isAi ? 'Guidance Assistant (Automated)' : 'Counselor',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.skyBlue,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            decoration: BoxDecoration(
              color:
                  isMe
                      ? AppTheme.deepBlue
                      : (isAi
                          ? Colors.grey.shade100
                          : AppTheme.skyBlue.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.message.replaceAll('[EMERGENCY_CALL]', '').trim(),
                  style: TextStyle(
                    color: isMe ? Colors.white : AppTheme.deepBlue,
                    fontSize: 14,
                  ),
                ),
                if (message.message.contains('[EMERGENCY_CALL]'))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final Uri launchUri = Uri(
                          scheme: 'tel',
                          path: '6210471',
                        );
                        if (await canLaunchUrl(launchUri)) {
                          await launchUrl(launchUri);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(Icons.phone_in_talk, size: 18),
                      label: const Text('Call Guidance Office'),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: (isMe ? Colors.white : AppTheme.mediumGray)
                            .withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(SupportChatProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.lightGray.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.lightGray),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type your concern here...',
                  border: InputBorder.none,
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppTheme.deepBlue,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingDot extends StatefulWidget {
  final int index;
  const _ThinkingDot({required this.index});

  @override
  State<_ThinkingDot> createState() => _ThinkingDotState();
}

class _ThinkingDotState extends State<_ThinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    Future.delayed(Duration(milliseconds: widget.index * 200), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 6,
          height: 6,
          margin: EdgeInsets.only(bottom: _animation.value * 6),
          decoration: const BoxDecoration(
            color: AppTheme.skyBlue,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
