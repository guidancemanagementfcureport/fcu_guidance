import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import '../../services/supabase_service.dart';
import '../../services/pdf_export_service.dart';
import '../../models/report_model.dart';
import '../../models/user_model.dart';
import '../../models/case_message_model.dart';
import '../../models/report_activity_log_model.dart';
import '../../models/case_record_detail_model.dart';
import '../../models/counseling_request_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/modern_dashboard_header.dart';
import '../../widgets/responsive_sidebar.dart';

class AdminReportAnalyticsPage extends StatefulWidget {
  const AdminReportAnalyticsPage({super.key});

  @override
  State<AdminReportAnalyticsPage> createState() =>
      _AdminReportAnalyticsPageState();
}

class _AdminReportAnalyticsPageState extends State<AdminReportAnalyticsPage> {
  final SupabaseService _supabase = SupabaseService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _allReports = [];
  List<Map<String, dynamic>> _filteredReports = [];

  // Analytics data
  int _totalReports = 0;
  int _activeReports = 0;
  int _resolvedReports = 0;

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedStatus;
  String? _selectedRole;
  bool? _isAnonymousFilter;
  String _searchQuery = '';

  // Pagination
  int _currentPage = 0;
  final int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load all reports
      _allReports = await _supabase.getAllReportsForAdmin();

      // Load global analytics
      final analytics = await _supabase.getReportAnalytics();
      _totalReports = analytics['totalReports'] as int;
      _activeReports = analytics['activeReports'] as int;
      _resolvedReports = analytics['resolvedReports'] as int;

