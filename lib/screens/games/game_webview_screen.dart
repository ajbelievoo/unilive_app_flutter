/// Game WebView screen — loads a game URL in a WebView.
///
/// Ports native `BottomSheetGameCasino`, `DialogGame`, and
/// `BottomSheetGameTeenPatti` which all load game URLs in a WebView.
/// Native uses fixed-height bottom sheets (370sdp for casino, 351dp for
/// teen patti, 550dp for dialog) — NOT full screen.
library game_webview_screen;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../constants/const.dart';
import '../../services/session_manager.dart';
import '../../services/socket_service.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

/// Opens a game in a bottom-sheet WebView (matches native app sizing).
///
/// [gameName] is displayed in the title bar.
/// [gameUrl] is the URL to load in the WebView.
/// [gameType] determines the presentation style:
///   - 'casino' or 'teenpatti': compact bottom sheet (~370dp)
///   - 'dialog': taller bottom sheet (~550dp)
Future<void> openGameWebView(
  BuildContext context, {
  required String gameName,
  required String gameUrl,
  String gameType = 'dialog',
}) async {
  final session = SessionManager.instance;
  final user = session?.getUser();
  final userId = user?.id ?? '';
  final diamond = user?.coin.toInt() ?? 0;
  final token = user?.token ?? '';
  final userName = user?.name ?? '';
  final userImage = user?.image ?? '';

  // Pass identity, balance, and token to the game. Different game builds
  // read different parameter names, so we supply all common variants.
  String finalUrl = gameUrl;
  if (userId.isNotEmpty) {
    final parsed = Uri.tryParse(gameUrl);
    if (parsed != null) {
      final query =
          Map<String, String>.from(parsed.queryParameters)
            ..['userId'] = userId
            ..['userID'] = userId
            ..['user_id'] = userId
            ..['user'] = userId
            ..['id'] = userId
            ..['diamond'] = '$diamond'
            ..['userDiamond'] = '$diamond'
            ..['balance'] = '$diamond'
            ..['coin'] = '$diamond'
            ..['coins'] = '$diamond'
            ..['token'] = token
            ..['name'] = userName
            ..['userName'] = userName
            ..['image'] = userImage
            ..['userImage'] = userImage
            ..['profileImage'] = userImage;
      finalUrl = parsed.replace(queryParameters: query).toString();
    } else {
      final sep = gameUrl.contains('?') ? '&' : '?';
      finalUrl =
          '$gameUrl${sep}userId=$userId&user=$userId&diamond=$diamond&userDiamond=$diamond&balance=$diamond&coin=$diamond&token=$token&name=$userName&image=$userImage';
    }
  }
  Log.d(
    'GameWebView',
    'Opening game: $gameName | userId=$userId | diamond=$diamond',
  );

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder:
        (_) => _GameWebViewSheet(
          gameName: gameName,
          gameUrl: finalUrl,
          gameType: gameType,
          userId: userId,
          diamond: diamond,
          token: token,
          userName: userName,
          userImage: userImage,
        ),
  );
  // Emit coin update when game closes (matches native behavior)
  if (session != null && userId.isNotEmpty) {
    SocketService.instance.emit(Const.eventUserCoinUpdate, userId);
    Log.d('GameWebView', 'Game closed, emitted USER_COIN_UPDATE for $userId');
  }
}

class _GameWebViewSheet extends StatefulWidget {
  const _GameWebViewSheet({
    required this.gameName,
    required this.gameUrl,
    required this.gameType,
    required this.userId,
    required this.diamond,
    required this.token,
    required this.userName,
    required this.userImage,
  });

  final String gameName;
  final String gameUrl;
  final String gameType;
  final String userId;
  final int diamond;
  final String token;
  final String userName;
  final String userImage;

  @override
  State<_GameWebViewSheet> createState() => _GameWebViewSheetState();
}

