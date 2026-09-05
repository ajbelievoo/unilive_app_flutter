import 'package:flutter/material.dart';

import '../services/issue_report_service.dart';

/// Bigo/Chamet-style in-app "Report Issue" dialog.
///
/// Reports go to the backend `/api/v1/report-issue` endpoint which triggers
/// the Devin AI bug-fix pipeline. The network call is fire-and-forget so the
/// UI is never blocked and the dialog closes immediately with a thank-you
/// SnackBar even if the backend is unreachable.
class ReportIssueDialog extends StatefulWidget {
  final String? currentRoute;
  final String? userId;

  const ReportIssueDialog({super.key, this.currentRoute, this.userId});

  @override
  State<ReportIssueDialog> createState() => _ReportIssueDialogState();
}

class _ReportIssueDialogState extends State<ReportIssueDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() => _sending = true);

    await IssueReportService.reportIssue(
      title: title,
      description: _descriptionController.text.trim(),
      screenRoute: widget.currentRoute ?? '',
      userId: widget.userId,
    );

    if (mounted) {
      setState(() => _sending = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report sent. Thank you!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report Issue'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Issue title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'What happened?'),
              maxLines: 4,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }
}

void showReportIssueDialog(BuildContext context, {String? currentRoute, String? userId}) {
  showDialog(
    context: context,
    builder: (_) => ReportIssueDialog(currentRoute: currentRoute, userId: userId),
  );
}
