/// Dynamic Avatar screen — VIP 5+ feature.
///
/// Lets VIP users browse and equip animated GIF avatars, or upload their own.
/// Ports native `DynamicAvatarActivity.java` with Bigo-style gallery.
library dynamic_avatar;

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/vip_extended_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../utils/media_utils.dart';
import 'package:belive/widgets/preloader.dart';

class DynamicAvatarScreen extends StatefulWidget {
  const DynamicAvatarScreen({super.key, this.avatars = const []});

  final List<Map<String, dynamic>> avatars;

  @override
  State<DynamicAvatarScreen> createState() => _DynamicAvatarScreenState();
}

class _DynamicAvatarScreenState extends State<DynamicAvatarScreen> {
  static const String _tag = 'DynamicAvatar';
  final _avatars = <DynamicAvatar>[];
  bool _loading = true;
  bool _uploading = false;
  bool _equipping = false;
  String? _currentAvatarId;
  int _userVipLevel = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final session = context.read<SessionManager>();
    final user = session.getUser();
    _userVipLevel = _extractVipLevel(user);
    setState(() => _loading = true);
    try {
      final res = await ApiService.getDynamicAvatars(session.userId);
      if (res.status) {
        _avatars.clear();
        _avatars.addAll(res.avatars);
        _currentAvatarId = res.currentAvatarId;
      }
    } catch (e, s) {
      Log.e(_tag, 'loadData failed', e, s);
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

  Future<void> _equipAvatar(DynamicAvatar avatar) async {
    if (_equipping) return;
    if (_userVipLevel < avatar.requiredVipLevel) {
      Fluttertoast.showToast(
        msg: 'Enable VIP ${avatar.requiredVipLevel} to unlock this avatar',
      );
      return;
    }
    setState(() => _equipping = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.equipDynamicAvatar(
        userId: session.userId,
        avatarId: avatar.id ?? '',
      );
      if (res.status) {
        setState(() => _currentAvatarId = avatar.id);
        Fluttertoast.showToast(msg: 'Dynamic avatar equipped!');
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to equip');
      }
    } catch (e, s) {
      Log.e(_tag, 'equipAvatar failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to equip avatar');
    } finally {
      if (mounted) setState(() => _equipping = false);
    }
  }

  Future<void> _uploadGif() async {
    if (_userVipLevel < 5) {
      Fluttertoast.showToast(msg: 'Enable VIP 5 to upload custom avatars');
      return;
    }
    if (_uploading) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      setState(() => _uploading = true);
      final session = context.read<SessionManager>();
      final res = await ApiService.uploadDynamicAvatar(
        userId: session.userId,
        gifFile: File(picked.path),
      );
      if (res.status) {
        Fluttertoast.showToast(msg: 'Avatar uploaded!');
        _loadData();
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Upload failed');
      }
    } catch (e, s) {
      Log.e(_tag, 'uploadGif failed', e, s);
      Fluttertoast.showToast(msg: 'Upload failed');
    } finally {
      if (mounted) setState(() => _uploading = false);
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
              if (_userVipLevel < 5)
                _buildVipLockBanner()
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _uploading ? null : _uploadGif,
                      icon:
                          _uploading
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: Preloader(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.upload, color: Colors.white),
                      label: const Text(
                        'Upload Custom GIF',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child:
                    _loading
                        ? const Center(child: Preloader())
                        : _avatars.isEmpty
                        ? _buildEmpty()
                        : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.8,
                              ),
                          itemCount: _avatars.length,
                          itemBuilder: (context, i) {
                            final avatar = _avatars[i];
                            final isEquipped = _currentAvatarId == avatar.id;
                            final isLocked =
                                _userVipLevel < avatar.requiredVipLevel;
                            return _buildAvatarCard(
                              avatar,
                              isEquipped,
                              isLocked,
                            );
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
                'Dynamic Avatar',
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

  Widget _buildVipLockBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.goldGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.lock_outline, color: Colors.white, size: 40),
          SizedBox(height: 12),
          Text(
            'VIP 5 Required',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Upgrade to VIP 5 to unlock dynamic GIF avatars',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gif_box_outlined, color: Colors.white38, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No avatars available',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _loadData, child: const Text('Refresh')),
        ],
      ),
    );
  }

  Widget _buildAvatarCard(
    DynamicAvatar avatar,
    bool isEquipped,
    bool isLocked,
  ) {
    return GestureDetector(
      onTap: isLocked ? null : () => _equipAvatar(avatar),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
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
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child:
                          (avatar.url != null && avatar.url!.isNotEmpty)
                              ? CachedNetworkImage(
                                imageUrl: VideoUtil.getFullImageUrl(avatar.url),
                                fit: BoxFit.contain,
                                placeholder: (_, __) => const Preloader(),
                                errorWidget:
                                    (_, __, ___) => const Icon(
                                      Icons.broken_image,
                                      color: Colors.white24,
                                      size: 32,
                                    ),
                              )
                              : const Icon(
                                Icons.gif,
                                color: Colors.white24,
                                size: 32,
                              ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      avatar.name ?? 'Avatar',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            if (isEquipped)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.check_circle,
                  color: AppTheme.primary,
                  size: 18,
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
                        const Icon(Icons.lock, color: Colors.white38, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          'VIP ${avatar.requiredVipLevel}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
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
    );
  }
}
