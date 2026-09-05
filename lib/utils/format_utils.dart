// Number / date formatting helpers used across the app.

import '../models/setting_root.dart';

/// Beans received per diamond gift (admin panel `diamondToRcoin`).
/// Falls back to 1 when settings are unavailable (matches backend default).
int _diamondToRcoin(Setting? setting) => (setting?.diamondToRcoin ?? 0) > 0
    ? setting!.diamondToRcoin
    : 1;

/// Convert diamonds (gift coins) to beans using the backend `diamondToRcoin`
/// config from the admin panel. Used for host/seat earning displays so they
/// match what the backend actually credits to the receiver.
int diamondsToBeans(int diamonds, Setting? setting) =>
    diamonds * _diamondToRcoin(setting);

/// Format a count as its full value with thousands separators: 1234 -> "1,234".
String formatCountFull(int n) {
  return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );
}

/// Format a count compactly: 1234 -> "1.2K", 1000000 -> "1M".
String formatCount(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    final k = n / 1000;
    return k >= 100 ? '${k.round()}K' : '${k.toStringAsFixed(1)}K';
  }
  final m = n / 1000000;
  return m >= 100 ? '${m.round()}M' : '${m.toStringAsFixed(1)}M';
}

/// Format time ago: "2m ago", "1h ago", "3d ago".
String formatTimeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).round()}w ago';
  return '${(diff.inDays / 30).round()}mo ago';
}
