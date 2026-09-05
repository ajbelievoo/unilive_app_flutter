/// Host compliance overlay — UI widgets for the on-device Host Presence
/// Guard (Bigo Live style).
///
/// Shows:
///  * A persistent red banner while a violation is in progress (with a
///    live countdown to the 180s declaration threshold).
///  * A prominent "Please return to camera" warning overlay at the 60s
///    threshold — before any penalty is applied.
///  * A ban-info toast/dialog when the 180s threshold is crossed and the
///    escalating ban is applied.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../models/host_compliance_models.dart';
import '../services/host_presence_guard_service.dart';

/// A red banner shown at the top of the host's live screen while a
/// presence violation is in progress.
///
/// Listens to [HostPresenceGuardService.statusStream] and rebuilds on every
/// status change. Hidden when the status is clear.
class HostComplianceBanner extends StatefulWidget {
  const HostComplianceBanner({super.key, required this.service});

  final HostPresenceGuardService service;

  @override
  State<HostComplianceBanner> createState() => _HostComplianceBannerState();
}

class _HostComplianceBannerState extends State<HostComplianceBanner> {
  HostPresenceStatus _status = HostPresenceStatus.clear;
  StreamSubscription<HostPresenceStatus>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.service.statusStream.listen((s) {
      if (!mounted) return;
      setState(() => _status = s);
      if (s.severity == HostPresenceSeverity.violation && s.ban != null) {
        _showBanToast(s.ban);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _reasonText(HostPresenceReason r) {
    switch (r) {
      case HostPresenceReason.cameraCovered:
        return 'Camera appears covered or black screen';
      case HostPresenceReason.cameraOff:
        return 'Camera is turned off';
      case HostPresenceReason.noFace:
        return 'Face not clearly visible';
      case HostPresenceReason.facePartial:
        return 'Face is partially covered or turned away';
      case HostPresenceReason.mask:
        return 'Face is masked or covered';
      case HostPresenceReason.none:
        return '';
    }
  }

  void _showBanToast(HostPresenceBanInfo? ban) {
    final rewardPenalty =
        ban?.tier == HostPresenceBanTier.second
            ? ' Today\'s task rewards and earnings are forfeited.'
            : '';
    final msg =
        ban == null
            ? 'Stream terminated due to a compliance violation.'
            : 'Stream terminated. Your ID is blocked from streaming for '
                '${_formatDuration(ban.banDurationMinutes)} '
                '(violation #${ban.dailyViolationCount} today).$rewardPenalty';
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      backgroundColor: Colors.red.shade900,
      textColor: Colors.white,
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0
        ? '$h hour${h == 1 ? '' : 's'}'
        : '$h hour${h == 1 ? '' : 's'} $m min';
  }

  @override
  Widget build(BuildContext context) {
    if (!_status.isViolating) return const SizedBox.shrink();
    final secondsLeft = _secondsToDeclaration(_status);
    return Positioned(
      top: MediaQuery.of(context).viewPadding.top + 8,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.shade900.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_reasonText(_status.reason)}. '
                  '${_severityLabel(_status.severity)} '
                  '(${secondsLeft}s remaining)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _severityLabel(HostPresenceSeverity s) {
    switch (s) {
      case HostPresenceSeverity.warning:
        return 'Please return to camera';
      case HostPresenceSeverity.violation:
        return 'Closing stream & applying ban...';
      case HostPresenceSeverity.clear:
        return '';
    }
  }

  /// Seconds remaining until the 180s declaration threshold.
  int _secondsToDeclaration(HostPresenceStatus s) {
    const term = 180;
    final left = term - s.violationSeconds;
    return left < 0 ? 0 : left;
  }
}
