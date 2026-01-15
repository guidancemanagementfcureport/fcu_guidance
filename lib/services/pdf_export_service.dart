import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/report_model.dart';
import '../models/case_record_detail_model.dart';

class PdfExportService {
  /// Export a single case record to PDF
  static Future<Uint8List> exportSingleCase(
    CaseRecordDetailModel caseDetail,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (context) => [
              // Header
              _buildHeader(),
              pw.SizedBox(height: 20),

              // Case Information
              _buildCaseInfo(caseDetail.report),
              pw.SizedBox(height: 20),

              // Participants
              _buildParticipantsSection(caseDetail),
              pw.SizedBox(height: 20),

              // Case Details
              _buildCaseDetails(caseDetail.report),
              pw.SizedBox(height: 20),

              // Message History
              if (caseDetail.messages.isNotEmpty) ...[
                _buildMessagesSection(caseDetail),
                pw.SizedBox(height: 20),
              ],

              // Activity Timeline
              if (caseDetail.activityLogs.isNotEmpty) ...[
                _buildActivityTimeline(caseDetail),
              ],
            ],
        footer: (context) => _buildFooter(context),
      ),
    );

    return pdf.save();
  }

  /// Export filtered report list to PDF
  static Future<Uint8List> exportFilteredReports(
    List<Map<String, dynamic>> reports,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build:
            (context) => [
              // Header
              _buildHeader(),
              pw.SizedBox(height: 20),

              // Title
              pw.Text(
                'Report Analytics - Filtered Results',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Total Reports: ${reports.length}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),

              // Reports Table
              _buildReportsTable(reports),
            ],
        footer: (context) => _buildFooter(context),
      ),
    );

    return pdf.save();
  }

  /// Build PDF header with FCU branding
  static pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'FCU GUIDANCE MANAGEMENT SYSTEM',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: pw.BoxDecoration(
            color: PdfColors.red700,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'CONFIDENTIAL - FOR OFFICIAL USE ONLY',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  /// Build case information section
  static pw.Widget _buildCaseInfo(ReportModel report) {
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Case Code: ${report.trackingId ?? report.id.substring(0, 8).toUpperCase()}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: _getStatusColor(report.status),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  report.status.displayName,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Text(
                'Date Submitted: ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(dateFormat.format(report.createdAt)),
            ],
          ),
          if (report.incidentDate != null) ...[
            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                pw.Text(
                  'Incident Date: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(dateFormat.format(report.incidentDate!)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Build participants section
  static pw.Widget _buildParticipantsSection(CaseRecordDetailModel caseDetail) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PARTICIPANTS',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildParticipantCard(
                  'Student',
                  caseDetail.studentDisplayName,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildParticipantCard(
                  'Teacher',
                  caseDetail.teacherDisplayName,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildParticipantCard(
                  'Counselor',
                  caseDetail.counselorDisplayName,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildParticipantCard(
                  'Dean',
                  caseDetail.deanDisplayName,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildParticipantCard(String role, String name) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            role,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(name, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  /// Build case details section
  static pw.Widget _buildCaseDetails(ReportModel report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CASE DETAILS',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          pw.Row(
            children: [
              pw.Text(
                'Title: ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Expanded(child: pw.Text(report.title)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Text(
                'Type: ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(report.type),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Description:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(report.details, style: const pw.TextStyle(fontSize: 11)),
          if (report.teacherNote != null) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Teacher Note:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              report.teacherNote!,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
          if (report.counselorNote != null) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Counselor Note:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              report.counselorNote!,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
          if (report.deanNote != null) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Dean Note:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(report.deanNote!, style: const pw.TextStyle(fontSize: 11)),
          ],
        ],
      ),
    );
  }

  /// Build messages section
  static pw.Widget _buildMessagesSection(CaseRecordDetailModel caseDetail) {
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'MESSAGE HISTORY',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          ...caseDetail.messages.map((message) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        message.senderRole.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue700,
                        ),
                      ),
                      pw.Text(
                        dateFormat.format(message.createdAt),
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    message.message,
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Build activity timeline
  static pw.Widget _buildActivityTimeline(CaseRecordDetailModel caseDetail) {
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ACTIVITY TIMELINE',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          ...caseDetail.activityLogs.map((log) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 8,
                    height: 8,
                    margin: const pw.EdgeInsets.only(top: 4, right: 8),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue700,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              '${log.role.toUpperCase()} - ${log.action}',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              dateFormat.format(log.timestamp),
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ),
                        if (log.note != null) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            log.note!,
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Build reports table for filtered export
  static pw.Widget _buildReportsTable(List<Map<String, dynamic>> reports) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2), // Case Code
        1: const pw.FlexColumnWidth(1.5), // Title
        2: const pw.FlexColumnWidth(1), // Date
        3: const pw.FlexColumnWidth(1.5), // Status
        4: const pw.FlexColumnWidth(1.5), // Student
        5: const pw.FlexColumnWidth(1.5), // Teacher
        6: const pw.FlexColumnWidth(1.5), // Counselor
        7: const pw.FlexColumnWidth(1.5), // Dean
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell('Case Code', isHeader: true),
            _buildTableCell('Title', isHeader: true),
            _buildTableCell('Date', isHeader: true),
            _buildTableCell('Status', isHeader: true),
            _buildTableCell('Student', isHeader: true),
            _buildTableCell('Teacher', isHeader: true),
            _buildTableCell('Counselor', isHeader: true),
            _buildTableCell('Dean', isHeader: true),
          ],
        ),
        // Data rows
        ...reports.map((report) {
          final isAnonymous = report['is_anonymous'] as bool? ?? false;
          final student = report['student'] as Map<String, dynamic>?;
          final teacher = report['teacher'] as Map<String, dynamic>?;
          final counselor = report['counselor'] as Map<String, dynamic>?;
          final dean = report['dean'] as Map<String, dynamic>?;
          final createdAt = DateTime.parse(report['created_at'] as String);
          final status = ReportStatus.fromString(report['status'] as String);

          return pw.TableRow(
            children: [
              _buildTableCell(
                report['tracking_id'] as String? ??
                    report['id'].toString().substring(0, 8),
              ),
              _buildTableCell(report['title']?.toString() ?? 'N/A'),
              _buildTableCell(dateFormat.format(createdAt)),
              _buildTableCell(status.displayName),
              _buildTableCell(
                isAnonymous
                    ? 'Anonymous'
                    : (student?['full_name'] as String? ?? 'N/A'),
              ),
              _buildTableCell(
                teacher?['full_name'] as String? ?? 'Not Assigned',
              ),
              _buildTableCell(
                counselor?['full_name'] as String? ?? 'Not Assigned',
              ),
              _buildTableCell(dean?['full_name'] as String? ?? 'Not Assigned'),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Build footer with watermark and page number
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 16),
      child: pw.Column(
        children: [
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'FCU Guidance System - Confidential Document',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Get status color for PDF
  static PdfColor _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.submitted:
      case ReportStatus.pending:
        return PdfColors.orange700;
      case ReportStatus.teacherReviewed:
      case ReportStatus.forwarded:
      case ReportStatus.counselorReviewed:
      case ReportStatus.counselorConfirmed:
      case ReportStatus.approvedByDean:
        return PdfColors.blue700;
      case ReportStatus.counselingScheduled:
        return PdfColors.purple700;
      case ReportStatus.settled:
      case ReportStatus.completed:
        return PdfColors.green700;
    }
  }
}
