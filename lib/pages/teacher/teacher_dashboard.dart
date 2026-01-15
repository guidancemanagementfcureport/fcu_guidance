import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/report_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_layout.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final _supabase = SupabaseService();
  bool _isLoading = true;
  int _openReports = 0;
  int _reportsToday = 0;
  int _settledReports = 0;
  List<ActivityItem> _activityItems = [];
  Timer? _activityRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadActivities();

    // Refresh when notifications arrive (real-time trigger)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationProvider = Provider.of<NotificationProvider>(
        context,
        listen: false,
      );
      notificationProvider.addListener(_onNotificationsChanged);
    });

    // Fallback periodic refresh
    _activityRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadActivities();
      }
    });
  }

  void _onNotificationsChanged() {
    if (mounted) {
      _loadActivities();
      _loadData(); // Also refresh stats
    }
  }

  @override
  void dispose() {
    // Note: in a real app, you'd want to remove the listener too,
    // but NotificationProvider is usually global and lives as long as the session.
    // To be safe, we can try to get it if still mounted.
    try {
      final notificationProvider = Provider.of<NotificationProvider>(
        context,
        listen: false,
      );
      notificationProvider.removeListener(_onNotificationsChanged);
    } catch (_) {}

    _activityRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final teacherId = authProvider.currentUser?.id;

      if (teacherId != null) {
        // Fetch counts in parallel
        final results = await Future.wait([
          _supabase.countTeacherReports(teacherId: teacherId, openOnly: true),
          _supabase.countReportsToday(teacherId: teacherId),
          _supabase.countTeacherReports(
            teacherId: teacherId,
            status: ReportStatus.settled,
          ),
        ]);

        if (mounted) {
          setState(() {
            _openReports = results[0];
            _reportsToday = results[1];
            _settledReports = results[2];
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

  String _getReportsDeltaText() {
    if (_reportsToday > 0) {
      return '+$_reportsToday today';
    }
    return '';
  }

  Future<void> _loadActivities() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final teacherId = authProvider.currentUser?.id;

      if (teacherId == null) return;

      final activities = await _supabase.getTeacherRecentActivities(
        teacherId: teacherId,
        limit: 5,
      );

      if (mounted) {
        setState(() {
          _activityItems =
              activities.map((activity) {
                final timestamp = DateTime.parse(
                  activity['timestamp'] as String,
                );
                final timeAgo = _formatTimeAgo(timestamp);

                String title;
                String subtitle;
                Color color;

                if (activity['type'] == 'report') {
                  final action = activity['action'] as String;
                  final role = activity['role'] as String;

                  switch (action) {
                    case 'submitted':
                      title = 'Report assigned';
                      subtitle =
                          role == 'student'
                              ? 'Student submitted a new report'
                              : 'New report submitted';
                      color = AppTheme.skyBlue;
                      break;
                    case 'reviewed':
                      title = 'Report reviewed';
                      subtitle = 'You reviewed a student report';
                      color = AppTheme.infoBlue;
                      break;
                    case 'forwarded':
                      title = 'Report forwarded';
                      subtitle = 'Report forwarded to counselor';
                      color = AppTheme.warningOrange;
                      break;
                    case 'confirmed':
                      title = 'Case confirmed';
                      subtitle = 'Counselor confirmed the case';
                      color = AppTheme.successGreen;
                      break;
                    case 'settled':
                      title = 'Case settled';
                      subtitle = 'Report has been resolved';
                      color = AppTheme.successGreen;
                      break;
                    default:
                      title = 'Case activity';
                      subtitle = 'Activity on report';
                      color = AppTheme.mediumGray;
                  }
                } else {
                  title = 'Case activity';
                  subtitle = 'Activity on case';
                  color = AppTheme.mediumGray;
                }

                return ActivityItem(
                  title: title,
                  subtitle: subtitle,
                  time: timeAgo,
                  color: color,
                );
              }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading activities: $e');
    }
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat('MMM dd').format(timestamp);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
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
                title: 'Teacher Dashboard',
                subtitle: 'Monitor cases and student incident reports',
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
                          const SizedBox(height: 20),
                          _buildInsights(constraints),
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
    // Account for padding
    final double contentWidth = constraints.maxWidth - 48;

    final bool isDesktop = contentWidth >= 850;
    final bool isTablet = contentWidth >= 550 && !isDesktop;

    double cardWidth;
    if (isDesktop) {
      cardWidth = (contentWidth - 32) / 3;
    } else if (isTablet) {
      cardWidth = (contentWidth - 16) / 2;
    } else {
      cardWidth = contentWidth;
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: cardWidth,
          child: _TeacherStatCard(
            label: 'Open Reports',
            value: '$_openReports',
            delta: _getReportsDeltaText(),
            icon: Icons.assignment_late_rounded,
            color: AppTheme.skyBlue,
            gradient: const [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _TeacherStatCard(
            label: 'Reports Today',
            value: '$_reportsToday',
            delta: '',
            icon: Icons.today_rounded,
            color: AppTheme.infoBlue,
            gradient: const [Color(0xFF3B82F6), Color(0xFF60A5FA)],
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _TeacherStatCard(
            label: 'Settled Reports',
            value: '$_settledReports',
            delta: '',
            icon: Icons.check_circle_rounded,
            color: AppTheme.successGreen,
            gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
          ),
        ),
      ],
    );
  }

  Widget _buildInsights(BoxConstraints constraints) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            offset: const Offset(0, 4),
            blurRadius: 20,
          ),
        ],
        border: Border.all(color: AppTheme.lightBlue.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: AppTheme.deepBlue, size: 24),
              SizedBox(width: 12),
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_activityItems.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No recent activity',
                  style: TextStyle(color: AppTheme.mediumGray),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activityItems.length,
              separatorBuilder:
                  (_, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      height: 1,
                      color: AppTheme.lightGray.withValues(alpha: 0.5),
                    ),
                  ),
              itemBuilder: (context, index) {
                final item = _activityItems[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_active_rounded,
                        color: item.color,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.deepBlue,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.mediumGray,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.time,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.mediumGray.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TeacherStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String delta;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  const _TeacherStatCard({
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
