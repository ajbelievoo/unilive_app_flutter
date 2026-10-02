import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../models/splash_poster_model.dart';
import '../../models/user_root.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../providers/ai_feature_manager.dart';
import '../../providers/call_config_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/block_helper.dart';
import '../../utils/log.dart';

/// Single entry screen — brand splash + optional admin poster, then routes
/// to /main (logged in) or /login. Previously a separate SplashPosterScreen
/// sat in front of this one adding a full extra hop.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _hasNavigated = false;
  Timer? _minTimer;
  Timer? _posterTimer;
  AnimationController? _pulseController;

  SplashPoster? _poster;
  bool _posterChecked = false;
  bool _sessionReady = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Brand flash minimum, then navigate as soon as the session resolves.
    _minTimer = Timer(const Duration(milliseconds: 900), () {
      _sessionReady = true;
      _maybeNavigate();
    });

    _startBackgroundTasks();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Poster check runs in parallel with the session refresh. A poster only
    // ever *extends* the splash — when disabled/absent we never wait on it.
    ApiService.getSplashPoster()
        .timeout(const Duration(seconds: 3))
        .then((res) {
          if (res.status && res.data != null && res.data!.enabled &&
              (res.data!.image ?? '').isNotEmpty) {
            _poster = res.data;
            _posterChecked = true;
            if (mounted && !_hasNavigated) {
              setState(() {});
              final secs = _poster?.duration ?? 3;
              _posterTimer = Timer(
                Duration(seconds: secs.clamp(1, 5)),
                _navigate,
              );
            }
          } else {
            _posterChecked = true;
            _maybeNavigate();
          }
        })
        .catchError((_) {
          _posterChecked = true;
          _maybeNavigate();
        });

    await _resolveSession();
  }

  void _maybeNavigate() {
    // Wait until BOTH the brand-flash minimum and the session resolve — but
    // never wait on the poster fetch (speed over promos).
    if (_sessionReady && !_hasNavigated) _navigate();
  }

  Future<void> _resolveSession() async {
    try {
      final session = context.read<SessionManager>();
      final auth = context.read<AuthProvider>();
      final user = session.getUser();
      final isLoggedIn = session.isLoggedIn &&
          user != null &&
          user.id != null &&
          user.id!.isNotEmpty;
      if (isLoggedIn) {
        final refresh = await auth
            .refreshUserRoot()
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () => UserRoot(status: true),
            );
        if (!mounted) return;
        if (!refresh.status && BlockHelper.handleResult(context, refresh)) {
          _hasNavigated = true; // blocked — BlockHelper owns the UI now
          return;
        }
      }
    } catch (e) {
      debugPrint('[Splash] session refresh failed: $e');
    }
    _maybeNavigate();
  }

  void _startBackgroundTasks() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final session = context.read<SessionManager>();
        ApiService.getSettings().then((res) {
          if (res.status && res.setting != null) {
            session.saveSetting(res.setting!);
          }
        }).catchError((_) {});
        try {
          context.read<AIFeatureManager>().fetchActiveFeatures().catchError((e) {
            Log.w('Splash', 'AI feature fetch failed: $e');
          });
        } catch (_) {}
        try {
          final callConfig = context.read<CallConfigProvider>();
          callConfig.load().catchError((e) {
            Log.w('Splash', 'call config fetch failed: $e');
          });
          callConfig.startAutoRefresh();
        } catch (_) {}
        ApiService.getIp().then((ip) {
          if (ip.country != null) session.saveCountry(ip.country!);
          if (ip.query != null) session.saveIpAddress(ip.query!);
        }).catchError((_) {});
        ApiService.createTesting(
          platformType: Platform.isAndroid ? 'android' : 'ios',
          deviceName: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
          identity: session.userId.isNotEmpty ? session.userId : 'guest',
          user: session.userName.isNotEmpty ? session.userName : 'Guest',
        ).then((_) {}).catchError((e) {
          Log.e('Splash', 'createTesting failed', e);
          return;
        });
      } catch (_) {}
    });
  }

  Future<void> _navigate() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _minTimer?.cancel();
    _posterTimer?.cancel();

    String target = '/login';
    try {
      final session = context.read<SessionManager>();
      final user = session.getUser();
      final isLoggedIn = session.isLoggedIn &&
          user != null &&
          user.id != null &&
          user.id!.isNotEmpty;
      if (isLoggedIn) {
        target = '/main';
      } else if (user != null && user.id != null && user.id!.isNotEmpty) {
        session.setLoggedIn(true);
        target = '/main';
      }
    } catch (_) {}

    Future.microtask(() {
      if (!mounted) return;
      try {
        context.go(target);
      } catch (e) {
        Navigator.of(context).pushReplacementNamed(target);
      }
    });
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _posterTimer?.cancel();
    _pulseController?.dispose();
    super.dispose();
  }

  // ── UI ──────────────────────────────────────────────────────────────

  Widget _glowOrb(double size, Color color, double opacity) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      ),
    );
  }

  Widget _brandSplash() {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Soft glowing orbs for depth.
          Positioned(
            top: -60,
            left: -50,
            child: _glowOrb(220, const Color(0xFFFF5C8A), 0.35),
          ),
          Positioned(
            bottom: -40,
            right: -60,
            child: _glowOrb(260, const Color(0xFF7E3FF2), 0.4),
          ),
          Positioned(
            top: 140,
            right: -80,
            child: _glowOrb(160, const Color(0xFF00C2FF), 0.25),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo wrapped in an animated halo.
                  AnimatedBuilder(
                    animation: _pulseController!,
                    builder: (_, child) {
                      final pulse = 1 + (_pulseController!.value * 0.06);
                      return Transform.scale(scale: pulse, child: child);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.45),
                            blurRadius: 46,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: const Color(0xFFFF5C8A)
                                .withValues(alpha: 0.35),
                            blurRadius: 90,
                            spreadRadius: 26,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Image.asset(
                            'assets/images/unilive_logo.png',
                            width: 118,
                            height: 118,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Unilive',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      shadows: [
                        Shadow(
                          color: Color(0x55000000),
                          offset: Offset(0, 5),
                          blurRadius: 16,
                        ),
                        Shadow(color: Color(0x66FFFFFF), blurRadius: 30),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Live • Stream • Connect',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 60),
                  FadeTransition(
                    opacity: _pulseController!,
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _posterSplash() {
    return GestureDetector(
      onTap: _navigate,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: _poster!.image!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (_, __) => _brandSplash(),
            errorWidget: (_, __, ___) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
              return _brandSplash();
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _posterChecked && _poster != null ? _posterSplash() : _brandSplash(),
    );
  }
}
