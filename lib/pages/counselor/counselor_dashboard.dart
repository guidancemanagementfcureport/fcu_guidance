import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/report_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';

class CounselorDashboard extends StatefulWidget {
  const CounselorDashboard({super.key});

  @override
  State<CounselorDashboard> createState() => _CounselorDashboardState();
}

class _CounselorDashboardState extends State<CounselorDashboard> {
  final _supabase = SupabaseService();
  bool _isLoading = true;
  int _totalRecords = 0;
  int _newReportsToday = 0;
  int _pendingForwardedCount = 0;
  int _resolvedCases = 0;
  int _resolvedThisWeek = 0;

  List<ActivityItem> _timelineItems = [];
  List<ActivityItem> _recentActivityItems = [];
  Timer? _activityRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadActivities();
    // Refresh activities every 30 seconds for real-time updates
    _activityRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadActivities();
      }
    });
  }

  @override
  void dispose() {
    _activityRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final counselorId = authProvider.currentUser?.id;

      if (counselorId != null) {
        // Fetch counts in parallel
        final results = await Future.wait([
          _supabase.getCounselorAllReports(counselorId),
          _supabase.countCounselorCases(
            counselorId: counselorId,
            status: ReportStatus.settled,
          ),
          _countResolvedThisWeek(counselorId),
        ]);

        if (mounted) {
          final reports = results[0] as List<ReportModel>;
          final today = DateTime.now();
          final startOfDay = DateTime(today.year, today.month, today.day);

          setState(() {
            _totalRecords = reports.length;
            _newReportsToday =
                reports.where((r) => r.createdAt.isAfter(startOfDay)).length;
            _pendingForwardedCount =
                reports.where((r) => r.status == ReportStatus.forwarded).length;
            _resolvedCases = results[1] as int;
            _resolvedThisWeek = results[2] as int;
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

  Future<int> _countResolvedThisWeek(String counselorId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      );

      final reports = await _supabase.getReportsWithFilters(
        counselorId: counselorId,
        status: ReportStatus.settled,
        startDate: weekStartDate,
      );

      return reports.length;
    } catch (e) {
      return 0;
    }
  }

  String _getTotalRecordsDeltaText() {
    if (_totalRecords > 0) {
      return '+$_totalRecords';
    }
    return '';
  }

  String _getResolvedDeltaText() {
    if (_resolvedThisWeek > 0) {
      return '+$_resolvedThisWeek';
    }
    return '';
  }

  String _getNewReportsDeltaText() {
    if (_newReportsToday > 0) {
      return '+$_newReportsToday';
    }
    return '';
  }

  Future<void> _loadActivities() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final counselorId = authProvider.currentUser?.id;

      if (counselorId == null) return;

      final reports = await _supabase.getCounselorAllReports(counselorId);
      final recentReports = reports.take(5).toList();

      final activities = await _supabase.getCounselorRecentActivities(
        counselorId: counselorId,
        limit: 5,
      );

      if (mounted) {
        setState(() {
          _timelineItems =
              recentReports.map((report) {
                final timestamp = report.updatedAt;
                final timeAgo = _formatTimeAgo(timestamp);

                String title =
                    report.isAnonymous
                        ? (report.trackingId ??
                            'ANON-${report.id.substring(0, 5)}')
                        : 'C-${report.id.substring(0, 5)}';

                String subtitle;
                Color color;

                switch (report.status) {
                  case ReportStatus.forwarded:
                    subtitle = 'Forwarded Case';
                    color = AppTheme.warningOrange;
                    break;
                  case ReportStatus.counselorConfirmed:
                    subtitle = 'Active Case';
                    color = AppTheme.errorRed;
                    break;
                  case ReportStatus.counselorReviewed:
                    subtitle = 'Reviewed by Counselor';
                    color = AppTheme.infoBlue;
                    break;
                  case ReportStatus.counselingScheduled:
                    subtitle = 'Under Monitoring';
                    color = AppTheme.warningOrange;
                    break;
                  case ReportStatus.approvedByDean:
                    subtitle = 'For Follow Up';
                    color = AppTheme.purple;
                    break;
                  case ReportStatus.settled:
                    subtitle = 'Resolved';
                    color = AppTheme.successGreen;
                    break;
                  case ReportStatus.completed:
                    subtitle = 'Case Closed';
                    color = AppTheme.mediumGray;
                    break;
                  default:
                    subtitle = 'Case Record';
                    color = AppTheme.mediumGray;
                }

                return ActivityItem(
                  title: title,
                  subtitle: subtitle,
                  time: timeAgo,
                  color: color,
                );
              }).toList();

          _recentActivityItems =
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

                  switch (action) {
                    case 'submitted':
                      title = 'New case intake';
                      subtitle = 'Report submitted';
                      color = AppTheme.skyBlue;
                      break;
                    case 'reviewed':
                      title = 'Case reviewed';
                      subtitle = 'Title reviewed';
                      color = AppTheme.infoBlue;
                      break;
                    case 'forwarded':
                      title = 'Case forwarded';
                      subtitle = 'Forwarded to you';
                      color = AppTheme.warningOrange;
                      break;
                    case 'confirmed':
                      title = 'Case confirmed';
                      subtitle = 'You confirmed case';
                      color = AppTheme.successGreen;
                      break;
                    case 'settled':
                      title = 'Case settled';
                      subtitle = 'Case resolved';
                      color = AppTheme.successGreen;
                      break;
                    default:
                      title = 'Case activity';
                      subtitle = 'Activity on report';
                      color = AppTheme.mediumGray;
                  }
                } else {
                  final action = activity['action'] as String;
                  switch (action) {
                    case 'requested':
                      title = 'Counseling Req';
                      subtitle = 'Student requested';
                      color = AppTheme.skyBlue;
                      break;
                    case 'confirmed':
                      title = 'Session set';
                      subtitle = 'Session confirmed';
                      color = AppTheme.infoBlue;
                      break;
                    case 'settled':
                      title = 'Session done';
                      subtitle = 'Completed';
                      color = AppTheme.successGreen;
                      break;
                    default:
                      title = 'Counseling';
                      subtitle = 'Activity';
                      color = AppTheme.mediumGray;
                  }
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
                title: 'Counselor Dashboard',
                subtitle: 'Manage case records and student counseling history',
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
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else ...[
                            _buildStats(constraints),
                            const SizedBox(height: 32),
                            _buildInsights(constraints),
                          ],
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
    // Account for ListView padding: 32 on each side = 64px total
    final availableWidth = constraints.maxWidth - 64;
    final spacing = 16.0;

    // Force 3 columns if available width is at least 600px
    if (availableWidth >= 600) {
      return Row(
        children: [
          Expanded(
            child: _CounselorStatCard(
              label: 'All Records',
              value: '$_totalRecords',
              delta: _getTotalRecordsDeltaText(),
              color: AppTheme.skyBlue,
              icon: Icons.assignment_outlined,
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: _CounselorStatCard(
              label: 'Resolved Cases',
              value: '$_resolvedCases',
              delta: _getResolvedDeltaText(),
              color: AppTheme.successGreen,
              icon: Icons.check_circle_outline_rounded,
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: _CounselorStatCard(
              label: 'New Reports',
              value: '$_newReportsToday',
              delta: _getNewReportsDeltaText(),
              color: AppTheme.warningOrange,
              icon: Icons.new_releases_outlined,
            ),
          ),
        ],
      );
    }

    // For smaller screens, use a Wrap with calculated widths
    final columns = availableWidth >= 400 ? 2 : 1;
    final cardWidth = (availableWidth - (columns - 1) * spacing) / columns;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        _CounselorStatCard(
          label: 'All Records',
          value: '$_totalRecords',
          delta: _getTotalRecordsDeltaText(),
          color: AppTheme.skyBlue,
          icon: Icons.assignment_outlined,
          width: cardWidth,
        ),
        _CounselorStatCard(
          label: 'Resolved Cases',
          value: '$_resolvedCases',
          delta: _getResolvedDeltaText(),
          color: AppTheme.successGreen,
          icon: Icons.check_circle_outline_rounded,
          width: cardWidth,
        ),
        _CounselorStatCard(
          label: 'New Reports',
          value: '$_newReportsToday',
          delta: _getNewReportsDeltaText(),
          color: AppTheme.warningOrange,
          icon: Icons.new_releases_outlined,
          width: cardWidth,
        ),
      ],
    );
  }

  Widget _buildInsights(BoxConstraints constraints) {
    final isWide = constraints.maxWidth > 900;

    final timelineCard = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Student Case Timeline',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepBlue,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/counselor/timeline'),
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.lightGray),
          _timelineItems.isEmpty
              ? const Padding(
                padding: EdgeInsets.all(48),
                child: Center(
                  child: Text(
                    'No case timeline data',
                    style: TextStyle(color: AppTheme.mediumGray),
                  ),
                ),
              )
              : Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children:
                      _timelineItems
                          .map((item) => _buildActivityItem(item))
                          .toList(),
                ),
              ),
        ],
      ),
    );

    final recentActivityCard = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepBlue,
                  ),
                ),
                // No view all needed here as per design
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.lightGray),
          _recentActivityItems.isEmpty
              ? const Padding(
                padding: EdgeInsets.all(48),
                child: Center(
                  child: Text(
                    'No recent activity',
                    style: TextStyle(color: AppTheme.mediumGray),
                  ),
                ),
              )
              : Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children:
                      _recentActivityItems
                          .map((item) => _buildActivityItem(item))
                          .toList(),
                ),
              ),
        ],
      ),
    );

    final forwardedCard = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.warningOrange,
            AppTheme.warningOrange.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.warningOrange.withValues(alpha: 0.3),
            offset: const Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.pending_actions_rounded,
              size: 140,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pending Action',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_pendingForwardedCount',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Forwarded Reports',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'New reports forwarded by faculty members requiring your immediate review.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/counselor/reports'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.warningOrange,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Review Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 1, child: recentActivityCard),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: timelineCard),
          const SizedBox(width: 24),
          Expanded(flex: 1, child: forwardedCard),
        ],
      );
    }

    return Column(
      children: [
        forwardedCard,
        const SizedBox(height: 24),
        timelineCard,
        const SizedBox(height: 24),
        recentActivityCard,
      ],
    );
  }

  Widget _buildActivityItem(ActivityItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.color == AppTheme.successGreen
                  ? Icons.check_rounded
                  : item.color == AppTheme.warningOrange
                  ? Icons.forward_to_inbox_rounded
                  : Icons.assignment_rounded,
              size: 18,
              color: item.color,
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
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepBlue,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    color: AppTheme.mediumGray,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            item.time,
            style: const TextStyle(
              color: AppTheme.mediumGray,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CounselorStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String delta;
  final Color color;
  final IconData icon;
  final double? width;

  const _CounselorStatCard({
    required this.label,
    required this.value,
    required this.delta,
    required this.color,
    required this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 160),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            offset: const Offset(0, 10),
            blurRadius: 20,
          ),
        ],
        border: Border.all(color: AppTheme.lightBlue.withValues(alpha: 0.1)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(icon, size: 80, color: color.withValues(alpha: 0.05)),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.7)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    if (delta.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          delta,
                          style: const TextStyle(
                            color: AppTheme.successGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepBlue,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.mediumGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityItem {
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  ActivityItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });
}
