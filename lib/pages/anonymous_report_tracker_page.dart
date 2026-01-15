import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import '../widgets/sticky_navigation_bar.dart';
import '../services/supabase_service.dart';
import '../models/report_model.dart';

class AnonymousReportTrackerPage extends StatefulWidget {
  const AnonymousReportTrackerPage({super.key});

  @override
  State<AnonymousReportTrackerPage> createState() =>
      _AnonymousReportTrackerPageState();
}

class _AnonymousReportTrackerPageState
    extends State<AnonymousReportTrackerPage> {
  final _formKey = GlobalKey<FormState>();
  final _trackingIdController = TextEditingController();
  final _supabase = SupabaseService();

  ReportModel? _report;
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _trackingIdController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _report = null;
    });

    try {
      final caseCode = _trackingIdController.text.trim().toUpperCase();
      final reportData = await _supabase.getAnonymousReportByCaseCode(caseCode);

      if (mounted) {
        if (reportData != null) {
          // Map the anonymous report data to the ReportModel
          final statusString = reportData['status'] as String? ?? 'pending';
          final reportId = reportData['id'] as String;

          // Check for counselor involvement
          final roles = await _supabase.getAnonymousReportRecipientRoles(
            reportId,
          );
          final hasCounselor = roles.contains('counselor');

          ReportStatus status;
          switch (statusString) {
            case 'pending':
              status = ReportStatus.pending;
              break;
            case 'ongoing':
              status =
                  hasCounselor
                      ? ReportStatus.counselorReviewed
                      : ReportStatus.teacherReviewed;
              break;
            case 'resolved':
              status = ReportStatus.settled;
              break;
            default:
              status = ReportStatus.pending;
          }

          setState(() {
            _report = ReportModel(
              id: reportData['id'] as String,
              title: reportData['category'] as String? ?? 'Anonymous Report',
              type: reportData['category'] as String? ?? 'Other',
              details:
                  reportData['description'] as String? ??
                  'No details provided.',
              status: status,
              isAnonymous: true,
              trackingId: reportData['case_code'] as String?,
              createdAt: DateTime.parse(reportData['created_at'] as String),
              updatedAt: DateTime.parse(reportData['updated_at'] as String),
            );
            _isLoading = false;
          });
        } else {
          setState(() {
            _report = null;
            _isLoading = false;
          });
          ToastUtils.showWarning(
            context,
            'No report found with this Case Code. Please check and try again.',
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastUtils.showError(
          context,
          'Error checking status: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
      case ReportStatus.submitted:
        return AppTheme.warningOrange;
      case ReportStatus.teacherReviewed:
      case ReportStatus.forwarded:
        return AppTheme.infoBlue;
      case ReportStatus.counselorReviewed:
        return AppTheme.warningOrange;
      case ReportStatus.counselorConfirmed:
        return AppTheme.successGreen;
      case ReportStatus.approvedByDean:
        return AppTheme.successGreen;
      case ReportStatus.counselingScheduled:
        return AppTheme.skyBlue;
      case ReportStatus.settled:
      case ReportStatus.completed:
        return AppTheme.mediumGray;
    }
  }

  IconData _getStatusIcon(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
      case ReportStatus.submitted:
        return Icons.pending;
      case ReportStatus.teacherReviewed:
        return Icons.visibility;
      case ReportStatus.forwarded:
        return Icons.forward;
      case ReportStatus.counselorReviewed:
        return Icons.psychology;
      case ReportStatus.counselorConfirmed:
        return Icons.check_circle;
      case ReportStatus.approvedByDean:
        return Icons.verified;
      case ReportStatus.counselingScheduled:
        return Icons.calendar_today;
      case ReportStatus.settled:
      case ReportStatus.completed:
        return Icons.done_all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      body: StickyNavigationBar(
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 32,
              vertical: 32,
            ),
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Section with Gradient Background
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.skyBlue.withValues(alpha: 0.1),
                          AppTheme.paleBlue.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.skyBlue.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Check Report Status',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.deepBlue,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Enter your Tracking ID to view the current status of your report',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppTheme.darkGray,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Tracker Card
                  Container(
                    padding: EdgeInsets.all(isMobile ? 24 : 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.deepBlue.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tracking ID Input
                        TextFormField(
                          controller: _trackingIdController,
                          decoration: InputDecoration(
                            labelText: 'Tracking ID',
                            hintText: 'e.g. FCU-AR-2025-00123',
                            prefixIcon: const Icon(
                              Icons.track_changes_outlined,
                              color: AppTheme.mediumGray,
                            ),
                            suffixIcon:
                                _trackingIdController.text.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        color: AppTheme.mediumGray,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _trackingIdController.clear();
                                          _report = null;
                                          _hasSearched = false;
                                        });
                                      },
                                    )
                                    : null,
                            filled: true,
                            fillColor: AppTheme.lightGray.withValues(
                              alpha: 0.3,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your Tracking ID';
                            }
                            if (!value.toUpperCase().startsWith('AR-')) {
                              return 'Tracking ID must start with AR-';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {});
                          },
                        ),

                        const SizedBox(height: 24),

                        // Check Status Button with Gradient
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.skyBlue, AppTheme.mediumBlue],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.skyBlue.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _checkStatus,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child:
                                _isLoading
                                    ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Checking…',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                    : const Text(
                                      'Check Status',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  // Report Status Display
                  if (_isLoading)
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.deepBlue.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Checking status...',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.mediumGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_hasSearched && _report == null)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.warningOrange.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.deepBlue.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.warningOrange.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: AppTheme.warningOrange,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Report Not Found',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkGray,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No report found with this Tracking ID. Please verify and try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.mediumGray,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_report != null)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.deepBlue.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 24 : 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status Header
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _getStatusColor(
                                      _report!.status,
                                    ).withValues(alpha: 0.1),
                                    _getStatusColor(
                                      _report!.status,
                                    ).withValues(alpha: 0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _getStatusColor(
                                    _report!.status,
                                  ).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        _report!.status,
                                      ).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _getStatusIcon(_report!.status),
                                      color: _getStatusColor(_report!.status),
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _report!.status.displayName,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.darkGray,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.fingerprint_outlined,
                                              size: 16,
                                              color: AppTheme.mediumGray,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Tracking ID: ${_report!.trackingId}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AppTheme.mediumGray,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.copy_rounded,
                                                size: 18,
                                              ),
                                              color: AppTheme.skyBlue,
                                              onPressed: () async {
                                                final trackingId =
                                                    _report!.trackingId ?? '';
                                                await Clipboard.setData(
                                                  ClipboardData(
                                                    text: trackingId,
                                                  ),
                                                );
                                                if (!mounted) return;
                                                ToastUtils.showSuccess(
                                                  this.context,
                                                  'Tracking ID copied to clipboard',
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),
                            const Divider(height: 1),
                            const SizedBox(height: 28),

                            // Report Details
                            _buildInfoRow(
                              'Title',
                              _report!.title,
                              Icons.title_outlined,
                            ),
                            const SizedBox(height: 18),
                            _buildInfoRow(
                              'Type',
                              _report!.type,
                              Icons.category_outlined,
                            ),
                            const SizedBox(height: 18),
                            _buildInfoRow(
                              'Submitted',
                              _formatDate(_report!.createdAt),
                              Icons.calendar_today_outlined,
                            ),
                            const SizedBox(height: 18),
                            _buildInfoRow(
                              'Last Updated',
                              _formatDate(_report!.updatedAt),
                              Icons.update_outlined,
                            ),

                            const SizedBox(height: 28),
                            const Divider(height: 1),
                            const SizedBox(height: 20),

                            // Details Section
                            const Text(
                              'Report Details',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkGray,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppTheme.lightGray.withValues(
                                  alpha: 0.5,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppTheme.lightGray,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _report!.details,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.darkGray,
                                  height: 1.6,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Privacy Reminder
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.paleBlue.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.skyBlue.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    color: AppTheme.skyBlue,
                                    size: 18,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Only this Tracking ID can access this report.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.darkGray,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.lightGray.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppTheme.mediumGray),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mediumGray,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.darkGray,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
