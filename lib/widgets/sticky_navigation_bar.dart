import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../pages/about_page.dart';
import '../pages/anonymous_report_form_page.dart';
import '../pages/anonymous_report_tracker_page.dart';
import '../pages/contact_crisis_support_page.dart';
import '../pages/terms_condition_page.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../utils/toast_utils.dart';
import 'anonymous_chatbox.dart';
import 'ai_support_chatbox.dart';
import 'chat_hub.dart';

class StickyNavigationBar extends StatefulWidget {
  final Widget child;

  const StickyNavigationBar({super.key, required this.child});

  @override
  State<StickyNavigationBar> createState() => _StickyNavigationBarState();
}

class _StickyNavigationBarState extends State<StickyNavigationBar> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 50 && !_isScrolled) {
      setState(() => _isScrolled = true);
    } else if (_scrollController.offset <= 50 && _isScrolled) {
      setState(() => _isScrolled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    final isTablet = MediaQuery.of(context).size.width > 600 && !isWeb;

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Premium Navigation Bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _NavigationBarDelegate(
                child: _buildPremiumNavigationBar(context, isWeb, isTablet),
                isScrolled: _isScrolled,
              ),
            ),
            // Content
            SliverToBoxAdapter(child: widget.child),
          ],
        ),
        // Floating Chatboxes & Hub
        const AnonymousChatbox(),
        const AiSupportChatbox(),
        const ChatHub(),
      ],
    );
  }

  // Premium Navigation Bar with Glass-like Effect (matching home page)
  Widget _buildPremiumNavigationBar(
    BuildContext context,
    bool isWeb,
    bool isTablet,
  ) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal:
            isWeb
                ? 64
                : isTablet
                ? 48
                : 24,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color:
            _isScrolled
                ? Colors.white.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.98),
        boxShadow:
            _isScrolled
                ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
                : [],
        border: Border(
          bottom: BorderSide(
            color: AppTheme.lightGray.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & App Name
          GestureDetector(
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Row(
              children: [
                Image.asset(
                  'assets/img/favicon_fcu/android-chrome-192x192.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 16),
                const Text(
                  'FCU Guidance',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepBlue,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // Navigation Links
          if (isWeb)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildNavLink(context, 'About', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AboutPage(),
                            settings: const RouteSettings(name: '/about'),
                          ),
                        );
                      }, '/about'),
                      const SizedBox(width: 8),
                      _buildNavLink(context, 'Anonymous Report', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AnonymousReportFormPage(),
                            settings: const RouteSettings(
                              name: '/anonymous-report',
                            ),
                          ),
                        );
                      }, '/anonymous-report'),
                      const SizedBox(width: 8),
                      _buildNavLink(
                        context,
                        'Anonymous Report Tracker',
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => const AnonymousReportTrackerPage(),
                              settings: const RouteSettings(
                                name: '/anonymous-report-tracker',
                              ),
                            ),
                          );
                        },
                        '/anonymous-report-tracker',
                      ),
                      const SizedBox(width: 8),
                      _buildNavLink(context, 'Contact Support', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContactCrisisSupportPage(),
                            settings: const RouteSettings(
                              name: '/contact-support',
                            ),
                          ),
                        );
                      }, '/contact-support'),
                      const SizedBox(width: 8),
                      _buildNavLink(context, 'Terms and Conditions', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TermsConditionPage(),
                            settings: const RouteSettings(
                              name: '/terms-conditions',
                            ),
                          ),
                        );
                      }, '/terms-conditions'),
                    ],
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: AppTheme.deepBlue,
                size: 28,
              ),
              onPressed: () => _showMobileMenu(context),
            ),

          // Auth Buttons
          if (isWeb)
            if (user != null)
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Sign Out'),
                              content: const Text(
                                'Are you sure you want to sign out?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    if (context.mounted) {
                                      ToastUtils.showSuccess(
                                        context,
                                        'Signed out successfully',
                                      );
                                    }
                                    await authProvider.signOut();
                                  },
                                  child: const Text(
                                    'Sign Out',
                                    style: TextStyle(color: AppTheme.errorRed),
                                  ),
                                ),
                              ],
                            ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      side: const BorderSide(color: AppTheme.errorRed),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Sign Out'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to dashboard based on role
                      String path = '/login';
                      switch (user.role) {
                        case UserRole.student:
                          path = '/student/dashboard';
                          break;
                        case UserRole.teacher:
                          path = '/teacher/dashboard';
                          break;
                        case UserRole.counselor:
                          path = '/counselor/dashboard';
                          break;
                        case UserRole.dean:
                        case UserRole.admin:
                          path = '/admin/dashboard';
                          break;
                      }
                      context.go(path);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.skyBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.dashboard_rounded, size: 18),
                    label: const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              )
            else
              ElevatedButton(
                onPressed: () => context.go('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.skyBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
        ],
      ),
    ).fadeIn();
  }

  bool _isActivePage(BuildContext context, String routeName) {
    final route = ModalRoute.of(context);
    if (route == null) return false;

    final currentRouteName = route.settings.name;
    if (currentRouteName == routeName) return true;

    // Fallback: Check if route name contains the key identifier
    if (currentRouteName != null) {
      if (routeName == '/about' && currentRouteName.contains('about')) {
        return true;
      }
      if (routeName == '/anonymous-report' &&
          currentRouteName.contains('anonymous-report') &&
          !currentRouteName.contains('tracker')) {
        return true;
      }
      if (routeName == '/anonymous-report-tracker' &&
          currentRouteName.contains('tracker')) {
        return true;
      }
      if (routeName == '/contact-support' &&
          currentRouteName.contains('contact')) {
        return true;
      }
      if (routeName == '/terms-conditions' &&
          (currentRouteName.contains('terms') ||
              currentRouteName.contains('condition'))) {
        return true;
      }
    }

    return false;
  }

  Widget _buildNavLink(
    BuildContext context,
    String text,
    VoidCallback onTap,
    String routeName,
  ) {
    final isActive = _isActivePage(context, routeName);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isActive ? 6 : 8,
          ),
          decoration:
              isActive
                  ? BoxDecoration(
                    color: AppTheme.skyBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  )
                  : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? AppTheme.skyBlue : AppTheme.deepBlue,
                  letterSpacing: 0.1,
                ),
              ),
              if (isActive)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  height: 2,
                  width: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.skyBlue,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMobileMenu(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.report_outlined),
                  title: const Text('Anonymous Report Form'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnonymousReportFormPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.track_changes_outlined),
                  title: const Text('Anonymous Report Tracker'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnonymousReportTrackerPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: const Text('Contact / Crisis Support'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContactCrisisSupportPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms & Conditions'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TermsConditionPage(),
                      ),
                    );
                  },
                ),
                const Divider(),
                if (user != null) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.dashboard_rounded,
                      color: AppTheme.skyBlue,
                    ),
                    title: const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.skyBlue,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      String path = '/login';
                      switch (user.role) {
                        case UserRole.student:
                          path = '/student/dashboard';
                          break;
                        case UserRole.teacher:
                          path = '/teacher/dashboard';
                          break;
                        case UserRole.counselor:
                          path = '/counselor/dashboard';
                          break;
                        case UserRole.dean:
                        case UserRole.admin:
                          path = '/admin/dashboard';
                          break;
                      }
                      context.go(path);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppTheme.errorRed),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: AppTheme.errorRed),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      if (context.mounted) {
                        ToastUtils.showSuccess(
                          context,
                          'Signed out successfully',
                        );
                      }
                      await authProvider.signOut();
                    },
                  ),
                ] else
                  ListTile(
                    leading: const Icon(Icons.login),
                    title: const Text('Sign In'),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/login');
                    },
                  ),
              ],
            ),
          ),
    );
  }
}

// Delegate for pinned navigation bar
class _NavigationBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final bool isScrolled;

  _NavigationBarDelegate({required this.child, this.isScrolled = false});

  @override
  double get minExtent => 80;

  @override
  double get maxExtent => 80;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _NavigationBarDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.isScrolled != isScrolled;
  }
}
