import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/counseling_request_model.dart';
import '../../models/counseling_activity_log_model.dart';
import '../../models/report_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/animations.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';

class ViewCounselingStatusPage extends StatefulWidget {
  const ViewCounselingStatusPage({super.key});

  @override
  State<ViewCounselingStatusPage> createState() =>
      _ViewCounselingStatusPageState();
}

class _ViewCounselingStatusPageState extends State<ViewCounselingStatusPage> {
  final _supabase = SupabaseService();
  bool _isLoading = true;
  List<CounselingRequestModel> _requests = [];
  Map<String, List<CounselingActivityLog>> _activityLogsMap = {};
  Map<String, ReportModel?> _reportMap = {};
  Map<String, UserModel?> _counselorMap = {};
  Map<String, UserModel?> _teacherMap = {};
  final Map<String, UserModel> _participantUserCache = {};

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final studentId = authProvider.currentUser?.id;

      if (studentId != null) {
        final requests = await _supabase.getStudentCounselingRequests(
          studentId,
        );

        // Load activity logs, reports, and person details for each request
        final logsMap = <String, List<CounselingActivityLog>>{};
        final reportsMap = <String, ReportModel?>{};
        final counselorMap = <String, UserModel?>{};
        final teacherMap = <String, UserModel?>{};

        for (final request in requests) {
          final logs = await _supabase.getCounselingActivityLogs(request.id);
          logsMap[request.id] = logs;

          if (request.reportId != null) {
            final report = await _supabase.getReportById(request.reportId!);
            reportsMap[request.id] = report;

            if (report?.teacherId != null) {
              final teacher = await _supabase.getUserById(report!.teacherId!);
              teacherMap[request.id] = teacher;
            }
          }

          if (request.counselorId != null) {
            final counselor = await _supabase.getUserById(request.counselorId!);
            counselorMap[request.id] = counselor;
          }

          // Cache participants names
          if (request.participants != null) {
            for (final p in request.participants!) {
              final uid = p['user_id'];
              if (uid is String &&
                  uid != 'parent' &&
                  !_participantUserCache.containsKey(uid)) {
                final user = await _supabase.getUserById(uid);
                if (user != null) {
                  _participantUserCache[uid] = user;
                }
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _requests = requests;
            _activityLogsMap = logsMap;
            _reportMap = reportsMap;
            _counselorMap = counselorMap;
            _teacherMap = teacherMap;
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
        ToastUtils.showError(context, 'Error loading requests: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatusColor(CounselingStatus status) {
    switch (status) {
      case CounselingStatus.pendingReview:
        return AppTheme.warningOrange;
      case CounselingStatus.confirmed:
        return AppTheme.successGreen;
      case CounselingStatus.settled:
        return AppTheme.mediumGray;
    }
  }

  IconData _getStatusIcon(CounselingStatus status) {
    switch (status) {
      case CounselingStatus.pendingReview:
        return Icons.pending;
      case CounselingStatus.confirmed:
        return Icons.check_circle;
      case CounselingStatus.settled:
        return Icons.verified;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return ResponsiveSidebar(
      currentRoute: currentRoute,
      child: Scaffold(
        body: Container(
          decoration: AppTheme.softBlueGradientDecoration,
          child: Column(
            children: [
              const ModernDashboardHeader(
                title: 'Counseling Status',
                subtitle: 'View and track your counseling requests',
                icon: Icons.psychology_rounded,
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _requests.isEmpty
                        ? _buildEmptyState()
                        : LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            int columns =
                                width >= 800 ? 3 : (width >= 550 ? 2 : 1);
                            final spacing = 16.0;
                            final horizontalPadding = 24.0;
                            final contentWidth =
                                width - (horizontalPadding * 2);
                            final cardWidth =
                                (contentWidth - (columns - 1) * spacing) /
                                columns;

                            return SingleChildScrollView(
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding,
                                vertical: 24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppTheme.warningOrange.withValues(
                                            alpha: 0.1,
                                          ),
                                          AppTheme.skyBlue.withValues(
                                            alpha: 0.05,
                                          ),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: AppTheme.warningOrange
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.psychology_rounded,
                                            color: AppTheme.warningOrange,
                                            size: 32,
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'My Counseling Requests',
                                                style: TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.deepBlue,
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                              SizedBox(height: 6),
                                              Text(
                                                'Track and manage your professional guidance sessions',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: AppTheme.mediumGray,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ).fadeInSlideUp(),
                                  const SizedBox(height: 24),
                                  Wrap(
                                    spacing: spacing,
                                    runSpacing: spacing,
                                    children:
                                        _requests
                                            .map<Widget>(
                                              (request) =>
                                                  SizedBox(
                                                    width: cardWidth,
                                                    child: _buildRequestCard(
                                                      request,
                                                    ),
                                                  ).fadeInSlideUp(),
                                            )
                                            .toList(),
                                  ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.warningOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_outlined,
                size: 64,
                color: AppTheme.warningOrange,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Counseling Requests',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepBlue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You haven\'t submitted any counseling requests yet.\nRequest counseling for a confirmed report to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.mediumGray,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go('/student/request-counseling'),
              icon: const Icon(Icons.add),
              label: const Text('Request Counseling'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(CounselingRequestModel request) {
    final report = _reportMap[request.id];
    final logs = _activityLogsMap[request.id] ?? [];
    final counselor = _counselorMap[request.id];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _getStatusColor(request.status).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showRequestDetails(request, report, logs, counselor),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        request.status,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatusIcon(request.status),
                      color: _getStatusColor(request.status),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (report != null)
                          Text(
                            report.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.deepBlue,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Requested: ${DateFormat('MMM dd, yyyy').format(request.createdAt)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.mediumGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        request.status,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      request.status.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: _getStatusColor(request.status),
                      ),
                    ),
                  ),
                ],
              ),
              if (counselor != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: AppTheme.skyBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Counselor: ${counselor.fullName} (Counselor)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.deepBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              if (_teacherMap[request.id] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      size: 16,
                      color: AppTheme.successGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Referred by: ${_teacherMap[request.id]!.fullName} (Teacher)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.deepBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              if (request.reason != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Reason: ${request.reason}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.darkGray,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRequestDetails(
    CounselingRequestModel request,
    ReportModel? report,
    List<CounselingActivityLog> logs,
    UserModel? counselor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Counseling Request Details',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.deepBlue,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Status
                        _buildDetailRow('Status', request.status.displayName),
                        _buildDetailRow(
                          'Requested',
                          DateFormat(
                            'MMM dd, yyyy HH:mm',
                          ).format(request.createdAt),
                        ),
                        if (request.updatedAt != request.createdAt)
                          _buildDetailRow(
                            'Last Updated',
                            DateFormat(
                              'MMM dd, yyyy HH:mm',
                            ).format(request.updatedAt),
                          ),

                        if (counselor != null)
                          _buildDetailRow(
                            'Counselor',
                            '${counselor.fullName} (Counselor)\n${counselor.department ?? "Guidance Dept"}',
                          ),

                        if (_teacherMap[request.id] != null)
                          _buildDetailRow(
                            'Referred By',
                            '${_teacherMap[request.id]!.fullName} (Teacher)\n${_teacherMap[request.id]!.department ?? "Faculty"}',
                          ),

                        // Report Details
                        if (report != null) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            'Related Report',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.deepBlue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow('Title', report.title),
                          _buildDetailRow('Type', report.type),
                          _buildDetailRow('Status', report.status.displayName),
                        ],

                        // Request Details
                        if (request.reason != null) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            'Reason for Counseling',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.deepBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.lightGray,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              request.reason!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          'Session Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (request.participants != null &&
                            request.participants!.isNotEmpty)
                          _buildDetailRow(
                            'Participants',
                            request.participants!
                                .map((p) {
                                  final uid = p['user_id'];
                                  final role = p['role'] ?? 'Participant';
                                  if (uid == null) return 'Unknown ($role)';
                                  final name =
                                      uid == 'parent'
                                          ? 'Parent/Guardian'
                                          : (_participantUserCache[uid]
                                                  ?.fullName ??
                                              'Unknown');
                                  return '$name ($role)';
                                })
                                .join(', '),
                          ),
                        _buildDetailRow(
                          'Session Type',
                          request.sessionType ?? 'Individual',
                        ),
                        _buildDetailRow(
                          'Location/Mode',
                          request.locationMode ?? 'In-person',
                        ),

                        if (request.preferredTime != null) ...[
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            'Preferred Time',
                            request.preferredTime!,
                          ),
                        ],

                        // Scheduled Details (if confirmed)
                        if (request.status != CounselingStatus.pendingReview &&
                            request.sessionDate != null) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            'Confirmed Session Schedule',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.deepBlue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            'Date',
                            DateFormat(
                              'MMMM dd, yyyy',
                            ).format(request.sessionDate!),
                          ),
                          if (request.sessionTime != null)
                            _buildDetailRow(
                              'Time',
                              request.sessionTime!.format(context),
                            ),
                          if (request.sessionType != null)
                            _buildDetailRow(
                              'Session Type',
                              request.sessionType!,
                            ),
                          if (request.locationMode != null)
                            _buildDetailRow(
                              'Mode/Location',
                              request.locationMode!,
                            ),
                        ],

                        if (request.counselorNote != null) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            'Counselor Response & Instructions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.deepBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.successGreen.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Text(
                              request.counselorNote!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],

                        // Status Timeline
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          'Status Timeline',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatusTimeline(request.status, logs),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.mediumGray,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: AppTheme.darkGray),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(
    CounselingStatus currentStatus,
    List<CounselingActivityLog> logs,
  ) {
    final statuses = [
      CounselingStatus.pendingReview,
      CounselingStatus.confirmed,
      CounselingStatus.settled,
    ];

    return Column(
      children:
          statuses.asMap().entries.map((entry) {
            final index = entry.key;
            final status = entry.value;
            final isCurrent = status == currentStatus;
            final isCompleted = _isStatusCompleted(currentStatus, status);

            // Find matching log
            CounselingActivityLog? log;
            if (logs.isEmpty) {
              log = null;
            } else if (status == CounselingStatus.pendingReview) {
              try {
                log = logs.firstWhere((l) => l.action == 'requested');
              } catch (e) {
                log = logs.first;
              }
            } else if (status == CounselingStatus.confirmed) {
              try {
                log = logs.firstWhere((l) => l.action == 'confirmed');
              } catch (e) {
                log = logs.length > 1 ? logs[1] : logs.first;
              }
            } else if (status == CounselingStatus.settled) {
              try {
                log = logs.firstWhere((l) => l.action == 'settled');
              } catch (e) {
                log = logs.last;
              }
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            isCurrent || isCompleted
                                ? _getStatusColor(status)
                                : AppTheme.lightGray,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child:
                          isCurrent || isCompleted
                              ? Icon(
                                _getStatusIcon(status),
                                size: 14,
                                color: Colors.white,
                              )
                              : null,
                    ),
                    if (index < statuses.length - 1)
                      Container(
                        width: 2,
                        height: 60,
                        color:
                            isCompleted
                                ? _getStatusColor(status)
                                : AppTheme.lightGray,
                      ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isCurrent || isCompleted
                                  ? _getStatusColor(
                                    status,
                                  ).withValues(alpha: 0.1)
                                  : AppTheme.lightGray.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color:
                                isCurrent || isCompleted
                                    ? _getStatusColor(status)
                                    : AppTheme.mediumGray,
                          ),
                        ),
                      ),
                      if (log != null && log.note != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.lightBlue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            log.note!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.darkGray,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      if (log != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: AppTheme.mediumGray,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat(
                                'MMM dd, yyyy • HH:mm',
                              ).format(log.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.mediumGray,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (index < statuses.length - 1)
                        const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
    );
  }

  bool _isStatusCompleted(CounselingStatus current, CounselingStatus check) {
    final order = [
      CounselingStatus.pendingReview,
      CounselingStatus.confirmed,
      CounselingStatus.settled,
    ];
    return order.indexOf(current) > order.indexOf(check);
  }
}
