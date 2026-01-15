import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';
import '../../models/user_model.dart';
import '../../models/user_activity_log_model.dart';
import '../../models/report_model.dart';
import '../../models/counseling_request_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _supabase = SupabaseService();

  bool _loading = true;
  int _totalUsers = 0;
  int _totalReports = 0;
  int _totalCounselingRequests = 0;
  int _studentCount = 0;
  int _teacherCount = 0;
  int _counselorCount = 0;
  int _deanCount = 0;
  int _adminCount = 0;
  List<UserActivityLog> _activityLogs = [];
  List<Map<String, dynamic>> _recentReports = [];
  List<CounselingRequestModel> _upcomingCounseling = [];
  final Map<String, String> _studentNames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final total = await _supabase.countUsers();
      if (!mounted) return;

      final reports = await _supabase.countAllReports();
      if (!mounted) return;

      final counseling = await _supabase.countAllCounselingRequests();
      if (!mounted) return;

      final users = await _supabase.getAllUsers();
      if (!mounted) return;

      final activityLogs = await _supabase.getActivityLogs(limit: 10);
      if (!mounted) return;

      final recentReports = await _supabase.getRecentReports(limit: 5);
      if (!mounted) return;

      // Get all upcoming counseling requests for all students
      final allCounseling = <CounselingRequestModel>[];
      try {
        final counselors =
            users.where((u) => u.role == UserRole.counselor).toList();
        for (final counselor in counselors) {
          final requests = await _supabase.getCounselorRequests(counselor.id);
          allCounseling.addAll(requests);
        }

        // Also get student requests directly
        final students =
            users.where((u) => u.role == UserRole.student).toList();
        for (final student in students) {
          final requests = await _supabase.getStudentCounselingRequests(
            student.id,
          );
          allCounseling.addAll(requests);
        }

        // Cache student names
        for (final user in users) {
          if (user.role == UserRole.student) {
            _studentNames[user.id] = user.fullName;
          }
        }
      } catch (e) {
        debugPrint('Error loading counseling requests: $e');
      }

      // Filter for upcoming sessions
      final upcoming =
          allCounseling
              .where(
                (c) =>
                    c.sessionDate != null &&
                    c.sessionDate!.isAfter(
                      DateTime.now().subtract(const Duration(days: 1)),
                    ),
              )
              .toList()
            ..sort((a, b) {
              if (a.sessionDate == null || b.sessionDate == null) return 0;
              return a.sessionDate!.compareTo(b.sessionDate!);
            });

      users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final studentCount =
          users.where((u) => u.role == UserRole.student).length;
      final teacherCount =
          users.where((u) => u.role == UserRole.teacher).length;
      final counselorCount =
          users.where((u) => u.role == UserRole.counselor).length;
      final deanCount = users.where((u) => u.role == UserRole.dean).length;
      final adminCount = users.where((u) => u.role == UserRole.admin).length;

      if (mounted) {
        setState(() {
          _totalUsers = total;
          _totalReports = reports;
          _totalCounselingRequests = counseling;
          _studentCount = studentCount;
          _teacherCount = teacherCount;
          _counselorCount = counselorCount;
          _deanCount = deanCount;
          _adminCount = adminCount;
          _activityLogs = activityLogs;
          _recentReports = recentReports;
          _upcomingCounseling = upcoming.take(5).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
                title: 'Admin Dashboard',
                subtitle: 'Manage users, monitor analytics, and system health',
                icon: Icons.admin_panel_settings_rounded,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final contentWidth = maxWidth > 1280 ? 1280.0 : maxWidth;

                    return Center(
                      child:
                          _loading
                              ? const CircularProgressIndicator()
                              : SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: contentWidth,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildStats(contentWidth),
                                      const SizedBox(height: 20),
                                      _buildRoleOverview(contentWidth),
                                      const SizedBox(height: 20),
                                      _buildActivityAndReports(contentWidth),
                                      const SizedBox(height: 24),
                                      _buildUpcomingSessions()
                                          .animate()
                                          .fadeIn(delay: 500.ms)
                                          .slideY(begin: 0.1),
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
        ),
      ),
    );
  }

  Widget _buildActivityAndReports(double width) {
    if (width >= 960) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildActivityLogList()),
          const SizedBox(width: 24),
          Expanded(child: _buildRecentReportsList()),
        ],
      );
    } else {
      return Column(
        children: [
          _buildActivityLogList(),
          const SizedBox(height: 24),
          _buildRecentReportsList(),
        ],
      );
    }
  }

  Widget _buildStats(double width) {
    final isWide = width >= 960;

    // Calculate width based on available space
    final cardWidth =
        isWide
            ? (width - 32) /
                3 // 3 cards with 16 spacing (2 gaps) -> width - 32
            : width >= 640
            ? (width - 16) / 2
            : width;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: cardWidth,
          child: _DashboardStatCard(
            label: 'Total Users',
            value: '$_totalUsers',
            icon: Icons.people_alt_rounded,
            color: AppTheme.skyBlue,
            gradient: const [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _DashboardStatCard(
            label: 'Reports Submitted',
            value: '$_totalReports',
            icon: Icons.assignment_rounded,
            color: AppTheme.infoBlue,
            gradient: const [Color(0xFF3B82F6), Color(0xFF60A5FA)],
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _DashboardStatCard(
            label: 'Counseling Requests',
            value: '$_totalCounselingRequests',
            icon: Icons.psychology_rounded,
            color: const Color(0xFF8B5CF6),
            gradient: const [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleOverview(double width) {
    // 5 cards is tricky for grid.
    // Wide: 5 cols if super wide? Or just flexible wrap.
    // Let's stick to a responsive wrap logic.

    // We want them to look good. Fixed width might be better for uniformity?
    // Or simpler: divide width by target column count.

    double cardWidth;
    if (width > 1200) {
      cardWidth = (width - 64) / 5; // 5 in a row
    } else if (width >= 960) {
      cardWidth = (width - 32) / 3; // 3 in a row
    } else if (width >= 600) {
      cardWidth = (width - 16) / 2; // 2 in a row
    } else {
      cardWidth = width;
    }

    final roleCards = [
      _RoleCard(
        title: 'Students',
        count: _studentCount,
        gradient: const [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
        icon: Icons.school_rounded,
        iconColor: Colors.white,
      ),
      _RoleCard(
        title: 'Teachers',
        count: _teacherCount,
        gradient: const [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
        icon: Icons.person_pin_rounded,
        iconColor: Colors.white,
      ),
      _RoleCard(
        title: 'Counselors',
        count: _counselorCount,
        gradient: const [Color(0xFF06B6D4), Color(0xFF22D3EE)],
        icon: Icons.psychology_alt_rounded,
        iconColor: Colors.white,
      ),
      _RoleCard(
        title: 'Deans',
        count: _deanCount,
        gradient: const [Color(0xFF6366F1), Color(0xFF818CF8)],
        icon: Icons.account_balance_rounded,
        iconColor: Colors.white,
      ),
      _RoleCard(
        title: 'Admins',
        count: _adminCount,
        gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        icon: Icons.admin_panel_settings_rounded,
        iconColor: Colors.white,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User Distribution',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.deepBlue,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children:
              roleCards
                  .map((card) => SizedBox(width: cardWidth, child: card))
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildActivityLogList() {
    if (_activityLogs.isEmpty) return const SizedBox();

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
          SizedBox(
            height: 400,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _activityLogs.length,
              separatorBuilder:
                  (_, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      height: 1,
                      color: AppTheme.lightGray.withValues(alpha: 0.5),
                    ),
                  ),
              itemBuilder: (context, index) {
                final log = _activityLogs[index];
                final time = DateFormat(
                  'MMM dd, hh:mm a',
                ).format(log.timestamp);
                final roleRaw = log.userRole ?? 'user';
                UserRole roleEnum = UserRole.values.firstWhere(
                  (e) => e.toString().split('.').last == roleRaw,
                  orElse: () => UserRole.student,
                );
                final roleColor = _roleColor(roleEnum);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getRoleIcon(roleEnum),
                        color: roleColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  log.userName ?? 'Unknown User',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.deepBlue,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: roleColor.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: roleColor.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  roleRaw.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: roleColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log.action,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.mediumGray,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            time,
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
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReportsList() {
    if (_recentReports.isEmpty) {
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
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: const [
            Text(
              'New Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepBlue,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No recent reports.',
              style: TextStyle(color: AppTheme.mediumGray),
            ),
          ],
        ),
      );
    }

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.assignment_turned_in_rounded,
                    color: AppTheme.skyBlue,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Incoming Reports',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.go('/admin/analytics'),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 400,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _recentReports.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final report = _recentReports[index];
                final isAnonymous = report['is_anonymous'] as bool;
                final createdAt = DateTime.parse(report['created_at']);
                final time = DateFormat('MMM dd').format(createdAt);

                final String status = report['status'] ?? 'pending';
                Color statusColor;
                Color statusBg;

                switch (status.toLowerCase()) {
                  case 'pending':
                  case 'submitted':
                    statusColor = AppTheme.warningOrange;
                    statusBg = AppTheme.warningOrange.withValues(alpha: 0.1);
                    break;
                  case 'completed':
                  case 'settled':
                    statusColor = AppTheme.successGreen;
                    statusBg = AppTheme.successGreen.withValues(alpha: 0.1);
                    break;
                  default:
                    statusColor = AppTheme.skyBlue;
                    statusBg = AppTheme.skyBlue.withValues(alpha: 0.1);
                }

                return InkWell(
                  onTap: () => _viewCaseDetail(report),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGray.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isAnonymous ? Icons.person_off : Icons.person,
                            color:
                                isAnonymous
                                    ? AppTheme.mediumGray
                                    : AppTheme.skyBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAnonymous
                                    ? 'Anonymous'
                                    : (report['student']?['full_name'] ??
                                        'Unknown'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.deepBlue,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                report['title'] ?? 'No Title',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGray,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.mediumGray.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Icons.school_rounded;
      case UserRole.teacher:
        return Icons.person_pin_rounded;
      case UserRole.counselor:
        return Icons.psychology_alt_rounded;
      case UserRole.dean:
        return Icons.account_balance_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return AppTheme.skyBlue;
      case UserRole.teacher:
        return const Color(0xFF8B5CF6);
      case UserRole.counselor:
        return const Color(0xFF0EA5E9);
      case UserRole.dean:
        return const Color(0xFF4C1D95); // Deep indigo
      case UserRole.admin:
        return AppTheme.warningOrange;
    }
  }

  void _viewCaseDetail(Map<String, dynamic> report) {
    if (report.isEmpty) return;

    final createdAt = DateTime.parse(report['created_at'] as String);
    final status = ReportStatus.fromString(report['status'] as String);
    final isAnonymous = report['is_anonymous'] as bool? ?? false;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text('Case Details'), _buildStatusChip(status)],
            ),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDetailRow(
                      'Tracking ID',
                      report['tracking_id'] ?? 'N/A',
                    ),
                    _buildDetailRow(
                      'Date',
                      DateFormat('MMM dd, yyyy – hh:mm a').format(createdAt),
                    ),
                    const Divider(),
                    _buildDetailRow('Subject', report['title'] ?? 'No Title'),
                    _buildDetailRow('Type', report['type'] ?? 'General'),
                    const SizedBox(height: 16),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        report['description'] ?? 'No description provided.',
                      ),
                    ),
                    const Divider(),
                    const Text(
                      'Participants',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Student',
                      isAnonymous
                          ? 'Anonymous Student'
                          : ((report['student'] as Map?)?['full_name']
                                  as String? ??
                              'N/A'),
                    ),
                    _buildDetailRow(
                      'Teacher',
                      (report['teacher'] as Map?)?['full_name'] as String? ??
                          'Not Assigned',
                    ),
                    _buildDetailRow(
                      'Counselor',
                      (report['counselor'] as Map?)?['full_name'] as String? ??
                          'Not Assigned',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('Print Formal Report'),
                onPressed: () {
                  context.pop();
                  _printDeanReport(report);
                },
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ReportStatus status) {
    Color color;
    switch (status) {
      case ReportStatus.submitted:
      case ReportStatus.pending:
        color = Colors.orange;
        break;
      case ReportStatus.teacherReviewed:
      case ReportStatus.forwarded:
      case ReportStatus.counselorReviewed:
      case ReportStatus.counselorConfirmed:
      case ReportStatus.approvedByDean:
        color = Colors.blue;
        break;
      case ReportStatus.counselingScheduled:
        color = Colors.purple;
        break;
      case ReportStatus.settled:
      case ReportStatus.completed:
        color = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildUpcomingSessions() {
    return Container(
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
        border: Border.all(color: AppTheme.lightBlue.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: AppTheme.skyBlue,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Upcoming Counseling Sessions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepBlue,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.lightGray),
          if (_upcomingCounseling.isEmpty)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                child: Text(
                  'No upcoming counseling sessions scheduled.',
                  style: TextStyle(color: AppTheme.mediumGray),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _upcomingCounseling.length,
              separatorBuilder:
                  (context, index) =>
                      const Divider(height: 1, indent: 24, endIndent: 24),
              itemBuilder: (context, index) {
                final session = _upcomingCounseling[index];
                return _buildSessionItem(session);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(CounselingRequestModel session) {
    final studentName = _studentNames[session.studentId] ?? 'Unknown Student';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_available,
              color: AppTheme.skyBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.deepBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Type: ${session.sessionType ?? 'Individual'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '•',
                      style: TextStyle(color: AppTheme.lightGray),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppTheme.mediumGray.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      session.sessionDate != null
                          ? DateFormat(
                            'MMM dd, yyyy',
                          ).format(session.sessionDate!)
                          : 'TBA',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Scheduled',
              style: TextStyle(
                color: AppTheme.successGreen,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printDeanReport(Map<String, dynamic> reportData) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Fetch Counseling Request for Participants
      CounselingRequestModel? counselingRequest;
      Map<String, String> participantNames = {};
      try {
        final reportId = reportData['id'] as String;
        counselingRequest = await _supabase.getCounselingRequestByReportId(
          reportId,
        );
        if (counselingRequest?.participants != null) {
          for (final p in counselingRequest!.participants!) {
            if (p['userId'] != null) {
              final u = await _supabase.getUserById(p['userId']);
              if (u != null) participantNames[p['userId']] = u.fullName;
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading counseling request for PDF: $e');
      }

      final pdf = pw.Document();
      final sessionDate = DateFormat(
        'MMMM dd, yyyy',
      ).format(DateTime.parse(reportData['created_at']));

      final reportStatus = reportData['status']?.toString() ?? 'Pending';
      final subject = reportData['title'] ?? 'No Subject';
      final type = reportData['type'] ?? 'General';

      // Student Name
      final studentName =
          (reportData['student'] != null &&
                  reportData['student']['full_name'] != null)
              ? reportData['student']['full_name']
              : (reportData['is_anonymous'] == true
                  ? 'Anonymous Student'
                  : 'N/A');

      final teacherName =
          (reportData['teacher'] != null &&
                  reportData['teacher']['full_name'] != null)
              ? reportData['teacher']['full_name']
              : 'Not Assigned';

      final counselorName =
          (reportData['counselor'] != null &&
                  reportData['counselor']['full_name'] != null)
              ? reportData['counselor']['full_name']
              : 'Not Assigned';

      // Build Participants Table Rows
      final List<pw.TableRow> participantRows = [
        _buildPdfTableRow('Student', studentName),
        _buildPdfTableRow('Teacher', teacherName),
        _buildPdfTableRow('Counselor', counselorName),
      ];

      if (counselingRequest?.participants != null &&
          counselingRequest!.participants!.isNotEmpty) {
        for (final p in counselingRequest.participants!) {
          String label = p['role']?.toString() ?? 'Participant';
          String value;

          if (p['userId'] != null) {
            value = participantNames[p['userId']] ?? 'Loading...';
          } else if (p['name'] != null) {
            value = p['name'];
          } else if (label.toLowerCase() == 'parent') {
            value = 'Invitation Requested';
            label = 'Parent/Guardian';
          } else {
            value = 'Unknown';
          }

          if (label != 'Parent/Guardian') {
            label = label[0].toUpperCase() + label.substring(1);
          }

          participantRows.add(_buildPdfTableRow(label, value));
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Filamer Christian University',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text('Guidance Management System'),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue100,
                          borderRadius: pw.BorderRadius.circular(10),
                          border: pw.Border.all(color: PdfColors.blue900),
                        ),
                        child: pw.Text(
                          reportStatus.toUpperCase(),
                          style: pw.TextStyle(
                            color: PdfColors.blue900,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Content
                pw.Table(
                  columnWidths: {
                    0: const pw.FixedColumnWidth(100),
                    1: const pw.FlexColumnWidth(),
                  },
                  children: [
                    _buildPdfTableRow('Date', sessionDate),
                    _buildPdfTableRow('Subject', subject),
                    _buildPdfTableRow('Type', type),
                  ],
                ),

                pw.SizedBox(height: 15),
                pw.Text(
                  'Description',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(5),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Text(
                    reportData['description'] ?? 'No description provided.',
                  ),
                ),

                if (reportData['teacher_note'] != null &&
                    reportData['teacher_note'].toString().isNotEmpty) ...[
                  pw.SizedBox(height: 15),
                  pw.Text(
                    "Teacher's Note",
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(5),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Text(reportData['teacher_note']),
                  ),
                ],

                if (reportData['counselor_note'] != null &&
                    reportData['counselor_note'].toString().isNotEmpty) ...[
                  pw.SizedBox(height: 15),
                  pw.Text(
                    "Counselor's Note",
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(5),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Text(reportData['counselor_note']),
                  ),
                ],

                if (reportData['dean_note'] != null &&
                    reportData['dean_note'].toString().isNotEmpty) ...[
                  pw.SizedBox(height: 15),
                  pw.Text(
                    "Dean's Note",
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(5),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Text(reportData['dean_note']),
                  ),
                ],

                pw.SizedBox(height: 15),
                pw.Divider(),
                pw.SizedBox(height: 10),

                pw.Text(
                  'Participants',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                pw.Table(
                  columnWidths: {
                    0: const pw.FixedColumnWidth(100),
                    1: const pw.FlexColumnWidth(),
                  },
                  children: participantRows,
                ),

                pw.Spacer(),

                // Footer
                pw.Divider(),
                pw.Center(
                  child: pw.Text(
                    'CONFIDENTIAL – FOR OFFICIAL GUIDANCE USE ONLY',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.red,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        html.window.open(url, '_blank');
        html.Url.revokeObjectUrl(url);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Failed to generate PDF: $e');
    }
  }

  pw.TableRow _buildPdfTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(value)),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final int count;
  final List<Color> gradient;
  final IconData icon;
  final Color iconColor;

  const _RoleCard({
    required this.title,
    required this.count,
    required this.gradient,
    required this.icon,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mediumGray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepBlue,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  const _DashboardStatCard({
    required this.label,
    required this.value,
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
