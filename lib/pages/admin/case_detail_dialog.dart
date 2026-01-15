import 'package:flutter/material.dart';

// Placeholder for case detail dialog
// This will be fully implemented in the next phase
class CaseDetailDialog extends StatelessWidget {
  final String reportId;

  const CaseDetailDialog({super.key, required this.reportId});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Case Details'),
      content: Text('Case detail view for report: $reportId'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
