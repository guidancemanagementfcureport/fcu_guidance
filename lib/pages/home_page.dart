import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../widgets/anonymous_chatbox.dart';
import '../widgets/ai_support_chatbox.dart';
import '../widgets/chat_hub.dart';
import 'about_page.dart';
import 'anonymous_report_form_page.dart';
import 'anonymous_report_tracker_page.dart';
import 'contact_crisis_support_page.dart';
import 'terms_condition_page.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../utils/toast_utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

    return Scaffold(
      body: Stack(
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

              // Hero Section
              SliverToBoxAdapter(
                child: _buildHeroSection(context, isWeb, isTablet),
              ),

              // Value Proposition Section
              SliverToBoxAdapter(
                child: _buildValuePropositionSection(context, isWeb, isTablet),
              ),

              // Guided Workflow Section
              SliverToBoxAdapter(
                child: _buildGuidedWorkflowSection(context, isWeb, isTablet),
              ),

              // Trust & Credibility Section
              SliverToBoxAdapter(
                child: _buildTrustSection(context, isWeb, isTablet),
              ),

              // Call-to-Action Section
              SliverToBoxAdapter(
                child: _buildCTASection(context, isWeb, isTablet),
              ),

              // Institutional Footer
              SliverToBoxAdapter(
                child: _buildInstitutionalFooter(context, isWeb, isTablet),
              ),
            ],
          ),
          // Floating Chatboxes & Hub
          const AnonymousChatbox(),
          const AiSupportChatbox(),
          const ChatHub(),
        ],
      ),
    );
  }

  // Premium Navigation Bar with Glass-like Effect
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
          Row(
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
                          path = '/dean/dashboard';
                          break;
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

  // High-Impact Hero Section
  Widget _buildHeroSection(BuildContext context, bool isWeb, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.deepBlue,
            AppTheme.mediumBlue,
            AppTheme.skyBlue.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Soft lighting effect
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal:
                  isWeb
                      ? 80
                      : isTablet
                      ? 48
                      : 24,
              vertical:
                  isWeb
                      ? 100
                      : isTablet
                      ? 80
                      : 60,
            ),
            child:
                isWeb
                    ? Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Support Your Students\nWhere They Need It Most',
                                style: TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.1,
                                  letterSpacing: -1,
                                ),
                              ).fadeInSlideUp(),
                              const SizedBox(height: 28),
                              const Text(
                                'A comprehensive, secure platform for managing student reports, counseling sessions, and guidance resources. Built with trust, designed for support.',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                  height: 1.7,
                                  letterSpacing: 0.2,
                                ),
                              ).fadeInSlideUp(delay: 200.ms),
                              const SizedBox(height: 48),
                              Wrap(
                                spacing: 20,
                                runSpacing: 20,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => context.go('/login'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppTheme.skyBlue,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 40,
                                        vertical: 18,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Get Started',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const AboutPage(),
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 40,
                                        vertical: 18,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text(
                                      'Learn More',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ).fadeInSlideUp(delay: 400.ms),
                            ],
                          ),
                        ),
                        const SizedBox(width: 60),
                        // Guidance Illustration
                        Container(
                          width: 500,
                          height: 600,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Image.asset(
                              'assets/img/home page.png',
                              width: 500,
                              height: 600,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 500,
                                  height: 600,
                                  color: Colors.white.withValues(alpha: 0.1),
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: Colors.white70,
                                      size: 64,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ).fadeInSlideUp(delay: 300.ms),
                      ],
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Support Your Students\nWhere They Need It Most',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ).fadeInSlideUp(),
                        const SizedBox(height: 20),
                        const Text(
                          'A comprehensive, secure platform for managing student reports, counseling sessions, and guidance resources.',
                          style: TextStyle(
                            fontSize: 17,
                            color: Colors.white,
                            height: 1.6,
                          ),
                        ).fadeInSlideUp(delay: 200.ms),
                        const SizedBox(height: 40),
                        // Guidance Illustration (Mobile)
                        Center(
                          child: Container(
                            width: 300,
                            height: 240,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/img/home page.png',
                                width: 300,
                                height: 240,
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 300,
                                    height: 240,
                                    color: Colors.white.withValues(alpha: 0.1),
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        color: Colors.white70,
                                        size: 48,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ).fadeInSlideUp(delay: 300.ms),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => context.go('/login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.skyBlue,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ).fadeInSlideUp(delay: 400.ms),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  // Value Proposition Section
  Widget _buildValuePropositionSection(
    BuildContext context,
    bool isWeb,
    bool isTablet,
  ) {
    final valueBlocks = [
      {
        'icon': Icons.shield_rounded,
        'title': 'Student Safety & Confidentiality',
        'description':
            'Enterprise-grade security ensures all student information and reports are handled with the utmost confidentiality and protection.',
      },
      {
        'icon': Icons.work_rounded,
        'title': 'Structured Guidance Workflow',
        'description':
            'Streamlined processes from report submission to resolution, ensuring every student receives timely and appropriate support.',
      },
      {
        'icon': Icons.track_changes_rounded,
        'title': 'Real-Time Monitoring & Support',
        'description':
            'Track progress, monitor cases, and provide support in real-time with comprehensive dashboards and notifications.',
      },
      {
        'icon': Icons.people_rounded,
        'title': 'Professional Counselor Management',
        'description':
            'Empower counselors with tools to manage cases efficiently, maintain detailed records, and deliver quality guidance services.',
      },
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal:
            isWeb
                ? 80
                : isTablet
                ? 48
                : 24,
        vertical:
            isWeb
                ? 100
                : isTablet
                ? 80
                : 60,
      ),
      child: Column(
        children: [
          Text(
            'WHY IT MATTERS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.skyBlue,
              letterSpacing: 2,
            ),
          ).fadeIn(),
          const SizedBox(height: 20),
          Text(
            'Built for Trust, Designed for Support',
            style: TextStyle(
              fontSize:
                  isWeb
                      ? 44
                      : isTablet
                      ? 36
                      : 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
              height: 1.2,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ).fadeInSlideUp(delay: 100.ms),
          const SizedBox(height: 16),
          SizedBox(
            width: isWeb ? 600 : double.infinity,
            child: Text(
              'A comprehensive platform that brings together students, teachers, and counselors in a secure, structured environment.',
              style: TextStyle(
                fontSize: isWeb ? 18 : 16,
                color: AppTheme.darkGray,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ).fadeInSlideUp(delay: 200.ms),
          const SizedBox(height: 60),
          isWeb
              ? GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 32,
                  mainAxisSpacing: 32,
                  childAspectRatio: 1.1,
                ),
                itemCount: valueBlocks.length,
                itemBuilder: (context, index) {
                  return _buildValueBlock(
                    valueBlocks[index]['icon'] as IconData,
                    valueBlocks[index]['title'] as String,
                    valueBlocks[index]['description'] as String,
                    index,
                  );
                },
              )
              : Column(
                children:
                    valueBlocks.asMap().entries.map((entry) {
                      final index = entry.key;
                      final block = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _buildValueBlock(
                          block['icon'] as IconData,
                          block['title'] as String,
                          block['description'] as String,
                          index,
                        ),
                      );
                    }).toList(),
              ),
        ],
      ),
    );
  }

  Widget _buildValueBlock(
    IconData icon,
    String title,
    String description,
    int index,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.lightGray, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.skyBlue.withValues(alpha: 0.1),
                  AppTheme.mediumBlue.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 32, color: AppTheme.skyBlue),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.darkGray,
              height: 1.6,
            ),
          ),
        ],
      ),
    ).fadeInSlideUp(delay: Duration(milliseconds: 100 * index));
  }

  // Guided Workflow Section
  Widget _buildGuidedWorkflowSection(
    BuildContext context,
    bool isWeb,
    bool isTablet,
  ) {
    final steps = [
      {
        'number': '1',
        'title': 'Student Submits Report',
        'description':
            'Students can submit reports securely through an intuitive interface, with options for anonymous reporting.',
        'icon': Icons.description_rounded,
      },
      {
        'number': '2',
        'title': 'Teacher Reviews & Monitors',
        'description':
            'Teachers receive notifications and can review, monitor, and track the progress of student reports.',
        'icon': Icons.visibility_rounded,
      },
      {
        'number': '3',
        'title': 'Dean Reviews & Approves',
        'description':
            'Deans have oversight, reviewing sensitive reports and ensuring proper procedures are followed for resolution.',
        'icon': Icons.admin_panel_settings_rounded,
      },
      {
        'number': '4',
        'title': 'Counselor Provides Guidance',
        'description':
            'Professional counselors access cases, provide guidance, schedule sessions, and maintain detailed records.',
        'icon': Icons.support_agent_rounded,
      },
      {
        'number': '5',
        'title': 'Student Tracks Progress',
        'description':
            'Students can track their report status, view counseling schedules, and access guidance resources.',
        'icon': Icons.track_changes_rounded,
      },
    ];

    return Container(
      color: AppTheme.lightGray,
      padding: EdgeInsets.symmetric(
        horizontal:
            isWeb
                ? 80
                : isTablet
                ? 48
                : 24,
        vertical:
            isWeb
                ? 100
                : isTablet
                ? 80
                : 60,
      ),
      child: Column(
        children: [
          Text(
            'HOW IT WORKS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.skyBlue,
              letterSpacing: 2,
            ),
          ).fadeIn(),
          const SizedBox(height: 20),
          Text(
            'A Clear, Structured Process',
            style: TextStyle(
              fontSize:
                  isWeb
                      ? 44
                      : isTablet
                      ? 36
                      : 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
              height: 1.2,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ).fadeInSlideUp(delay: 100.ms),
          const SizedBox(height: 60),
          isWeb
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    steps.asMap().entries.map((entry) {
                      final index = entry.key;
                      final step = entry.value;
                      return Expanded(
                        child: Column(
                          children: [
                            _buildWorkflowStep(
                              step['number'] as String,
                              step['title'] as String,
                              step['description'] as String,
                              step['icon'] as IconData,
                              index,
                              steps.length,
                              isWeb: true,
                            ),
                            if (index < steps.length - 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: Container(
                                  width: 40,
                                  height: 2,
                                  color: AppTheme.skyBlue.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
              )
              : Column(
                children:
                    steps.asMap().entries.map((entry) {
                      final index = entry.key;
                      final step = entry.value;
                      return Column(
                        children: [
                          _buildWorkflowStep(
                            step['number'] as String,
                            step['title'] as String,
                            step['description'] as String,
                            step['icon'] as IconData,
                            index,
                            steps.length,
                            isWeb: false,
                          ),
                          if (index < steps.length - 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Container(
                                width: 2,
                                height: 40,
                                color: AppTheme.skyBlue.withValues(alpha: 0.3),
                              ),
                            ),
                        ],
                      );
                    }).toList(),
              ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStep(
    String number,
    String title,
    String description,
    IconData icon,
    int index,
    int total, {
    required bool isWeb,
  }) {
    return Column(
      children: [
        Container(
          width: isWeb ? 80 : 64,
          height: isWeb ? 80 : 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.skyBlue, AppTheme.mediumBlue],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.skyBlue.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: isWeb ? 32 : 28),
              const SizedBox(height: 4),
              Text(
                number,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ).fadeInSlideUp(delay: Duration(milliseconds: 100 * index)),
        const SizedBox(height: 24),
        Text(
          title,
          style: TextStyle(
            fontSize: isWeb ? 20 : 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.deepBlue,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWeb ? 0 : 16),
          child: Text(
            description,
            style: TextStyle(
              fontSize: isWeb ? 15 : 14,
              color: AppTheme.darkGray,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // Trust & Credibility Section
  Widget _buildTrustSection(BuildContext context, bool isWeb, bool isTablet) {
    final trustPoints = [
      {
        'icon': Icons.lock_rounded,
        'title': 'Confidentiality Assured',
        'description':
            'All reports and counseling sessions are handled with strict confidentiality protocols.',
      },
      {
        'icon': Icons.security_rounded,
        'title': 'Secure Handling',
        'description':
            'Enterprise-grade security measures protect all student data and communications.',
      },
      {
        'icon': Icons.verified_user_rounded,
        'title': 'Professional Oversight',
        'description':
            'All processes are supervised by qualified guidance counselors and administrators.',
      },
      {
        'icon': Icons.favorite_rounded,
        'title': 'Student-Focused Support',
        'description':
            'Every feature is designed with student wellbeing and support as the top priority.',
      },
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal:
            isWeb
                ? 80
                : isTablet
                ? 48
                : 24,
        vertical:
            isWeb
                ? 100
                : isTablet
                ? 80
                : 60,
      ),
      child: Column(
        children: [
          Text(
            'TRUST & CREDIBILITY',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.skyBlue,
              letterSpacing: 2,
            ),
          ).fadeIn(),
          const SizedBox(height: 20),
          Text(
            'Your Trust is Our Foundation',
            style: TextStyle(
              fontSize:
                  isWeb
                      ? 44
                      : isTablet
                      ? 36
                      : 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
              height: 1.2,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ).fadeInSlideUp(delay: 100.ms),
          const SizedBox(height: 16),
          SizedBox(
            width: isWeb ? 600 : double.infinity,
            child: Text(
              'We understand the sensitive nature of guidance and counseling. Our platform is built on principles of trust, security, and professional care.',
              style: TextStyle(
                fontSize: isWeb ? 18 : 16,
                color: AppTheme.darkGray,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ).fadeInSlideUp(delay: 200.ms),
          const SizedBox(height: 60),
          isWeb
              ? GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 32,
                  mainAxisSpacing: 32,
                  childAspectRatio: 1.1,
                ),
                itemCount: trustPoints.length,
                itemBuilder: (context, index) {
                  return _buildTrustPoint(
                    trustPoints[index]['icon'] as IconData,
                    trustPoints[index]['title'] as String,
                    trustPoints[index]['description'] as String,
                    index,
                  );
                },
              )
              : Column(
                children:
                    trustPoints.asMap().entries.map((entry) {
                      final index = entry.key;
                      final point = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _buildTrustPoint(
                          point['icon'] as IconData,
                          point['title'] as String,
                          point['description'] as String,
                          index,
                        ),
                      );
                    }).toList(),
              ),
        ],
      ),
    );
  }

  Widget _buildTrustPoint(
    IconData icon,
    String title,
    String description,
    int index,
  ) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.paleBlue.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.skyBlue.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.skyBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 28, color: AppTheme.skyBlue),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.darkGray,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).fadeInSlideUp(delay: Duration(milliseconds: 100 * index));
  }

  // Call-to-Action Section
  Widget _buildCTASection(BuildContext context, bool isWeb, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.deepBlue, AppTheme.mediumBlue, AppTheme.skyBlue],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal:
            isWeb
                ? 80
                : isTablet
                ? 48
                : 24,
        vertical:
            isWeb
                ? 100
                : isTablet
                ? 80
                : 60,
      ),
      child: Column(
        children: [
          const Text(
            'Ready to Get Started?',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ).fadeInSlideUp(),
          const SizedBox(height: 20),
          SizedBox(
            width: isWeb ? 600 : double.infinity,
            child: const Text(
              'Join students, teachers, and counselors who trust FCU Guidance Management System for secure, professional support.',
              style: TextStyle(fontSize: 18, color: Colors.white, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ).fadeInSlideUp(delay: 200.ms),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AnonymousReportFormPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.skyBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Submit a Report',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (isWeb) const SizedBox(width: 20),
              if (isWeb)
                OutlinedButton(
                  onPressed: () => context.go('/login'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Sign In to Track Reports',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
            ],
          ).fadeInSlideUp(delay: 400.ms),
          if (!isWeb) const SizedBox(height: 16),
          if (!isWeb)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/login'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Sign In to Track Reports',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ).fadeInSlideUp(delay: 500.ms),
        ],
      ),
    );
  }

  // Institutional Footer
  Widget _buildInstitutionalFooter(
    BuildContext context,
    bool isWeb,
    bool isTablet,
  ) {
    return Container(
      color: AppTheme.deepBlue,
      padding: EdgeInsets.symmetric(
        horizontal:
            isWeb
                ? 80
                : isTablet
                ? 48
                : 24,
        vertical: isWeb ? 60 : 48,
      ),
      child: Column(
        children: [
          isWeb
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Brand Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/img/favicon_fcu/android-chrome-192x192.png',
                              width: 64,
                              height: 64,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'FCU Guidance',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Comprehensive guidance management system for students, teachers, and counselors. Built with trust, designed for support.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white70,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 60),
                  // Quick Links
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Links',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFooterLink(context, 'About', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutPage()),
                        );
                      }),
                      const SizedBox(height: 8),
                      _buildFooterLink(context, 'Anonymous Report', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AnonymousReportFormPage(),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      _buildFooterLink(context, 'Report Tracker', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AnonymousReportTrackerPage(),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      _buildFooterLink(context, 'Contact Support', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContactCrisisSupportPage(),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(width: 60),
                  // Contact Info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contact',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Guidance Office',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'fcu.guidance@gmail.com',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '621-0471 or 621-2318 loc. 140',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => context.go('/login'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.skyBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
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
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/img/favicon_fcu/android-chrome-192x192.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'FCU Guidance',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Comprehensive guidance management system for students, teachers, and counselors.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Quick Links',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFooterLink(context, 'About', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    );
                  }),
                  const SizedBox(height: 8),
                  _buildFooterLink(context, 'Anonymous Report', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnonymousReportFormPage(),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  _buildFooterLink(context, 'Report Tracker', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnonymousReportTrackerPage(),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  _buildFooterLink(context, 'Contact Support', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContactCrisisSupportPage(),
                      ),
                    );
                  }),
                  const SizedBox(height: 32),
                  const Text(
                    'Contact',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'fcu.guidance@gmail.com',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '621-0471 or 621-2318 loc. 140',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.skyBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          const SizedBox(height: 40),
          const Divider(color: Colors.white24),
          const SizedBox(height: 24),
          isWeb
              ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '© 2024 FCU Guidance Office. All rights reserved.',
                    style: TextStyle(fontSize: 13, color: Colors.white60),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TermsConditionPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Terms & Conditions',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ContactCrisisSupportPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Contact',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ],
              )
              : Column(
                children: [
                  const Text(
                    '© 2024 FCU Guidance Office. All rights reserved.',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TermsConditionPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Terms & Conditions',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContactCrisisSupportPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Contact',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(
    BuildContext context,
    String text,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
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
                      await authProvider.signOut();
                      if (context.mounted) {
                        ToastUtils.showSuccess(
                          context,
                          'Signed out successfully',
                        );
                      }
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
