import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:archive/archive.dart';
import 'package:printing/printing.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  final _supabase = SupabaseService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _backupJobs = [];

  // Table Configuration
  final Map<String, String> _tableDisplayNames = {
    'reports': 'Student Reports',
    'anonymous_reports': 'Anonymous Reports',
    'case_messages': 'Messages & Conversations',
    'counseling_requests': 'Counseling Sessions',
    'report_activity_logs': 'Activity Logs',
    'users': 'User Profiles',
  };

  final Map<String, bool> _selectedTables = {
    'reports': true,
    'anonymous_reports': true,
    'case_messages': true,
    'counseling_requests': true,
    'report_activity_logs': true,
    'users': true,
  };

  @override
  void initState() {
    super.initState();
    _loadBackupJobs();
  }

  Future<void> _loadBackupJobs() async {
    setState(() => _isLoading = true);
    try {
      final jobs = await _supabase.getBackupJobs();
      if (mounted) {
        setState(() {
          _backupJobs = jobs;
        });
      }
    } catch (e) {
      debugPrint('Error loading backup jobs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performBackup() async {
    // 1. Validate Selection
    final tablesToBackup =
        _selectedTables.entries
            .where((e) => e.value)
            .map((e) => e.key)
            .toList();

    if (tablesToBackup.isEmpty) {
      ToastUtils.showWarning(
        context,
        'Please select at least one data type to backup.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Create Job
      final jobId = await _supabase.createBackupJob(
        backupType:
            tablesToBackup.length == _tableDisplayNames.length
                ? 'Full Backup'
                : 'Custom Selection',
        description: 'Manual backup of ${tablesToBackup.length} tables.',
      );

      // 3. Backup Each Table
      for (final tableName in tablesToBackup) {
        try {
          final data = await _supabase.getTableData(tableName);
          await _supabase.saveBackupRecords(
            jobId: jobId,
            tableName: tableName,
            records: data,
          );
        } catch (e) {
          debugPrint('Error backing up table $tableName: $e');
        }
      }

      if (mounted) {
        ToastUtils.showSuccess(context, 'Backup generated successfully.');
        await _loadBackupJobs(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Backup failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePdf(Map<String, dynamic> job) async {
    setState(() => _isLoading = true);
    try {
      final records = await _supabase.getBackupRecords(job['id']);
      final groupedData = _groupRecords(records);
      final theme = await _getUnicodeTheme();

      final pdf = pw.Document(theme: theme);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'Backup Summary Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(job['created_at']))}',
                ),
                pw.Text('Job ID: ${job['id']}'),
                pw.Text('Type: ${job['backup_type']}'),
                pw.Text('Description: ${job['description']}'),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Content Included:',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  context: context,
                  headers: ['Table Name', 'Records Count'],
                  data:
                      groupedData.entries
                          .map((e) => [e.key, e.value.length.toString()])
                          .toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                  cellHeight: 30,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerRight,
                  },
                ),
                pw.Spacer(),
                pw.Footer(
                  title: pw.Text(
                    'Generated by FCU Guidance System (Admin)',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey,
                    ),
                  ),
                  margin: const pw.EdgeInsets.only(top: 20),
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();

      if (kIsWeb) {
        await FilePicker.platform.saveFile(
          fileName:
              'backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.parse(job['created_at']))}.pdf',
          bytes: bytes,
        );
        if (mounted) {
          ToastUtils.showSuccess(context, 'Report downloaded successfully.');
        }
      } else {
        final String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Backup Report',
          fileName:
              'backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.parse(job['created_at']))}.pdf',
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);
          if (mounted) {
            ToastUtils.showSuccess(context, 'Report saved successfully.');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'PDF Generation failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, List<dynamic>> _groupRecords(List<Map<String, dynamic>> records) {
    final Map<String, List<dynamic>> grouped = {};
    for (final r in records) {
      final tableName = r['table_name'] as String;
      if (!grouped.containsKey(tableName)) grouped[tableName] = [];
      grouped[tableName]!.add(r['record_data']);
    }
    return grouped;
  }

  Future<void> _generateZip(Map<String, dynamic> job) async {
    setState(() => _isLoading = true);
    try {
      final records = await _supabase.getBackupRecords(job['id']);
      final groupedData = _groupRecords(records);

      final archive = Archive();
      final theme = await _getUnicodeTheme();

      for (final entry in groupedData.entries) {
        final tableName = entry.key;
        final tableRecords = entry.value;

        for (int i = 0; i < tableRecords.length; i++) {
          final recordData = tableRecords[i];
          final String recordId = recordData['id']?.toString() ?? 'rec_$i';

          final pdfBytes = await _createRecordPdf(tableName, recordData, theme);

          final archiveFile = ArchiveFile(
            '$tableName/${tableName}_$recordId.pdf',
            pdfBytes.length,
            pdfBytes,
          );
          archive.addFile(archiveFile);
        }
      }

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) throw Exception('Failed to encode ZIP');
      final uint8ZipBytes = Uint8List.fromList(zipBytes);

      final String fileName =
          'backup_full_${DateFormat('yyyyMMdd_HHmm').format(DateTime.parse(job['created_at']))}.zip';

      if (kIsWeb) {
        await FilePicker.platform.saveFile(
          fileName: fileName,
          bytes: uint8ZipBytes,
        );
        if (mounted) {
          ToastUtils.showSuccess(context, 'ZIP Archive downloaded.');
        }
      } else {
        final String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Backup ZIP',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(uint8ZipBytes);
          if (mounted) {
            ToastUtils.showSuccess(context, 'ZIP Saved successfully.');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'ZIP Generation failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<pw.ThemeData> _getUnicodeTheme() async {
    final font = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();
    return pw.ThemeData.withFont(base: font, bold: boldFont);
  }

  Future<Uint8List> _createRecordPdf(
    String tableName,
    Map<String, dynamic> data,
    pw.ThemeData theme,
  ) async {
    final pdf = pw.Document(theme: theme);
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Text('Record Export: $tableName')),
              pw.SizedBox(height: 10),
              pw.Text('Record ID: ${data['id'] ?? 'N/A'}'),
              pw.Divider(),
              pw.SizedBox(height: 10),
              // Filter out large JSON fields if necessary, or show as text
              ...data.entries
                  .take(20)
                  .map(
                    (e) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: '${e.key}: ',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.TextSpan(text: '${e.value}'),
                          ],
                        ),
                      ),
                    ),
                  ),
              if (data.length > 20) pw.Text('... and more fields'),
            ],
          );
        },
      ),
    );
    return await pdf.save();
  }

  Future<void> _performRestore(Map<String, dynamic> job) async {
    // Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Restore'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Restoring data may overwrite existing records. Do you want to continue?',
                ),
                const SizedBox(height: 12),
                Text(
                  'Backup Date: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(job['created_at']))}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Type: ${job['backup_type']}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.errorRed,
                ),
                child: const Text('Restore Data'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final records = await _supabase.getBackupRecords(job['id']);

      // Group by table to restore efficiently (though specific order might be needed for FKs)
      // MVP: Restore in specific order to avoid FK issues if possible?
      // Order: users -> reports -> others

      // Sort records based on table priority
      // Not easily done with flat list unless we process them carefully.
      // For MVP, if we use Upsert, foreign keys might still fail if parent is missing.
      // Simplest robust strategy: Restore Users, then Reports, etc.

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final r in records) {
        final tableName = r['table_name'] as String;
        if (!grouped.containsKey(tableName)) grouped[tableName] = [];
        grouped[tableName]!.add(r['record_data']);
      }

      // Priority Order
      final order = [
        'users',
        'reports',
        'anonymous_reports',
        'counseling_requests',
        'report_activity_logs',
        'case_messages',
      ];

      for (final table in order) {
        if (grouped.containsKey(table)) {
          for (final recordData in grouped[table]!) {
            await _supabase.restoreRecord(
              tableName: table,
              recordData: recordData,
            );
          }
        }
      }

      // Restore remaining tables not in order
      for (final table in grouped.keys) {
        if (!order.contains(table)) {
          for (final recordData in grouped[table]!) {
            await _supabase.restoreRecord(
              tableName: table,
              recordData: recordData,
            );
          }
        }
      }

      if (mounted) {
        ToastUtils.showSuccess(context, 'System restored successfully.');
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Restore failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                title: 'Backup & Restore',
                subtitle:
                    'Manage system safety with data backups and restoration tools',
                icon: Icons.settings_backup_restore_rounded,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 900) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildBackupPanel()),
                                const SizedBox(width: 24),
                                Expanded(flex: 3, child: _buildRestorePanel()),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                _buildBackupPanel(),
                                const SizedBox(height: 24),
                                _buildRestorePanel(),
                              ],
                            );
                          }
                        },
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

  Widget _buildBackupPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create New Backup',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.deepBlue,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Data to Backup',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          // Checkboxes
          ..._tableDisplayNames.keys.map((key) {
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_tableDisplayNames[key]!),
              value: _selectedTables[key],
              activeColor: AppTheme.skyBlue,
              onChanged:
                  _isLoading
                      ? null
                      : (val) {
                        setState(() {
                          _selectedTables[key] = val ?? false;
                        });
                      },
            );
          }),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _performBackup,
              icon:
                  _isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Icon(Icons.save_alt),
              label: Text(
                _isLoading ? 'Generating Backup...' : 'Generate Backup',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.skyBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestorePanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              const Text(
                'Backup History & Restore',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepBlue,
                ),
              ),
              IconButton(
                onPressed: _isLoading ? null : _loadBackupJobs,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_backupJobs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No backups found.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _backupJobs.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final job = _backupJobs[index];
                final date = DateTime.parse(job['created_at']).toLocal();
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.successGreen.withValues(
                      alpha: 0.1,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppTheme.successGreen,
                    ),
                  ),
                  title: Text(
                    DateFormat('MMM dd, yyyy - hh:mm a').format(date),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(job['description'] ?? 'No description'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          color: AppTheme.skyBlue,
                        ),
                        tooltip: 'PDF Summary',
                        onPressed: _isLoading ? null : () => _generatePdf(job),
                      ),
                      IconButton(
                        icon: const Icon(Icons.compress, color: Colors.purple),
                        tooltip: 'Export All as ZIP (PDFs)',
                        onPressed: _isLoading ? null : () => _generateZip(job),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed:
                            _isLoading ? null : () => _performRestore(job),
                        child: const Text('Restore'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
