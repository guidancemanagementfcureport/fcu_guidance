import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../models/report_model.dart';
import '../../models/counseling_request_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';
import 'dean_approval_dialog.dart';
import '../../utils/animations.dart';

class DeanDashboard extends StatefulWidget {
  const DeanDashboard({super.key});

  @override
  State<DeanDashboard> createState() => _DeanDashboardState();
}

class _DeanDashboardState extends State<DeanDashboard> {
  final _supabase = SupabaseService();

  bool _loading = true;
  int _totalReportsReceived = 0;
  int _reportsAwaitingAction = 0;
  int _approvedCounselingRequests = 0;
  int _upcomingSessions = 0;
  List<ReportModel> _pendingReports = [];
  List<CounselingRequestModel> _upcomingCounseling = [];
  final Map<String, String> _studentNames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final allReports = await _supabase.getDeanReports();
      // Get all counseling requests by fetching from all counselors
      final allCounseling = <CounselingRequestModel>[];
      try {
        final allUsers = await _supabase.getAllUsers();
        final counselors =
            allUsers.where((u) => u.role == UserRole.counselor).toList();

        // Filter students to only include College level
        final collegeStudents =
            allUsers
                .where(
                  (u) =>
                      u.role == UserRole.student &&
                      u.studentLevel == StudentLevel.college,
                )
                .toList();
        final collegeStudentIds = collegeStudents.map((u) => u.id).toSet();

        for (final counselor in counselors) {
          final requests = await _supabase.getCounselorRequests(counselor.id);
          // Only add requests belonging to college students
          allCounseling.addAll(
            requests.where((r) => collegeStudentIds.contains(r.studentId)),
          );
        }

        // Also get student requests for College students only
        for (final student in collegeStudents) {
          final requests = await _supabase.getStudentCounselingRequests(
            student.id,
          );
          allCounseling.addAll(requests);
        }

        // Cache student names only for college students/grads for Dean's oversight
        for (final user in allUsers) {
          if (user.role == UserRole.student &&
              user.studentLevel != StudentLevel.college) {
            continue;
          }
          _studentNames[user.id] = user.fullName;
        }
      } catch (e) {
        debugPrint('Error loading counseling requests: $e');
      }

      // Calculate statistics
      final totalReports = allReports.length;
      final awaitingAction =
          allReports
              .where((r) => r.status == ReportStatus.counselorReviewed)
              .length;
      final approved =
          allReports
              .where((r) => r.status == ReportStatus.approvedByDean)
              .length;
      final scheduled =
          allReports
              .where((r) => r.status == ReportStatus.counselingScheduled)
              .length;

      // Get pending reports (counselor reviewed, awaiting Dean action)
      final pending =
          allReports
              .where((r) => r.status == ReportStatus.counselorReviewed)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Sort all reports by date
      allReports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Get upcoming counseling sessions
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

