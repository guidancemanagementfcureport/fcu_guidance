// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/modern_dashboard_header.dart';
import '../../widgets/responsive_sidebar.dart';

class AdminGuidanceReportGeneratorPage extends StatefulWidget {
  final Map<String, dynamic> reportData;

  const AdminGuidanceReportGeneratorPage({super.key, required this.reportData});

  @override
  State<AdminGuidanceReportGeneratorPage> createState() =>
      _AdminGuidanceReportGeneratorPageState();
}

class _AdminGuidanceReportGeneratorPageState
    extends State<AdminGuidanceReportGeneratorPage> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseService _supabaseService = SupabaseService();

  bool _isLoading = true;
  bool _hasCounselingRequest = false;

  // Form Fields
  late TextEditingController _summaryController;
  late TextEditingController _recommendationsController;
  late TextEditingController _actionPlanController;
  late TextEditingController _generatedByController;

  String _sessionType = 'Individual Session';
  String _sessionMode = 'In-person';
  String _caseStatus = 'Ongoing';

  // Attendance
  bool _studentPresent = true;
  bool _counselorPresent = true;
  bool _teacherPresent = false;
  bool _parentPresent = false;
  bool _deanPresent = false;

  @override
  void initState() {
    super.initState();
    _summaryController = TextEditingController(
      text: widget.reportData['description'] ?? '',
    );
    _recommendationsController = TextEditingController();
    _actionPlanController = TextEditingController();
    _generatedByController = TextEditingController(text: 'Admin');

    _fetchLinkedCounselingRequest();
  }

  Future<void> _fetchLinkedCounselingRequest() async {
    try {
      final reportId = widget.reportData['id'];
      if (reportId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final request = await _supabaseService.getCounselingRequestByReportId(
        reportId,
      );

      if (request != null) {
        if (mounted) {
          setState(() {
            _hasCounselingRequest = true;
            // Pre-fill from request
            if (request.reason != null && request.reason!.isNotEmpty) {
              _summaryController.text =
                  'Reason for Counseling: ${request.reason}\n\n${_summaryController.text}';
            }
            if (request.sessionType != null) {
              _sessionType = request.sessionType ?? 'Individual Session';
            }
            if (request.locationMode != null) {
              _sessionMode =
                  request.locationMode == 'online' ? 'Online' : 'In-person';
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching counseling request: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _recommendationsController.dispose();
    _actionPlanController.dispose();
    _generatedByController.dispose();
    super.dispose();
  }

  Future<void> _generateAndDownloadPdf() async {
    if (!_formKey.currentState!.validate()) return;

    final pdf = pw.Document();

    final reportDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    final sessionDate = DateFormat(
      'MMMM dd, yyyy',
    ).format(DateTime.parse(widget.reportData['created_at']));
    final caseCode =
        widget.reportData['tracking_id'] ??
        widget.reportData['id'].toString().substring(0, 8).toUpperCase();

    // Student Name
    final studentName =
        (widget.reportData['student'] != null &&
                widget.reportData['student']['full_name'] != null)
            ? widget.reportData['student']['full_name']
            : (widget.reportData['is_anonymous'] == true
                ? 'Anonymous Student'
                : 'N/A');

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
                    pw.Text(
                      'Guidance Session Report',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Info Table
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  _buildTableRow('Case Code', caseCode),
                  _buildTableRow('Generated Date', reportDate),
                  _buildTableRow('Prepared By', _generatedByController.text),
                  _buildTableRow('Session Date', sessionDate),
                  _buildTableRow('Session Type', _sessionType),
                  _buildTableRow('Session Mode', _sessionMode),
                  _buildTableRow('Location', 'Guidance Office'),
                ],
              ),
              pw.SizedBox(height: 20),

              // Attendance
              pw.Text(
                'Attendance',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Role',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Name',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Status',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  _buildAttendanceRow('Student', studentName, _studentPresent),
                  _buildAttendanceRow(
                    'Counselor',
                    'Assigned Counselor',
                    _counselorPresent,
                  ),
                  if (_teacherPresent)
                    _buildAttendanceRow('Teacher', 'Assigned Teacher', true),
                  if (_parentPresent)
                    _buildAttendanceRow('Parent/Guardian', 'N/A', true),
                  if (_deanPresent) _buildAttendanceRow('Dean', 'Dean', true),
                ],
              ),
              pw.SizedBox(height: 20),

              // Body Sections
              _buildSection('Session Summary', _summaryController.text),
              _buildSection('Observations', 'No major observations noted.'),
              _buildSection('Recommendations', _recommendationsController.text),
              _buildSection(
                'Action Plan / Settlement',
                _actionPlanController.text.isEmpty
                    ? 'Case Status: $_caseStatus'
                    : _actionPlanController.text,
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

    html.window.open(url, '_blank');
    html.Url.revokeObjectUrl(url);
  }

  pw.TableRow _buildTableRow(String label, String value) {
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

  pw.TableRow _buildAttendanceRow(String role, String name, bool present) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(role)),
        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(name)),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            present ? 'Present' : 'Absent',
            style: pw.TextStyle(
              color: present ? PdfColors.green : PdfColors.red,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSection(String title, String content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(content),
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                title: 'Generate Guidance Report',
                subtitle:
                    'Configure session details and generate formal documentation',
                icon: Icons.assignment_rounded,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Header Info
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.skyBlue.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.settings_suggest_rounded,
                                        color: AppTheme.skyBlue,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Report Configuration',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.deepBlue,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (_hasCounselingRequest)
                                          Text(
                                            'Linked to Student Counseling Request',
                                            style: TextStyle(
                                              color: AppTheme.successGreen,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          )
                                        else
                                          Text(
                                            'New Formal Report',
                                            style: TextStyle(
                                              color: AppTheme.mediumGray,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),

                                _buildSectionHeader(
                                  context,
                                  'Session Details',
                                  Icons.calendar_today,
                                ),
                                const SizedBox(height: 16),

                                // Session Type & Mode
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        decoration: const InputDecoration(
                                          labelText: 'Session Type',
                                          border: OutlineInputBorder(),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                        initialValue: _sessionType,
                                        items:
                                            [
                                                  'Individual Session',
                                                  'Group Session',
                                                  'Parent Conference',
                                                  'Adviser Conference',
                                                  'Combined Session',
                                                ]
                                                .map(
                                                  (t) => DropdownMenuItem(
                                                    value: t,
                                                    child: Text(t),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged:
                                            (v) => setState(
                                              () => _sessionType = v!,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        decoration: const InputDecoration(
                                          labelText: 'Session Mode',
                                          border: OutlineInputBorder(),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                        initialValue: _sessionMode,
                                        items:
                                            ['In-person', 'Online']
                                                .map(
                                                  (t) => DropdownMenuItem(
                                                    value: t,
                                                    child: Text(t),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged:
                                            (v) => setState(
                                              () => _sessionMode = v!,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'Case Status',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  initialValue: _caseStatus,
                                  items:
                                      [
                                            'Ongoing',
                                            'Settled',
                                            'Referred',
                                            'Escalated',
                                          ]
                                          .map(
                                            (t) => DropdownMenuItem(
                                              value: t,
                                              child: Text(t),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (v) => setState(() => _caseStatus = v!),
                                ),
                                const SizedBox(height: 32),

                                _buildSectionHeader(
                                  context,
                                  'Attendance',
                                  Icons.people_outline,
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 24,
                                  children: [
                                    _buildCheckbox(
                                      'Student',
                                      _studentPresent,
                                      (v) =>
                                          setState(() => _studentPresent = v!),
                                    ),
                                    _buildCheckbox(
                                      'Counselor',
                                      _counselorPresent,
                                      (v) => setState(
                                        () => _counselorPresent = v!,
                                      ),
                                    ),
                                    _buildCheckbox(
                                      'Teacher',
                                      _teacherPresent,
                                      (v) =>
                                          setState(() => _teacherPresent = v!),
                                    ),
                                    _buildCheckbox(
                                      'Parent',
                                      _parentPresent,
                                      (v) =>
                                          setState(() => _parentPresent = v!),
                                    ),
                                    _buildCheckbox(
                                      'Dean',
                                      _deanPresent,
                                      (v) => setState(() => _deanPresent = v!),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),

                                _buildSectionHeader(
                                  context,
                                  'Outcomes & Plan',
                                  Icons.article_outlined,
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _summaryController,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    labelText: 'Session Summary / Discussion',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText:
                                        'Enter a summary of the session...',
                                  ),
                                  validator:
                                      (v) =>
                                          v == null || v.isEmpty
                                              ? 'Summary is required'
                                              : null,
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _recommendationsController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Recommendations',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: 'Enter recommendations...',
                                  ),
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _actionPlanController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Action Plan / Settlement Agreement',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: 'Enter action plan...',
                                  ),
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _generatedByController,
                                  decoration: const InputDecoration(
                                    labelText: 'Prepared By (Admin Name)',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),

                                const SizedBox(height: 48),

                                // Buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => context.pop(),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 16,
                                        ),
                                      ),
                                      child: const Text('Cancel'),
                                    ),
                                    const SizedBox(width: 16),
                                    ElevatedButton.icon(
                                      onPressed: _generateAndDownloadPdf,
                                      icon: const Icon(Icons.print),
                                      label: const Text(
                                        'Generate Form & Print',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.skyBlue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        elevation: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.skyBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.deepBlue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Divider(color: AppTheme.skyBlue.withValues(alpha: 0.2)),
        ),
      ],
    );
  }

  Widget _buildCheckbox(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.skyBlue,
        ),
        Text(label),
      ],
    );
  }
}