class _GameWebViewSheetState extends State<_GameWebViewSheet> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _historyPage = false;
  String? _loadError;

  bool _isHistoryUrl(String url) {
    final value = url.toLowerCase();
    return value.contains('history') || value.contains('record');
  }

  void _updateHistoryPage(String url) {
    final historyPage =
        widget.gameType.toLowerCase() == 'teenpatti' && _isHistoryUrl(url);
    if (mounted && historyPage != _historyPage) {
      setState(() => _historyPage = historyPage);
    }
  }

  /// JS that injects identity + balance into the game page.
  /// Called on onPageStarted AND onPageFinished so values are available
  /// regardless of when the game's JS reads them.
  String get _injectJs => '''
    window.userId = '${_escapeJs(widget.userId)}';
    window.userID = '${_escapeJs(widget.userId)}';
    window.user = '${_escapeJs(widget.userId)}';
    window.id = '${_escapeJs(widget.userId)}';
    window.diamond = ${widget.diamond};
    window.userDiamond = ${widget.diamond};
    window.balance = ${widget.diamond};
    window.coin = ${widget.diamond};
    window.coins = ${widget.diamond};
    window.token = '${_escapeJs(widget.token)}';
    window.userName = '${_escapeJs(widget.userName)}';
    window.name = '${_escapeJs(widget.userName)}';
    window.userImage = '${_escapeJs(widget.userImage)}';
    window.image = '${_escapeJs(widget.userImage)}';
    try {
      localStorage.setItem('userId', '${_escapeJs(widget.userId)}');
      localStorage.setItem('userID', '${_escapeJs(widget.userId)}');
      localStorage.setItem('user', '${_escapeJs(widget.userId)}');
      localStorage.setItem('diamond', '${widget.diamond}');
      localStorage.setItem('userDiamond', '${widget.diamond}');
      localStorage.setItem('balance', '${widget.diamond}');
      localStorage.setItem('coin', '${widget.diamond}');
      localStorage.setItem('coins', '${widget.diamond}');
      localStorage.setItem('token', '${_escapeJs(widget.token)}');
      localStorage.setItem('userName', '${_escapeJs(widget.userName)}');
      localStorage.setItem('name', '${_escapeJs(widget.userName)}');
      localStorage.setItem('userImage', '${_escapeJs(widget.userImage)}');
      localStorage.setItem('image', '${_escapeJs(widget.userImage)}');
    } catch(e) {}
  ''';

  /// Escape single quotes and backslashes for safe JS string embedding.
  String _escapeJs(String s) => s
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('"', r'\"')
      .replaceAll('\r', r'\r')
      .replaceAll('\n', r'\n')
      .replaceAll('\t', r'\t')
      .replaceAll('\u2028', r'\u2028')
      .replaceAll('\u2029', r'\u2029')
      .replaceAll('<', r'\x3C')
      .replaceAll('>', r'\x3E')
      .replaceAll('&', r'\x26');

  @override
  void initState() {
    super.initState();
    Log.d(
      'GameWebView',
      'initState | game=${widget.gameName} | diamond=${widget.diamond}',
    );

    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..enableZoom(true)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (url) {
                _updateHistoryPage(url);
                if (mounted) {
                  setState(() {
                    _loading = true;
                    _loadError = null;
                  });
                }
                // Inject values as early as possible — before game JS runs
                _controller.runJavaScript(_injectJs).catchError((e) {
                  Log.w('GameWebView', 'onPageStarted JS inject failed: $e');
                });
              },
              onUrlChange: (change) {
                final url = change.url;
                if (url != null) _updateHistoryPage(url);
              },
              onPageFinished: (url) {
                _updateHistoryPage(url);
                // Re-inject after page loads — some games reset window vars
                _controller.runJavaScript(_injectJs).catchError((e) {
                  Log.w('GameWebView', 'onPageFinished JS inject failed: $e');
                });
                Log.d('GameWebView', 'page finished: $url');
                if (mounted) setState(() => _loading = false);
              },
              onWebResourceError: (error) {
                Log.e(
                  'GameWebView',
                  'WebView resource error: ${error.description} (code=${error.errorCode}) for ${error.url}',
                );
                if (error.isForMainFrame != true) return;
                if (mounted) {
                  setState(() {
                    _loading = false;
                    _loadError = error.description;
                  });
                }
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.gameUrl));
  }

  @override
  void dispose() {
    _controller.loadRequest(Uri.parse('about:blank'));
    _controller.setNavigationDelegate(NavigationDelegate());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Match native sizing:
    // - Casino / Teen Patti: ~370dp fixed height WebView
    // - Dialog: ~550dp fixed height WebView
    // Plus header (~40dp) = total bottom sheet height
    final type = widget.gameType.toLowerCase();
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    final requestedWebViewHeight =
        type == 'teenpatti'
            ? (_historyPage ? availableHeight * 0.86 : 351.0)
            : (type == 'dialog' ? 550.0 : 370.0);
    final maxSheetHeight = availableHeight * 0.96;
    final webViewHeight =
        requestedWebViewHeight
            .clamp(0.0, (maxSheetHeight - 44).clamp(0.0, maxSheetHeight))
            .toDouble();
    final totalHeight = webViewHeight + 44;

    return Container(
      height: totalHeight,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header with close button (matches native: close button top-right)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text(
                  widget.gameName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // WebView with fixed height (matches native layout)
          SizedBox(
            height: webViewHeight,
            child: Stack(
              alignment: Alignment.topLeft,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  child: WebViewWidget(controller: _controller),
                ),
                if (_loading)
                  const Center(child: Preloader(color: Color(0xFF7E3FF2))),
                if (_loadError != null && !_loading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Game failed to load',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _loadError!,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                _loading = true;
                                _loadError = null;
                              });
                              _controller.reload();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
