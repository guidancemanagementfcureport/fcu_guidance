import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';
import '../../services/supabase_service.dart';
import '../../models/report_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/toast_utils.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CounselorCaseTimelinePage extends StatefulWidget {
  const CounselorCaseTimelinePage({super.key});

  @override
  State<CounselorCaseTimelinePage> createState() =>
      _CounselorCaseTimelinePageState();
}

enum CaseTimelineStatus {
  active,
  underMonitoring,
  forFollowUp,
  resolved,
  caseClosed;

  String get displayName {
    switch (this) {
      case CaseTimelineStatus.active:
        return 'Active Case';
      case CaseTimelineStatus.underMonitoring:
        return 'Under Monitoring';
      case CaseTimelineStatus.forFollowUp:
        return 'For Follow Up';
      case CaseTimelineStatus.resolved:
        return 'Resolved';
      case CaseTimelineStatus.caseClosed:
        return 'Case Closed';
    }
  }

  Color get color {
    switch (this) {
      case CaseTimelineStatus.active:
        return AppTheme.errorRed;
      case CaseTimelineStatus.underMonitoring:
        return AppTheme.warningOrange;
      case CaseTimelineStatus.forFollowUp:
        return AppTheme.purple;
      case CaseTimelineStatus.resolved:
        return AppTheme.successGreen;
      case CaseTimelineStatus.caseClosed:
        return AppTheme.mediumGray;
    }
  }
}

class CaseRecord {
  final String originalReportId;
  final String id;
  final String studentName;
  final String caseType;
  final DateTime dateReported;
  final DateTime lastUpdated;
  CaseTimelineStatus status;
  final String description;

  CaseRecord({
    required this.originalReportId,
    required this.id,
    required this.studentName,
    required this.caseType,
    required this.dateReported,
    required this.lastUpdated,
    required this.status,
    required this.description,
  });
}

class _CounselorCaseTimelinePageState extends State<CounselorCaseTimelinePage> {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  List<CaseRecord> _allCases = [];
  List<CaseRecord> _filteredCases = [];
  CaseTimelineStatus? _selectedFilter;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final counselorId = authProvider.currentUser?.id;

