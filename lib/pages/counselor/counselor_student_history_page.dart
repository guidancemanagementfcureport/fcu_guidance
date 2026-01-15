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

class CounselorStudentHistoryPage extends StatefulWidget {
  const CounselorStudentHistoryPage({super.key});

  @override
  State<CounselorStudentHistoryPage> createState() =>
      _CounselorStudentHistoryPageState();
}

class _CounselorStudentHistoryPageState
    extends State<CounselorStudentHistoryPage> {
  final _supabase = SupabaseService();
  bool _isLoading = true;
  List<CounselingRequestModel> _requests = [];
  Map<String, ReportModel?> _reportMap = {};
  Map<String, List<CounselingActivityLog>> _activityLogsMap = {};
  final Map<String, UserModel> _userCache = {};
  CounselingStatus? _selectedFilter;
  final _notesController = TextEditingController();
  DateTime? _dialogDate;
  TimeOfDay? _dialogTime;
  String _dialogSessionType = 'Individual';
  String _dialogLocationMode = 'In-person';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final counselorId = authProvider.currentUser?.id;

      if (counselorId != null) {
        final requests = await _supabase.getAllCounselingRequestsForCounselor(
          counselorId: counselorId,
          status: _selectedFilter,
        );

        final reportsMap = <String, ReportModel?>{};
        final logsMap = <String, List<CounselingActivityLog>>{};

        for (final request in requests) {
          if (request.reportId != null) {
            final report = await _supabase.getReportById(request.reportId!);
            reportsMap[request.id] = report;

            if (report?.teacherId != null &&
                !_userCache.containsKey(report!.teacherId!)) {
              final teacher = await _supabase.getUserById(report.teacherId!);
              if (teacher != null) {
                _userCache[report.teacherId!] = teacher;
              }
            }
          }

          final logs = await _supabase.getCounselingActivityLogs(request.id);
          logsMap[request.id] = logs;

          // Cache participants names
          if (request.participants != null) {
            for (final p in request.participants!) {
              final uid = p['userId'] ?? p['user_id'];
              if (uid is String &&
                  uid != 'parent' &&
                  !_userCache.containsKey(uid)) {
                final user = await _supabase.getUserById(uid);
                if (user != null) {
                  _userCache[uid] = user;
                }
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _requests = requests;
            _reportMap = reportsMap;
            _activityLogsMap = logsMap;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error loading requests: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmRequest(
    CounselingRequestModel request,
    DateTime? sessionDate,
    TimeOfDay? sessionTime,
    String? sessionType,
    String? locationMode,
  ) async {
    if (sessionDate == null || sessionTime == null) {
      ToastUtils.showWarning(context, 'Please set a session date and time');
      return;
    }

    final note = _notesController.text.trim();
    if (note.isEmpty) {
      ToastUtils.showWarning(context, 'Please add a note before confirming');
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final counselorId = authProvider.currentUser?.id;

      if (counselorId != null) {
        await _supabase.updateCounselingRequest(
          requestId: request.id,
          status: CounselingStatus.confirmed,
          counselorId: counselorId,
          counselorNote: note,
          sessionDate: sessionDate,
          sessionTime: sessionTime,
          sessionType: sessionType,
          locationMode: locationMode,
        );

        if (mounted) {
          ToastUtils.showSuccess(context, 'Counseling request confirmed');
          Navigator.pop(context);
          _notesController.clear();
          _loadRequests();
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error confirming request: $e');
      }
    }
  }

  Future<void> _settleRequest(CounselingRequestModel request) async {
    final note = _notesController.text.trim();
    if (note.isEmpty) {
      ToastUtils.showWarning(
        context,
        'Please add closing notes before settling',
      );
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final counselorId = authProvider.currentUser?.id;

      if (counselorId != null) {
        await _supabase.updateCounselingRequest(
          requestId: request.id,
          status: CounselingStatus.settled,
          counselorId: counselorId,
          counselorNote: note,
        );

        if (request.reportId != null) {
          await _supabase.updateReportStatus(
            reportId: request.reportId!,
            status: ReportStatus.settled,
            counselorId: counselorId,
            note: 'Case settled through counseling',
          );
        }

        if (mounted) {
          ToastUtils.showSuccess(context, 'Case settled successfully');
          Navigator.pop(context);
          _notesController.clear();
          _loadRequests();
        }
      }
    } catch (e) {
      if (mounted) ToastUtils.showError(context, 'Error settling request: $e');
    }
  }

  void _showRequestDetails(CounselingRequestModel request) {
    final report = _reportMap[request.id];
    final logs = _activityLogsMap[request.id] ?? [];
    _notesController.clear();

    // Initialize temporary dialog state
    _dialogDate = null;
    _dialogTime = null;
    _dialogSessionType =
        (request.participants != null && request.participants!.isNotEmpty)
            ? 'Group'
            : 'Individual';
    _dialogLocationMode = 'In-person';

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 800,
                      maxHeight: 850,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.deepBlue, AppTheme.infoBlue],
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.psychology_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'Counseling Session Details',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          request.status,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        request.status.displayName
                                            .toUpperCase(),
                                        style: TextStyle(
                                          color: _getStatusColor(
                                            request.status,
                                          ),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'MMMM dd, yyyy hh:mm a',
                                      ).format(request.createdAt),
                                      style: const TextStyle(
                                        color: AppTheme.mediumGray,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),

                                if (report != null) ...[
                                  _buildSectionHeader(
                                    Icons.assignment_outlined,
                                    'Related Case Report',
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDetailItem('Case Title', report.title),
                                  _buildDetailItem('Case Type', report.type),
                                  _buildDetailItem(
                                    'Current Status',
                                    report.status.displayName,
                                  ),
                                  if (report.teacherId != null &&
                                      _userCache.containsKey(report.teacherId!))
                                    _buildDetailItem(
                                      'Referred By',
                                      '${_userCache[report.teacherId!]!.fullName} (Teacher)',
                                    ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppTheme.lightGray.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      report.details,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.deepBlue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                ],

                                _buildSectionHeader(
                                  Icons.chat_bubble_outline_rounded,
                                  'Student Request Reason',
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.skyBlue.withValues(
                                      alpha: 0.05,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.skyBlue.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    request.reason ?? 'No reason provided',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 32),
                                _buildSectionHeader(
                                  Icons.info_outline_rounded,
                                  'Session Settings',
                                ),
                                const SizedBox(height: 16),
                                if (request.participants != null &&
                                    request.participants!.isNotEmpty)
                                  _buildDetailItem(
                                    'Participants',
                                    request.participants!
                                        .map((p) {
                                          final role =
                                              p['role'] ?? 'Participant';
                                          final uid =
                                              p['userId'] ??
                                              p['user_id'] ??
                                              (role == 'parent'
                                                  ? 'parent'
                                                  : null);

                                          if (uid == null) {
                                            return 'Unknown ($role)';
                                          }
                                          final name =
                                              uid == 'parent'
                                                  ? 'Parent/Guardian'
                                                  : (_userCache[uid]
                                                          ?.fullName ??
                                                      'Unknown');
                                          return '$name ($role)';
                                        })
                                        .join(', '),
                                  ),
                                _buildDetailItem(
                                  'Session Type',
                                  request.sessionType ?? _dialogSessionType,
                                ),
                                _buildDetailItem(
                                  'Location/Mode',
                                  request.locationMode ?? _dialogLocationMode,
                                ),

                                // Show scheduled details if already confirmed
                                if (request.status !=
                                        CounselingStatus.pendingReview &&
                                    request.sessionDate != null) ...[
                                  const SizedBox(height: 24),
                                  _buildSectionHeader(
                                    Icons.event_available_rounded,
                                    'Confirmed Schedule',
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDetailItem(
                                    'Date',
                                    DateFormat(
                                      'MMMM dd, yyyy',
                                    ).format(request.sessionDate!),
                                  ),
                                  if (request.sessionTime != null)
                                    _buildDetailItem(
                                      'Time',
                                      request.sessionTime!.format(context),
                                    ),
                                  if (request.sessionType != null)
                                    _buildDetailItem(
                                      'Type',
                                      request.sessionType!,
                                    ),
                                  if (request.locationMode != null)
                                    _buildDetailItem(
                                      'Mode',
                                      request.locationMode!,
                                    ),
                                ],

                                const SizedBox(height: 32),
                                _buildSectionHeader(
                                  Icons.history_rounded,
                                  'Session Activity Log',
                                ),
                                const SizedBox(height: 16),
                                ...logs.map((log) => _buildTimelineItem(log)),

                                const SizedBox(height: 32),

                                // Confirmation UI for Pending requests
                                if (request.status ==
                                    CounselingStatus.pendingReview) ...[
                                  _buildSectionHeader(
                                    Icons.schedule_rounded,
                                    'Set Official Schedule',
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: DateTime.now().add(
                                                const Duration(days: 1),
                                              ),
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime.now().add(
                                                const Duration(days: 365),
                                              ),
                                            );
                                            if (picked != null) {
                                              setDialogState(
                                                () => _dialogDate = picked,
                                              );
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: AppTheme.lightGray,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.calendar_today,
                                                  size: 18,
                                                  color: AppTheme.skyBlue,
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  _dialogDate == null
                                                      ? 'Select Date'
                                                      : DateFormat(
                                                        'MMM dd, yyyy',
                                                      ).format(_dialogDate!),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () async {
                                            final picked = await showTimePicker(
                                              context: context,
                                              initialTime: TimeOfDay.now(),
                                            );
                                            if (picked != null) {
                                              setDialogState(
                                                () => _dialogTime = picked,
                                              );
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: AppTheme.lightGray,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.access_time,
                                                  size: 18,
                                                  color: AppTheme.skyBlue,
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  _dialogTime == null
                                                      ? 'Select Time'
                                                      : _dialogTime!.format(
                                                        context,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 32),
                                ],

                                _buildSectionHeader(
                                  Icons.note_alt_outlined,
                                  'Counselor Response',
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _notesController,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText:
                                        request.status ==
                                                CounselingStatus.pendingReview
                                            ? 'Enter your assessment and meeting instructions...'
                                            : 'Add closing observations and guidance summary...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 16),
                              if (request.status ==
                                  CounselingStatus.pendingReview)
                                FilledButton(
                                  onPressed:
                                      () => _confirmRequest(
                                        request,
                                        _dialogDate,
                                        _dialogTime,
                                        _dialogSessionType,
                                        _dialogLocationMode,
                                      ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.successGreen,
                                  ),
                                  child: const Text('Confirm & Set Schedule'),
                                )
                              else if (request.status ==
                                  CounselingStatus.confirmed)
                                FilledButton(
                                  onPressed: () => _settleRequest(request),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.deepBlue,
                                  ),
                                  child: const Text('Settle & Close Session'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.skyBlue, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.deepBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.mediumGray, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppTheme.deepBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(CounselingActivityLog log) {
    return Container(
      margin: const EdgeInsets.only(left: 10, bottom: 20),
      padding: const EdgeInsets.only(left: 20),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppTheme.skyBlue, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                log.action.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.skyBlue,
                ),
              ),
              Text(
                DateFormat('MMM dd, HH:mm').format(log.timestamp),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.mediumGray,
                ),
              ),
            ],
          ),
          if (log.note != null) ...[
            const SizedBox(height: 4),
            Text(
              log.note!,
              style: const TextStyle(fontSize: 13, color: AppTheme.darkGray),
            ),
          ],
        ],
      ),
    );
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
                title: 'Student Guidance History',
                subtitle:
                    'Monitor counseling requests and professional session outcomes',
                icon: Icons.history_rounded,
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                          onRefresh: _loadRequests,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final width =
                                  constraints.maxWidth -
                                  48; // Account for padding
                              int columns = 1;
                              if (width >= 900) {
                                columns = 3;
                              } else if (width >= 600) {
                                columns = 2;
                              }

                              final spacing = 16.0;
                              final cardWidth =
                                  (width - (columns - 1) * spacing) / columns;

                              final isMobile = width < 600;

                              return ListView(
                                padding: EdgeInsets.all(isMobile ? 16 : 24),
                                children: [
                                  _buildStatsRow(width),
                                  SizedBox(height: isMobile ? 24 : 32),
                                  _buildFiltersHeader(isMobile: isMobile),
                                  const SizedBox(height: 16),
                                  if (_requests.isEmpty)
                                    _buildEmptyState()
                                  else
                                    Wrap(
                                      spacing: spacing,
                                      runSpacing: spacing,
                                      children:
                                          _requests
                                              .map(
                                                (req) => SizedBox(
                                                  width: cardWidth,
                                                  child: _buildRequestCard(req),
                                                ),
                                              )
                                              .toList(),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(double width) {
    final pendingCount =
        _requests
            .where((r) => r.status == CounselingStatus.pendingReview)
            .length;
    final activeCount =
        _requests.where((r) => r.status == CounselingStatus.confirmed).length;
    final settledCount =
        _requests.where((r) => r.status == CounselingStatus.settled).length;

    if (width >= 600) {
      return Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Pending Review',
              pendingCount.toString(),
              AppTheme.warningOrange,
              Icons.pending_actions_rounded,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'In Progress',
              activeCount.toString(),
              AppTheme.skyBlue,
              Icons.psychology_rounded,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryCard(
              'Completed',
              settledCount.toString(),
              AppTheme.successGreen,
              Icons.verified_rounded,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildSummaryCard(
          'Pending Review',
          pendingCount.toString(),
          AppTheme.warningOrange,
          Icons.pending_actions_rounded,
          isMobile: true,
        ),
        const SizedBox(height: 8),
        _buildSummaryCard(
          'In Progress',
          activeCount.toString(),
          AppTheme.skyBlue,
          Icons.psychology_rounded,
          isMobile: true,
        ),
        const SizedBox(height: 8),
        _buildSummaryCard(
          'Completed',
          settledCount.toString(),
          AppTheme.successGreen,
          Icons.verified_rounded,
          isMobile: true,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    Color color,
    IconData icon, {
    bool isMobile = false,
  }) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.mediumGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).fadeInSlideUp();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.mediumGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ).fadeInSlideUp();
  }

  Widget _buildFiltersHeader({bool isMobile = false}) {
    return Row(
      children: [
        Text(
          isMobile ? 'Filter:' : 'Status Filter:',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.deepBlue,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCustomChip(null, 'All Sessions'),
                _buildCustomChip(CounselingStatus.pendingReview, 'Pending'),
                _buildCustomChip(CounselingStatus.confirmed, 'Active'),
                _buildCustomChip(CounselingStatus.settled, 'Completed'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomChip(CounselingStatus? status, String label) {
    final isSelected = _selectedFilter == status;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = status);
        _loadRequests();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.skyBlue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? AppTheme.skyBlue
                    : AppTheme.lightGray.withValues(alpha: 0.5),
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: AppTheme.skyBlue.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.mediumGray,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(64),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.lightGray.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.psychology_outlined, size: 80, color: AppTheme.lightGray),
          const SizedBox(height: 24),
          const Text(
            'No records found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'There are no counseling sessions matching your selection.',
            style: TextStyle(color: AppTheme.mediumGray),
          ),
        ],
      ),
    ).fadeInSlideUp();
  }

  Widget _buildRequestCard(CounselingRequestModel request) {
    final report = _reportMap[request.id];
    final color = _getStatusColor(request.status);

    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: AppTheme.lightGray.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showRequestDetails(request),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
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
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.forum_rounded, color: color, size: 20),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        request.status.displayName.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  report?.title ?? 'Personal Guidance',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.deepBlue,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'Requested: ${DateFormat('MMM dd, yyyy').format(request.createdAt)}',
                  style: const TextStyle(
                    color: AppTheme.mediumGray,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      request.locationMode == 'Online'
                          ? Icons.videocam_outlined
                          : Icons.location_on_outlined,
                      size: 14,
                      color: AppTheme.mediumGray,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      request.locationMode ?? _dialogLocationMode,
                      style: const TextStyle(
                        color: AppTheme.mediumGray,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.people_outline,
                      size: 14,
                      color: AppTheme.mediumGray,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${request.participants?.length ?? 1} Participants',
                      style: const TextStyle(
                        color: AppTheme.mediumGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Divider(height: 24),
                Row(
                  children: [
                    const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.skyBlue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppTheme.skyBlue,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).fadeInSlideUp();
  }

  Color _getStatusColor(CounselingStatus status) {
    switch (status) {
      case CounselingStatus.pendingReview:
        return AppTheme.warningOrange;
      case CounselingStatus.confirmed:
        return AppTheme.skyBlue;
      case CounselingStatus.settled:
        return AppTheme.successGreen;
    }
  }
}
