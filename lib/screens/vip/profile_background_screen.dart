/// Profile Background screen — VIP-exclusive profile backgrounds.
///
/// Bigo-style profile background gallery — VIP users can browse and
/// equip exclusive profile background images.
library profile_background;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../utils/media_utils.dart';
import 'package:belive/widgets/preloader.dart';

class ProfileBackgroundScreen extends StatefulWidget {
  const ProfileBackgroundScreen({super.key});

  @override
  State<ProfileBackgroundScreen> createState() =>
      _ProfileBackgroundScreenState();
}

class _ProfileBackgroundScreenState extends State<ProfileBackgroundScreen> {
  static const String _tag = 'ProfileBackground';
  final _backgrounds = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _equipping = false;
  String? _currentBgId;
  int _userVipLevel = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = context.read<SessionManager>();
    final user = session.getUser();
    _userVipLevel = _extractVipLevel(user);
    setState(() => _loading = true);
    try {
      // Reuse the theme gallery endpoint which includes profile backgrounds
      final res = await ApiService.getVipThemeGallery(session.userId);
      if (res.status) {
        _backgrounds.clear();
        for (final t in res.themes) {
          if (t.profileBgUrl != null && t.profileBgUrl!.isNotEmpty) {
            _backgrounds.add({
              'id': t.id,
              'name': t.name,
              'url': t.profileBgUrl,
              'requiredVipLevel': t.requiredVipLevel,
            });
          }
        }
        _currentBgId = res.currentThemeId;
      }
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _extractVipLevel(dynamic user) {
    try {
      final u = user as dynamic;
      final status = u?.vipStatus;
      if (status != null && status.currentLevel > 0) return status.currentLevel;
      final vipInfo = u?.vip;
      final tierId = vipInfo?.tierId?.toString() ?? '';
      final digits = tierId.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) return 0;
      return int.parse(digits);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _equip(Map<String, dynamic> bg) async {
    if (_equipping) return;
    final reqLevel = (bg['requiredVipLevel'] as int?) ?? 3;
    if (_userVipLevel < reqLevel) {
      Fluttertoast.showToast(
        msg: 'Enable VIP $reqLevel to unlock this background',
      );
      return;
    }
    setState(() => _equipping = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.equipVipTheme(
        userId: session.userId,
        themeId: bg['id'] as String? ?? '',
      );
      if (res.status) {
        setState(() => _currentBgId = bg['id'] as String?);
        Fluttertoast.showToast(msg: 'Background equipped!');
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to equip');
      }
    } catch (e, s) {
      Log.e(_tag, 'equip failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to equip background');
    } finally {
      if (mounted) setState(() => _equipping = false);
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
                child:
                    _loading
                        ? const Center(child: Preloader())
                        : _backgrounds.isEmpty
                        ? _buildEmpty()
                        : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.85,
                              ),
                          itemCount: _backgrounds.length,
                          itemBuilder: (context, i) {
                            final bg = _backgrounds[i];
                            final isEquipped = _currentBgId == bg['id'];
                            final isLocked =
                                _userVipLevel <
                                ((bg['requiredVipLevel'] as int?) ?? 3);
                            return _buildCard(bg, isEquipped, isLocked);
                          },
                        ),
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Profile Background',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wallpaper_outlined, color: Colors.white38, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No backgrounds available',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Refresh')),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> bg, bool isEquipped, bool isLocked) {
    final url = bg['url'] as String?;
    final name = bg['name'] as String?;
    final reqLevel = (bg['requiredVipLevel'] as int?) ?? 3;
    return GestureDetector(
      onTap: isLocked ? null : () => _equip(bg),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isEquipped
                    ? AppTheme.primary
                    : (isLocked
                        ? Colors.white12
                        : Colors.white.withValues(alpha: 0.1)),
            width: isEquipped ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.topLeft,
            fit: StackFit.expand,
            children: [
              if (url != null && url.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: VideoUtil.getFullImageUrl(url),
                  fit: BoxFit.cover,
                  placeholder:
                      (_, __) => Container(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                  errorWidget:
                      (_, __, ___) => Container(
                        color: Colors.white.withValues(alpha: 0.05),
                        child: const Icon(
                          Icons.wallpaper,
                          color: Colors.white24,
                          size: 32,
                        ),
                      ),
                )
              else
                Container(
                  color: Colors.white.withValues(alpha: 0.05),
                  child: const Icon(
                    Icons.wallpaper,
                    color: Colors.white24,
                    size: 32,
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Text(
                    name ?? 'Background',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
              if (isEquipped)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.check_circle,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
              if (isLocked)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.6),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock,
                            color: Colors.white38,
                            size: 28,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'VIP $reqLevel',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
