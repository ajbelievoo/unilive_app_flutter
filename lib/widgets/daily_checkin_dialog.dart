/// Daily Check-in dialog — 7-day reward grid.
///
/// Shows automatically once per day on the home screen when a claim is
/// available (`DailyCheckIn.maybeShow`), and manually from Settings via
/// `DailyCheckIn.show(context)`.
library daily_checkin;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/checkin_root.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import '../theme/app_theme.dart';
import '../utils/log.dart';
import 'preloader.dart';

class DailyCheckIn {
  static const String _tag = 'DailyCheckIn';
  static const String _prefKey = 'checkin_prompted_date';

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Show the dialog once per local day if today's reward is claimable.
  static Future<void> maybeShow(BuildContext context) async {
    try {
      final userId = SessionManager.instance?.getUser()?.id ?? '';
      if (userId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_prefKey) == _today()) return;

      final status = await ApiService.getCheckInStatus(userId);
      if (!status.canClaim) return;

      await prefs.setString(_prefKey, _today());
      if (!context.mounted) return;
      await show(context, status: status);
    } catch (e, s) {
      Log.e(_tag, 'maybeShow failed', e, s);
    }
  }

  /// Fetch fresh status (unless provided) and show the dialog.
  static Future<void> show(BuildContext context, {CheckInStatus? status}) async {
    try {
      final userId = SessionManager.instance?.getUser()?.id ?? '';
      if (userId.isEmpty) {
        Fluttertoast.showToast(msg: 'Please login first');
        return;
      }
      status ??= await ApiService.getCheckInStatus(userId);
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (_) => _CheckInDialog(status: status!, userId: userId),
      );
    } catch (e, s) {
      Log.e(_tag, 'show failed', e, s);
      if (context.mounted) {
        Fluttertoast.showToast(msg: 'Could not load check-in');
      }
    }
  }
}

class _CheckInDialog extends StatefulWidget {
  final CheckInStatus status;
  final String userId;
  const _CheckInDialog({required this.status, required this.userId});

  @override
  State<_CheckInDialog> createState() => _CheckInDialogState();
}

class _CheckInDialogState extends State<_CheckInDialog> {
  late int _nextDay = widget.status.nextDay;
  late bool _canClaim = widget.status.canClaim;
  bool _claiming = false;

  Future<void> _claim() async {
    if (_claiming || !_canClaim) return;
    setState(() => _claiming = true);
    try {
      final res = await ApiService.claimCheckIn(widget.userId);
      if (!mounted) return;
      if (res.status) {
        setState(() {
          _canClaim = false;
          _nextDay = (res.day ?? _nextDay) + 1;
          _claiming = false;
        });
        final r = res.reward;
        if (r != null) {
          Fluttertoast.showToast(
            msg: '+${r.amount} ${r.type == 'coin' ? 'diamonds' : 'beans'} claimed!',
          );
        }
        // Refresh balances in the local session.
        context.read<AuthProvider>().refreshUser().catchError((_) => null);
      } else {
        setState(() => _claiming = false);
        Fluttertoast.showToast(msg: res.message ?? 'Claim failed');
      }
    } catch (e, s) {
      Log.e('DailyCheckIn', 'claim failed', e, s);
      if (mounted) {
        setState(() => _claiming = false);
        Fluttertoast.showToast(msg: 'Claim failed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rewards = widget.status.rewards;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.themed(context, 0xFF1C1C30, 0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ribbon title
            Transform.translate(
              offset: const Offset(0, -14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Daily Check In',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            // Reward grid — 4 per row.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
                itemCount: rewards.length,
                itemBuilder: (context, i) {
                  final r = rewards[i];
                  final claimed = r.day < _nextDay || !_canClaim;
                  return _DayCell(reward: r, claimed: claimed, isNext: r.day == _nextDay && _canClaim);
                },
              ),
            ),
            // Claim button
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _claiming
                  ? const Preloader()
                  : GestureDetector(
                      onTap: _canClaim ? _claim : () => Navigator.pop(context),
                      child: Container(
                        width: 200,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: AppTheme.brandGradient,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _canClaim ? 'Check-in' : 'See you tomorrow!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
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

class _DayCell extends StatelessWidget {
  final CheckInReward reward;
  final bool claimed;
  final bool isNext;
  const _DayCell({required this.reward, required this.claimed, required this.isNext});

  @override
  Widget build(BuildContext context) {
    final isDiamond = reward.type == 'coin';
    return Container(
      decoration: BoxDecoration(
        color: isNext
            ? AppTheme.primary.withValues(alpha: 0.15)
            : AppTheme.themed(context, 0xFF2A2A42, 0xFFF3F2FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNext ? AppTheme.primary : AppTheme.hairline(context),
          width: isNext ? 1.5 : 1,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Day ${reward.day}',
                  style: TextStyle(
                    color: AppTheme.fg(context, 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Icon(
                  isDiamond ? Icons.diamond : Icons.star_rounded,
                  size: 22,
                  color: isDiamond ? const Color(0xFF54C7FC) : const Color(0xFFFF5C8A),
                ),
                const SizedBox(height: 3),
                Text(
                  '+${reward.amount}',
                  style: TextStyle(
                    color: AppTheme.fg(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (claimed)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.themed(context, 0xB31C1C30, 0xB3FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.check_circle, color: AppTheme.green, size: 26),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
