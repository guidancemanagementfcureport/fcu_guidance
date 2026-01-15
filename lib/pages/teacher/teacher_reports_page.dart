import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/report_model.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';

class TeacherReportsPage extends StatefulWidget {
  const TeacherReportsPage({super.key});

  @override
  State<TeacherReportsPage> createState() => _TeacherReportsPageState();
}

class _TeacherReportsPageState extends State<TeacherReportsPage> {
  final _supabase = SupabaseService();
  bool _isLoading = true;
  List<ReportModel> _reports = [];
  List<ReportModel> _filteredReports = [];
  List<UserModel> _counselors = [];
  ReportModel? _selectedReport;
  String? _selectedStatus;
  String? _selectedType;
  final _commentController = TextEditingController();
  final Map<String, UserModel> _studentCache = {};

  @override
  void initState() {
    super.initState();
    _loadReports();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser != null) {
          final matchedLocation = GoRouterState.of(context).matchedLocation;
          context.read<NotificationProvider>().markNotificationsAsSeenForRoute(
            authProvider.currentUser!.id,
            matchedLocation,
          );
        }
      }
    });
    _loadCounselors();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final teacherId = authProvider.currentUser?.id;

      if (teacherId != null) {
        final reports = await _supabase.getTeacherReportsAndAnonymous(
          teacherId,
        );
        if (mounted) {
          setState(() {
            _reports = reports;
            _applyFilters(); // Apply initial filters
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

  Future<void> _loadCounselors() async {
    try {
      final users = await _supabase.getAllUsers();
      if (mounted) {
        setState(() {
          _counselors =
              users.where((u) => u.role == UserRole.counselor).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading counselors: $e');
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredReports =
          _reports.where((report) {
            final statusMatch =
                _selectedStatus == null ||
                (_selectedStatus == 'submitted' &&
                    (report.status == ReportStatus.submitted ||
                        report.status == ReportStatus.pending)) ||
                (report.status.toString() == _selectedStatus);

            final typeMatch =
                _selectedType == null || report.type == _selectedType;

            return statusMatch && typeMatch;
          }).toList();
    });
  }

  Future<void> _forwardToCounselor() async {
    if (_selectedReport == null) return;

    final note = _commentController.text.trim();
    if (note.isEmpty) {
      ToastUtils.showWarning(context, 'Please add a comment before forwarding');
      return;
    }

    String? selectedCounselorId;

    // Show dialog to select counselor
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Forward to Counselor'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select a counselor to forward this report to:',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCounselorId,
                        decoration: InputDecoration(
                          labelText: 'Select Counselor',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        items:
                            _counselors
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(
                                      '${c.fullName} (${c.department ?? "Guidance"})',
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (v) => setState(() => selectedCounselorId = v),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed:
                          selectedCounselorId != null
                              ? () => Navigator.pop(context, true)
                              : null,
                      child: const Text('Forward'),
                    ),
                  ],
                ),
          ),
    );

    if (confirmed != true || selectedCounselorId == null) return;
    if (!mounted) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final teacherId = authProvider.currentUser?.id;

      if (teacherId != null) {
        await _supabase.updateReportStatus(
          reportId: _selectedReport!.id,
          status: ReportStatus.forwarded,
          teacherId: teacherId,
          counselorId: selectedCounselorId,
          note: note,
        );

        if (mounted) {
          ToastUtils.showSuccess(context, 'Report forwarded to counselor');
          Navigator.pop(context);
          _commentController.clear();
          _loadReports();
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error forwarding report: $e');
      }
    }
  }

  Future<void> _loadStudentInfo(String? studentId) async {
    if (studentId == null || _studentCache.containsKey(studentId)) return;

    try {
      final student = await _supabase.getUserById(studentId);
      if (student != null && mounted) {
        setState(() {
          _studentCache[studentId] = student;
        });
      }
    } catch (e) {
      debugPrint('Error loading student info: $e');
    }
  }

  void _showReportDetails(ReportModel report) {
    setState(() => _selectedReport = report);
    _commentController.clear();

    // Load student info if not anonymous
    if (!report.isAnonymous && report.studentId != null) {
      _loadStudentInfo(report.studentId);
    }

    // Mark as read when opened
    context.read<NotificationProvider>().markReportAsSeen(report.id);

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
                              'Report Details',
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
                        const Text(
                          'Student Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (report.isAnonymous) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.warningOrange.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.warningOrange,
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.visibility_off,
                                  color: AppTheme.warningOrange,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'This is an Anonymous Report',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.warningOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (report.trackingId != null)
                            _buildDetailRow('Tracking ID', report.trackingId!),
                          _buildDetailRow('Name', 'Anonymous'),
                        ] else if (report.studentId != null)
                          Builder(
                            builder: (context) {
                              final student = _studentCache[report.studentId];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow(
                                    'Name',
                                    student?.fullName ?? 'Loading...',
                                  ),
                                  _buildDetailRow(
                                    'Email',
                                    student?.gmail ?? 'Loading...',
                                  ),
                                  // Student Level Badge
                                  if (student?.studentLevel != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _getStudentLevelColor(
                                          student?.studentLevel,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _getStudentLevelColor(
                                            student?.studentLevel,
                                          ).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.school_rounded,
                                            color: _getStudentLevelColor(
                                              student?.studentLevel,
                                            ),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Student Level: ',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: AppTheme.mediumGray,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            student!.studentLevel!.displayName,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _getStudentLevelColor(
                                                student.studentLevel,
                                              ),
                                              fontWeight: FontWeight.w600,
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
                                      _buildDetailRow(
                                        'Grade Level',
                                        student!.gradeLevel!,
                                      ),
                                    if (student?.section != null)
                                      _buildDetailRow(
                                        'Section',
                                        student!.section!,
                                      ),
                                  ] else if (student?.studentLevel ==
                                      StudentLevel.seniorHigh) ...[
                                    if (student?.gradeLevel != null)
                                      _buildDetailRow(
                                        'Grade Level',
                                        student!.gradeLevel!,
                                      ),
                                    if (student?.strand != null)
                                      _buildDetailRow(
                                        'Strand',
                                        student!.strand!,
                                      ),
                                  ] else if (student?.studentLevel ==
                                      StudentLevel.college) ...[
                                    if (student?.course != null)
                                      _buildDetailRow(
                                        'Course',
                                        student!.course!,
                                      ),
                                    if (student?.yearLevel != null)
                                      _buildDetailRow(
                                        'Year Level',
                                        student!.yearLevel!,
                                      ),
                                  ] else ...[
                                    // Fallback for old data
                                    if (student?.course != null)
                                      _buildDetailRow(
                                        'Course',
                                        student!.course!,
                                      ),
                                    if (student?.gradeLevel != null)
                                      _buildDetailRow(
                                        'Grade Level',
                                        student!.gradeLevel!,
                                      ),
                                  ],
                                ],
                              );
                            },
                          ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Report Information Section
                        const Text(
                          'Report Information',
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
                        _buildDetailRow(
                          'Submitted',
                          DateFormat(
                            'MMM dd, yyyy HH:mm',
                          ).format(report.createdAt),
                        ),
                        if (report.incidentDate != null)
                          _buildDetailRow(
                            'Incident Date',
                            DateFormat(
                              'MMM dd, yyyy HH:mm',
                            ).format(report.incidentDate!),
                          ),
                        const SizedBox(height: 16),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
                            report.details,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        if (report.attachmentUrl != null &&
                            report.attachmentUrl!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Attachments',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.deepBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final urls = report.attachmentUrl!.split(',');
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:
                                    urls.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final url = entry.value.trim();
                                      if (url.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8.0,
                                        ),
                                        child: OutlinedButton.icon(
                                          onPressed: () => _viewAttachment(url),
                                          icon: const Icon(Icons.attach_file),
                                          label: Text(
                                            'View Attachment ${urls.length > 1 ? index + 1 : ''}',
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 24),
                        const Text(
                          'Approval Notes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText:
                                'Provide notes confirming your approval...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 4,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _forwardToCounselor,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.skyBlue,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text('Forward to Counselor'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.mediumGray,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.darkGray),
            ),
          ),
        ],
      ),
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

  IconData _getReportIcon(String type) {
    switch (type) {
      case 'Bullying':
        return Icons.gavel_rounded;
      case 'Academic Concern':
        return Icons.menu_book_rounded;
      case 'Personal Issue':
        return Icons.psychology_rounded;
      case 'Behavioral Issue':
        return Icons.warning_amber_rounded;
      case 'Safety Concern':
        return Icons.security_rounded;
      default:
        return Icons.assignment_rounded;
    }
  }

  Widget _buildStatusBadge(ReportStatus status) {
    final color = _getStatusColor(status);
    final label =
        status == ReportStatus.submitted
            ? 'PENDING'
            : status == ReportStatus.forwarded
            ? 'MARK AS REVIEWED'
            : status.displayName.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.submitted:
      case ReportStatus.pending:
        return AppTheme.errorRed;
      case ReportStatus.teacherReviewed:
        return AppTheme.infoBlue;
      case ReportStatus.forwarded:
        return AppTheme.skyBlue;
      case ReportStatus.counselorReviewed:
        return AppTheme.warningOrange;
      case ReportStatus.counselorConfirmed:
        return AppTheme.successGreen;
      case ReportStatus.approvedByDean:
        return AppTheme.successGreen;
      case ReportStatus.counselingScheduled:
        return AppTheme.successGreen;
      case ReportStatus.settled:
      case ReportStatus.completed:
        return AppTheme.mediumGray;
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
                title: 'Student Reports & Incidents',
                subtitle: 'Manage and review student incident reports',
                icon: Icons.assignment_rounded,
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                          children: [
                            // Filters
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.lightBlue.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    offset: const Offset(0, 4),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width > 900
                                            ? 250
                                            : double.infinity,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _selectedStatus,
                                      decoration: InputDecoration(
                                        labelText: 'Filter by Status',
                                        labelStyle: const TextStyle(
                                          color: AppTheme.mediumGray,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.lightGray,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.lightGray,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: null,
                                          child: Text('All Statuses'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'submitted',
                                          child: Text('Submitted'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'teacher_reviewed',
                                          child: Text('Reviewed'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'forwarded',
                                          child: Text('Forwarded'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedStatus = value;
                                          _applyFilters();
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width > 900
                                            ? 250
                                            : double.infinity,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _selectedType,
                                      decoration: InputDecoration(
                                        labelText: 'Filter by Type',
                                        labelStyle: const TextStyle(
                                          color: AppTheme.mediumGray,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.lightGray,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.lightGray,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: null,
                                          child: Text('All Types'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Bullying',
                                          child: Text('Bullying'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Academic Concern',
                                          child: Text('Academic Concern'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Personal Issue',
                                          child: Text('Personal Issue'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Behavioral Issue',
                                          child: Text('Behavioral Issue'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Safety Concern',
                                          child: Text('Safety Concern'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Other',
                                          child: Text('Other'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedType = value;
                                          _applyFilters();
                                        });
                                      },
                                    ),
                                  ),
                                  if (_selectedStatus != null ||
                                      _selectedType != null)
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _selectedStatus = null;
                                          _selectedType = null;
                                          _applyFilters();
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 20,
                                        color: AppTheme.skyBlue,
                                      ),
                                      label: const Text(
                                        'Reset Filters',
                                        style: TextStyle(
                                          color: AppTheme.skyBlue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else
                                    IconButton(
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        color: AppTheme.mediumGray,
                                      ),
                                      onPressed: _loadReports,
                                      tooltip: 'Refresh List',
                                    ),
                                ],
                              ),
                            ),

                            // Reports List
                            Expanded(
                              child:
                                  _filteredReports.isEmpty
                                      ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.inbox_outlined,
                                              size: 64,
                                              color: AppTheme.mediumGray,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No reports found',
                                              style: TextStyle(
                                                color: AppTheme.mediumGray,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      : ListView.builder(
                                        padding: const EdgeInsets.all(16),
                                        itemCount: _filteredReports.length,
                                        itemBuilder: (context, index) {
                                          final report =
                                              _filteredReports[index];
                                          return Consumer<NotificationProvider>(
                                            builder: (
                                              context,
                                              notificationProvider,
                                              child,
                                            ) {
                                              final isNew = notificationProvider
                                                  .notifications
                                                  .any(
                                                    (n) =>
                                                        !n.isRead &&
                                                        n.type ==
                                                            NotificationType
                                                                .newReport &&
                                                        n.data['report_id'] ==
                                                            report.id,
                                                  );

                                              return Card(
                                                margin: const EdgeInsets.only(
                                                  bottom: 16,
                                                ),
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  side: BorderSide(
                                                    color:
                                                        isNew
                                                            ? AppTheme.skyBlue
                                                            : AppTheme.lightBlue
                                                                .withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                    width: isNew ? 2 : 1,
                                                  ),
                                                ),
                                                clipBehavior: Clip.antiAlias,
                                                child: InkWell(
                                                  onTap: () {
                                                    // Mark the corresponding notification as read when the report is opened
                                                    final notification =
                                                        notificationProvider
                                                            .notifications
                                                            .firstWhereOrNull(
                                                              (n) =>
                                                                  !n.isRead &&
                                                                  n.type ==
                                                                      NotificationType
                                                                          .newReport &&
                                                                  n.data['report_id'] ==
                                                                      report.id,
                                                            );
                                                    if (notification != null) {
                                                      notificationProvider
                                                          .markAsRead(
                                                            notification.id,
                                                          );
                                                    }
                                                    _showReportDetails(report);
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          20,
                                                        ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    12,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: _getStatusColor(
                                                                  report.status,
                                                                ).withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                              child: Icon(
                                                                _getReportIcon(
                                                                  report.type,
                                                                ),
                                                                color:
                                                                    _getStatusColor(
                                                                      report
                                                                          .status,
                                                                    ),
                                                                size: 24,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 16,
                                                            ),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Row(
                                                                    children: [
                                                                      if (isNew)
                                                                        Container(
                                                                          margin: const EdgeInsets.only(
                                                                            right:
                                                                                8,
                                                                          ),
                                                                          padding: const EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                8,
                                                                            vertical:
                                                                                2,
                                                                          ),
                                                                          decoration: BoxDecoration(
                                                                            color:
                                                                                AppTheme.skyBlue,
                                                                            borderRadius: BorderRadius.circular(
                                                                              6,
                                                                            ),
                                                                          ),
                                                                          child: const Text(
                                                                            'NEW',
                                                                            style: TextStyle(
                                                                              color:
                                                                                  Colors.white,
                                                                              fontSize:
                                                                                  10,
                                                                              fontWeight:
                                                                                  FontWeight.bold,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      Expanded(
                                                                        child: Text(
                                                                          report
                                                                              .title,
                                                                          style: const TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontSize:
                                                                                17,
                                                                            color:
                                                                                AppTheme.deepBlue,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 4,
                                                                  ),
                                                                  Text(
                                                                    report.type,
                                                                    style: const TextStyle(
                                                                      color:
                                                                          AppTheme
                                                                              .mediumGray,
                                                                      fontSize:
                                                                          14,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            _buildStatusBadge(
                                                              report.status,
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 20,
                                                        ),
                                                        const Divider(
                                                          height: 1,
                                                        ),
                                                        const SizedBox(
                                                          height: 16,
                                                        ),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                const Icon(
                                                                  Icons
                                                                      .calendar_today_outlined,
                                                                  size: 14,
                                                                  color:
                                                                      AppTheme
                                                                          .mediumGray,
                                                                ),
                                                                const SizedBox(
                                                                  width: 6,
                                                                ),
                                                                Text(
                                                                  DateFormat(
                                                                    'MMM dd, yyyy',
                                                                  ).format(
                                                                    report
                                                                        .createdAt,
                                                                  ),
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color:
                                                                        AppTheme
                                                                            .mediumGray,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            if (report
                                                                .isAnonymous)
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          4,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: AppTheme
                                                                      .warningOrange
                                                                      .withValues(
                                                                        alpha:
                                                                            0.1,
                                                                      ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        8,
                                                                      ),
                                                                ),
                                                                child: Row(
                                                                  children: const [
                                                                    Icon(
                                                                      Icons
                                                                          .visibility_off_rounded,
                                                                      size: 14,
                                                                      color:
                                                                          AppTheme
                                                                              .warningOrange,
                                                                    ),
                                                                    SizedBox(
                                                                      width: 6,
                                                                    ),
                                                                    Text(
                                                                      'Anonymous',
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color:
                                                                            AppTheme.warningOrange,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              )
                                                            else
                                                              Text(
                                                                report.id
                                                                    .substring(
                                                                      0,
                                                                      8,
                                                                    )
                                                                    .toUpperCase(),
                                                                style: const TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color:
                                                                      AppTheme
                                                                          .mediumGray,
                                                                  letterSpacing:
                                                                      1,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
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
