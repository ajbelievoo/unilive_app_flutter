import 'dart:async';

import 'package:flutter/material.dart';

import '../routes/navigation_keys.dart';
import '../services/session_manager.dart';
import '../services/socket_handlers.dart';
import '../utils/log.dart';
import 'svga_player_widget.dart';

/// Global overlay that plays the CP couple animations delivered by socket
/// payloads (`animation.svga` / `animation.image`):
///
///  - `cpRequest`       → invite dialog asset (recipient only)
///  - `cpRequestUpdate` → bind-success asset (both partners, on "accepted")
///  - `cpGlobalNotify`  → global-notify marquee (everyone)
///  - `cpLevelUp`       → full celebration asset (both partners)
///
/// Wrap the app's top-level widget with this so the overlays work on any
/// screen. Each animation plays once and auto-dismisses; tapping dismisses.
class CpEffectsOverlay extends StatefulWidget {
  final Widget child;

  const CpEffectsOverlay({super.key, required this.child});

  @override
  State<CpEffectsOverlay> createState() => _CpEffectsOverlayState();
}

class _CpEffectsOverlayState extends State<CpEffectsOverlay> {
  final _subs = <StreamSubscription>[];
  OverlayEntry? _entry;
  Timer? _dismissTimer;
  String? _lastKey;
  DateTime? _lastAt;

  @override
  void initState() {
    super.initState();
    final s = SocketHandlers.instance;
    _subs.add(s.cpRequestStream.listen(_onCpRequest));
    _subs.add(s.cpUpdateStream.listen(_onCpUpdate));
    _subs.add(s.cpGlobalNotifyStream.listen(_onCpGlobalNotify));
    _subs.add(s.cpLevelUpStream.listen(_onCpLevelUp));
  }

  String get _myId => SessionManager.instance?.userId ?? '';

  bool _involvesMe(Map<String, dynamic> d) {
    final me = _myId;
    if (me.isEmpty) return false;
    String idOf(dynamic v) {
      if (v is Map) return (v['_id'] ?? v['id'] ?? '').toString();
      return (v ?? '').toString();
    }
    for (final k in const ['user1', 'user2', 'fromUser', 'toUser', 'fromUserId', 'toUserId']) {
      if (idOf(d[k]) == me) return true;
    }
    return false;
  }

  String? _svgaOf(Map<String, dynamic> d) {
    final anim = d['animation'];
    if (anim is Map) {
      final svga = anim['svga'];
      if (svga is String && svga.isNotEmpty) return svga;
    }
    if (anim is String && anim.isNotEmpty) return anim;
    return null;
  }

  bool _throttled(String key) {
    final now = DateTime.now();
    if (key == _lastKey &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 3)) {
      return true;
    }
    _lastKey = key;
    _lastAt = now;
    return false;
  }

  void _onCpRequest(Map<String, dynamic> d) {
    // Invite dialog asset shows only to the request recipient.
    final toUser = d['toUser'];
    final toId = toUser is Map
        ? (toUser['_id'] ?? toUser['id'] ?? '').toString()
        : (d['toUserId'] ?? '').toString();
    if (toId.isEmpty || toId != _myId) return;
    final svga = _svgaOf(d);
    if (svga == null || _throttled('req:$toId')) return;
    _play(svga);
  }

  void _onCpUpdate(Map<String, dynamic> d) {
    if (d['status'] != 'accepted') return;
    if (!_involvesMe(d)) return;
    final svga = _svgaOf(d);
    if (svga == null || _throttled('bind:${d['cpId']}')) return;
    _play(svga);
  }

  void _onCpGlobalNotify(Map<String, dynamic> d) {
    // Global couple announcement — play for everyone except the couple
    // (they already see the bind-success animation).
    if (_involvesMe(d)) return;
    final svga = _svgaOf(d);
    if (svga == null || _throttled('global:${d['cpId']}')) return;
    _play(svga, heightFactor: 0.5);
  }

  void _onCpLevelUp(Map<String, dynamic> d) {
    // cpLevelUp arrives as a global emit — the payload only carries cpId, so
    // show it to everyone (mirrors how other level-up announcements behave).
    final svga = _svgaOf(d);
    if (svga == null || _throttled('lvup:${d['cpId']}:${d['level']}')) return;
    _play(svga);
  }

  void _play(String svgaUrl, {double heightFactor = 0.75}) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      Log.d('CpEffectsOverlay', 'no overlay available — skipping $svgaUrl');
      return;
    }
    _dismissTimer?.cancel();
    _entry?.remove();
    _entry = OverlayEntry(
      builder: (_) => _CpAnimationView(
        url: svgaUrl,
        heightFactor: heightFactor,
        onDone: _dismiss,
      ),
    );
    overlay.insert(_entry!);
    _dismissTimer = Timer(const Duration(seconds: 8), _dismiss);
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _CpAnimationView extends StatelessWidget {
  const _CpAnimationView({
    required this.url,
    required this.onDone,
    this.heightFactor = 0.75,
  });

  final String url;
  final VoidCallback onDone;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: onDone,
      child: Container(
        color: Colors.black45,
        alignment: Alignment.center,
        child: SizedBox(
          width: size.width,
          height: size.height * heightFactor,
          child: SvgaPlayer(
            url: url,
            width: size.width,
            height: size.height * heightFactor,
            repeat: false,
            fit: BoxFit.contain,
            onCompleted: onDone,
          ),
        ),
      ),
    );
  }
}
