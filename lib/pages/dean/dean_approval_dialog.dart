import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../models/report_model.dart';
import '../../models/counseling_request_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/toast_utils.dart';

class DeanApprovalDialog extends StatefulWidget {
  final ReportModel report;

  const DeanApprovalDialog({super.key, required this.report});

  @override
  State<DeanApprovalDialog> createState() => _DeanApprovalDialogState();
}

class _DeanApprovalDialogState extends State<DeanApprovalDialog> {
  final _supabase = SupabaseService();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  bool _isApproving = false;

  CounselingRequestModel? _counselingRequest;
  final Map<String, String> _participantNames = {};
  bool _isLoadingParticipants = true;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    try {
      final request = await _supabase.getCounselingRequestByReportId(
        widget.report.id,
      );
      if (mounted) {
        setState(() => _counselingRequest = request);

        if (request?.participants != null) {
          for (final participant in request!.participants!) {
            if (participant['userId'] != null) {
              final user = await _supabase.getUserById(participant['userId']);
              if (user != null && mounted) {
                setState(() {
                  _participantNames[participant['userId']] = user.fullName;
                });
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading participants: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingParticipants = false);
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _approveReport() async {
    if (_isLoading) return;

    // Get authProvider before async gap
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final deanId = authProvider.currentUser?.id;

    if (deanId == null) {
      if (mounted) {
        ToastUtils.showError(context, 'Dean not authenticated');
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _isApproving = true;
    });

    try {
      await _supabase.approveReportByDean(
        reportId: widget.report.id,
        deanId: deanId,
        deanNote:
            _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isApproving = false;
      });
      ToastUtils.showError(context, 'Error approving report: $e');
    }
  }

  Future<void> _declineReport() async {
    if (_isLoading) return;

    // Get authProvider before async gap
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final deanId = authProvider.currentUser?.id;

    if (deanId == null) {
      if (mounted) {
        ToastUtils.showError(context, 'Dean not authenticated');
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Decline Report'),
            content: const Text(
              'Are you sure you want to decline this report? The student will be notified.',
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
                child: const Text('Decline'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _isApproving = false;
    });

    try {
      await _supabase.declineReportByDean(
        reportId: widget.report.id,
        deanId: deanId,
        deanNote:
            _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : 'Report declined by Dean',
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ToastUtils.showError(context, 'Error declining report: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Premium Gradient Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Approve for Counseling',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed:
                        _isLoading ? null : () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Report Summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGray,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.report.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.deepBlue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Type: ${widget.report.type}',
                              style: const TextStyle(
                                color: AppTheme.mediumBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.report.details.length > 150
                                  ? '${widget.report.details.substring(0, 150)}...'
                                  : widget.report.details,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Internal Notes (Dean can see)
                      if (widget.report.teacherNote != null ||
                          widget.report.counselorNote != null) ...[
                        const Text(
                          'Review Notes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (widget.report.teacherNote != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.successGreen.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Teacher Notes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.successGreen,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.report.teacherNote!,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (widget.report.counselorNote != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.warningOrange.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.warningOrange.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Counselor Notes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.warningOrange,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.report.counselorNote!,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],

                      // Participants Section (if any)
                      if (_isLoadingParticipants)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_counselingRequest?.participants != null &&
                          _counselingRequest!.participants!.isNotEmpty) ...[
                        const Text(
                          'Requested Participants',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.purple.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children:
                                _counselingRequest!.participants!.map((
                                  participant,
                                ) {
                                  String label =
                                      participant['role']?.toString() ??
                                      'Participant';
                                  String value;

                                  if (participant['userId'] != null) {
                                    value =
                                        _participantNames[participant['userId']] ??
                                        'Loading...';
                                  } else if (participant['name'] != null) {
                                    value = participant['name'];
                                  } else if (label.toLowerCase() == 'parent') {
                                    value = 'Invitation Requested';
                                    label = 'Parent/Guardian';
                                  } else {
                                    value = 'Unknown';
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$label: ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Colors.purple,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            value,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Dean Notes
                      const Text(
                        'Your Notes (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          hintText:
                              'Add internal notes about your decision (not visible to student)...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: _isLoading ? null : _declineReport,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.errorRed,
                              side: const BorderSide(color: AppTheme.errorRed),
                            ),
                            child: const Text('Decline'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _isLoading ? null : _approveReport,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.successGreen,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child:
                                _isLoading && _isApproving
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text('Approve for Counseling'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
