import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../models/report_model.dart';
import '../../models/counseling_request_model.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';
import '../../theme/app_theme.dart';

class DeanReportAnalyticsPage extends StatefulWidget {
  const DeanReportAnalyticsPage({super.key});

  @override
  State<DeanReportAnalyticsPage> createState() =>
      _DeanReportAnalyticsPageState();
}

class _DeanReportAnalyticsPageState extends State<DeanReportAnalyticsPage> {
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
      final reports = await _supabase.getAllReportsForAdmin();

      _allReports =
          reports.where((r) {
            final student = r['student'] as Map<String, dynamic>?;
            final level = student?['student_level'] as String?;
            return level != null && level.toLowerCase() == 'college';
          }).toList();

      _totalReports = _allReports.length;
      _activeReports =
          _allReports.where((r) {
            final status = r['status'] as String? ?? '';
            return status != 'settled' && status != 'completed';
          }).length;
      _resolvedReports = _totalReports - _activeReports;

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
        final searchLower = _searchQuery.toLowerCase();
        _filteredReports =
            _allReports.where((report) {
              final student = report['student'] as Map<String, dynamic>?;
              final level = student?['student_level'] as String?;
              if (level == null || level.toLowerCase() != 'college') {
                return false;
              }

              final trackingId = report['tracking_id'] as String?;
              final title = report['title'] as String?;
              final type = report['type'] as String?;
              final details = report['details'] as String?;
              final description = report['description'] as String?;

              return (trackingId?.toLowerCase().contains(searchLower) ??
                      false) ||
                  (title?.toLowerCase().contains(searchLower) ?? false) ||
                  (type?.toLowerCase().contains(searchLower) ?? false) ||
                  (details?.toLowerCase().contains(searchLower) ?? false) ||
                  (description?.toLowerCase().contains(searchLower) ?? false) ||
                  (student?['full_name']?.toString().toLowerCase().contains(
                        searchLower,
                      ) ??
                      false);
            }).toList();
      } else {
        final reports = await _supabase.getReportsWithAdvancedFilters(
          startDate: _startDate,
          endDate: _endDate,
          status: _selectedStatus,
          roleFilter: _selectedRole,
          isAnonymous: _isAnonymousFilter,
        );

        _filteredReports =
            reports.where((r) {
              final student = r['student'] as Map<String, dynamic>?;
              final level = student?['student_level'] as String?;
              return level != null && level.toLowerCase() == 'college';
            }).toList();
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

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    return ResponsiveSidebar(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            color: AppTheme.lightGray.withValues(alpha: 0.4),
            image: DecorationImage(
              image: const AssetImage(
                'assets/images/pattern.png',
              ), // Fallback if exists
              opacity: 0.03,
              repeat: ImageRepeat.repeat,
              colorFilter: ColorFilter.mode(
                AppTheme.skyBlue.withValues(alpha: 0.1),
                BlendMode.srcIn,
              ),
            ),
          ),
          child: Column(
            children: [
              const ModernDashboardHeader(
                title: 'Report Analytics',
                subtitle: 'College Student Oversight & Case Records',
                icon: Icons.insights,
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPremiumAnalyticsGrid(isDesktop),
                              const SizedBox(height: 32),
                              _buildEnhancedFilterBar(),
                              const SizedBox(height: 32),
                              _buildReportsSection(isDesktop),
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

  Widget _buildPremiumAnalyticsGrid(bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            _buildPremiumCard(
              'Total Submissions',
              _totalReports.toString(),
              Icons.summarize_rounded,
              AppTheme.skyBlue,
              'All archived & active cases',
            ),
            _buildPremiumCard(
              'Pending Action',
              _activeReports.toString(),
              Icons.pending_actions_rounded,
              AppTheme.warningOrange,
              'Reports awaiting resolution',
            ),
            _buildPremiumCard(
              'Successfully Settled',
              _resolvedReports.toString(),
              Icons.verified_user_rounded,
              AppTheme.successGreen,
              'Cases marked as completed',
            ),
          ],
        );
      },
    );
  }

  Widget _buildPremiumCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      width:
          MediaQuery.of(context).size.width >= 1100
              ? (MediaQuery.of(context).size.width - 340) / 3
              : double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.05), width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(icon, size: 80, color: color.withValues(alpha: 0.05)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 20),
              Text(
                value,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.deepBlue,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGray,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: AppTheme.mediumGray),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedFilterBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepBlue.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
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
                  const Icon(Icons.tune_rounded, color: AppTheme.skyBlue),
                  const SizedBox(width: 12),
                  Text(
                    'Precision Filters',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.deepBlue,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Reset'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.mediumGray,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  _buildSearchField(isNarrow ? double.infinity : 300),
                  _buildModernDropdown(
                    label: 'Workflow Status',
                    value: _selectedStatus,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Global (All)'),
                      ),
                      ...ReportStatus.values.map(
                        (s) => DropdownMenuItem(
                          value: s.toString(),
                          child: Text(s.displayName),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedStatus = v);
                      _applyFilters();
                    },
                    width: isNarrow ? double.infinity : 220,
                  ),
                  _buildModernDropdown(
                    label: 'Stakeholder Role',
                    value: _selectedRole,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Everyone')),
                      DropdownMenuItem(
                        value: 'teacher',
                        child: Text('Teacher Involved'),
                      ),
                      DropdownMenuItem(
                        value: 'counselor',
                        child: Text('Counseling Team'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedRole = v);
                      _applyFilters();
                    },
                    width: isNarrow ? double.infinity : 220,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(double width) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Search Case Information',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.mediumGray,
              ),
            ),
          ),
          TextField(
            decoration: InputDecoration(
              hintText: 'Tracking ID, Student Name...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppTheme.skyBlue,
              ),
              filled: true,
              fillColor: AppTheme.lightGray.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (value) {
              _searchQuery = value;
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModernDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.mediumGray,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.lightGray.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(15),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: value,
                items: items,
                onChanged: onChanged,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.skyBlue,
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.darkGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsSection(bool isDesktop) {
    if (_filteredReports.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Icon(
              Icons.auto_stories_rounded,
              size: 80,
              color: AppTheme.mediumGray.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No records match your current criteria.',
              style: TextStyle(color: AppTheme.mediumGray, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(
      0,
      _filteredReports.length,
    );
    final pageReports = _filteredReports.sublist(startIndex, endIndex);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Records (${_filteredReports.length})',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.deepBlue,
              ),
            ),
            _buildPaginationControls(startIndex, endIndex),
          ],
        ),
        const SizedBox(height: 16),
        isDesktop
            ? _buildModernTable(pageReports)
            : _buildResponsiveListView(pageReports),
      ],
    );
  }

  Widget _buildPaginationControls(int start, int end) {
    return Row(
      children: [
        Text(
          '${start + 1}-$end of ${_filteredReports.length}',
          style: const TextStyle(color: AppTheme.mediumGray, fontSize: 13),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed:
              _currentPage > 0 ? () => setState(() => _currentPage--) : null,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            elevation: 1,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed:
              end < _filteredReports.length
                  ? () => setState(() => _currentPage++)
                  : null,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            elevation: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildModernTable(List<Map<String, dynamic>> reports) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepBlue.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue.withValues(alpha: 0.03),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text(
                    'CASE IDENTIFIER',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: AppTheme.mediumGray,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'REPORT TITLE',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: AppTheme.mediumGray,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'CURRENT STATUS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: AppTheme.mediumGray,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'STUDENT NAME',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: AppTheme.mediumGray,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ASSIGNED',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: AppTheme.mediumGray,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'REVIEW',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: AppTheme.mediumGray,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          ...reports.map((r) => _buildModernTableRow(r)),
        ],
      ),
    );
  }

  Widget _buildModernTableRow(Map<String, dynamic> report) {
    final reportId = report['id'] as String;
    final status = ReportStatus.fromString(report['status'] as String);
    final createdAt = DateTime.parse(report['created_at'] as String);
    final isAnonymous = report['is_anonymous'] as bool? ?? false;
    final student = report['student'] as Map<String, dynamic>?;
    final counselor = report['counselor'] as Map<String, dynamic>?;

    return InkWell(
      onTap: () => _viewCaseDetail(reportId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.lightGray.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
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
                  Text(
                    DateFormat('MMM dd, yyyy').format(createdAt),
                    style: TextStyle(fontSize: 12, color: AppTheme.mediumGray),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
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
            Expanded(flex: 2, child: _buildStatusBadge(status)),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: (isAnonymous
                            ? Colors.grey
                            : AppTheme.skyBlue)
                        .withValues(alpha: 0.1),
                    child: Icon(
                      isAnonymous
                          ? Icons.person_off_rounded
                          : Icons.person_rounded,
                      size: 14,
                      color: isAnonymous ? Colors.grey : AppTheme.skyBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isAnonymous
                          ? 'Anonymous'
                          : (student?['full_name'] as String? ?? 'N/A'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkGray,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                counselor?['full_name'] as String? ?? 'Pending...',
                style: const TextStyle(
                  color: AppTheme.mediumGray,
                  fontSize: 13,
                ),
              ),
            ),
            SizedBox(
              width: 80,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.skyBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppTheme.skyBlue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveListView(List<Map<String, dynamic>> reports) {
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

        return InkWell(
          onTap: () => _viewCaseDetail(reportId),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.deepBlue.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report['tracking_id'] as String? ??
                              reportId.substring(0, 8).toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report['title']?.toString() ?? 'No Title',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.skyBlue,
                          ),
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy').format(createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.mediumGray,
                          ),
                        ),
                      ],
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                Row(
                  children: [
                    Icon(
                      isAnonymous
                          ? Icons.person_off_rounded
                          : Icons.person_rounded,
                      size: 20,
                      color: AppTheme.skyBlue,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isAnonymous
                          ? 'Anonymous Filing'
                          : (student?['full_name'] as String? ?? 'N/A'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGray,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _viewCaseDetail(reportId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.skyBlue.withValues(alpha: 0.1),
                      foregroundColor: AppTheme.skyBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Access Detailed Record'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(ReportStatus status) {
    Color baseColor;
    switch (status) {
      case ReportStatus.submitted:
      case ReportStatus.pending:
        baseColor = AppTheme.warningOrange;
        break;
      case ReportStatus.settled:
      case ReportStatus.completed:
        baseColor = AppTheme.successGreen;
        break;
      default:
        baseColor = AppTheme.skyBlue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.displayName.toUpperCase(),
        style: TextStyle(
          color: baseColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _viewCaseDetail(String reportId) async {
    final report = _allReports.firstWhere(
      (r) => r['id'] == reportId,
      orElse: () => {},
    );
    if (report.isEmpty) return;

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
            if (u != null) participantNames[p['userId']] = u.fullName;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading details: $e');
    }

    if (mounted) Navigator.pop(context);

    final createdAt = DateTime.parse(report['created_at'] as String);
    final status = ReportStatus.fromString(report['status'] as String);
    final isAnonymous = report['is_anonymous'] as bool? ?? false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            child: Container(
              width: 800,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Comprehensive Case Review',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.mediumGray,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            report['tracking_id'] as String? ??
                                reportId.substring(0, 8).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.deepBlue,
                            ),
                          ),
                        ],
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailSection('Core Information', [
                            _buildRecordField(
                              'Report Timestamp',
                              DateFormat(
                                'MMMM dd, yyyy - hh:mm a',
                              ).format(createdAt),
                            ),
                            _buildRecordField(
                              'Subject Classification',
                              report['title'] ?? 'Generic Report',
                            ),
                            _buildRecordField(
                              'Incident Category',
                              report['type'] ?? 'General Inquiry',
                            ),
                          ]),
                          const SizedBox(height: 24),
                          _buildDescriptionPanel(
                            'Submission Details',
                            report['description'] ??
                                report['details'] ??
                                'Historical record with no text body.',
                          ),

                          if (report['teacher_note']?.toString().isNotEmpty ??
                              false)
                            _buildNotePanel(
                              'Eductor Observation',
                              report['teacher_note'],
                              AppTheme.skyBlue,
                            ),
                          if (report['counselor_note']?.toString().isNotEmpty ??
                              false)
                            _buildNotePanel(
                              'Specialist Evaluation',
                              report['counselor_note'],
                              AppTheme.successGreen,
                            ),
                          if (report['dean_note']?.toString().isNotEmpty ??
                              false)
                            _buildNotePanel(
                              'Executive Remark',
                              report['dean_note'],
                              AppTheme.deepBlue,
                            ),

                          const SizedBox(height: 24),
                          _buildDetailSection('Stakeholder Identification', [
                            _buildRecordField(
                              'Principal Student',
                              isAnonymous
                                  ? 'Anonymous Filer'
                                  : ((report['student']
                                          as Map?)?['full_name'] ??
                                      'Undefined'),
                            ),
                            _buildRecordField(
                              'Referring Officer',
                              (report['teacher'] as Map?)?['full_name'] ??
                                  'Direct Filing',
                            ),
                            _buildRecordField(
                              'Case Specialist',
                              (report['counselor'] as Map?)?['full_name'] ??
                                  'Pending Assignment',
                            ),
                          ]),

                          if (counselingRequest?.participants != null &&
                              counselingRequest!.participants!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Additional Participants',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.mediumGray,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...counselingRequest.participants!.map((p) {
                              String label =
                                  p['role']?.toString().toUpperCase() ??
                                  'PARTICIPANT';
                              String value =
                                  p['userId'] != null
                                      ? (participantNames[p['userId']] ??
                                          'Loading...')
                                      : (p['name'] ?? 'External Party');
                              return _buildRecordField(label, value);
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Dismiss View'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: AppTheme.skyBlue,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        ...fields,
      ],
    );
  }

  Widget _buildRecordField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.mediumGray,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.darkGray,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionPanel(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: AppTheme.skyBlue,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.lightGray.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.lightGray),
          ),
          child: Text(
            content,
            style: const TextStyle(height: 1.5, color: AppTheme.darkGray),
          ),
        ),
      ],
    );
  }

  Widget _buildNotePanel(String title, String content, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: color,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Text(
              content,
              style: TextStyle(
                height: 1.5,
                color: AppTheme.darkGray,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
