import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../models/report_model.dart';
import '../../models/counseling_request_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_sidebar.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/modern_dashboard_header.dart';
// import 'dean_approval_dialog.dart';
import '../../utils/animations.dart';

class PrincipalDashboard extends StatefulWidget {
  const PrincipalDashboard({super.key});

  @override
  State<PrincipalDashboard> createState() => _PrincipalDashboardState();
}

class _PrincipalDashboardState extends State<PrincipalDashboard> {
  final _supabase = SupabaseService();

  bool _loading = true;
  int _totalReportsReceived = 0;
  int _recentForwardReportsCount = 0;
  List<ReportModel> _recentForwardReports = [];
  final Map<String, String> _studentNames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentRole = authProvider.currentUser?.role;
    
    setState(() => _loading = true);
    try {
      final allReports = await _supabase.getDeanReports(role: currentRole);
      // Get all counseling requests by fetching from all counselors
      final allCounseling = <CounselingRequestModel>[];
      try {
        final allUsers = await _supabase.getAllUsers();
        final counselors =
            allUsers.where((u) => u.role == UserRole.counselor).toList();

        // Filter students to include College level for Dean, JHS/SHS for Principal
        final targetStudents =
            allUsers
                .where((u) {
                  if (u.role != UserRole.student) return false;
                  if (currentRole == UserRole.principal || currentRole == UserRole.assistantPrincipal) {
                    return u.studentLevel == StudentLevel.juniorHigh || u.studentLevel == StudentLevel.seniorHigh;
                  }
                  return u.studentLevel == StudentLevel.college;
                })
                .toList();
        final targetStudentIds = targetStudents.map((u) => u.id).toSet();

        for (final counselor in counselors) {
          final requests = await _supabase.getCounselorRequests(counselor.id);
          // Only add requests belonging to college students
          allCounseling.addAll(
            requests.where((r) => targetStudentIds.contains(r.studentId)),
          );
        }

        // Also get student requests for targeted students only
        for (final student in targetStudents) {
          final requests = await _supabase.getStudentCounselingRequests(
            student.id,
          );
          allCounseling.addAll(requests);
        }

        for (final user in allUsers) {
          if (user.role != UserRole.student) continue;

          if (currentRole == UserRole.principal || currentRole == UserRole.assistantPrincipal) {
            if (user.studentLevel == StudentLevel.college) continue;
          } else {
            if (user.studentLevel != StudentLevel.college) continue;
          }
          _studentNames[user.id] = user.fullName;
        }
      } catch (e) {
        debugPrint('Error loading counseling requests: $e');
      }

      // Calculate statistics
      final totalReports = allReports.length;

      List<ReportModel> recentForwards = [];
      final oversightId = authProvider.currentUser?.id;
      if (oversightId != null) {
        recentForwards = await _supabase
            .getRecentCounselorForwardedCopiesForOversight(
              oversightUserId: oversightId,
              role: currentRole,
            );
      }

      setState(() {
        _totalReportsReceived = totalReports;
        _recentForwardReportsCount = recentForwards.length;
        _recentForwardReports = recentForwards.take(5).toList();
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
                title: 'Principal Dashboard',
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
      cardWidth = (width - 64) / 4;
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
          onTap: () => context.go('/principal/reports'),
          width: cardWidth,
        ),
        _DeanStatCard(
          label: 'Recent Forward Reports',
          value: '$_recentForwardReportsCount',
          icon: Icons.inventory_2_outlined,
          color: AppTheme.warningOrange,
          onTap: () => context.go('/principal/reports'),
          width: cardWidth,
        ),
        FutureBuilder<Map<StudentLevel, int>>(
          future: _countRecentForwardStudentLevels(),
          builder: (context, snapshot) {
            final data = snapshot.data ?? const {};
            final jhs = data[StudentLevel.juniorHigh] ?? 0;
            final shs = data[StudentLevel.seniorHigh] ?? 0;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _DeanStatCard(
                  label: 'Junior High Records',
                  value: jhs.toString(),
                  icon: Icons.school_rounded,
                  color: const Color(0xFF3B82F6),
                  onTap: () => context.go('/principal/reports'),
                  width: cardWidth,
                ),
                _DeanStatCard(
                  label: 'Senior High Records',
                  value: shs.toString(),
                  icon: Icons.school_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => context.go('/principal/reports'),
                  width: cardWidth,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<Map<StudentLevel, int>> _countRecentForwardStudentLevels() async {
    final counts = <StudentLevel, int>{};
    final ids =
        _recentForwardReports.map((r) => r.studentId).whereType<String>().toSet().toList();
    if (ids.isEmpty) return counts;

    final users = await _supabase.getUsersByIds(ids);
    final levelById = <String, StudentLevel>{};
    for (final u in users) {
      if (u.studentLevel != null) {
        levelById[u.id] = u.studentLevel!;
      }
    }

    for (final r in _recentForwardReports) {
      final sid = r.studentId;
      if (sid == null) continue;
      final level = levelById[sid];
      if (level == null) continue;
      counts[level] = (counts[level] ?? 0) + 1;
    }

    return counts;
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
                      'Recent Forward Reports',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                    Text(
                      'Counselor forwards (last 30 days)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/principal/reports'),
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.lightGray),
          if (_recentForwardReports.isEmpty)
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
                      'No recent forward reports',
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
              itemCount: _recentForwardReports.length,
              separatorBuilder:
                  (context, index) =>
                      const Divider(height: 1, indent: 24, endIndent: 24),
              itemBuilder: (context, index) {
                final report = _recentForwardReports[index];
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
                      'Student: ${report.isAnonymous ? 'Anonymous' : (_studentNames[report.studentId] ?? 'Loading...')} • Updated: ${DateFormat('MMM dd, yyyy').format(report.updatedAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
              _buildForwardStatusChip(report),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppTheme.lightGray),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _viewReportDetails(ReportModel report) async {
    // Navigate to reports page to view details
    context.go('/principal/reports');
  }

  Widget _buildForwardStatusChip(ReportModel report) {
    final isSettled =
        report.status == ReportStatus.settled ||
        report.status == ReportStatus.completed;
    final color =
        isSettled ? AppTheme.successGreen : AppTheme.warningOrange;
    final label = isSettled ? 'Settled' : 'Pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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
