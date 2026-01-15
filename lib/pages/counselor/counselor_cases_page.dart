import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/report_model.dart';
import '../../models/notification_model.dart';
import '../../models/report_activity_log_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';

class CounselorCasesPage extends StatefulWidget {
  const CounselorCasesPage({super.key});

  @override
  State<CounselorCasesPage> createState() => _CounselorCasesPageState();
}

class _CounselorCasesPageState extends State<CounselorCasesPage> {
  final _supabase = SupabaseService();
  bool _isLoading = true;
  List<ReportModel> _reports = [];
  ReportModel? _selectedReport;
  List<ReportActivityLog> _activityLogs = [];
  final _notesController = TextEditingController();
  final Map<String, UserModel> _studentCache = {};
  final Map<String, UserModel> _teacherCache = {};

  @override
  void initState() {
    super.initState();
    _loadReports();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser != null) {
          context.read<NotificationProvider>().markNotificationsAsSeenForRoute(
            authProvider.currentUser!.id,
            '/counselor/cases',
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final counselorId = authProvider.currentUser?.id;

      if (counselorId != null) {
        final reports = await _supabase.getForwardedReports(counselorId);
        if (mounted) {
          setState(() {
            _reports = reports;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error loading reports: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadActivityLogs(String reportId) async {
    try {
      final logs = await _supabase.getReportActivityLogs(reportId);
      if (mounted) {
        setState(() {
          _activityLogs = logs;
        });
      }
    } catch (e) {
      debugPrint('Error loading activity logs: $e');
    }
  }

  Future<void> _acceptReport() async {
    if (_selectedReport == null) return;

    final note = _notesController.text.trim();
    if (note.isEmpty) {
      ToastUtils.showWarning(context, 'Please add notes before accepting');
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final counselorId = authProvider.currentUser?.id;

      if (counselorId != null) {
        await _supabase.updateReportStatus(
          reportId: _selectedReport!.id,
          status: ReportStatus.counselorConfirmed,
          counselorId: counselorId,
          note: note,
        );

        if (mounted) {
          ToastUtils.showSuccess(context, 'Report accepted successfully');
          _notesController.clear();
          _loadReports();
          setState(() => _selectedReport = null);
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error accepting report: $e');
      }
    }
  }

  Future<void> _confirmReport() async {
    if (_selectedReport == null) return;

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
        await _supabase.updateReportStatus(
          reportId: _selectedReport!.id,
          status: ReportStatus.settled,
          counselorId: counselorId,
          note: note,
        );

        if (mounted) {
          ToastUtils.showSuccess(context, 'Report settled successfully');
          _notesController.clear();
          _loadReports();
          setState(() => _selectedReport = null);
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error settling report: $e');
      }
    }
  }

  Future<void> _forwardToDean() async {
    if (_selectedReport == null) return;

    final note = _notesController.text.trim();
    if (note.isEmpty) {
      ToastUtils.showWarning(
        context,
        'Please add assessment notes before forwarding to Dean',
      );
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final counselorId = authProvider.currentUser?.id;

      if (counselorId != null) {
        await _supabase.updateReportStatus(
          reportId: _selectedReport!.id,
          status: ReportStatus.counselorReviewed,
          counselorId: counselorId,
          note: 'Forwarded to Dean for final action. Counselor Note: $note',
        );

        if (mounted) {
          ToastUtils.showSuccess(context, 'Report forwarded to Dean');
          _notesController.clear();
          _loadReports();
          setState(() => _selectedReport = null);
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error forwarding report: $e');
      }
    }
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

  Future<void> _loadStudentInfo(String? studentId) async {
    if (studentId == null || _studentCache.containsKey(studentId)) return;
    try {
      final user = await _supabase.getUserById(studentId);
      if (user != null && mounted) {
        setState(() {
          _studentCache[studentId] = user;
        });
      }
    } catch (e) {
      debugPrint('Error loading student info: $e');
    }
  }

  void _showReportDetails(ReportModel report) async {
    setState(() {
      _selectedReport = report;
      _activityLogs = [];
    });
    _loadActivityLogs(report.id);

    // Mark as seen when opened
    if (mounted) {
      context.read<NotificationProvider>().markReportAsSeen(report.id);
    }

    if (!report.isAnonymous && report.studentId != null) {
      _loadStudentInfo(report.studentId);
    }

    // Load teacher info
    if (report.teacherId != null &&
        !_teacherCache.containsKey(report.teacherId!)) {
      final teacher = await _supabase.getUserById(report.teacherId!);
      if (teacher != null && mounted) {
        setState(() {
          _teacherCache[report.teacherId!] = teacher;
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
                title: 'Case Management',
                subtitle:
                    'Review, accept, and provide professional feedback on active cases',
                icon: Icons.assignment_turned_in_rounded,
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 900) {
                              return Row(
                                children: [
                                  Container(
                                    width: 400,
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: AppTheme.lightGray,
                                        ),
                                      ),
                                    ),
                                    child: _buildCasesList(),
                                  ),
                                  Expanded(
                                    child:
                                        _selectedReport == null
                                            ? _buildEmptyDetailView()
                                            : _buildCaseDetailView(),
                                  ),
                                ],
                              );
                            } else {
                              if (_selectedReport != null) {
                                return _buildCaseDetailView();
                              }
                              return _buildCasesList();
                            }
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCasesList() {
    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 64,
              color: AppTheme.lightGray,
            ),
            const SizedBox(height: 16),
            const Text(
              'No cases found',
              style: TextStyle(
                color: AppTheme.mediumGray,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        return Consumer<NotificationProvider>(
          builder: (context, notificationProvider, child) {
            final isNew = notificationProvider.notifications.any(
              (n) =>
                  !n.isRead &&
                  n.type == NotificationType.newReport &&
                  n.data['report_id'] == report.id,
            );

            final isSelected = _selectedReport?.id == report.id;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppTheme.skyBlue.withValues(alpha: 0.05)
                        : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppTheme.skyBlue : Colors.white,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Row(
                  children: [
                    if (isNew)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.skyBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        report.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color:
                              isSelected ? AppTheme.skyBlue : AppTheme.deepBlue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      report.type,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat(
                        'MMM dd, yyyy • HH:mm',
                      ).format(report.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      report.status,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.status.displayName,
                    style: TextStyle(
                      color: _getStatusColor(report.status),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () => _showReportDetails(report),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyDetailView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_ind_rounded,
              size: 80,
              color: AppTheme.skyBlue.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Select a case to manage',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a report from the list to view details and take action',
            style: TextStyle(color: AppTheme.mediumGray),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseDetailView() {
    if (_selectedReport == null) return const SizedBox.shrink();

    final report = _selectedReport!;
    final student =
        report.studentId != null ? _studentCache[report.studentId] : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _selectedReport = null),
                style: IconButton.styleFrom(backgroundColor: Colors.white),
              ),
              const SizedBox(width: 16),
              const Text(
                'Case Analysis',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepBlue,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(report.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(
                      report.status,
                    ).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  report.status.displayName.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(report.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(28),
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
                _buildSectionTitle(
                  Icons.description_outlined,
                  'Basic Information',
                ),
                const SizedBox(height: 20),
                _buildInfoRow('Case Title', report.title),
                _buildInfoRow('Type', report.type),
                _buildInfoRow('Tracking ID', report.trackingId ?? 'N/A'),
                _buildInfoRow(
                  'Date',
                  DateFormat('MMMM dd, yyyy • HH:mm').format(report.createdAt),
                ),

                if (_teacherCache[report.teacherId] != null)
                  _buildInfoRow(
                    'Referred By',
                    '${_teacherCache[report.teacherId]!.fullName} (Teacher)',
                  ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(color: AppTheme.lightGray),
                ),

                _buildSectionTitle(
                  Icons.person_outline_rounded,
                  report.isAnonymous ? 'Anonymous Student' : 'Student Identity',
                ),
                const SizedBox(height: 20),
                if (report.isAnonymous)
                  const Text(
                    'Identity hidden for this report.',
                    style: TextStyle(
                      color: AppTheme.mediumGray,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else if (student != null) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.skyBlue.withValues(
                          alpha: 0.1,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppTheme.skyBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.deepBlue,
                            ),
                          ),
                          Text(
                            '${student.studentLevel?.displayName ?? ""} • ${student.department ?? ""}',
                            style: const TextStyle(
                              color: AppTheme.mediumGray,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else
                  const Text(
                    'Loading student info...',
                    style: TextStyle(color: AppTheme.mediumGray),
                  ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(color: AppTheme.lightGray),
                ),

                _buildSectionTitle(Icons.subject_rounded, 'Case Description'),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGray.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    report.details,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                ),

                if (report.teacherId != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(color: AppTheme.lightGray),
                  ),
                  _buildSectionTitle(
                    Icons.rate_review_outlined,
                    'Teacher\'s Approval Notes',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.skyBlue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.skyBlue.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      (report.teacherNote != null &&
                              report.teacherNote!.isNotEmpty)
                          ? report.teacherNote!
                          : 'No additional notes provided by the teacher.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color:
                            (report.teacherNote != null &&
                                    report.teacherNote!.isNotEmpty)
                                ? AppTheme.deepBlue
                                : AppTheme.mediumGray,
                        fontStyle:
                            (report.teacherNote != null &&
                                    report.teacherNote!.isNotEmpty)
                                ? FontStyle.normal
                                : FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Attachments Section
          if (report.attachmentUrl != null &&
              report.attachmentUrl!.isNotEmpty) ...[
            const SizedBox(height: 32),
            _buildSectionTitle(Icons.attach_file_rounded, 'Attachments'),
            const SizedBox(height: 16),
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
                        if (url.isEmpty) return const SizedBox.shrink();
                        return OutlinedButton.icon(
                          onPressed: () => _viewAttachment(url),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.attach_file, size: 18),
                          label: Text(
                            'View Attachment ${urls.length > 1 ? index + 1 : ''}',
                          ),
                        );
                      }).toList(),
                );
              },
            ),
          ],

          const SizedBox(height: 40),
          _buildSectionTitle(Icons.history_rounded, 'Activity Timeline'),
          const SizedBox(height: 20),
          ..._activityLogs.map((log) => _buildTimelineItem(log)),

          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 24),
          _buildSectionTitle(
            Icons.rate_review_outlined,
            'Professional Assessment',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText:
                  'Add your guidance assessment, professional observations, or closing notes...',
              hintStyle: const TextStyle(
                color: AppTheme.mediumGray,
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.lightGray),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.lightGray),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppTheme.skyBlue,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          const SizedBox(height: 32),
          _buildActionButtons(student),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.skyBlue, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.deepBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.mediumGray, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.deepBlue,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(ReportActivityLog log) {
    return Container(
      margin: const EdgeInsets.only(left: 8, bottom: 0),
      padding: const EdgeInsets.only(left: 24, bottom: 24),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppTheme.skyBlue, width: 2)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -33,
            top: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.skyBlue, width: 3),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    log.action.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppTheme.skyBlue,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy • HH:mm').format(log.timestamp),
                    style: const TextStyle(
                      color: AppTheme.mediumGray,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              if (log.note != null && log.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.lightGray.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    log.note!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.darkGray,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(UserModel? student) {
    final isCollege = student?.studentLevel == StudentLevel.college;

    if (isCollege) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _forwardToDean,
          icon: const Icon(Icons.forward_to_inbox_rounded),
          label: const Text('Forward to Dean for Final Decision'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.warningOrange,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _acceptReport,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: const BorderSide(color: AppTheme.successGreen),
              foregroundColor: AppTheme.successGreen,
            ),
            child: const Text(
              'Accept & Take Over',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton(
            onPressed: _confirmReport,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.skyBlue,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Confirm & Finalize Case',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.submitted:
      case ReportStatus.pending:
        return AppTheme.warningOrange;
      case ReportStatus.forwarded:
        return AppTheme.skyBlue;
      case ReportStatus.counselorConfirmed:
        return AppTheme.successGreen;
      case ReportStatus.counselorReviewed:
        return AppTheme.infoBlue;
      case ReportStatus.approvedByDean:
        return AppTheme.deepBlue;
      case ReportStatus.settled:
      case ReportStatus.completed:
        return AppTheme.mediumGray;
      default:
        return AppTheme.mediumGray;
    }
  }
}