      setState(() {
        _totalReportsReceived = totalReports;
        _reportsAwaitingAction = awaitingAction;
        _approvedCounselingRequests = approved;
        _upcomingSessions = scheduled;
        _pendingReports = pending.take(5).toList();
        _upcomingCounseling = upcoming.take(5).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading Dean dashboard data: $e');
      setState(() => _loading = false);
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
                title: 'Dean Dashboard',
                subtitle: 'Welcome to your oversight control center',
                icon: Icons.dashboard_rounded,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 24,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: contentWidth,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildStats(
                                        contentWidth,
                                      ).fadeInSlideUp(delay: 100.ms),
                                      const SizedBox(height: 24),
                                      _buildIncomingReports(
                                        contentWidth,
                                      ).fadeInSlideUp(delay: 200.ms),
                                      const SizedBox(height: 24),
                                      maxWidth > 850
                                          ? Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: _buildUpcomingSessions()
                                                    .fadeInSlideUp(
                                                      delay: 300.ms,
                                                    ),
                                              ),
                                              const SizedBox(width: 24),
                                              Expanded(
                                                child: _buildCaseStatusTracker()
                                                    .fadeInSlideUp(
                                                      delay: 400.ms,
                                                    ),
                                              ),
                                            ],
                                          )
                                          : Column(
                                            children: [
                                              _buildUpcomingSessions()
                                                  .fadeInSlideUp(delay: 300.ms),
                                              const SizedBox(height: 24),
                                              _buildCaseStatusTracker()
                                                  .fadeInSlideUp(delay: 400.ms),
                                            ],
                                          ),
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

  Widget _buildStats(double width) {
    final isDesktop = width >= 900;
    final isTablet = width >= 600 && !isDesktop;

    double cardWidth;
    if (isDesktop) {
      cardWidth = (width - 48) / 4;
    } else if (isTablet) {
      cardWidth = (width - 24) / 2;
    } else {
      cardWidth = width;
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _DeanStatCard(
          label: 'Reports Received',
          value: '$_totalReportsReceived',
          icon: Icons.assignment_outlined,
          color: AppTheme.skyBlue,
          onTap: () => context.go('/dean/reports'),
          width: cardWidth,
        ),
        _DeanStatCard(
          label: 'Awaiting Action',
          value: '$_reportsAwaitingAction',
          icon: Icons.pending_actions,
          color: AppTheme.warningOrange,
          onTap: () => context.go('/dean/reports?filter=pending'),
          width: cardWidth,
        ),
        _DeanStatCard(
          label: 'Approved Cases',
          value: '$_approvedCounselingRequests',
          icon: Icons.check_circle_outline,
          color: AppTheme.successGreen,
          onTap: () => context.go('/dean/reports?filter=approved'),
          width: cardWidth,
        ),
        _DeanStatCard(
          label: 'Scheduled',
          value: '$_upcomingSessions',
          icon: Icons.calendar_today,
          color: AppTheme.infoBlue,
          onTap: () => context.go('/dean/reports?filter=scheduled'),
          width: cardWidth,
        ),
      ],
    );
  }

  Widget _buildIncomingReports(double width) {
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incoming Reports',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                    Text(
                      'Awaiting Review & Approval',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/dean/reports?filter=pending'),
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.lightGray),
          if (_pendingReports.isEmpty)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 48,
                      color: AppTheme.lightGray,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'All reports have been reviewed',
                      style: TextStyle(color: AppTheme.mediumGray),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pendingReports.length,
              separatorBuilder:
                  (context, index) =>
                      const Divider(height: 1, indent: 24, endIndent: 24),
              itemBuilder: (context, index) {
                final report = _pendingReports[index];
                return _buildReportItem(report);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildReportItem(ReportModel report) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _viewReportDetails(report),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.infoBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppTheme.infoBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Student: ${report.isAnonymous ? 'Anonymous' : (_studentNames[report.studentId] ?? 'Loading...')} • Received: ${DateFormat('MMM dd, yyyy').format(report.createdAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    color: AppTheme.warningOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppTheme.lightGray),
            ],
          ),
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
                  'Upcoming Counseling',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepBlue,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/dean/reports?filter=scheduled'),
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.lightGray),
          if (_upcomingCounseling.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No upcoming sessions',
                  style: TextStyle(color: AppTheme.mediumGray),
                ),
              ),
            )
          else
            Column(
              children:
                  _upcomingCounseling
                      .map((session) => _buildSessionItem(session))
                      .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(CounselingRequestModel session) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month,
              color: AppTheme.skyBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _studentNames[session.studentId] ??
                      session.sessionType ??
                      'Counseling Session',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.deepBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Date: ${session.sessionDate != null ? DateFormat('MMM dd, yyyy').format(session.sessionDate!) : 'TBA'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGray,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 12,
            color: AppTheme.lightGray,
          ),
        ],
      ),
    );
  }

  Widget _buildCaseStatusTracker() {
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
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Case Status Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 24),
          _buildStatusStep(
            'Student Submitted',
            Icons.edit_note_rounded,
            AppTheme.infoBlue,
            true,
          ),
          _buildStatusStep(
            'Counselor Reviewed',
            Icons.fact_check_rounded,
            AppTheme.warningOrange,
            _reportsAwaitingAction > 0,
          ),
          _buildStatusStep(
            'Dean Approved',
            Icons.verified_rounded,
            AppTheme.successGreen,
            _approvedCounselingRequests > 0,
          ),
          _buildStatusStep(
            'Counseling Scheduled',
            Icons.event_available_rounded,
            AppTheme.mediumBlue,
            _upcomingSessions > 0,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStep(
    String label,
    IconData icon,
    Color color,
    bool isActive,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  isActive
                      ? color.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isActive ? color : Colors.grey, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? AppTheme.deepBlue : Colors.grey,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewReportDetails(ReportModel report) async {
    if (report.status == ReportStatus.counselorReviewed) {
      // Show approval dialog
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => DeanApprovalDialog(report: report),
      );

      if (result == true) {
        _loadData();
      }
    } else if (report.status == ReportStatus.approvedByDean) {
      // Navigate to reports monitoring
      context.go('/dean/reports?filter=approved');
    } else {
      // Navigate to reports page to view details
      context.go('/dean/reports');
    }
  }
}

class _DeanStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double width;

  const _DeanStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
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
            border: Border.all(
              color: AppTheme.lightBlue.withValues(alpha: 0.1),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -10,
                child: Icon(
                  icon,
                  size: 80,
                  color: color.withValues(alpha: 0.05),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
        ),
      ),
    );
  }
}
