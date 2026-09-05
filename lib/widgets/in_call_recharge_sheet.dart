/// In-call recharge bottom sheet.
///
/// Shown when the caller's balance is running low during a 1-on-1 call.
/// Lets the user jump to the full RechargeScreen without leaving the call
/// permanently — on return, the caller's balance is refreshed from the
/// backend so the call can continue.
library in_call_recharge_sheet;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import 'currency_icon.dart';

/// Result returned by [InCallRechargeSheet.show].
///
/// [newBalance] is the caller's coin balance after the recharge flow
/// (refreshed from the backend), or `null` if the user dismissed the sheet
/// without recharging.
class InCallRechargeResult {
  InCallRechargeResult({this.newBalance});
  final int? newBalance;
}

class InCallRechargeSheet extends StatefulWidget {
  const InCallRechargeSheet({
    super.key,
    required this.currentBalance,
    required this.callRate,
    required this.remainingSeconds,
  });

  /// Caller's current coin balance (approximate, client-tracked).
  final int currentBalance;

  /// Per-minute call rate.
  final int callRate;

  /// Estimated remaining seconds at the current balance.
  final int remainingSeconds;

  /// Shows the in-call recharge sheet.
  ///
  /// Returns an [InCallRechargeResult] with the refreshed balance if the
  /// user recharged, or `null` if dismissed.
  static Future<InCallRechargeResult?> show(
    BuildContext context, {
    required int currentBalance,
    required int callRate,
    required int remainingSeconds,
  }) {
    return showModalBottomSheet<InCallRechargeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => InCallRechargeSheet(
        currentBalance: currentBalance,
        callRate: callRate,
        remainingSeconds: remainingSeconds,
      ),
    );
  }

  @override
  State<InCallRechargeSheet> createState() => _InCallRechargeSheetState();
}

class _InCallRechargeSheetState extends State<InCallRechargeSheet> {
  bool _recharging = false;

  Future<void> _openRecharge() async {
    if (_recharging) return;
    setState(() => _recharging = true);

    // Navigate to the full recharge screen.
    await context.pushNamed(AppRoutes.recharge);

    // On return, refresh the user's balance from the backend.
    if (!mounted) {
      return;
    }
    try {
      final auth = context.read<AuthProvider>();
      final user = await auth.refreshUser();
      final newBalance = (user?.coin ?? 0).toInt();
      if (mounted) {
        if (newBalance > widget.currentBalance) {
          Fluttertoast.showToast(msg: 'Recharge successful!');
        }
        Navigator.of(context).pop(InCallRechargeResult(newBalance: newBalance));
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(msg: 'Could not refresh balance. Please retry.');
        setState(() => _recharging = false);
      }
    }
  }

  String _fmtDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isCritical = widget.remainingSeconds <= 10;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
              // Warning icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isCritical ? Colors.red : Colors.amber).withValues(alpha: 0.15),
                ),
                child: Icon(
                  isCritical ? Icons.warning_amber_rounded : Icons.bolt,
                  color: isCritical ? Colors.red : Colors.amber,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isCritical ? 'Balance Running Out!' : 'Low Balance',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isCritical ? Colors.red : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your call will end in ${_fmtDuration(widget.remainingSeconds)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              // Balance + rate row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Balance',
                            style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const CurrencyIcon(CurrencyType.diamond, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.currentBalance}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppTheme.surfaceVariant,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Call Rate',
                              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const CurrencyIcon(CurrencyType.diamond, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  '${widget.callRate}/min',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Recharge button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _recharging ? null : _openRecharge,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _recharging
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.diamond_outlined, color: Colors.white),
                  label: Text(
                    _recharging ? 'Please wait...' : 'Recharge Now',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Dismiss
              TextButton(
                onPressed: _recharging ? null : () => Navigator.of(context).pop(),
                child: const Text(
                  'Not now',
                  style: TextStyle(color: AppTheme.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
