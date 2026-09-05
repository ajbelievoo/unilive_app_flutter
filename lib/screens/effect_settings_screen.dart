/// Effect Settings screen.
///
/// Mirrors the native "Effect Settings" page: toggles for room entry,
/// gift, vehicle, and various broadcast banners (Gift, Game, Fighter, PK,
/// Lucky Bag). A live preview of each banner is shown underneath the toggle.
library effect_settings_screen;

import 'package:flutter/material.dart';

import '../services/effect_settings_service.dart';
import '../theme/app_theme.dart';
import 'package:belive/widgets/preloader.dart';

class EffectSettingsScreen extends StatefulWidget {
  const EffectSettingsScreen({super.key});

  @override
  State<EffectSettingsScreen> createState() => _EffectSettingsScreenState();
}

class _EffectSettingsScreenState extends State<EffectSettingsScreen> {
  EffectSettings _settings = EffectSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await EffectSettingsService.instance.getSettings();
    if (mounted) setState(() { _settings = s; _loading = false; });
  }

  Future<void> _save(EffectSettings s) async {
    await EffectSettingsService.instance.saveSettings(s);
    if (mounted) setState(() => _settings = s);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.surface : AppTheme.lightSurface;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Effect Settings',
          style: TextStyle(
            color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: Preloader())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _sectionTitle('Room Entry'),
                _toggleTile(
                  'Enter room message',
                  _settings.showEnterRoomMessage,
                  (v) => _save(_settings.copyWith(showEnterRoomMessage: v)),
                  preview: _buildPreviewBanner(
                    icon: Icons.chat_bubble,
                    text: 'Welcome R**** to the room',
                    bgColor: const Color(0xFFB0BEC5),
                  ),
                ),
                _toggleTile(
                  'Enter room effect',
                  _settings.showEnterRoomEffect,
                  (v) => _save(_settings.copyWith(showEnterRoomEffect: v)),
                  preview: _buildPreviewBanner(
                    icon: Icons.stars,
                    text: 'Lv.20 Welcome R****',
                    bgColor: const Color(0xFF66BB6A),
                    leftBadge: _levelBadge('20'),
                  ),
                ),
                _sectionTitle('Gift & Vehicle'),
                _toggleTile(
                  'Gift Effect',
                  _settings.showGiftEffect,
                  (v) => _save(_settings.copyWith(showGiftEffect: v)),
                  preview: _buildPreviewBanner(
                    imageUrl: null,
                    text: 'Teddy couple gift animation',
                    bgColor: const Color(0xFFFFCCBC),
                    customChild: Center(
                      child: Image.asset(
                        'assets/gift/teddy_couple.webp',
                        height: 52,
                        errorBuilder: (_, __, ___) => const ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Colors.white, size: 40),
                      ),
                    ),
                  ),
                ),
                _toggleTile(
                  'Vehicle Effect',
                  _settings.showVehicleEffect,
                  (v) => _save(_settings.copyWith(showVehicleEffect: v)),
                  preview: _buildPreviewBanner(
                    imageUrl: null,
                    text: 'Ferrari sports car',
                    bgColor: const Color(0xFFCFD8DC),
                    customChild: Center(
                      child: Image.asset(
                        'assets/vehicle/ferrari.webp',
                        height: 52,
                        errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, color: Colors.white, size: 40),
                      ),
                    ),
                  ),
                ),
                _sectionTitle('Broadcast Banners'),
                _toggleTile(
                  'Gift Broadcast',
                  _settings.showGiftBroadcast,
                  (v) => _save(_settings.copyWith(showGiftBroadcast: v)),
                  preview: _buildPreviewBanner(
                    avatar: 'https://i.pravatar.cc/150?u=gift',
                    text: 'AamirKhan sent Kumar a gift',
                    sub: 'x999',
                    bgColor: const Color(0xFFE1BEE7),
                    right: const Icon(Icons.play_circle, color: Colors.white, size: 24),
                  ),
                ),
                _toggleTile(
                  'Game Broadcast',
                  _settings.showGameBroadcast,
                  (v) => _save(_settings.copyWith(showGameBroadcast: v)),
                  preview: _buildPreviewBanner(
                    avatar: 'https://i.pravatar.cc/150?u=game',
                    text: 'AamirKhan win 10000 diamonds at game',
                    bgColor: const Color(0xFFFFF9C4),
                    textColor: Colors.black87,
                    right: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                      child: const Text('Play', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
                ),
                _toggleTile(
                  'Fighter Broadcast',
                  _settings.showFighterBroadcast,
                  (v) => _save(_settings.copyWith(showFighterBroadcast: v)),
                  preview: _buildPreviewBanner(
                    avatar: 'https://i.pravatar.cc/150?u=fighter',
                    text: 'Room ID:1111  the fighter is about to launch',
                    bgColor: const Color(0xFF90CAF9),
                    right: const Icon(Icons.rocket_launch, color: Colors.white, size: 24),
                  ),
                ),
                _toggleTile(
                  'PK Broadcast',
                  _settings.showPkBroadcast,
                  (v) => _save(_settings.copyWith(showPkBroadcast: v)),
                  preview: _buildPreviewBanner(
                    avatar: 'https://i.pravatar.cc/150?u=pk',
                    text: 'Nick name got over 100,000 diamonds support',
                    sub: 'in PK',
                    bgColor: const Color(0xFFFFCDD2),
                    right: const Icon(Icons.sports_kabaddi, color: Colors.white, size: 24),
                  ),
                ),
                _toggleTile(
                  'Lucky Bag Broadcast',
                  _settings.showLuckyBagBroadcast,
                  (v) => _save(_settings.copyWith(showLuckyBagBroadcast: v)),
                  preview: _buildPreviewBanner(
                    avatar: 'https://i.pravatar.cc/150?u=lucky',
                    text: 'Nick name send a 500,000 Lucky Bag',
                    sub: '10',
                    bgColor: const Color(0xFFFFE0B2),
                    right: const Icon(Icons.redeem, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _toggleTile(String label, bool value, ValueChanged<bool> onChanged, {Widget? preview}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.textPrimary : AppTheme.lightTextPrimary),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          if (preview != null)
            Opacity(
              opacity: value ? 1.0 : 0.35,
              child: preview,
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewBanner({
    IconData? icon,
    String? imageUrl,
    String? avatar,
    String? text,
    String? sub,
    Color? bgColor,
    Color textColor = Colors.white,
    Widget? right,
    Widget? customChild,
    Widget? leftBadge,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: bgColor != null
            ? LinearGradient(colors: [bgColor, bgColor.withValues(alpha: 0.85)])
            : AppTheme.pinkGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (avatar != null) ...[
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(avatar),
              onBackgroundImageError: (_, __) {},
            ),
            const SizedBox(width: 10),
          ] else if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
          ] else if (leftBadge != null) ...[
            leftBadge,
            const SizedBox(width: 10),
          ],
          if (customChild != null)
            Expanded(child: customChild)
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (text != null)
                    Text(
                      text,
                      style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (sub != null)
                    Text(
                      sub,
                      style: TextStyle(color: textColor.withValues(alpha: 0.9), fontSize: 11),
                    ),
                ],
              ),
            ),
          if (right != null) ...[
            const SizedBox(width: 8),
            right,
          ],
        ],
      ),
    );
  }

  Widget _levelBadge(String level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.white, size: 10),
          const SizedBox(width: 2),
          Text('Lv.$level', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
