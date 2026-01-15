import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/report_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final _supabase = SupabaseService();
  bool _isLoading = true;
  int _openReports = 0;
  int _counselingRequests = 0;
  int _resolvedCases = 0;
  int _reportsToday = 0;
  int _counselingToday = 0;
  int _resolvedThisWeek = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final studentId = authProvider.currentUser?.id;

      if (studentId != null) {
        // Fetch counts in parallel
        final results = await Future.wait([
          _supabase.countStudentReports(studentId: studentId, openOnly: true),
          _supabase.countStudentCounselingRequests(
            studentId: studentId,
            activeOnly: true,
          ),
          _supabase.countStudentReports(
            studentId: studentId,
            status: ReportStatus.settled,
          ),
          _supabase.countReportsToday(studentId: studentId),
          _supabase.countCounselingRequestsToday(studentId: studentId),
          _countResolvedThisWeek(studentId),
        ]);

        if (mounted) {
          setState(() {
            _openReports = results[0];
            _counselingRequests = results[1];
            _resolvedCases = results[2];
            _reportsToday = results[3];
            _counselingToday = results[4];
            _resolvedThisWeek = results[5];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<int> _countResolvedThisWeek(String studentId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      );

      final reports = await _supabase.getReportsWithFilters(
        studentId: studentId,
        status: ReportStatus.settled,
        startDate: weekStartDate,
      );

      return reports.length;
    } catch (e) {
      return 0;
    }
  }

  String _getDeltaText() {
    if (_reportsToday > 0) {
      return '+$_reportsToday today';
    }
    return '';
  }

  String _getCounselingDeltaText() {
    if (_counselingToday > 0) {
      return '+$_counselingToday today';
    }
    return '';
  }

  String _getResolvedDeltaText() {
    if (_resolvedThisWeek > 0) {
      return '+$_resolvedThisWeek this week';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return ResponsiveSidebar(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: AppTheme.softBlueGradientDecoration,
          child: Column(
            children: [
              const ModernDashboardHeader(
                title: 'Student Dashboard',
                subtitle: 'Track cases, request support, and manage reports',
                icon: Icons.dashboard_rounded,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _isLoading
                              ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                              : _buildStats(constraints),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats(BoxConstraints constraints) {
    // Account for the horizontal padding of the SingleChildScrollView (24 left + 24 right = 48)
    final double contentWidth = constraints.maxWidth - 48;

    // Determine layout based on available content width
    // We want 3 cards in a row for desktop.
    // Ensure we have enough space for 3 cards of at least ~250px width?
    // 250 * 3 + 32 (gaps) = 782.
    // Let's us 850 as a safe breakpoint for 3 columns.
    final bool isDesktop = contentWidth >= 850;
    final bool isTablet = contentWidth >= 550 && !isDesktop;

    double cardWidth;
    if (isDesktop) {
      // 3 cards in a row: (Total - 2 gaps) / 3
      cardWidth = (contentWidth - 32) / 3;
    } else if (isTablet) {
      // 2 cards in a row: (Total - 1 gap) / 2
      cardWidth = (contentWidth - 16) / 2;
    } else {
      // 1 card in a row
      cardWidth = contentWidth;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: cardWidth,
              child: _StudentStatCard(
                label: 'Open Reports',
                value: '$_openReports',
                delta: _getDeltaText(),
                icon: Icons.report_gmailerrorred_rounded,
                color: AppTheme.skyBlue,
                gradient: const [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _StudentStatCard(
                label: 'Counseling Requests',
                value: '$_counselingRequests',
                delta: _getCounselingDeltaText(),
                icon: Icons.psychology_rounded,
                color: AppTheme.warningOrange,
                gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _StudentStatCard(
                label: 'Resolved Cases',
                value: '$_resolvedCases',
                delta: _getResolvedDeltaText(),
                icon: Icons.check_circle_rounded,
                color: AppTheme.successGreen,
                gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.deepBlue,
          ),
        ),
        const SizedBox(height: 16),
        _buildQuickActions(contentWidth),
      ],
    );
  }

  Widget _buildQuickActions(double contentWidth) {
    // Responsive Quick Actions
    // If desktop (large), try to fit 4 in a row or 2.
    // If we have 4 items:
    // Width > ~1000 -> 4 columns
    // Width > ~600 -> 2 columns
    // Else -> 1 column

    double actionWidth;
    if (contentWidth > 1100) {
      // 4 in a row: (Total - 3 gaps) / 4
      actionWidth = (contentWidth - 48) / 4;
    } else if (contentWidth > 600) {
      // 2 in a row: (Total - 1 gap) / 2
      actionWidth = (contentWidth - 16) / 2;
    } else {
      // Full width
      actionWidth = contentWidth;
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _QuickActionCard(
          title: 'Submit Report',
          subtitle: 'File a new incident report',
          icon: Icons.add_circle_outline_rounded,
          color: AppTheme.skyBlue,
          onTap: () => context.go('/student/submit-report'),
          width: actionWidth,
        ),
        _QuickActionCard(
          title: 'Request Counseling',
          subtitle: 'Schedule a session',
          icon: Icons.calendar_today_rounded,
          color: AppTheme.warningOrange,
          onTap: () => context.go('/student/request-counseling'),
          width: actionWidth,
        ),
        _QuickActionCard(
          title: 'View Status',
          subtitle: 'Check your case updates',
          icon: Icons.history_rounded,
          color: AppTheme.mediumBlue,
          onTap: () => context.go('/student/view-report-status'),
          width: actionWidth,
        ),
        _QuickActionCard(
          title: 'Help & Support',
          subtitle: 'FAQs and guidance',
          icon: Icons.help_outline_rounded,
          color: const Color(0xFF8B5CF6),
          onTap: () => context.go('/student/help-support'),
          width: actionWidth,
        ),
      ],
    );
  }
}

class _StudentStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String delta;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  const _StudentStatCard({
    required this.label,
    required this.value,
    required this.delta,
    required this.icon,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -15,
              top: -15,
              child: Icon(
                icon,
                size: 100,
                color: color.withValues(alpha: 0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradient),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 24),
                      ),
                      if (delta.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            delta,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepBlue,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double width;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.lightBlue.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppTheme.mediumGray,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
