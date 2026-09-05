/// Live VIP expiry countdown timer widget.
///
/// Shows a ticking countdown ("12d 4h 23m 15s") that updates every second.
/// Bigo Live style — used on My VIP Store and VIP Settings screens.
library vip_countdown_timer;

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class VipCountdownTimer extends StatefulWidget {
  const VipCountdownTimer({
    super.key,
    required this.expiresAt,
    this.style,
    this.showSeconds = true,
    this.compact = false,
    this.onExpired,
  });

  /// ISO-8601 expiry date string.
  final String expiresAt;

  final TextStyle? style;
  final bool showSeconds;
  final bool compact;
  final VoidCallback? onExpired;

  @override
  State<VipCountdownTimer> createState() => _VipCountdownTimerState();
}

class _VipCountdownTimerState extends State<VipCountdownTimer> {
  Timer? _timer;
  Duration? _remaining;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  @override
  void didUpdateWidget(VipCountdownTimer old) {
    super.didUpdateWidget(old);
    if (old.expiresAt != widget.expiresAt) {
      _expired = false;
      _updateRemaining();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final expiry = DateTime.tryParse(widget.expiresAt);
    if (expiry == null) {
      setState(() => _remaining = null);
      return;
    }
    final now = DateTime.now();
    final diff = expiry.difference(now);
    if (diff.isNegative) {
      if (!_expired) {
        _expired = true;
        widget.onExpired?.call();
      }
      setState(() => _remaining = Duration.zero);
    } else {
      setState(() => _remaining = diff);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == null) {
      return Text('Expires: ${widget.expiresAt}', style: widget.style);
    }
    if (_remaining == Duration.zero) {
      return Text(
        'VIP Expired',
        style: widget.style?.copyWith(color: const Color(0xFFFF4444)) ??
            const TextStyle(color: Color(0xFFFF4444), fontSize: 13, fontWeight: FontWeight.bold),
      );
    }

    final d = _remaining!;
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    final isWarning = days <= 7;
    final color = isWarning ? const Color(0xFFFF6B6B) : (widget.style?.color ?? AppTheme.textSecondary);

    if (widget.compact) {
      final text = widget.showSeconds
          ? '${days}d ${hours}h ${minutes}m ${seconds}s'
          : '${days}d ${hours}h ${minutes}m';
      return Text(
        text,
        style: widget.style?.copyWith(color: color) ??
            TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 14, color: color),
        const SizedBox(width: 4),
        _unit(days, 'd', color),
        const SizedBox(width: 4),
        _unit(hours, 'h', color),
        const SizedBox(width: 4),
        _unit(minutes, 'm', color),
        if (widget.showSeconds) ...[
          const SizedBox(width: 4),
          _unit(seconds, 's', color),
        ],
      ],
    );
  }

  Widget _unit(int value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${value.toString().padLeft(2, '0')}$label',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
