import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/report_model.dart';
import '../../models/report_activity_log_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/animations.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/responsive_sidebar.dart';
import '../../widgets/modern_dashboard_header.dart';

class ViewReportStatusPage extends StatefulWidget {
  const ViewReportStatusPage({super.key});

  @override
  State<ViewReportStatusPage> createState() => _ViewReportStatusPageState();
}

class _ViewReportStatusPageState extends State<ViewReportStatusPage> {
  final _supabase = SupabaseService();
  bool _isLoading = true;
  List<ReportModel> _reports = [];
  Map<String, List<ReportActivityLog>> _activityLogsMap = {};

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final studentId = authProvider.currentUser?.id;

      if (studentId != null) {
        final reports = await _supabase.getStudentReports(studentId);

        // Load activity logs for each report
        final logsMap = <String, List<ReportActivityLog>>{};
        for (final report in reports) {
          final logs = await _supabase.getReportActivityLogs(report.id);
          logsMap[report.id] = logs;
        }

        if (mounted) {
          setState(() {
            _reports = reports;
            _activityLogsMap = logsMap;
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

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.submitted:
      case ReportStatus.pending:
        return AppTheme.warningOrange;
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

  IconData _getStatusIcon(ReportStatus status) {
    switch (status) {
      case ReportStatus.submitted:
      case ReportStatus.pending:
        return Icons.send;
      case ReportStatus.teacherReviewed:
        return Icons.check_circle_outline;
      case ReportStatus.forwarded:
        return Icons.forward;
      case ReportStatus.counselorReviewed:
        return Icons.psychology;
      case ReportStatus.counselorConfirmed:
        return Icons.verified;
      case ReportStatus.approvedByDean:
        return Icons.verified_user;
      case ReportStatus.counselingScheduled:
        return Icons.calendar_today;
      case ReportStatus.settled:
      case ReportStatus.completed:
        return Icons.check_circle;
    }
  }

  Widget _buildStatusTimeline(ReportModel report) {
    final logs = _activityLogsMap[report.id] ?? [];

    final statuses = [
      ReportStatus.submitted,
      ReportStatus.teacherReviewed,
      ReportStatus.counselorReviewed,
      ReportStatus.approvedByDean,
      ReportStatus.counselingScheduled,
      ReportStatus.completed,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.lightGray.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children:
            statuses.asMap().entries.map((entry) {
              final index = entry.key;
              final status = entry.value;
              final isCompleted = _isStatusCompleted(report.status, status);
              final isCurrent = report.status == status;

              ReportActivityLog? log;
              try {
                log = logs.firstWhere(
                  (l) => l.action == status.toString().replaceAll('_', ''),
                  orElse:
                      () => logs.firstWhere(
                        (l) => _matchesStatus(l.action, status),
                        orElse: () => logs.isNotEmpty ? logs.last : logs.first,
                      ),
                );
              } catch (e) {
                log = logs.isNotEmpty ? logs.first : null;
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient:
                              isCompleted || isCurrent
                                  ? LinearGradient(
                                    colors: [
                                      _getStatusColor(status),
                                      _getStatusColor(
                                        status,
                                      ).withValues(alpha: 0.8),
                                    ],
                                  )
                                  : null,
                          color:
                              isCompleted || isCurrent
                                  ? null
                                  : AppTheme.lightGray,
                          border: Border.all(
                            color:
                                isCompleted || isCurrent
                                    ? _getStatusColor(status)
                                    : AppTheme.mediumGray.withValues(
                                      alpha: 0.3,
                                    ),
                            width: 2.5,
                          ),
                          boxShadow:
                              isCompleted || isCurrent
                                  ? [
                                    BoxShadow(
                                      color: _getStatusColor(
                                        status,
                                      ).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Icon(
                          _getStatusIcon(status),
                          size: 20,
                          color:
                              isCompleted || isCurrent
                                  ? Colors.white
                                  : AppTheme.mediumGray,
                        ),
                      ),
                      if (index < statuses.length - 1)
                        Container(
                          width: 3,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient:
                                isCompleted
                                    ? LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        _getStatusColor(status),
                                        _getStatusColor(
                                          status,
                                        ).withValues(alpha: 0.3),
                                      ],
                                    )
                                    : null,
                            color: isCompleted ? null : AppTheme.lightGray,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isCurrent || isCompleted
                                    ? _getStatusColor(
                                      status,
                                    ).withValues(alpha: 0.1)
                                    : AppTheme.lightGray.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color:
                                  isCurrent || isCompleted
                                      ? _getStatusColor(status)
                                      : AppTheme.mediumGray,
                            ),
                          ),
                        ),
                        if (log != null && log.note != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.lightBlue.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Text(
                              log.note!,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.darkGray,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                        if (log != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: AppTheme.mediumGray,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat(
                                  'MMM dd, yyyy • HH:mm',
                                ).format(log.timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (index < statuses.length - 1)
                          const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }

  bool _isStatusCompleted(ReportStatus current, ReportStatus check) {
    final order = [
      ReportStatus.submitted,
      ReportStatus.teacherReviewed,
      ReportStatus.forwarded,
      ReportStatus.counselorConfirmed,
      ReportStatus.settled,
    ];
    return order.indexOf(current) > order.indexOf(check);
  }

  bool _matchesStatus(String action, ReportStatus status) {
    final actionMap = {
      'submitted': ReportStatus.submitted,
      'reviewed': ReportStatus.teacherReviewed,
      'forwarded': ReportStatus.forwarded,
      'confirmed': ReportStatus.counselorConfirmed,
    };
    return actionMap[action] == status;
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

  void _showReportDetails(ReportModel report) {
    // Mark as read when opened
    if (mounted) {
      context.read<NotificationProvider>().markReportAsSeen(report.id);
    }

    final logs = _activityLogsMap[report.id] ?? [];

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
                        // Premium Header with ID Badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.deepBlue.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.description_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Report Details',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.deepBlue,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    'ID: ${report.id.substring(0, 8).toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.mediumGray,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.lightGray,
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 24),

                        _buildReportInfoSection(report),
                        const SizedBox(height: 32),
                        // Description Section
                        Row(
                          children: [
                            Icon(
                              Icons.notes_rounded,
                              color: AppTheme.skyBlue,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Detailed Description',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.deepBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.skyBlue.withValues(alpha: 0.1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
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

                        // Status Timeline
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppTheme.skyBlue,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Status Timeline',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.deepBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildStatusTimeline(report),

                        // Feedback/Comments
                        if (logs.any(
                          (log) => log.note != null && log.role != 'student',
                        )) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Feedback & Comments',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.deepBlue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...logs
                              .where(
                                (log) =>
                                    log.note != null && log.role != 'student',
                              )
                              .map(
                                (log) => Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        log.role == 'teacher'
                                            ? AppTheme.infoBlue.withValues(
                                              alpha: 0.1,
                                            )
                                            : AppTheme.successGreen.withValues(
                                              alpha: 0.1,
                                            ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          log.role == 'teacher'
                                              ? AppTheme.infoBlue.withValues(
                                                alpha: 0.3,
                                              )
                                              : AppTheme.successGreen
                                                  .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            log.role == 'teacher'
                                                ? Icons.person_outline
                                                : Icons.psychology_outlined,
                                            size: 16,
                                            color:
                                                log.role == 'teacher'
                                                    ? AppTheme.infoBlue
                                                    : AppTheme.successGreen,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            log.role.toUpperCase(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  log.role == 'teacher'
                                                      ? AppTheme.infoBlue
                                                      : AppTheme.successGreen,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            DateFormat(
                                              'MMM dd, yyyy HH:mm',
                                            ).format(log.timestamp),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.mediumGray,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        log.note!,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                        if (report.status == ReportStatus.approvedByDean) ...[
                          const SizedBox(height: 32),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.skyBlue.withValues(alpha: 0.1),
                                  AppTheme.infoBlue.withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.skyBlue.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Ready for Counseling',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.deepBlue,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Your report has been approved by the Dean. You can now request a counseling session to discuss this further.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      context.push(
                                        '/student/request-counseling',
                                      );
                                    },
                                    icon: const Icon(Icons.calendar_month),
                                    label: const Text(
                                      'Request Counseling Session',
                                    ),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      backgroundColor: AppTheme.skyBlue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildReportCard(ReportModel report, int index) {
    return Card(
      elevation: 4,
      shadowColor: _getStatusColor(report.status).withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showReportDetails(report),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  _getStatusColor(report.status).withValues(alpha: 0.02),
                ],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          report.status,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getStatusIcon(report.status),
                        color: _getStatusColor(report.status),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: AppTheme.darkGray,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGray,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  report.type,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.mediumGray,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    report.status,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _getStatusColor(
                                      report.status,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  report.status.displayName,
                                  style: TextStyle(
                                    color: _getStatusColor(report.status),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: AppTheme.lightGray, height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: AppTheme.mediumGray,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Submitted ${DateFormat('MMM dd, yyyy').format(report.createdAt)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppTheme.mediumGray,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).fadeInSlideUp(delay: Duration(milliseconds: index * 50));
  }

  Widget _buildReportInfoSection(ReportModel report) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.lightBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.lightBlue.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildDetailRowNew(Icons.title_rounded, 'Title', report.title),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _buildDetailRowNew(Icons.category_outlined, 'Category', report.type),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _buildDetailRowNew(
            Icons.info_outline_rounded,
            'Status',
            report.status.displayName,
            valueColor: _getStatusColor(report.status),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _buildDetailRowNew(
            Icons.access_time_rounded,
            'Submitted',
            DateFormat('MMM dd, yyyy • HH:mm').format(report.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowNew(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.mediumGray),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.mediumGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppTheme.deepBlue,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  // Placeholder if needed in future

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
              ModernDashboardHeader(
                title: 'View Report Status',
                subtitle: 'Track the progress and updates of your reports',
                icon: Icons.assignment_turned_in_rounded,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadReports,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              Expanded(
                child:
                    _isLoading
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.skyBlue,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading your reports...',
                                style: TextStyle(
                                  color: AppTheme.mediumGray,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                        : _reports.isEmpty
                        ? Center(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      color: AppTheme.skyBlue.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.inbox_outlined,
                                      size: 80,
                                      color: AppTheme.skyBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Text(
                                    'No Reports Yet',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.deepBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'You haven\'t submitted any reports yet.\nStart by submitting your first incident report.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: AppTheme.mediumGray,
                                      height: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppTheme.skyBlue,
                                          AppTheme.mediumBlue,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.skyBlue.withValues(
                                            alpha: 0.4,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap:
                                            () => context.go(
                                              '/student/submit-report',
                                            ),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 32,
                                            vertical: 16,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons
                                                    .add_circle_outline_rounded,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                              const SizedBox(width: 12),
                                              const Text(
                                                'Submit Your First Report',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        : CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              sliver: SliverToBoxAdapter(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.skyBlue.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.assignment_outlined,
                                        color: AppTheme.skyBlue,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'My Reports',
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.deepBlue,
                                            ),
                                          ),
                                          Text(
                                            '${_reports.length} ${_reports.length == 1 ? 'report' : 'reports'} submitted',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: AppTheme.mediumGray,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final report = _reports[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildReportCard(report, index),
                                  );
                                }, childCount: _reports.length),
                              ),
                            ),
                            const SliverPadding(
                              padding: EdgeInsets.only(bottom: 16),
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
