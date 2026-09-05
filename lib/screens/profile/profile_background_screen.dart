/// Profile Background selection screen.
///
/// Ports native `ProfileBackgroundActivity.java`.
/// Shows VIP tier backgrounds + allows uploading a custom image.
/// - VIP privilege check (isProfileBackgroundEnabled / isMultipleProfileBackgroundsEnabled)
/// - Lock dialog for non-VIP users
/// - Save selection to backend via updateUser API
/// - Remove background option
/// - Replace/remove buttons on current background
library profile_background;
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/vip_models.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'ProfileBg';

class ProfileBackgroundScreen extends StatefulWidget {
  const ProfileBackgroundScreen({super.key});

  @override
  State<ProfileBackgroundScreen> createState() => _ProfileBackgroundScreenState();
}

class _ProfileBackgroundScreenState extends State<ProfileBackgroundScreen> {
  List<VipTier> _tiers = [];
  bool _loading = true;
  bool _uploading = false;
  bool _saving = false;
  String? _currentBgUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchVipTiers();
  }

  void _loadUserData() {
    final user = context.read<SessionManager>().getUser();
    if (user != null) {
      _currentBgUrl = user.vipBackgroundImage;
      if (!_hasProfileBackgroundPrivilege()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Fluttertoast.showToast(msg: 'Enable VIP to unlock profile backgrounds');
          }
        });
      }
    }
  }

  bool _hasProfileBackgroundPrivilege() {
    final user = context.read<SessionManager>().getUser();
    if (user == null || !user.isVIP || user.vipDetails == null) return false;
    final vd = user.vipDetails!;
    return vd.isMultipleProfileBackgroundsEnabled || vd.isProfileBackgroundEnabled;
  }

  bool _hasMultiProfileBackgroundPrivilege() {
    final user = context.read<SessionManager>().getUser();
    if (user == null || !user.isVIP || user.vipDetails == null) return false;
    return user.vipDetails!.isMultipleProfileBackgroundsEnabled;
  }

  Future<void> _fetchVipTiers() async {
    try {
      final res = await ApiService.getVipTiers();
      _tiers = res.data.where((t) => (t.profileBackgroundUrl ?? '').isNotEmpty).toList();
    } catch (e, s) {
      Log.e(_tag, 'fetchVipTiers failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickBackgroundImage() async {
    if (!_hasMultiProfileBackgroundPrivilege()) {
      _showLockDialog();
      return;
    }
    final session = context.read<SessionManager>();
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      await ApiService.updateProfileBackground(userId: session.userId, image: File(picked.path));
      if (!mounted) return;
      Fluttertoast.showToast(msg: 'Background uploaded');
      _loadUserData();
      _fetchVipTiers();
    } catch (e, s) {
      Log.e(_tag, 'upload failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to upload');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveBackgroundSelection(String? url) async {
    final session = context.read<SessionManager>();
    final user = session.getUser();
    if (user == null || user.id == null) {
      Fluttertoast.showToast(msg: 'Please login first');
      return;
    }

    setState(() => _saving = true);

    // Update local state immediately
    setState(() => _currentBgUrl = url);

    try {
      final fields = <String, String>{
        'userId': user.id!,
        'vipBackgroundImage': url ?? '',
        'name': user.name ?? '',
        'username': user.username ?? '',
        'bio': user.bio ?? '',
        'gender': user.gender ?? '',
        'age': '${user.age}',
      };
      final res = await ApiService.updateUser(fields: fields);
      if (res.status && res.user != null) {
        session.saveUser(res.user);
        Fluttertoast.showToast(msg: 'Profile background updated');
      } else {
        Fluttertoast.showToast(msg: 'Background updated locally');
      }
      _loadUserData();
    } catch (e) {
      Log.e(_tag, 'saveBackground failed', e);
      Fluttertoast.showToast(msg: 'Network error, saved locally');
      _loadUserData();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showLockDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Profile background', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text('Enable SVIP2 to use/change more background'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pushNamed(AppRoutes.vip);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enable SVIP2'),
          ),
        ],
      ),
    );
  }

  void _selectTierBackground(String url) {
    if (!_hasProfileBackgroundPrivilege()) {
      _showLockDialog();
      return;
    }
    _saveBackgroundSelection(url);
  }

  void _removeBackground() {
    _saveBackgroundSelection(null);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile Background')),
      body: _loading
          ? const Center(child: Preloader())
          : _saving
              ? const Center(child: Preloader())
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _tiers.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) return _currentTile(isDark);
                    final tier = _tiers[i - 1];
                    final url = tier.profileBackgroundUrl!;
                    final isSelected = _currentBgUrl == url;
                    return _bgTile(isDark, url, tier.name ?? 'VIP', isSelected, () {
                      _selectTierBackground(url);
                    });
                  },
                ),
    );
  }

  Widget _currentTile(bool isDark) {
    final hasBg = _currentBgUrl != null && _currentBgUrl!.isNotEmpty;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: hasBg
              ? CachedNetworkImage(
                  imageUrl: _currentBgUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorWidget: (_, __, ___) => Container(
                    color: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
                    child: const Icon(Icons.image, size: 32),
                  ),
                )
              : Container(
                  color: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
                  child: const Center(
                    child: Icon(Icons.wallpaper, size: 40, color: Colors.grey),
                  ),
                ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
              ),
            ),
            child: const Text(
              'Current',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        // Replace button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _uploading ? null : _pickBackgroundImage,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: Preloader(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
            ),
          ),
        ),
        // Remove button
        if (hasBg)
          Positioned(
            top: 8,
            left: 8,
            child: GestureDetector(
              onTap: _removeBackground,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete, color: Colors.white, size: 18),
              ),
            ),
          ),
      ],
    );
  }

  Widget _bgTile(bool isDark, String url, String label, bool isSelected, VoidCallback onTap) {
    final hasPrivilege = _hasProfileBackgroundPrivilege();
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorWidget: (_, __, ___) => Container(
                color: isDark ? AppTheme.surfaceLight : AppTheme.lightBg,
                child: const Icon(Icons.image, size: 32),
              ),
            ),
          ),
          // Lock overlay if no privilege
          if (!hasPrivilege)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(Icons.lock, color: Colors.white70, size: 32),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

