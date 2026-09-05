/// Generic web view screen — loads external URLs.
///
/// Ports native `WebActivity.java`. Used for banner clicks, games, recharge,
/// privacy policy, etc.
library web_view;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../theme/app_theme.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({
    super.key,
    required this.url,
    this.title,
    this.showAppBar = true,
  });

  final String url;
  final String? title;
  final bool showAppBar;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  double _progress = 0;

  /// Tracks URLs we recently tried to launch so multiple delegates don't
  /// open the same link 2-3 times. Removed after a short debounce.
  final _recentUrls = <String>{};
  Timer? _recentUrlsTimer;

  static final _externalSchemes = {
    'whatsapp',
    'tel',
    'sms',
    'mailto',
    'fb',
    'fb-messenger',
    'instagram',
    'tg',
    'viber',
    'line',
    'skype',
  };

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..addJavaScriptChannel(
            'NativeLauncher',
            onMessageReceived: (msg) {
              final url = msg.message.trim();
              if (url.isNotEmpty) _tryLaunchUrl(url);
            },
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (url) {
                if (mounted) setState(() => _loading = true);
                // Fallback: if a non-http(s) link still somehow starts loading,
                // launch it externally and reload the original page so the user
                // doesn't get stuck on an error screen.
                if (url.isNotEmpty) {
                  final uri = Uri.parse(url);
                  if (uri.scheme != 'http' &&
                      uri.scheme != 'https' &&
                      _externalSchemes.contains(uri.scheme)) {
                    _tryLaunchUrl(url);
                    _controller.loadRequest(Uri.parse(widget.url));
                    return;
                  }
                }
              },
              onPageFinished: (_) {
                if (mounted) setState(() => _loading = false);
                _attachExternalLinkInterceptor();
              },
              onProgress: (p) {
                if (mounted) setState(() => _progress = p / 100.0);
              },
              onUrlChange: (change) async {
                final url = change.url;
                if (url != null) {
                  final uri = Uri.parse(url);
                  if (uri.scheme != 'http' && uri.scheme != 'https') {
                    await _tryLaunchUrl(url);
                    await _controller.goBack();
                  }
                }
              },
              onNavigationRequest: (request) {
                final uri = Uri.parse(request.url);

                // Non-http(s) deep links (whatsapp://, tel://, mailto://, etc.)
                if (uri.scheme != 'http' && uri.scheme != 'https') {
                  _tryLaunchUrl(request.url);
                  return NavigationDecision.prevent;
                }

                // WhatsApp / messenger web links that should open their native apps.
                if (_isWhatsAppOrMessengerLink(uri)) {
                  _tryLaunchUrl(request.url);
                  return NavigationDecision.prevent;
                }

                // Normal web link: always PREVENT the webview's default load and
                // manually load it. This works around a webview_flutter Android bug
                // where shouldOverrideUrlLoading uses the *previous* decision's
                // value, so a previous navigate() causes the next whatsapp:// link
                // to briefly load in the webview before it can be prevented.
                if (!_recentUrls.contains(request.url)) {
                  _recentUrls.add(request.url);
                  _recentUrlsTimer?.cancel();
                  _recentUrlsTimer = Timer(
                    const Duration(seconds: 2),
                    () => _recentUrls.clear(),
                  );
                  _controller.loadRequest(Uri.parse(request.url));
                }
                return NavigationDecision.prevent;
              },
              onWebResourceError: (error) async {
                final url = error.url;
                if (url != null && url.isNotEmpty) {
                  final uri = Uri.parse(url);
                  if (uri.scheme != 'http' && uri.scheme != 'https') {
                    await _tryLaunchUrl(url);
                    if (await _controller.canGoBack()) {
                      await _controller.goBack();
                    } else {
                      // If there is no previous page, reload the original
                      // URL so the user doesn't get stuck on the error screen.
                      await _controller.loadRequest(Uri.parse(widget.url));
                    }
                    return;
                  }
                }
                if (mounted) setState(() => _loading = false);
                if (error.errorType != WebResourceErrorType.unknown) {
                  Fluttertoast.showToast(
                    msg: 'Error loading page: ${error.description}',
                  );
                }
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.url));
  }

  bool _isWhatsAppOrMessengerLink(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'wa.me' ||
        host == 'api.whatsapp.com' ||
        host == 'web.whatsapp.com' ||
        host.contains('whatsapp') ||
        host == 'm.me' ||
        host.contains('messenger') ||
        host == 't.me' ||
        _externalSchemes.contains(uri.scheme);
  }

  Future<void> _attachExternalLinkInterceptor() async {
    await _controller.runJavaScript('''
      (function() {
        if (window._nativeLauncherAttached) return;
        window._nativeLauncherAttached = true;

        function toArray(list) {
          if (!list) return [];
          if (Array.isArray(list)) return list;
          if (typeof list.length === 'number') {
            return Array.prototype.slice.call(list);
          }
          return [];
        }

        function closest(el, selector) {
          if (!el) return null;
          if (el.closest) return el.closest(selector);
          while (el && el !== document.body) {
            if (el.matches && el.matches(selector)) return el;
            el = el.parentNode;
          }
          return null;
        }

        function shouldIntercept(url) {
          if (!url) return false;
          var lower = url.toLowerCase();
          return lower.indexOf('whatsapp://') === 0
              || lower.indexOf('wa.me/') === 0
              || lower.indexOf('https://wa.me/') === 0
              || lower.indexOf('http://wa.me/') === 0
              || lower.indexOf('api.whatsapp.com') !== -1
              || lower.indexOf('web.whatsapp.com') !== -1
              || lower.indexOf('tel:') === 0
              || lower.indexOf('sms:') === 0
              || lower.indexOf('mailto:') === 0
              || lower.indexOf('tg://') === 0
              || lower.indexOf('viber://') === 0
              || lower.indexOf('line://') === 0
              || lower.indexOf('skype://') === 0;
        }

        function sendToNative(url) {
          if (window.NativeLauncher && window.NativeLauncher.postMessage) {
            window.NativeLauncher.postMessage(url);
            return true;
          }
          return false;
        }

        function intercept(url) {
          if (shouldIntercept(url)) {
            if (sendToNative(url)) return true;
          }
          return false;
        }

        document.addEventListener('click', function(e) {
          var a = closest(e.target, 'a[href]');
          if (a) {
            var href = a.getAttribute('href');
            if (href && intercept(href)) {
              e.preventDefault();
              e.stopPropagation();
              e.stopImmediatePropagation();
              return false;
            }
          }
        }, true);

        try {
          var origLocation = Object.getOwnPropertyDescriptor(window, 'location');
          if (origLocation && origLocation.configurable) {
            Object.defineProperty(window, 'location', {
              set: function(url) {
                if (intercept(url)) return url;
                origLocation.set.call(window, url);
              },
              get: origLocation.get,
              configurable: true
            });
          }
        } catch (_) {}

        try {
          var origOpen = window.open;
          window.open = function(url, target, features) {
            if (url && intercept(url)) return null;
            return origOpen.call(window, url, target, features);
          };
        } catch (_) {}

        try {
          var origAssign = window.location.assign;
          var origReplace = window.location.replace;
          window.location.assign = function(url) {
            if (url && intercept(url)) return;
            origAssign.call(window.location, url);
          };
          window.location.replace = function(url) {
            if (url && intercept(url)) return;
            origReplace.call(window.location, url);
          };
        } catch (_) {}

        try {
          var observer = new MutationObserver(function(mutations) {
            for (var i = 0; i < mutations.length; i++) {
              var nodes = toArray(mutations[i].addedNodes);
              for (var j = 0; j < nodes.length; j++) {
                var n = nodes[j];
                if (n.nodeType === 1) {
                  var links = [];
                  if (n.matches && n.matches('a[href]')) {
                    links.push(n);
                  }
                  if (n.querySelectorAll) {
                    links = links.concat(toArray(n.querySelectorAll('a[href]')));
                  }
                  for (var k = 0; k < links.length; k++) {
                    links[k].addEventListener('click', function(e) {
                      var href = this.getAttribute('href');
                      if (href && intercept(href)) {
                        e.preventDefault();
                        e.stopPropagation();
                        e.stopImmediatePropagation();
                        return false;
                      }
                    }, true);
                  }
                }
              }
            }
          });
          if (document.body) {
            observer.observe(document.body, { childList: true, subtree: true });
          } else {
            document.addEventListener('DOMContentLoaded', function() {
              observer.observe(document.body, { childList: true, subtree: true });
            });
          }
        } catch (_) {}
      })();
    ''');
  }

  Future<void> _tryLaunchUrl(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty || _recentUrls.contains(normalized)) return;
    _recentUrls.add(normalized);
    _recentUrlsTimer?.cancel();
    _recentUrlsTimer = Timer(
      const Duration(seconds: 2),
      () => _recentUrls.clear(),
    );

    try {
      final uri = _normalizeWhatsAppUri(Uri.parse(normalized));

      // WhatsApp deep links → try native WhatsApp, then wa.me fallback, then api.whatsapp.com.
      if (uri.scheme == 'whatsapp' ||
          uri.host == 'wa.me' ||
          uri.host.toLowerCase().contains('whatsapp')) {
        final phone = _extractPhone(uri);
        final text = uri.queryParameters['text'];

        // Prefer a clean https://wa.me/ fallback — works even if the app isn't installed.
        final waMeParams = <String, String>{};
        if (text != null && text.isNotEmpty) waMeParams['text'] = text;
        final waMePhone = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        final waMeUri =
            waMePhone.isNotEmpty
                ? Uri.https('wa.me', '/$waMePhone', waMeParams)
                : null;

        // 1) Try the raw whatsapp:// scheme first (opens native app).
        if (uri.scheme == 'whatsapp') {
          try {
            await launchUrl(
              uri,
              mode: LaunchMode.externalNonBrowserApplication,
            );
            return;
          } catch (_) {}
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          } catch (_) {}
        }

        // 2) wa.me web fallback in an external browser.
        if (waMeUri != null) {
          try {
            await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
            return;
          } catch (_) {}
        }

        // 3) api.whatsapp.com fallback.
        final apiParams = <String, String>{};
        if (phone != null && phone.isNotEmpty) apiParams['phone'] = phone;
        if (text != null && text.isNotEmpty) apiParams['text'] = text;
        final fallback =
            waMePhone.isNotEmpty
                ? Uri.https('api.whatsapp.com', '/send', apiParams)
                : null;

        if (fallback != null) {
          try {
            await launchUrl(fallback, mode: LaunchMode.externalApplication);
            return;
          } catch (_) {}
        }

        Fluttertoast.showToast(msg: 'WhatsApp not available');
        return;
      }

      // Other deep links
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Cannot open: $normalized');
    }
  }

  /// Converts malformed whatsapp://send/?phone=... to whatsapp://send?phone=...
  /// and https://wa.me/send?phone=... to https://wa.me/<phone>?text=...
  Uri _normalizeWhatsAppUri(Uri uri) {
    if (uri.scheme == 'whatsapp' && uri.host == 'send' && uri.path == '/') {
      final phone = uri.queryParameters['phone'];
      final text = uri.queryParameters['text'];
      final params = <String, String>{};
      if (phone != null && phone.isNotEmpty) params['phone'] = phone;
      if (text != null && text.isNotEmpty) params['text'] = text;
      return Uri(scheme: 'whatsapp', host: 'send', queryParameters: params);
    }
    return uri;
  }

  String? _extractPhone(Uri uri) {
    // whatsapp://send?phone=...
    if (uri.scheme == 'whatsapp' && uri.host == 'send') {
      return uri.queryParameters['phone'];
    }
    // wa.me/phone or wa.me/send?phone=
    if (uri.host == 'wa.me') {
      final segments =
          uri.pathSegments.where((s) => s.isNotEmpty && s != 'send').toList();
      if (segments.isNotEmpty) return segments.first;
      return uri.queryParameters['phone'];
    }
    // api.whatsapp.com/send?phone=...
    if (uri.host.toLowerCase().contains('whatsapp')) {
      return uri.queryParameters['phone'];
    }
    return null;
  }

  @override
  void dispose() {
    _recentUrlsTimer?.cancel();
    unawaited(_controller.setNavigationDelegate(NavigationDelegate()));
    unawaited(_controller.removeJavaScriptChannel('NativeLauncher'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: Text(widget.title ?? 'Web'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _controller.reload(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_browser),
                    onPressed: () async {
                      final uri = Uri.parse(widget.url);
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                ],
              )
              : null,
      body: Stack(
        alignment: Alignment.topLeft,
        children: [
          WebViewWidget(controller: _controller),
          if (_loading && _progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.transparent,
              color: AppTheme.primary,
              minHeight: 3,
            ),
        ],
      ),
    );
  }
}
