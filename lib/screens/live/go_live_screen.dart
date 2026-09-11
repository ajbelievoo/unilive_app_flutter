/// Premium Go Live host setup screen.
///
/// Full-screen camera preview, dark neon overlay controls,
/// stream quality, and beauty settings that carry into the live room.
library go_live;

import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart'
    show LighteningContrastLevel;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/host_compliance_models.dart';
import '../../models/kyc_models.dart';
import '../../services/api_service.dart';
import '../../services/host_presence_guard_service.dart';
import '../../services/session_manager.dart';
import '../../services/socket_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {
  static const String _tag = 'GoLive';
  static const String _prefTitle = 'golive_room_title';
  static const String _prefWelcome = 'golive_room_welcome';
  static const String _prefCover = 'golive_room_cover';
  static const String _prefPublic = 'golive_is_public';

  final _titleCtrl = TextEditingController();
  final _welcomeCtrl = TextEditingController();
  final _passcodeCtrl = TextEditingController();
  bool _isPublic = true;
  bool _starting = false;
  String _quality = 'hd';

  double _smoothness = 0.0;
  double _lightening = 0.0;
  double _redness = 0.0;
  LighteningContrastLevel _lighteningContrast =
      LighteningContrastLevel.lighteningContrastNormal;

  CameraController? _cameraCtrl;
  bool _cameraReady = false;
  String? _cameraError;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  File? _coverImage;

  @override
  void initState() {
    super.initState();
    _loadSavedFields();
    _initCamera();
  }

  Future<void> _loadSavedFields() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString(_prefTitle) ?? '';
    final welcome = prefs.getString(_prefWelcome) ?? '';
    final isPublic = prefs.getBool(_prefPublic) ?? true;
    final coverPath = prefs.getString(_prefCover) ?? '';
    if (!mounted) return;
    setState(() {
      _titleCtrl.text = title;
      _welcomeCtrl.text = welcome;
      _isPublic = isPublic;
      // Reuse the previously uploaded cover — no need to upload every time.
      // The user can change it explicitly by tapping the cover tile.
      if (coverPath.isNotEmpty && File(coverPath).existsSync()) {
        _coverImage = File(coverPath);
      }
    });
  }

  Future<void> _saveFields() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTitle, _titleCtrl.text.trim());
    await prefs.setString(_prefWelcome, _welcomeCtrl.text.trim());
    await prefs.setBool(_prefPublic, _isPublic);
    if (_coverImage != null) {
      await prefs.setString(_prefCover, _coverImage!.path);
    } else {
      await prefs.remove(_prefCover);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _welcomeCtrl.dispose();
    _passcodeCtrl.dispose();
    _cameraCtrl?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final status = await Permission.camera.status;
      if (status.isDenied || status.isRestricted) {
        final result = await Permission.camera.request();
        if (!result.isGranted) {
          if (mounted) {
            setState(
              () => _cameraError = 'Camera permission needed to preview',
            );
          }
          return;
        }
      }
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() => _cameraError = 'No camera found');
        }
        return;
      }
      final target = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
      _cameraIndex = _cameras.indexOf(target);
      final controller = CameraController(
        target,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      await controller.initialize();
      if (mounted) {
        setState(() {
          _cameraCtrl = controller;
          _cameraReady = true;
        });
      } else {
        controller.dispose();
      }
    } catch (e, s) {
      Log.e(_tag, 'camera preview init failed', e, s);
      if (mounted) setState(() => _cameraError = 'Camera preview unavailable');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      Fluttertoast.showToast(msg: 'No other camera found');
      return;
    }
    final old = _cameraCtrl;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    final next = _cameras[_cameraIndex];
    final controller = CameraController(
      next,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      if (mounted) {
        setState(() => _cameraCtrl = controller);
      } else {
        controller.dispose();
      }
    } catch (e, s) {
      Log.e(_tag, 'switch camera failed', e, s);
      if (mounted) setState(() => _cameraError = 'Switch failed');
    } finally {
      old?.dispose();
    }
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<Object?>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Cover Photo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Color(0xFF7E3FF2),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera,
                    color: Color(0xFF7E3FF2),
                  ),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                if (_coverImage != null)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.redAccent),
                    title: const Text(
                      'Remove Cover',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () => Navigator.pop(ctx, 'remove'),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
    if (source == 'remove') {
      setState(() => _coverImage = null);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefCover);
      return;
    }
    if (source is! ImageSource) return;
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked != null) {
      try {
        // Copy to the app's own folder so the cover persists across sessions
        // (image_picker returns a cache path that can be cleaned by the OS).
        final dir = await getApplicationDocumentsDirectory();
        final savedPath =
            '${dir.path}/golive_cover${picked.name.substring(picked.name.lastIndexOf('.'))}';
        final savedFile = await File(picked.path).copy(savedPath);
        setState(() => _coverImage = savedFile);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefCover, savedFile.path);
      } catch (e) {
        setState(() => _coverImage = File(picked.path));
      }
    }
  }

  Future<bool> _blockIfPresenceBanned(String userId) async {
    HostPresenceBanInfo? localBan;
    HostComplianceBanStatus? backendStatus;
    var backendAvailable = false;
    var backendBanned = false;

    try {
      localBan = await HostPresenceGuardService.persistedBanForUser(userId);
    } catch (e) {
      Log.w(_tag, 'local presence ban check failed: $e');
    }

    try {
      backendStatus = await ApiService.getHostComplianceBanStatus(userId);
      backendAvailable = true;
      backendBanned = backendStatus.isLiveBanned == true;
    } catch (e) {
      Log.w(_tag, 'backend presence ban check failed: $e');
    }

    if (!mounted) return true;

    // Backend is the source of truth. If it says the user is not banned,
    // clear any stale local presence ban (e.g. after an admin unban) and
    // allow them to go live.
    if (backendAvailable && !backendBanned) {
      if (localBan != null) {
        try {
          await HostPresenceGuardService.clearPersistedBanForUser(userId);
        } catch (e) {
          Log.w(_tag, 'failed to clear stale local presence ban: $e');
        }
      }
      return false;
    }

    final localActive = localBan?.isActive() ?? false;
    if (!localActive && !backendBanned) return false;

    final remainingMinutes =
        localBan == null ? null : (localBan.remainingMs() / 60000).ceil();
    final localPenalty =
        localBan?.tier == HostPresenceBanTier.second
            ? ' Today\'s task rewards and earnings are forfeited.'
            : '';
    final backendMessage = backendStatus?.message ?? backendStatus?.ban?.reason;

    final String message;
    if (backendAvailable && backendBanned && backendMessage != null) {
      message = backendMessage;
    } else if (localBan != null) {
      message =
          'Your Host ID is blocked for $remainingMinutes more minute'
          '${remainingMinutes == 1 ? '' : 's'} after presence violation '
          '#${localBan.dailyViolationCount} today.$localPenalty';
    } else {
      message =
          backendMessage ??
          'Your Host ID is temporarily blocked from streaming.';
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Streaming blocked'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
    );
    return true;
  }

  Future<void> _startLive() async {
    if (_titleCtrl.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'Enter room title');
      return;
    }
    if (_coverImage == null) {
      Fluttertoast.showToast(
        msg: 'Please add a cover photo to go live',
        backgroundColor: Colors.redAccent,
      );
      _pickCover();
      return;
    }
    if (!mounted) return;
    final session = context.read<SessionManager>();
    if (await _blockIfPresenceBanned(session.userId)) return;
    if (!mounted) return;
    setState(() => _starting = true);
    // Dispose camera after state update to avoid race condition.
    final cam = _cameraCtrl;
    _cameraCtrl = null;
    await cam?.dispose();
    if (!mounted) return;
    await _saveFields();

    // ---- KYC + Host approval gate ----------------------------------------
    // Before going live, check if the user is verified and host-approved.
    // The backend enforces this too, but we check client-side to give the
    // user a clear message and redirect to KYC instead of a cryptic error.
    try {
      final liveCheck = await ApiService.getKycLiveCheck(
        userId: session.userId,
      );
      if (!liveCheck.canGoLive) {
        if (mounted) {
          setState(() => _starting = false);
          _showKycGateDialog(liveCheck);
        }
        return;
      }
    } catch (e) {
      // If the check fails (network error, endpoint not ready), proceed —
      // the backend will reject if the user isn't allowed.
      Log.w(_tag, 'KYC live check failed, proceeding: $e');
    }

    try {
      await [Permission.camera, Permission.microphone].request();
      final agoraUID = Random().nextInt(999999) + 100000;
      final res = await ApiService.makeLiveStream(
        userId: session.userId,
        roomName: _titleCtrl.text.trim(),
        channel: session.userId,
        agoraUID: agoraUID,
        roomWelcome: _welcomeCtrl.text.trim(),
        isPublic: _isPublic,
        roomImage: _coverImage,
      );
      if (res.status && res.user != null) {
        if (!_isPublic && _passcodeCtrl.text.isNotEmpty) {
          try {
            await ApiService.updatePasscode(
              liveUserId: res.user!.id ?? '',
              privateCode: _passcodeCtrl.text.trim(),
            );
          } catch (e) {
            Log.e(_tag, 'updatePasscode failed', e);
          }
        }
        if (!SocketService.instance.isConnected) {
          await SocketService.instance.connect(
            session.userId,
            authToken: session.token,
          );
        }
        if (mounted) {
          context.replaceNamed(
            'liveRoom',
            extra: {
              'liveUser': res.user!,
              'isHost': true,
              'quality': _quality,
              'smoothness': _smoothness,
              'lightening': _lightening,
              'redness': _redness,
              'lighteningContrast': _lighteningContrast,
            },
          );
        }
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to go live');
      }
    } catch (e, s) {
      Log.e(_tag, 'startLive failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to go live');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Show a dialog explaining why the user can't go live, with a button
  /// to navigate to the KYC verification screen.
  void _showKycGateDialog(KycLiveCheck check) {
    final IconData icon;
    final String title;
    final String actionLabel;
    final VoidCallback? onAction;

    if (check.reason == KycLiveCheck.reasonHostNotApproved ||
        check.reason == KycLiveCheck.reasonHostNoRequest) {
      icon = Icons.record_voice_over_outlined;
      title = 'Host Approval Required';
      actionLabel = 'OK';
      onAction = null;
    } else if (check.reason == KycLiveCheck.reasonKycPending) {
      icon = Icons.hourglass_top_rounded;
      title = 'KYC Under Review';
      actionLabel = 'Check Status';
      onAction = () => context.pushNamed('kycStatus');
    } else if (check.reason == KycLiveCheck.reasonKycRejected) {
      icon = Icons.cancel_rounded;
      title = 'KYC Rejected';
      actionLabel = 'Re-apply';
      onAction = () => context.pushNamed('kyc');
    } else {
      // kyc_required or default
      icon = Icons.verified_user_outlined;
      title = 'KYC Verification Required';
      actionLabel = 'Verify Now';
      onAction = () => context.pushNamed('kyc');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            title: Row(
              children: [
                Icon(icon, color: const Color(0xFF6A5AE0), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              check.message ??
                  'You need to complete KYC verification before going live.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B6B80),
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
              if (onAction != null)
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onAction!();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6A5AE0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(actionLabel),
                ),
            ],
          ),
    );
  }

  void _showBeautySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => _GoLiveBeautySheet(
            smoothness: _smoothness,
            lightening: _lightening,
            redness: _redness,
            lighteningContrast: _lighteningContrast,
            onChanged:
                (s, l, r, c) => setState(() {
                  _smoothness = s;
                  _lightening = l;
                  _redness = r;
                  _lighteningContrast = c;
                }),
          ),
    );
  }

  /// Frosted-glass cover tile with gradient border glow when empty.
  Widget _buildCoverTile() {
    final hasCover = _coverImage != null;
    return Padding(
      padding: const EdgeInsets.all(5),
      child: GestureDetector(
        onTap: _pickCover,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 80,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient:
                    hasCover
                        ? null
                        : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0x20FF8BBF), Color(0x104F8DFD)],
                        ),
                border: Border.all(
                  color:
                      hasCover
                          ? Colors.transparent
                          : const Color(0xB3FF8BBF),
                  width: 1.2,
                ),
                boxShadow:
                    hasCover
                        ? null
                        : const [
                          BoxShadow(
                            color: Color(0x40FF8BBF),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
              ),
              child:
                  hasCover
                      ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _coverImage!,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 100,
                        ),
                      )
                      : const Center(
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Color(0xB3FF8BBF),
                          size: 30,
                        ),
                      ),
            ),
            // Bottom label strip
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                    child: const Center(
                      child: Text(
                        'Cover *',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (hasCover)
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => setState(() => _coverImage = null),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Frosted-glass panel with gradient border and subtle glow.
  Widget _glassCard({required Widget child, double radius = 16}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xB30D0D1A), Color(0x8514142A)],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F8DFD).withValues(alpha: 0.12),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  /// Frosted-glass pill option for Room Type / Stream Quality.
  Widget _typePill(
    IconData icon,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    const pink = Color(0xFFFF8BBF);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient:
              selected
                  ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x35FF8BBF), Color(0x204F8DFD)],
                  )
                  : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xB30D0D1A), Color(0x8014142A)],
                  ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? pink : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1,
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: const Color(0xFFFF8BBF).withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? pink : const Color(0xB3FF8BBF),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? pink : const Color(0xCCFF8BBF),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Glassmorphic right-side tool with gradient ring glow on tap.
  Widget _sideTool(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x40000000), Color(0x201A1A2E)],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B61FF).withValues(alpha: 0.2),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Center(
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleIcon(
    IconData icon,
    VoidCallback onTap, {
    String? tooltip,
    double size = 18,
  }) {
    final child = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x40000000), Color(0x201A1A2E)],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B61FF).withValues(alpha: 0.2),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Icon(icon, color: Colors.white, size: size),
          ),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: child) : child;
  }

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => AnimatedPadding(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: _GoLiveOptionsSheet(
                titleCtrl: _titleCtrl,
                welcomeCtrl: _welcomeCtrl,
                passcodeCtrl: _passcodeCtrl,
                isPublic: _isPublic,
                onUpdate:
                    (isPublic) => setState(() {
                      _isPublic = isPublic;
                    }),
              ),
            ),
          ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _cameraCtrl;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(child: Preloader(color: Colors.white)),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final scale =
            1 / (controller.value.aspectRatio * size.width / size.height);
        return ClipRect(
          child: OverflowBox(
            maxWidth: size.width,
            maxHeight: size.height,
            child: Transform.scale(
              scale: scale,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionManager>();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen camera preview
          _cameraReady && _cameraCtrl != null
              ? _buildCameraPreview()
              : Container(
                color: const Color(0xFF0A0A1A),
                child:
                    _cameraError != null
                        ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.videocam_off,
                                color: Colors.white38,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _cameraError!,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                        : const Center(child: Preloader(color: Colors.white)),
              ),
          // Gradient overlays — top + bottom
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.2, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // ---- Top bar ----
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _circleIcon(
                      Icons.arrow_back_ios_new,
                      () => Navigator.pop(context),
                      size: 16,
                    ),
                    const SizedBox(width: 12),
                    // Host pill — frosted glass
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            const Color(0x201A1A2E),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundImage:
                                session.userImage.isNotEmpty
                                    ? NetworkImage(session.userImage)
                                    : null,
                            backgroundColor: AppTheme.primary.withValues(
                              alpha: 0.3,
                            ),
                            child:
                                session.userImage.isEmpty
                                    ? const Icon(
                                      Icons.person,
                                      size: 18,
                                      color: Colors.white,
                                    )
                                    : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            session.userName.isNotEmpty
                                ? session.userName
                                : 'Host',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
          // ---- LIVE preview badge (top center) ----
          Positioned(
            top: 64,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: _titleCtrl.text.isNotEmpty ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF7B61FF).withValues(alpha: 0.85),
                            const Color(0xFF4F8DFD).withValues(alpha: 0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.55),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fiber_manual_record,
                            color: Colors.white,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ---- Setup panel (premium glassmorphism style) ----
          Positioned(
            top: MediaQuery.of(context).viewPadding.top + 58,
            left: 15,
            right: 15,
            bottom: 120,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cover + title card
                    _glassCard(
                      radius: 16,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCoverTile(),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                10,
                                10,
                                12,
                                10,
                              ),
                              child: TextField(
                                controller: _titleCtrl,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLength: 30,
                                maxLines: 3,
                                minLines: 1,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  hintText: 'Click to input a Room Title',
                                  hintStyle: TextStyle(
                                    color: Color(0xB3FF8BBF),
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                  counterText: '',
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Room Description',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _glassCard(
                      radius: 16,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        child: TextField(
                          controller: _welcomeCtrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 3,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            hintText: 'Enter your room description',
                            hintStyle: TextStyle(
                              color: Color(0xB3FF8BBF),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            counterStyle: TextStyle(
                              color: Color(0xB3FF8BBF),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Room Type',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _typePill(Icons.public, 'Public', _isPublic, () {
                          setState(() => _isPublic = true);
                        }),
                        const SizedBox(width: 14),
                        _typePill(Icons.lock_outline, 'Private', !_isPublic, () {
                          setState(() => _isPublic = false);
                        }),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Stream Quality',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _typePill(
                          Icons.sd_outlined,
                          'SD',
                          _quality == 'sd',
                          () => setState(() => _quality = 'sd'),
                        ),
                        const SizedBox(width: 14),
                        _typePill(
                          Icons.hd_outlined,
                          'HD',
                          _quality == 'hd',
                          () => setState(() => _quality = 'hd'),
                        ),
                        const SizedBox(width: 14),
                        _typePill(
                          Icons.high_quality_outlined,
                          'FHD',
                          _quality == 'fhd',
                          () => setState(() => _quality = 'fhd'),
                        ),
                      ],
                    ),
                    if (!_isPublic) ...[
                      const SizedBox(height: 22),
                      const Text(
                        'Private Room Passcode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _glassCard(
                        radius: 16,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: TextField(
                            controller: _passcodeCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 30,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Enter passcode',
                              hintStyle: TextStyle(
                                color: Color(0xB3FF8BBF),
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              counterText: '',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // ---- Right side tools (native: Filter + Camera) ----
          Positioned(
            right: 15,
            top: MediaQuery.of(context).size.height * 0.42,
            child: Column(
              children: [
                _sideTool(
                  Icons.auto_fix_high,
                  'Beauty',
                  _showBeautySheet,
                ),
                const SizedBox(height: 16),
                _sideTool(
                  Icons.flip_camera_ios,
                  'Camera',
                  _switchCamera,
                ),
                const SizedBox(height: 16),
                _sideTool(Icons.tune, 'Settings', _showOptionsSheet),
              ],
            ),
          ),
          // ---- Go Live pill (premium pink gradient with neon glow) ----
          Positioned(
            bottom: MediaQuery.of(context).viewPadding.bottom + 26,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _starting ? null : _startLive,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 72,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    gradient:
                        _coverImage != null
                            ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFF8BBF), Color(0xFFE9428F)],
                            )
                            : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF4A4A5E), Color(0xFF3A3A4C)],
                            ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow:
                        _coverImage != null
                            ? [
                              BoxShadow(
                                color: const Color(
                                  0xFFFF8BBF,
                                ).withValues(alpha: 0.55),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: const Color(
                                  0xFFE9428F,
                                ).withValues(alpha: 0.35),
                                blurRadius: 14,
                                spreadRadius: 6,
                              ),
                            ]
                            : null,
                  ),
                  child:
                      _starting
                          ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: Preloader(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                          : Text(
                            _coverImage != null
                                ? 'Go Live'
                                : 'Add Cover Photo',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoLiveBeautySheet extends StatefulWidget {
  const _GoLiveBeautySheet({
    required this.smoothness,
    required this.lightening,
    required this.redness,
    required this.lighteningContrast,
    required this.onChanged,
  });

  final double smoothness;
  final double lightening;
  final double redness;
  final LighteningContrastLevel lighteningContrast;
  final void Function(double, double, double, LighteningContrastLevel)
  onChanged;

  @override
  State<_GoLiveBeautySheet> createState() => _GoLiveBeautySheetState();
}

class _GoLiveBeautySheetState extends State<_GoLiveBeautySheet> {
  late double _smoothness;
  late double _lightening;
  late double _redness;
  late LighteningContrastLevel _lighteningContrast;

  @override
  void initState() {
    super.initState();
    _smoothness = widget.smoothness;
    _lightening = widget.lightening;
    _redness = widget.redness;
    _lighteningContrast = widget.lighteningContrast;
  }

  void _notify() {
    widget.onChanged(_smoothness, _lightening, _redness, _lighteningContrast);
  }

  void _close() => Navigator.pop(context);

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Slider(
          value: value,
          min: 0,
          max: 1,
          divisions: 10,
          thumbColor: const Color(0xFF7E3FF2),
          activeColor: const Color(0xFF00E5FF),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _contrastChip(String label, LighteningContrastLevel value) {
    final selected = _lighteningContrast == value;
    return Expanded(
      child: GestureDetector(
        onTap:
            () => setState(() {
              _lighteningContrast = value;
              _notify();
            }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient:
                selected
                    ? const LinearGradient(
                      colors: [Color(0xFF7E3FF2), Color(0xFF00E5FF)],
                    )
                    : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_fix_high,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Beauty Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Effects will be applied when you go live',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Lightening Contrast',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _contrastChip(
                'Low',
                LighteningContrastLevel.lighteningContrastLow,
              ),
              const SizedBox(width: 8),
              _contrastChip(
                'Normal',
                LighteningContrastLevel.lighteningContrastNormal,
              ),
              const SizedBox(width: 8),
              _contrastChip(
                'High',
                LighteningContrastLevel.lighteningContrastHigh,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _slider('Smoothness', _smoothness, (v) {
            setState(() => _smoothness = v);
            _notify();
          }),
          _slider('Lightening', _lightening, (v) {
            setState(() => _lightening = v);
            _notify();
          }),
          _slider('Redness', _redness, (v) {
            setState(() => _redness = v);
            _notify();
          }),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _smoothness = 0;
                      _lightening = 0;
                      _redness = 0;
                      _lighteningContrast =
                          LighteningContrastLevel.lighteningContrastNormal;
                    });
                    _notify();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _close,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoLiveOptionsSheet extends StatefulWidget {
  const _GoLiveOptionsSheet({
    required this.titleCtrl,
    required this.welcomeCtrl,
    required this.passcodeCtrl,
    required this.isPublic,
    required this.onUpdate,
  });

  final TextEditingController titleCtrl;
  final TextEditingController welcomeCtrl;
  final TextEditingController passcodeCtrl;
  final bool isPublic;
  final void Function(bool isPublic) onUpdate;

  @override
  State<_GoLiveOptionsSheet> createState() => _GoLiveOptionsSheetState();
}

class _GoLiveOptionsSheetState extends State<_GoLiveOptionsSheet> {
  late bool _isPublic;

  InputDecoration _darkInput(String label, String hint) {
    return InputDecoration(
      labelText: label.isNotEmpty ? label : null,
      hintText: hint.isNotEmpty ? hint : null,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _choiceChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient:
              selected
                  ? const LinearGradient(
                    colors: [Color(0xFF7E3FF2), Color(0xFF00E5FF)],
                  )
                  : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: const Color(0xFF7E3FF2).withValues(alpha: 0.45),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _isPublic = widget.isPublic;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tune, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'Live Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: widget.titleCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _darkInput('Room Title', 'Give your live a title...'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.welcomeCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _darkInput('Welcome Message', 'Welcome to my live!'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Privacy',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _choiceChip(
                'Public',
                _isPublic,
                () => setState(() => _isPublic = true),
              ),
              const SizedBox(width: 8),
              _choiceChip(
                'Private',
                !_isPublic,
                () => setState(() => _isPublic = false),
              ),
            ],
          ),
          if (!_isPublic) ...[
            const SizedBox(height: 10),
            TextField(
              controller: widget.passcodeCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: _darkInput('Room Passcode', 'Enter a passcode'),
            ),
          ],
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              widget.onUpdate(_isPublic);
              Navigator.pop(context);
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7E3FF2), Color(0xFF00E5FF)],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7E3FF2).withValues(alpha: 0.6),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Save Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
