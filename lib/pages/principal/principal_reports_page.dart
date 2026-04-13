import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/report_model.dart';
import '../../models/counseling_request_model.dart';
import '../../models/report_activity_log_model.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';
// import 'dean_approval_dialog.dart';
// import 'dean_schedule_counseling_page.dart';

class PrincipalReportsPage extends StatefulWidget {
  const PrincipalReportsPage({super.key});

  @override
  State<PrincipalReportsPage> createState() => _PrincipalReportsPageState();
}

class _PrincipalReportsPageState extends State<PrincipalReportsPage> {
  final _supabase = SupabaseService();
  bool _isLoading = true;
  List<ReportModel> _reports = [];
  List<ReportModel> _filteredReports = [];
  List<ReportActivityLog> _activityLogs = [];
  final Map<String, UserModel> _userCache = {};
  String _filterStatus = 'all';
  String _studentLevelFilter = 'all'; // all | juniorHigh | seniorHigh
  List<ReportModel> _allDedupedReports = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
      final currentRole = currentUser?.role;

      // Get reports based on role mapping
      final allReports = await _supabase.getDeanReports(role: currentRole);
      final finalRecords =
          allReports
              .where((r) => r.status == ReportStatus.counselorReviewed || r.status == ReportStatus.completed || r.status == ReportStatus.settled)
              .toList();

      final filtered = _deduplicateForwardedCopies(finalRecords);

      _allDedupedReports = filtered;

      // Batch-load student levels so the student-level dropdown can filter results.
      final studentIds =
          filtered.map((r) => r.studentId).whereType<String>().toSet().toList();
      if (studentIds.isNotEmpty) {
        final users = await _supabase.getUsersByIds(studentIds);
        for (final u in users) {
          _userCache[u.id] = u;
        }
      }

