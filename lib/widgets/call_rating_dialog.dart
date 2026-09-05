import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../providers/call_config_provider.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import '../theme/app_theme.dart';
import '../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

/// Post-call rating dialog. Shown after a call ends so the caller can
/// rate the host with stars and optional feedback, call them again, or
/// follow them.
class CallRatingDialog extends StatefulWidget {
  final String hostName;
  final String? hostImage;
  final String hostId;
  final String callRoomId;
  final VoidCallback? onCallAgain;

  const CallRatingDialog({
    super.key,
    required this.hostName,
    this.hostImage,
    required this.hostId,
    required this.callRoomId,
    this.onCallAgain,
  });

  /// Shows the rating dialog as a bottom sheet.
  /// Returns the rating (1-5) or null if dismissed.
  static Future<int?> show(
    BuildContext context, {
    required String hostName,
    String? hostImage,
    required String hostId,
    required String callRoomId,
    VoidCallback? onCallAgain,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CallRatingDialog(
        hostName: hostName,
        hostImage: hostImage,
        hostId: hostId,
        callRoomId: callRoomId,
        onCallAgain: onCallAgain,
      ),
    );
  }

  @override
  State<CallRatingDialog> createState() => _CallRatingDialogState();
}

class _CallRatingDialogState extends State<CallRatingDialog> {
  int _rating = 0;
  final _tags = <String>[];
  bool _submitting = false;
  bool _following = false;
  bool _isFollowing = false;
  bool _followChecked = false;
  final _reviewCtrl = TextEditingController();

  static const _allTags = [
    'Good conversation',
    'Beautiful',
    'Polite',
    'Boring',
    'Rude',
    'Audio issues',
  ];

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkFollowStatus() async {
    if (widget.hostId.isEmpty) return;
    try {
      final session = context.read<SessionManager>();
      final following = await ApiService.checkFollowStatus(session.userId, widget.hostId);
      if (mounted) {
        setState(() {
          _isFollowing = following;
          _followChecked = true;
        });
      }
    } catch (e) {
      Log.e('CallRating', 'checkFollow failed', e);
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_tags.contains(tag)) {
        _tags.remove(tag);
      } else {
        _tags.add(tag);
      }
    });
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating'), duration: Duration(seconds: 1)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final session = context.read<SessionManager>();
      // Combine tags + free-text review.
      final parts = <String>[];
      if (_tags.isNotEmpty) parts.add(_tags.join(', '));
      final text = _reviewCtrl.text.trim();
      if (text.isNotEmpty) parts.add(text);
      final review = parts.isNotEmpty ? parts.join(' — ') : null;
      await ApiService.submitHostRating(
        userId: session.userId,
        hostId: widget.hostId,
        rating: _rating,
        review: review,
      );
      if (mounted) {
        Fluttertoast.showToast(msg: 'Thank you for your rating!');
        Navigator.of(context).pop(_rating);
      }
    } catch (e, s) {
      Log.e('CallRating', 'submit failed', e, s);
      if (mounted) {
        Fluttertoast.showToast(msg: 'Failed to submit rating');
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_following) return;
    setState(() => _following = true);
    try {
      final session = context.read<SessionManager>();
      await ApiService.followUnfollow({
        'userId': session.userId,
        'otherUserId': widget.hostId,
      });
      if (mounted) {
        setState(() => _isFollowing = !_isFollowing);
        Fluttertoast.showToast(
          msg: _isFollowing ? 'Following ${widget.hostName}' : 'Unfollowed',
        );
      }
    } catch (e) {
      Log.e('CallRating', 'follow failed', e);
      if (mounted) Fluttertoast.showToast(msg: 'Failed');
    } finally {
      if (mounted) setState(() => _following = false);
    }
  }

  void _callAgain() {
    Navigator.of(context).pop();
    widget.onCallAgain?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 32,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Host avatar
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.brandGradient,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: widget.hostImage != null && widget.hostImage!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.hostImage!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.primary,
                            child: const Icon(Icons.person, color: Colors.white),
                          ),
                        )
                      : Container(
                          color: AppTheme.primary,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Rate ${widget.hostName}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'How was your call experience?',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starIndex = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = starIndex),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      starIndex <= _rating ? Icons.star : Icons.star_border,
                      size: 40,
                      color: starIndex <= _rating ? const Color(0xFFFFB800) : AppTheme.surfaceVariant,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            // Tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _allTags.map((tag) {
                final selected = _tags.contains(tag);
                return GestureDetector(
                  onTap: () => _toggleTag(tag),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppTheme.primary : AppTheme.surfaceVariant,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 13,
                        color: selected ? AppTheme.primary : AppTheme.textSecondary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Free-text review
            TextField(
              controller: _reviewCtrl,
              maxLines: 3,
              maxLength: context.watch<CallConfigProvider>().reviewMaxChars,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Write a review (optional)...',
                hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 14),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.surfaceVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Submit button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Preloader(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Submit Rating', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            // Call-again + Follow row
            Row(
              children: [
                if (widget.onCallAgain != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _callAgain,
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('Call Again'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (widget.onCallAgain != null) const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _following || !_followChecked ? null : _toggleFollow,
                    icon: _following
                        ? const SizedBox(width: 16, height: 16, child: Preloader(strokeWidth: 2))
                        : Icon(_isFollowing ? Icons.check : Icons.person_add_alt_1, size: 18),
                    label: Text(_isFollowing ? 'Following' : 'Follow'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _isFollowing ? AppTheme.textTertiary : AppTheme.primary,
                      side: BorderSide(
                        color: _isFollowing ? AppTheme.surfaceVariant : AppTheme.primary,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Skip
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Skip',
                style: TextStyle(color: AppTheme.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
