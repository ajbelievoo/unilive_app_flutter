/// VIP Trial screen — free 1-day VIP preview.
///
/// Bigo-style trial — eligible users get a free 24-hour VIP preview
/// to try out VIP features before purchasing.
library vip_trial;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/vip_extended_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class VipTrialScreen extends StatefulWidget {
  const VipTrialScreen({super.key});

  @override
  State<VipTrialScreen> createState() => _VipTrialScreenState();
}

class _VipTrialScreenState extends State<VipTrialScreen> {
  static const String _tag = 'VipTrial';
  VipTrial? _trial;
  bool _loading = true;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = context.read<SessionManager>();
    setState(() => _loading = true);
    try {
      final res = await ApiService.getVipTrialStatus(session.userId);
      if (res.status && res.data != null) {
        _trial = res.data;
      }
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _activate() async {
    if (_activating) return;
    setState(() => _activating = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.activateVipTrial(session.userId);
      if (res.status) {
        Fluttertoast.showToast(msg: 'VIP Trial activated! Enjoy ${_trial?.trialDurationHours ?? 24} hours of VIP.');
        _load();
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Activation failed');
      }
    } catch (e, s) {
      Log.e(_tag, 'activate failed', e, s);
      Fluttertoast.showToast(msg: 'Activation failed');
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _loading
                    ? const Center(child: Preloader())
                    : _buildBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
          const Expanded(
            child: Center(
              child: Text('VIP Trial', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_trial == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_empty, color: Colors.white38, size: 64),
            const SizedBox(height: 16),
            const Text('Trial not available', style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final eligible = _trial!.eligible;
    final used = _trial!.trialUsed;
    final active = _trial!.trialActive;
    final hours = _trial!.trialDurationHours;
    final tierName = _trial!.trialTierName ?? 'VIP';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Hero
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 8))],
          ),
          child: Column(
            children: [
              const Icon(Icons.workspace_premium, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              const Text('Free VIP Trial', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('$hours hours of $tierName', style: const TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Benefits list
        const Text('Trial Benefits', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _benefit('VIP badge & frame', Icons.badge),
        _benefit('Exclusive entrance animation', Icons.directions_car),
        _benefit('Special name color', Icons.text_fields),
        _benefit('Hide online status', Icons.visibility_off),
        _benefit('Hide visit history', Icons.history),
        const SizedBox(height: 24),
        // Status / CTA
        if (active) ...[
          _buildActiveCard(),
        ] else if (used) ...[
          _buildUsedCard(),
        ] else if (eligible) ...[
          _buildEligibleCard(),
        ] else ...[
          _buildIneligibleCard(),
        ],
      ],
    );
  }

  Widget _benefit(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14))),
          const Icon(Icons.check_circle, color: Color(0xFF27AE60), size: 18),
        ],
      ),
    );
  }

  Widget _buildActiveCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF27AE60).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27AE60), width: 1),
      ),
      child: Column(
        children: [
          const Icon(Icons.play_circle, color: Color(0xFF27AE60), size: 40),
          const SizedBox(height: 12),
          const Text('Trial Active!', style: TextStyle(color: Color(0xFF27AE60), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (_trial!.trialExpiresAt != null)
            Text('Expires: ${_trial!.trialExpiresAt}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildUsedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.check_circle, color: Colors.white38, size: 40),
          SizedBox(height: 12),
          Text('Trial Already Used', style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('You can only use the free trial once', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEligibleCard() {
    return GestureDetector(
      onTap: _activating ? null : _activate,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.goldGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: _activating
            ? const Center(child: SizedBox(width: 24, height: 24, child: Preloader(strokeWidth: 2, color: Colors.white)))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text('Activate Free Trial', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }

  Widget _buildIneligibleCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.lock, color: Colors.white38, size: 40),
          SizedBox(height: 12),
          Text('Not Eligible', style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Purchase VIP to unlock trial benefits', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}
