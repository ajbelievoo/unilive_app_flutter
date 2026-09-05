/// Live summary screen — post-stream statistics.
///
/// Ports native `LiveSummaryActivity.java`. Shown after a live stream ends.
/// Merges the backend summary response with client-side running counters
/// (tracked in the live/audio room) so the page does not show 0 when the
/// backend has not finished aggregating the stream.
library live_summary;

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../routes/app_routes.dart';
import '../../models/json_annotation_helper.dart';
import '../../models/level_summary_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../misc/video_player_screen.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'LiveSummary';

class LiveSummaryScreen extends StatefulWidget {
  const LiveSummaryScreen({
    super.key,
    required this.liveStreamingId,
    this.fallbackDurationSeconds = 0,
    this.liveType = 'audio',
    this.fallbackComments = 0,
    this.fallbackViewers = 0,
    this.fallbackGifts = 0,
    this.fallbackFans = 0,
    this.fallbackBeans = 0,
    this.fallbackEarnings,
  });

  final String liveStreamingId;
  final int fallbackDurationSeconds;
  final String liveType;
  final int fallbackComments;
  final int fallbackViewers;
  final int fallbackGifts;
  final int fallbackFans;
  final int fallbackBeans;
  final String? fallbackEarnings;

  @override
  State<LiveSummaryScreen> createState() => _LiveSummaryScreenState();
}

class _LiveSummaryScreenState extends State<LiveSummaryScreen> {
  LiveSummaryRoot? _summary;
  bool _loading = true;
  String? _hostEarnings;
  String? _recordingUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = context.read<SessionManager>();
    try {
      final res = await ApiService.getLiveSummary(widget.liveStreamingId);
      // Backend sometimes returns 0 for fields it has not yet aggregated.
      // Fall back to client-side running counters passed from the room.
      final duration = res.duration > 0 ? res.duration : widget.fallbackDurationSeconds;
      final comments = res.comments > 0 ? res.comments : widget.fallbackComments;
      final rCoin = res.rCoin > 0 ? res.rCoin : widget.fallbackBeans;
      final user = res.user > 0 ? res.user : widget.fallbackViewers;
      final gifts = res.gifts > 0 ? res.gifts : widget.fallbackGifts;
      final fans = res.fans > 0 ? res.fans : widget.fallbackFans;
      if (mounted) {
        setState(() => _summary = res.copyWith(
          duration: duration,
          comments: comments,
          rCoin: rCoin,
          user: user,
          gifts: gifts,
          fans: fans,
        ));
      }

      // Also fetch host earnings for this session (native: getHostApi).
      try {
        final hostRes = await ApiService.getHostApi(
          hostId: session.userId,
          liveType: widget.liveType,
          date: DateTime.now().toIso8601String().split('T')[0],
        );
        if (hostRes.status && mounted) {
          final payload = hostRes.data?['data'] as Map<String, dynamic>? ?? hostRes.data;
          final earnings = payload?['todayEarning'] ?? payload?['coin'] ?? payload?['todayCoin'];
          if (earnings != null) {
            final earningsStr = earnings.toString();
            if (earningsStr.isNotEmpty && parseInt(earningsStr, 0) > 0) {
              setState(() => _hostEarnings = earningsStr);
            }
          }
        }
      } catch (e) {
        Log.e(_tag, 'getHostApi failed', e);
      }

      // Use client-side earnings as fallback when the host API is empty.
      if ((_hostEarnings ?? '').isEmpty &&
          widget.fallbackEarnings != null &&
          widget.fallbackEarnings!.isNotEmpty) {
        setState(() => _hostEarnings = widget.fallbackEarnings);
      }

      // Fetch recording URL if the stream was recorded.
      try {
        final recRes = await ApiService.getLiveRecording(
          liveStreamingId: widget.liveStreamingId,
        );
        if (recRes.status && mounted) {
          final url = recRes.data?['recordingUrl']?.toString() ?? recRes.data?['url']?.toString();
          if (url != null && url.isNotEmpty) {
            setState(() => _recordingUrl = url);
          }
        }
      } catch (e) {
        Log.e(_tag, 'getLiveRecording failed', e);
      }
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionManager>();
    final userImage = session.getUser()?.image ?? '';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Host image as background.
          if (userImage.isNotEmpty)
            CachedNetworkImage(
              imageUrl: userImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorWidget: (_, __, ___) => Container(color: Colors.black),
            )
          else
            Container(color: Colors.black),
          // Blur + dark overlay for the glassy look.
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
              ),
            ),
          ),
          // Content.
          SafeArea(
            child: _loading
                ? const Center(child: Preloader(color: Colors.white))
                : _summary == null
                    ? _errorView()
                    : _content(),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white54, size: 48),
          const SizedBox(height: 12),
          const Text('Failed to load summary', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.goNamed(AppRoutes.main),
            child: const Text('Go Home'),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    final s = _summary!;
    final earnings = _hostEarnings ?? '0';

    return Column(
      children: [
        const SizedBox(height: 50),
        Text(
          'Live Summary',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 16),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your stream has ended',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const Spacer(),
        // Stats grid.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.95,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _statCard(Icons.access_time, _formatDuration(s.duration), 'Duration'),
              _statCard(Icons.comment, '${s.comments}', 'Comments'),
              _statCard(Icons.savings, '${s.rCoin}', 'Beans'),
              _statCard(Icons.people, '${s.user}', 'Viewers'),
              _statCard(Icons.card_giftcard, '${s.gifts}', 'Gifts'),
              _statCard(Icons.favorite, '${s.fans}', 'New Fans'),
              _statCard(Icons.account_balance_wallet, earnings, 'Earnings'),
            ],
          ),
        ),
        const Spacer(),
        // Recording replay button (if available).
        if (_recordingUrl != null && _recordingUrl!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: SizedBox(
              width: double.infinity,
              child: _glassButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(
                        url: _recordingUrl!,
                        title: 'Stream Replay',
                      ),
                    ),
                  );
                },
                icon: Icons.play_circle_outline,
                label: 'Watch Replay',
              ),
            ),
          ),
        // Home button.
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          child: SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: AppTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.55),
                    blurRadius: 24,
                    spreadRadius: -2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  // GoRouter does not pop to a route in the same way as
                  // Navigator, so we explicitly go to the main/home route.
                  context.goNamed(AppRoutes.main);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Go to Home Page',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.2),
            blurRadius: 12,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: Colors.white.withValues(alpha: 0.04),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(color: Colors.white.withValues(alpha: 0.25), blurRadius: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white),
            label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
            style: OutlinedButton.styleFrom(
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m < 60) return '${m}m ${s}s';
    final h = m ~/ 60;
    final rm = m % 60;
    return '${h}h ${rm}m';
  }
}
