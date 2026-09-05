/// WebView screen â€” ported from native `WebActivity.java`.
///
/// Opens a URL in an in-app WebView with optional toolbar/title.
library web_view;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../theme/app_theme.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({
    super.key,
    required this.url,
    this.title,
    this.showToolbar = true,
  });

  final String url;
  final String? title;
  final bool showToolbar;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  int _progress = 0;
  String? _lastExternalUrl;
  DateTime? _lastExternalLaunchAt;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) {
                if (mounted) setState(() => _loading = true);
              },
              onPageFinished: (_) {
                if (mounted) setState(() => _loading = false);
              },
              onProgress: (p) {
                if (mounted) setState(() => _progress = p);
              },
              onNavigationRequest: (request) async {
                final uri = Uri.tryParse(request.url);
                if (uri == null) return NavigationDecision.prevent;
                if (_shouldLaunchExternally(uri)) {
                  await _launchExternally(uri);
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
              onWebResourceError: (error) async {
                final uri = Uri.tryParse(error.url ?? '');
                if (uri == null || !_shouldLaunchExternally(uri)) return;
                await _launchExternally(uri);
                if (await _controller.canGoBack()) {
                  await _controller.goBack();
                } else {
                  await _controller.loadRequest(Uri.parse(widget.url));
                }
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.url));
  }

  bool _shouldLaunchExternally(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    return (scheme != 'http' && scheme != 'https') ||
        host == 'wa.me' ||
        host == 'api.whatsapp.com' ||
        host == 'web.whatsapp.com';
  }

  Future<void> _launchExternally(Uri uri) async {
    final now = DateTime.now();
    if (_lastExternalUrl == uri.toString() &&
        _lastExternalLaunchAt != null &&
        now.difference(_lastExternalLaunchAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastExternalUrl = uri.toString();
    _lastExternalLaunchAt = now;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (uri.scheme.toLowerCase() != 'whatsapp') return;
    final phone = (uri.queryParameters['phone'] ?? '').replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final text = uri.queryParameters['text'];
    final fallback = Uri.https(
      'wa.me',
      phone.isEmpty ? '/' : '/$phone',
      text?.isNotEmpty == true ? {'text': text!} : null,
    );
    try {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.setNavigationDelegate(NavigationDelegate());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.showToolbar
              ? AppBar(
                title: Text(widget.title ?? 'Web'),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _controller.reload(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_browser),
                    onPressed:
                        () => _controller.canGoBack().then((can) {
                          if (can) _controller.goBack();
                        }),
                  ),
                ],
              )
              : null,
      body: Stack(
        alignment: Alignment.topLeft,
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            LinearProgressIndicator(
              value: _progress > 0 ? _progress / 100 : null,
              color: AppTheme.primary,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            ),
        ],
      ),
    );
  }
}
