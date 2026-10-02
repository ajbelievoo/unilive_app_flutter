/// In-room Ludo panel — embeds the Ludo web game (ludo.unilive.me) inside the
/// audio room so seated players can play without leaving the room.
///
/// The web page talks to the app through the `GameBridge` JS channel:
///   - 'close'       → hide the panel locally (game/table keeps running)
///   - 'minimize'    → collapse to a chip; WebView stays alive so the round
///                     continues and the seat is not forfeited
///   - 'recharge'    → push the wallet recharge screen
///   - 'coin_update' → emit USER_COIN_UPDATE so balances refresh
///   - 'toast:<msg>' → show a toast
library ludo_room_panel;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../constants/const.dart';
import '../routes/app_routes.dart';
import '../services/session_manager.dart';
import '../services/socket_service.dart';
import '../utils/log.dart';

/// Game server URLs — the dedicated subdomain is preferred; the path-based
/// fallback on the main domain keeps working even before its DNS record exists.
const String kLudoBaseUrl = 'https://ludo.unilive.me/';
const String kLudoFallbackUrl = 'https://admin.unilive.me/ludo/';

class LudoRoomPanel extends StatefulWidget {
  const LudoRoomPanel({
    super.key,
    required this.roomId,
    this.onClose,
    this.onMinimize,
    this.canHost = false,
  });

  /// Audio room id — becomes the ludo table id (liveStreamingId).
  final String roomId;

  /// Whether the local user is the room host or an admin — only they may
  /// open/start the table (the web client mirrors this in its UI).
  final bool canHost;

  /// Local dismiss — the table itself is unaffected.
  final VoidCallback? onClose;

  /// Collapse to a floating chip while keeping the game socket alive
  /// (mid-round the web client can't fully close).
  final VoidCallback? onMinimize;

  @override
  State<LudoRoomPanel> createState() => _LudoRoomPanelState();
}

class _LudoRoomPanelState extends State<LudoRoomPanel> {
  static const String _tag = 'LudoPanel';
  late final WebViewController _controller;
  bool _loading = true;
  bool _useFallback = false;
  String? _loadError;

  String _buildUrl(String base) {
    final session = SessionManager.instance;
    final user = session?.getUser();
    final uri = Uri.parse(base);
    final params = <String, String>{
      'roomId': widget.roomId,
      'userId': user?.id ?? '',
      'uniqueId': user?.uniqueId ?? '',
      'name': user?.name ?? '',
      'image': user?.image ?? '',
      'token': user?.token ?? '',
      'diamond': '${user?.coin.toInt() ?? 0}',
      if (widget.canHost) 'host': '1',
    };
    return uri.replace(queryParameters: params).toString();
  }

  void _onGameMessage(String message) {
    if (message == 'close') {
      widget.onClose?.call();
      return;
    }
    if (message == 'minimize') {
      widget.onMinimize?.call();
      return;
    }
    if (message == 'recharge') {
      context.pushNamed(AppRoutes.recharge);
      return;
    }
    if (message == 'coin_update') {
      final uid = SessionManager.instance?.getUser()?.id ?? '';
      if (uid.isNotEmpty) {
        SocketService.instance.emit(Const.eventUserCoinUpdate, uid);
      }
      return;
    }
    if (message.startsWith('toast:')) {
      final text = message.substring(6);
      if (text.isNotEmpty) Fluttertoast.showToast(msg: text);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.transparent)
          ..addJavaScriptChannel(
            'GameBridge',
            onMessageReceived: (m) => _onGameMessage(m.message),
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (_) {
                if (mounted) setState(() => _loading = false);
              },
              onWebResourceError: (e) {
                if (e.isForMainFrame != true || !mounted) return;
                // Domain not resolving yet? Retry once on the fallback path.
                if (!_useFallback &&
                    (e.errorCode == -2 ||
                        e.description.contains('ERR_NAME'))) {
                  _useFallback = true;
                  _controller.loadRequest(Uri.parse(_buildUrl(kLudoFallbackUrl)));
                  return;
                }
                setState(() {
                  _loading = false;
                  _loadError = e.description;
                });
              },
            ),
          );
    final url = _buildUrl(kLudoBaseUrl);
    Log.d(_tag, 'loading ludo: $url');
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final h = MediaQuery.sizeOf(context).height;
    // Full-width square board + slim top bar (~42px) inside the page; while
    // open the seat grid collapses to a strip so the board takes the width.
    final panelH = ((w - 6) + 46).clamp(280.0, h * 0.74);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: panelH,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF2A1B52).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_loading)
                const Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFFA55CFF),
                    ),
                  ),
                ),
              if (_loadError != null && !_loading)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white54,
                        size: 30,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ludo failed to load',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _loadError = null;
                          });
                          _controller.reload();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