      if (mounted) {
        setState(() {
          _reports = _applyStudentLevelFilter(_allDedupedReports);
          _filteredReports = _reports;
          _isLoading = false;
        });
        _filterBySearch(_searchController.text);
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error loading reports: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  List<ReportModel> _applyStudentLevelFilter(List<ReportModel> source) {
    if (_studentLevelFilter == 'all') return source;

    final targetLevel = _studentLevelFilter == 'juniorHigh'
        ? StudentLevel.juniorHigh
        : StudentLevel.seniorHigh;

    return source.where((r) {
      if (r.studentId == null) return false; // can't determine level
      return _userCache[r.studentId!]?.studentLevel == targetLevel;
    }).toList();
  }

  int _countRecordsForLevel(StudentLevel level) {
    var count = 0;
    for (final r in _allDedupedReports) {
      final sid = r.studentId;
      if (sid == null) continue;
      if (_userCache[sid]?.studentLevel == level) {
        count++;
      }
    }
    return count;
  }

  String? _extractForwardSourceReportId(ReportModel report) {
    final note = report.counselorNote;
    if (note == null || note.isEmpty) return null;

    // Marker format comes from Forward Copy:
    // "(source report: <sourceReportId>)"
    final match = RegExp(r'source report:\s*([^)]+)\)', caseSensitive: false)
        .firstMatch(note);
    return match?.group(1)?.trim();
  }

  List<ReportModel> _deduplicateForwardedCopies(
    List<ReportModel> reports,
  ) {
    final latestByKey = <String, ReportModel>{};

    for (final report in reports) {
      final sourceId = _extractForwardSourceReportId(report);
      final key = sourceId != null ? 'forwarded:$sourceId' : 'report:${report.id}';

      final existing = latestByKey[key];
      if (existing == null) {
        latestByKey[key] = report;
        continue;
      }

      // Keep the most recently updated row for the same forwarded source.
      if (report.updatedAt.isAfter(existing.updatedAt)) {
        latestByKey[key] = report;
      }
    }

    final deduped = latestByKey.values.toList();
    deduped.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return deduped;
  }

  Future<void> _loadActivityLogs(String reportId) async {
    try {
      final logs = await _supabase.getReportActivityLogs(reportId);
      if (!mounted) {
        return;
      }
      setState(() {
        _activityLogs = logs;
      });
    } catch (e) {
      debugPrint('Error loading activity logs: $e');
    }
  }

  Future<void> _loadUserInfo(String? userId) async {
    if (userId == null || _userCache.containsKey(userId)) return;

    try {
      final user = await _supabase.getUserById(userId);
      if (user != null && mounted) {
        setState(() {
          _userCache[userId] = user;
        });
      }
    } catch (e) {
      debugPrint('Error loading user info: $e');
    }
  }

  void _filterBySearch(String query) {
    if (query.isEmpty) {
      setState(() => _filteredReports = _reports);
      return;
    }
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredReports =
          _reports.where((report) {
            final title = report.title.toLowerCase();
            final type = report.type.toLowerCase();
            final studentName =
                !report.isAnonymous && report.studentId != null
                    ? (_userCache[report.studentId]?.fullName.toLowerCase() ??
                        '')
                    : 'anonymous';

            return title.contains(lowerQuery) ||
                type.contains(lowerQuery) ||
                studentName.contains(lowerQuery);
          }).toList();
    });
  }

  Future<void> _viewReportDetails(ReportModel report) async {
    // Load related user info
    if (report.studentId != null) {
      await _loadUserInfo(report.studentId);
    }
    if (report.teacherId != null) {
      await _loadUserInfo(report.teacherId);
    }
    if (report.counselorId != null) {
      await _loadUserInfo(report.counselorId);
    }

    // Load counseling request if exists to check for extra participants (e.g. parents)
    CounselingRequestModel? counselingRequest;
    try {
      counselingRequest = await _supabase.getCounselingRequestByReportId(
        report.id,
      );
      if (counselingRequest != null && counselingRequest.participants != null) {
        for (final participant in counselingRequest.participants!) {
          if (participant['userId'] != null) {
            await _loadUserInfo(participant['userId']);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading counseling request: $e');
    }

    await _loadActivityLogs(report.id);

    // Mark as seen/read when opened, similar to Counselor's implementation
    if (mounted) {
      context.read<NotificationProvider>().markReportAsSeen(report.id);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => _buildReportDetailsDialog(report, counselingRequest),
    );
  }

  Future<void> _viewAttachment(String url) async {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('.jpg') ||
        lowerUrl.contains('.jpeg') ||
        lowerUrl.contains('.png') ||
        lowerUrl.contains('.gif') ||
        lowerUrl.contains('.webp')) {
      _showImageDialog(url);
    } else {
      final uri = Uri.parse(url);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ToastUtils.showError(context, 'Could not open attachment');
          }
        }
      } catch (e) {
        if (mounted) {
          ToastUtils.showError(context, 'Error opening link: $e');
        }
      }
    }
  }

  void _showImageDialog(String url) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(10),
            child: Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: InteractiveViewer(
                    maxScale: 5.0,
                    child: Image.network(
                      url,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder:
                          (context, error, stackTrace) => Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error, color: Colors.red, size: 48),
                                SizedBox(height: 16),
                                Text('Error loading image'),
                              ],
                            ),
                          ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

