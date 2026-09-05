/// VIP Theme Gallery screen — VIP-exclusive chat & profile themes.
///
/// Bigo-style theme gallery — VIP 3+ users can browse and equip
/// exclusive chat bubble, profile background, and room card themes.
library vip_theme_gallery;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/vip_extended_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../utils/media_utils.dart';
import 'package:belive/widgets/preloader.dart';

class VipThemeGalleryScreen extends StatefulWidget {
  const VipThemeGalleryScreen({super.key});

  @override
  State<VipThemeGalleryScreen> createState() => _VipThemeGalleryScreenState();
}

class _VipThemeGalleryScreenState extends State<VipThemeGalleryScreen> {
  static const String _tag = 'VipThemeGallery';
  final _themes = <VipTheme>[];
  bool _loading = true;
  bool _equipping = false;
  String? _currentThemeId;
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
      final res = await ApiService.getVipThemeGallery(session.userId);
      if (res.status) {
        _themes.clear();
        _themes.addAll(res.themes);
        _currentThemeId = res.currentThemeId;
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

  Future<void> _equip(VipTheme theme) async {
    if (_equipping) return;
    if (_userVipLevel < theme.requiredVipLevel) {
      Fluttertoast.showToast(
        msg: 'Enable VIP ${theme.requiredVipLevel} to unlock this theme',
      );
      return;
    }
    setState(() => _equipping = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.equipVipTheme(
        userId: session.userId,
        themeId: theme.id ?? '',
      );
      if (res.status) {
        setState(() => _currentThemeId = theme.id);
        Fluttertoast.showToast(msg: 'Theme equipped!');
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to equip');
      }
    } catch (e, s) {
      Log.e(_tag, 'equip failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to equip theme');
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
                        : _themes.isEmpty
                        ? _buildEmpty()
                        : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.75,
                              ),
                          itemCount: _themes.length,
                          itemBuilder: (context, i) {
                            final theme = _themes[i];
                            final isEquipped = _currentThemeId == theme.id;
                            final isLocked =
                                _userVipLevel < theme.requiredVipLevel;
                            return _buildThemeCard(theme, isEquipped, isLocked);
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
                'VIP Themes',
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
          const Icon(Icons.palette_outlined, color: Colors.white38, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No themes available',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Refresh')),
        ],
      ),
    );
  }

  Widget _buildThemeCard(VipTheme theme, bool isEquipped, bool isLocked) {
    return GestureDetector(
      onTap: isLocked ? null : () => _equip(theme),
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
              // Preview image
              if (theme.previewUrl != null && theme.previewUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: VideoUtil.getFullImageUrl(theme.previewUrl),
                  fit: BoxFit.cover,
                  placeholder:
                      (_, __) => Container(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                  errorWidget:
                      (_, __, ___) => Container(
                        color: Colors.white.withValues(alpha: 0.05),
                        child: const Icon(
                          Icons.palette,
                          color: Colors.white24,
                          size: 32,
                        ),
                      ),
                )
              else
                Container(
                  color: Colors.white.withValues(alpha: 0.05),
                  child: const Icon(
                    Icons.palette,
                    color: Colors.white24,
                    size: 32,
                  ),
                ),
              // Gradient overlay
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        theme.name ?? 'Theme',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                      ),
                      if (isEquipped)
                        const Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppTheme.primary,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Equipped',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
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
                            'VIP ${theme.requiredVipLevel}',
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
