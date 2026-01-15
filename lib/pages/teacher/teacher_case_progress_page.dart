import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/report_model.dart';
import '../../models/report_activity_log_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';

class TeacherCaseProgressPage extends StatefulWidget {
  const TeacherCaseProgressPage({super.key});

  @override
  State<TeacherCaseProgressPage> createState() =>
      _TeacherCaseProgressPageState();
}

class _TeacherCaseProgressPageState extends State<TeacherCaseProgressPage> {
  final _supabase = SupabaseService();
  final _searchController = TextEditingController();
  final _commentController = TextEditingController();

  bool _isLoading = true;
  List<ReportModel> _reports = [];
  List<ReportModel> _filteredReports = [];
  ReportModel? _selectedReport;
  List<ReportActivityLog> _activityLogs = [];
  final Map<String, UserModel> _studentCache = {};
  final Map<String, UserModel> _usersCache = {};

  // Filters
  String? _selectedStatus;
  String? _selectedType;
  DateTimeRange? _dateRange;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
            _applyFilters();
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

  Future<void> _loadStudentInfo(String studentId) async {
    if (_studentCache.containsKey(studentId)) return;

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

  Future<void> _loadUsers() async {
    try {
      final users = await _supabase.getAllUsers();
      if (mounted) {
        setState(() {
          for (final user in users) {
            _usersCache[user.id] = user;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  String _getAssignedName(ReportModel report) {
    if (report.counselorId != null) {
      final counselor = _usersCache[report.counselorId];
      if (counselor != null) {
        return '${counselor.fullName} (Counselor)';
      }
      return 'Counselor';
    }

    if (report.teacherId != null) {
      final teacher = _usersCache[report.teacherId];
      if (teacher != null) {
        return '${teacher.fullName} (Teacher)';
      }
    }

    return 'Teacher';
  }

  void _applyFilters() {
    setState(() {
      _filteredReports =
          _reports.where((report) {
            // Status filter
            if (_selectedStatus != null) {
              if (_selectedStatus == 'pending' &&
                  report.status != ReportStatus.submitted) {
                return false;
              }
              if (_selectedStatus == 'in_review' &&
                  report.status != ReportStatus.teacherReviewed) {
                return false;
              }
              if (_selectedStatus == 'ongoing' &&
                  report.status != ReportStatus.forwarded &&
                  report.status != ReportStatus.counselorConfirmed) {
                return false;
              }
              if (_selectedStatus == 'settled' &&
                  report.status != ReportStatus.settled) {
                return false;
              }
            }

            // Type filter
            if (_selectedType != null && report.type != _selectedType) {
              return false;
            }

            // Date range filter
            if (_dateRange != null) {
              if (report.createdAt.isBefore(_dateRange!.start) ||
                  report.createdAt.isAfter(
                    _dateRange!.end.add(const Duration(days: 1)),
                  )) {
                return false;
              }
            }

            // Search query
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final studentName =
                  report.isAnonymous
                      ? 'anonymous'
                      : (report.studentId != null
                              ? _studentCache[report.studentId]?.fullName
                              : null) ??
                          '';
              final studentNameLower = studentName.toLowerCase();
              if (!report.title.toLowerCase().contains(query) &&
                  !report.type.toLowerCase().contains(query) &&
                  !studentNameLower.contains(query)) {
                return false;
              }
            }

            return true;
          }).toList();
    });
  }

  Color _getStatusColor(ReportStatus? status) {
    if (status == null) return AppTheme.mediumGray;
    switch (status) {
      case ReportStatus.submitted:
      case ReportStatus.pending:
        return AppTheme.mediumGray; // Pending - gray
      case ReportStatus.teacherReviewed:
        return AppTheme.infoBlue; // In Review - blue
      case ReportStatus.forwarded:
      case ReportStatus.counselorReviewed:
      case ReportStatus.counselorConfirmed:
        return AppTheme.warningOrange; // Ongoing - orange
      case ReportStatus.approvedByDean:
      case ReportStatus.counselingScheduled:
        return AppTheme.successGreen; // Confirmed by Counselor - green
      case ReportStatus.settled:
      case ReportStatus.completed:
        return AppTheme.successGreen; // Settled - green
    }
  }

  String _getStatusLabel(ReportStatus? status) {
    if (status == null) return 'Pending';
    switch (status) {
      case ReportStatus.submitted:
      case ReportStatus.pending:
        return 'Pending';
      case ReportStatus.teacherReviewed:
        return 'In Review';
      case ReportStatus.forwarded:
      case ReportStatus.counselorReviewed:
      case ReportStatus.counselorConfirmed:
        return 'Ongoing';
      case ReportStatus.approvedByDean:
        return 'Approved';
      case ReportStatus.counselingScheduled:
        return 'Scheduled';
      case ReportStatus.settled:
      case ReportStatus.completed:
        return 'Settled';
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

  Future<void> _showCaseDetails(ReportModel report) async {
    setState(() => _selectedReport = report);
    _commentController.clear();

    // Load student info if not cached (skip for anonymous reports)
    if (report.studentId != null) {
      await _loadStudentInfo(report.studentId!);
    }

    // Load activity logs
    try {
      final logs = await _supabase.getReportActivityLogs(report.id);
      if (mounted) {
        setState(() {
          _activityLogs = logs;
        });
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error loading activity logs: $e');
      }
    }

    if (!mounted) return;

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
                              'Case Details',
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

                        // Student Information
                        _buildInfoSection('Student Information', [
                          if (report.isAnonymous) ...[
                            _buildInfoRow('Name', 'Anonymous'),
                            if (report.trackingId != null)
                              _buildInfoRow('Tracking ID', report.trackingId!),
                          ] else ...[
                            _buildInfoRow(
                              'Name',
                              _studentCache[report.studentId]?.fullName ??
                                  'Loading...',
                            ),
                            _buildInfoRow(
                              'Email',
                              _studentCache[report.studentId]?.gmail ??
                                  'Loading...',
                            ),
                            if (_studentCache[report.studentId]?.course != null)
                              _buildInfoRow(
                                'Course',
                                _studentCache[report.studentId]!.course!,
                              ),
                            if (_studentCache[report.studentId]?.gradeLevel !=
                                null)
                              _buildInfoRow(
                                'Grade Level',
                                _studentCache[report.studentId]!.gradeLevel!,
                              ),
                          ],
                        ]),

                        const SizedBox(height: 24),

                        // Report Information
                        _buildInfoSection('Report Information', [
                          _buildInfoRow('Title', report.title),
                          _buildInfoRow('Type', report.type),
                          if (report.counselorId != null ||
                              report.teacherId != null)
                            _buildInfoRow(
                              'Assigned To',
                              _getAssignedName(report),
                            ),
                          _buildInfoRow(
                            'Status',
                            _getStatusLabel(report.status),
                          ),
                          _buildInfoRow(
                            'Submitted',
                            DateFormat(
                              'MMM dd, yyyy HH:mm',
                            ).format(report.createdAt),
                          ),
                          if (report.incidentDate != null)
                            _buildInfoRow(
                              'Incident Date',
                              DateFormat(
                                'MMM dd, yyyy HH:mm',
                              ).format(report.incidentDate!),
                            ),
                        ]),

                        const SizedBox(height: 24),

                        // Description
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            report.details,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),

                        // Attachment
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

                        // Timeline
                        const Text(
                          'Activity Timeline',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTimeline(),

                        const SizedBox(height: 24),

                        // Add Comment/Follow-up
                        const Text(
                          'Add Comment or Follow-up',
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
                            hintText: 'Enter your comment or follow-up note...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 4,
                        ),

                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    () => _updateStatus(
                                      ReportStatus.teacherReviewed,
                                    ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text('Mark as In Review'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    () => _updateStatus(ReportStatus.forwarded),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text('Forward to Counselor'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed:
                                    () => _updateStatus(ReportStatus.settled),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.successGreen,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text('Mark as Settled'),
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

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.deepBlue,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.lightGray,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
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

  Widget _buildTimeline() {
    if (_activityLogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.lightGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No activity logs available',
          style: TextStyle(color: AppTheme.mediumGray),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children:
            _activityLogs.asMap().entries.map((entry) {
              final index = entry.key;
              final log = entry.value;
              final isLast = index == _activityLogs.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppTheme.skyBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 60,
                          color: AppTheme.mediumGray.withValues(alpha: 0.3),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                log.action.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.deepBlue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat(
                                  'MMM dd, yyyy HH:mm',
                                ).format(log.timestamp),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGray,
                                ),
                              ),
                            ],
                          ),
                          if (log.note != null && log.note!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              log.note!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.darkGray,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }

  Future<void> _updateStatus(ReportStatus newStatus) async {
    if (_selectedReport == null) return;

    final note = _commentController.text.trim();
    String? selectedCounselorId;

    // Special handling for forwarding to counselor
    if (newStatus == ReportStatus.forwarded) {
      if (note.isEmpty) {
        ToastUtils.showWarning(
          context,
          'Please add a comment before forwarding',
        );
        return;
      }

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
                              _usersCache.values
                                  .where((u) => u.role == UserRole.counselor)
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text('${c.fullName} (Counselor)'),
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
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final teacherId = authProvider.currentUser?.id;

      if (teacherId != null) {
        await _supabase.updateReportStatus(
          reportId: _selectedReport!.id,
          status: newStatus,
          teacherId: teacherId,
          counselorId: selectedCounselorId,
          note: note.isNotEmpty ? note : null,
        );

        if (mounted) {
          final statusLabel = _getStatusLabel(newStatus);
          ToastUtils.showSuccess(context, 'Case marked as $statusLabel');
          Navigator.pop(context);
          _commentController.clear();
          _loadReports();
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Error updating case: $e');
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null && mounted) {
      setState(() {
        _dateRange = picked;
        _applyFilters();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return ResponsiveSidebar(
      currentRoute: currentRoute,
      child: Scaffold(
        body: Container(
          decoration: AppTheme.softBlueGradientDecoration,
          child: Column(
            children: [
              const ModernDashboardHeader(
                title: 'Monitor Case Progress',
                subtitle: 'Track status and updates of referred cases',
                icon: Icons.timeline_rounded,
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                          children: [
                            // Filters and Search
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
                              child: Column(
                                children: [
                                  // Search Bar
                                  TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText:
                                          'Search by student name, title, or type...',
                                      hintStyle: const TextStyle(
                                        color: AppTheme.mediumGray,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        color: AppTheme.skyBlue,
                                      ),
                                      filled: true,
                                      fillColor: AppTheme.lightGray.withValues(
                                        alpha: 0.3,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 16,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: AppTheme.skyBlue,
                                        ),
                                      ),
                                      suffixIcon:
                                          _searchQuery.isNotEmpty
                                              ? IconButton(
                                                icon: const Icon(
                                                  Icons.clear,
                                                  color: AppTheme.mediumGray,
                                                ),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  setState(() {
                                                    _searchQuery = '';
                                                    _applyFilters();
                                                  });
                                                },
                                              )
                                              : null,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                        _applyFilters();
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  // Filter Row
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    alignment: WrapAlignment.start,
                                    children: [
                                      // Status Filter
                                      SizedBox(
                                        width: isTablet ? 200 : double.infinity,
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _selectedStatus,
                                          decoration: InputDecoration(
                                            labelText: 'Status',
                                            labelStyle: const TextStyle(
                                              color: AppTheme.mediumGray,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: AppTheme.lightGray,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
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
                                              value: 'pending',
                                              child: Text('Pending'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'in_review',
                                              child: Text('In Review'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'ongoing',
                                              child: Text('Ongoing'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'settled',
                                              child: Text('Settled'),
                                            ),
                                          ],
                                          onChanged:
                                              (value) => setState(() {
                                                _selectedStatus = value;
                                                _applyFilters();
                                              }),
                                        ),
                                      ),
                                      // Type Filter
                                      SizedBox(
                                        width: isTablet ? 200 : double.infinity,
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _selectedType,
                                          decoration: InputDecoration(
                                            labelText: 'Report Type',
                                            labelStyle: const TextStyle(
                                              color: AppTheme.mediumGray,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: AppTheme.lightGray,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
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
                                          onChanged:
                                              (value) => setState(() {
                                                _selectedType = value;
                                                _applyFilters();
                                              }),
                                        ),
                                      ),
                                      // Date Range
                                      OutlinedButton.icon(
                                        onPressed: _selectDateRange,
                                        icon: const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 18,
                                        ),
                                        label: Text(
                                          _dateRange == null
                                              ? 'Date Range'
                                              : '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}',
                                          style: const TextStyle(
                                            color: AppTheme.deepBlue,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.deepBlue,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 18,
                                          ),
                                          side: BorderSide(
                                            color: AppTheme.lightGray,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Clear Filters
                                      if (_selectedStatus != null ||
                                          _selectedType != null ||
                                          _dateRange != null)
                                        TextButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _selectedStatus = null;
                                              _selectedType = null;
                                              _dateRange = null;
                                              _applyFilters();
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.refresh_rounded,
                                            size: 18,
                                            color: AppTheme.mediumBlue,
                                          ),
                                          label: const Text(
                                            'Reset',
                                            style: TextStyle(
                                              color: AppTheme.mediumBlue,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 18,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Reports List/Table
                            Expanded(
                              child:
                                  _isLoading
                                      ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                      : _filteredReports.isEmpty
                                      ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.assignment_outlined,
                                              size: 64,
                                              color: AppTheme.mediumGray
                                                  .withValues(alpha: 0.5),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'No cases found',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.mediumGray,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Try adjusting your filters',
                                              style: TextStyle(
                                                color: AppTheme.mediumGray,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      : Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                        ),
                                        child:
                                            isDesktop
                                                ? _buildDesktopTable()
                                                : isTablet
                                                ? _buildTabletCards()
                                                : _buildMobileCards(),
                                      ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.lightBlue.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 8,
                ),
                color: AppTheme.lightGray.withValues(alpha: 0.3),
                child: Row(
                  children: const [
                    Expanded(flex: 2, child: _TableHeader('Student Name')),
                    Expanded(flex: 2, child: _TableHeader('Report Type')),
                    Expanded(flex: 2, child: _TableHeader('Date Submitted')),
                    Expanded(flex: 2, child: _TableHeader('Status')),
                    Expanded(flex: 2, child: _TableHeader('Assigned To')),
                    Expanded(
                      flex: 1,
                      child: _TableHeader('Action', align: TextAlign.center),
                    ),
                  ],
                ),
              ),
              // Rows
              ..._filteredReports.asMap().entries.map((entry) {
                final index = entry.key;
                final report = entry.value;
                if (report.studentId != null) {
                  _loadStudentInfo(report.studentId!);
                }
                final student =
                    report.studentId != null
                        ? _studentCache[report.studentId]
                        : null;

                return Container(
                  decoration: BoxDecoration(
                    border:
                        index != _filteredReports.length - 1
                            ? Border(
                              bottom: BorderSide(
                                color: AppTheme.lightGray.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            )
                            : null,
                    color: Colors.white,
                  ),
                  child: InkWell(
                    onTap: () => _showCaseDetails(report),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    report.isAnonymous
                                        ? 'Anonymous'
                                        : (student?.fullName ?? 'Loading...'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.deepBlue,
                                    ),
                                  ),
                                  if (report.isAnonymous)
                                    const Text(
                                      'Hidden',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.mediumGray,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(flex: 2, child: _TableCell(report.type)),
                          Expanded(
                            flex: 2,
                            child: _TableCell(
                              DateFormat(
                                'MMM dd, yyyy',
                              ).format(report.createdAt),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _StatusCell(
                                _getStatusLabel(report.status),
                                _getStatusColor(report.status),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _TableCell(
                              _getAssignedName(report),
                              isSecondary: true,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: _ActionCell(
                                onTap: () => _showCaseDetails(report),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletCards() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemCount: _filteredReports.length,
      itemBuilder: (context, index) {
        final report = _filteredReports[index];
        if (report.studentId != null) {
          _loadStudentInfo(report.studentId!);
        }
        final student =
            report.studentId != null ? _studentCache[report.studentId] : null;

        return _buildCaseCard(report, student);
      },
    );
  }

  Widget _buildMobileCards() {
    return ListView.builder(
      itemCount: _filteredReports.length,
      itemBuilder: (context, index) {
        final report = _filteredReports[index];
        if (report.studentId != null) {
          _loadStudentInfo(report.studentId!);
        }
        final student =
            report.studentId != null ? _studentCache[report.studentId] : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildCaseCard(report, student),
        );
      },
    );
  }

  Widget _buildCaseCard(ReportModel report, UserModel? student) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.lightBlue.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showCaseDetails(report),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.deepBlue,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (report.isAnonymous)
                            Row(
                              children: const [
                                Icon(
                                  Icons.visibility_off,
                                  size: 12,
                                  color: AppTheme.warningOrange,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Anonymous',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.warningOrange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              student?.fullName ?? 'Loading...',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.mediumGray,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _StatusCell(
                      _getStatusLabel(report.status),
                      _getStatusColor(report.status),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.lightGray),
                const SizedBox(height: 12),
                _buildCardRow(Icons.category_rounded, 'Type', report.type),
                const SizedBox(height: 8),
                _buildCardRow(
                  Icons.calendar_today_rounded,
                  'Submitted',
                  DateFormat('MMM dd').format(report.createdAt),
                ),
                const SizedBox(height: 8),
                _buildCardRow(
                  Icons.person_pin_rounded,
                  'Assigned',
                  _getAssignedName(report),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showCaseDetails(report),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.mediumBlue),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, color: AppTheme.mediumGray),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.deepBlue,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  final TextAlign align;

  const _TableHeader(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppTheme.mediumGray,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool isSecondary;

  const _TableCell(this.text, {this.isSecondary = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: isSecondary ? AppTheme.mediumGray : AppTheme.darkGray,
          fontWeight: isSecondary ? FontWeight.normal : FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusCell(this.status, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  final VoidCallback onTap;

  const _ActionCell({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: AppTheme.mediumGray,
      ),
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.lightGray.withValues(alpha: 0.5),
        padding: const EdgeInsets.all(8),
      ),
    );
  }
}