// Approval functionality moved to Counselor

  // _scheduleCounseling removed as it was unused

  Widget _buildReportDetailsDialog(
    ReportModel report, [
    CounselingRequestModel? counselingRequest,
  ]) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        child: Column(
          children: [
            // Custom Header with Gradient
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Report Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge and Header Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              report.status,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getStatusColor(
                                report.status,
                              ).withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: _getStatusColor(report.status),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                report.status.displayName.toUpperCase(),
                                style: TextStyle(
                                  color: _getStatusColor(report.status),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'ID: ${report.id.substring(0, 8).toUpperCase()}',
                          style: TextStyle(
                            color: AppTheme.mediumGray,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Student Information Section
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.skyBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            color: AppTheme.skyBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Student Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (report.isAnonymous) ...[
                      _buildInfoRow('Name', 'Anonymous'),
                      if (report.trackingId != null)
                        _buildInfoRow('Tracking ID', report.trackingId!),
                    ] else if (report.studentId != null)
                      Builder(
                        builder: (context) {
                          final student = _userCache[report.studentId];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(
                                'Name',
                                student?.fullName ?? 'Loading...',
                              ),
                              _buildInfoRow(
                                'Email',
                                student?.gmail ?? 'Loading...',
                              ),
                              // Student Level Badge
                              if (student?.studentLevel != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _getStudentLevelColor(
                                      student?.studentLevel,
                                    ).withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _getStudentLevelColor(
                                        student?.studentLevel,
                                      ).withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: _getStudentLevelColor(
                                            student?.studentLevel,
                                          ).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.school_rounded,
                                          color: _getStudentLevelColor(
                                            student?.studentLevel,
                                          ),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Student Level',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.mediumGray,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              student!
                                                  .studentLevel!
                                                  .displayName,
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: _getStudentLevelColor(
                                                  student.studentLevel,
                                                ),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              // Student Level Details
                              if (student?.studentLevel ==
                                  StudentLevel.juniorHigh) ...[
                                if (student?.gradeLevel != null)
                                  _buildInfoRow(
                                    'Grade Level',
                                    student!.gradeLevel!,
                                  ),
                                if (student?.section != null)
                                  _buildInfoRow('Section', student!.section!),
                              ] else if (student?.studentLevel ==
                                  StudentLevel.seniorHigh) ...[
                                if (student?.gradeLevel != null)
                                  _buildInfoRow(
                                    'Grade Level',
                                    student!.gradeLevel!,
                                  ),
                                if (student?.strand != null)
                                  _buildInfoRow('Strand', student!.strand!),
                              ] else if (student?.studentLevel ==
                                  StudentLevel.college) ...[
                                if (student?.course != null)
                                  _buildInfoRow('Course', student!.course!),
                                if (student?.yearLevel != null)
                                  _buildInfoRow(
                                    'Year Level',
                                    student!.yearLevel!,
                                  ),
                              ] else ...[
                                // Fallback for old data
                                if (student?.course != null)
                                  _buildInfoRow('Course', student!.course!),
                                if (student?.gradeLevel != null)
                                  _buildInfoRow(
                                    'Grade Level',
                                    student!.gradeLevel!,
                                  ),
                              ],
                            ],
                          );
                        },
                      ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    // Report Information Section
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.warningOrange.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.assignment_outlined,
                            color: AppTheme.warningOrange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Report Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Title', report.title),
                    _buildInfoRow('Type', report.type),
                    _buildInfoRow(
                      'Submitted',
                      DateFormat('MMM dd, yyyy HH:mm').format(report.createdAt),
                    ),
                    if (report.incidentDate != null)
                      _buildInfoRow(
                        'Incident Date',
                        DateFormat(
                          'MMM dd, yyyy HH:mm',
                        ).format(report.incidentDate!),
                      ),

                    const SizedBox(height: 24),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.skyBlue.withValues(alpha: 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        (report.details.isNotEmpty)
                            ? report.details
                            : 'No description provided.',
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: AppTheme.deepBlue,
                        ),
                      ),
                    ),

                    // Attachments
                    if (report.attachmentUrl != null &&
                        report.attachmentUrl!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Attachments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final urls = report.attachmentUrl!.split(',');
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children:
                                urls.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final url = entry.value.trim();
                                  if (url.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return OutlinedButton.icon(
                                    onPressed: () => _viewAttachment(url),
                                    icon: const Icon(
                                      Icons.attach_file,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Attachment ${urls.length > 1 ? index + 1 : ''}',
                                    ),
                                  );
                                }).toList(),
                          );
                        },
                      ),
                    ],

                    // Internal Notes (Dean can see all)
                    if (report.teacherNote != null ||
                        report.counselorNote != null ||
                        report.deanNote != null) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      const Text(
                        'Internal Notes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (report.teacherNote != null &&
                          report.teacherNote!.isNotEmpty) ...[
                        const Text(
                          'Teacher Notes',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mediumBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.successGreen.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(report.teacherNote!),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (report.counselorNote != null &&
                          report.counselorNote!.isNotEmpty) ...[
                        const Text(
                          'Counselor Notes',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mediumBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.warningOrange.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.warningOrange.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(report.counselorNote!),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (report.deanNote != null &&
                          report.deanNote!.isNotEmpty) ...[
                        const Text(
                          'Dean Notes',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mediumBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.deepBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.deepBlue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(report.deanNote!),
                        ),
                      ],
                    ],

                    // Participants Section
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.people_outline,
                            color: Colors.purple,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Participants',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final studentName =
                            report.isAnonymous
                                ? 'Anonymous Student'
                                : (_userCache[report.studentId]?.fullName ??
                                    'Loading...');

                        final teacher =
                            (report.teacherId != null)
                                ? _userCache[report.teacherId]
                                : null;
                        final teacherName =
                            teacher != null
                                ? '${teacher.fullName} (Teacher)'
                                : 'Not Assigned';

                        final counselor =
                            (report.counselorId != null)
                                ? _userCache[report.counselorId]
                                : null;
                        final counselorName =
                            counselor != null
                                ? '${counselor.fullName} (Counselor)'
                                : 'Not Assigned';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Student', studentName),
                            _buildInfoRow('Teacher', teacherName),
                            _buildInfoRow('Counselor', counselorName),

                            // Additional Participants from Counseling Request
                            if (counselingRequest?.participants != null &&
                                counselingRequest!.participants!.isNotEmpty)
                              for (final participant
                                  in counselingRequest.participants!)
                                Builder(
                                  builder: (context) {
                                    String label =
                                        participant['role']?.toString() ??
                                        'Participant';
                                    String value;

                                    if (participant['userId'] != null) {
                                      value =
                                          _userCache[participant['userId']]
                                              ?.fullName ??
                                          'Loading...';
                                    } else if (participant['name'] != null) {
                                      value = participant['name'];
                                    } else if (label.toLowerCase() ==
                                        'parent') {
                                      value = 'Invitation Requested';
                                      label = 'Parent/Guardian';
                                    } else {
                                      value = 'Unknown';
                                    }
                                    return _buildInfoRow(label, value);
                                  },
                                ),
                          ],
                        );
                      },
                    ),

                    // Activity Timeline
                    if (_activityLogs.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      const Text(
                        'Activity Timeline',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._activityLogs.map((log) => _buildActivityLogItem(log)),
                    ],
                  ],
                ),
              ),
            ),
            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.lightGray,
                border: Border(
                  top: BorderSide(
                    color: AppTheme.skyBlue.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
// Action buttons removed for Dean user.
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStudentLevelColor(StudentLevel? level) {
    if (level == null) {
      return AppTheme.mediumGray;
    }
    switch (level) {
      case StudentLevel.juniorHigh:
        return const Color(0xFF3B82F6); // Blue
      case StudentLevel.seniorHigh:
        return const Color(0xFF10B981); // Green
      case StudentLevel.college:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.mediumBlue,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.deepBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLogItem(ReportActivityLog log) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 12),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.action.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppTheme.mediumBlue,
                  ),
                ),
                if (log.note != null && log.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(log.note!, style: const TextStyle(fontSize: 13)),
                ],
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy HH:mm').format(log.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.counselorReviewed:
        return AppTheme.warningOrange;
      case ReportStatus.approvedByDean:
        return AppTheme.successGreen;
      case ReportStatus.counselingScheduled:
        return AppTheme.successGreen;
      default:
        return AppTheme.mediumBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return ResponsiveSidebar(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: AppTheme.softBlueGradientDecoration,
          child: Column(
            children: [
              const ModernDashboardHeader(
                title: 'Report Review',
                subtitle: 'Oversee and act on student incident reports',
                icon: Icons.fact_check_rounded,
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                          onRefresh: _loadReports,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStatsHeader(isDesktop),
                                const SizedBox(height: 32),
                                _buildSearchAndFilters(),
                                const SizedBox(height: 24),
                                _buildReportsContent(isDesktop),
                              ],
                            ),
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsHeader(bool isDesktop) {
    final total = _reports.length;
    final juniorHighCount = _countRecordsForLevel(StudentLevel.juniorHigh);
    final seniorHighCount = _countRecordsForLevel(StudentLevel.seniorHigh);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        int columns = 1;
        if (availableWidth >= 750) {
          columns = 3;
        } else if (availableWidth >= 500) {
          columns = 2;
        }

        final spacing = 16.0;
        final cardWidth = (availableWidth - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _DeanReportStatMiniCard(
              label: 'Finalized Records',
              value: total.toString(),
              color: AppTheme.skyBlue,
              icon: Icons.assignment_outlined,
              width: cardWidth,
            ),
            _DeanReportStatMiniCard(
              label: 'Junior High Records',
              value: juniorHighCount.toString(),
              color: const Color(0xFF3B82F6),
              icon: Icons.school_rounded,
              width: cardWidth,
            ),
            _DeanReportStatMiniCard(
              label: 'Senior High Records',
              value: seniorHighCount.toString(),
              color: const Color(0xFF10B981),
              icon: Icons.school_rounded,
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterBySearch,
                  decoration: InputDecoration(
                    hintText: 'Search by title, student, or type...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppTheme.mediumGray,
                    ),
                    filled: true,
                    fillColor: AppTheme.lightGray.withValues(alpha: 0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_studentLevelFilter),
                  initialValue: _studentLevelFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Student Level',
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.mediumGray,
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: const Icon(
                      Icons.school_outlined,
                      size: 18,
                      color: AppTheme.mediumGray,
                    ),
                    filled: true,
                    fillColor: AppTheme.skyBlue.withValues(alpha: 0.07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('All Levels'),
                    ),
                    DropdownMenuItem(
                      value: 'juniorHigh',
                      child: Text('Junior High'),
                    ),
                    DropdownMenuItem(
                      value: 'seniorHigh',
                      child: Text('Senior High'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _studentLevelFilter = value);
                    setState(() {
                      _reports = _applyStudentLevelFilter(_allDedupedReports);
                      _filteredReports = _reports;
                    });
                    _filterBySearch(_searchController.text);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.skyBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppTheme.mediumGray,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tip: Use “Student Level” to quickly view Junior High or Senior High forwarded records.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGray.withValues(alpha: 0.95),
                    height: 1.25,
                  ),
                ),
              ),
              Tooltip(
                message:
                    'This filter is available only on the Principal account.',
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.skyBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppTheme.skyBlue,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'Final Records'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status, String label) {
    final isSelected = _filterStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterStatus = status);
          _loadReports();
        }
      },
      selectedColor: AppTheme.skyBlue.withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.skyBlue : AppTheme.mediumGray,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              isSelected
                  ? AppTheme.skyBlue
                  : AppTheme.lightGray.withValues(alpha: 0.5),
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildReportsContent(bool isDesktop) {
    if (_filteredReports.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: AppTheme.lightGray),
            const SizedBox(height: 16),
            const Text(
              'No reports found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepBlue,
              ),
            ),
            const Text(
              'Try adjusting your filters or search',
              style: TextStyle(color: AppTheme.mediumGray),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
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
                Text(
                  _filterStatus == 'all'
                      ? 'All Active Reports'
                      : '${_filterStatus[0].toUpperCase()}${_filterStatus.substring(1)} Reports',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepBlue,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.skyBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filteredReports.length} Items',
                    style: const TextStyle(
                      color: AppTheme.skyBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredReports.length,
            separatorBuilder:
                (context, index) =>
                    const Divider(height: 1, indent: 24, endIndent: 24),
            itemBuilder: (context, index) {
              final report = _filteredReports[index];
              return _buildReportListItem(report, isDesktop);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportListItem(ReportModel report, bool isDesktop) {
    final notificationProvider = context.watch<NotificationProvider>();
    final isNew = notificationProvider.notifications.any(
      (n) =>
          !n.isRead &&
          n.type == NotificationType.newReport &&
          n.data['report_id'] == report.id,
    );

    return InkWell(
      onTap: () => _viewReportDetails(report),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      report.status,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    color: _getStatusColor(report.status),
                    size: 24,
                  ),
                ),
                if (isNew)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isNew)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          report.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepBlue,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.isAnonymous
                        ? 'Anonymous Reporter'
                        : (_userCache[report.studentId]?.fullName ??
                            'Loading student...'),
                    style: const TextStyle(
                      color: AppTheme.mediumGray,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isDesktop)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Case Type',
                      style: TextStyle(
                        color: AppTheme.mediumGray,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.type,
                      style: const TextStyle(
                        color: AppTheme.deepBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            if (isDesktop)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Received',
                      style: TextStyle(
                        color: AppTheme.mediumGray,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat(
                        'MMM dd, yyyy • HH:mm',
                      ).format(report.createdAt),
                      style: const TextStyle(
                        color: AppTheme.deepBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(report.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                report.status.displayName.toUpperCase(),
                style: TextStyle(
                  color: _getStatusColor(report.status),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.lightGray),
          ],
        ),
      ),
    );
  }
}

class _DeanReportStatMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double width;

  const _DeanReportStatMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepBlue,
                    height: 1.1,
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
          ),
        ],
      ),
    );
  }
}
