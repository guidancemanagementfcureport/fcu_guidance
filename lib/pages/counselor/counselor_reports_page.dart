import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/report_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';
import '../../utils/toast_utils.dart';
import 'package:go_router/go_router.dart';

class CounselorReportsPage extends StatefulWidget {
  const CounselorReportsPage({super.key});

  @override
  State<CounselorReportsPage> createState() => _CounselorReportsPageState();
}

class _CounselorReportsPageState extends State<CounselorReportsPage> {
  final _supabase = SupabaseService();
  bool _isLoading = true;
  List<ReportModel> _reports = [];
  List<ReportModel> _filteredReports = [];
  final TextEditingController _searchController = TextEditingController();
  Map<String, int> _referralStats = {};
  final Map<String, UserModel> _studentCache = {};
  final Map<String, UserModel> _teacherCache = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final counselorId = authProvider.currentUser?.id;

      if (counselorId != null) {
        final reports = await _supabase.getCounselorAllReports(counselorId);

        final stats = <String, int>{
          'Total Forwarded': reports.length,
          'Pending Review':
              reports.where((r) => r.status == ReportStatus.forwarded).length,
          'Forwarded to Dean':
              reports
                  .where((r) => r.status == ReportStatus.counselorReviewed)
                  .length,
          'Anonymous': reports.where((r) => r.isAnonymous).length,
        };

        if (mounted) {
          setState(() {
            _reports = reports;
            _filteredReports = reports;
            _referralStats = stats;
            _isLoading = false;
          });
          _filterReports(_searchController.text);

          for (final report in reports) {
            if (!report.isAnonymous && report.studentId != null) {
              _loadStudentInfo(report.studentId);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error loading reports: $e');
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

  void _filterReports(String query) {
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
            final details = report.details.toLowerCase();

            String studentName = '';
            if (!report.isAnonymous && report.studentId != null) {
              studentName =
                  _studentCache[report.studentId]?.fullName.toLowerCase() ?? '';
            }

            return title.contains(lowerQuery) ||
                type.contains(lowerQuery) ||
                details.contains(lowerQuery) ||
                studentName.contains(lowerQuery);
          }).toList();
    });
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
                title: 'Teacher Referrals',
                subtitle:
                    'Analyze and manage case reports referred by faculty members',
                icon: Icons.assignment_ind_rounded,
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                          onRefresh: _loadData,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStatsGrid(isDesktop),
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

  Widget _buildStatsGrid(bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Account for SingleChildScrollView padding: 24 on each side = 48px total
        final availableWidth = constraints.maxWidth - 48;
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
            _CounselorReportStatCard(
              label: 'Total Forwarded',
              value: _referralStats['Total Forwarded']?.toString() ?? '0',
              color: AppTheme.skyBlue,
              icon: Icons.assignment_ind_outlined,
              width: cardWidth,
            ),
            _CounselorReportStatCard(
              label: 'Pending Review',
              value: _referralStats['Pending Review']?.toString() ?? '0',
              color: AppTheme.warningOrange,
              icon: Icons.pending_actions_outlined,
              width: cardWidth,
            ),
            _CounselorReportStatCard(
              label: 'To Dean',
              value: _referralStats['Forwarded to Dean']?.toString() ?? '0',
              color: AppTheme.infoBlue,
              icon: Icons.send_outlined,
              width: cardWidth,
            ),
            _CounselorReportStatCard(
              label: 'Anonymous',
              value: _referralStats['Anonymous']?.toString() ?? '0',
              color: AppTheme.mediumBlue,
              icon: Icons.visibility_off_outlined,
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _filterReports,
              decoration: InputDecoration(
                hintText: 'Search by title, student name, or type...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppTheme.mediumGray,
                ),
                filled: true,
                fillColor: AppTheme.lightGray.withValues(alpha: 0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
          Container(
            padding: const EdgeInsets.all(12),
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
        ],
      ),
    );
  }

  Widget _buildReportsContent(bool isDesktop) {
    if (_filteredReports.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: AppTheme.lightGray),
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
              'Try adjusting your search or filters',
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
                const Text(
                  'Forwarded Reports',
                  style: TextStyle(
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
                    '${_filteredReports.length} Records',
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
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final report = _filteredReports[index];
              return _buildReportItem(report, isDesktop);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(ReportModel report, bool isDesktop) {
    return InkWell(
      onTap: () => _showReportDetails(context, report),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (report.isAnonymous
                        ? AppTheme.warningOrange
                        : AppTheme.skyBlue)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                report.isAnonymous
                    ? Icons.visibility_off_rounded
                    : Icons.person_rounded,
                color:
                    report.isAnonymous
                        ? AppTheme.warningOrange
                        : AppTheme.skyBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepBlue,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.isAnonymous
                        ? 'Anonymous'
                        : (_studentCache[report.studentId]?.fullName ??
                            'Loading...'),
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
                      'Type',
                      style: TextStyle(
                        color: AppTheme.mediumGray,
                        fontSize: 11,
                      ),
                    ),
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
                      'Submitted',
                      style: TextStyle(
                        color: AppTheme.mediumGray,
                        fontSize: 11,
                      ),
                    ),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(report.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
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

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.forwarded:
        return AppTheme.warningOrange;
      case ReportStatus.counselorReviewed:
        return AppTheme.infoBlue;
      case ReportStatus.approvedByDean:
        return AppTheme.deepBlue;
      case ReportStatus.settled:
        return AppTheme.successGreen;
      default:
        return AppTheme.mediumGray;
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

  void _showReportDetails(BuildContext context, ReportModel report) async {
    if (!report.isAnonymous && report.studentId != null) {
      await _loadStudentInfo(report.studentId);
    }

    if (report.teacherId != null &&
        !_teacherCache.containsKey(report.teacherId!)) {
      try {
        final teacher = await _supabase.getUserById(report.teacherId!);
        if (teacher != null && mounted) {
          setState(() {
            _teacherCache[report.teacherId!] = teacher;
          });
        }
      } catch (e) {
        debugPrint('Error loading teacher info: $e');
      }
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
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

                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                ),
                                child: Text(
                                  report.status.displayName.toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(report.status),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                'REF: ${report.id.substring(0, 8).toUpperCase()}',
                                style: const TextStyle(
                                  color: AppTheme.mediumGray,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          _buildDetailSection(
                            Icons.assignment_outlined,
                            'Case Information',
                            [
                              _DetailItem('Title', report.title),
                              _DetailItem('Category', report.type),
                              _DetailItem(
                                'Date Submitted',
                                DateFormat(
                                  'MMM dd, yyyy • HH:mm',
                                ).format(report.createdAt),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          if (!report.isAnonymous && report.studentId != null)
                            _buildDetailSection(
                              Icons.person_outline,
                              'Student Information',
                              [
                                _DetailItem(
                                  'Full Name',
                                  _studentCache[report.studentId]?.fullName ??
                                      'N/A',
                                ),
                                _DetailItem(
                                  'Student Level',
                                  _studentCache[report.studentId]
                                          ?.studentLevel
                                          ?.displayName ??
                                      'N/A',
                                ),
                              ],
                            )
                          else
                            _buildDetailSection(
                              Icons.visibility_off_outlined,
                              'Anonymous Report',
                              [_DetailItem('Identity', 'Hidden by student')],
                            ),

                          const SizedBox(height: 32),

                          if (report.teacherId != null)
                            _buildDetailSection(
                              Icons.school_outlined,
                              'Referring Teacher',
                              [
                                _DetailItem(
                                  'Full Name',
                                  _teacherCache[report.teacherId]?.fullName ??
                                      'Loading...',
                                ),
                                _DetailItem('Role', 'Teacher'),
                                _DetailItem(
                                  'Department',
                                  _teacherCache[report.teacherId]?.department ??
                                      'Faculty',
                                ),
                              ],
                            ),

                          if (report.teacherId != null)
                            _buildDetailSection(
                              Icons.rate_review_outlined,
                              'Teacher\'s Approval Notes',
                              [],
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppTheme.skyBlue.withValues(
                                    alpha: 0.05,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.skyBlue.withValues(
                                      alpha: 0.1,
                                    ),
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
                            ),

                          const SizedBox(height: 32),

                          _buildDetailSection(
                            Icons.text_snippet_outlined,
                            'Description',
                            [],
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.lightGray.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.lightGray.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
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
                          ),

                          if (report.attachmentUrl != null &&
                              report.attachmentUrl!.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildDetailSection(
                              Icons.attach_file_rounded,
                              'Attachments',
                              [],
                              child: Builder(
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
                                            onPressed:
                                                () => _viewAttachment(url),
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
                            ),
                          ],
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
                          child: const Text('Close'),
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

  Widget _buildDetailSection(
    IconData icon,
    String title,
    List<_DetailItem> items, {
    Widget? child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.skyBlue, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (child != null)
          child
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        color: AppTheme.mediumGray,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.value,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.deepBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailItem {
  final String label;
  final String value;
  _DetailItem(this.label, this.value);
}

class _CounselorReportStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final double width;

  const _CounselorReportStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
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
    );
  }
}
