import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/anonymous_chat_provider.dart';
import '../providers/support_chat_provider.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';

class ChatHub extends StatefulWidget {
  const ChatHub({super.key});

  @override
  State<ChatHub> createState() => _ChatHubState();
}

class _ChatHubState extends State<ChatHub> with SingleTickerProviderStateMixin {
  bool _isMenuOpen = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final anonProvider = Provider.of<AnonymousChatProvider>(context);
    final supportProvider = Provider.of<SupportChatProvider>(context);
    
    // If a chat window is already open, hide the hub button
    if (anonProvider.isOpen || supportProvider.isOpen) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 20,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Sub-menu items
          SizeTransition(
            sizeFactor: _expandAnimation,
            axis: Axis.vertical,
            child: FadeTransition(
              opacity: _expandAnimation,
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.support_agent_rounded,
                    label: 'Guidance Support (AI)',
                    color: AppTheme.deepBlue,
                    onTap: () {
                      _toggleMenu();
                      supportProvider.toggleChat();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Anonymous Chat',
                    color: AppTheme.skyBlue,
                    onTap: () {
                      _toggleMenu();
                      anonProvider.toggleChat(open: true);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // Main Toggle Button
          FloatingActionButton.extended(
            onPressed: _toggleMenu,
            backgroundColor: AppTheme.deepBlue,
            elevation: 8,
            icon: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _controller,
              color: Colors.white,
            ),
            label: Text(
              _isMenuOpen ? 'Close Hub' : 'Chat Hub',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ).fadeIn(),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 18,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