      _filteredReports = List.from(_allReports);

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _applyFilters() async {
    setState(() => _isLoading = true);

    try {
      if (_searchQuery.isNotEmpty) {
        // Perform local search on _allReports
        final searchLower = _searchQuery.toLowerCase();
        _filteredReports =
            _allReports.where((report) {
              // 1. Search in tracking_id
              final trackingId = report['tracking_id'] as String?;
              if (trackingId != null &&
                  trackingId.toLowerCase().contains(searchLower)) {
                return true;
              }

              // 2. Search in title and type
              final title = report['title'] as String?;
              final type = report['type'] as String?;
              if (title != null && title.toLowerCase().contains(searchLower)) {
                return true;
              }
              if (type != null && type.toLowerCase().contains(searchLower)) {
                return true;
              }

              // 3. Search in details (standard) or description (anonymous)
              final details = report['details'] as String?;
              final description = report['description'] as String?;
              if (details != null &&
                  details.toLowerCase().contains(searchLower)) {
                return true;
              }
              if (description != null &&
                  description.toLowerCase().contains(searchLower)) {
                return true;
              }

              // 4. Search in participant names
              final student = report['student'] as Map<String, dynamic>?;
              if (student?['full_name']?.toString().toLowerCase().contains(
                    searchLower,
                  ) ==
                  true) {
                return true;
              }

              final teacher = report['teacher'] as Map<String, dynamic>?;
              if (teacher?['full_name']?.toString().toLowerCase().contains(
                    searchLower,
                  ) ==
                  true) {
                return true;
              }

              final counselor = report['counselor'] as Map<String, dynamic>?;
              if (counselor?['full_name']?.toString().toLowerCase().contains(
                    searchLower,
                  ) ==
                  true) {
                return true;
              }

              return false;
            }).toList();
      } else {
        _filteredReports = await _supabase.getReportsWithAdvancedFilters(
          startDate: _startDate,
          endDate: _endDate,
          status: _selectedStatus,
          roleFilter: _selectedRole,
          isAnonymous: _isAnonymousFilter,
        );
      }

      setState(() {
        _currentPage = 0;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error applying filters: $e');
      setState(() => _isLoading = false);
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedStatus = null;
      _selectedRole = null;
      _isAnonymousFilter = null;
      _searchQuery = '';
      _filteredReports = List.from(_allReports);
      _currentPage = 0;
    });
  }

  Future<void> _exportSingleCase(String reportId) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get case details
      final caseData = await _supabase.getCaseRecordDetail(reportId);
      if (caseData == null) {
        if (mounted) Navigator.pop(context);
        _showError('Failed to load case details');
        return;
      }

      // Parse case data
      final report = ReportModel.fromJson(
        caseData['report'] as Map<String, dynamic>,
      );
      final messages =
          (caseData['messages'] as List)
              .map((m) => CaseMessageModel.fromJson(m as Map<String, dynamic>))
              .toList();
      final logs =
          (caseData['activityLogs'] as List)
              .map((l) => ReportActivityLog.fromJson(l as Map<String, dynamic>))
              .toList();

      UserModel? student, teacher, counselor, dean;
      final reportData = caseData['report'] as Map<String, dynamic>;

      if (!report.isAnonymous && reportData['student'] != null) {
        student = UserModel.fromJson(
          reportData['student'] as Map<String, dynamic>,
        );
      }
      if (reportData['teacher'] != null) {
        teacher = UserModel.fromJson(
          reportData['teacher'] as Map<String, dynamic>,
        );
      }
      if (reportData['counselor'] != null) {
        counselor = UserModel.fromJson(
          reportData['counselor'] as Map<String, dynamic>,
        );
      }
      if (reportData['dean'] != null) {
        dean = UserModel.fromJson(reportData['dean'] as Map<String, dynamic>);
      }

      final caseDetail = CaseRecordDetailModel(
        report: report,
        student: student,
        teacher: teacher,
        counselor: counselor,
        dean: dean,
        messages: messages,
        activityLogs: logs,
      );

      // Generate PDF
      final pdfBytes = await PdfExportService.exportSingleCase(caseDetail);

      // Download
      final blob = html.Blob([pdfBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute(
          'download',
          'case_${report.trackingId ?? reportId.substring(0, 8)}.pdf',
        )
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError('Failed to export PDF: $e');
    }
  }

  Future<void> _exportFilteredReports() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final pdfBytes = await PdfExportService.exportFilteredReports(
        _filteredReports,
      );

      final blob = html.Blob([pdfBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute(
          'download',
          'report_analytics_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
        )
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report list exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError('Failed to export PDF: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return ResponsiveSidebar(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: Colors.transparent, // Or AppTheme color
        body: Container(
          decoration:
              AppTheme.softBlueGradientDecoration, // Consistent background
          child: Column(
            children: [
              const ModernDashboardHeader(
                title: 'Report Analytics & Records',
                subtitle:
                    'Monitor system-wide analytics and manage all data records',
                icon: Icons.analytics_rounded,
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Analytics Cards
                              _buildAnalyticsCards(),
                              const SizedBox(height: 24),
                              // Filters
                              _buildFiltersSection(),
                              const SizedBox(height: 24),
                              // Reports Table
                              _buildReportsTable(),
                            ],
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 768) {
          return Column(
            children: [
              _buildAnalyticsCard(
                'Total Reports',
                _totalReports.toString(),
                Icons.description,
                Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildAnalyticsCard(
                'Active Cases',
                _activeReports.toString(),
                Icons.pending_actions,
                Colors.orange,
              ),
              const SizedBox(height: 16),
              _buildAnalyticsCard(
                'Resolved Cases',
                _resolvedReports.toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ],
          );
        } else {
          return Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  'Total Reports',
                  _totalReports.toString(),
                  Icons.description,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard(
                  'Active Cases',
                  _activeReports.toString(),
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard(
                  'Resolved Cases',
                  _resolvedReports.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildAnalyticsCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepBlue,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            offset: const Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.deepBlue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.filter_list_rounded,
                      color: AppTheme.deepBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Filter Records',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasActiveFilters())
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reset'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.mediumGray,
                      ),
                    ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _exportFilteredReports,
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('Export PDF Report'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  // Search
                  SizedBox(
                    width: isMobile ? double.infinity : 320,
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Search Reports',
                        hintText: 'e.g. Case ID, Student Name...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppTheme.mediumGray,
                        ),
                        filled: true,
                        fillColor: AppTheme.lightGray.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        _searchQuery = value;
                        _applyFilters();
                      },
                    ),
                  ),

                  // Date Range Picker
                  SizedBox(
                    width: isMobile ? double.infinity : 240,
                    child: InkWell(
                      onTap: _selectDateRange,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date Range',
                          filled: true,
                          fillColor: AppTheme.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.lightGray),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.lightGray),
                          ),
                          prefixIcon: const Icon(
                            Icons.date_range_rounded,
                            color: AppTheme.mediumGray,
                            size: 20,
                          ),
                        ),
                        child: Text(
                          _startDate == null || _endDate == null
                              ? 'Select Date Range'
                              : '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                _startDate == null
                                    ? AppTheme.mediumGray
                                    : AppTheme.deepBlue,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Quick Month Filter
                  SizedBox(
                    width: isMobile ? double.infinity : 180,
                    child: DropdownButtonFormField<int?>(
                      decoration: InputDecoration(
                        labelText: 'Filter by Month',
                        filled: true,
                        fillColor: AppTheme.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                        prefixIcon: const Icon(
                          Icons.calendar_month_rounded,
                          color: AppTheme.mediumGray,
                          size: 20,
                        ),
                      ),
                      initialValue: null, // Always show "Select Month"
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Months'),
                        ),
                        ...List.generate(12, (index) {
                          final month = DateTime(2024, index + 1);
                          return DropdownMenuItem(
                            value: index + 1,
                            child: Text(DateFormat('MMMM').format(month)),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          final now = DateTime.now();
                          final start = DateTime(now.year, value, 1);
                          final end = DateTime(now.year, value + 1, 0);
                          setState(() {
                            _startDate = start;
                            _endDate = end;
                          });
                          _applyFilters();
                        }
                      },
                    ),
                  ),

                  // Status filter
                  SizedBox(
                    width: isMobile ? double.infinity : 200,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        filled: true,
                        fillColor: AppTheme.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                      ),
                      initialValue: _selectedStatus,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Statuses'),
                        ),
                        ...ReportStatus.values.map((status) {
                          return DropdownMenuItem(
                            value: status.toString(),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    status.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedStatus = value);
                        _applyFilters();
                      },
                    ),
                  ),

                  // Role filter
                  SizedBox(
                    width: isMobile ? double.infinity : 180,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Role Involved',
                        filled: true,
                        fillColor: AppTheme.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                      ),
                      initialValue: _selectedRole,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Roles')),
                        DropdownMenuItem(
                          value: 'teacher',
                          child: Text('Teacher'),
                        ),
                        DropdownMenuItem(
                          value: 'counselor',
                          child: Text('Counselor'),
                        ),
                        DropdownMenuItem(value: 'dean', child: Text('Dean')),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedRole = value);
                        _applyFilters();
                      },
                    ),
                  ),

                  // Anonymous filter
                  SizedBox(
                    width: isMobile ? double.infinity : 160,
                    child: DropdownButtonFormField<bool?>(
                      decoration: InputDecoration(
                        labelText: 'Case Type',
                        filled: true,
                        fillColor: AppTheme.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                      ),
                      initialValue: _isAnonymousFilter,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Types')),
                        DropdownMenuItem(value: true, child: Text('Anonymous')),
                        DropdownMenuItem(
                          value: false,
                          child: Text('Identified'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _isAnonymousFilter = value);
                        _applyFilters();
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
        _selectedStatus != null ||
        _selectedRole != null ||
        _isAnonymousFilter != null ||
        _startDate != null ||
        _endDate != null;
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.submitted:
      case ReportStatus.pending:
        return AppTheme.mediumGray;
      case ReportStatus.teacherReviewed:
      case ReportStatus.forwarded:
      case ReportStatus.counselorReviewed:
      case ReportStatus.counselorConfirmed:
        return AppTheme.warningOrange;
      case ReportStatus.approvedByDean:
      case ReportStatus.counselingScheduled:
        return AppTheme.infoBlue;
      case ReportStatus.settled:
      case ReportStatus.completed:
        return AppTheme.successGreen;
    }
  }

  Widget _buildReportsTable() {
    if (_filteredReports.isEmpty) {
      return Card(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(48),
          child: Column(
            children: const [
              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No reports found',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(
      0,
      _filteredReports.length,
    );
    final pageReports = _filteredReports.sublist(startIndex, endIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        return Column(
          children: [
            if (isWide)
              _buildWideTable(pageReports)
            else
              _buildResponsiveList(pageReports),

            // Pagination
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${startIndex + 1}-$endIndex of ${_filteredReports.length}',
                    style: TextStyle(color: AppTheme.darkGray),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed:
                        _currentPage > 0
                            ? () => setState(() => _currentPage--)
                            : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed:
                        endIndex < _filteredReports.length
                            ? () => setState(() => _currentPage++)
                            : null,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWideTable(List<Map<String, dynamic>> reports) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: AppTheme.lightGray.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: AppTheme.lightGray)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'CASE INFO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mediumGray,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'TITLE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mediumGray,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'STATUS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mediumGray,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'STUDENT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mediumGray,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ASSIGNED TO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mediumGray,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'ACTION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mediumGray,
                      letterSpacing: 1.0,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          // List Items
          Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: reports.length,
              separatorBuilder:
                  (_, _) => Divider(
                    height: 1,
                    color: AppTheme.lightGray.withValues(alpha: 0.3),
                  ),
              itemBuilder: (context, index) {
                final report = reports[index];
                return _buildReportRow(report);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(Map<String, dynamic> report) {
    final reportId = report['id'] as String;
    final status = ReportStatus.fromString(report['status'] as String);
    final createdAt = DateTime.parse(report['created_at'] as String);
    final isAnonymous = report['is_anonymous'] as bool? ?? false;
    final student = report['student'] as Map<String, dynamic>?;
    final counselor = report['counselor'] as Map<String, dynamic>?;

    // final currentUser = context.read<AuthProvider>().currentUser; // Unused

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _viewCaseDetail(reportId),
        hoverColor: AppTheme.skyBlue.withValues(alpha: 0.02),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              // Case Info
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.skyBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: AppTheme.skyBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report['tracking_id'] as String? ??
                                reportId.substring(0, 8).toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.deepBlue,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM dd, yyyy').format(createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.mediumGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Title
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    report['title']?.toString() ?? 'No Title',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepBlue,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Status
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildStatusChip(status),
                ),
              ),
              // Student
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor:
                          isAnonymous
                              ? Colors.grey.withValues(alpha: 0.2)
                              : AppTheme.mediumBlue,
                      child: Icon(
                        isAnonymous ? Icons.person_off : Icons.person,
                        size: 14,
                        color: isAnonymous ? Colors.grey : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAnonymous
                            ? 'Anonymous'
                            : (student?['full_name'] as String? ?? 'N/A'),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.darkGray,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Assigned To (Counselor usually)
              Expanded(
                flex: 2,
                child: Text(
                  counselor?['full_name'] as String? ?? 'Not Assigned',
                  style: TextStyle(color: AppTheme.mediumGray, fontSize: 13),
                ),
              ),
              // Actions
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: AppTheme.mediumBlue,
                      ),
                      onPressed: () => _viewCaseDetail(reportId),
                      tooltip: 'View Details',
                      splashRadius: 20,
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        size: 18,
                        color: AppTheme.mediumGray,
                      ),
                      splashRadius: 20,
                      onSelected: (value) {
                        if (value == 'print') {
                          _printDeanReport(report);
                        } else if (value == 'export') {
                          _exportSingleCase(reportId);
                        }
                      },
                      itemBuilder: (context) {
                        return [
                          const PopupMenuItem(
                            value: 'print',
                            child: Row(
                              children: [
                                Icon(Icons.print, size: 16),
                                SizedBox(width: 8),
                                Text('Print Report'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'export',
                            child: Row(
                              children: [
                                Icon(Icons.picture_as_pdf, size: 16),
                                SizedBox(width: 8),
                                Text('Export PDF'),
                              ],
                            ),
                          ),
                        ];
                      },
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
        counselingRequest = await _supabase.getCounselingRequestByReportId(
          reportData['id'],
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

      final reportStatus = reportData['status'].toString();
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
                    reportData['description'] ??
                        reportData['details'] ??
                        'No description provided.',
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
                    fontSize: 14,
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
      _showError('Failed to generate PDF: $e');
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

  Widget _buildResponsiveList(List<Map<String, dynamic>> reports) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final report = reports[index];
        final reportId = report['id'] as String;
        final status = ReportStatus.fromString(report['status'] as String);
        final createdAt = DateTime.parse(report['created_at'] as String);
        final isAnonymous = report['is_anonymous'] as bool? ?? false;
        final student = report['student'] as Map<String, dynamic>?;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                offset: const Offset(0, 4),
                blurRadius: 16,
              ),
            ],
            border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.skyBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            color: AppTheme.skyBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          report['tracking_id'] as String? ??
                              reportId.substring(0, 8).toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepBlue,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: AppTheme.mediumGray,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM dd, yyyy').format(createdAt),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isAnonymous
                          ? Icons.person_off_rounded
                          : Icons.person_rounded,
                      size: 16,
                      color: AppTheme.mediumGray,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isAnonymous
                          ? 'Anonymous'
                          : (student?['full_name'] as String? ?? 'N/A'),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.darkGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _exportSingleCase(reportId),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Export'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.mediumGray,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _viewCaseDetail(reportId),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('View Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.skyBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(ReportStatus status) {
    Color color;
    Color bgColor;

    switch (status) {
      case ReportStatus.submitted:
      case ReportStatus.pending:
        color = AppTheme.mediumGray;
        bgColor = AppTheme.lightGray;
        break;
      case ReportStatus.teacherReviewed:
      case ReportStatus.forwarded:
      case ReportStatus.counselorReviewed:
      case ReportStatus.counselorConfirmed:
        color = AppTheme.warningOrange;
        bgColor = AppTheme.warningOrange.withValues(alpha: 0.1);
        break;
      case ReportStatus.approvedByDean:
      case ReportStatus.counselingScheduled:
        color = AppTheme.infoBlue;
        bgColor = AppTheme.infoBlue.withValues(alpha: 0.1);
        break;
      case ReportStatus.settled:
      case ReportStatus.completed:
        color = AppTheme.successGreen;
        bgColor = AppTheme.successGreen.withValues(alpha: 0.1);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            status.displayName,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewCaseDetail(String reportId) async {
    final report = _filteredReports.firstWhere(
      (r) => r['id'] == reportId,
      orElse: () => {},
    );

    if (report.isEmpty) return;

    // Show loading while fetching details
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    CounselingRequestModel? counselingRequest;
    Map<String, String> participantNames = {};

    try {
      counselingRequest = await _supabase.getCounselingRequestByReportId(
        reportId,
      );
      if (counselingRequest?.participants != null) {
        for (final p in counselingRequest!.participants!) {
          if (p['userId'] != null) {
            final u = await _supabase.getUserById(p['userId']);
            if (u != null) {
              participantNames[p['userId']] = u.fullName;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading counseling request: $e');
    }

    if (mounted) Navigator.pop(context); // Close loading

    final createdAt = DateTime.parse(report['created_at'] as String);
    final status = ReportStatus.fromString(report['status'] as String);
    final isAnonymous = report['is_anonymous'] as bool? ?? false;

    if (!mounted) return;

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
                        report['description'] ??
                            report['details'] ??
                            'No description provided.',
                      ),
                    ),

                    if (report['teacher_note'] != null &&
                        report['teacher_note'].toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        "Teacher's Note",
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
                        child: Text(report['teacher_note']),
                      ),
                    ],

                    if (report['counselor_note'] != null &&
                        report['counselor_note'].toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        "Counselor's Note",
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
                        child: Text(report['counselor_note']),
                      ),
                    ],

                    if (report['dean_note'] != null &&
                        report['dean_note'].toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        "Dean's Note",
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
                        child: Text(report['dean_note']),
                      ),
                    ],

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

                    // Extra participants
                    if (counselingRequest?.participants != null &&
                        counselingRequest!.participants!.isNotEmpty)
                      ...counselingRequest.participants!.map((p) {
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

                        // Capitalize label
                        if (label != 'Parent/Guardian') {
                          label = label[0].toUpperCase() + label.substring(1);
                        }

                        return _buildDetailRow(label, value);
                      }),
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

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange:
          _startDate != null && _endDate != null
              ? DateTimeRange(start: _startDate!, end: _endDate!)
              : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.skyBlue,
              onPrimary: Colors.white,
              onSurface: AppTheme.deepBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyFilters();
    }
  }
}
