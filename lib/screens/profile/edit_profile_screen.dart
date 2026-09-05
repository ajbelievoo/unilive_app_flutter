import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../constants/const.dart';
import '../../models/user_root.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../widgets/profile_badge_row.dart';
import '../../widgets/svga_player_widget.dart';
import '../../utils/media_utils.dart';
import 'package:belive/widgets/preloader.dart';

/// Ported from native `EditProfileActivity.java`.
///
/// Shown after first login when the user has no username/gender. The user
/// picks a profile image, enters a username, selects a gender, and submits.
/// On success we mark the user logged-in and route to main.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const String _tag = 'EditProfile';

  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _bankDetailsCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();
  String _gender = '';
  String _relationship = 'Single';
  File? _avatar;
  String? _avatarUrl;
  File? _cover;
  String? _coverUrl;
  File? _profileBg;
  bool _saving = false;
  bool _hideContact = false;

  final _relationships = ['Single', 'In a Relationship', 'Married', 'Divorced', 'Complicated'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _ageCtrl.dispose();
    _countryCtrl.dispose();
    _cityCtrl.dispose();
    _websiteCtrl.dispose();
    _birthDateCtrl.dispose();
    _bankDetailsCtrl.dispose();
    _statusCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill from existing user data so the form is editable, not blank.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final u = context.read<SessionManager>().getUser();
      final authProvider = context.read<AuthProvider>();
      if (u == null) return;
      _prefillFromUser(u);
      // Refresh in the background so fields that were missing from the
      // cached user (e.g. because /user/getUser previously dropped them)
      // get filled once the backend returns them.
      try {
        final refreshed = await authProvider.refreshUser();
        if (refreshed != null && mounted) {
          _prefillEmptyFromUser(refreshed);
          Log.d(_tag, 'initState refresh: name=${refreshed.name}, '
              'bio=${refreshed.bio}, birthDate=${refreshed.birthDate}, '
              'city=${refreshed.city}, website=${refreshed.website}, '
              'statusText=${refreshed.statusText}, bankDetails=${refreshed.bankDetails}, '
              'image=${refreshed.image}, coverImage=${refreshed.coverImage}');
        }
      } catch (e, s) {
        Log.e(_tag, 'initState refresh failed', e, s);
      }
    });
  }

  /// Fill all form controllers from [u].
  void _prefillFromUser(User u) {
    _nameCtrl.text = (u.name?.isNotEmpty == true ? u.name! : u.username) ?? '';
    _bioCtrl.text = u.bio ?? '';
    _ageCtrl.text = u.age > 0 ? u.age.toString() : '';
    _countryCtrl.text = u.country ?? '';
    _cityCtrl.text = u.city ?? '';
    _websiteCtrl.text = u.website ?? '';
    _birthDateCtrl.text = u.birthDate ?? '';
    _statusCtrl.text = u.statusText ?? '';
    _bankDetailsCtrl.text = u.bankDetails ?? '';
    _gender = u.gender ?? '';
    _relationship = u.relationship?.isNotEmpty == true ? u.relationship! : 'Single';
    _hideContact = !u.showPhonePublic;
    if (mounted) setState(() {});
  }

  /// Update only empty controllers from [u] so we don't overwrite text the
  /// user may have typed before the API response arrives.
  void _prefillEmptyFromUser(User u) {
    if (_bioCtrl.text.isEmpty && u.bio?.isNotEmpty == true) _bioCtrl.text = u.bio!;
    if (_ageCtrl.text.isEmpty && u.age > 0) _ageCtrl.text = u.age.toString();
    if (_countryCtrl.text.isEmpty && u.country?.isNotEmpty == true) _countryCtrl.text = u.country!;
    if (_cityCtrl.text.isEmpty && u.city?.isNotEmpty == true) _cityCtrl.text = u.city!;
    if (_websiteCtrl.text.isEmpty && u.website?.isNotEmpty == true) _websiteCtrl.text = u.website!;
    if (_birthDateCtrl.text.isEmpty && u.birthDate?.isNotEmpty == true) _birthDateCtrl.text = u.birthDate!;
    if (_statusCtrl.text.isEmpty && u.statusText?.isNotEmpty == true) _statusCtrl.text = u.statusText!;
    if (_bankDetailsCtrl.text.isEmpty && u.bankDetails?.isNotEmpty == true) _bankDetailsCtrl.text = u.bankDetails!;
    if (_gender.isEmpty && u.gender?.isNotEmpty == true) _gender = u.gender!;
    if (_relationship == 'Single' && u.relationship?.isNotEmpty == true) _relationship = u.relationship!;
    if (!_hideContact && !u.showPhonePublic) _hideContact = true;
    if (mounted) setState(() {});
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x == null) return;
    // Try cropping; if cropper fails or is cancelled, use the original image.
    File? result = File(x.path);
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: x.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Avatar',
            toolbarColor: AppTheme.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Avatar',
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      if (cropped != null) result = File(cropped.path);
    } catch (e) {
      Log.e(_tag, 'cropImage failed, using original', e);
    }
    if (mounted) setState(() {
      _avatar = result;
      _avatarUrl = null;
    });
  }

  Future<void> _pickCoverFromGallery() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x != null) setState(() {
      _cover = File(x.path);
      _coverUrl = null;
    });
  }

  Future<void> _useVipCover() async {
    final user = context.read<SessionManager>().getUser();
    final vipCover = user?.vipDetails?.backgroundImage ??
        user?.vipDetails?.profileBackgroundUrl ??
        user?.vipBackgroundImage ??
        user?.profileBackgroundImage;
    if (vipCover == null || vipCover.isEmpty) {
      Fluttertoast.showToast(msg: 'No VIP cover available');
      return;
    }
    setState(() {
      _coverUrl = vipCover;
      _cover = null;
    });
  }

  Future<void> _pickCover() async {
    final user = context.read<SessionManager>().getUser();
    final isVip = user?.isVIP ?? false;
    if (!isVip) {
      Fluttertoast.showToast(msg: 'Cover upload is available for VIP users only');
      return;
    }
    final hasVipCover = (user?.vipDetails?.backgroundImage?.isNotEmpty == true) ||
        (user?.vipBackgroundImage?.isNotEmpty == true);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Cover Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 16),
              _coverOptionTile(Icons.photo_library, 'Gallery', 'Pick from your phone', () {
                Navigator.pop(ctx);
                _pickCoverFromGallery();
              }),
              if (hasVipCover) ...[
                const SizedBox(height: 8),
                _coverOptionTile(Icons.stars, 'VIP Cover', 'Use your VIP plan cover', () {
                  Navigator.pop(ctx);
                  _useVipCover();
                }),
              ],
              const SizedBox(height: 8),
              _coverOptionTile(Icons.delete_outline, 'Remove Cover', 'Use default gradient', () {
                setState(() {
                  _cover = null;
                  _coverUrl = '';
                });
                Navigator.pop(ctx);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverOptionTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: () {
        onTap();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: const Color(0xFFF6F5FB),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, color: AppTheme.primary, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E), fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF9A9AB0)),
    );
  }

  Future<void> _pickProfileBackground() async {
    final user = context.read<SessionManager>().getUser();
    if (user == null || !user.isVIP) {
      Fluttertoast.showToast(msg: 'Profile background is available for VIP users only');
      return;
    }
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    if (!mounted) return;
    setState(() => _profileBg = File(x.path));
    // Upload immediately via updateProfileBackground API
    final authProvider = context.read<AuthProvider>();
    Fluttertoast.showToast(msg: 'Uploading background...');
    try {
      final res = await ApiService.updateProfileBackground(
        userId: user.id ?? '',
        image: File(x.path),
      );
      if (res.status) {
        Fluttertoast.showToast(msg: 'Profile background updated');
        // Refresh the cached user so profileBackgroundImage is updated
        // and the edit screen shows the saved background on next open.
        if (mounted) {
          await authProvider.refreshUser();
        }
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed');
      }
    } catch (e) {
      Log.e(_tag, 'updateProfileBackground failed', e);
      Fluttertoast.showToast(msg: 'Failed to update background');
    }
  }

  Widget _buildCoverPreview(String url) {
    final fullUrl = VideoUtil.getFullImageUrl(url);
    if (fullUrl.isEmpty) return const SizedBox.shrink();
    if (SvgaHelper.isSvgaUrl(fullUrl)) {
      return LayoutBuilder(
        builder: (context, constraints) => SvgaPlayer(
          url: fullUrl,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          fit: BoxFit.cover,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: fullUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => const SizedBox.shrink(),
      errorWidget: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  /// Merges an update response into the existing user object. The backend
  /// update endpoint often returns a partial user (only the changed text
  /// fields and images), so we keep all VIP/level/badge/family fields from
  /// the original user to prevent the frame, VIP badge, etc. from disappearing.
  User _mergeProfileUpdate(User existing, User updated) {
    final existingJson = existing.toJson();
    final updatedJson = updated.toJson();
    final merged = Map<String, dynamic>.from(existingJson);
    // Only overwrite the keys that the profile update may change.
    // All other fields (isVIP, level, vipDetails, avatarFrameImage,
    // familyImage, badges) are preserved from [existing].
    const keysToUpdate = [
      'name', 'username', 'image', 'coverImage', 'bio', 'gender', 'age',
      'country', 'city', 'website', 'birthDate', 'relationship', 'statusText',
      'bankDetails', 'showPhonePublic', 'showEmailPublic', 'updatedAt',
    ];
    for (final key in keysToUpdate) {
      final value = updatedJson[key];
      if (value != null && (value is! String || value.isNotEmpty)) {
        merged[key] = value;
      }
    }
    return User.fromJson(merged);
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Fluttertoast.showToast(msg: 'Enter name');
      return;
    }
    if (_gender.isEmpty) {
      Fluttertoast.showToast(msg: 'Select gender');
      return;
    }
    setState(() => _saving = true);
    try {
      final session = context.read<SessionManager>();
      final authProvider = context.read<AuthProvider>();
      final user = session.getUser();
      if (user == null) {
        Fluttertoast.showToast(msg: 'Session expired');
        return;
      }
      // Upload avatar/cover to the generic upload endpoint first. Some backends
      // expect /user/update to receive the URL, not a raw multipart file.
      String? uploadedAvatarUrl;
      String? uploadedCoverUrl;
      if (_avatar != null) {
        uploadedAvatarUrl = await ImageUploadUtil.uploadImage(
          file: _avatar!,
          userId: user.id ?? '',
        );
      }
      if (_cover != null) {
        uploadedCoverUrl = await ImageUploadUtil.uploadImage(
          file: _cover!,
          userId: user.id ?? '',
        );
      }
      // If user picked a VIP cover URL, use it directly. Empty string means remove cover.
      if (_coverUrl != null) uploadedCoverUrl = _coverUrl;

      Log.d(_tag, 'updateUser: name=$name, gender=$_gender, '
          'avatar=${uploadedAvatarUrl ?? _avatar?.path ?? "null"}, '
          'cover=${uploadedCoverUrl ?? _cover?.path ?? _coverUrl ?? "null"}');
      final res = await ApiService.updateUser(
        fields: {
          'userId': user.id ?? '',
          'name': name,
          'username': name,
          'gender': _gender,
          'bio': _bioCtrl.text.trim(),
          'age': _ageCtrl.text.trim().isEmpty ? '18' : _ageCtrl.text.trim(),
          'country': _countryCtrl.text.trim().isEmpty ? (session.getCountry().isNotEmpty ? session.getCountry() : 'India') : _countryCtrl.text.trim(),
          'city': _cityCtrl.text.trim().isEmpty ? (session.getCity().isNotEmpty ? session.getCity() : '') : _cityCtrl.text.trim(),
          'website': _websiteCtrl.text.trim(),
          'birthDate': _birthDateCtrl.text.trim(),
          'relationship': _relationship,
          'statusText': _statusCtrl.text.trim(),
          'showPhonePublic': (!_hideContact).toString(),
          'showEmailPublic': (!_hideContact).toString(),
          if (user.isHost == true) 'bankDetails': _bankDetailsCtrl.text.trim(),
        },
        avatarFile: uploadedAvatarUrl == null ? _avatar : null,
        avatarUrl: uploadedAvatarUrl,
        coverFile: uploadedCoverUrl == null ? _cover : null,
        coverUrl: uploadedCoverUrl,
      );
      Log.d(_tag, 'updateUser response: status=${res.status}, '
          'message=${res.message}, '
          'userImage=${res.user?.image}, '
          'userCover=${res.user?.coverImage}, '
          'bio=${res.user?.bio}, city=${res.user?.city}, '
          'website=${res.user?.website}, birthDate=${res.user?.birthDate}, '
          'statusText=${res.user?.statusText}, bankDetails=${res.user?.bankDetails}, '
          'relationship=${res.user?.relationship}');
      if (res.status) {
        if (res.user != null) {
          // Use AuthProvider.setUser() instead of session.saveUser() so that
          // notifyListeners() fires and the ProfileScreen rebuilds with the
          // updated data when we pop back. Merge so VIP/level/badges don't
          // disappear if the backend response is missing them.
          authProvider.setUser(_mergeProfileUpdate(user, res.user!));
        } else {
          // Some backends return status without the user object; refresh.
          await authProvider.refreshUser();
        }
        // Clear picked files so the UI reflects the saved (server) state.
        if (mounted) setState(() {
          _avatar = null;
          _avatarUrl = null;
          _cover = null;
          _coverUrl = null;
        });
        Fluttertoast.showToast(msg: 'Profile updated');
        if (!mounted) return;
        // If the user is already logged in (editing from profile), just pop back.
        // Otherwise (first-time completion), proceed to main.
        if (authProvider.isLoggedIn) {
          Navigator.of(context).maybePop();
        } else {
          authProvider.markLoggedIn();
          context.replaceNamed(AppRoutes.main);
        }
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Update failed');
      }
    } catch (e, s) {
      Log.e(_tag, 'updateUser failed', e, s);
      Fluttertoast.showToast(msg: 'Update failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionManager>();
    final user = session.getUser();
    final isVip = user?.isVIP ?? false;
    final existingAvatar = user?.image ?? '';
    final existingCover = user?.coverImage ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5FB),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover photo with gradient + avatar overlapping
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover
                GestureDetector(
                  onTap: _pickCover,
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background: gradient by default; image/SVGA when selected.
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF7B61FF), Color(0xFF4F8DFD), Color(0xFFFF6B9D)],
                            ),
                          ),
                          child: _cover != null
                              ? Image.file(_cover!, fit: BoxFit.cover)
                              : (_coverUrl?.isNotEmpty == true
                                  ? _buildCoverPreview(_coverUrl!)
                                  : (_coverUrl == null && existingCover.isNotEmpty
                                      ? _buildCoverPreview(existingCover)
                                      : null)),
                        ),
                        // Dark gradient overlay + camera chip.
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.35)],
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Visibility(
                                visible: isVip,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text('Cover', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Avatar overlapping cover
                Positioned(
                  left: 0,
                  right: 0,
                  top: 140,
                  child: Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFF7B61FF)]),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7B61FF).withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF6F5FB),
                            shape: BoxShape.circle,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 56,
                                backgroundColor: const Color(0xFFE8E8F5),
                                backgroundImage: _avatar != null
                                    ? FileImage(_avatar!)
                                    : (existingAvatar.isNotEmpty
                                        ? CachedNetworkImageProvider(VideoUtil.getFullImageUrl(existingAvatar))
                                        : null),
                                child: _avatar == null && existingAvatar.isEmpty
                                    ? const Icon(Icons.camera_alt, size: 30, color: Color(0xFF9A9AB0))
                                    : null,
                              ),
                              // Camera badge so users know the avatar is tappable
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF6A5AE0),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1),
                                    ],
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 70),

            // Form card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6A5AE0).withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionLabel('Your Badges'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F5FB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Preview',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
                          ),
                          const SizedBox(height: 8),
                          ProfileBadgeRow.fromUser(user ?? User(), isDark: false),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionLabel('Basic Info'),
                    const SizedBox(height: 14),
                    _premiumField(_nameCtrl, 'Name', Icons.person_outline_rounded),
                    const SizedBox(height: 12),
                    _premiumField(_bioCtrl, 'Bio', Icons.info_outline_rounded, maxLines: 3),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _genderChip(Const.male, Icons.male)),
                        const SizedBox(width: 12),
                        Expanded(child: _genderChip(Const.female, Icons.female)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _premiumField(_ageCtrl, 'Age', Icons.cake_outlined, keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _relationship,
                      decoration: _premiumInputDecoration('Relationship', Icons.favorite_outline),
                      items: _relationships.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setState(() => _relationship = v ?? _relationship),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _birthDateCtrl,
                      readOnly: true,
                      decoration: _premiumInputDecoration('Birth Date', Icons.calendar_today_outlined),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime(2000),
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          _birthDateCtrl.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        }
                      },
                    ),

                    const SizedBox(height: 24),
                    _sectionLabel('Location'),
                    const SizedBox(height: 14),
                    _premiumField(_countryCtrl, 'Country', Icons.public, hintText: session.getCountry()),
                    const SizedBox(height: 12),
                    _premiumField(_cityCtrl, 'City', Icons.location_city_outlined, hintText: session.getCity()),

                    const SizedBox(height: 24),
                    _sectionLabel('Extra'),
                    const SizedBox(height: 14),
                    _premiumField(_websiteCtrl, 'Website', Icons.language, keyboardType: TextInputType.url),
                    const SizedBox(height: 12),
                    _premiumField(_statusCtrl, 'Status Text', Icons.tag),

                    const SizedBox(height: 16),
                    // Profile background (VIP feature)
                    GestureDetector(
                      onTap: _pickProfileBackground,
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1976D2)]),
                          borderRadius: BorderRadius.circular(16),
                          image: _profileBg != null ? DecorationImage(image: FileImage(_profileBg!), fit: BoxFit.cover) : null,
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wallpaper, size: 22, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Profile Background (VIP)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Family badge
                    if (user?.family != null && user!.family!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: AppTheme.purpleGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(children: [
                          const Icon(Icons.family_restroom, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Family', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                Text(user.family!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.pushNamed(AppRoutes.family),
                            child: const Text('View', style: TextStyle(color: Colors.white)),
                          ),
                        ]),
                      )
                    else
                      GestureDetector(
                        onTap: () => context.pushNamed(AppRoutes.family),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F1FA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Row(children: [
                            Icon(Icons.family_restroom, color: AppTheme.primary),
                            SizedBox(width: 10),
                            Text('Join a Family', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                            Spacer(),
                            Icon(Icons.chevron_right, color: AppTheme.primary),
                          ]),
                        ),
                      ),

                    const SizedBox(height: 16),
                    if (user?.isHost ?? false) ...[
                      _premiumField(_bankDetailsCtrl, 'Bank Details (host payouts)', Icons.account_balance_outlined, maxLines: 2),
                      const SizedBox(height: 12),
                    ],
                    SwitchListTile(
                      title: const Text('Hide my contact info', style: TextStyle(fontWeight: FontWeight.w600)),
                      value: _hideContact,
                      onChanged: (v) => setState(() => _hideContact = v),
                      activeColor: AppTheme.primary,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            // Save button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: GestureDetector(
                onTap: _saving ? null : _submit,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFF4F8DFD)]),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6A5AE0).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: Preloader(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E), letterSpacing: 0.3),
    );
  }

  InputDecoration _premiumInputDecoration(String label, IconData icon, {String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(icon, color: const Color(0xFF6A5AE0), size: 20),
      filled: true,
      fillColor: const Color(0xFFF6F5FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: const Color(0xFF6A5AE0).withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6A5AE0), width: 1.5),
      ),
      labelStyle: const TextStyle(color: Color(0xFF6B6B80), fontWeight: FontWeight.w500),
    );
  }

  Widget _premiumField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hintText,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _premiumInputDecoration(label, icon, hintText: hintText),
    );
  }

  Widget _genderChip(String label, IconData icon) {
    final selected = _gender == label;
    return GestureDetector(
      onTap: () => setState(() => _gender = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFF4F8DFD)])
              : null,
          color: selected ? null : const Color(0xFFF1F1FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFF6A5AE0).withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : const Color(0xFF6A5AE0)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF1A1A2E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
