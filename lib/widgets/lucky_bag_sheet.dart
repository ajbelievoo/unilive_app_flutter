import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

/// Lucky bag (red packet) bottom sheet for audio rooms.
///
/// Host can create a bag by setting total coins and winner count.
/// Viewers can claim the active bag.
class LuckyBagSheet extends StatefulWidget {
  const LuckyBagSheet({
    super.key,
    required this.roomId,
    required this.userId,
    required this.isHost,
  });

  final String roomId;
  final String userId;
  final bool isHost;

  static Future<void> show(
    BuildContext context, {
    required String roomId,
    required String userId,
    required bool isHost,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LuckyBagSheet(
        roomId: roomId,
        userId: userId,
        isHost: isHost,
      ),
    );
  }

  @override
  State<LuckyBagSheet> createState() => _LuckyBagSheetState();
}

class _LuckyBagSheetState extends State<LuckyBagSheet> {
  static const String _tag = 'LuckyBagSheet';

  final _totalCoinsCtrl = TextEditingController();
  final _winnerCountCtrl = TextEditingController();
  bool _loading = false;
  String? _result;

  @override
  void dispose() {
    _totalCoinsCtrl.dispose();
    _winnerCountCtrl.dispose();
    super.dispose();
  }

  Future<void> _createBag() async {
    final totalCoins = int.tryParse(_totalCoinsCtrl.text.trim()) ?? 0;
    final winnerCount = int.tryParse(_winnerCountCtrl.text.trim()) ?? 0;

    if (totalCoins <= 0) {
      Fluttertoast.showToast(msg: 'Enter a valid diamond amount');
      return;
    }
    if (winnerCount <= 0) {
      Fluttertoast.showToast(msg: 'Enter a valid winner count');
      return;
    }
    if (winnerCount > totalCoins) {
      Fluttertoast.showToast(msg: 'Winners cannot be more than total diamonds');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await ApiService.createLuckyBag(
        roomId: widget.roomId,
        userId: widget.userId,
        totalCoins: totalCoins,
        winnerCount: winnerCount,
      );
      if (res.status) {
        if (mounted) {
          setState(() => _result = 'Lucky bag created!\nTotal: $totalCoins diamonds | Winners: $winnerCount');
        }
        Fluttertoast.showToast(msg: 'Lucky bag created');
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to create lucky bag');
      }
    } catch (e, s) {
      Log.e(_tag, 'createLuckyBag failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to create lucky bag');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claimBag() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.claimLuckyBag(
        roomId: widget.roomId,
        userId: widget.userId,
      );
      if (res.status) {
        final coins = res.data?['coin'] ?? res.data?['coins'] ?? res.message;
        if (mounted) {
          setState(() => _result = coins != null ? 'You won $coins diamonds!' : 'Claimed successfully');
        }
        Fluttertoast.showToast(msg: 'Lucky bag claimed');
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'No lucky bag available');
      }
    } catch (e, s) {
      Log.e(_tag, 'claimLuckyBag failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to claim lucky bag');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Colors.red, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isHost ? 'Create Lucky Bag' : 'Claim Lucky Bag',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.isHost
                            ? 'Set total diamonds and number of winners'
                            : 'Tap claim to grab a share from the active lucky bag',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.isHost) ...[
              TextField(
                controller: _totalCoinsCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Total Diamonds',
                  hintText: 'e.g. 1000',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _winnerCountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Number of Winners',
                  hintText: 'e.g. 10',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7E3FF2).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _result!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : (widget.isHost ? _createBag : _claimBag),
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: Preloader(strokeWidth: 2, color: Colors.white))
                  : Icon(widget.isHost ? Icons.add_box : Icons.celebration, color: Colors.white),
              label: Text(widget.isHost ? 'Create Lucky Bag' : 'Claim Now'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: const Color(0xFF7E3FF2),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
