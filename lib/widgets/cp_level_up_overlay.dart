/// CP/Friend level-up overlay — full-screen celebration when CP/Friend
/// bond levels up. Listens to socket streams from SocketHandlers.
library cp_level_up_overlay;

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

/// Overlay that listens to CP/Friend level-up socket events and shows
/// a brief celebration banner. Place once in the room Stack.
class CpLevelUpOverlay extends StatelessWidget {
  const CpLevelUpOverlay({
    super.key,
    this.cpLevelUpStream,
    this.friendLevelUpStream,
  });

  /// Stream of CP level-up events.
  final Stream<dynamic>? cpLevelUpStream;

  /// Stream of Friend level-up events.
  final Stream<dynamic>? friendLevelUpStream;

  @override
  Widget build(BuildContext context) {
    return _CpLevelUpOverlayBody(
      cpLevelUpStream: cpLevelUpStream,
      friendLevelUpStream: friendLevelUpStream,
    );
  }
}

class _CpLevelUpOverlayBody extends StatefulWidget {
  const _CpLevelUpOverlayBody({
    this.cpLevelUpStream,
    this.friendLevelUpStream,
  });

  final Stream<dynamic>? cpLevelUpStream;
  final Stream<dynamic>? friendLevelUpStream;

  @override
  State<_CpLevelUpOverlayBody> createState() => _CpLevelUpOverlayBodyState();
}

class _CpLevelUpOverlayBodyState extends State<_CpLevelUpOverlayBody>
    with SingleTickerProviderStateMixin {
  bool _show = false;
  String _text = '';
  StreamSubscription? _cpSub;
  StreamSubscription? _friendSub;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _cpSub = widget.cpLevelUpStream?.listen((data) {
      _showOverlay('CP Level Up!', data);
    });
    _friendSub = widget.friendLevelUpStream?.listen((data) {
      _showOverlay('Friend Level Up!', data);
    });
  }

  @override
  void dispose() {
    _cpSub?.cancel();
    _friendSub?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _showOverlay(String prefix, dynamic data) {
    if (!mounted) return;
    String level = '';
    if (data is Map) {
      level = '${data['level'] ?? data['newLevel'] ?? ''}';
    }
    setState(() {
      _show = true;
      _text = level.isNotEmpty ? '$prefix Lv.$level' : prefix;
    });
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _show = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.3,
      left: 0,
      right: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE84B8A), Color(0xFF6A5AE0)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE84B8A).withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.celebration, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    _text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
