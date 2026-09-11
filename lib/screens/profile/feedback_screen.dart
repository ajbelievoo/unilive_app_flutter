/// Feedback screen â€” submit and view user feedback/complaints.
///
/// Ports native `FeedbackActivity.java`.
library feedback;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../models/leaderboard_complain_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'Feedback';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _messageCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _items = <ComplainItem>[];
  String _category = 'App Problems';
  bool _sending = false;
  bool _loading = true;

  final _categories = ['App Problems', 'Suggestions', 'Recharge', 'Others'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.getComplaints(session.userId);
      if (mounted) setState(() => _items.addAll(res.complain));
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final msg = _messageCtrl.text.trim();
    if (msg.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter a message');
      return;
    }
    setState(() => _sending = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.createComplaint(
        userId: session.userId,
        contactDetails: _contactCtrl.text.trim(),
        issue: msg,
        category: _category,
      );
      if (res.status) {
        Fluttertoast.showToast(msg: 'Feedback submitted');
        _messageCtrl.clear();
        _contactCtrl.clear();
        _load();
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to submit');
      }
    } catch (e, s) {
      Log.e(_tag, 'submit failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to submit');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Category chips
          Wrap(
            spacing: 8,
            children: _categories.map((c) {
              final selected = _category == c;
              return ChoiceChip(
                label: Text(c),
                selected: selected,
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(color: selected ? Colors.white : (isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary)),
                onSelected: (_) => setState(() => _category = c),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageCtrl,
            maxLines: 4,
            style: TextStyle(color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary),
            decoration: InputDecoration(
              labelText: 'Message',
              hintText: 'Describe your issue or suggestion...',
              filled: true,
              fillColor: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactCtrl,
            style: TextStyle(color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary),
            decoration: InputDecoration(
              labelText: 'Contact (email/mobile/username)',
              filled: true,
              fillColor: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _sending ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _sending
                ? const SizedBox(height: 20, width: 20, child: Preloader(strokeWidth: 2, color: Colors.white))
                : const Text('Submit Feedback'),
          ),
          const SizedBox(height: 24),
          Text(
            'History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: Preloader())
          else if (_items.isEmpty)
            Center(
              child: Text('No feedback yet', style: TextStyle(color: isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary)),
            )
          else
            ..._items.map((item) => _historyCard(isDark, item)),
        ],
      ),
    );
  }

  Widget _historyCard(bool isDark, ComplainItem item) {
    return Card(
      color: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(6)),
                  child: const Text(
                    'Feedback',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(item.createdAt),
                  style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.message ?? '',
              style: TextStyle(color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final dt = DateTime.parse(date);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return date;
    }
  }
}