      if (counselorId != null) {
        // Fetch all reports relevant to the counselor
        final reports = await _supabase.getCounselorAllReports(counselorId);

        // Fetch student names for all reports
        final studentIds =
            reports
                .map((r) => r.studentId)
                .where((id) => id != null)
                .cast<String>()
                .toSet()
                .toList();
        final students = await _supabase.getUsersByIds(studentIds);
        final studentMap = {for (var s in students) s.id: s.fullName};

        final cases =
            reports.map((report) {
              return CaseRecord(
                originalReportId: report.id,
                id:
                    report.isAnonymous
                        ? (report.trackingId ??
                            'ANON-${report.id.substring(0, 5)}')
                        : 'C-${report.id.substring(0, 5)}',
                studentName:
                    report.isAnonymous
                        ? 'Anonymous'
                        : (studentMap[report.studentId] ?? 'Unknown Student'),
                caseType: report.type,
                dateReported: report.createdAt,
                lastUpdated: report.updatedAt,
                status: _mapReportStatusToTimeline(report.status),
                description: report.details,
              );
            }).toList();

        if (mounted) {
          setState(() {
            _allCases = cases;
            _filterCases(_selectedFilter);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading cases: $e');
      if (mounted) {
        ToastUtils.showError(context, 'Error loading cases: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  CaseTimelineStatus _mapReportStatusToTimeline(ReportStatus status) {
    switch (status) {
      case ReportStatus.forwarded:
      case ReportStatus.counselorConfirmed:
        return CaseTimelineStatus.active;
      case ReportStatus.counselingScheduled:
        return CaseTimelineStatus.underMonitoring;
      case ReportStatus.counselorReviewed:
      case ReportStatus.approvedByDean:
        return CaseTimelineStatus.forFollowUp;
      case ReportStatus.settled:
        return CaseTimelineStatus.resolved;
      case ReportStatus.completed:
        return CaseTimelineStatus.caseClosed;
      default:
        return CaseTimelineStatus.active;
    }
  }

  void _filterCases(CaseTimelineStatus? status) {
    setState(() {
      _selectedFilter = status;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCases =
          _allCases.where((caseRecord) {
            final matchesStatus =
                _selectedFilter == null || caseRecord.status == _selectedFilter;
            final matchesSearch =
                caseRecord.studentName.toLowerCase().contains(query) ||
                caseRecord.id.toLowerCase().contains(query) ||
                caseRecord.caseType.toLowerCase().contains(query);
            return matchesStatus && matchesSearch;
          }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(
    CaseRecord caseRecord,
    CaseTimelineStatus newStatus,
  ) async {
    // Optimistic update
    setState(() {
      caseRecord.status = newStatus;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final counselorId = authProvider.currentUser?.id;

      if (counselorId != null) {
        final reportStatus = _mapTimelineToReportStatus(newStatus);

        await _supabase.updateReportStatus(
          reportId: caseRecord.originalReportId,
          status: reportStatus,
          counselorId: counselorId,
        );
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
      // Revert on error could be implemented here
      if (mounted) {
        ToastUtils.showError(context, 'Failed to update status on server');
      }
    }

    // Re-apply filter if active
    _filterCases(_selectedFilter);

    // Show confirmation
    if (mounted) {
      ToastUtils.showSuccess(
        context,
        'Status updated to ${newStatus.displayName} for ${caseRecord.studentName}',
        title: 'Status Updated',
      );
    }
  }

  ReportStatus _mapTimelineToReportStatus(CaseTimelineStatus status) {
    switch (status) {
      case CaseTimelineStatus.active:
        return ReportStatus.counselorConfirmed;
      case CaseTimelineStatus.underMonitoring:
        return ReportStatus.counselingScheduled;
      case CaseTimelineStatus.forFollowUp:
        return ReportStatus.counselorReviewed;
      case CaseTimelineStatus.resolved:
        return ReportStatus.settled;
      case CaseTimelineStatus.caseClosed:
        return ReportStatus.completed;
    }
  }

  Future<void> _generateReport({
    CaseRecord? individualCase,
    bool isMonthly = false,
    int? month,
    int? year,
  }) async {
    final pdf = pw.Document();
    final isAnnual = individualCase == null && !isMonthly;
    final isIndividual = individualCase != null;

    String title = 'Student Case Report';
    if (isAnnual) title = 'Annual Student Case Timeline Report';
    if (isMonthly) {
      title =
          'Monthly Case Report - ${DateFormat('MMMM yyyy').format(DateTime(year!, month!))}';
    }

    List<CaseRecord> reportData = _filteredCases;
    if (isMonthly) {
      reportData =
          _allCases
              .where(
                (c) =>
                    c.dateReported.month == month &&
                    c.dateReported.year == year,
              )
              .toList();
    }
    if (isIndividual) {
      reportData = [individualCase];
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            _buildPdfHeader(title),
            pw.SizedBox(height: 20),
            if (isIndividual)
              _buildIndividualReportContent(individualCase)
            else
              _buildAnnualReportContent(reportData),
          ];
        },
      ),
    );

    final fileName =
        isIndividual
            ? 'case_${individualCase.id}_report.pdf'
            : (isMonthly
                ? 'monthly_report_${month}_$year.pdf'
                : 'annual_case_report.pdf');

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: fileName,
    );
  }

  Future<void> _generateExcelReport({
    CaseRecord? individualCase,
    bool isMonthly = false,
    int? month,
    int? year,
  }) async {
    final excel = excel_pkg.Excel.createExcel();
    final excel_pkg.Sheet sheetObject = excel['Sheet1'];

    // Header Style
    excel_pkg.CellStyle headerStyle = excel_pkg.CellStyle(
      bold: true,
      backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#DEEBF7'),
      fontFamily: excel_pkg.getFontFamily(excel_pkg.FontFamily.Calibri),
    );

    // Set Headers
    var headers = [
      'Case ID',
      'Student Name',
      'Case Type',
      'Status',
      'Date Reported',
      'Last Updated',
      'Description',
    ];
    for (var i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(
        excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = excel_pkg.TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    List<CaseRecord> reportData = _filteredCases;
    if (isMonthly) {
      reportData =
          _allCases
              .where(
                (c) =>
                    c.dateReported.month == month &&
                    c.dateReported.year == year,
              )
              .toList();
    }
    if (individualCase != null) {
      reportData = [individualCase];
    }

    // Add Data
    for (var i = 0; i < reportData.length; i++) {
      var c = reportData[i];
      sheetObject
          .cell(
            excel_pkg.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: i + 1,
            ),
          )
          .value = excel_pkg.TextCellValue(c.id);
      sheetObject
          .cell(
            excel_pkg.CellIndex.indexByColumnRow(
              columnIndex: 1,
              rowIndex: i + 1,
            ),
          )
          .value = excel_pkg.TextCellValue(c.studentName);
      sheetObject
          .cell(
            excel_pkg.CellIndex.indexByColumnRow(
              columnIndex: 2,
              rowIndex: i + 1,
            ),
          )
          .value = excel_pkg.TextCellValue(c.caseType);
      sheetObject
          .cell(
            excel_pkg.CellIndex.indexByColumnRow(
              columnIndex: 3,
              rowIndex: i + 1,
            ),
          )
          .value = excel_pkg.TextCellValue(c.status.displayName);
      sheetObject
          .cell(
            excel_pkg.CellIndex.indexByColumnRow(
              columnIndex: 4,
              rowIndex: i + 1,
            ),
          )
          .value = excel_pkg.TextCellValue(
        DateFormat('yyyy-MM-dd').format(c.dateReported),
      );
      sheetObject
          .cell(
            excel_pkg.CellIndex.indexByColumnRow(
              columnIndex: 5,
              rowIndex: i + 1,
            ),
          )
          .value = excel_pkg.TextCellValue(
        DateFormat('yyyy-MM-dd').format(c.lastUpdated),
      );
      sheetObject
          .cell(
            excel_pkg.CellIndex.indexByColumnRow(
              columnIndex: 6,
              rowIndex: i + 1,
            ),
          )
          .value = excel_pkg.TextCellValue(c.description);
    }

    final fileName =
        individualCase != null
            ? 'case_${individualCase.id}_report.xlsx'
            : (isMonthly
                ? 'monthly_report_${month}_$year.xlsx'
                : 'annual_case_report.xlsx');

    var fileBytes = excel.save();
    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: Uint8List.fromList(fileBytes!),
        filename: fileName,
      );
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(fileBytes!);
      if (mounted) {
        ToastUtils.showSuccess(context, 'Report saved to ${file.path}');
      }
    }
  }

  void _showExportDialog({CaseRecord? individualCase}) {
    int selectedMonth = DateTime.now().month;
    int selectedYear = DateTime.now().year;
    String selectedPeriod = individualCase != null ? 'Individual' : 'Annual';
    String selectedFormat = 'PDF';

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Row(
                    children: [
                      Icon(
                        Icons.file_download_outlined,
                        color: AppTheme.deepBlue,
                      ),
                      const SizedBox(width: 12),
                      const Text('Export Case Report'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (individualCase == null) ...[
                        const Text(
                          'Select Period',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: selectedPeriod,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                          items:
                              ['Annual', 'Monthly']
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (val) =>
                                  setDialogState(() => selectedPeriod = val!),
                        ),
                        if (selectedPeriod == 'Monthly') ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: selectedMonth,
                                  decoration: InputDecoration(
                                    labelText: 'Month',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items:
                                      List.generate(12, (i) => i + 1)
                                          .map(
                                            (m) => DropdownMenuItem(
                                              value: m,
                                              child: Text(
                                                DateFormat(
                                                  'MMMM',
                                                ).format(DateTime(2024, m)),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (val) => setDialogState(
                                        () => selectedMonth = val!,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: selectedYear,
                                  decoration: InputDecoration(
                                    labelText: 'Year',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items:
                                      [
                                            DateTime.now().year,
                                            DateTime.now().year - 1,
                                          ]
                                          .map(
                                            (y) => DropdownMenuItem(
                                              value: y,
                                              child: Text(y.toString()),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (val) => setDialogState(
                                        () => selectedYear = val!,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                      const Text(
                        'Select Format',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormatOption(
                              'PDF',
                              Icons.picture_as_pdf_rounded,
                              Colors.red.shade700,
                              selectedFormat == 'PDF',
                              () =>
                                  setDialogState(() => selectedFormat = 'PDF'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFormatOption(
                              'Excel',
                              Icons.table_view_rounded,
                              Colors.green.shade700,
                              selectedFormat == 'Excel',
                              () => setDialogState(
                                () => selectedFormat = 'Excel',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (selectedFormat == 'PDF') {
                          _generateReport(
                            individualCase: individualCase,
                            isMonthly: selectedPeriod == 'Monthly',
                            month: selectedMonth,
                            year: selectedYear,
                          );
                        } else {
                          _generateExcelReport(
                            individualCase: individualCase,
                            isMonthly: selectedPeriod == 'Monthly',
                            month: selectedMonth,
                            year: selectedYear,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.deepBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Generate Report'),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _buildFormatOption(
    String label,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? color : AppTheme.mediumGray.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? color : AppTheme.mediumGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCaseDetailsDialog(CaseRecord caseRecord) {
    showDialog(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        final isDesktop = size.width > 700;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.all(24),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.skyBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.assignment_rounded, color: AppTheme.deepBlue),
              ),
              const SizedBox(width: 16),
              const Text(
                'Case Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Container(
            width: 700,
            constraints: BoxConstraints(
              maxWidth: size.width * 0.9,
              maxHeight: size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailItem('Case ID', caseRecord.id),
                              _buildDetailItem(
                                'Student',
                                caseRecord.studentName,
                              ),
                              _buildDetailItem('Category', caseRecord.caseType),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailItem(
                                'Status',
                                caseRecord.status.displayName,
                                color: caseRecord.status.color,
                              ),
                              _buildDetailItem(
                                'Date Reported',
                                DateFormat(
                                  'MMM d, yyyy • hh:mm a',
                                ).format(caseRecord.dateReported),
                              ),
                              _buildDetailItem(
                                'Last Updated',
                                DateFormat(
                                  'MMM d, yyyy • hh:mm a',
                                ).format(caseRecord.lastUpdated),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildDetailItem('Case ID', caseRecord.id),
                    _buildDetailItem('Student', caseRecord.studentName),
                    _buildDetailItem('Category', caseRecord.caseType),
                    _buildDetailItem(
                      'Status',
                      caseRecord.status.displayName,
                      color: caseRecord.status.color,
                    ),
                    _buildDetailItem(
                      'Date Reported',
                      DateFormat(
                        'MMM d, yyyy • hh:mm a',
                      ).format(caseRecord.dateReported),
                    ),
                    _buildDetailItem(
                      'Last Updated',
                      DateFormat(
                        'MMM d, yyyy • hh:mm a',
                      ).format(caseRecord.lastUpdated),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mediumGray,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.mediumGray.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.mediumGray.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      caseRecord.description,
                      style: const TextStyle(height: 1.6, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.all(24),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value, {Color? color}) {
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
                color: AppTheme.mediumGray,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? AppTheme.deepBlue,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'FCU Guidance Office',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Generated on: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildAnnualReportContent(List<CaseRecord> cases) {
    return pw.TableHelper.fromTextArray(
      headers: ['ID', 'Student', 'Type', 'Status', 'Last Updated'],
      data:
          cases.map((c) {
            return [
              c.id,
              c.studentName,
              c.caseType,
              c.status.displayName,
              DateFormat('MMM d, yyyy').format(c.lastUpdated),
            ];
          }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        3: pw.Alignment.center, // Center Status
        4: pw.Alignment.centerRight, // Right align Date
      },
    );
  }

  pw.Widget _buildIndividualReportContent(CaseRecord c) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildPdfField('Case ID', c.id),
        _buildPdfField('Student Name', c.studentName),
        _buildPdfField('Case Type', c.caseType),
        _buildPdfField(
          'Current Status',
          c.status.displayName,
          color: _getPdfColor(c.status),
        ),
        _buildPdfField(
          'Date Reported',
          DateFormat('MMMM d, yyyy').format(c.dateReported),
        ),
        _buildPdfField(
          'Last Updated',
          DateFormat('MMMM d, yyyy').format(c.lastUpdated),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Case Description / Notes:',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(c.description),
        ),
        pw.SizedBox(height: 200), // Filler for report look
        pw.Divider(color: PdfColors.grey300),
        pw.Text(
          'Confidential Document - For Authorized Use Only',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
        ),
      ],
    );
  }

  pw.Widget _buildPdfField(String label, String value, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: color ?? PdfColors.black,
              fontWeight: color != null ? pw.FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  PdfColor _getPdfColor(CaseTimelineStatus status) {
    switch (status) {
      case CaseTimelineStatus.active:
        return PdfColors.red;
      case CaseTimelineStatus.underMonitoring:
        return PdfColors.orange;
      case CaseTimelineStatus.forFollowUp:
        return PdfColors.purple;
      case CaseTimelineStatus.resolved:
        return PdfColors.green;
      case CaseTimelineStatus.caseClosed:
        return PdfColors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1200;
    final isTablet = size.width > 768 && size.width <= 1200;

    return ResponsiveSidebar(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: AppTheme.softBlueGradientDecoration,
          child: Column(
            children: [
              ModernDashboardHeader(
                title: 'Student Case Timeline',
                subtitle:
                    'Manage and track student case progress with real-time analytics',
                icon: Icons.timeline_rounded,
                actions: [
                  ElevatedButton.icon(
                    onPressed: () => _showExportDialog(),
                    icon: const Icon(Icons.file_download_outlined, size: 20),
                    label: const Text('Export Reports'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.deepBlue,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: AppTheme.deepBlue.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 40 : (isTablet ? 24 : 16),
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchAndFilters(isDesktop || isTablet),
                      const SizedBox(height: 32),
                      Expanded(
                        child:
                            _isLoading
                                ? _buildLoadingState()
                                : _filteredCases.isEmpty
                                ? _buildEmptyState()
                                : (isDesktop || isTablet)
                                ? _buildDesktopView()
                                : _buildMobileView(),
                      ),
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

  Widget _buildSearchAndFilters(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (_) => _applyFilters(),
                  decoration: InputDecoration(
                    hintText: 'Search by student name, case ID, or type...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.mediumGray,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    suffixIcon:
                        _searchController.text.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                            : null,
                  ),
                ),
              ),
            ),
            if (isDesktop) ...[
              const SizedBox(width: 16),
              _buildStatsQuickView(),
            ],
          ],
        ),
        const SizedBox(height: 24),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildModernFilterChip(
                null,
                'All Cases',
                Icons.all_inclusive_rounded,
              ),
              const SizedBox(width: 12),
              ...CaseTimelineStatus.values.map((status) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildModernFilterChip(
                    status,
                    status.displayName,
                    _getStatusIcon(status),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsQuickView() {
    return Row(
      children: [
        _buildMiniStat('Total', _allCases.length.toString(), AppTheme.deepBlue),
        const SizedBox(width: 12),
        _buildMiniStat(
          'Active',
          _allCases
              .where((c) => c.status == CaseTimelineStatus.active)
              .length
              .toString(),
          AppTheme.errorRed,
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFilterChip(
    CaseTimelineStatus? status,
    String label,
    IconData icon,
  ) {
    final isSelected = _selectedFilter == status;
    final color = status?.color ?? AppTheme.deepBlue;

    return InkWell(
      onTap: () => _filterCases(status),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? color : AppTheme.mediumGray.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppTheme.mediumGray,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.mediumGray,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopView() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(
          context,
        ).copyWith(dividerColor: AppTheme.mediumGray.withValues(alpha: 0.05)),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 350,
              ),
              child: DataTable(
                headingRowHeight: 75,
                dataRowMaxHeight: 90,
                dataRowMinHeight: 80,
                horizontalMargin: 30,
                columnSpacing: 40,
                headingRowColor: WidgetStateProperty.all(
                  AppTheme.skyBlue.withValues(alpha: 0.05),
                ),
                columns: [
                  _buildDataColumn('STUDENT'),
                  _buildDataColumn('CASE CATEGORY'),
                  _buildDataColumn('STATUS'),
                  _buildDataColumn('TIMELINE'),
                  _buildDataColumn('ACTIONS', center: true),
                ],
                rows:
                    _filteredCases.map((caseRecord) {
                      return DataRow(
                        cells: [
                          DataCell(_buildStudentCell(caseRecord)),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.skyBlue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                caseRecord.caseType,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.deepBlue,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          DataCell(_buildStatusBadge(caseRecord)),
                          DataCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat(
                                    'MMM d, yyyy',
                                  ).format(caseRecord.lastUpdated),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.deepBlue,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Last updated ${DateFormat('hh:mm a').format(caseRecord.lastUpdated)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.mediumGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildActionButton(
                                    icon: Icons.visibility_outlined,
                                    tooltip: 'View Details',
                                    color: AppTheme.deepBlue,
                                    onTap:
                                        () =>
                                            _showCaseDetailsDialog(caseRecord),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildActionButton(
                                    icon: Icons.file_download_outlined,
                                    tooltip: 'Export Case',
                                    color: AppTheme.mediumBlue,
                                    onTap:
                                        () => _showExportDialog(
                                          individualCase: caseRecord,
                                        ),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildUpdateStatusButton(caseRecord),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileView() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredCases.length,
      itemBuilder: (context, index) {
        final caseRecord = _filteredCases[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: caseRecord.status.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        _getStatusIcon(caseRecord.status),
                        color: caseRecord.status.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  caseRecord.studentName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: AppTheme.deepBlue,
                                  ),
                                ),
                              ),
                              _buildUpdateStatusButton(caseRecord),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            caseRecord.id,
                            style: TextStyle(
                              color: AppTheme.mediumGray,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildStatusBadge(caseRecord),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.skyBlue.withValues(alpha: 0.03),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 14,
                          color: AppTheme.mediumGray,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          caseRecord.caseType,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildActionButton(
                          icon: Icons.visibility_outlined,
                          tooltip: 'View',
                          color: AppTheme.deepBlue,
                          onTap: () => _showCaseDetailsDialog(caseRecord),
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          icon: Icons.file_download_outlined,
                          tooltip: 'Export',
                          color: AppTheme.mediumBlue,
                          onTap:
                              () =>
                                  _showExportDialog(individualCase: caseRecord),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat(
                            'MMM d, yyyy',
                          ).format(caseRecord.lastUpdated),
                          style: TextStyle(
                            color: AppTheme.mediumGray,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  DataColumn _buildDataColumn(String label, {bool center = false}) {
    return DataColumn(
      label:
          center
              ? Expanded(
                child: Center(child: Text(label, style: _headingStyle())),
              )
              : Text(label, style: _headingStyle()),
    );
  }

  TextStyle _headingStyle() => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: AppTheme.deepBlue.withValues(alpha: 0.6),
    letterSpacing: 1.2,
  );

  Widget _buildStudentCell(CaseRecord caseRecord) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.skyBlue, AppTheme.mediumBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              caseRecord.studentName[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              caseRecord.studentName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.deepBlue,
                fontSize: 15,
              ),
            ),
            Text(
              caseRecord.id,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.mediumGray,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _buildUpdateStatusButton(CaseRecord caseRecord) {
    return PopupMenuButton<CaseTimelineStatus>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.mediumGray.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.edit_note_rounded,
          color: AppTheme.mediumGray,
          size: 18,
        ),
      ),
      onSelected: (status) => _updateStatus(caseRecord, status),
      itemBuilder:
          (context) =>
              CaseTimelineStatus.values.map((status) {
                return PopupMenuItem(
                  value: status,
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: status.color, size: 10),
                      const SizedBox(width: 12),
                      Text(
                        status.displayName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.skyBlue.withValues(alpha: 0.1),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 80,
              color: AppTheme.skyBlue.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _searchController.text.isNotEmpty
                ? 'No matches found'
                : 'No records yet',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _searchController.text.isNotEmpty
                ? 'Try adjusting your search terms or filters'
                : 'Student cases will appear here as they are forwarded to you',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.mediumGray, fontSize: 16),
          ),
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: TextButton(
                onPressed: () {
                  _searchController.clear();
                  _applyFilters();
                },
                child: const Text('Clear Search'),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(CaseTimelineStatus status) {
    switch (status) {
      case CaseTimelineStatus.active:
        return Icons.local_fire_department_rounded;
      case CaseTimelineStatus.underMonitoring:
        return Icons.visibility_rounded;
      case CaseTimelineStatus.forFollowUp:
        return Icons.schedule_rounded;
      case CaseTimelineStatus.resolved:
        return Icons.check_circle_rounded;
      case CaseTimelineStatus.caseClosed:
        return Icons.archive_rounded;
    }
  }

  Widget _buildStatusBadge(CaseRecord caseRecord) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: caseRecord.status.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: caseRecord.status.color.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        caseRecord.status.displayName,
        style: TextStyle(
          color: caseRecord.status.color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
