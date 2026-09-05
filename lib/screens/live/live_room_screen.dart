/// Ported from native `GotoLiveActivityNew.java` + `HostPKLiveActivity.java`.
///
/// Phase 4 implementation: Agora-only live streaming.
/// - GoLiveScreen: host setup (title, cover, privacy, go live button)
/// - LiveRoomScreen: Agora RTC video + Socket.IO comments/gifts/views
library live_room;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'dart:ui' as ui;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_token_generator/agora_token_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../services/chat_translation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../services/audio_quality_service.dart';

import '../../constants/const.dart';
import '../call/call_screen.dart';
import '../../models/ai_feature_model.dart';
import '../../models/common_models.dart';
import '../../models/live_stream_root.dart' as live_stream;
import '../../models/live_user_root.dart' as lur;
import '../../models/audio_room_root.dart';
import '../../models/json_annotation_helper.dart';
import '../../models/pk_call_models.dart';
import '../../providers/ai_feature_manager.dart';
import '../../providers/auth_provider.dart';
import '../../providers/minimized_live_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/agora_extensions_service.dart';
import '../../services/api_service.dart';
import '../../services/dynamic_ai_features_service.dart';
import '../../services/effect_settings_service.dart';
import '../../services/host_presence_guard_service.dart';
import '../../services/gift_sound_service.dart';
import '../../services/session_manager.dart';
import '../../services/host_features_service.dart';
import '../../services/socket_handlers.dart';
import '../../services/socket_service.dart';
import '../../services/system_ui_service.dart';
import '../../utils/format_utils.dart' show diamondsToBeans, formatCount;
import '../../utils/log.dart';
import '../../utils/live_video_uid_resolver.dart';
import '../../utils/media_utils.dart';
import '../../widgets/beauty_options_sheet.dart';
import '../../widgets/cheer_animation_widget.dart';
import '../../widgets/game_bottom_sheet.dart';
import '../../widgets/gift_bottom_sheet.dart';
import '../../widgets/host_compliance_overlay.dart';
import '../../widgets/live_ranking_sheet.dart';
import '../../widgets/gift_overlay.dart';
import '../../widgets/big_gift_overlay.dart';
import '../../widgets/gift_fly_overlay.dart';
import '../../widgets/gift_combo_burst_overlay.dart';
import '../../widgets/gift_trail_overlay.dart';
import '../../widgets/screen_shake_widget.dart';

import '../../widgets/lucky_treasure_box_overlay.dart';
import '../../widgets/live_gift_stats_overlay.dart';
import '../../widgets/live_broadcast_overlay.dart';
import '../../widgets/live_extra_sheets.dart';
import '../../widgets/live_lucky_bag_sheet.dart';
import '../../widgets/party_game_sheet.dart';
import '../../widgets/tools_sheet.dart';
import '../../widgets/live_moderation_sheet.dart';
import '../../widgets/pk_battle_sheets.dart';
import '../../widgets/pk_hand_raise_sheet.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/relationship_badge.dart';
import '../../widgets/relationship_entry_overlay.dart';
import '../../widgets/intimacy_fly_overlay.dart';
import '../../widgets/bond_progress_bar.dart';
import '../../widgets/user_profile_sheet.dart';
import '../../widgets/profile_room_card_sheet.dart';
import '../../widgets/cp_entry_overlay.dart';
import '../../widgets/cp_level_up_overlay.dart';
import '../../widgets/vip_entry_overlay.dart';
import '../../widgets/audio_room_comment_bubble.dart';
import '../../utils/cp_style_helper.dart';
import '../../utils/vip_privilege_helper.dart';
import '../../widgets/emoji_picker_sheet.dart';
import '../../widgets/subscription_sheet.dart';
import '../../widgets/top_contributor_banner.dart';
import '../../widgets/voice_changer_sheet.dart';
import '../../widgets/ai_feature_guard.dart';
import '../../widgets/gift_predictor_banner.dart';
import '../../widgets/gifting_multiplier_banner.dart';
import '../../widgets/group_match_sheet.dart';
import '../../widgets/ar_sticker_overlay.dart';
import '../../widgets/ar_face_sticker_sheet.dart';
import '../../widgets/co_watch_widget.dart';
import '../../widgets/stream_quality_sheet.dart';
import '../../widgets/virtual_avatar_widget.dart';
import '../../widgets/draw_and_guess_widget.dart';
import '../../widgets/voice_emoji_widget.dart';
import '../../services/ar_face_sticker_service.dart';
import '../../services/screen_share_service.dart';
import '../../services/live_clip_service.dart';
import '../../services/virtual_avatar_service.dart';
import '../../services/animated_room_background_service.dart';
import '../../models/host_compliance_models.dart';
import '../../models/room_music_models.dart';
import '../../models/room_runtime_models.dart';
import '../../services/audio_room_advanced_service.dart';
import '../../services/room_music_controller.dart';
import '../../widgets/sound_effects_sheet.dart';
import '../../widgets/room_poll_card.dart';
import 'add_music_screen.dart';
import 'audio_room_music_screen.dart';
import 'package:belive/widgets/preloader.dart';

/// Agora App ID â€” read from settings (agoraKey) at runtime, matching native.
/// Falls back to --dart-define AGORA_APP_ID if settings not loaded yet.
const String _agoraAppIdFallback = String.fromEnvironment(
  'AGORA_APP_ID',
  defaultValue: '',
);

/// Host setup screen â€” ported from `GotoLiveActivityNew.java`.
class _GoLiveScreenOld extends StatefulWidget {
  const _GoLiveScreenOld();

  @override
  State<_GoLiveScreenOld> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<_GoLiveScreenOld> {
  static const String _tag = 'GoLive';
  static const String _prefTitle = 'golive_room_title';
  static const String _prefWelcome = 'golive_room_welcome';
  static const String _prefCover = 'golive_room_cover';
  static const String _prefPublic = 'golive_is_public';
  static const String _prefCategory = 'golive_category';
  static const String _prefBroadcastType = 'golive_broadcast_type';

  final _titleCtrl = TextEditingController();
  final _welcomeCtrl = TextEditingController();
  final _passcodeCtrl = TextEditingController();
  File? _coverImage;
  bool _isPublic = true;
  bool _starting = false;
  String _category = 'Chatting';
  String _broadcastType = 'camera';
  final _categories = const [
    'Chatting',
    'Singing',
    'Dancing',
    'Gaming',
    'Talent',
    'New',
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedFields();
  }

  Future<void> _loadSavedFields() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString(_prefTitle) ?? '';
    final welcome = prefs.getString(_prefWelcome) ?? '';
    final coverPath = prefs.getString(_prefCover) ?? '';
    final isPublic = prefs.getBool(_prefPublic) ?? true;
    final category = prefs.getString(_prefCategory) ?? 'Chatting';
    final broadcastType = prefs.getString(_prefBroadcastType) ?? 'camera';
    if (!mounted) return;
    setState(() {
      _titleCtrl.text = title;
      _welcomeCtrl.text = welcome;
      _isPublic = isPublic;
      _category = _categories.contains(category) ? category : 'Chatting';
      _broadcastType = broadcastType;
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
    await prefs.setString(_prefCategory, _category);
    await prefs.setString(_prefBroadcastType, _broadcastType);
    if (_coverImage != null) {
      await prefs.setString(_prefCover, _coverImage!.path);
    } else {
      await prefs.remove(_prefCover);
    }
  }

  /// Show the 24-hour live ban dialog when the backend rejects going live.
  void _showLiveBanDialog(HostComplianceBan? ban) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.red.shade900,
            title: const Row(
              children: [
                Icon(Icons.block, color: Colors.white),
                SizedBox(width: 8),
                Text('Live Banned', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Text(
              ban?.reason ??
                  'Your live is banned for 24 hours due to a compliance violation.',
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _welcomeCtrl.dispose();
    _passcodeCtrl.dispose();
    super.dispose();
  }

  bool _isPickingCover = false;

  Future<void> _pickCover() async {
    if (_isPickingCover) return;
    _isPickingCover = true;
    try {
      final picked = await ImagePickerGuard.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _coverImage = File(picked.path));
        // Persist immediately so the cover survives across sessions.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefCover, picked.path);
      }
    } finally {
      _isPickingCover = false;
    }
  }

  Future<void> _startLive() async {
    if (_titleCtrl.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'Enter room title');
      return;
    }
    setState(() => _starting = true);
    final session = context.read<SessionManager>();
    // Persist fields so they're pre-filled next time.
    await _saveFields();
    try {
      // Request camera + mic permissions.
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
        category: _category,
        broadcastType: _broadcastType,
      );
      if (res.isLiveBanned) {
        setState(() => _starting = false);
        _showLiveBanDialog(res.ban);
        return;
      }
      if (res.status && res.user != null) {
        // Update passcode for private rooms (native: updatePrivateCode)
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
            AppRoutes.liveRoom,
            extra: {'liveUser': res.user!, 'isHost': true},
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Go Live')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pickCover,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child:
                  _coverImage == null
                      ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Room cover (optional)',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      )
                      : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _coverImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 180,
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Room Title',
              hintText: 'Give your live a title...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _welcomeCtrl,
            decoration: const InputDecoration(
              labelText: 'Welcome Message',
              hintText: 'Welcome to my live!',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Privacy: ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              ChoiceChip(
                label: const Text('Public'),
                selected: _isPublic,
                onSelected: (_) => setState(() => _isPublic = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Private'),
                selected: !_isPublic,
                onSelected: (_) => setState(() => _isPublic = false),
              ),
            ],
          ),
          if (!_isPublic) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _passcodeCtrl,
              decoration: const InputDecoration(
                labelText: 'Room Passcode',
                hintText: 'Enter a passcode for private room',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Category: ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _category,
                    isDense: true,
                    dropdownColor: Colors.grey.shade100,
                    items:
                        _categories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                    onChanged:
                        (v) => setState(() => _category = v ?? 'Chatting'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Mode: ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              ChoiceChip(
                label: const Text('Camera'),
                selected: _broadcastType == 'camera',
                onSelected: (_) => setState(() => _broadcastType = 'camera'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Game / Screen'),
                selected: _broadcastType == 'screen',
                onSelected: (_) => setState(() => _broadcastType = 'screen'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _starting ? null : _startLive,
            icon:
                _starting
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: Preloader(strokeWidth: 2, color: Colors.white),
                    )
                    : const Icon(Icons.live_tv),
            label: const Text('Go Live', style: TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF7E3FF2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live room screen â€” ported from `HostPKLiveActivity.java` (single host).
///
/// Uses Agora RTC for video + Socket.IO for comments/gifts/views.
class LiveRoomScreen extends StatefulWidget {
  const LiveRoomScreen({
    super.key,
    required this.liveUser,
    required this.isHost,
    this.quality = 'hd',
    this.smoothness = 0.0,
    this.lightening = 0.0,
    this.redness = 0.0,
    this.lighteningContrast = LighteningContrastLevel.lighteningContrastNormal,
    this.fromChat = false,
  });

  final live_stream.LiveUser liveUser;
  final bool isHost;
  final String quality;
  final double smoothness;
  final double lightening;
  final double redness;
  final LighteningContrastLevel lighteningContrast;

  /// True when the viewer joined from a chat conversation (tapped the LIVE
  /// badge in chat list or the live banner in chat screen). The room shows a
  /// brief "Joined from chat" highlight banner so the user knows how they got
  /// here — mirrors native UnilivePro behaviour.
  final bool fromChat;

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen>
    with WidgetsBindingObserver {
  static const String _tag = 'LiveRoom';

  late RtcEngineEx _engine;
  bool _engineReady = false;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  bool _frontCamera = true;

  // Audience-side state for the live host's camera-off fallback.
  bool _remoteHostCameraOff = false;
  int? _remoteUid;
  bool _isFollowing = false;
  String? _hostUniqueId;
  // Network quality: 0=excellent, 1=good, 2=fair, 3=poor, 4=bad, 5=very bad, 6=down
  int _networkQuality = 0;
  bool _hostOffline = false;

  /// "Joined from chat" highlight banner — shown for ~4s on entry when the
  /// viewer came from a chat conversation. Mirrors native UnilivePro.
  bool _showFromChatBanner = false;
  Timer? _fromChatBannerTimer;

  // Cache controllers so they aren't recreated on every build (causes white screen).
  VideoViewController? _localController;
  VideoViewController? _remoteController;

  // Persisted for onAgoraVideoViewCreated callback.
  String? _channel;
  int? _uid;
  String _agoraAppId = '';
  String? _agoraAppCertificate;

  bool _videoStarted = false;
  bool _videoStarting = false;
  int _videoStartRetryCount = 0;
  static const int _videoStartMaxRetries = 12;
  Timer? _videoStartFallbackTimer;
  Timer? _durationTimer;
  Timer? _liveTimeTimer;
  int _durationSeconds = 0;
  final ValueNotifier<int> _durationNotifier = ValueNotifier<int>(0);

  // Local cache deltas for graceful fallback when backend hostLiveHistory
  // endpoints are empty / 404. Updated on each heartbeat.
  int _lastCachedDuration = 0;
  int _lastCachedEarnings = 0;

  String _formatDuration(int durationSeconds) {
    final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _setDurationSeconds(int value) {
    _durationSeconds = value;
    _durationNotifier.value = value;
  }

  VideoEncoderConfiguration _getVideoConfig() {
    // Map quality preset to Agora encoder dimensions + bitrate.
    final dims = switch (_currentQuality) {
      'sd' || 'low' => const VideoDimensions(width: 360, height: 640),
      'hd' || 'medium' => const VideoDimensions(width: 720, height: 1280),
      'fhd' || 'high' => const VideoDimensions(width: 1080, height: 1920),
      _ => const VideoDimensions(width: 720, height: 1280),
    };
    return VideoEncoderConfiguration(
      dimensions: dims,
      frameRate: 20,
      bitrate: standardBitrate,
      minBitrate: defaultMinBitrate,
      orientationMode: OrientationMode.orientationModeFixedPortrait,
      degradationPreference: DegradationPreference.maintainBalanced,
      mirrorMode: VideoMirrorModeType.videoMirrorModeDisabled,
    );
  }

  final _comments = <_LiveComment>[];
  int _clientCommentCount = 0;
  int _viewerCount = 0;
  int _clientFanCount = 0;
  Function? _cancelFollowSub;
  StreamSubscription<void>? _reconnectSub;
  final _viewers = <ViewerEntry>[];
  final _giftController = GiftQueueController();
  final _bigGiftController = BigGiftController();
  final _comboBurstController = GiftComboBurstController();
  final _shakeController = ScreenShakeController();
  final _giftTrailController = GiftTrailController();
  final _topContributorController = TopContributorController();
  final _giftStatsController = LiveGiftStatsController();
  final _giftPredictor = GiftPredictorController();
  final _multiplier = GiftingMultiplierController();
  final _broadcastOverlayKey = GlobalKey<LiveBroadcastOverlayState>();
  final _luckyTreasureKey = GlobalKey<LuckyTreasureBoxOverlayState>();
  final _cheerKey = GlobalKey<CheerAnimationOverlayState>();
  final _vipEntryKey = GlobalKey<VipEntryOverlayState>();
  final _cpEntryKey = GlobalKey<CpEntryOverlayState>();
  final _relationshipEntryKey = GlobalKey<RelationshipEntryOverlayState>();
  final _intimacyFlyKey = GlobalKey<IntimacyFlyOverlayState>();

  // ---- AI Feature Integration -------------------------------------------
  final HostPresenceGuardService _presenceGuard = HostPresenceGuardService();
  StreamSubscription<HostPresenceStatus>? _presenceSub;
  StreamSubscription<HostPresenceBanInfo?>? _banSub;
  bool _giftsBlocked = false;
  // RepaintBoundary key for capturing host's local video frame (AR tracking).
  final GlobalKey _videoBoundaryKey = GlobalKey();
  // Native Agora video frame observer — feeds real camera frames to the
  // host presence guard for compliance analysis (replaces the old
  // RepaintBoundary.toImage() capture which only saw black Flutter surfaces).
  VideoFrameObserver? _videoFrameObserver;
  bool _beautyModeActive = false;
  bool _presenceBanDialogOpen = false;

  // ---- 3D Gift Trigger (voice-triggered, simplified to tap-reaction) ----
  StreamSubscription<Gift3DTriggerEvent>? _gift3DSub;
  bool _showGift3DReaction = false;
  Timer? _gift3DReactionTimer;
  // ---- Reaction overlay (ports native imgHostReaction) ----
  String? _reactionImage;
  String? _reactionName;
  Timer? _reactionTimer;
  Function? _cancelReactionSub;
  // Background image for theme change
  String? _backgroundImage;
  // Background music state (host controls via socket events).
  String? _currentMusicName;
  bool _isMusicPlaying = false;
  // Unified room music controller (Agora mixing for host, state mirror for
  // viewers). Created once the Agora engine is ready.
  RoomMusicController? _musicController;
  String _musicPermission = 'host';
  bool _friendMusicDialogOpen = false;
  // Sound effects / ambient sounds (applause, laughter, rain, etc.).
  final MusicSoundService _musicSoundService = MusicSoundService();
  // Room announcement shown in the top marquee (host-set or backend-pushed
  // next-day gifting / game announcements).
  String _liveAnnouncement = '';
  Function? _cancelCommentSub;
  Function? _cancelGiftSub;
  Function? _cancelLiveUserGiftSub;
  Function? _cancelNormalUserGiftSub;
  Function? _cancelLuckyGiftSub;
  Function? _cancelAddViewSub;
  Function? _cancelLessViewSub;
  Function? _cancelCpRoomEntrySub;
  Function? _cancelCoHostJoinSub;
  Function? _cancelCoHostLeaveSub;
  Function? _cancelCoHostMuteSub;

  // Co-host state for multi-guest live.
  final _coHosts = <Map<String, dynamic>>[];
  final _joinRequests = <Map<String, dynamic>>[];

  /// Request userIds the host has already been alerted about (toast/popup),
  /// so a refreshed request list doesn't re-alert for the same user.
  final _notifiedRequestIds = <String>{};
  bool _joinRequestDialogOpen = false;
  bool _isJoined = false;
  // Gift fly overlay — tracks co-host box positions for fly-to-guest animation.
  final _giftFlyKey = GlobalKey<GiftFlyOverlayState>();
  final _coHostBoxKeys = <String, GlobalKey>{}; // keyed by userId
  bool _isCameraOff = false;
  bool _speakerEnabled = true;
  int _myAgoraUid = 0;
  Function? _cancelLiveEndSub;
  Function? _cancelLiveHostEndSub;
  Function? _cancelEndLiveSub;
  Function? _cancelLiveEndGenericSub;
  Function? _cancelLiveEndByAdminSub;
  Function? _cancelDestroyRoomSub;
  Function? _cancelMigrateToVideoLiveSub;
  bool _isRoomEnded = false;
  Function? _cancelRequestedCallJoinSub;
  Function? _cancelCameraOffCallJoinSub;
  Function? _cancelInviteSub;
  // Remote video controllers for co-hosts, keyed by agoraUid.
  final _coHostControllers = <int, VideoViewController>{};
  // Admin list for host.
  final _admins = <AdminEntry>[];
  Function? _cancelAdminListSub;

  /// True when the current user is a room admin (assigned by the host).
  /// Admins can mute/kick/ban users, manage comments, manage guests and
  /// end the live — per the room-admin permission model.
  bool get _iAmAdmin {
    final myId = context.read<SessionManager>().userId;
    if (myId.isEmpty) return false;
    return _admins.any((a) => a.adminUserId?.id == myId);
  }

  /// Host OR assigned room admin — gates moderation actions.
  bool get _canModerate => widget.isHost || _iAmAdmin;

  /// Unwrap a socket admin-list payload to a flat list of Maps.
  /// Handles `{'admins': [...]}`, `[[{...}]]`, and simple `[{...}]`.
  List<dynamic>? _unwrapAdminList(dynamic data) {
    if (data == null) return null;
    if (data is List) {
      if (data.isEmpty) return null;
      if (data.length == 1 && data.first is List) {
        return data.first as List;
      }
      return data;
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['admins'] is List) return map['admins'] as List;
      if (map['adminList'] is List) return map['adminList'] as List;
      return [map];
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        return _unwrapAdminList(decoded);
      } catch (_) {}
    }
    return null;
  }

  // Bigo-parity feature controllers.
  CoWatchController? _coWatchController;
  bool _isClipCapturing = false;
  String _currentStreamQuality = 'auto';
  // Bigo-parity: Draw and Guess, Voice Emoji, Chat Translation.
  DrawAndGuessController? _drawAndGuessController;
  bool _showDrawAndGuess = false;
  final _voiceEmojiKey = GlobalKey<VoiceEmojiOverlayState>();
  bool _isTranslationEnabled = false;
  String _translationTargetLang = 'en';
  StreamSubscription<TranslatedMessage>? _translationSub;
  // Bigo-parity: AR / Virtual Avatar live face tracking.
  Timer? _arTrackingTimer;
  final _arFaceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: false,
      minFaceSize: 0.10,
    ),
  );
  // PK vote counts + PK score + PK punishment state.
  int _pkVoteCountHost1 = 0;
  int _pkVoteCountHost2 = 0;
  int _pkScoreHost1 = 0;
  int _pkScoreHost2 = 0;
  bool _isPkActive = false;
  int? _pkRemoteAgoraUid;
  bool _openingPkBattle = false;
  bool _pkRequestDialogOpen = false;
  bool _isPkPunishment = false;
  String? _pkPunishmentTask;
  // Inline PK overlay state — PK renders inside the live room, not a separate route.
  PkConfig? _pkConfig;
  Map<String, dynamic>? _pendingPkRequest;
  bool _pkIsHost1 = false;
  VideoViewController? _pkRemoteController;
  Timer? _pkTimer;
  int _pkSecondsLeft = 0;
  int _pkWinner = -1;
  int _pkRoundCount = 0;
  // PK relay retry — matches native startPkVideoRetry + mediaRelayRetry.
  Timer? _pkVideoRetryTimer;
  int _pkVideoRetryCount = 0;
  static const int _pkVideoMaxRetries = 10;
  Timer? _pkRelayRetryTimer;
  int _pkRelayRetryCount = 0;
  bool _pkRelayStarted = false;
  bool _pkRelayStarting = false;
  static const int _pkRelayMaxRetries = 3;
  Timer? _pkResultResetTimer;
  RoomPoll? _activeRoomPoll;
  LiveRoomAnalytics? _liveRoomAnalytics;
  // In-room effect/broadcast visibility settings.
  EffectSettings _effectSettings = EffectSettings();
  // Track PK supporter totals to fire pkBroadcast banners (100k support threshold).
  final _pkSupporters = <String, int>{};
  final _pkSupporterAnnounced = <String>{};
  static const int _pkSupportThreshold = 100000;
  Function? _cancelPkVoteSub;
  Function? _cancelPkScoreSub;
  Function? _cancelPkStartSub;
  Function? _cancelPkEndSub;
  Function? _cancelPkPunishmentSub;
  Function? _cancelPkRequestSub;
  Function? _cancelPkRequestAnswerSub;
  final List<VoidCallback> _roomRuntimeSocketCancellations = [];
  // New backend socket event subscriptions.
  Function? _cancelHostEarningSub;
  Function? _cancelTopGiftersSub;
  Function? _cancelViewerKickedSub;
  Function? _cancelViewerMutedSub;
  Function? _cancelGameResultSub;
  Function? _cancelLuckyBagCreateSub;
  Function? _cancelLuckyBagClaimSub;
  Function? _cancelHostComplianceStrikeSub;
  Function? _cancelHostComplianceBanSub;
  Function? _cancelCallAnswerSub;
  // Lucky gift winner broadcast banner.
  String? _luckyBannerName;
  String? _luckyBannerImage;
  int _luckyBannerCoins = 0;
  Timer? _luckyBannerTimer;
  List<String> _luckyBannerUrls = [];
  // PK round history.
  final _pkRoundHistory = <PkRoundResult>[];
  final _commentCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final _commentFocus = FocusNode();
  final _viewerAvatarScroll = ScrollController();
  // Tracks whether the chat input is focused (keyboard open) to switch the
  // bottom bar between the compact "typing" layout and the full action bar.
  bool _isTyping = false;
  late String _currentQuality;
  late LighteningContrastLevel _currentLighteningContrast;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keep the screen on during the live stream.
    WakelockPlus.enable();
    // Start a foreground service so the stream keeps running when the user
    // backgrounds the app (Bigo/Chamet keep audio/video alive in background).
    AudioQualityService.startForegroundService();
    _currentQuality = widget.quality;
    _currentLighteningContrast = widget.lighteningContrast;
    _musicPermission = widget.liveUser.musicPermission;
    _beautyModeActive =
        widget.smoothness > 0 || widget.lightening > 0 || widget.redness > 0;
    _hostUniqueId = widget.liveUser.uniqueId;
    _loadHostUniqueId();
    // Respect 3-button nav: full screen only when the nav bar is hidden.
    SystemUiService.instance.applyForLive();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _viewerCount = max(0, widget.liveUser.view - 1);
    _giftStatsController
      ..setHostEarnings(widget.liveUser.coin)
      ..attach(() {
        if (mounted) setState(() {});
      });
    _giftPredictor.setHostEarnings(widget.liveUser.coin);
    // Toggle bottom bar layout when the chat input gains/loses focus.
    _commentFocus.addListener(() {
      if (mounted) setState(() => _isTyping = _commentFocus.hasFocus);
    });
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _setDurationSeconds(_durationSeconds + 1);
    });
    // Sync live time with server every 60s for both host and viewers.
    _syncLiveTime();
    _liveTimeTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _syncLiveTime();
    });
    // Agora-only streaming engine.
    _initAgora();
    _listenSocketEvents();
    // Fetch current gift stats so new viewers don't see 0 while the live
    // already has gifts. Falls back to widget.liveUser.coin if API fails.
    _fetchInitialGiftStats();
    // Show "Joined from chat" highlight banner for ~4s on entry.
    if (widget.fromChat) {
      _showFromChatBanner = true;
      _fromChatBannerTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showFromChatBanner = false);
      });
    }
    // Generate a random agoraUid for viewer (used when joining as co-host).
    if (!widget.isHost) {
      _myAgoraUid = Random().nextInt(999999) + 100000;
      // Load effect settings before emitting join comment, then notify backend.
      _loadEffectSettings().then((_) {
        _emitAddView();
        _checkFollowStatus();
      });
    }
    // Re-fetch AI feature config on room join + start host presence guard.
    _initAiFeatures();
    // Fetch Bigo-parity catalogs from backend (best-effort, falls back to built-in).
    ARFaceStickerService.instance.fetchFromBackend();
    VirtualAvatarService.instance.fetchFromBackend();
    AnimatedRoomBackgroundService.instance.fetchFromBackend();
    _loadLuckyBanners();
  }

  Future<void> _loadHostUniqueId() async {
    final hostUserId = widget.liveUser.userId ?? '';
    if (hostUserId.isEmpty) return;
    if (widget.isHost) {
      final uniqueId = context.read<AuthProvider>().user?.uniqueId;
      if (uniqueId?.isNotEmpty == true && mounted) {
        setState(() => _hostUniqueId = uniqueId);
        return;
      }
    }
    if (_hostUniqueId?.isNotEmpty == true) return;
    try {
      final response = await ApiService.getUser({'userId': hostUserId});
      final uniqueId = response.user?.uniqueId;
      if (response.status && uniqueId?.isNotEmpty == true && mounted) {
        setState(() => _hostUniqueId = uniqueId);
      }
    } catch (e) {
      Log.e(_tag, 'loadHostUniqueId failed', e);
    }
  }

  /// Load Bigo-style lucky gift broadcast banner images from backend.
  Future<void> _loadLuckyBanners() async {
    try {
      final root = await ApiService.getLuckyBanners();
      if (root.status && root.banner.isNotEmpty) {
        _luckyBannerUrls =
            root.banner
                .map((b) => b.image ?? '')
                .where((u) => u.isNotEmpty)
                .toList();
      } else {
        _luckyBannerUrls = _defaultLuckyBannerUrls();
      }
    } catch (e, s) {
      Log.e(_tag, 'loadLuckyBanners failed', e, s);
      _luckyBannerUrls = _defaultLuckyBannerUrls();
    }
  }

  List<String> _defaultLuckyBannerUrls() {
    // Bigo/Chamet-style fallback decorative banner backgrounds. These are
    // port-agnostic URLs; if the backend returns images, those are used.
    return [
      'https://app.bigo.tv/banner/lucky_01.png',
      'https://app.bigo.tv/banner/lucky_02.png',
      'https://app.bigo.tv/banner/lucky_03.png',
    ];
  }

  /// Fetch existing gift stats when entering a live room so a viewer who joins
  /// late doesn't see 0 diamonds/beans. Sets host earnings to the backend
  /// total and seeds the local top gifters list.
  Future<void> _fetchInitialGiftStats() async {
    final liveId = widget.liveUser.liveRoomId ?? widget.liveUser.id ?? '';
    if (liveId.isEmpty) return;
    try {
      final res = await ApiService.getTopGiftersInRoom(liveStreamingId: liveId);
      if (!res.status || res.data == null) return;

      // Some backends return a single hostEarnings/totalCoins field.
      final apiTotal =
          (res.data!['hostEarnings'] as num?)?.toInt() ??
          (res.data!['totalCoins'] as num?)?.toInt() ??
          (res.data!['earnings'] as num?)?.toInt() ??
          (res.data!['coins'] as num?)?.toInt() ??
          0;

      final list =
          res.data!['topGifters'] ?? res.data!['data'] ?? res.data!['gifters'];

      int totalFromGifters = 0;
      if (list is List) {
        for (final raw in list) {
          if (raw is! Map) continue;
          final m = Map<String, dynamic>.from(raw);
          final userId = m['userId']?.toString() ?? m['_id']?.toString() ?? '';
          final name =
              m['name']?.toString() ?? m['userName']?.toString() ?? 'User';
          final image =
              m['image']?.toString() ?? m['userImage']?.toString() ?? '';
          final coins =
              (m['totalCoins'] as num?)?.toInt() ??
              (m['coin'] as num?)?.toInt() ??
              0;
          totalFromGifters += coins;
          if (userId.isNotEmpty && coins > 0) {
            _topContributorController.recordGift(
              userId: userId,
              name: name,
              avatar: image,
              coins: coins,
              count: 1,
            );
          }
        }
      }

      final totalCoins = apiTotal > 0 ? apiTotal : totalFromGifters;
      if (totalCoins > 0 && totalCoins > _giftStatsController.hostEarnings) {
        _giftStatsController.setHostEarnings(totalCoins);
      }
    } catch (e, s) {
      Log.e(_tag, 'fetchInitialGiftStats failed', e, s);
    }
  }

  /// Load in-room effect/broadcast visibility settings.
  Future<void> _loadEffectSettings() async {
    try {
      _effectSettings = await EffectSettingsService.instance.getSettings();
      _broadcastOverlayKey.currentState?.updateSettings(_effectSettings);
    } catch (e) {
      Log.e(_tag, 'effect settings load', e);
    }
  }

  /// Re-fetch the active AI feature config on room join and, for hosts,
  /// start the on-device presence guard.
  void _initAiFeatures() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final ai = context.read<AIFeatureManager>();
        await ai.refreshForRoomJoin().timeout(
          const Duration(seconds: 5),
          onTimeout:
              () => Log.w(
                _tag,
                'AI feature refresh timed out; using cached/fail-open config',
              ),
        );
        if (!mounted) return;

        if (widget.isHost &&
            (ai.isFeatureEnabled(AIFeatureKeys.arFaceStickers) ||
                ai.isFeatureEnabled(AIFeatureKeys.virtualAvatar))) {
          _startArTracking();
        }

        if (widget.isHost &&
            ai.isFeatureEnabled(AIFeatureKeys.hostComplianceGuard)) {
          // Bigo Live style: check whether the host is currently serving an
          // active presence ban before allowing the guard / stream to run.
          final hasActiveBan = await _checkHostPresenceBan();
          if (hasActiveBan || !mounted) return;
          _presenceSub = _presenceGuard.statusStream.listen((_) {
            if (mounted) setState(() {});
          });
          _banSub = _presenceGuard.banStream.listen((ban) {
            if (!mounted) return;
            if (ban != null) _showBanActiveDialog(ban);
          });
          await _presenceGuard.startWithAgora(
            ai: ai,
            userId: context.read<SessionManager>().userId,
            liveStreamingId: widget.liveUser.liveRoomId ?? '',
            isCameraOn: () => _cameraEnabled,
            // Dynamic exemptions — pause presence checking while the host
            // is screen sharing, playing mini-games, using AR masks / beauty
            // / virtual avatars, in a PK battle, or has a UI popup open.
            isExempted: _isHostPresenceExempted,
            onTerminate: _terminateStreamForCompliance,
            onGiftsBlocked: () {
              setState(() => _giftsBlocked = true);
              Fluttertoast.showToast(
                msg:
                    'Gifts are temporarily blocked due to a compliance violation.',
                backgroundColor: Colors.red.shade900,
                textColor: Colors.white,
              );
            },
          );
        } else if (widget.isHost) {
          Log.w(_tag, 'host presence guard disabled by AI feature config');
        }

        // 3D Gift Trigger — listen for trigger events and show a celebration.
        if (ai.isFeatureEnabled(AIFeatureKeys.voiceTriggered3DGifts)) {
          _gift3DSub = DynamicAIFeaturesService.instance.gift3DTriggerStream.listen((
            event,
          ) {
            if (!mounted) return;
            Log.d(
              _tag,
              '3D gift trigger event: word="${event.triggerWord}" gift="${event.giftName}"',
            );
            // Show a flying celebration text for the 3D gift trigger.
            _intimacyFlyKey.currentState?.spawn(
              text: '${event.triggerWord.toUpperCase()}! ${event.giftName}',
              position: Offset(
                MediaQuery.of(context).size.width / 2,
                MediaQuery.of(context).size.height / 3,
              ),
              color: Colors.purple,
            );
            Fluttertoast.showToast(
              msg:
                  '3D Gift Triggered: ${event.giftName} (${event.giftCoins} coins)',
              toastLength: Toast.LENGTH_LONG,
              backgroundColor: Colors.purple.shade900,
              textColor: Colors.white,
            );
            setState(() => _showGift3DReaction = false);
          });
        }
      } catch (e) {
        Log.w(_tag, 'AI feature init failed: $e');
      }
    });
  }

  /// Bigo Live style dynamic exemption checker. Returns `true` when the
  /// host is in a state where presence checking should be paused:
  /// screen sharing / Game LIVE, in-app mini-games (Draw & Guess, Co-Watch),
  /// AR masks / face filters / virtual avatars, PK battles /
  /// PK punishment rounds, or a blocking UI popup / bottom sheet is open.
  ///
  /// NOTE: plain beauty sliders (smoothness/lightening/redness) do NOT
  /// exempt the host — ML Kit can still detect a beautified face. Only
  /// AR stickers / virtual avatars that overlay or replace the face cause
  /// false face-detection negatives and warrant an exemption.
  bool _isHostPresenceExempted() {
    // Screen share / Game LIVE.
    if (ScreenShareService.instance.isScreenSharing) return true;
    // AR face stickers / masks that overlay the face.
    if (ARFaceStickerService.instance.activeSticker != null) return true;
    // Virtual avatar active (replaces the camera feed with an avatar).
    if (VirtualAvatarService.instance.isTracking) return true;
    if (_beautyModeActive) return true;
    // PK battle or PK punishment round.
    if (_isPkActive || _isPkPunishment) return true;
    // In-app mini-games.
    if (_showDrawAndGuess || _coWatchController?.isActive == true) return true;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return true;
    return false;
  }

  /// Check whether the host is currently serving an active presence ban
  /// before allowing the stream to continue. If banned, show a dialog and
  /// navigate away — the host ID is blocked from streaming for the
  /// remaining ban window.
  Future<bool> _checkHostPresenceBan() async {
    try {
      final userId = context.read<SessionManager>().userId;
      final ban = await _presenceGuard.getActiveBan(userId: userId);

      // Always verify against the backend: if the user was unbanned there,
      // the locally persisted presence ban is stale and must be cleared.
      try {
        final status = await ApiService.getHostComplianceBanStatus(userId);
        if (status.isLiveBanned == false) {
          if (ban != null) {
            await _presenceGuard.clearActiveBan(userId: userId);
          }
          return false;
        }
        final backendMessage = status.message ?? status.ban?.reason;
        if (status.isLiveBanned == true && ban != null && mounted) {
          _showBanActiveDialog(ban, message: backendMessage);
          return true;
        }
      } catch (e) {
        Log.w(_tag, 'backend presence ban check failed: $e');
      }

      if (ban != null && ban.isActive() && mounted) {
        _showBanActiveDialog(ban);
        return true;
      }
    } catch (e) {
      Log.w(_tag, 'presence ban check failed: $e');
    }
    return false;
  }

  /// Show a non-dismissible dialog informing the host of an active ban and
  /// navigate away from the live room.
  ///
  /// [message] can override the default text, e.g. with a backend-provided
  /// reason when the ban status comes from the server.
  void _showBanActiveDialog(HostPresenceBanInfo ban, {String? message}) {
    if (!mounted || _presenceBanDialogOpen) return;
    _presenceBanDialogOpen = true;
    final remaining = ban.remainingMs();
    final remainingMin = (remaining / 60000).ceil();
    final rewardPenalty =
        ban.tier == HostPresenceBanTier.second
            ? '\n\nToday\'s task rewards and earnings are forfeited.'
            : '';
    final dialogText =
        message ??
        'Your ID is blocked from streaming for $remainingMin more minute'
        '${remainingMin == 1 ? '' : 's'} due to a presence violation '
        '(violation #${ban.dailyViolationCount} today).$rewardPenalty\n\n'
        'Please try again later.';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.red.shade900,
            title: const Row(
              children: [
                Icon(Icons.block, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Streaming blocked',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Text(
              dialogText,
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _presenceBanDialogOpen = false;
                  Navigator.pop(ctx);
                  if (mounted) context.goNamed(AppRoutes.main);
                },
                child: const Text(
                  'Leave',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  /// Start periodic AR sticker + virtual avatar face tracking for the host.
  void _startArTracking() {
    _arTrackingTimer?.cancel();
    ARFaceStickerService.instance.startTracking();
    _arTrackingTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _captureArFrame(),
    );
    Log.d(_tag, 'AR tracking started');
  }

  /// Stop AR / virtual avatar frame capture.
  void _stopArTracking() {
    _arTrackingTimer?.cancel();
    _arTrackingTimer = null;
    ARFaceStickerService.instance.stopTracking();
    _arFaceDetector.close();
    Log.d(_tag, 'AR tracking stopped');
  }

  /// Capture the host video frame, run face detection, and feed the active
  /// AR sticker and virtual avatar with the detected face.
  Future<void> _captureArFrame() async {
    if (!mounted || !widget.isHost) return;
    try {
      final boundary =
          _videoBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 0.75);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/ar_frame_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(pngBytes);
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final faces = await _arFaceDetector.processImage(inputImage);
      final face = faces.isNotEmpty ? faces.first : null;
      final frameSize = Size(image.width.toDouble(), image.height.toDouble());
      if (ARFaceStickerService.instance.isTracking) {
        ARFaceStickerService.instance.processFace(face, frameSize);
      }
      VirtualAvatarService.instance.processFace(face);
      Future.delayed(const Duration(seconds: 1), () {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      });
    } catch (e) {
      Log.w(_tag, 'AR frame capture failed: $e');
    }
  }

  /// Called by the presence guard when the 180-second violation threshold
  /// is reached. Terminates the stream via the compliance endpoint, tears
  /// down the Agora engine, and navigates the host away from the live room.
  Future<bool> _terminateStreamForCompliance() async {
    Log.w(_tag, '*** _terminateStreamForCompliance called — ending stream ***');
    final session = context.read<SessionManager>();
    final endRequest = ApiService.endStreamForCompliance(
      liveId: widget.liveUser.liveRoomId ?? '',
      userId: session.userId,
    );
    var released = true;
    try {
      await _leaveAndRelease();
    } catch (e, s) {
      released = false;
      Log.e(_tag, 'compliance Agora teardown failed', e, s);
    }
    if (mounted && !_presenceBanDialogOpen) {
      context.goNamed(AppRoutes.main);
    }
    unawaited(
      endRequest.then<void>((_) {}).catchError((e, s) {
        Log.e(_tag, 'compliance backend termination failed', e, s);
      }),
    );
    return released;
  }

  @override
  void dispose() {
    _pkTimer?.cancel();
    _pkTimer = null;
    _pkVideoRetryTimer?.cancel();
    _pkVideoRetryTimer = null;
    _pkRelayRetryTimer?.cancel();
    _pkRelayRetryTimer = null;
    _pkResultResetTimer?.cancel();
    _pkResultResetTimer = null;
    _videoStartFallbackTimer?.cancel();
    _videoStartFallbackTimer = null;
    _durationTimer?.cancel();
    _durationTimer = null;
    _durationNotifier.dispose();
    _liveTimeTimer?.cancel();
    _liveTimeTimer = null;
    _fromChatBannerTimer?.cancel();
    _fromChatBannerTimer = null;
    _musicController?.dispose();
    _musicSoundService.dispose();
    _cancelCommentSub?.call();
    _cancelGiftSub?.call();
    _cancelLiveUserGiftSub?.call();
    _cancelNormalUserGiftSub?.call();
    _cancelLuckyGiftSub?.call();
    _cancelAddViewSub?.call();
    _cancelCpRoomEntrySub?.call();
    _cancelLessViewSub?.call();
    _cancelCoHostJoinSub?.call();
    _cancelCoHostLeaveSub?.call();
    _cancelCoHostMuteSub?.call();
    _cancelRequestedCallJoinSub?.call();
    _cancelCameraOffCallJoinSub?.call();
    _cancelInviteSub?.call();
    _cancelAdminListSub?.call();
    _cancelLiveEndSub?.call();
    _cancelLiveHostEndSub?.call();
    _cancelEndLiveSub?.call();
    _cancelLiveEndGenericSub?.call();
    _cancelLiveEndByAdminSub?.call();
    _cancelDestroyRoomSub?.call();
    _cancelMigrateToVideoLiveSub?.call();
    _cancelPkVoteSub?.call();
    _cancelPkScoreSub?.call();
    _cancelPkStartSub?.call();
    _cancelPkEndSub?.call();
    _cancelPkPunishmentSub?.call();
    _cancelPkRequestSub?.call();
    _cancelPkRequestAnswerSub?.call();
    for (final cancel in _roomRuntimeSocketCancellations) {
      cancel();
    }
    _roomRuntimeSocketCancellations.clear();
    _cancelHostEarningSub?.call();
    _cancelTopGiftersSub?.call();
    _cancelViewerKickedSub?.call();
    _cancelViewerMutedSub?.call();
    _cancelGameResultSub?.call();
    _cancelLuckyBagCreateSub?.call();
    _cancelLuckyBagClaimSub?.call();
    _luckyBannerTimer?.cancel();
    _cancelHostComplianceStrikeSub?.call();
    _cancelHostComplianceBanSub?.call();
    _cancelCallAnswerSub?.call();
    _cancelFollowSub?.call();
    _reconnectSub?.cancel();
    _reconnectSub = null;
    _commentCtrl.dispose();
    _scrollController.dispose();
    _commentFocus.dispose();
    _viewerAvatarScroll.dispose();
    _presenceSub?.cancel();
    _banSub?.cancel();
    _unregisterVideoFrameObserver();
    _presenceGuard.dispose();
    _reactionTimer?.cancel();
    _cancelReactionSub?.call();
    _gift3DSub?.cancel();
    _gift3DReactionTimer?.cancel();
    _giftPredictor.dispose();
    _multiplier.dispose();
    _coWatchController?.dispose();
    _stopArTracking();
    ARFaceStickerService.instance.stopTracking();
    VirtualAvatarService.instance.stopTracking();
    ScreenShareService.instance.clear();
    LiveClipService.instance.unbind();
    _translationSub?.cancel();
    _drawAndGuessController?.dispose();
    VoiceEmojiSoundService.instance.dispose();
    _leaveAndRelease();
    final myUserId = SessionManager.instance?.userId ?? '';
    if (myUserId.isNotEmpty) HostLiveCache.clearSessionRecorded(myUserId);
    WakelockPlus.disable();
    AudioQualityService.stopForegroundService();
    WidgetsBinding.instance.removeObserver(this);
    SystemUiService.instance.restoreDefault();
    super.dispose();
  }

  /// Register a native Agora `VideoFrameObserver` to feed real camera
  /// frames (I420) to the Host Presence Guard. This replaces the old
  /// `RepaintBoundary.toImage()` capture which only saw the black Flutter
  /// surface above the native video view.
  void _registerVideoFrameObserver() {
    if (_videoFrameObserver != null) return;
    try {
      _videoFrameObserver = VideoFrameObserver(
        onCaptureVideoFrame: (sourceType, videoFrame) {
          if (!sourceType.name.startsWith('videoSourceCamera')) return;
          final width = videoFrame.width ?? 0;
          final height = videoFrame.height ?? 0;
          if (!_presenceGuard.shouldProcessAgoraFrame(
            width: width,
            height: height,
          )) {
            return;
          }
          try {
            final yBuffer = videoFrame.yBuffer;
            final uBuffer = videoFrame.uBuffer;
            final vBuffer = videoFrame.vBuffer;
            final format = videoFrame.type;
            final yStride = videoFrame.yStride ?? width;
            Log.d(
              _tag,
              'onCaptureVideoFrame: source=$sourceType '
              '${width}x$height format=$format '
              'yBuffer=${yBuffer?.length ?? 'null'} '
              'uBuffer=${uBuffer?.length ?? 'null'} '
              'vBuffer=${vBuffer?.length ?? 'null'} yStride=$yStride',
            );
            if (yBuffer == null ||
                uBuffer == null ||
                vBuffer == null ||
                width <= 0 ||
                height <= 0) {
              _presenceGuard.reportAgoraFrameFailure();
              Log.w(_tag, 'Agora camera frame has invalid I420 planes');
              return;
            }
            final inputImage = HostPresenceGuardService.agoraFrameToInputImage(
              yBuffer: yBuffer,
              uBuffer: uBuffer,
              vBuffer: vBuffer,
              yStride: yStride,
              uStride: videoFrame.uStride ?? (width ~/ 2),
              vStride: videoFrame.vStride ?? (width ~/ 2),
              width: width,
              height: height,
              rotation: videoFrame.rotation ?? 0,
            );
            if (inputImage == null) {
              _presenceGuard.reportAgoraFrameFailure();
              return;
            }
            final brightness = HostPresenceGuardService.agoraFrameBrightness(
              yBuffer,
              yStride,
              width,
              height,
            );
            _presenceGuard.submitAgoraFrame(inputImage, brightness: brightness);
          } catch (e, s) {
            _presenceGuard.reportAgoraFrameFailure();
            Log.e(_tag, 'onCaptureVideoFrame failed', e, s);
          }
        },
      );
      _engine.getMediaEngine().registerVideoFrameObserver(_videoFrameObserver!);
      Log.d(_tag, 'Agora VideoFrameObserver registered for presence guard');
    } catch (e, s) {
      Log.e(_tag, 'registerVideoFrameObserver failed', e, s);
    }
  }

  /// Unregister the Agora video frame observer (called on dispose).
  void _unregisterVideoFrameObserver() {
    final observer = _videoFrameObserver;
    if (observer == null) return;
    _videoFrameObserver = null;
    try {
      _engine.getMediaEngine().unregisterVideoFrameObserver(observer);
      Log.d(_tag, 'Agora VideoFrameObserver unregistered');
    } catch (e) {
      Log.w(_tag, 'unregisterVideoFrameObserver failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Re-enable wakelock when user returns to the live stream.
    if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable();
      // Resume publishing local video if host (was muted when backgrounded).
      if (widget.isHost || _isJoined) {
        try {
          _engine.muteLocalVideoStream(
            widget.isHost ? !_cameraEnabled : _isCameraOff,
          );
        } catch (_) {}
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // When backgrounded, mute the local camera to save bandwidth/upload.
      // The foreground service keeps the Agora session alive so audio
      // continues and the host is not dropped from the room.
      if (widget.isHost || _isJoined) {
        try {
          _engine.muteLocalVideoStream(true);
        } catch (_) {}
      }
    }
  }

  Future<void> _initAgora() async {
    try {
      final session = context.read<SessionManager>();
      final appId = session.getSetting()?.agoraKey ?? _agoraAppIdFallback;
      final appCert = session.getSetting()?.agoraCertificate;
      // Use Log.e so lifecycle messages are visible in release builds.
      Log.e(
        _tag,
        'initAgora start: appId=${appId.isEmpty ? "EMPTY" : "set"}, cert=${appCert == null ? "null" : "set(${appCert.length}chars)"}, isHost=${widget.isHost}, channel=${widget.liveUser.channel}, userId=${widget.liveUser.userId}, agoraUID=${widget.liveUser.agoraUID}',
      );

      if (appId.isEmpty) {
        Log.e(
          _tag,
          'Agora app ID not configured — cannot initialize engine',
          null,
          null,
        );
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Live streaming not configured. Please try again later.',
          );
          context.goNamed(AppRoutes.main);
        }
        return;
      }

      final perms = await [Permission.camera, Permission.microphone].request();
      final camDenied = perms[Permission.camera]?.isGranted != true;
      final micDenied = perms[Permission.microphone]?.isGranted != true;
      if (camDenied || micDenied) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Camera and microphone permissions are required',
          );
          _showPermissionDialog();
        }
        return;
      }

      _engine = createAgoraRtcEngineEx();
      await _engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            Log.e(_tag, 'joined channel ${connection.channelId}');
            if (mounted && _hostOffline) setState(() => _hostOffline = false);
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            Log.e(_tag, 'remote user $remoteUid joined (connection.channelId=${connection.channelId}) pkRemoteUid=$_pkRemoteAgoraUid pkIsHost1=$_pkIsHost1');

            // PK opponent video — create dedicated PK remote controller.
            if (_pkRemoteAgoraUid == remoteUid) {
              setState(() {
                _pkRemoteController = VideoViewController.remote(
                  rtcEngine: _engine,
                  canvas: VideoCanvas(
                    uid: remoteUid,
                    renderMode: RenderModeType.renderModeHidden,
                    mirrorMode: VideoMirrorModeType.videoMirrorModeDisabled,
                  ),
                  connection: RtcConnection(
                    channelId:
                        _pkIsHost1
                            ? (_pkConfig?.host1Channel ?? '')
                            : (_pkConfig?.host2Channel ?? ''),
                  ),
                  useFlutterTexture: true,
                  useAndroidSurfaceView: false,
                );
              });
              return;
            }
            final knownCoHostUids =
                _coHosts.map(_coHostAgoraUid).where((uid) => uid > 0).toSet();
            final role = resolveLiveVideoParticipant(
              isRoomHost: widget.isHost,
              remoteUid: remoteUid,
              expectedHostUid: widget.liveUser.agoraUID,
              currentHostUid: _remoteUid,
              knownCoHostUids: knownCoHostUids,
              pkOpponentUid: _pkRemoteAgoraUid,
            );
            if (role == LiveVideoParticipantRole.host) {
              setState(() {
                _hostOffline = false;
                _remoteUid = remoteUid;
                _createRemoteController(remoteUid);
              });
            } else if (role == LiveVideoParticipantRole.coHost &&
                !_coHostControllers.containsKey(remoteUid)) {
              _bindRemoteUidToPendingCoHost(remoteUid);
              _createCoHostController(remoteUid);
            }
          },
          onUserOffline: (
            RtcConnection connection,
            int remoteUid,
            UserOfflineReasonType reason,
          ) {
            Log.e(_tag, 'remote user $remoteUid offline: reason=$reason');
            if (_pkRemoteAgoraUid == remoteUid) {
              setState(() => _pkRemoteController = null);
              return;
            }

            if (remoteUid == widget.liveUser.agoraUID ||
                remoteUid == _remoteUid) {
              setState(() {
                _remoteUid = null;
                _remoteController = null;
              });
              Fluttertoast.showToast(msg: 'Host went offline');
            }

            // Remove co-host controller if present.
            if (_coHostControllers.containsKey(remoteUid)) {
              setState(() {
                _coHostControllers.remove(remoteUid);
                _coHosts.removeWhere((h) => _coHostAgoraUid(h) == remoteUid);
              });
            }
          },
          onError: (ErrorCodeType err, String msg) {
            Log.e(_tag, 'agora error $err: $msg');
            if (err == ErrorCodeType.errInvalidToken) {
              Fluttertoast.showToast(
                msg: 'Invalid token — live stream may have ended',
              );
            }
          },
          onChannelMediaRelayStateChanged: (state, code) {
            Log.d(_tag, 'PK media relay state=$state code=$code');
            if (state == ChannelMediaRelayState.relayStateRunning) {
              _pkRelayStarted = true;
              _pkRelayRetryCount = 0;
              _pkRelayRetryTimer?.cancel();
              _pkRelayRetryTimer = null;
            } else if (state == ChannelMediaRelayState.relayStateFailure) {
              _pkRelayStarted = false;
            }
            // state FAILURE — retry relay.
            if (state == ChannelMediaRelayState.relayStateFailure &&
                _isPkActive &&
                _pkConfig != null) {
              if (_pkRelayRetryCount < _pkRelayMaxRetries) {
                _pkRelayRetryCount++;
                Log.d(
                  _tag,
                  'PK relay retry $_pkRelayRetryCount/$_pkRelayMaxRetries in 2s',
                );
                _pkRelayRetryTimer?.cancel();
                _pkRelayRetryTimer = Timer(const Duration(seconds: 2), () {
                  if (mounted && _isPkActive) {
                    unawaited(_startPkMediaRelay());
                  }
                });
              } else {
                Log.e(_tag, 'PK relay max retries reached');
              }
            }
          },
          onNetworkQuality: (
            RtcConnection connection,
            int remoteUid,
            QualityType rxQuality,
            QualityType txQuality,
          ) {
            // Use the worse of rx/tx quality as the overall indicator.
            final worst =
                rxQuality.index > txQuality.index ? rxQuality : txQuality;
            if (mounted && worst.index != _networkQuality) {
              setState(() => _networkQuality = worst.index);
            }
          },
          onConnectionLost: (RtcConnection connection) {
            Log.e(_tag, 'agora connection lost');
            if (mounted) setState(() => _hostOffline = true);
          },
          onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
            Log.e(_tag, 'token privilege will expire, renewing...');
            final session = context.read<SessionManager>();
            final newToken = _generateAgoraToken(
              appId: session.getSetting()?.agoraKey ?? _agoraAppIdFallback,
              appCert: session.getSetting()?.agoraCertificate,
              channel: connection.channelId ?? '',
              uid: widget.isHost ? widget.liveUser.agoraUID : 0,
            );
            if (newToken.isNotEmpty) {
              _engine.renewToken(newToken);
            }
          },
          onAudioMixingStateChanged: (state, reason) {
            Log.d(_tag, 'audioMixing state=$state reason=$reason');
            _musicController?.onAudioMixingStateChanged(state, reason);
          },
        ),
      );

      await _engine.enableVideo();

      // Register a native Agora video frame observer so the Host Presence
      // Guard can inspect REAL camera frames (I420) instead of the black
      // Flutter surface captured by RepaintBoundary.toImage(). The observer
      // forwards each captured local frame to the presence guard; the guard
      // throttles analysis internally.
      if (widget.isHost) _registerVideoFrameObserver();

      // Enable the Agora clear-vision video filter extension for beauty effects.
      try {
        await _engine.enableExtension(
          provider: 'agora_video_filters_clear_vision',
          extension: 'clear_vision',
        );
      } catch (e) {
        Log.w(_tag, 'clear_vision extension not available: $e');
      }

      // Match native UnilivePro encoder config: fixed portrait orientation.
      await _engine.setVideoEncoderConfiguration(_getVideoConfig());

      // Apply beauty settings selected on Go Live screen.
      if (widget.smoothness > 0 ||
          widget.lightening > 0 ||
          widget.redness > 0) {
        try {
          await _engine.setBeautyEffectOptions(
            enabled: true,
            options: BeautyOptions(
              lighteningContrastLevel: _currentLighteningContrast,
              lighteningLevel: widget.lightening,
              smoothnessLevel: widget.smoothness,
              rednessLevel: widget.redness,
              sharpnessLevel: 0,
            ),
          );
        } catch (e, s) {
          Log.e(_tag, 'setBeautyEffectOptions failed', e, s);
        }
      }

      if (widget.isHost) {
        await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      } else {
        await _engine.setClientRole(role: ClientRoleType.clientRoleAudience);
        // Optimized for multi-user live: request lower resolution for remote if data usage is a concern,
        // but here we ensure high quality for the main host.
        await _engine.setRemoteDefaultVideoStreamType(
          VideoStreamType.videoStreamHigh,
        );
      }

      // Use Flutter Texture rendering path. The SDK has been patched to render
      // even before dimensions are known, and Impeller is disabled to avoid
      // external-texture rendering issues on Nokia G42 5G.
      final channel = widget.liveUser.channel ?? widget.liveUser.userId ?? '';
      final uid = widget.isHost ? widget.liveUser.agoraUID : 0;

      if (widget.isHost) {
        _localController = VideoViewController(
          rtcEngine: _engine,
          canvas: const VideoCanvas(
            uid: 0,
            renderMode: RenderModeType.renderModeHidden,
            // Mirror the host's local self-view like a front-camera selfie.
            // The published stream remains unmirrored via VideoEncoderConfiguration.
            mirrorMode: VideoMirrorModeType.videoMirrorModeEnabled,
          ),
          useFlutterTexture: true,
          useAndroidSurfaceView: false,
        );
      } else {
        final hostAgoraUid = widget.liveUser.agoraUID;
        Log.e(_tag, 'audience: expected host uid=$hostAgoraUid');
        if (hostAgoraUid > 0) {
          _remoteUid = hostAgoraUid;
          _remoteController = VideoViewController.remote(
            rtcEngine: _engine,
            canvas: VideoCanvas(
              uid: hostAgoraUid,
              renderMode: RenderModeType.renderModeHidden,
              mirrorMode: VideoMirrorModeType.videoMirrorModeDisabled,
            ),
            connection: RtcConnection(channelId: channel),
            useFlutterTexture: true,
            useAndroidSurfaceView: false,
          );
        }
      }

      // Persist for the onAgoraVideoViewCreated callback.
      _channel = channel;
      _uid = uid;
      _agoraAppId = appId;
      _agoraAppCertificate = appCert;

      // Show the video view.
      if (mounted) {
        _initMusicController();
        setState(() => _engineReady = true);
      }

      // Retry video setup every 1.5s up to 12 times (matches native
      // startAudienceVideoRetry) until the view is created or join succeeds.
      _videoStartFallbackTimer = Timer.periodic(
        const Duration(milliseconds: 1500),
        (_) async {
          if (_videoStarted || !mounted) {
            _videoStartFallbackTimer?.cancel();
            _videoStartFallbackTimer = null;
            return;
          }
          _videoStartRetryCount++;
          if (_videoStartRetryCount > _videoStartMaxRetries) {
            _videoStartFallbackTimer?.cancel();
            _videoStartFallbackTimer = null;
            Log.e(_tag, 'video start retry exhausted');
            return;
          }
          Log.d(_tag, 'video start retry #$_videoStartRetryCount');
          await _startVideo();
        },
      );
    } catch (e, s) {
      Log.e(_tag, 'initAgora failed', e, s);
      if (mounted) setState(() => _engineReady = true);
    }
  }

  /// Create the unified room music controller once the Agora engine is ready
  /// and wire its socket hooks so host actions sync to viewers.
  void _initMusicController() {
    if (_musicController != null) return;
    final liveId = widget.liveUser.liveRoomId ?? '';
    _musicController = RoomMusicController(
      engine: _engine,
      isHost: widget.isHost,
      hooks: RoomMusicSocketHooks(
        onPlay:
            (track, pos) => SocketService.instance.emit(Const.eventMusicPlay, {
              'liveStreamingId': liveId,
              'track': track.toSocketJson(),
              'positionMs': pos,
            }),
        onPause:
            () => SocketService.instance.emit(Const.eventMusicPause, {
              'liveStreamingId': liveId,
            }),
        onResume:
            () => SocketService.instance.emit(Const.eventMusicResume, {
              'liveStreamingId': liveId,
            }),
        onStop:
            () => SocketService.instance.emit(Const.eventMusicStop, {
              'liveStreamingId': liveId,
            }),
        onSeek:
            (pos) => SocketService.instance.emit(Const.eventMusicSeek, {
              'liveStreamingId': liveId,
              'positionMs': pos,
            }),
        onTrackChanged:
            (track) => SocketService.instance.emit(Const.eventMusicPlay, {
              'liveStreamingId': liveId,
              'track': track.toSocketJson(),
              'positionMs': 0,
            }),
        onVolume:
            (vol) => SocketService.instance.emit(Const.eventMusicVolume, {
              'liveStreamingId': liveId,
              'volume': vol,
            }),
      ),
    );
  }

  Future<void> _onAgoraVideoViewCreated(int viewId) async {
    Log.e(
      _tag,
      'AgoraVideoView created: viewId=$viewId, isHost=${widget.isHost}',
    );
    _videoStartFallbackTimer?.cancel();
    _videoStartFallbackTimer = null;
    await _startVideo();
  }

  Future<void> _startVideo() async {
    if (!mounted) return;
    if (_videoStarted || _videoStarting) return;
    final channel = _channel;
    final uid = _uid;
    if (channel == null || uid == null) {
      Log.e(_tag, '_startVideo: channel/uid not set', null, null);
      return;
    }
    _videoStarting = true;
    final isGameScreen =
        widget.isHost &&
        (widget.liveUser.broadcastType == 'screen' ||
            widget.liveUser.category?.toLowerCase() == 'gaming');
    try {
      await _joinAgoraChannel(
        uid: uid,
        broadcaster: widget.isHost,
        startPreview: widget.isHost,
        screenShare: isGameScreen,
      );
      // Game LIVE: start screen share when the broadcast type is screen.
      if (isGameScreen) {
        ScreenShareService.instance.setEngine(_engine);
        await ScreenShareService.instance.startScreenShare();
      }
      _videoStarted = true;
      Log.d(_tag, 'video started successfully, uid=$uid');
    } catch (e, s) {
      Log.e(_tag, '_startVideo failed, will retry if attempts left', e, s);
    } finally {
      _videoStarting = false;
    }
  }

  /// Join (or rejoin) the Agora channel with a specific [uid] and role.
  /// Used for initial join and for a viewer switching to co-host.
  Future<void> _joinAgoraChannel({
    required int uid,
    required bool broadcaster,
    bool startPreview = false,
    bool screenShare = false,
  }) async {
    final channel = _channel;
    if (channel == null) {
      Log.e(_tag, '_joinAgoraChannel: channel not set', null, null);
      return;
    }

    final appId = _agoraAppId;
    final appCert = _agoraAppCertificate;
    if (appId.isEmpty) {
      Log.e(_tag, '_joinAgoraChannel: appId empty', null, null);
      return;
    }

    try {
      if (startPreview) {
        await _engine.startPreview();
        Log.e(_tag, 'startPreview done');
      }

      // Host: use backend-provided token (generated for host's agoraUID).
      // Audience / co-host: generate locally for their specific uid.
      String token = '';
      if (widget.isHost && (widget.liveUser.token ?? '').isNotEmpty) {
        token = widget.liveUser.token!;
      } else {
        token = _generateAgoraToken(
          appId: appId,
          appCert: appCert,
          channel: channel,
          uid: uid,
        );
      }
      final tokenPrefix = token.isEmpty
          ? 'EMPTY'
          : 'set(${token.length}chars, prefix=${token.length > 35 ? token.substring(0, 35) : token})';
      Log.e(
        _tag,
        'joinChannel: channel=$channel, token=$tokenPrefix, uid=$uid, broadcaster=$broadcaster',
      );

      await _engine.joinChannel(
        token: token,
        channelId: channel,
        options: ChannelMediaOptions(
          clientRoleType:
              broadcaster
                  ? ClientRoleType.clientRoleBroadcaster
                  : ClientRoleType.clientRoleAudience,
          publishCameraTrack: broadcaster && !screenShare,
          publishScreenCaptureVideo: broadcaster && screenShare,
          publishMicrophoneTrack: broadcaster,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
        uid: uid,
      );
      Log.e(_tag, 'joinChannel done, uid=$uid, broadcaster=$broadcaster');

      // Enable 3D spatial audio when the AI feature is active.
      if (mounted) {
        try {
          final ai = context.read<AIFeatureManager>();
          await AgoraExtensionsService.instance.enableSpatialAudio(_engine, ai);
        } catch (_) {}
      }
    } catch (e, s) {
      Log.e(_tag, '_joinAgoraChannel failed', e, s);
      rethrow;
    }
  }

  String _generateAgoraToken({
    required String appId,
    required String? appCert,
    required String channel,
    required int uid,
  }) {
    if (appCert == null || appCert.isEmpty) {
      Log.e(
        _tag,
        'agoraCertificate missing â€” cannot generate token',
        null,
        null,
      );
      return '';
    }
    try {
      final token = RtcTokenBuilder.buildTokenWithUid(
        appId: appId,
        appCertificate: appCert,
        channelName: channel,
        uid: uid,
        tokenExpireSeconds: 36000,
      );
      Log.d(_tag, 'generated local Agora token for uid=$uid channel=$channel');
      return token;
    } catch (e) {
      Log.e(_tag, 'token generation failed', e);
      return '';
    }
  }

  String _formatNumber(int n) {
    final s = n.abs().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
      count++;
    }
    final result = buffer.toString().split('').reversed.join();
    return n < 0 ? '-$result' : result;
  }

  Future<void> _leaveAndRelease() async {
    try {
      // Unregister the Agora video frame observer before releasing the
      // engine so the presence guard stops receiving frames.
      _unregisterVideoFrameObserver();
      // Stop the host presence guard + tear down AI extensions.
      // Capture the AI manager before any await so we don't touch context
      // across an async gap.
      AIFeatureManager? aiManager;
      try {
        aiManager = context.read<AIFeatureManager>();
      } catch (_) {}
      await _presenceGuard.stop();
      if (aiManager != null) {
        try {
          await AgoraExtensionsService.instance.dispose(_engine, aiManager);
        } catch (_) {}
      }
      await _engine.leaveChannel();
      await _engine.release();
    } catch (e) {
      Log.e(_tag, 'leaveAndRelease failed', e);
    }
  }

  void _syncLiveTime() {
    // 1. Try the API first — backend now returns reliable elapsedTime
    //    computed from liveUser.createdAt (server-side, no clock drift).
    try {
      ApiService.getLiveTime(
            liveUserId: widget.liveUser.userId ?? '',
            liveStreamingId: widget.liveUser.liveRoomId ?? '',
          )
          .then((res) {
            Log.e(
              _tag,
              'syncLiveTime response: elapsedTime=${res.elapsedTime}, status=${res.status}',
            );
            if (res.elapsedTime > 0 && mounted) {
              _setDurationSeconds(res.elapsedTime);
            }
          })
          .catchError((e) {
            Log.e(_tag, 'syncLiveTime failed', e);
            _fallbackLiveTime();
          });
    } catch (e) {
      Log.e(_tag, 'syncLiveTime error', e);
      _fallbackLiveTime();
    }

    // 2. Host-only: emit a roomTime heartbeat so the backend can update
    //    host live history / rewards even if the old updateLiveTime HTTP
    //    endpoint is missing (it currently returns 404).
    if (widget.isHost && mounted) {
      try {
        SocketService.instance.emit(Const.eventRoomTime, {
          'liveStreamingId':
              widget.liveUser.liveRoomId ?? widget.liveUser.id ?? '',
          'liveUserId': widget.liveUser.userId ?? '',
          'userId': SessionManager.instance?.userId ?? '',
          'watchSeconds': _durationSeconds,
          'micOn': _micEnabled,
          'isHost': true,
        });
      } catch (e) {
        Log.e(_tag, 'roomTime emit failed', e);
      }

      // Sync to local cache using the session userId so the Host Dashboard,
      // which loads data with the same id, can read the cached progress. The
      // room's liveUserId may be a uniqueId while the session id is _id.
      _syncHostCache(SessionManager.instance?.userId ?? widget.liveUser.userId ?? '');
    }
  }

  void _syncHostCache(String hostId) {
    if (hostId.isEmpty) return;
    final duration = _durationSeconds.clamp(0, _durationSeconds);
    final durDelta = duration - _lastCachedDuration;
    if (durDelta > 0) {
      HostLiveCache.addDuration(
        userId: hostId,
        liveType: 'video',
        seconds: durDelta,
      );
      _lastCachedDuration = duration;
    }
    final earnings = _giftStatsController.hostEarnings;
    final earDelta = earnings - _lastCachedEarnings;
    if (earDelta > 0) {
      HostLiveCache.addEarnings(userId: hostId, coins: earDelta);
      _lastCachedEarnings = earnings;
    }
  }

  void _showRelationshipEntrance(ViewerEntry v) {
    if (v.relationshipType == null || !mounted) return;
    _relationshipEntryKey.currentState?.addEntry(
      RelationshipEntryData(
        userId: v.userId ?? '',
        userName: v.name ?? 'User',
        userImage: v.image,
        relationshipType: v.relationshipType,
        level:
            v.relationshipType == 'cp'
                ? (v.cpLevel ?? 1)
                : (v.friendLevel ?? 1),
      ),
    );
  }

  /// Fallback: calculate elapsed time from the stream's start timestamp
  /// when the API is unavailable.
  void _fallbackLiveTime() {
    // Try the "time" field (Unix timestamp in seconds from API response).
    if (widget.liveUser.time > 0) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final elapsed = now - widget.liveUser.time;
      if (elapsed > 0 && mounted) {
        _setDurationSeconds(elapsed);
      }
      return;
    }
    // Try createdAt (ISO date string).
    final createdAt = widget.liveUser.createdAt;
    if (createdAt != null && createdAt.isNotEmpty) {
      try {
        final created = DateTime.parse(createdAt);
        final elapsed = DateTime.now().difference(created).inSeconds;
        if (elapsed > 0 && mounted) {
          _setDurationSeconds(elapsed);
        }
      } catch (_) {}
    }
  }

  /// The server (and native clients) may send [comment] events in two ways:
  ///   1. Plain object: all fields are top-level.
  ///   2. Nested [PKLiveStramComment]: the `comment` field itself is a JSON
  ///      string containing the comment object; the outer map is a wrapper.
  /// This helper returns the effective comment payload.
  /// Extract image badge URLs (level, VIP, medals, achievements) from a
  /// comment payload — mirrors audio room logic so video live shows the same
  /// badges.
  List<String> _extractCommentBadgeUrls(Map<String, dynamic> payload) {
    final urls = <String>[];

    void addUnique(String value) {
      final text = value.trim();
      if (text.isEmpty || urls.contains(text)) return;
      urls.add(text);
    }

    void collect(dynamic value) {
      if (value == null) return;
      if (value is List) {
        for (final item in value) {
          collect(item);
        }
        return;
      }
      if (value is Map) {
        final m = Map<String, dynamic>.from(value);
        for (final key in const [
          'image',
          'url',
          'icon',
          'iconUrl',
          'badgeUrl',
          'badgeImage',
          'levelBadgeUrl',
          'vipBadgeUrl',
          'vipBadgeImage',
        ]) {
          collect(m[key]);
        }
        return;
      }
      if (value is String) {
        final text = value.trim();
        final lower = text.toLowerCase();
        final looksLikeAsset =
            text.startsWith('http') ||
            text.startsWith('/') ||
            lower.contains('.png') ||
            lower.contains('.webp') ||
            lower.contains('.jpg') ||
            lower.contains('.jpeg') ||
            lower.contains('.gif') ||
            lower.contains('.svga');
        if (looksLikeAsset) addUnique(text);
      }
    }

    final user =
        payload['user'] is Map
            ? Map<String, dynamic>.from(payload['user'] as Map)
            : <String, dynamic>{};
    for (final source in [payload, user]) {
      for (final key in const [
        'badges',
        'medals',
        'achievements',
        'achievementBadges',
        'tags',
        'vipBadgeUrl',
        'familyBadgeUrl',
        'levelBadgeUrl',
        'level',
        'hostLevel',
        'vipDetails',
      ]) {
        collect(source[key]);
      }
    }
    return urls;
  }

  /// Extract text tag labels (agency, bd, custom tags) from a comment payload.
  List<String> _extractCommentTagLabels(Map<String, dynamic> payload) {
    final labels = <String>{};
    final user =
        payload['user'] is Map
            ? Map<String, dynamic>.from(payload['user'] as Map)
            : <String, dynamic>{};

    void addLabel(String? value) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) labels.add(text);
    }

    for (final source in [payload, user]) {
      if (source['isAgency'] == true) addLabel('Agency');
      if (source['isBd'] == true) addLabel('BD');
      final tags = source['tags'];
      if (tags is List) {
        for (final tag in tags) {
          if (tag is String) addLabel(tag);
          if (tag is Map) addLabel(tag['name']?.toString());
        }
      }
      final userTags = source['userTags'];
      if (userTags is List) {
        for (final tag in userTags) {
          if (tag is String) addLabel(tag);
          if (tag is Map) addLabel(tag['name']?.toString());
        }
      }
    }
    return labels.toList();
  }

  Map<String, dynamic> _unwrapCommentPayload(dynamic data) {
    if (data is List && data.isNotEmpty) {
      return _unwrapCommentPayload(data.first);
    }
    Map<String, dynamic> payload;
    if (data is Map) {
      payload = Map<String, dynamic>.from(data);
    } else if (data is String) {
      try {
        return _unwrapCommentPayload(jsonDecode(data));
      } catch (_) {
        return {};
      }
    } else {
      return {};
    }
    for (final key in const ['data', 'payload', 'result']) {
      final nested = payload[key];
      final unwrapped =
          nested is Map || nested is List || nested is String
              ? _unwrapCommentPayload(nested)
              : <String, dynamic>{};
      if (unwrapped.isNotEmpty) {
        final merged = Map<String, dynamic>.from(unwrapped);
        for (final entry in payload.entries) {
          if (entry.key != key && merged[entry.key] == null) {
            merged[entry.key] = entry.value;
          }
        }
        payload = merged;
        break;
      }
    }

    final commentField = payload['comment'];
    if (commentField is String && commentField.trim().startsWith('{')) {
      try {
        final nested = jsonDecode(commentField);
        if (nested is Map<String, dynamic>) {
          // Outer wrapper values (liveStreamingId, liveUserId) take precedence
          // when the nested payload is missing them.
          final merged = Map<String, dynamic>.from(nested);
          for (final entry in payload.entries) {
            if (entry.key != 'comment' && merged[entry.key] == null) {
              merged[entry.key] = entry.value;
            }
          }
          return merged;
        }
      } catch (_) {}
    }
    return payload;
  }

  void _listenSocketEvents() {
    final socket = SocketService.instance;
    final liveId = widget.liveUser.liveRoomId;
    final liveUserMongoId = widget.liveUser.id;

    // Explicitly connect to this room on the backend to receive events (SS 11).
    socket.emit(Const.eventLiveRoomConnect, {
      'liveStreamingId': liveId,
      'liveUserId': widget.liveUser.userId,
      if (liveUserMongoId != null && liveUserMongoId.isNotEmpty)
        'liveUserMongoId': liveUserMongoId,
    });

    // On socket reconnect, tell the backend we are back in the room.
    final currentUserId = context.read<SessionManager>().userId;
    _reconnectSub?.cancel();
    _reconnectSub = SocketService.instance.reconnectStream.listen((_) {
      try {
        SocketService.instance.emit(Const.eventLiveRejoin, {
          'liveStreamingId': liveId,
          'liveUserId': widget.liveUser.userId,
          'liveType': 'video',
          'userId': currentUserId,
        });
        SocketService.instance.emit(Const.eventRoomPollRestore, {
          'liveStreamingId': liveId,
          'userId': currentUserId,
        });
        if (widget.isHost) {
          SocketService.instance.emit(Const.eventRoomAnalyticsRequest, {
            'liveStreamingId': liveId,
            'userId': currentUserId,
          });
        }
        Log.d(_tag, 'emitted liveRejoin on socket reconnect');
      } catch (e) {
        Log.e(_tag, 'liveRejoin emit failed', e);
      }
    });

    _cancelCommentSub = socket.on(Const.eventComment, (data) {
      try {
        final map = _unwrapCommentPayload(data);
        if (map.isEmpty) return;
        final liveStreamingId = map['liveStreamingId']?.toString();
        // Only filter by liveStreamingId if backend actually sends it.
        if (liveStreamingId != null &&
            liveStreamingId.isNotEmpty &&
            liveStreamingId != liveId)
          return;
        final commentText = map['comment']?.toString() ?? '';
        final userMap =
            map['user'] is Map<String, dynamic>
                ? map['user'] as Map<String, dynamic>
                : (map['user'] is Map
                    ? Map<String, dynamic>.from(map['user'] as Map)
                    : <String, dynamic>{});
        final userName =
            map['name']?.toString() ?? userMap['name']?.toString() ?? 'User';
        final imageUrl = map['imageUrl']?.toString() ?? '';
        final senderId =
            map['userId']?.toString() ??
            userMap['_id']?.toString() ??
            userMap['id']?.toString() ??
            '';
        final userImage =
            map['image']?.toString() ?? userMap['image']?.toString() ?? '';
        final userFrame =
            map['avatarFrame']?.toString() ??
            map['avatarFrameImage']?.toString() ??
            map['frameUrl']?.toString() ??
            map['profileFrameUrl']?.toString() ??
            map['selectedFrame']?.toString() ??
            map['activeFrame']?.toString() ??
            userMap['avatarFrame']?.toString() ??
            userMap['avatarFrameImage']?.toString() ??
            userMap['frameUrl']?.toString() ??
            userMap['profileFrameUrl']?.toString() ??
            userMap['selectedFrame']?.toString() ??
            userMap['activeFrame']?.toString() ??
            (userMap['vipDetails'] is Map
                ? ((userMap['vipDetails'] as Map)['profileFrameUrl'] ??
                        (userMap['vipDetails'] as Map)['avatarFrameImage'])
                    ?.toString()
                : null);

        // Skip our own echoed comments unless it's a join request / invite echo.
        final myUserId = context.read<SessionManager>().userId;
        Log.d(
          _tag,
          'comment from=$senderId me=$myUserId text=$commentText type=${map['type']}',
        );

        // VIP styling
        final isVIP =
            map['isVIP'] == true ||
            userMap['isVIP'] == true ||
            userMap['isVip'] == true ||
            (userMap['vip'] != null);

        // Check for call invite sent to this user
        final type = map['type']?.toString() ?? '';
        if (type == 'luckyBag' || type == 'luckyWin') return;
        final targetUserId =
            map['targetUserId']?.toString() ??
            map['mentionedUserId']?.toString();
        if ((type == 'callInvite' || type == 'invite') &&
            targetUserId == myUserId &&
            !widget.isHost) {
          final hostName = map['hostName']?.toString() ?? 'Host';
          _showCallInviteDialog(hostName, Map<String, dynamic>.from(map));
          return;
        }

        // Check for call acceptance for THIS viewer
        if ((type == 'callAccept' ||
                commentText.toLowerCase().contains('request accepted')) &&
            (targetUserId == myUserId ||
                senderId == myUserId ||
                commentText.startsWith(userName)) &&
            !widget.isHost) {
          final coHostEntry = {
            'userId': myUserId,
            'name': userName,
            'image': userImage,
            'avatarFrame': userFrame,
            'agoraUid': _myAgoraUid,
            'isVIP': isVIP,
            'isMute': false,
            'isCameraOff': false,
          };
          setState(() {
            _coHosts.removeWhere((h) => h['userId'] == myUserId);
            _coHosts.add(coHostEntry);
          });
          if (!_isJoined) {
            _isJoined = true;
            _startBroadcast();
            Fluttertoast.showToast(
              msg: 'Join request accepted. Connecting call...',
            );
          }
        }

        if (senderId.isNotEmpty &&
            senderId == myUserId &&
            type != 'callRequest' &&
            type != 'seatRequest')
          return;

        final vipLevel = parseInt(
          map['vipLevel'] ??
              userMap['vipLevel'] ??
              userMap['vipDetails']?['vipLevel'],
          0,
        );
        final levelName = parseString(
          userMap['level']?['name'] ??
              userMap['levelName'] ??
              map['levelName'] ??
              map['level'],
        );
        final isAdmin = userMap['isAdmin'] == true || map['isAdmin'] == true;
        final isHostUser =
            senderId.isNotEmpty &&
            (widget.liveUser.userId?.isNotEmpty == true) &&
            senderId == widget.liveUser.userId;
        final isAgency = userMap['isAgency'] == true || map['isAgency'] == true;
        final isBd = userMap['isBd'] == true || map['isBd'] == true;
        final country = parseString(userMap['country'] ?? map['country']);
        final countryFlagImage = parseString(
          userMap['countryFlagImage'] ?? map['countryFlagImage'],
        );
        final mentionedUserId = map['mentionedUserId']?.toString();
        final mentionedUserName = map['mentionedUserName']?.toString();

        final cpLevel = parseInt(map['cpLevel'] ?? userMap['cpLevel'], 0);
        final friendLevel = parseInt(
          map['friendLevel'] ?? userMap['friendLevel'],
          0,
        );
        final relationshipType = parseString(
          map['relationshipType'] ?? userMap['relationshipType'],
        );

        // Family badge — ports audio room family badge parsing.
        final familyName = parseString(
          map['familyName'] ??
              userMap['familyName'] ??
              userMap['family'] ??
              map['family'],
        );
        final familyBadgeUrl = VideoUtil.getFullImageUrl(
          map['familyBadgeUrl']?.toString() ??
              userMap['familyBadgeUrl']?.toString() ??
              '',
        );

        // Badge URLs + text tags — same extraction as audio room so video
        // live shows the same level/VIP/medal flags and tags.
        final badgeUrls = _extractCommentBadgeUrls(map);
        final tagLabels = _extractCommentTagLabels(map);

        // Call / seat request from viewer: handle from comment stream so
        // requests ALWAYS reach the host even if backend doesn't route requestedCallJoin.
        final isCallRequest =
            type == 'callRequest' ||
            type == 'seatRequest' ||
            map['isRequested'] == true ||
            commentText.toLowerCase().contains(
              'sent a request to join a call',
            ) ||
            commentText.toLowerCase().contains('requested a seat') ||
            commentText.toLowerCase().contains('wants to join');

        if (isCallRequest && senderId.isNotEmpty) {
          final reqAgoraUid = _coHostAgoraUid({
            ...Map<String, dynamic>.from(map),
            'user': userMap,
          });
          final reqEntry = {
            'userId': senderId,
            'name': userName,
            'image': userImage,
            'avatarFrame': userFrame,
            'country': country,
            'agoraUid': reqAgoraUid,
            'isVIP': isVIP,
            if (map['vipDetails'] != null || userMap['vipDetails'] != null)
              'vipDetails': map['vipDetails'] ?? userMap['vipDetails'],
          };
          if (widget.isHost) {
            setState(() {
              _joinRequests.removeWhere((r) => r['userId'] == senderId);
              _joinRequests.add(reqEntry);
            });
            if (!_notifiedRequestIds.contains(senderId)) {
              _notifiedRequestIds.add(senderId);
              Fluttertoast.showToast(msg: '$userName wants to join the call');
              _showJoinRequestDialog(reqEntry);
            }
          }
          setState(
            () => _comments.add(
              _LiveComment(
                name: userName,
                text: 'sent a request to join a call',
                userId: senderId,
                isVIP: isVIP,
                userImage: VideoUtil.getFullImageUrl(userImage),
                frameUrl: userFrame,
                isSystem: true,
                isSeatRequest: true,
                seatRequestUserId: senderId,
                vipStyle: VipPrivilegeHelper.chatStyleFromPayload(
                  Map<String, dynamic>.from(map),
                ),
                vipLevel: vipLevel > 0 ? vipLevel : null,
                levelName: levelName?.isNotEmpty == true ? levelName : null,
                country: country?.isNotEmpty == true ? country : null,
                countryFlagImage:
                    countryFlagImage?.isNotEmpty == true
                        ? countryFlagImage
                        : null,
                isAdmin: isAdmin,
                isHost: isHostUser,
                isAgency: isAgency,
                isBd: isBd,
                familyName: familyName,
                familyBadgeUrl: familyBadgeUrl,
                relationshipType: relationshipType,
                cpLevel: cpLevel > 0 ? cpLevel : null,
                friendLevel: friendLevel > 0 ? friendLevel : null,
                badgeUrls: badgeUrls,
                tagLabels: tagLabels,
              ),
            ),
          );
          _clientCommentCount++;
          _scrollToBottom();
          return;
        }

        // Join comment — backend sends comment with isJoined: true when a
        // viewer enters the room. Show it with the user's profile avatar +
        // "entered the room" text + a door icon (ports native
        // PKLiveStramComment.isJoined → comment adapter entry).
        final isJoined =
            map['isJoined'] == true ||
            map['joined'] == true ||
            userMap['isJoined'] == true ||
            map['type']?.toString() == 'joined';
        if (isJoined) {
          if (_effectSettings.showEnterRoomMessage) {
            setState(
              () => _comments.add(
                _LiveComment(
                  name: userName,
                  text: 'joined the room',
                  userId: senderId,
                  isJoined: true,
                  isVIP: isVIP,
                  userImage: VideoUtil.getFullImageUrl(userImage),
                  frameUrl: userFrame,
                  vipLevel: vipLevel > 0 ? vipLevel : null,
                  levelName: levelName?.isNotEmpty == true ? levelName : null,
                  country: country?.isNotEmpty == true ? country : null,
                  countryFlagImage:
                      countryFlagImage?.isNotEmpty == true
                          ? countryFlagImage
                          : null,
                  isAdmin: isAdmin,
                  isHost: isHostUser,
                  isAgency: isAgency,
                  isBd: isBd,
                  cpLevel: cpLevel > 0 ? cpLevel : null,
                  friendLevel: friendLevel > 0 ? friendLevel : null,
                  relationshipType: relationshipType,
                  familyName: familyName,
                  familyBadgeUrl: familyBadgeUrl,
                  badgeUrls: badgeUrls,
                  tagLabels: tagLabels,
                  vipStyle: VipPrivilegeHelper.chatStyleFromPayload(
                    Map<String, dynamic>.from(map),
                  ),
                ),
              ),
            );
            _clientCommentCount++;
            _scrollToBottom();
          }
          // Entry animation for EVERY joining user — VIPs get the special
          // entrance, regular users get the compact corner entry (mirrors
          // audio room + native UnilivePro). Host also sees entries.
          if (_effectSettings.showEnterRoomEffect) {
            _vipEntryKey.currentState?.addEntry(
              VipEntryData.fromSocketJson(map),
            );
          }
          return;
        }

        if (commentText == 'cheer' || map['type']?.toString() == 'cheer') {
          _cheerKey.currentState?.addCheer(name: userName, imageUrl: userImage);
          return;
        }

        // Image comment (photo sent in chat).
        if (commentText.isEmpty && imageUrl.isNotEmpty) {
          setState(
            () => _comments.add(
              _LiveComment(
                name: userName,
                text: '',
                userId: senderId,
                isVIP: isVIP,
                userImage: VideoUtil.getFullImageUrl(userImage),
                imageUrl: VideoUtil.getFullImageUrl(imageUrl),
                frameUrl: userFrame,
                vipLevel: vipLevel > 0 ? vipLevel : null,
                levelName: levelName?.isNotEmpty == true ? levelName : null,
                country: country?.isNotEmpty == true ? country : null,
                countryFlagImage:
                    countryFlagImage?.isNotEmpty == true
                        ? countryFlagImage
                        : null,
                isAdmin: isAdmin,
                isHost: isHostUser,
                isAgency: isAgency,
                isBd: isBd,
                cpLevel: cpLevel > 0 ? cpLevel : null,
                friendLevel: friendLevel > 0 ? friendLevel : null,
                relationshipType: relationshipType,
                familyName: familyName,
                familyBadgeUrl: familyBadgeUrl,
                badgeUrls: badgeUrls,
                tagLabels: tagLabels,
                vipStyle: VipPrivilegeHelper.chatStyleFromPayload(
                  Map<String, dynamic>.from(map),
                ),
              ),
            ),
          );
          _clientCommentCount++;
          _scrollToBottom();
          return;
        }

        final isSystem = map['isSystem'] == true || userMap['isSystem'] == true;
        final cardImage =
            map['imageUrl']?.toString() ?? map['image']?.toString();
        final cardCta = map['cta']?.toString() ?? map['button']?.toString();
        final cardAction =
            map['action']?.toString() ?? map['deeplink']?.toString();
        final isCard =
            isSystem &&
            (cardImage?.isNotEmpty == true || cardCta?.isNotEmpty == true);

        final newComment = _LiveComment(
          name: userName,
          text: commentText,
          userId: senderId,
          isVIP: isVIP,
          userImage: VideoUtil.getFullImageUrl(userImage),
          frameUrl: userFrame,
          vipLevel: vipLevel > 0 ? vipLevel : null,
          levelName: levelName?.isNotEmpty == true ? levelName : null,
          country: country?.isNotEmpty == true ? country : null,
          countryFlagImage:
              countryFlagImage?.isNotEmpty == true ? countryFlagImage : null,
          isAdmin: isAdmin,
          isHost: isHostUser,
          isAgency: isAgency,
          isBd: isBd,
          isSystem: isSystem,
          isCard: isCard,
          cardImage: cardImage,
          cardCta: cardCta,
          cardAction: cardAction,
          mentionedUserId: mentionedUserId,
          mentionedUserName: mentionedUserName,
          cpLevel: cpLevel > 0 ? cpLevel : null,
          friendLevel: friendLevel > 0 ? friendLevel : null,
          relationshipType: relationshipType,
          familyName: familyName,
          familyBadgeUrl: familyBadgeUrl,
          badgeUrls: badgeUrls,
          tagLabels: tagLabels,
          vipStyle: VipPrivilegeHelper.chatStyleFromPayload(
            Map<String, dynamic>.from(map),
          ),
        );
        setState(() => _comments.add(newComment));
        if (_isTranslationEnabled) _translateComment(newComment);
        _clientCommentCount++;
        _scrollToBottom();
      } catch (e) {
        Log.e(_tag, 'comment parse failed', e);
      }
    });
    _cancelGiftSub = socket.on(Const.eventGift, (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;
        // === GIFT DATA AUDIT — log raw JSON so backend giftType/svgaImage/isBigGift can be verified ===
        Log.d(_tag, 'GIFT_AUDIT eventGift raw: $map');
        final name =
            map['name']?.toString() ??
            map['senderName']?.toString() ??
            'Someone';
        final giftName = map['giftName']?.toString() ?? 'a gift';
        final giftSenderId =
            map['userId']?.toString() ??
            map['senderId']?.toString() ??
            map['user']?['_id']?.toString() ??
            '';
        final giftImage = _safeGiftCommentImage(
          map['giftImage']?.toString() ?? map['image']?.toString() ?? '',
          map['svgaImage']?.toString() ?? '',
        );
        final senderImage = VideoUtil.getFullImageUrl(
          map['senderImage']?.toString() ?? map['userImage']?.toString() ?? '',
        );
        final count = (map['count'] as num?)?.toInt() ?? 1;
        final coin = (map['coin'] as num?)?.toInt() ?? 0;
        final totalCoins = coin * count;
        final giftFamilyName = parseString(
          map['familyName'] ??
              (map['user'] is Map
                  ? map['user']['familyName'] ?? map['user']['family']
                  : null) ??
              map['family'],
        );
        final giftFamilyBadgeUrl = VideoUtil.getFullImageUrl(
          map['familyBadgeUrl']?.toString() ??
              (map['user'] is Map
                  ? map['user']['familyBadgeUrl']?.toString()
                  : '') ??
              '',
        );
        final receiverName =
            map['receiverName']?.toString() ??
            map['receiverUserName']?.toString() ??
            'Host';
        final receiverImage = VideoUtil.getFullImageUrl(
          map['receiverImage']?.toString() ??
              map['receiverUserImage']?.toString() ??
              '',
        );
        setState(
          () => _comments.add(
            _LiveComment(
              name: name,
              text: '',
              userId: giftSenderId,
              isGift: true,
              userImage: senderImage,
              giftImage: giftImage,
              giftCount: count,
              giftCoins: totalCoins,
              giftReceiverName: receiverName,
              giftReceiverImage: receiverImage,
              familyName: giftFamilyName,
              familyBadgeUrl: giftFamilyBadgeUrl,
            ),
          ),
        );
        _scrollToBottom();
        // Feed gift overlay.
        final event = GiftQueueController.fromSocketData(data);
        if (event != null) {
          Log.d(_tag, 'Gift received: $giftName from $name');
          // Record to top contributor leaderboard.
          _topContributorController.recordGift(
            userId: event.senderId,
            name: event.senderName,
            avatar: event.senderImage,
            coins: event.coin * event.count,
            count: event.count,
          );
          // Track this gift in the host earnings / gift wall counter.
          // eventGift is the legacy/room-wide gift broadcast; recording it
          // here ensures the in-room counter and live summary are correct
          // when the backend only emits this event name.
          _giftStatsController.recordGift(event);
          _giftPredictor.addCoins(event.coin * event.count);
          _checkPkSupport(
            event.senderId,
            event.senderName,
            event.senderImage,
            event.coin,
            event.count,
          );
          // Update PK score when a gift is for either host in this battle.
          final myUserId = context.read<SessionManager>().userId;
          if (widget.isHost && event.senderId != myUserId) {
            final receiverId = _resolvePkGiftReceiver(map);
            Log.d(
              _tag,
              'PK_GIFT eventGift receiverId=$receiverId myLiveId=${widget.liveUser.liveRoomId} myUserId=${widget.liveUser.userId} isHost1=$_pkIsHost1 host1Id=${_pkConfig?.host1Id} host2Id=${_pkConfig?.host2Id} roomId=${map['liveStreamingId']} receiverIdField=${map['receiverId']} receiverNameField=${map['receiverName']}',
            );
            if (receiverId != null && receiverId.isNotEmpty) {
              _applyOptimisticPkGiftScore(
                receiverId,
                event.coin * event.count,
              );
            }
          }
          if (_effectSettings.showGiftEffect) {
            final isBig = _bigGiftController.isBigGift(event);
            if (isBig) {
              _bigGiftController.showBigGift(event);
              if (_bigGiftController.shouldShake(event)) {
                _shakeController.shake(
                  (event.coin * event.count / 200).clamp(6.0, 18.0).toDouble(),
                );
              }
            } else {
              _giftController.addGift(event);
            }
            _playGiftReceiveSound(event);
          }
        }

        // Trigger intimacy fly-up if sender or recipient is in a relationship
        if (coin > 0) {
          _intimacyFlyKey.currentState?.spawn(
            text: '+$coin Intimacy',
            position: Offset(
              MediaQuery.of(context).size.width / 2,
              MediaQuery.of(context).size.height / 2,
            ),
          );
        }

        // Feed the 3D gift trigger listener (host side only).
        if (widget.isHost && !_giftsBlocked) {
          try {
            final ai = context.read<AIFeatureManager>();
            DynamicAIFeaturesService.instance.onHighTierGiftReceived(
              giftName: giftName,
              giftCoins: totalCoins,
              ai: ai,
            );
            // Show quick reaction bar for high-tier gifts (>=500 coins).
            if (totalCoins >= 500 &&
                ai.isFeatureEnabled(AIFeatureKeys.voiceTriggered3DGifts)) {
              setState(() => _showGift3DReaction = true);
              _gift3DReactionTimer?.cancel();
              _gift3DReactionTimer = Timer(const Duration(seconds: 15), () {
                if (mounted) setState(() => _showGift3DReaction = false);
              });
            }
          } catch (_) {}
        }
      } catch (_) {}
    });
    _cancelLiveUserGiftSub = socket.on(Const.eventLiveUserGift, (data) {
      // === GIFT DATA AUDIT ===
      Log.d(_tag, 'GIFT_AUDIT eventLiveUserGift raw: $data');
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      // Skip host's own gift echo — host already sees the animation locally
      // from the onGiftSent callback. Prevents duplicate animations.
      final senderId =
          map?['senderId']?.toString() ?? map?['userId']?.toString() ?? '';
      final myUserId = context.read<SessionManager>().userId;
      if (senderId.isNotEmpty && senderId == myUserId) return;
      final event = GiftQueueController.fromSocketData(data);
      if (event != null) {
        // Add gift comment to chat list (Bigo/Chamet-style — other viewers
        // should see "Host sent a gift" in the chat, same as normalUserGift).
        final giftImage = _safeGiftCommentImage(
          map?['giftImage']?.toString() ?? map?['image']?.toString() ?? '',
          map?['svgaImage']?.toString() ?? '',
        );
        final senderImage = VideoUtil.getFullImageUrl(
          map?['senderImage']?.toString() ??
              map?['userImage']?.toString() ??
              '',
        );
        final hostGiftFamilyName = parseString(
          map?['familyName'] ??
              (map?['user'] is Map
                  ? map?['user']?['familyName'] ?? map?['user']?['family']
                  : null) ??
              map?['family'],
        );
        final hostGiftFamilyBadgeUrl = VideoUtil.getFullImageUrl(
          map?['familyBadgeUrl']?.toString() ??
              (map?['user'] is Map
                  ? map?['user']?['familyBadgeUrl']?.toString()
                  : '') ??
              '',
        );
        setState(
          () => _comments.add(
            _LiveComment(
              name: event.senderName,
              text: '',
              userId: event.senderId,
              isGift: true,
              userImage: senderImage,
              giftImage: giftImage,
              giftCount: event.count,
              giftCoins: event.coin * event.count,
              familyName: hostGiftFamilyName,
              familyBadgeUrl: hostGiftFamilyBadgeUrl,
            ),
          ),
        );
        _scrollToBottom();
        if (_effectSettings.showGiftEffect) {
          if (_bigGiftController.isBigGift(event)) {
            _bigGiftController.showBigGift(event);
          } else {
            _giftController.addGift(event);
          }
          _playGiftReceiveSound(event);
        }
        _giftStatsController.recordGift(event);
        _giftPredictor.addCoins(event.coin * event.count);
        // Record to top contributor leaderboard.
        _topContributorController.recordGift(
          userId: event.senderId,
          name: event.senderName,
          avatar: event.senderImage,
          coins: event.coin * event.count,
          count: event.count,
        );
        _checkPkSupport(
          event.senderId,
          event.senderName,
          event.senderImage,
          event.coin,
          event.count,
        );
        // Update PK score when a gift is for either host in this battle.
        if (widget.isHost && event.senderId != myUserId) {
          final receiverId = _resolvePkGiftReceiver(map);
          Log.d(
            _tag,
            'PK_GIFT eventLiveUserGift receiverId=$receiverId myLiveId=${widget.liveUser.liveRoomId} myUserId=${widget.liveUser.userId} isHost1=$_pkIsHost1 host1Id=${_pkConfig?.host1Id} host2Id=${_pkConfig?.host2Id} roomId=${map?['liveStreamingId']} receiverIdField=${map?['receiverId']} receiverNameField=${map?['receiverName']}',
          );
          if (receiverId != null && receiverId.isNotEmpty) {
            _applyOptimisticPkGiftScore(
              receiverId,
              event.coin * event.count,
            );
          }
        }
        // Fly gift to co-host box if receiver is a co-host (not host).
        if (map != null) _maybeFlyGiftToCoHost(map, event);
        // Gift broadcast banner.
        _broadcastOverlayKey.currentState?.enqueue(
          BroadcastEvent(
            type: BroadcastType.giftBroadcast,
            title: '${event.senderName} sent a gift',
            subtitle: '${event.giftName} x${event.count}',
            avatar: event.senderImage,
            image: event.giftImage,
            rightText: 'Go',
            durationSeconds: 5,
          ),
        );
      }
    });
    _cancelNormalUserGiftSub = socket.on(Const.eventNormalUserGift, (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;
        // === GIFT DATA AUDIT ===
        Log.d(_tag, 'GIFT_AUDIT eventNormalUserGift raw: $map');
        final senderId = map['senderId']?.toString() ?? '';
        final myUserId = context.read<SessionManager>().userId;
        // Skip our own gift echo completely — we already added the gift
        // animation locally in the onGiftSent callback above. This prevents
        // duplicate animations when backend echoes back to sender.
        if (senderId.isNotEmpty && senderId == myUserId) {
          return;
        }
        final name =
            map['name']?.toString() ??
            map['senderName']?.toString() ??
            'Someone';
        final giftImage = _safeGiftCommentImage(
          map['giftImage']?.toString() ?? map['image']?.toString() ?? '',
          map['svgaImage']?.toString() ?? '',
        );
        final senderImage = VideoUtil.getFullImageUrl(
          map['senderImage']?.toString() ?? map['userImage']?.toString() ?? '',
        );
        final count = (map['count'] as num?)?.toInt() ?? 1;
        final coin = (map['coin'] as num?)?.toInt() ?? 0;
        final totalCoins = coin * count;
        final normGiftFamilyName = parseString(
          map['familyName'] ??
              (map['user'] is Map
                  ? map['user']['familyName'] ?? map['user']['family']
                  : null) ??
              map['family'],
        );
        final normGiftFamilyBadgeUrl = VideoUtil.getFullImageUrl(
          map['familyBadgeUrl']?.toString() ??
              (map['user'] is Map
                  ? map['user']['familyBadgeUrl']?.toString()
                  : '') ??
              '',
        );
        setState(
          () => _comments.add(
            _LiveComment(
              name: name,
              text: '',
              userId: senderId,
              isGift: true,
              userImage: senderImage,
              giftImage: giftImage,
              giftCount: count,
              giftCoins: totalCoins,
              familyName: normGiftFamilyName,
              familyBadgeUrl: normGiftFamilyBadgeUrl,
            ),
          ),
        );
        _scrollToBottom();
        final event = GiftQueueController.fromSocketData(data);
        if (event != null) {
          if (_effectSettings.showGiftEffect) {
            if (_bigGiftController.isBigGift(event)) {
              _bigGiftController.showBigGift(event);
            } else {
              _giftController.addGift(event);
            }
            _playGiftReceiveSound(event);
          }
          _giftStatsController.recordGift(event);
          // Record to top contributor leaderboard.
          _topContributorController.recordGift(
            userId: event.senderId,
            name: event.senderName,
            avatar: event.senderImage,
            coins: event.coin * event.count,
            count: event.count,
          );
          _checkPkSupport(
            event.senderId,
            event.senderName,
            event.senderImage,
            event.coin,
            event.count,
          );
          // Update PK score when a gift is for either host in this battle.
          final myUserId = context.read<SessionManager>().userId;
          if (widget.isHost && event.senderId != myUserId) {
            final receiverId = _resolvePkGiftReceiver(map);
            Log.d(
              _tag,
              'PK_GIFT eventGift receiverId=$receiverId myLiveId=${widget.liveUser.liveRoomId} myUserId=${widget.liveUser.userId} isHost1=$_pkIsHost1 host1Id=${_pkConfig?.host1Id} host2Id=${_pkConfig?.host2Id} roomId=${map['liveStreamingId']} receiverIdField=${map['receiverId']} receiverNameField=${map['receiverName']}',
            );
            if (receiverId != null && receiverId.isNotEmpty) {
              _applyOptimisticPkGiftScore(
                receiverId,
                event.coin * event.count,
              );
            }
          }
          // Fly gift to co-host box if receiver is a co-host (not host).
          _maybeFlyGiftToCoHost(map, event);
          // Gift broadcast banner (respects EffectSettings.showGiftBroadcast).
          _broadcastOverlayKey.currentState?.enqueue(
            BroadcastEvent(
              type: BroadcastType.giftBroadcast,
              title: '${event.senderName} sent ${event.receiverName} a gift',
              subtitle:
                  'x${event.count} · ${event.coin * event.count} diamonds',
              avatar: event.senderImage,
              image: event.giftImage,
              rightText: 'Go',
              durationSeconds: 5,
            ),
          );
          // Special gift effect (e.g. teddy couple) — broadcast visual effect banner.
          if (_isSpecialGiftEffect(event.giftName)) {
            _broadcastOverlayKey.currentState?.enqueue(
              BroadcastEvent(
                type: BroadcastType.giftEffect,
                title: '${event.senderName} sent a ${event.giftName}',
                subtitle: 'x${event.count}',
                image: event.giftImage,
                durationSeconds: 5,
              ),
            );
          }
        }
      } catch (_) {}
    });
    _cancelLuckyGiftSub = socket.on(Const.luckyGift, (data) {
      try {
        final session = context.read<SessionManager>();
        if (data is num) {
          // Winner-only payload: just the coin amount.
          final coins = data.toInt();
          if (coins > 0) {
            Fluttertoast.showToast(msg: 'You won $coins diamonds');
            setState(
              () => _comments.add(
                _LiveComment(
                  name: 'System',
                  text: 'You won $coins diamonds',
                  isGift: true,
                ),
              ),
            );
            _scrollToBottom();
          }
          return;
        }
        if (data is String) {
          final coins = int.tryParse(data) ?? 0;
          if (coins > 0) {
            Fluttertoast.showToast(msg: 'You won $coins diamonds');
            setState(
              () => _comments.add(
                _LiveComment(
                  name: 'System',
                  text: 'You won $coins diamonds',
                  isGift: true,
                ),
              ),
            );
            _scrollToBottom();
          }
          return;
        }
        if (data is! Map) return;
        final map = data;
        final name =
            map['name']?.toString() ?? map['userName']?.toString() ?? 'Someone';
        final image =
            map['image']?.toString() ?? map['senderImage']?.toString() ?? '';
        final coins =
            (map['coin'] as num?)?.toInt() ??
            (map['diamonds'] as num?)?.toInt() ??
            (map['coins'] as num?)?.toInt() ??
            0;
        if (coins > 0) {
          setState(() {
            _luckyBannerName = name;
            _luckyBannerImage = image;
            _luckyBannerCoins = coins;
          });
          _startLuckyBannerTimer();
          setState(
            () => _comments.add(
              _LiveComment(
                name: 'System',
                text: '$name won lucky gift $coins diamonds!',
                isGift: true,
              ),
            ),
          );
          _scrollToBottom();
          if (map['userId']?.toString() == session.userId) {
            Fluttertoast.showToast(msg: 'You won $coins diamonds');
          }
        }
      } catch (_) {}
    });
    _cancelAddViewSub = socket.on(Const.eventAddView, (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        final hostId = widget.liveUser.userId;
        if (map != null) {
          final v = ViewerEntry.fromJson(map);
          if (v.userId == null || v.userId!.isEmpty || v.userId == hostId)
            return;
          final isNew = !_viewers.any((e) => e.userId == v.userId);
          if (isNew && _effectSettings.showEnterRoomEffect) {
            // Entry for every new viewer (overlay dedupes if the join
            // comment already queued this user).
            _vipEntryKey.currentState?.addEntry(
              VipEntryData.fromSocketJson(map),
            );
            if (!v.isVIP && v.relationshipType != null) {
              _showRelationshipEntrance(v);
            }
          }
          setState(() {
            _viewers.removeWhere((e) => e.userId == v.userId);
            _viewers.add(v);
            _viewerCount = _viewers.length;
          });
        } else {
          setState(() => _viewerCount++);
        }
      } catch (_) {
        setState(() => _viewerCount++);
      }
    });
    _cancelLessViewSub = socket.on(Const.eventLessView, (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        final userId = map?['userId']?.toString();
        final hostId = widget.liveUser.userId;
        if (userId != null && userId.isNotEmpty && userId != hostId) {
          _viewers.removeWhere((v) => v.userId == userId);
          setState(() => _viewerCount = _viewers.length);
        } else if (userId == null || userId.isEmpty) {
          // Backend sent a count-only signal; decrement viewer count.
          setState(
            () => _viewerCount = _viewerCount > 0 ? _viewerCount - 1 : 0,
          );
        }
        // If userId == hostId, ignore — host should never be counted as a viewer.
      } catch (_) {
        setState(() => _viewerCount = _viewerCount > 0 ? _viewerCount - 1 : 0);
      }
    });
    // CP/Friend rich room entrance (Bigo-style couple entrance with SVGA +
    // both partner avatars). Falls back to the simple corner banner via
    // addView.relationshipType when this event is not emitted.
    _cancelCpRoomEntrySub = socket.on(Const.eventCpRoomEntry, (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null || !mounted) return;
        if (_effectSettings.showEnterRoomEffect) {
          _cpEntryKey.currentState?.addEntry(CpEntryData.fromSocketJson(map));
        }
      } catch (e) {
        Log.e(_tag, 'cpRoomEntry parse error', e);
      }
    });
    socket.on(Const.eventView, (data) {
      Log.d(
        _tag,
        'view event received: ${data.runtimeType} ${data is List ? "list of ${data.length}" : data}',
      );
      try {
        final list = data is List ? data : (data is Map ? [data] : null);
        if (list == null || list.isEmpty) return;
        final hostId = widget.liveUser.userId;
        final parsed =
            list
                .whereType<Map>()
                .map((e) {
                  try {
                    return ViewerEntry.fromJson(Map<String, dynamic>.from(e));
                  } catch (_) {
                    return null;
                  }
                })
                .whereType<ViewerEntry>()
                .where((v) => v.userId != hostId && v.isAdd && !v.invisible)
                .toList();
        Log.d(_tag, 'parsed ${parsed.length} viewers');
        if (mounted) {
          setState(() {
            _viewers
              ..clear()
              ..addAll(parsed);
            // VIP room online list top — pin VIP users above non-VIP.
            _viewers.sort((a, b) {
              final aTop = a.isRoomOnlineListTopEnabled || a.isVIP;
              final bTop = b.isRoomOnlineListTopEnabled || b.isVIP;
              if (aTop != bTop) return aTop ? -1 : 1;
              return 0;
            });
            _viewerCount = parsed.length;
          });
          // Vehicle entry effect for viewers joining with an equipped vehicle.
          // The welcome / join message is now shown in the comments list
          // (mirrors audio room "joined the room" chat bubble).
          if (_effectSettings.showVehicleEffect) {
            for (final raw in list.whereType<Map>()) {
              final vMap = Map<String, dynamic>.from(raw);
              if (vMap['userId']?.toString() == hostId) continue;
              final vName =
                  vMap['name']?.toString() ??
                  vMap['userName']?.toString() ??
                  'someone';
              final vehicleImage =
                  vMap['vehicleImage']?.toString() ??
                  vMap['vehicle']?.toString();
              if (vehicleImage != null && vehicleImage.isNotEmpty) {
                final vehicleName =
                    vMap['vehicleName']?.toString() ?? 'Luxury Vehicle';
                _broadcastOverlayKey.currentState?.enqueue(
                  BroadcastEvent(
                    type: BroadcastType.vehicle,
                    title: '$vName arrives in $vehicleName',
                    subtitle: 'room entry vehicle',
                    image: vehicleImage,
                    durationSeconds: 5,
                  ),
                );
              }
            }
          }
        }
      } catch (e) {
        Log.e(_tag, 'view parse', e);
      }
    });
    void onLiveEndEvent(dynamic data, {bool isAdmin = false}) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        final room =
            map?['liveStreamingId']?.toString() ??
            map?['liveRoom']?.toString() ??
            map?['liveRoomId']?.toString();
        final currentLiveId = widget.liveUser.liveRoomId ?? widget.liveUser.id;
        if (room != null && room.isNotEmpty && room != currentLiveId) {
          return;
        }
        final reason =
            map?['reason']?.toString() ??
            (isAdmin
                ? 'Live stream ended by admin'
                : 'Live stream ended by host');
        if (widget.isHost && !isAdmin) {
          return;
        }
        _handleLiveEndedByHost(reason: reason, isAdmin: isAdmin);
      } catch (_) {
        if (!widget.isHost || isAdmin) {
          _handleLiveEndedByHost(isAdmin: isAdmin);
        }
      }
    }

    _cancelLiveEndSub = socket.on(
      'liveEndByEnd',
      (data) => onLiveEndEvent(data),
    );
    _cancelLiveHostEndSub = socket.on(
      Const.eventLiveHostEnd,
      (data) => onLiveEndEvent(data),
    );
    _cancelEndLiveSub = socket.on(
      Const.eventEndLive,
      (data) => onLiveEndEvent(data),
    );
    _cancelLiveEndGenericSub = socket.on(
      'liveEnd',
      (data) => onLiveEndEvent(data),
    );
    _cancelLiveEndByAdminSub = socket.on(
      Const.eventLiveEndByAdmin,
      (data) => onLiveEndEvent(data, isAdmin: true),
    );
    _cancelDestroyRoomSub = socket.on(
      'destroyRoom',
      (data) => onLiveEndEvent(data),
    );

    // AI Host Compliance — backend strike / ban updates.
    _cancelHostComplianceStrikeSub = socket.on(
      Const.eventHostComplianceStrikeUpdate,
      (data) {
        try {
          final map = data is Map ? Map<String, dynamic>.from(data) : null;
          if (map == null) return;
          final update = HostComplianceStrikeUpdate.fromJson(map);
          _presenceGuard.onStrikeUpdateReceived(map);
          final reason = update.message ?? 'Keep your face visible';
          Fluttertoast.showToast(
            msg: reason,
            backgroundColor: Colors.orange.shade900,
            textColor: Colors.white,
            toastLength: Toast.LENGTH_LONG,
          );
          if (update.liveEnded || update.banned) {
            _handleLiveEndedByHost(
              reason:
                  update.message ?? 'Live ended due to compliance violation',
              isAdmin: false,
            );
          }
        } catch (_) {}
      },
    );
    _cancelHostComplianceBanSub = socket.on(Const.eventHostComplianceBan, (
      data,
    ) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;
        final ban = HostComplianceBan.fromJson(map);
        _presenceGuard.onBanReceived(map);
        _handleLiveEndedByHost(
          reason: ban.reason ?? 'Live ended due to compliance violation',
          isAdmin: false,
        );
        Fluttertoast.showToast(
          msg: ban.reason ?? 'Your live has been banned for 24 hours',
          backgroundColor: Colors.red.shade900,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
      } catch (_) {}
    });

    // If a 1-on-1 call is accepted by/through the host, end the live stream
    // automatically so the host can take the call without conflicting streams.
    _cancelCallAnswerSub = socket.on(Const.eventCallAnswer, (data) {
      try {
        if (!widget.isHost) return;
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;
        if (map['isAccept'] != true) return;
        final userId1 = map['userId1']?.toString() ?? '';
        final userId2 = map['userId2']?.toString() ?? '';
        final myId = context.read<SessionManager>().userId;
        if (userId1 == myId || userId2 == myId) {
          Log.d(_tag, 'Host accepted a 1-1 call, ending video live');
          _endLive(confirm: false);
        }
      } catch (_) {}
    });

    // Host migrated from audio room → video live. Auto-join the new video live.
    _cancelMigrateToVideoLiveSub = socket.on(Const.eventMigrateToVideoLive, (
      data,
    ) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;
        final audioLiveId =
            map['audioLiveId']?.toString() ??
            map['liveStreamingId']?.toString();
        final currentLiveId = widget.liveUser.liveRoomId ?? widget.liveUser.id;
        // Only handle if this is the audio room being migrated FROM.
        // The host itself already navigates; this is for viewers/guests of the
        // audio room who are still on the audio room screen. On the video live
        // side we ignore it (different room).
        if (audioLiveId == null || audioLiveId != currentLiveId) return;
        final newLiveStreamingId = map['newLiveStreamingId']?.toString() ?? '';
        final newLiveRoomId = map['newLiveRoomId']?.toString() ?? '';
        if (newLiveStreamingId.isEmpty) return;
        if (_isRoomEnded) return;
        _isRoomEnded = true;
        Log.d(
          _tag,
          '=== MIGRATING TO VIDEO LIVE === from=$audioLiveId to=$newLiveStreamingId',
        );
        // Build a LiveUser for the new video live room and navigate.
        final newLiveUser = live_stream.LiveUser(
          id: newLiveRoomId,
          liveStreamingId: newLiveStreamingId,
          userId: map['hostUserId']?.toString(),
          name: map['hostName']?.toString(),
          image: map['hostImage']?.toString(),
          roomName: map['roomName']?.toString(),
          channel: map['channel']?.toString(),
          agoraUID: (map['agoraUID'] as num?)?.toInt() ?? 0,
          token: map['token']?.toString(),
          isAudio: false,
        );
        // Tear down current room resources before switching.
        _durationTimer?.cancel();
        _liveTimeTimer?.cancel();
        _videoStartFallbackTimer?.cancel();
        _fromChatBannerTimer?.cancel();
        _gift3DReactionTimer?.cancel();
        _reconnectSub?.cancel();
        try {
          _coWatchController?.dispose();
        } catch (_) {}
        try {
          _musicController?.stop();
        } catch (_) {}
        try {
          _engine.leaveChannel();
        } catch (_) {}
        Fluttertoast.showToast(
          msg: 'Host moved to Video Live — joining...',
          backgroundColor: const Color(0xFF6A5AE0),
          textColor: Colors.white,
        );
        if (mounted) {
          Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((r) => r.isFirst || r.settings.name == AppRoutes.liveRoom);
          context.replaceNamed(
            'liveRoom',
            extra: {
              'liveUser': newLiveUser,
              'isHost': false,
              'quality': 'auto',
              'smoothness': 0.0,
              'lightening': 0.0,
              'redness': 0.0,
              'lighteningContrast':
                  LighteningContrastLevel.lighteningContrastNormal,
            },
          );
        }
      } catch (e) {
        Log.e(_tag, 'migrateToVideoLive handler error', e);
      }
    });

    socket.on(Const.eventUserCoinUpdate, (data) {
      try {
        context.read<AuthProvider>().updateUserCoinsFromSocket(data);
      } catch (_) {}
    });

    // Lucky bag created in this room — add the room comment; the app-level
    // overlay owns the single clickable announcement.
    _cancelLuckyBagCreateSub = socket.on(Const.eventLuckyBagCreate, (data) {
      try {
        final map = _unwrapCommentPayload(data);
        if (map.isEmpty || !mounted) return;
        final roomId =
            map['liveStreamingId']?.toString() ??
            map['roomId']?.toString() ??
            '';
        final currentRoomId =
            widget.liveUser.liveRoomId ?? widget.liveUser.id ?? '';
        if (roomId.isNotEmpty && roomId != currentRoomId) return;
        final senderId =
            map['userId']?.toString() ?? map['hostUserId']?.toString() ?? '';
        if (senderId == context.read<SessionManager>().userId) return;
        final senderName =
            map['name']?.toString() ??
            map['senderName']?.toString() ??
            map['userName']?.toString() ??
            'Someone';
        final totalCoins =
            (map['totalCoins'] as num?)?.toInt() ??
            (map['totalCoin'] as num?)?.toInt() ??
            0;
        final bagCount =
            (map['bagCount'] as num?)?.toInt() ??
            (map['winnerCount'] as num?)?.toInt() ??
            0;
        // Also post a chat comment so the lucky bag notification is visible
        // to all viewers AND the broadcaster in the comments section.
        if (mounted) {
          setState(
            () => _comments.add(
              _LiveComment(
                name: senderName,
                text:
                    'sent a $totalCoins diamonds Lucky Bag ($bagCount bags) — tap to claim!',
                isGift: true,
                userImage:
                    map['senderImage']?.toString() ?? map['image']?.toString(),
                userId: map['userId']?.toString() ?? '',
              ),
            ),
          );
          _scrollToBottom();
        }
      } catch (_) {}
    });

    // Lucky bag claimed — announce the win in room chat.
    _cancelLuckyBagClaimSub = socket.on(Const.eventLuckyBagClaim, (data) {
      try {
        final map = _unwrapCommentPayload(data);
        if (map.isEmpty || !mounted) return;
        final roomId =
            map['liveStreamingId']?.toString() ??
            map['roomId']?.toString() ??
            '';
        final currentRoomId =
            widget.liveUser.liveRoomId ?? widget.liveUser.id ?? '';
        if (roomId.isNotEmpty && roomId != currentRoomId) return;
        final claimerId = map['userId']?.toString() ?? '';
        if (claimerId == context.read<SessionManager>().userId) return;
        final name = map['name']?.toString() ?? 'Someone';
        final coins =
            (map['coin'] as num?)?.toInt() ??
            (map['coins'] as num?)?.toInt() ??
            0;
        setState(
          () => _comments.add(
            _LiveComment(
              name: name,
              text: 'won $coins diamonds from the lucky bag',
              isGift: true,
              userImage: map['image']?.toString(),
              userId: map['userId']?.toString() ?? '',
            ),
          ),
        );
        _scrollToBottom();
      } catch (_) {}
    });

    // Live-pushed announcements (next-day gifting events, game schedules,
    // admin broadcasts) — shown in the comments section.
    socket.on('roomAnnouncement', (data) {
      try {
        String? text;
        if (data is Map) {
          text = data['announcement']?.toString() ?? data['text']?.toString();
        } else if (data is String) {
          text = data;
        }
        if (text != null && text.trim().isNotEmpty && mounted) {
          setState(() {
            _comments.add(
              _LiveComment(
                name: 'Announcement',
                text: text!.trim(),
                isSystem: true,
              ),
            );
          });
        }
      } catch (_) {}
    });

    // Host-set room welcome/announcement updates the comments too.
    socket.on(Const.eventRoomWelcome, (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        final welcome = map?['roomWelcome']?.toString();
        if (welcome != null && welcome.trim().isNotEmpty && mounted) {
          setState(() {
            _comments.add(
              _LiveComment(
                name: 'Announcement',
                text: welcome.trim(),
                isSystem: true,
              ),
            );
          });
        }
      } catch (_) {}
    });

    // Room-wide sound effects — when anyone plays a sound effect, every
    // room member hears it locally (assets are bundled in the app).
    socket.on('roomSoundEffect', (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null || !mounted) return;
        final senderId = map['userId']?.toString() ?? '';
        if (senderId == context.read<SessionManager>().userId) return;
        final effectId = map['effectId']?.toString() ?? '';
        final effect =
            SoundEffect.defaults().where((e) => e.id == effectId).firstOrNull;
        if (effect != null) _musicSoundService.playSoundEffect(effect);
      } catch (_) {}
    });

    socket.on(Const.eventMaintenance, (_) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Under Maintenance'),
                content: const Text(
                  'We are under maintenance. Please try again later.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.popUntil(ctx, (r) => r.isFirst),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
        );
      }
    });

    socket.on(Const.eventUserBlock, (_) {
      if (mounted) {
        Fluttertoast.showToast(msg: 'You have been removed from the room');
        Navigator.pop(context);
      }
    });

    // Cheer from other users
    socket.on('cheer', (data) {
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final name = map['name']?.toString() ?? 'User';
        final image = map['image']?.toString();
        _cheerKey.currentState?.addCheer(name: name, imageUrl: image);
      } catch (_) {}
    });

    // Co-host / multi-guest events
    _cancelCoHostJoinSub = socket.on(Const.eventAddParticipatesCallJoin, (
      data,
    ) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;
        final nestedUser = map['user'];
        final userId =
            (map['userId'] ??
                    map['guestUserId'] ??
                    (nestedUser is Map
                        ? nestedUser['_id'] ?? nestedUser['userId']
                        : null))
                ?.toString();
        if (userId == null || userId.isEmpty) return;
        final isAccepted =
            map['isAccept'] == true ||
            map['isAccept'] == 1 ||
            map['isAccepted'] == true ||
            map['isAccepted'] == 1;
        if (!isAccepted) {
          Log.d(_tag, 'Co-host join ignored (not accepted): userId=$userId');
          return;
        }
        final session = context.read<SessionManager>();
        final parsedAgoraUid = _coHostAgoraUid(map);
        final agoraUid =
            userId == session.userId ? _myAgoraUid : parsedAgoraUid;
        if (userId == widget.liveUser.userId ||
            (agoraUid > 0 && agoraUid == widget.liveUser.agoraUID)) {
          Log.w(
            _tag,
            'Ignoring host/colliding UID in co-host event: userId=$userId uid=$agoraUid',
          );
          return;
        }
        map['agoraUid'] = agoraUid;

        Log.d(
          _tag,
          'Co-host join event: userId=$userId agoraUid=$agoraUid isAccepted=$isAccepted',
        );

        setState(() {
          _coHosts.removeWhere((h) => h['userId'] == userId);
          _coHosts.add(map);
        });

        // Create remote controller for OTHER co-hosts only. The local user
        // already gets their own controller from _startBroadcast.
        if (agoraUid > 0 && userId != session.userId) {
          _createCoHostController(agoraUid);
        }

        // If this is the current user being accepted, switch to broadcaster.
        if (userId == session.userId && !_isJoined) {
          _isJoined = true;
          _startBroadcast();
        }
      } catch (e) {
        Log.e(_tag, 'coHost join parse', e);
      }
    });
    _cancelCoHostLeaveSub = socket.on(Const.eventLessParticipatesCallJoin, (
      data,
    ) {
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final userId = map['userId']?.toString();
        final agoraUid = _coHostAgoraUid(Map<String, dynamic>.from(map));
        final session = context.read<SessionManager>();
        setState(() => _coHosts.removeWhere((h) => h['userId'] == userId));
        // Remove co-host video controller.
        if (agoraUid > 0) {
          _coHostControllers.remove(agoraUid);
        }
        // If this is the current user being removed, switch back to audience.
        if (userId == session.userId && _isJoined) {
          _isJoined = false;
          _stopBroadcast();
        }
      } catch (e) {
        Log.e(_tag, 'coHost leave parse', e);
      }
    });
    _cancelCoHostMuteSub = socket.on(Const.eventMuteCallJoin, (data) {
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final userId = map['userId']?.toString();
        final muted = map['isMute'] == true;
        setState(() {
          for (final h in _coHosts) {
            if (h['userId'] == userId) h['isMute'] = muted;
          }
        });
      } catch (e) {
        Log.e(_tag, 'coHost mute parse', e);
      }
    });
    _cancelCameraOffCallJoinSub = socket.on(Const.eventCameraOffCallJoin, (
      data,
    ) {
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final userId = map['userId']?.toString();
        final cameraOff = parseBool(map['isCameraOff']);
        setState(() {
          // The same event is used for the live host and co-hosts.
          if (!widget.isHost && userId == widget.liveUser.userId) {
            _remoteHostCameraOff = cameraOff;
          }
          for (final h in _coHosts) {
            if (h['userId'] == userId) h['isCameraOff'] = cameraOff;
          }
        });
      } catch (e) {
        Log.e(_tag, 'coHost cameraOff parse', e);
      }
    });
    // Host receives join request list.
    _cancelRequestedCallJoinSub = socket.on(Const.eventRequestedCallJoin, (
      data,
    ) {
      try {
        final list = data is List ? data : (data is Map ? [data] : null);
        if (list == null) return;
        final parsed =
            list
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();

        Log.d(_tag, 'Received join requests: ${parsed.length}');

        if (!mounted) return;

        // Detect brand-new requests so the host is alerted immediately —
        // ports native showPkRequestPopup (accept/decline dialog as soon as
        // a viewer raises a hand).
        final currentIds =
            parsed
                .map((r) => r['userId']?.toString())
                .whereType<String>()
                .toSet();
        _notifiedRequestIds.removeWhere((id) => !currentIds.contains(id));
        final fresh =
            parsed.where((r) {
              final id = r['userId']?.toString();
              return id != null && !_notifiedRequestIds.contains(id);
            }).toList();

        setState(() {
          _joinRequests.clear();
          _joinRequests.addAll(parsed);
        });

        if (widget.isHost && fresh.isNotEmpty) {
          for (final r in fresh) {
            final id = r['userId']?.toString();
            if (id != null) _notifiedRequestIds.add(id);
          }
          final name = fresh.first['name']?.toString() ?? 'Someone';
          Fluttertoast.showToast(msg: '$name wants to join the call');
          _showJoinRequestDialog(fresh.first);
        }
      } catch (e) {
        Log.e(_tag, 'requestedCallJoin parse', e);
      }
    });
    // Viewer receives invite from host (Bigo/Chamet-style call invite popup).
    // Ports native HostPKLiveActivity.onInvite — host emits `eventInvite`,
    // backend forwards to target viewer, viewer sees accept/decline popup.
    // On accept, viewer emits `eventAddParticipatesCallJoin` with isInvited:true.
    _cancelInviteSub = socket.on(Const.eventInvite, (data) {
      try {
        final map =
            data is Map
                ? Map<String, dynamic>.from(data)
                : (data is List && data.isNotEmpty && data.first is Map
                    ? Map<String, dynamic>.from(data.first as Map)
                    : null);
        if (map == null) return;
        final targetUserId = map['userId']?.toString();
        final session = context.read<SessionManager>();
        if (targetUserId == session.userId) {
          final hostName = map['hostName']?.toString() ?? 'Host';
          _showCallInviteDialog(hostName, map);
        }
      } catch (e) {
        Log.e(_tag, 'eventInvite parse', e);
      }
    });
    // Admin list updates.
    _cancelAdminListSub = socket.on(Const.eventRoomAdminList, (data) {
      try {
        final list = _unwrapAdminList(data);
        if (list == null) return;
        setState(() {
          _admins
            ..clear()
            ..addAll(
              list
                  .whereType<Map>()
                  .map((e) => AdminEntry.fromJson(Map<String, dynamic>.from(e)))
                  .toList(),
            );
        });
      } catch (e) {
        Log.e(_tag, 'adminList parse', e);
      }
    });

    for (final event in [
      Const.eventRoomPollStarted,
      Const.eventRoomPollUpdated,
      Const.eventRoomPollRestore,
    ]) {
      _roomRuntimeSocketCancellations.add(
        socket.on(event, _applyRoomPollEvent),
      );
    }
    _roomRuntimeSocketCancellations.add(
      socket.on(Const.eventRoomPollEnded, _applyRoomPollEnded),
    );
    _roomRuntimeSocketCancellations.add(
      socket.on(Const.eventRoomAnalyticsUpdated, (data) {
        final map = _unwrapCommentPayload(data);
        if (map.isEmpty || !_runtimeEventMatchesRoom(map) || !mounted) return;
        setState(() {
          _liveRoomAnalytics = LiveRoomAnalytics.fromJson(map);
          if (_liveRoomAnalytics!.viewerCount > 0) {
            _viewerCount = _liveRoomAnalytics!.viewerCount;
          }
        });
      }),
    );
    _roomRuntimeSocketCancellations.add(
      socket.on(Const.eventMusicPermissionUpdated, (data) {
        final map = _unwrapCommentPayload(data);
        if (map.isEmpty || !_runtimeEventMatchesRoom(map)) return;
        final permission = map['musicPermission']?.toString().toLowerCase();
        if (permission == null ||
            !const {'host', 'admins', 'friends'}.contains(permission)) {
          return;
        }
        if (mounted) setState(() => _musicPermission = permission);
      }),
    );
    _roomRuntimeSocketCancellations.add(
      socket.on(Const.eventFriendMusicRequest, _handleFriendMusicRequest),
    );
    _roomRuntimeSocketCancellations.add(
      socket.on(
        Const.eventFriendMusicRequestUpdated,
        _handleFriendMusicRequestUpdated,
      ),
    );
    socket.emit(Const.eventRoomPollRestore, {
      'liveStreamingId': liveId,
      'userId': context.read<SessionManager>().userId,
    });
    if (widget.isHost) {
      socket.emit(Const.eventRoomAnalyticsRequest, {
        'liveStreamingId': liveId,
        'userId': context.read<SessionManager>().userId,
      });
    }

    _cancelPkRequestSub = socket.on(Const.eventPkRequest, (data) {
      try {
        final map = _unwrapCommentPayload(data);
        if (map.isEmpty || !mounted || !widget.isHost) return;
        final myId =
            widget.liveUser.userId ?? context.read<SessionManager>().userId;
        final targetId =
            (map['host2Id'] ?? map['targetHostId'] ?? map['toUserId'])
                ?.toString() ??
            '';
        final targetRoomId =
            (map['host2LiveId'] ?? map['targetRoomId'] ?? map['toRoomId'])
                ?.toString();
        if (targetId.isNotEmpty && targetId != myId) return;
        if (targetRoomId?.isNotEmpty == true &&
            targetRoomId != widget.liveUser.liveRoomId) {
          return;
        }
        if (_pkRequestDialogOpen) return;
        _pkRequestDialogOpen = true;
        _pendingPkRequest = Map<String, dynamic>.from(map);
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: Text(
                  'PK Request from ${map['host1Name'] ?? map['fromName'] ?? 'Host'}',
                ),
                content: const Text('Do you accept the PK battle?'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _pkRequestDialogOpen = false;
                      _answerVideoPkRequest(map, accepted: false);
                    },
                    child: const Text('Decline'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _pkRequestDialogOpen = false;
                      _answerVideoPkRequest(map, accepted: true);
                    },
                    child: const Text('Accept'),
                  ),
                ],
              ),
        ).then((_) => _pkRequestDialogOpen = false);
      } catch (e, s) {
        Log.e(_tag, 'PK request parse failed', e, s);
      }
    });
    _cancelPkRequestAnswerSub = socket.on(Const.eventPkRequestAnswer, (data) {
      final map = _unwrapCommentPayload(data);
      if (map.isEmpty || !mounted) return;
      // DEBUG: log the raw PK answer payload to see all token fields from backend.
      Log.d(_tag, 'PK answer raw payload keys: ${map.keys.toList()}');
      if (map['pkConfig'] is Map) {
        final pkCfg = Map<String, dynamic>.from(map['pkConfig'] as Map);
        Log.d(_tag, 'PK answer pkConfig keys: ${pkCfg.keys.toList()}');
        Log.d(_tag, 'PK answer pkConfig tokens: host1Token=${pkCfg['host1Token']} host2Token=${pkCfg['host2Token']} fromToken=${pkCfg['fromToken']} targetToken=${pkCfg['targetToken']} host1SrcToken=${pkCfg['host1SrcToken']} host2SrcToken=${pkCfg['host2SrcToken']}');
      }
      final myId =
          widget.liveUser.userId ?? context.read<SessionManager>().userId;
      final answerConfig =
          map['pkConfig'] is Map
              ? Map<String, dynamic>.from(map['pkConfig'] as Map)
              : <String, dynamic>{};
      final host1Id =
          (map['host1Id'] ??
                  answerConfig['host1Id'] ??
                  map['requesterId'] ??
                  map['fromUserId'])
              ?.toString();
      final host2Id =
          (map['host2Id'] ??
                  answerConfig['host2Id'] ??
                  map['targetHostId'] ??
                  map['toUserId'])
              ?.toString();
      if (myId != host1Id && myId != host2Id) return;
      final accepted = parseBool(
        map['isAccept'] ?? map['ISACCEPT'] ?? map['accepted'],
      );
      final type = parseInt(map['type'], -1);
      if (!accepted) {
        Fluttertoast.showToast(msg: 'PK request declined');
        _pendingPkRequest = null;
        return;
      }
      // Match native startMediaRelay2 guard:
      // - type 0 (host path): ignore if this is a duplicate for the same PK round
      // - type 1 (accepter host): ignore if this is a duplicate for the same PK round
      // - type 2+ (periodic sync): only update scores, never restart relay
      if (type == 0 || type == 1) {
        final incomingPkId =
            map['pkId']?.toString() ??
            answerConfig['pkId']?.toString() ??
            map['_id']?.toString() ??
            '';
        final incomingRound = parseInt(
          map['pkRoundCount'] ??
              answerConfig['pkRoundCount'] ??
              map['PK_ROUND_COUNT'],
          -1,
        );
        final isSameRound =
            _pkConfig != null &&
            incomingPkId.isNotEmpty &&
            incomingPkId == _pkConfig?.pkId &&
            (incomingRound < 0 || incomingRound == _pkRoundCount);
        if (_isPkActive && _pkConfig != null && isSameRound) {
          Log.d(_tag, 'PK answer type=$type ignored — same PK round');
          // Still sync scores from the periodic payload.
          final scores = _resolveIncomingPkScores(map);
          setState(() {
            _pkScoreHost1 = scores.host1;
            _pkScoreHost2 = scores.host2;
          });
          return;
        }
        Fluttertoast.showToast(msg: 'PK request accepted');
        unawaited(_openAcceptedVideoPk(map, startTimer: false));
      } else {
        // type 2+ (periodic sync): only update scores, never restart relay.
        final scores = _resolveIncomingPkScores(map);
        setState(() {
          _pkScoreHost1 = scores.host1;
          _pkScoreHost2 = scores.host2;
        });
        Log.d(_tag, 'PK answer type=$type periodic sync scores h1=${scores.host1} h2=${scores.host2}');
      }
    });

    // PK vote count updates.
    _cancelPkVoteSub = socket.on(Const.eventPkVote, (data) {
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final hostSide = parseString(map['hostSide']);
        setState(() {
          _isPkActive = true;
          if (hostSide == 'host1') {
            _pkVoteCountHost1++;
          } else if (hostSide == 'host2') {
            _pkVoteCountHost2++;
          }
        });
      } catch (_) {}
    });

    // PK score updates — real-time score bar.
    _cancelPkScoreSub = socket.on(Const.eventPkScoreUpdate, (data) {
      try {
        Log.d(_tag, 'PK score update raw=$data');
        final map = _unwrapCommentPayload(data);
        if (map.isEmpty || !mounted) return;
        final scores = _resolveIncomingPkScores(map);
        setState(() {
          _isPkActive = true;
          _pkScoreHost1 = scores.host1;
          _pkScoreHost2 = scores.host2;
        });
        Log.d(
          _tag,
          'PK scores synced host1=${scores.host1} host2=${scores.host2}',
        );
      } catch (e, s) {
        Log.e(_tag, 'PK score update failed', e, s);
      }
    });

    // PK start — activate PK mode.
    _cancelPkStartSub = socket.on(Const.eventPkStart, (data) {
      final map = _unwrapCommentPayload(data);
      setState(() {
        _isPkActive = true;
        _pkVoteCountHost1 = 0;
        _pkVoteCountHost2 = 0;
        _isPkPunishment = false;
        _pkPunishmentTask = null;
        _pkWinner = -1;
      });
      _pkSupporters.clear();
      _pkSupporterAnnounced.clear();
      // Activate gifting multiplier during PK battle.
      _multiplier.onPkStart();
      if (map.isNotEmpty) {
        unawaited(
          _openAcceptedVideoPk(
            map,
            restartRelay: _pkConfig == null,
          ).whenComplete(() {
            if (mounted && _isPkActive && _pkConfig != null) _startPkTimer();
          }),
        );
      } else if (_pkConfig != null) {
        setState(() {
          _pkSecondsLeft =
              _pkConfig!.durationSeconds > 0 ? _pkConfig!.durationSeconds : 300;
        });
        _startPkTimer();
      }
    });

    // PK end — show result briefly, then deactivate PK mode.
    _cancelPkEndSub = socket.on(Const.eventPkEnd, (data) {
      final map = _unwrapCommentPayload(data);
      final reason = parseString(map['reason'] ?? map['endReason']);
      final isManual =
          reason == 'host_ended' ||
          reason == 'manual' ||
          reason == 'closed' ||
          reason == 'left';
      final isDisconnect =
          parseBool(map['isDisconnect'] ?? map['disconnect']) ||
          reason == 'disconnect';

      // Manual close or disconnect — reset immediately.
      if (isManual || isDisconnect) {
        _resetPkState();
        return;
      }

      // Determine final winner from server payload or current scores.
      final serverWinner = parseInt(map['winner'], -1);
      final finalScores = _resolveIncomingPkScores(map);
      var winner =
          serverWinner >= 0
              ? serverWinner
              : pkWinnerFromScores(
                  host1Score: finalScores.host1,
                  host2Score: finalScores.host2,
                );

      _recordPkRound(
        _pkRoundCount + 1,
        finalScores.host1,
        finalScores.host2,
        winner,
      );

      if (!mounted) return;
      setState(() {
        _pkScoreHost1 = finalScores.host1;
        _pkScoreHost2 = finalScores.host2;
        _pkWinner = winner;
        _pkSecondsLeft = 0;
      });

      // Show the result overlay for 5 seconds, then reset.
      _pkResultResetTimer?.cancel();
      _pkResultResetTimer = Timer(const Duration(seconds: 5), () {
        if (!mounted) return;
        _resetPkState();
      });
    });

    // PK punishment round — show punishment task.
    _cancelPkPunishmentSub = socket.on(Const.eventPkPunishmentRound, (data) {
      try {
        final map = _unwrapCommentPayload(data);
        if (map.isEmpty || !mounted) return;
        _handlePkPunishmentRound(map);
      } catch (e, s) {
        Log.e(_tag, 'PK punishment update failed', e, s);
      }
    });

    // Host earning update — real-time diamonds received by host.
    // We still show no gift notification toast; only update the earnings counter.
    _cancelHostEarningSub = socket.on(Const.eventHostEarningUpdate, (data) {
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final totalCoins = (map['totalCoins'] as num?)?.toInt() ?? 0;
        _giftStatsController.setHostEarnings(totalCoins);
      } catch (_) {}
    });

    // Top gifters update — real-time top gifters in room.
    _cancelTopGiftersSub = socket.on(Const.eventTopGiftersUpdate, (data) {
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final giftersList = map['topGifters'];
        if (giftersList is List) {
          final entries =
              giftersList
                  .whereType<Map>()
                  .map((e) {
                    final m = Map<String, dynamic>.from(e);
                    final userId =
                        m['userId']?.toString() ?? m['_id']?.toString() ?? '';
                    if (userId.isEmpty) return null;
                    return GifterEntry(
                      userId: userId,
                      name:
                          m['name']?.toString() ??
                          m['userName']?.toString() ??
                          'User',
                      image:
                          m['image']?.toString() ??
                          m['userImage']?.toString() ??
                          '',
                      totalCoins:
                          (m['totalCoins'] as num?)?.toInt() ??
                          (m['coin'] as num?)?.toInt() ??
                          0,
                    );
                  })
                  .whereType<GifterEntry>()
                  .toList();
          _giftStatsController.setTopGifters(entries);
        }
      } catch (_) {}
    });

    // Viewer kicked — host/admin kicked this viewer from the room.
    _cancelViewerKickedSub = socket.on(Const.eventViewerKicked, (data) {
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final kickedUserId =
            map['userId']?.toString() ?? map['viewerId']?.toString() ?? '';
        final myUserId = context.read<SessionManager>().userId;
        if (kickedUserId == myUserId) {
          Fluttertoast.showToast(msg: 'You have been removed from the room');
          _leaveRoom();
        }
      } catch (_) {}
    });

    // Viewer muted — host/admin muted this viewer's mic/cam.
    _cancelViewerMutedSub = socket.on(Const.eventViewerMuted, (data) {
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final mutedUserId =
            map['userId']?.toString() ?? map['viewerId']?.toString() ?? '';
        final isMuted = map['mute'] == true || map['isMuted'] == true;
        final myUserId = context.read<SessionManager>().userId;
        if (mutedUserId == myUserId) {
          Fluttertoast.showToast(
            msg:
                isMuted
                    ? 'You have been muted by host'
                    : 'You have been unmuted by host',
          );
        }
      } catch (_) {}
    });

    // Game result — broadcast to room when a game completes.
    _cancelGameResultSub = socket.on(Const.eventGameResult, (data) {
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final winnerName = map['winnerName']?.toString() ?? 'Host';
        final prize = (map['prize'] as num?)?.toInt() ?? 0;
        final gameName = map['gameName']?.toString() ?? 'Game';
        setState(
          () => _comments.add(
            _LiveComment(
              name: 'System',
              text: '$winnerName won $prize diamonds in $gameName!',
              isGift: false,
            ),
          ),
        );
        _scrollToBottom();
        if (gameName.toLowerCase().contains('fighter') ||
            map['gameType']?.toString().toLowerCase() == 'fighter') {
          // Fighter launch broadcast.
          _broadcastOverlayKey.currentState?.enqueue(
            BroadcastEvent(
              type: BroadcastType.fighterBroadcast,
              title:
                  'Room ID:${widget.liveUser.liveRoomId} the fighter is about to launch',
              subtitle: '$winnerName is ready',
              avatar: map['winnerImage']?.toString(),
              rightText: 'GO',
              durationSeconds: 5,
            ),
          );
        }
        // Game broadcast banner.
        _broadcastOverlayKey.currentState?.enqueue(
          BroadcastEvent(
            type: BroadcastType.gameBroadcast,
            title:
                '$winnerName won ${_formatCoins(prize)} diamonds at $gameName',
            avatar: map['winnerImage']?.toString(),
            rightText: 'Play',
            durationSeconds: 5,
          ),
        );
      } catch (_) {}
    });

    // Theme change
    socket.on(Const.eventChangeTheme, (data) {
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final bg = map['background']?.toString();
        if (bg != null && bg.isNotEmpty && mounted) {
          setState(() => _backgroundImage = bg);
        }
      } catch (_) {}
    });

    // Reaction overlay (ports native onReactionReceived).
    _cancelReactionSub = socket.on(Const.eventSendReaction, (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;
        final room = map['liveStreamingId']?.toString();
        if (room != null && room.isNotEmpty && room != liveId) return;
        final rawImage = map['image']?.toString() ?? '';
        final reactionImage = VideoUtil.getFullImageUrl(rawImage);
        final reactionName = map['name']?.toString() ?? '';
        final position = (map['position'] as num?)?.toInt() ?? -1;
        final senderUser =
            map['user'] is Map
                ? Map<String, dynamic>.from(map['user'] as Map)
                : null;
        final name =
            senderUser?['name']?.toString() ??
            map['userId']?.toString() ??
            'User';
        final reactUserId =
            map['userId']?.toString() ??
            senderUser?['_id']?.toString() ??
            senderUser?['id']?.toString() ??
            '';

        // Show reaction image/emoji centered over the host video for 7s.
        if (reactionImage.isNotEmpty || reactionName.isNotEmpty) {
          if (mounted) {
            setState(() {
              _reactionImage = reactionImage.isNotEmpty ? reactionImage : null;
              _reactionName = reactionName.isNotEmpty ? reactionName : null;
            });
            _reactionTimer?.cancel();
            _reactionTimer = Timer(const Duration(seconds: 7), () {
              if (mounted) {
                setState(() {
                  _reactionImage = null;
                  _reactionName = null;
                });
              }
            });
          }
        }

        // For position -1 (or legacy payloads) also add a chat comment.
        if (position == -1) {
          if (mounted) {
            setState(
              () => _comments.add(
                _LiveComment(
                  name: name,
                  text:
                      reactionImage.isEmpty && reactionName.isNotEmpty
                          ? reactionName
                          : 'reacted',
                  userId: reactUserId,
                  isGift: reactionImage.isNotEmpty,
                  giftImage: reactionImage.isNotEmpty ? reactionImage : null,
                  userImage: VideoUtil.getFullImageUrl(
                    senderUser?['image']?.toString() ??
                        map['userImage']?.toString(),
                  ),
                ),
              ),
            );
            _scrollToBottom();
          }
        }
      } catch (_) {}
    });

    // Banned user list (host blocks user)
    socket.on(Const.eventUpdateBlockedlist, (data) {
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final blockedList = map['blocked'] as List? ?? [];
        final session = context.read<SessionManager>();
        final isBlocked = blockedList.any(
          (e) => e?.toString() == session.userId,
        );
        if (isBlocked && mounted) {
          Fluttertoast.showToast(msg: 'You are banned by host');
          Navigator.pop(context);
        }
      } catch (_) {}
    });

    // Live rejoin - update viewer count (backend total includes the host).
    socket.on(Const.eventLiveRejoin, (data) {
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final view = parseInt(map['view']);
        if (view > 0 && mounted)
          setState(() => _viewerCount = max(0, view - 1));
      } catch (_) {}
    });

    // Music events (host controls background music; viewers mirror state).
    // Host actions are emitted by RoomMusicController hooks, so the host
    // ignores these echoes — only viewers mirror.
    socket.on(Const.eventMusicPlay, (data) {
      if (widget.isHost) return;
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final trackJson = map['track'] is Map ? map['track'] as Map : null;
        final pos =
            map['positionMs'] is int
                ? map['positionMs'] as int
                : (map['positionMs'] != null
                    ? int.tryParse(map['positionMs'].toString()) ?? 0
                    : 0);
        if (trackJson != null) {
          final track = RoomMusicTrack.fromSocketJson(
            Map<String, dynamic>.from(trackJson),
          );
          _musicController?.mirrorPlay(track, pos);
          if (mounted) {
            setState(() {
              _currentMusicName = track.title;
              _isMusicPlaying = true;
            });
          }
        } else {
          final songName =
              map['title']?.toString() ?? map['name']?.toString() ?? '';
          final songUrl = map['song']?.toString() ?? map['url']?.toString();
          if (songUrl != null && songUrl.isNotEmpty) {
            _musicController?.mirrorPlay(
              RoomMusicTrack(
                id: 'legacy_$songUrl',
                title: songName,
                source: songUrl,
                isLocal: false,
              ),
              0,
            );
            if (mounted) {
              setState(() {
                _currentMusicName = songName;
                _isMusicPlaying = true;
              });
            }
          }
        }
      } catch (_) {}
    });

    socket.on(Const.eventMusicStop, (_) {
      if (widget.isHost) return;
      if (mounted) {
        _musicController?.mirrorStop();
        setState(() {
          _isMusicPlaying = false;
          _currentMusicName = null;
        });
      }
    });

    socket.on(Const.eventMusicPause, (_) {
      if (widget.isHost || !mounted) return;
      _musicController?.mirrorPause();
      setState(() => _isMusicPlaying = false);
    });

    socket.on(Const.eventMusicResume, (_) {
      if (widget.isHost || !mounted) return;
      _musicController?.mirrorResume();
      setState(() => _isMusicPlaying = true);
    });

    socket.on(Const.eventMusicSeek, (data) {
      if (widget.isHost || !mounted) return;
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final pos =
            map['positionMs'] is int
                ? map['positionMs'] as int
                : int.tryParse(map['positionMs']?.toString() ?? '') ?? 0;
        _musicController?.mirrorSeek(pos);
      } catch (_) {}
    });

    socket.on(Const.eventMusicVolume, (data) {
      if (widget.isHost || !mounted) return;
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final vol =
            map['volume'] is int
                ? map['volume'] as int
                : int.tryParse(map['volume']?.toString() ?? '') ?? 80;
        _musicController?.mirrorVolume(vol);
      } catch (_) {}
    });

    // Live end by admin.
    socket.on(Const.eventLiveEndByAdmin, (_) {
      if (mounted) {
        Fluttertoast.showToast(msg: 'Live ended by admin');
        Navigator.pop(context);
      }
    });

    // Host calling event (host initiates a call from live).
    socket.on(Const.eventHostCalling, (data) {
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final targetUserId = map['userId']?.toString();
        final session = context.read<SessionManager>();
        if (targetUserId == session.userId && mounted) {
          Log.d(_tag, 'Received host calling event');
          // Automatically accept if needed or show dialog?
          // User said "Cal py khud chally jana", maybe they want a dialog.
          // For now, ensure it doesn't auto-join unless accepted.
        }
      } catch (_) {}
    });

    // Host call ended.
    socket.on(Const.eventHostCallEnded, (_) {
      if (mounted) {
        Fluttertoast.showToast(msg: 'Host call ended');
      }
    });

    // VIP expiry warning.
    socket.on(Const.eventVipExpiryWarning, (data) {
      try {
        final map = data is Map ? data : null;
        if (map == null) return;
        final message =
            map['message']?.toString() ?? 'Your VIP is expiring soon';
        if (mounted) {
          Fluttertoast.showToast(msg: message);
        }
      } catch (_) {}
    });

    // VIP downgraded.
    socket.on(Const.eventVipDowngraded, (_) {
      if (mounted) {
        Fluttertoast.showToast(msg: 'Your VIP has expired');
        context.read<AuthProvider>().refreshUser();
      }
    });

    // Track new fans during the stream (host only).
    _cancelFollowSub = socket.on('follow', (data) {
      try {
        if (!widget.isHost) return;
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;
        final session = context.read<SessionManager>();
        final myUserId = session.userId;
        final followedId =
            map['followingUserId']?.toString() ??
            map['toUserId']?.toString() ??
            map['userId']?.toString() ??
            '';
        if (followedId.isNotEmpty && followedId == myUserId) {
          _clientFanCount++;
        }
      } catch (_) {}
    });

    // Co-Watch sync events.
    socket.on(Const.eventCoWatchPlay, (data) {
      if (widget.isHost) return;
      _applyCoWatchData(data, (m, url, title, pos) {
        _coWatchController?.applyPlay(url, title, pos);
      });
    });
    socket.on(Const.eventCoWatchPause, (data) {
      if (widget.isHost) return;
      _coWatchController?.applyPause();
    });
    socket.on(Const.eventCoWatchResume, (data) {
      if (widget.isHost) return;
      _coWatchController?.applyResume();
    });
    socket.on(Const.eventCoWatchSeek, (data) {
      if (widget.isHost) return;
      _applyCoWatchData(data, (m, url, title, pos) {
        _coWatchController?.applySeek(pos);
      });
    });
    socket.on(Const.eventCoWatchStop, (data) {
      if (widget.isHost) return;
      _coWatchController?.applyStop();
    });

    // Voice Emoji events.
    socket.on(Const.eventVoiceEmoji, (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;
        final room = map['liveStreamingId']?.toString() ?? '';
        if (room.isNotEmpty && room != liveId) return;
        _voiceEmojiKey.currentState?.showFromSocket(map);
      } catch (_) {}
    });

    // Draw and Guess events are handled by [DrawAndGuessController] itself.
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Derive a safe static image URL (PNG/JPG) from raw gift image/SVGA/video
  /// URLs for use in chat comment bubbles. `VideoUtil.getFullImageUrl()`
  /// returns '' for .svga paths, which made gift comments show no gift image
  /// at all. This method tries:
  ///   1. A non-SVGA, non-video candidate as-is.
  ///   2. A .png sibling derived from the .svga/.mp4/.mov/.webm URL.
  ///   3. A _thumb.jpg for video assets.
  ///   4. The RAW animation URL as a last resort — the comment bubble's
  ///      _giftAsset can handle SVGA URLs (shows first frame).
  /// Returns '' if no URL can be derived at all.
  String _safeGiftCommentImage(String? rawGiftImage, String? rawSvgaImage) {
    final candidates = [rawGiftImage, rawSvgaImage];
    // 1. Use a candidate that is already a static image.
    for (final c in candidates) {
      if (c == null || c.isEmpty) continue;
      final lower = c.toLowerCase().split('?').first;
      if (!lower.contains('.svga') &&
          !lower.contains('/svga') &&
          !lower.endsWith('.mp4') &&
          !lower.endsWith('.mov') &&
          !lower.endsWith('.webm')) {
        final full = VideoUtil.getFullImageUrl(c);
        if (full.isNotEmpty) return full;
      }
    }
    // 2. Derive a .png sibling from the animation/video URL.
    for (final c in candidates) {
      if (c == null || c.isEmpty) continue;
      final lower = c.toLowerCase().split('?').first;
      if (lower.contains('.svga') ||
          lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.webm')) {
        final png = c.replaceAll(
          RegExp(r'\.(svga|mp4|mov|webm)$', caseSensitive: false),
          '.png',
        );
        if (png != c) {
          final full = VideoUtil.getFullImageUrl(png);
          if (full.isNotEmpty) return full;
        }
      }
    }
    // 3. Derive a _thumb.jpg for video assets.
    for (final c in candidates) {
      if (c == null || c.isEmpty) continue;
      final lower = c.toLowerCase().split('?').first;
      if (lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.webm')) {
        final thumb = VideoUtil.getThumbnailUrl(c);
        if (thumb.isNotEmpty && thumb != c) {
          final full = VideoUtil.getFullImageUrl(thumb);
          if (full.isNotEmpty) return full;
        }
      }
    }
    // 4. Last resort: return the RAW animation URL. The comment bubble's
    // _giftAsset method can handle SVGA URLs (shows first frame via
    // SvgaPlayer with allowAnimation=false). This is better than showing
    // a generic gift icon.
    for (final c in candidates) {
      if (c != null && c.isNotEmpty) return c;
    }
    return '';
  }

  Map<String, dynamic> _buildCommentPayload({
    required String comment,
    required String userId,
    String? imageUrl,
    String? type,
    String? name,
    String? image,
    String? country,
    bool? isVIP,
    Map<String, dynamic>? vipDetails,
  }) {
    final user = context.read<AuthProvider>().user;
    final session = context.read<SessionManager>();
    final effectiveUser = user ?? session.getUser();
    final vip = vipDetails ?? effectiveUser?.vipDetails?.toJson();
    final effectiveName = name ?? effectiveUser?.name ?? session.userName;
    final effectiveImage = image ?? effectiveUser?.image ?? session.userImage;
    final effectiveCountry = country ?? effectiveUser?.country ?? '';
    final effectiveIsVip = isVIP ?? effectiveUser?.isVIP ?? false;
    final directVipBadgeUrl = effectiveUser?.vipBadgeUrl?.trim() ?? '';
    final vipBadgeUrl =
        directVipBadgeUrl.isNotEmpty
            ? directVipBadgeUrl
            : effectiveUser?.vipDetails?.levelBadgeUrl;
    return {
      'comment': comment,
      'liveStreamingId': widget.liveUser.liveRoomId,
      'liveUserId': widget.liveUser.userId,
      'liveUserMongoId': widget.liveUser.id,
      'userId': userId,
      'name': effectiveName,
      'image': effectiveImage,
      'country': effectiveCountry,
      'isVIP': effectiveIsVip,
      'isVip': effectiveIsVip,
      'isAdmin': _iAmAdmin,
      'isHost': widget.isHost,
      'vipLevel': effectiveUser?.vipStatus?.currentLevel ?? 0,
      if (effectiveUser?.level != null) 'level': effectiveUser!.level!.toJson(),
      if (effectiveUser?.hostLevel != null)
        'hostLevel': effectiveUser!.hostLevel!.toJson(),
      'tags':
          effectiveUser?.tags.map((tag) => tag.toJson()).toList() ?? const [],
      'vipBadgeUrl': vipBadgeUrl,
      'familyName': effectiveUser?.familyName ?? effectiveUser?.family,
      'familyBadgeUrl': effectiveUser?.familyBadgeUrl,
      'isAgency': effectiveUser?.isAgency ?? false,
      'isBd': effectiveUser?.isBd ?? false,
      if (vip != null) 'vipDetails': vip,
      'user': {
        'id': effectiveUser?.id,
        'userId': userId,
        'name': effectiveName,
        'image': effectiveImage,
        'country': effectiveCountry,
        'isVIP': effectiveIsVip,
        'isVip': effectiveIsVip,
        'avatarFrameImage':
            effectiveUser?.avatarFrameImage ??
            effectiveUser?.vipDetails?.profileFrameUrl,
        'vipLevel': effectiveUser?.vipStatus?.currentLevel ?? 0,
        if (effectiveUser?.level != null)
          'level': effectiveUser!.level!.toJson(),
        if (effectiveUser?.hostLevel != null)
          'hostLevel': effectiveUser!.hostLevel!.toJson(),
        'tags':
            effectiveUser?.tags.map((tag) => tag.toJson()).toList() ?? const [],
        'vipBadgeUrl': vipBadgeUrl,
        'familyName': effectiveUser?.familyName ?? effectiveUser?.family,
        'familyBadgeUrl': effectiveUser?.familyBadgeUrl,
        'isHost': widget.isHost,
        'isAdmin': _iAmAdmin,
        'isAgency': effectiveUser?.isAgency ?? false,
        'isBd': effectiveUser?.isBd ?? false,
        if (vip != null) 'vipDetails': vip,
      },
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      if (type != null && type.isNotEmpty) 'type': type,
      'isPkRunning': false,
    };
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final containsExternalLink = RegExp(
      r'(https?://|www\.|(?:^|\s)[a-z0-9-]+\.(?:com|net|org|app|io|me|co|in|pk)(?:/|\s|$))',
      caseSensitive: false,
    ).hasMatch(text);
    if (containsExternalLink) {
      Fluttertoast.showToast(
        msg: 'External links are not allowed in room comments',
      );
      return;
    }

    if (text.length > 200) {
      Fluttertoast.showToast(msg: 'Comment too long');
      return;
    }

    _commentCtrl.clear();
    final session = context.read<SessionManager>();
    final user = context.read<AuthProvider>().user;
    final userImage = VideoUtil.getFullImageUrl(
      user?.image ?? session.getUser()?.image ?? '',
    );

    // Add locally for immediate feedback
    final localComment = _LiveComment(
      name: user?.name ?? 'Me',
      text: text,
      userId: session.userId,
      isMine: true,
      isVIP: user?.isVIP ?? false,
      userImage: userImage,
      frameUrl: user?.avatarFrameImage ?? user?.vipDetails?.profileFrameUrl,
      country: user?.country,
      familyName: user?.familyName ?? user?.family,
      familyBadgeUrl: VideoUtil.getFullImageUrl(user?.familyBadgeUrl ?? ''),
      vipLevel: user?.vipStatus?.currentLevel,
      levelName: user?.level?.name,
      isAdmin: _iAmAdmin,
      isHost: widget.isHost,
      isAgency: user?.isAgency ?? false,
      isBd: user?.isBd ?? false,
      badgeUrls:
          [
            user?.vipBadgeUrl?.isNotEmpty == true
                ? user!.vipBadgeUrl
                : user?.vipDetails?.levelBadgeUrl,
            user?.level?.image,
            user?.hostLevel?.image,
            ...?user?.tags.map((tag) => tag.image),
          ].whereType<String>().where((url) => url.isNotEmpty).toList(),
      tagLabels:
          user?.tags
              .map((tag) => tag.name)
              .whereType<String>()
              .where((label) => label.isNotEmpty)
              .toList() ??
          const [],
      vipStyle: VipChatStyle(
        isVip: user?.isVIP ?? false,
        nameColorHex: VipPrivilegeHelper.selfNameColor(session),
        chatBubbleUrl: VipPrivilegeHelper.selfChatBubbleUrl(session),
        chatBubbleId:
            user?.vipStatus?.currentLevel ?? (user?.isVIP == true ? 1 : 0),
        isGoldenName: VipPrivilegeHelper.hasGoldenName(session),
        isColoredChat: VipPrivilegeHelper.hasColoredChat(session),
        isNameAnimation: VipPrivilegeHelper.hasNameAnimation(session),
      ),
    );
    setState(() => _comments.add(localComment));
    if (_isTranslationEnabled) _translateComment(localComment);
    _clientCommentCount++;
    _scrollToBottom();
    SocketService.instance.emit(
      Const.eventComment,
      _buildCommentPayload(comment: text, userId: session.userId),
    );
  }

  Future<void> _sendPhoto() async {
    final session = context.read<SessionManager>();
    final user = context.read<AuthProvider>().user;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;
    final file = File(picked.path);
    Fluttertoast.showToast(msg: 'Sending photo...');
    try {
      // Upload via chat upload endpoint (same as native), then delete the chat
      // entry so it doesn't clutter the inbox â€” only the live comment matters.
      final upload = await ApiService.uploadChatImage(
        file: file,
        userId: session.userId,
        topic: session.userId,
        messageType: 'image',
      );
      final chatMap = upload.chat;
      final imageUrl = chatMap?['image']?.toString() ?? '';
      final chatId =
          chatMap?['_id']?.toString() ?? chatMap?['id']?.toString() ?? '';
      if (!upload.status || imageUrl.isEmpty) {
        Fluttertoast.showToast(msg: upload.message ?? 'Failed to send photo');
        return;
      }
      // Delete the chat entry (native does this to avoid inbox clutter).
      if (chatId.isNotEmpty) {
        try {
          await ApiService.deleteChat(chatId);
        } catch (e) {
          Log.e(_tag, 'deleteChat after photo upload failed', e);
        }
      }
      final fullUrl = VideoUtil.getFullImageUrl(imageUrl);
      setState(
        () => _comments.add(
          _LiveComment(
            name: user?.name ?? 'Me',
            text: '',
            userId: session.userId,
            isMine: true,
            isVIP: user?.isVIP ?? false,
            imageUrl: fullUrl,
            familyName: user?.familyName ?? user?.family,
            familyBadgeUrl: VideoUtil.getFullImageUrl(
              user?.familyBadgeUrl ?? '',
            ),
            vipStyle: VipChatStyle(
              isVip: user?.isVIP ?? false,
              nameColorHex: VipPrivilegeHelper.selfNameColor(session),
              chatBubbleUrl: VipPrivilegeHelper.selfChatBubbleUrl(session),
              chatBubbleId:
                  user?.vipStatus?.currentLevel ??
                  (user?.isVIP == true ? 1 : 0),
              isGoldenName: VipPrivilegeHelper.hasGoldenName(session),
              isColoredChat: VipPrivilegeHelper.hasColoredChat(session),
              isNameAnimation: VipPrivilegeHelper.hasNameAnimation(session),
            ),
          ),
        ),
      );
      _clientCommentCount++;
      _scrollToBottom();
      SocketService.instance.emit(
        Const.eventComment,
        _buildCommentPayload(
          comment: '',
          userId: session.userId,
          imageUrl: imageUrl,
          type: 'image',
        ),
      );
    } catch (e, s) {
      Log.e(_tag, 'sendPhoto failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to send photo');
    }
  }

  Future<void> _toggleMic() async {
    final newState = !_micEnabled;
    await _engine.muteLocalAudioStream(!newState);
    setState(() => _micEnabled = newState);
  }

  Future<void> _toggleCamera() async {
    final newState = !_cameraEnabled;
    await _engine.muteLocalVideoStream(!newState);
    if (!mounted) return;
    setState(() => _cameraEnabled = newState);
    // Tell every audience member to replace the host video with the host DP.
    if (widget.isHost) {
      final session = context.read<SessionManager>();
      SocketService.instance.emit(Const.eventCameraOffCallJoin, {
        'liveStreamingId': widget.liveUser.liveRoomId,
        'userId': session.userId,
        'isCameraOff': !newState,
      });
    }
  }

  Future<void> _switchCamera() async {
    final useFrontCamera = !_frontCamera;
    await _engine.switchCamera();
    await _engine.setLocalRenderMode(
      renderMode: RenderModeType.renderModeHidden,
      mirrorMode:
          useFrontCamera
              ? VideoMirrorModeType.videoMirrorModeEnabled
              : VideoMirrorModeType.videoMirrorModeDisabled,
    );
    if (mounted) setState(() => _frontCamera = useFrontCamera);
  }

  // ---- Multi-guest / co-host helpers ----

  int _coHostAgoraUid(Map<String, dynamic> coHost) {
    final nested = coHost['user'];
    final raw =
        coHost['agoraUid'] ??
        coHost['agoraUID'] ??
        coHost['agoraId'] ??
        coHost['uid'] ??
        (nested is Map
            ? nested['agoraUid'] ?? nested['agoraUID'] ?? nested['agoraId']
            : null);
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  void _bindRemoteUidToPendingCoHost(int agoraUid) {
    if (_coHosts.any((coHost) => _coHostAgoraUid(coHost) == agoraUid)) return;
    final pendingIndex = _coHosts.indexWhere(
      (coHost) =>
          _coHostAgoraUid(coHost) == 0 &&
          coHost['userId']?.toString() != widget.liveUser.userId,
    );
    if (pendingIndex >= 0) {
      _coHosts[pendingIndex]['agoraUid'] = agoraUid;
    }
  }

  void _createCoHostController(int agoraUid) {
    if (!_engineReady) return;
    final channel =
        _channel ?? widget.liveUser.channel ?? widget.liveUser.userId ?? '';
    _coHostControllers[agoraUid] = VideoViewController.remote(
      rtcEngine: _engine,
      canvas: VideoCanvas(
        uid: agoraUid,
        renderMode: RenderModeType.renderModeHidden,
        mirrorMode: VideoMirrorModeType.videoMirrorModeDisabled,
      ),
      connection: RtcConnection(channelId: channel),
      useFlutterTexture: true,
      useAndroidSurfaceView: false,
    );
    setState(() {});
  }

  void _createRemoteController(int agoraUid) {
    if (!_engineReady) return;
    final channel =
        _channel ?? widget.liveUser.channel ?? widget.liveUser.userId ?? '';
    _remoteController = VideoViewController.remote(
      rtcEngine: _engine,
      canvas: VideoCanvas(
        uid: agoraUid,
        renderMode: RenderModeType.renderModeHidden,
        mirrorMode: VideoMirrorModeType.videoMirrorModeDisabled,
      ),
      connection: RtcConnection(channelId: channel),
      useFlutterTexture: true,
      useAndroidSurfaceView: false,
    );
  }

  Future<void> _startBroadcast() async {
    if (!_engineReady || _myAgoraUid <= 0) return;
    try {
      // The viewer initially joined as audience with uid=0. To publish as a
      // co-host with a stable, known agoraUid, we must leave and rejoin.
      await _engine.leaveChannel();
      await _joinAgoraChannel(
        uid: _myAgoraUid,
        broadcaster: true,
        startPreview: true,
      );

      // Create local video controller for co-host (self view).
      _coHostControllers[_myAgoraUid] = VideoViewController(
        rtcEngine: _engine,
        canvas: const VideoCanvas(
          uid: 0,
          renderMode: RenderModeType.renderModeHidden,
          mirrorMode: VideoMirrorModeType.videoMirrorModeEnabled,
        ),
        useFlutterTexture: true,
        useAndroidSurfaceView: false,
      );

      if (mounted) setState(() {});
      Fluttertoast.showToast(msg: 'You joined the call');
    } catch (e) {
      Log.e(_tag, 'startBroadcast failed', e);
    }
  }

  Future<void> _stopBroadcast() async {
    try {
      await _engine.leaveChannel();
      _coHostControllers.remove(_myAgoraUid);
      // Rejoin as audience with uid=0 (the original audience uid).
      if (_uid case final uid?) {
        await _joinAgoraChannel(uid: uid, broadcaster: false);
      }
      if (mounted) setState(() {});
      Fluttertoast.showToast(msg: 'You left the call');
    } catch (e) {
      Log.e(_tag, 'stopBroadcast failed', e);
    }
  }

  void _sendJoinRequest() {
    final session = context.read<SessionManager>();
    final user = context.read<AuthProvider>().user;
    final name = user?.name ?? session.userName;
    final image = user?.image ?? session.userImage;
    SocketService.instance.emit(Const.eventAddRequestedCallJoin, {
      'userId': session.userId,
      'liveStreamingId': widget.liveUser.liveRoomId,
      'image': image,
      'name': name,
      'country': user?.country ?? '',
      'agoraUid': _myAgoraUid,
      'liveUserMongoId': widget.liveUser.id,
      'isMute': false,
      'isCameraOff': false,
      'isVIP': user?.isVIP ?? false,
      if (user?.vipDetails != null) 'vipDetails': user!.vipDetails!.toJson(),
    });
    // Mirror native: show the join request in the comment list with type 'callRequest'.
    SocketService.instance.emit(
      Const.eventComment,
      _buildCommentPayload(
        comment: '$name sent a request to join a call',
        userId: session.userId,
        name: name,
        image: image,
        type: 'callRequest',
        isVIP: user?.isVIP,
        vipDetails: user?.vipDetails?.toJson(),
      ),
    );
    Fluttertoast.showToast(
      msg: 'Request sent. Please wait for host to accept.',
    );
  }

  void _acceptJoinRequest(Map<String, dynamic> request) {
    if (_coHosts.length >= 9) {
      Fluttertoast.showToast(msg: 'Room is full (max 9 guests)');
      return;
    }
    final req = Map<String, dynamic>.from(request);
    req['isRequested'] = true;
    req['isAccept'] = true;
    req['isInvited'] = false;
    req['liveUserMongoId'] = widget.liveUser.id;
    req['liveStreamingId'] = widget.liveUser.liveRoomId;
    var acceptedAgoraUid = _coHostAgoraUid(req);
    if (acceptedAgoraUid == widget.liveUser.agoraUID) {
      acceptedAgoraUid = 0;
      req['agoraUid'] = 0;
    }

    // Add the accepted co-host to local UI immediately so the host doesn't
    // have to wait for the socket echo.
    setState(() {
      _coHosts.removeWhere((h) => h['userId'] == req['userId']);
      _coHosts.add(Map<String, dynamic>.from(req));
    });
    if (acceptedAgoraUid > 0) {
      _createCoHostController(acceptedAgoraUid);
    }

    SocketService.instance.emit(Const.eventAddParticipatesCallJoin, req);
    // Mirror native: announce the accepted guest in chat.
    final requesterName = request['name']?.toString() ?? 'Someone';
    final requesterImage = request['image']?.toString() ?? '';
    final requesterIsVip = request['isVIP'] == true;
    final requesterVipDetails =
        request['vipDetails'] is Map<String, dynamic>
            ? request['vipDetails'] as Map<String, dynamic>
            : null;
    SocketService.instance.emit(
      Const.eventComment,
      _buildCommentPayload(
        comment: '$requesterName Request accepted',
        userId: request['userId']?.toString() ?? '',
        name: requesterName,
        image: requesterImage,
        isVIP: requesterIsVip,
        vipDetails: requesterVipDetails,
      ),
    );
    setState(() {
      _joinRequests.removeWhere((r) => r['userId'] == request['userId']);
    });
  }

  void _rejectJoinRequest(Map<String, dynamic> request) {
    final req = Map<String, dynamic>.from(request);
    req['isAccept'] = false;
    req['liveUserMongoId'] = widget.liveUser.id;
    req['liveStreamingId'] = widget.liveUser.liveRoomId;
    SocketService.instance.emit(Const.eventLessParticipatesCallJoin, req);
    setState(() {
      _joinRequests.removeWhere((r) => r['userId'] == request['userId']);
    });
  }

  void _leaveCall() {
    final session = context.read<SessionManager>();
    SocketService.instance.emit(Const.eventLessParticipatesCallJoin, {
      'userId': session.userId,
      'liveUserMongoId': widget.liveUser.id,
      'liveStreamingId': widget.liveUser.liveRoomId,
      'agoraUid': _myAgoraUid,
    });
    _isJoined = false;
    _stopBroadcast();
  }

  void _toggleCoHostMute() async {
    final newMuted = !_micEnabled;
    final session = context.read<SessionManager>();
    await _engine.muteLocalAudioStream(newMuted);
    if (!mounted) return;
    setState(() => _micEnabled = !newMuted);
    SocketService.instance.emit(Const.eventMuteCallJoin, {
      'liveStreamingId': widget.liveUser.liveRoomId,
      'userId': session.userId,
      'isMute': newMuted,
    });
  }

  void _toggleCoHostCamera() async {
    final newCameraOff = !_isCameraOff;
    final session = context.read<SessionManager>();
    await _engine.muteLocalVideoStream(newCameraOff);
    if (!mounted) return;
    setState(() {
      _isCameraOff = newCameraOff;
      for (final coHost in _coHosts) {
        if (coHost['userId']?.toString() == session.userId) {
          coHost['isCameraOff'] = newCameraOff;
        }
      }
    });
    SocketService.instance.emit(Const.eventCameraOffCallJoin, {
      'liveStreamingId': widget.liveUser.liveRoomId,
      'userId': session.userId,
      'isCameraOff': newCameraOff,
    });
  }

  /// Native-style instant popup when a viewer requests to join the call
  /// (ports UnilivePro showPkRequestPopup). The host no longer has to dig
  /// through the menu to find pending requests.
  void _showJoinRequestDialog(Map<String, dynamic> request) {
    if (!widget.isHost || _joinRequestDialogOpen || !mounted) return;
    _joinRequestDialogOpen = true;
    final name = request['name']?.toString() ?? 'User';
    final image = request['image']?.toString();
    final frame =
        request['avatarFrame']?.toString() ??
        (request['vipDetails'] is Map
            ? (request['vipDetails'] as Map)['profileFrameUrl']?.toString()
            : null);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dlgCtx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Call Request',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(imageUrl: image, frameUrl: frame, size: 64),
                const SizedBox(height: 10),
                Text(
                  '$name wants to join the call',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                if (_joinRequests.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '+${_joinRequests.length - 1} more request(s)',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dlgCtx);
                  _rejectJoinRequest(request);
                },
                child: const Text(
                  'Decline',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(dlgCtx);
                  _acceptJoinRequest(request);
                },
                child: const Text(
                  'Accept',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    ).then((_) => _joinRequestDialogOpen = false);
  }

  /// Floating "call requests" pill shown on the host screen while requests
  /// are pending — tapping it opens the full requests sheet.
  Widget _buildJoinRequestFab() {
    final count = _joinRequests.length;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 64,
      right: 12,
      child: GestureDetector(
        onTap: _openJoinRequestsSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7E3FF2), Color(0xFF5b21b6)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7E3FF2).withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_add, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                count > 1 ? 'Requests ($count)' : 'Request',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openJoinRequestsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.5,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Join Requests',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                if (_joinRequests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No join requests',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _joinRequests.length,
                      itemBuilder: (_, i) {
                        final req = _joinRequests[i];
                        return ListTile(
                          leading: UserAvatar(
                            imageUrl: req['image']?.toString(),
                            size: 44,
                          ),
                          title: Text(
                            req['name']?.toString() ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  _acceptJoinRequest(req);
                                  if (_joinRequests.isEmpty) Navigator.pop(ctx);
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4CAF50),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  _rejectJoinRequest(req);
                                  if (_joinRequests.isEmpty) Navigator.pop(ctx);
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  // ---- Host co-host management ----

  void _openCoHostOptions(Map<String, dynamic> coHost) {
    final userId = coHost['userId']?.toString();
    final name = coHost['name']?.toString() ?? 'User';
    final isMuted = coHost['isMute'] == true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    isMuted ? Icons.mic_off : Icons.mic,
                    color: Colors.white70,
                  ),
                  title: Text(
                    isMuted ? 'Unmute' : 'Mute',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    SocketService.instance.emit(Const.eventMuteCallJoin, {
                      'liveStreamingId': widget.liveUser.liveRoomId,
                      'userId': userId,
                      'isMute': !isMuted,
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.call_end, color: Colors.red),
                  title: const Text(
                    'Remove from call',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    SocketService.instance
                        .emit(Const.eventLessParticipatesCallJoin, {
                          'userId': userId,
                          'liveUserMongoId': widget.liveUser.id,
                          'liveStreamingId': widget.liveUser.liveRoomId,
                          'agoraUid': coHost['agoraUid'],
                        });
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  /// Bigo/Chamet-style call invite popup shown to the invited viewer.
  /// Ports native HostPKLiveActivity.onInvite — on accept, the viewer
  /// emits `eventAddParticipatesCallJoin` with `isInvited: true` to join
  /// the host's call grid as a co-host/guest.
  void _showCallInviteDialog(String hostName, Map<String, dynamic> inviteData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.video_call,
                  color: Color(0xFF7E3FF2),
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$hostName is inviting you to join the call',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Join as a guest in the live video call?',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Decline',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Accept'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
    ).then((accept) async {
      if (!mounted) return;
      if (accept == true) {
        final session = context.read<SessionManager>();
        final user = context.read<AuthProvider>().user;
        final coHostData = {
          'userId': session.userId,
          'liveStreamingId': widget.liveUser.liveRoomId,
          'image': user?.image ?? session.userImage,
          'name': user?.name ?? session.userName,
          'country': user?.country ?? '',
          'agoraUid': _myAgoraUid,
          'liveUserMongoId': widget.liveUser.id,
          'isMute': false,
          'isRequested': false,
          'isAccept': true,
          'isInvited': true,
          'type': 'user',
          'isVIP': user?.isVIP ?? false,
          'isCameraOff': false,
        };

        // Switch to broadcaster immediately so the local co-host video shows
        // up without waiting for the backend socket echo.
        if (!_isJoined) {
          _isJoined = true;
          await _startBroadcast();
        }

        if (mounted) {
          setState(() {
            _coHosts.removeWhere((h) => h['userId'] == session.userId);
            _coHosts.add(Map<String, dynamic>.from(coHostData));
          });
          SocketService.instance.emit(
            Const.eventAddParticipatesCallJoin,
            coHostData,
          );
        }
        Fluttertoast.showToast(msg: 'Joining the call...');
      }
    });
  }

  void _inviteViewerToCall(ViewerEntry viewer) {
    final userId = viewer.userId;
    if (userId == null || userId.isEmpty) return;
    if (_coHosts.length >= 9) {
      Fluttertoast.showToast(msg: 'Room is full (max 9 guests)');
      return;
    }
    // Bigo/Chamet-style: host emits `eventInvite` + room comment with type: 'callInvite'
    // so viewer receives invitation popup through either channel.
    final session = context.read<SessionManager>();
    SocketService.instance.emit(Const.eventInvite, {
      'liveUserMongoId': widget.liveUser.id,
      'liveStreamingId': widget.liveUser.liveRoomId,
      'liveUserId': widget.liveUser.userId,
      'userId': userId,
      'targetUserId': userId,
      'hostName': session.userName,
      'name': viewer.name ?? '',
      'image': viewer.image ?? '',
    });
    SocketService.instance.emit(Const.eventComment, {
      'comment': '${session.userName} is inviting you to join the call',
      'liveStreamingId': widget.liveUser.liveRoomId,
      'liveUserId': widget.liveUser.userId,
      'liveUserMongoId': widget.liveUser.id,
      'userId': session.userId,
      'targetUserId': userId,
      'type': 'callInvite',
      'hostName': session.userName,
      'isSystem': true,
    });
    Fluttertoast.showToast(msg: 'Invitation sent to ${viewer.name ?? 'user'}');
  }

  void _openHostMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Right-side toolbar controls now live in the menu.
                          _menuTile(
                            ctx,
                            Icons.videocam,
                            _cameraEnabled ? 'Video Off' : 'Video On',
                            Colors.white,
                            _toggleCamera,
                          ),
                          _menuTile(
                            ctx,
                            Icons.cameraswitch,
                            'Flip Camera',
                            Colors.white,
                            _switchCamera,
                          ),
                          _menuTile(
                            ctx,
                            Icons.face_retouching_natural,
                            'Beauty',
                            Colors.white,
                            () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder:
                                  (_) => BeautyOptionsSheet(
                                    engine: _engine,
                                    initialSmoothness: widget.smoothness,
                                    initialLightening: widget.lightening,
                                    initialRedness: widget.redness,
                                    initialLighteningContrast:
                                        _currentLighteningContrast,
                                    onBeautyActiveChanged: (active) {
                                      if (mounted) {
                                        setState(
                                          () => _beautyModeActive = active,
                                        );
                                      }
                                    },
                                  ),
                            ),
                          ),
                          _menuTile(
                            ctx,
                            Icons.graphic_eq,
                            'Voice Changer',
                            Colors.cyan,
                            () => showVoiceChangerSheet(context, _engine),
                          ),
                          _menuTile(
                            ctx,
                            Icons.surround_sound,
                            'Sound FX',
                            Colors.amber,
                            () => showSoundEffectsSheet(
                              context,
                              service: _musicSoundService,
                              liveStreamingId: widget.liveUser.liveRoomId ?? '',
                            ),
                          ),
                          _menuTile(
                            ctx,
                            Icons.auto_fix_high,
                            'Effect Settings',
                            Colors.cyan,
                            _openEffectSettings,
                          ),
                          _menuTile(
                            ctx,
                            Icons.music_note,
                            'Music',
                            Colors.purple,
                            _openMusic,
                          ),
                          _menuTile(
                            ctx,
                            Icons.poll,
                            'Create Poll',
                            Colors.deepPurpleAccent,
                            _createRoomPoll,
                          ),
                          _menuTile(
                            ctx,
                            Icons.music_video,
                            'Music Access: $_musicPermission',
                            Colors.purpleAccent,
                            _showMusicPermissionPicker,
                          ),
                          _menuTile(
                            ctx,
                            Icons.face,
                            'AR Stickers',
                            Colors.purpleAccent,
                            _openArStickers,
                          ),
                          _menuTile(
                            ctx,
                            Icons.account_circle,
                            'Virtual Avatar',
                            Colors.tealAccent,
                            _openVirtualAvatar,
                          ),
                          _menuTile(
                            ctx,
                            Icons.ondemand_video,
                            'Co-Watch',
                            Colors.blueAccent,
                            _openCoWatch,
                          ),
                          _menuTile(
                            ctx,
                            _isClipCapturing
                                ? Icons.stop_circle
                                : Icons.content_cut,
                            _isClipCapturing ? 'Stop Live Clip' : 'Live Clip',
                            _isClipCapturing ? Colors.red : Colors.orangeAccent,
                            _toggleClipCapture,
                          ),
                          _menuTile(
                            ctx,
                            Icons.tune,
                            'Stream Quality',
                            Colors.white,
                            _openStreamQuality,
                          ),
                          _menuTile(
                            ctx,
                            Icons.draw,
                            _showDrawAndGuess
                                ? 'Stop Draw & Guess'
                                : 'Draw & Guess',
                            _showDrawAndGuess
                                ? Colors.red
                                : Colors.orangeAccent,
                            _toggleDrawAndGuess,
                          ),
                          _menuTile(
                            ctx,
                            Icons.wallpaper,
                            'Room Background',
                            Colors.purpleAccent,
                            _openRoomBackgroundPicker,
                          ),
                          const Divider(color: Colors.white12),
                          _menuTile(
                            ctx,
                            Icons.group_add,
                            _joinRequests.isNotEmpty
                                ? 'Call Request (${_joinRequests.length})'
                                : 'Call Request',
                            const Color(0xFF7E3FF2),
                            _openJoinRequestsSheet,
                          ),
                          _menuTile(
                            ctx,
                            Icons.card_giftcard,
                            'Lucky Bag',
                            Colors.pink,
                            _openLuckyBag,
                          ),
                          _menuTile(
                            ctx,
                            Icons.sports_kabaddi,
                            'VS / PK',
                            Colors.red,
                            _openVS,
                          ),
                          AIFeatureGuard(
                            featureKey: AIFeatureKeys.pkBattleMatchmaker,
                            child: _menuTile(
                              ctx,
                              Icons.shuffle,
                              'Quick PK Match',
                              Colors.deepOrange,
                              _quickPkMatch,
                            ),
                          ),
                          AIFeatureGuard(
                            featureKey: AIFeatureKeys.groupRoomMatchmaker,
                            child: _menuTile(
                              ctx,
                              Icons.group_work,
                              'Group Room Match',
                              Colors.teal,
                              _openGroupMatch,
                            ),
                          ),
                          _menuTile(
                            ctx,
                            Icons.history,
                            'PK Round History',
                            Colors.white70,
                            _openPkRoundHistory,
                          ),
                          _menuTile(
                            ctx,
                            Icons.gamepad,
                            'Games',
                            Colors.green,
                            _openGames,
                          ),
                          _menuTile(
                            ctx,
                            Icons.celebration,
                            'Party Game',
                            Colors.pink,
                            _openPartyGame,
                          ),
                          _menuTile(
                            ctx,
                            Icons.store,
                            'Store',
                            Colors.blue,
                            _openStore,
                          ),
                          _menuTile(
                            ctx,
                            Icons.construction,
                            'Tools',
                            Colors.orange,
                            _openTools,
                          ),
                          _menuTile(
                            ctx,
                            Icons.video_settings,
                            'Video Quality',
                            Colors.cyan,
                            _openVideoQualitySheet,
                          ),
                          _menuTile(
                            ctx,
                            Icons.photo_camera,
                            'Room Picture',
                            Colors.teal,
                            _pickAndUploadRoomImage,
                          ),
                          _menuTile(
                            ctx,
                            Icons.campaign,
                            'Announcement',
                            Colors.amber,
                            _editAnnouncement,
                          ),
                          _menuTile(
                            ctx,
                            Icons.shield,
                            'Admin List',
                            Colors.white70,
                            _openAdminList,
                          ),
                          _menuTile(
                            ctx,
                            Icons.people,
                            'Fans Ranking',
                            Colors.pink,
                            _openFansRanking,
                          ),
                          _menuTile(
                            ctx,
                            Icons.translate,
                            _isTranslationEnabled
                                ? 'Translation: ON'
                                : 'Translation',
                            const Color(0xFF26A69A),
                            _toggleChatTranslation,
                          ),
                          _menuTile(
                            ctx,
                            Icons.group,
                            'Fan Club',
                            Colors.pink,
                            _openFanClub,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _openAudienceMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: Colors.white12),
                _menuTile(
                  ctx,
                  Icons.call,
                  'Call',
                  const Color(0xFF7E3FF2),
                  _openHandRaise,
                ),
                _menuTile(
                  ctx,
                  Icons.subscriptions,
                  'Subscription',
                  const Color(0xFFE91E63),
                  _openSubscription,
                ),
                if (_musicPermission == 'friends')
                  _menuTile(
                    ctx,
                    Icons.queue_music,
                    'Request Music',
                    Colors.purpleAccent,
                    _requestFriendMusic,
                  ),
                _menuTile(
                  ctx,
                  Icons.pan_tool,
                  'Raise Hand',
                  Colors.orange,
                  _sendJoinRequest,
                ),
                if (_isPkActive)
                  _menuTile(
                    ctx,
                    Icons.how_to_vote,
                    'Vote',
                    Colors.blue,
                    _openVote,
                  ),
                _menuTile(
                  ctx,
                  Icons.card_giftcard,
                  'Lucky Bag',
                  Colors.pink,
                  _openLuckyBag,
                ),
                _menuTile(ctx, Icons.gamepad, 'Game', Colors.green, _openGames),
                _menuTile(
                  ctx,
                  Icons.celebration,
                  'Party Game',
                  Colors.pink,
                  _openPartyGame,
                ),
                _menuTile(
                  ctx,
                  Icons.construction,
                  'Tools',
                  Colors.orange,
                  _openTools,
                ),
                _menuTile(
                  ctx,
                  Icons.surround_sound,
                  'Sound FX',
                  Colors.amber,
                  () => showSoundEffectsSheet(
                    context,
                    service: _musicSoundService,
                    liveStreamingId: widget.liveUser.liveRoomId ?? '',
                  ),
                ),
                _menuTile(
                  ctx,
                  Icons.auto_fix_high,
                  'Effect Settings',
                  Colors.cyan,
                  _openEffectSettings,
                ),
                _menuTile(
                  ctx,
                  Icons.emoji_events,
                  'Leaderboard',
                  Colors.yellow,
                  _openLeaderboard,
                ),
                _menuTile(
                  ctx,
                  Icons.translate,
                  _isTranslationEnabled ? 'Translation: ON' : 'Translation',
                  const Color(0xFF26A69A),
                  _toggleChatTranslation,
                ),
                _menuTile(
                  ctx,
                  Icons.celebration,
                  'Live Events',
                  Colors.yellow,
                  _openLiveEvents,
                ),
                _menuTile(
                  ctx,
                  Icons.group,
                  'Fan Club',
                  Colors.pink,
                  _openFanClub,
                ),
                _menuTile(
                  ctx,
                  Icons.share,
                  'Share Live',
                  Colors.white70,
                  _openInboxShare,
                ),
                _menuTile(
                  ctx,
                  Icons.ios_share,
                  'Share via App',
                  Colors.lightBlue,
                  _openNativeShare,
                ),
                // Room-admin powers: manage viewers (tap a viewer to mute/kick/
                // ban), view admin list, and end the live when required.
                if (_iAmAdmin) ...[
                  const Divider(color: Colors.white12),
                  _menuTile(
                    ctx,
                    Icons.shield,
                    'Admin List',
                    Colors.white70,
                    _openAdminList,
                  ),
                  _menuTile(
                    ctx,
                    Icons.call_end,
                    'End Live (Admin)',
                    Colors.red,
                    () {
                      SocketService.instance.emit(Const.eventLiveEndByAdmin, {
                        'liveStreamingId': widget.liveUser.liveRoomId ?? '',
                        'liveUserMongoId': widget.liveUser.id ?? '',
                        'userId': context.read<SessionManager>().userId,
                      });
                      Fluttertoast.showToast(msg: 'Live ended');
                      Navigator.pop(context);
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  Widget _menuTile(
    BuildContext ctx,
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
  }

  Future<void> _setQuality(String quality) async {
    if (quality == _currentQuality) return;
    setState(() => _currentQuality = quality);
    if (!_engineReady) return;
    try {
      await _engine.setVideoEncoderConfiguration(_getVideoConfig());
      Log.i(_tag, 'video quality switched to $_currentQuality');
    } catch (e, s) {
      Log.e(_tag, 'setVideoEncoderConfiguration failed', e, s);
    }
  }

  void _openVideoQualitySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Video Quality',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: Colors.white12),
                _menuTile(
                  ctx,
                  Icons.videocam,
                  'SD (360p)',
                  Colors.white70,
                  () => _setQuality('sd'),
                ),
                _menuTile(
                  ctx,
                  Icons.videocam,
                  'HD (720p)',
                  Colors.white70,
                  () => _setQuality('hd'),
                ),
                _menuTile(
                  ctx,
                  Icons.videocam,
                  'FHD (1080p)',
                  Colors.white70,
                  () => _setQuality('fhd'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  /// Pick an image from gallery and upload it as a room picture.
  /// VIP-gated feature — mirrors native `onClickRoomCamera` + `uploadRoomImage`.
  Future<void> _pickAndUploadRoomImage() async {
    final session = context.read<SessionManager>();
    final user = session.getUser();
    if (user == null) return;

    // VIP check — only VIP with sendRoomPictures privilege can use this.
    if (!user.isVIP ||
        user.vipDetails == null ||
        !user.vipDetails!.isSendRoomPicturesEnabled) {
      Fluttertoast.showToast(
        msg: 'VIP membership required to send room pictures',
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (xfile == null) return;
      final file = File(xfile.path);
      if (!file.existsSync()) return;

      Fluttertoast.showToast(msg: 'Uploading image...');

      // Try uploading without a topic first (avoids creating inbox entry).
      var res = await ApiService.uploadChatImage(
        file: file,
        userId: session.userId,
        topic: null,
      );

      // Fallback: create a self-topic and retry.
      if (!res.status || res.chat == null) {
        Log.w(
          _tag,
          'uploadRoomImage: no-topic failed, falling back to self-topic',
        );
        final topicRes = await ApiService.createChatTopic(
          myUserId: session.userId,
          otherUserId: session.userId,
        );
        final topic = topicRes.topic ?? '';
        if (topic.isEmpty) {
          Fluttertoast.showToast(msg: 'Failed to upload image');
          return;
        }
        res = await ApiService.uploadChatImage(
          file: file,
          userId: session.userId,
          topic: topic,
        );
      }

      if (!res.status || res.chat == null) {
        Fluttertoast.showToast(msg: 'Failed to upload image: ${res.message}');
        return;
      }

      final imageUrl = res.chat!['image']?.toString() ?? '';
      final chatId =
          res.chat!['_id']?.toString() ?? res.chat!['id']?.toString() ?? '';
      if (imageUrl.isEmpty) {
        Fluttertoast.showToast(
          msg: 'Upload succeeded but no image URL returned',
        );
        return;
      }

      // Delete the chat entry to avoid creating an inbox message.
      if (chatId.isNotEmpty) {
        try {
          await ApiService.deleteChat(chatId);
        } catch (e) {
          Log.w(_tag, 'deleteChat failed (non-critical): $e');
        }
      }

      // Send the image URL as a comment via socket so all viewers see it.
      SocketService.instance.emit(
        Const.eventComment,
        _buildCommentPayload(
          comment: '[Image]',
          userId: session.userId,
          imageUrl: imageUrl,
          type: 'image',
        ),
      );
      Log.d(_tag, 'sendRoomImageMessage: emitted comment with url=$imageUrl');
      Fluttertoast.showToast(msg: 'Room picture sent');
    } catch (e, s) {
      Log.e(_tag, 'pickAndUploadRoomImage failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to send room picture');
    }
  }

  Future<void> _toggleSpeaker() async {
    _speakerEnabled = !_speakerEnabled;
    await _engine.muteAllRemoteAudioStreams(!_speakerEnabled);
    setState(() {});
  }

  void _openMessages() {
    context.pushNamed(AppRoutes.chat);
  }

  void _sendCheer() {
    final session = context.read<SessionManager>();
    final user = context.read<AuthProvider>().user;
    // Only show the heart animation â€” NO comment in chat
    _cheerKey.currentState?.addCheer(
      name: user?.name ?? 'Me',
      imageUrl: user?.image,
    );
    SocketService.instance.emit('cheer', {
      'liveStreamingId': widget.liveUser.liveRoomId,
      'userId': session.userId,
      'name': user?.name ?? session.getUser()?.name ?? '',
      'image': user?.image ?? '',
    });
  }

  void _showMusicPermissionPicker() {
    Navigator.pop(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF17172A),
      builder:
          (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final permission in const ['host', 'admins', 'friends'])
                  RadioListTile<String>(
                    value: permission,
                    groupValue: _musicPermission,
                    activeColor: const Color(0xFFB388FF),
                    title: Text(
                      permission == 'host'
                          ? 'Host only'
                          : permission == 'admins'
                          ? 'Host and authorized admins'
                          : 'Friends can request songs',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      Navigator.pop(sheetContext);
                      SocketService.instance
                          .emit(Const.eventMusicPermissionUpdated, {
                            'liveStreamingId': widget.liveUser.liveRoomId,
                            'hostUserId': widget.liveUser.userId,
                            'userId': context.read<SessionManager>().userId,
                            'musicPermission': value,
                          });
                    },
                  ),
              ],
            ),
          ),
    );
  }

  void _requestFriendMusic() {
    Navigator.pop(context);
    Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder:
            (_) => AddMusicScreen(
              onSongSelected: ({url, title, artist, image}) {
                if (url?.isNotEmpty != true) return;
                final track = RoomMusicTrack.fromServerSong(
                  id: title ?? url!,
                  title: title ?? 'Unknown',
                  artist: artist,
                  url: url!,
                  image: image,
                );
                SocketService.instance.emit(Const.eventFriendMusicRequest, {
                  'liveStreamingId': widget.liveUser.liveRoomId,
                  'hostUserId': widget.liveUser.userId,
                  'requesterUserId': context.read<SessionManager>().userId,
                  'track': track.toSocketJson(),
                });
                Fluttertoast.showToast(msg: 'Music request sent to host');
              },
            ),
      ),
    );
  }

  void _handleFriendMusicRequest(dynamic data) {
    final map = _unwrapCommentPayload(data);
    if (map.isEmpty || !_runtimeEventMatchesRoom(map) || !widget.isHost) return;
    final rawTrack = map['track'];
    if (rawTrack is! Map || _friendMusicDialogOpen || !mounted) return;
    final track = RoomMusicTrack.fromSocketJson(
      Map<String, dynamic>.from(rawTrack),
    );
    if (track.source.isEmpty) return;
    _friendMusicDialogOpen = true;
    final requesterName =
        (map['requesterName'] ?? map['name'] ?? 'A friend').toString();
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Music Request'),
            content: Text('$requesterName requested “${track.title}”.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _respondToFriendMusicRequest(map, track, false);
                },
                child: const Text('Reject'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _respondToFriendMusicRequest(map, track, true);
                },
                child: const Text('Play'),
              ),
            ],
          ),
    ).whenComplete(() => _friendMusicDialogOpen = false);
  }

  Future<void> _respondToFriendMusicRequest(
    Map<String, dynamic> request,
    RoomMusicTrack track,
    bool approved,
  ) async {
    SocketService.instance.emit(Const.eventFriendMusicRequestUpdated, {
      ...request,
      'liveStreamingId': widget.liveUser.liveRoomId,
      'approved': approved,
      'status': approved ? 'approved' : 'rejected',
      'track': track.toSocketJson(),
    });
    if (!approved) return;
    final controller = _musicController;
    if (controller == null || !controller.canControl) return;
    controller.addTracks([track]);
    await controller.playAt(controller.queue.length - 1);
  }

  void _handleFriendMusicRequestUpdated(dynamic data) {
    final map = _unwrapCommentPayload(data);
    if (map.isEmpty || !_runtimeEventMatchesRoom(map)) return;
    final requesterId = (map['requesterUserId'] ?? map['userId'])?.toString();
    if (requesterId?.isNotEmpty == true &&
        requesterId != context.read<SessionManager>().userId) {
      return;
    }
    final approved =
        map['approved'] == true || map['status']?.toString() == 'approved';
    Fluttertoast.showToast(
      msg:
          approved
              ? 'Your music request was approved'
              : 'Music request rejected',
    );
  }

  void _openMusic() {
    if (!_engineReady) {
      Fluttertoast.showToast(msg: 'Engine not ready');
      return;
    }
    final controller = _musicController;
    if (controller == null) {
      Fluttertoast.showToast(msg: 'Music player not ready');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AudioRoomMusicScreen(controller: controller),
      ),
    );
  }

  // ---- Bigo-parity feature helpers ----

  void _openArStickers() {
    showArFaceStickerSheet(context);
  }

  void _openVirtualAvatar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _VirtualAvatarPickerSheet(),
    );
  }

  void _openCoWatch() {
    _coWatchController ??= CoWatchController(isHost: widget.isHost);
    _coWatchController!.hooks = CoWatchSocketHooks(
      onPlay:
          (url, title, positionMs) =>
              SocketService.instance.emit(Const.eventCoWatchPlay, {
                'liveStreamingId': widget.liveUser.liveRoomId,
                'url': url,
                'title': title,
                'positionMs': positionMs,
              }),
      onPause:
          () => SocketService.instance.emit(Const.eventCoWatchPause, {
            'liveStreamingId': widget.liveUser.liveRoomId,
          }),
      onResume:
          () => SocketService.instance.emit(Const.eventCoWatchResume, {
            'liveStreamingId': widget.liveUser.liveRoomId,
          }),
      onSeek:
          (positionMs) => SocketService.instance.emit(Const.eventCoWatchSeek, {
            'liveStreamingId': widget.liveUser.liveRoomId,
            'positionMs': positionMs,
          }),
      onStop:
          () => SocketService.instance.emit(Const.eventCoWatchStop, {
            'liveStreamingId': widget.liveUser.liveRoomId,
          }),
      onVideoChanged:
          (url, title) => SocketService.instance.emit(Const.eventCoWatchPlay, {
            'liveStreamingId': widget.liveUser.liveRoomId,
            'url': url,
            'title': title,
            'positionMs': 0,
          }),
    );
    if (widget.isHost) {
      _showCoWatchUrlSheet();
    } else {
      Fluttertoast.showToast(
        msg: 'Co-Watch ready — waiting for host to start a video',
      );
      setState(() {});
    }
  }

  void _showCoWatchUrlSheet() {
    final urlCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Co-Watch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Video URL',
                    hintText: 'https://...',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Title (optional)',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final url = urlCtrl.text.trim();
                    if (url.isEmpty) {
                      Fluttertoast.showToast(msg: 'Enter a video URL');
                      return;
                    }
                    Navigator.pop(ctx);
                    _coWatchController?.setVideo(
                      url,
                      title: titleCtrl.text.trim(),
                    );
                    setState(() {});
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: const Color(0xFF7E3FF2),
                  ),
                  child: const Text('Start Watching'),
                ),
              ],
            ),
          ),
    );
  }

  void _applyCoWatchData(
    dynamic data,
    void Function(Map<String, dynamic>, String, String, int) cb,
  ) {
    try {
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      if (map == null) return;
      final room = map['liveStreamingId']?.toString() ?? '';
      if (room.isNotEmpty && room != widget.liveUser.liveRoomId) return;
      final url = map['url']?.toString() ?? '';
      final title = map['title']?.toString() ?? '';
      final pos =
          map['positionMs'] is int
              ? map['positionMs'] as int
              : int.tryParse(map['positionMs']?.toString() ?? '0') ?? 0;
      if (url.isEmpty) return;
      _coWatchController ??= CoWatchController(isHost: widget.isHost);
      cb(map, url, title, pos);
    } catch (_) {}
  }

  void _toggleDrawAndGuess() {
    setState(() {
      _showDrawAndGuess = !_showDrawAndGuess;
      if (_showDrawAndGuess) {
        _drawAndGuessController ??= DrawAndGuessController(
          roomId: widget.liveUser.liveRoomId ?? '',
          localUserId: context.read<SessionManager>().userId,
        );
      }
    });
  }

  Future<void> _openRoomBackgroundPicker() async {
    await AnimatedRoomBackgroundService.instance.fetchFromBackend();
    final backgrounds = AnimatedRoomBackgroundService.instance.backgrounds;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Room Background',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: backgrounds.length,
                    itemBuilder: (ctx, i) {
                      final bg = backgrounds[i];
                      final isSelected =
                          AnimatedRoomBackgroundService
                              .instance
                              .activeBackground
                              ?.id ==
                          bg.id;
                      return GestureDetector(
                        onTap: () {
                          AnimatedRoomBackgroundService.instance
                              .selectBackground(bg);
                          SocketService.instance.emit(Const.eventChangeTheme, {
                            'liveStreamingId': widget.liveUser.liveRoomId,
                            'background': bg.staticImageUrl ?? '',
                            'themeId': bg.id,
                          });
                          setState(() => _backgroundImage = bg.staticImageUrl);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors:
                                  bg.gradientColors.isNotEmpty
                                      ? bg.gradientColors
                                      : const [
                                        Color(0xFF1A1A2E),
                                        Color(0xFF16213E),
                                      ],
                            ),
                            border:
                                isSelected
                                    ? Border.all(
                                      color: const Color(0xFF7E3FF2),
                                      width: 2,
                                    )
                                    : null,
                          ),
                          child: Center(
                            child: Text(
                              bg.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  void _toggleChatTranslation() {
    final pickerItems =
        ChatTranslationService.supportedLanguages.map((l) => l.name).toList();
    if (!_isTranslationEnabled) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder:
            (ctx) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Translate to',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: pickerItems.length,
                    itemBuilder: (ctx, i) {
                      final lang = ChatTranslationService.supportedLanguages[i];
                      return ListTile(
                        leading: Text(
                          lang.code,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        title: Text(
                          lang.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing:
                            _translationTargetLang == lang.code
                                ? const Icon(
                                  Icons.check,
                                  color: Color(0xFF26A69A),
                                )
                                : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          _translationTargetLang = lang.code;
                          _setTranslationEnabled(true);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
      );
    } else {
      _setTranslationEnabled(false);
    }
  }

  void _setTranslationEnabled(bool enabled) {
    setState(() => _isTranslationEnabled = enabled);
    ChatTranslationService.instance.toggleTranslation(enabled);
    ChatTranslationService.instance.setTargetLanguage(_translationTargetLang);
    if (enabled) {
      for (final c in _comments) {
        _translateComment(c);
      }
    }
    Fluttertoast.showToast(msg: enabled ? 'Translation ON' : 'Translation OFF');
  }

  Future<void> _translateComment(_LiveComment c) async {
    final text = c.text;
    if (text == null || text.isEmpty) return;
    final translated = await ChatTranslationService.instance.translateMessage(
      text,
      _translationTargetLang,
    );
    if (mounted && translated.isNotEmpty && translated != text) {
      setState(() => c.translatedText = translated);
    }
  }

  void _openLiveEvents() {
    context.pushNamed(AppRoutes.liveEvents);
  }

  void _openFanClub() {
    context.pushNamed(AppRoutes.fanClub);
  }

  Future<void> _toggleClipCapture() async {
    if (_isClipCapturing) {
      LiveClipService.instance.cancelClipCapture();
      setState(() => _isClipCapturing = false);
      return;
    }
    LiveClipService.instance.bind(
      _engine,
      streamId: widget.liveUser.liveRoomId ?? '',
      userId: context.read<SessionManager>().userId,
    );
    setState(() => _isClipCapturing = true);
    await LiveClipService.instance.startClipCapture(durationSeconds: 15);
    if (mounted) setState(() => _isClipCapturing = false);
    final clip = LiveClipService.instance.getClips().lastOrNull;
    if (clip != null && mounted) {
      Fluttertoast.showToast(msg: 'Clip captured (${clip.duration}s)');
    }
  }

  void _openStreamQuality() {
    showStreamQualitySheet(context, _currentStreamQuality, (q) {
      setState(() => _currentStreamQuality = q);
      _applyStreamQuality(q);
    });
  }

  void _applyStreamQuality(String quality) {
    if (!_engineReady) return;
    final dims = switch (quality) {
      'hd' => const VideoDimensions(width: 720, height: 1280),
      'sd' => const VideoDimensions(width: 360, height: 640),
      'low' => const VideoDimensions(width: 240, height: 426),
      _ => const VideoDimensions(width: 540, height: 960),
    };
    final bitrate = switch (quality) {
      'hd' => 1200,
      'sd' => 500,
      'low' => 250,
      _ => 800,
    };
    _engine.setVideoEncoderConfiguration(
      VideoEncoderConfiguration(
        dimensions: dims,
        bitrate: bitrate,
        frameRate: 15,
      ),
    );
    Fluttertoast.showToast(msg: 'Quality: ${quality.toUpperCase()}');
  }

  void _openVS() {
    _openLiveHostsForPk();
  }

  /// One-click PK matchmaking powered by the Master AI Control Engine.
  /// Falls back to the manual host-picker when the feature is disabled.
  Future<void> _quickPkMatch() async {
    try {
      final ai = context.read<AIFeatureManager>();
      final session = context.read<SessionManager>();
      final result = await DynamicAIFeaturesService.instance.findPkMatch(
        hostUserId: session.userId,
        ai: ai,
      );
      if (!mounted) return;
      if (result.success && result.opponent != null) {
        _sendPkRequest(result.opponent!);
      } else {
        Fluttertoast.showToast(msg: result.message ?? 'No match found');
      }
    } catch (e, s) {
      Log.e(_tag, 'quickPkMatch failed', e, s);
      Fluttertoast.showToast(msg: 'Matchmaking failed');
    }
  }

  /// Open the AI Group Room Matchmaker sheet.
  void _openGroupMatch() {
    final session = context.read<SessionManager>();
    showGroupMatchSheet(context, session.userId);
  }

  void _openStore() {
    context.pushNamed(AppRoutes.store);
  }

  void _openPartyGame() {
    final session = context.read<SessionManager>();
    showPartyGameSheet(
      context,
      isHost: widget.isHost,
      liveStreamingId: widget.liveUser.liveRoomId ?? '',
      userId: session.userId,
      onLuckyBag: _openLuckyBag,
      onPK: _openVS,
      onVideoMusic: _openVideoMusic,
      onLudo: _openLudo,
    );
  }

  void _openTools() {
    showToolsSheet(
      context,
      onStore: _openStore,
      onEffect: _openEffectSettings,
      onMyItems: _openMyItems,
    );
  }

  void _openVideoMusic() {
    _openMusic();
  }

  void _openLudo() {
    context.pushNamed(AppRoutes.ludoGame);
  }

  void _openMyItems() {
    context.pushNamed(AppRoutes.myStore);
  }

  /// Host sets the room announcement — shown as a scrolling marquee at the
  /// top of the room for all viewers and broadcast via socket.
  void _editAnnouncement() {
    final ctrl = TextEditingController(text: _liveAnnouncement);
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Room Announcement'),
            content: TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'e.g. Tomorrow 8PM — 2x gifting event! Game night Friday!',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() => _liveAnnouncement = '');
                  SocketService.instance.emit(Const.eventRoomWelcome, {
                    'liveStreamingId': widget.liveUser.liveRoomId ?? '',
                    'roomWelcome': '',
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Clear'),
              ),
              FilledButton(
                onPressed: () {
                  final text = ctrl.text.trim();
                  setState(() => _liveAnnouncement = text);
                  final liveId = widget.liveUser.liveRoomId ?? '';
                  SocketService.instance.emit(Const.eventRoomWelcome, {
                    'liveStreamingId': liveId,
                    'roomWelcome': text,
                  });
                  SocketService.instance.emit('roomAnnouncement', {
                    'liveStreamingId': liveId,
                    'announcement': text,
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _openEffectSettings() {
    context
        .pushNamed(AppRoutes.effectSettings)
        .then((_) => _loadEffectSettings());
  }

  void _openLeaderboard() {
    showLiveRankingSheet(
      context,
      hostUserId: widget.liveUser.userId ?? '',
      hostName: widget.liveUser.name ?? 'Host',
    );
  }

  bool _runtimeEventMatchesRoom(Map<String, dynamic> map) {
    final roomId =
        (map['liveStreamingId'] ?? map['roomId'] ?? map['liveId'])?.toString();
    final currentRoomId = widget.liveUser.liveRoomId ?? widget.liveUser.id;
    return roomId?.isNotEmpty != true || roomId == currentRoomId;
  }

  void _applyRoomPollEvent(dynamic data) {
    final map = _unwrapCommentPayload(data);
    if (map.isEmpty || !_runtimeEventMatchesRoom(map)) return;
    final poll = RoomPoll.fromJson(map);
    if (poll.pollId.isEmpty || poll.options.length < 2 || !mounted) return;
    final previous = _activeRoomPoll;
    final samePoll = previous?.pollId == poll.pollId;
    setState(() {
      _activeRoomPoll = poll.copyWith(
        hasVoted: poll.hasVoted || (samePoll && previous!.hasVoted),
        selectedOptionId:
            poll.selectedOptionId ??
            (samePoll ? previous!.selectedOptionId : null),
      );
    });
  }

  void _applyRoomPollEnded(dynamic data) {
    final map = _unwrapCommentPayload(data);
    if (map.isEmpty || !_runtimeEventMatchesRoom(map) || !mounted) return;
    final poll = RoomPoll.fromJson(map);
    if (poll.pollId.isEmpty) return;
    final previous = _activeRoomPoll;
    setState(() {
      _activeRoomPoll =
          poll.options.isEmpty && previous?.pollId == poll.pollId
              ? previous!.copyWith(ended: true)
              : poll.copyWith(
                ended: true,
                hasVoted:
                    poll.hasVoted ||
                    (previous?.pollId == poll.pollId && previous!.hasVoted),
                selectedOptionId:
                    poll.selectedOptionId ??
                    (previous?.pollId == poll.pollId
                        ? previous!.selectedOptionId
                        : null),
              );
    });
  }

  void _createRoomPoll() {
    Navigator.pop(context);
    showCreateRoomPollSheet(
      context,
      onCreate: (question, options) {
        final stamp = DateTime.now().millisecondsSinceEpoch;
        SocketService.instance.emit(Const.eventRoomPollCreate, {
          'liveStreamingId': widget.liveUser.liveRoomId,
          'userId': context.read<SessionManager>().userId,
          'question': question,
          'options': [
            for (var i = 0; i < options.length; i++)
              {'id': '${stamp}_$i', 'text': options[i]},
          ],
          'durationSeconds': 60,
        });
      },
    );
  }

  void _voteRoomPoll(String optionId) {
    final poll = _activeRoomPoll;
    if (poll == null || poll.hasVoted || poll.ended) return;
    setState(() {
      _activeRoomPoll = poll.copyWith(
        hasVoted: true,
        selectedOptionId: optionId,
      );
    });
    SocketService.instance.emit(Const.eventRoomPollVote, {
      'pollId': poll.pollId,
      'liveStreamingId': widget.liveUser.liveRoomId,
      'userId': context.read<SessionManager>().userId,
      'optionId': optionId,
    });
  }

  void _openVote() {
    if (!_isPkActive) return;
    final session = context.read<SessionManager>();
    showPkVoteSheet(
      context,
      liveStreamingId: widget.liveUser.liveRoomId ?? '',
      userId: session.userId,
      host1Name: widget.liveUser.name ?? 'Host',
      host2Name: 'Opponent',
    );
  }

  void _startLuckyBannerTimer() {
    _luckyBannerTimer?.cancel();
    _luckyBannerTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _luckyBannerName = null;
          _luckyBannerImage = null;
          _luckyBannerCoins = 0;
        });
      }
    });
  }

  void _openLuckyBag() {
    final session = context.read<SessionManager>();
    showLiveLuckyBagSheet(
      context,
      liveStreamingId: widget.liveUser.liveRoomId ?? widget.liveUser.id ?? '',
      userId: session.userId,
      isHost: true,
      roomType: 'video',
      roomName: widget.liveUser.roomName ?? widget.liveUser.name,
      hostUserId: widget.liveUser.userId,
      onCreated: (payload) {
        _luckyTreasureKey.currentState?.showFromPayload(payload);
        final totalCoins = (payload['totalCoins'] as num?)?.toInt() ?? 0;
        final bagCount = (payload['bagCount'] as num?)?.toInt() ?? 0;
        final name = payload['name']?.toString() ?? session.userName;
        if (!mounted) return;
        setState(
          () => _comments.add(
            _LiveComment(
              name: name,
              text:
                  'sent a $totalCoins diamonds Lucky Bag ($bagCount bags) — get ready to claim!',
              isGift: true,
              userImage: payload['senderImage']?.toString(),
              userId: session.userId,
            ),
          ),
        );
        _scrollToBottom();
      },
    );
  }

  void _openInboxShare() {
    final shareLink = '${Const.baseUrl}live/${widget.liveUser.liveRoomId}';
    showInboxChatListSheet(
      context,
      shareLink: shareLink,
      onSelected: (chatUser) {
        Fluttertoast.showToast(msg: 'Shared with ${chatUser.name ?? 'user'}');
      },
    );
  }

  void _openNativeShare() {
    final hostName = widget.liveUser.name ?? 'Host';
    final shareLink = '${Const.baseUrl}live/${widget.liveUser.liveRoomId}';
    Share.share('Come join $hostName\'s live stream! $shareLink');
  }

  void _openAdminList() {
    showAdminListSheet(
      context,
      admins: _admins,
      liveStreamingId: widget.liveUser.liveRoomId ?? '',
      liveUserMongoId: widget.liveUser.id ?? '',
    );
  }

  void _openFansRanking() {
    showFansRankingSheet(
      context,
      hostUserId: widget.liveUser.userId ?? '',
      localContributors: _topContributorController.top,
    );
  }

  void _openPkRoundHistory() {
    showPkRoundHistorySheet(
      context,
      history: _pkRoundHistory,
      host1Name: widget.liveUser.name ?? 'Host',
      host2Name: 'Opponent',
    );
  }

  void _openReactions() {
    showEmojiPickerSheet(
      context,
      onSelected: (emoji) {
        final session = context.read<SessionManager>();
        final user = session.getUser();
        SocketService.instance.emit(Const.eventSendReaction, {
          'liveStreamingId': widget.liveUser.liveRoomId,
          'userId': session.userId,
          'image': VideoUtil.getFullImageUrl(emoji.image),
          'name': emoji.name ?? '',
          'position': -1,
          'user': {
            'id': session.userId,
            'name': user?.name ?? '',
            'image': VideoUtil.getFullImageUrl(user?.image),
            'avatarFrame':
                user?.avatarFrameImage ?? user?.vipDetails?.profileFrameUrl,
          },
        });
      },
    );
  }

  Future<void> _switchCoHostCamera() => _switchCamera();

  Future<void> _openLiveHostsForPk() async {
    final session = context.read<SessionManager>();
    final myUserId = session.userId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'VS / PK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            final res = await ApiService.getRandomPkMatch(
                              myUserId,
                            );
                            final match =
                                res.users.isNotEmpty ? res.users.first : null;
                            if (match == null) {
                              Fluttertoast.showToast(
                                msg: 'No random match found',
                              );
                              return;
                            }
                            _sendPkRequest(match);
                          } catch (e, s) {
                            Log.e(_tag, 'randomPkMatch', e, s);
                            Fluttertoast.showToast(msg: 'Random match failed');
                          }
                        },
                        icon: const Icon(
                          Icons.shuffle,
                          color: Colors.white70,
                          size: 18,
                        ),
                        label: const Text(
                          'Random',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                FutureBuilder<lur.LiveUserRoot>(
                  future: ApiService.getLiveUsers(
                    userId: myUserId,
                    type: 'All',
                    country: 'All',
                  ),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 120,
                        child: Center(child: Preloader()),
                      );
                    }
                    if (snap.hasError) {
                      return const SizedBox(
                        height: 120,
                        child: Center(
                          child: Text(
                            'Failed to load',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      );
                    }
                    final users =
                        snap.data?.users
                            .where(
                              (u) =>
                                  !u.isAudio &&
                                  u.liveUserId != widget.liveUser.userId &&
                                  u.liveStreamingId !=
                                      widget.liveUser.liveRoomId &&
                                  (u.liveUserId ?? '').isNotEmpty &&
                                  (u.liveStreamingId ?? '').isNotEmpty,
                            )
                            .toList() ??
                        [];
                    if (users.isEmpty) {
                      return const SizedBox(
                        height: 120,
                        child: Center(
                          child: Text(
                            'No live hosts',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      );
                    }
                    return SizedBox(
                      height: 320,
                      child: ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (_, i) {
                          final u = users[i];
                          return ListTile(
                            leading: UserAvatar(
                              imageUrl: u.image,
                              size: 40,
                              isVIP: u.isVIP,
                            ),
                            title: Text(
                              u.name ?? 'Host',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${u.view} watching',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _sendPkRequest(u);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7E3FF2),
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: const Text('Invite'),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _answerVideoPkRequest(
    Map<String, dynamic> request, {
    required bool accepted,
  }) {
    final host1Id =
        request['host1Id'] ?? request['requesterId'] ?? request['fromUserId'];
    final host2Id =
        request['host2Id'] ??
        widget.liveUser.userId ??
        context.read<SessionManager>().userId;
    final host1LiveId =
        request['host1LiveId'] ??
        request['host1LiveStreamingId'] ??
        request['fromRoomId'];
    final host2LiveId = request['host2LiveId'] ?? widget.liveUser.liveRoomId;
    final payload = <String, dynamic>{
      ...request,
      'host1Id': host1Id,
      'requesterId': host1Id,
      'toUserId': host1Id,
      'host2Id': host2Id,
      'targetHostId': host2Id,
      'host1LiveId': host1LiveId,
      'host1LiveStreamingId': host1LiveId,
      'host2LiveId': host2LiveId,
      'targetRoomId': host2LiveId,
      'toRoomId': host2LiveId,
      'liveStreamingId': host1LiveId,
      'host1Name': request['host1Name'],
      'host2Name': request['host2Name'] ?? widget.liveUser.name,
      'host1Image': request['host1Image'],
      'host2Image': request['host2Image'] ?? widget.liveUser.image,
      'host1Channel': request['host1Channel'],
      'host2Channel': resolvePkParticipantChannel(
        authoritative: widget.liveUser.channel,
        fallback: request['host2Channel']?.toString(),
      ),
      'host1AgoraId': request['host1AgoraId'] ?? request['host1AgoraUID'],
      'host1AgoraUID': request['host1AgoraUID'] ?? request['host1AgoraId'],
      'host2AgoraId': resolvePkParticipantUid(
        authoritative: widget.liveUser.agoraUID,
        fallback: parseInt(
          request['host2AgoraId'] ?? request['host2AgoraUID'],
          0,
        ),
      ),
      'host2AgoraUID': resolvePkParticipantUid(
        authoritative: widget.liveUser.agoraUID,
        fallback: parseInt(
          request['host2AgoraUID'] ?? request['host2AgoraId'],
          0,
        ),
      ),
      'isAccept': accepted,
      'ISACCEPT': accepted,
      'accepted': accepted,
    };
    for (final key in const [
      'host1Token',
      'host2Token',
      'host1SrcToken',
      'host2SrcToken',
      'host1RelayDestToken',
      'host2RelayDestToken',
    ]) {
      payload.remove(key);
    }
    _pendingPkRequest = Map<String, dynamic>.from(payload);
    SocketService.instance.emit(Const.eventPkRequestAnswer, payload);
  }

  Future<void> _openAcceptedVideoPk(
    Map<String, dynamic> payload, {
    bool startTimer = true,
    bool restartRelay = true,
  }) async {
    if (_openingPkBattle || !mounted) return;
    if (_isPkActive && _pkConfig != null && !restartRelay) {
      Log.d(_tag, 'PK already open, ignoring redundant open call');
      return;
    }
    _openingPkBattle = true;
    final myId =
        widget.liveUser.userId ?? context.read<SessionManager>().userId;
    final currentLiveId = widget.liveUser.liveRoomId ?? widget.liveUser.id;
    final nestedConfig = payload['pkConfig'];
    final resolvedPayload =
        nestedConfig is Map
            ? Map<String, dynamic>.from(nestedConfig)
            : Map<String, dynamic>.from(payload);
    if (nestedConfig is Map) {
      for (final entry in payload.entries) {
        if (entry.key != 'pkConfig') {
          resolvedPayload.putIfAbsent(entry.key, () => entry.value);
        }
      }
    }
    final pending = _pendingPkRequest;
    final host1Id =
        (resolvedPayload['host1Id'] ??
                pending?['host1Id'] ??
                pending?['requesterId'])
            ?.toString();
    final host2Id =
        (resolvedPayload['host2Id'] ??
                pending?['host2Id'] ??
                pending?['targetHostId'])
            ?.toString();
    if (pending != null) {
      for (final key in const [
        'host1Id',
        'host2Id',
        'host1LiveId',
        'host2LiveId',
        'host1Name',
        'host2Name',
        'host1Image',
        'host2Image',
        'host1Channel',
        'host2Channel',
        'host1AgoraId',
        'host1AgoraUID',
        'host2AgoraId',
        'host2AgoraUID',
      ]) {
        final value = pending[key];
        if (value != null && value.toString().isNotEmpty) {
          resolvedPayload.putIfAbsent(key, () => value);
        }
      }
    }
    if (widget.isHost && myId == host1Id) {
      resolvedPayload['host1AgoraUID'] = widget.liveUser.agoraUID;
      resolvedPayload['host1AgoraId'] = widget.liveUser.agoraUID;
      resolvedPayload['host1Channel'] = widget.liveUser.channel;
      final opponentUid =
          resolvedPayload['host2AgoraUID'] ??
          resolvedPayload['host2AgoraId'] ??
          pending?['host2AgoraUID'] ??
          pending?['host2AgoraId'];
      if (parseInt(opponentUid, 0) > 0) {
        resolvedPayload['host2AgoraUID'] = parseInt(opponentUid, 0);
        resolvedPayload['host2AgoraId'] = parseInt(opponentUid, 0);
      }
      resolvedPayload['host2Channel'] = resolvePkParticipantChannel(
        authoritative: resolvedPayload['host2Channel']?.toString(),
        fallback: pending?['host2Channel']?.toString(),
      );
    } else if (widget.isHost && myId == host2Id) {
      resolvedPayload['host2AgoraUID'] = widget.liveUser.agoraUID;
      resolvedPayload['host2AgoraId'] = widget.liveUser.agoraUID;
      resolvedPayload['host2Channel'] = widget.liveUser.channel;
    }
    try {
      final config = PkConfig.fromJson(resolvedPayload);
      // DEBUG: log all token-related fields from the resolved payload.
      Log.d(
        _tag,
        'PK open tokens: host1Token=${resolvedPayload['host1Token']} '
        'host2Token=${resolvedPayload['host2Token']} '
        'fromToken=${resolvedPayload['fromToken']} '
        'targetToken=${resolvedPayload['targetToken']} '
        'host1SrcToken=${resolvedPayload['host1SrcToken']} '
        'host2SrcToken=${resolvedPayload['host2SrcToken']} '
        'config.host1Token=${config.host1Token} '
        'config.host2Token=${config.host2Token} '
        'config.host1SrcToken=${config.host1SrcToken} '
        'config.host2SrcToken=${config.host2SrcToken} '
        'liveUser.token=${widget.liveUser.token}',
      );
      Log.d(
        _tag,
        'PK open resolvedPayload keys: ${resolvedPayload.keys.toList()}',
      );
      final isHost1 =
          widget.isHost
              ? config.host1Id == myId
              : config.host1LiveId == currentLiveId ||
                  config.host1Id == widget.liveUser.userId;
      final isHost2 =
          widget.isHost
              ? config.host2Id == myId
              : config.host2LiveId == currentLiveId ||
                  config.host2Id == widget.liveUser.userId;
      Log.d(
        _tag,
        'PK open: myId=$myId host1Id=${config.host1Id} host2Id=${config.host2Id} '
        'host1Channel=${config.host1Channel} host2Channel=${config.host2Channel} '
        'host1UID=${config.host1AgoraUID} host2UID=${config.host2AgoraUID} '
        'isHost1=$isHost1 isHost2=$isHost2 widget.isHost=${widget.isHost}',
      );
      final complete =
          config.host1Id?.isNotEmpty == true &&
          config.host2Id?.isNotEmpty == true &&
          config.host1Channel?.isNotEmpty == true &&
          config.host2Channel?.isNotEmpty == true &&
          config.host1AgoraUID > 0 &&
          config.host2AgoraUID > 0;
      if (!complete || (!isHost1 && !isHost2)) {
        Fluttertoast.showToast(msg: 'PK connection data is incomplete');
        return;
      }
      final perspectiveScores = pkScoresFromLocalPerspective(
        localIsHost1: isHost1,
        localScore: config.localRank,
        remoteScore: config.remoteRank,
      );
      final initialScores = resolvePkScores(
        payload: resolvedPayload,
        currentHost1: perspectiveScores.host1,
        currentHost2: perspectiveScores.host2,
        localIsHost1: isHost1,
      );
      final opponentUid = isHost1 ? config.host2AgoraUID : config.host1AgoraUID;
      final shouldRebind =
          restartRelay || _pkRemoteAgoraUid != opponentUid || _pkConfig == null;
      if (!mounted) return;
      setState(() {
        _isPkActive = true;
        _pkConfig = config;
        _pkIsHost1 = isHost1;
        _pkRemoteAgoraUid = opponentUid;
        if (shouldRebind) {
          _pkRemoteController = null;
          _pkRelayRetryCount = 0;
        }
        _pkScoreHost1 = initialScores.host1;
        _pkScoreHost2 = initialScores.host2;
        _pkSecondsLeft =
            config.durationSeconds > 0 ? config.durationSeconds : 300;
        _pkWinner = -1;
        _pkRoundCount = max(_pkRoundCount, config.pkRoundCount);
      });
      // Start media relay from the existing engine — no separate route.
      if (shouldRebind) _startPkVideoRetry(opponentUid);
      if (widget.isHost && restartRelay) {
        await _startPkMediaRelay();
      } else if (!widget.isHost) {
        // Audience: setup remote video for the opponent host (relayed into our channel).
        // The host we're watching is already bound to _remoteController.
        // The opponent comes through the host's relay.
        try {
          await Future.wait([
            _engine.setRemoteVideoStreamType(
              uid: config.host1AgoraUID,
              streamType: VideoStreamType.videoStreamLow,
            ),
            _engine.setRemoteVideoStreamType(
              uid: config.host2AgoraUID,
              streamType: VideoStreamType.videoStreamLow,
            ),
          ]);
        } catch (e) {
          Log.d(_tag, 'PK audience stream quality setup failed: $e');
        }
      }
      if (startTimer) _startPkTimer();
    } catch (e, s) {
      Log.e(_tag, 'Failed to open PK battle', e, s);
      Fluttertoast.showToast(msg: 'Could not connect PK battle');
    } finally {
      _openingPkBattle = false;
    }
  }

  Future<void> _startPkMediaRelay() async {
    final config = _pkConfig;
    if (config == null || !_engineReady) return;
    final myChannel = _pkIsHost1 ? config.host1Channel : config.host2Channel;
    final otherChannel = _pkIsHost1 ? config.host2Channel : config.host1Channel;
    final myUid = _pkIsHost1 ? config.host1AgoraUID : config.host2AgoraUID;

    // --- Match native startMediaRelay2 exactly ---
    // Source token: prefer PK-specific src token, fall back to liveUser token, then pkConfig token.
    final int srcUid =
        (widget.liveUser.agoraUID > 0) ? widget.liveUser.agoraUID : myUid;
    // Dest UID = MY own UID (I appear in the opponent's channel with my UID).
    final int destUid = srcUid;
    String srcToken =
        _pkIsHost1
            ? (config.host1SrcToken ?? '')
            : (config.host2SrcToken ?? '');
    if (srcToken.isEmpty) {
      srcToken = widget.liveUser.token ?? '';
      Log.d(_tag, 'PK relay: srcToken fallback to liveUser token');
    }
    if (srcToken.isEmpty) {
      srcToken =
          _pkIsHost1 ? (config.host1Token ?? '') : (config.host2Token ?? '');
      Log.d(_tag, 'PK relay: srcToken fallback to pkConfig token');
    }
    // Dest token: prefer relay-specific dest tokens (host2RelayDestToken for
    // Host1 means "token for Host1's UID in Host2's channel"). Fall back to
    // legacy host1Token / host2Token mapping for older backend payloads.
    String destToken = resolvePkRelayDestinationToken(
      localIsHost1: _pkIsHost1,
      host1Token: config.host1Token,
      host2Token: config.host2Token,
      host1RelayDestToken: config.host1RelayDestToken,
      host2RelayDestToken: config.host2RelayDestToken,
    );

    // OVERRIDE backend tokens with locally generated 007-format tokens.
    // Agora Flutter docs specify the source relay token must be generated for
    // uid 0 (the SDK fills in the current publisher's UID automatically).
    // The destination token must be for the UID that appears in the opponent's
    // channel (the current host's UID). The backend 006 tokens do not work with
    // the Flutter media-relay API, so generate locally when possible.
    String? localSrcToken;
    if (myChannel?.isNotEmpty == true &&
        _agoraAppCertificate != null &&
        _agoraAppCertificate!.isNotEmpty) {
      try {
        localSrcToken = _generateAgoraToken(
          appId: _agoraAppId,
          appCert: _agoraAppCertificate,
          channel: myChannel!,
          uid: 0,
        );
        Log.d(_tag, 'PK relay: srcToken generated locally for uid=0');
      } catch (e) {
        Log.e(_tag, 'PK relay: srcToken generation failed', e);
      }
    }
    final String? localDestToken =
        (otherChannel?.isNotEmpty == true && _agoraAppCertificate != null && _agoraAppCertificate!.isNotEmpty)
            ? _generateAgoraToken(
                appId: _agoraAppId,
                appCert: _agoraAppCertificate,
                channel: otherChannel!,
                uid: destUid,
              )
            : null;

    if (localSrcToken?.isNotEmpty == true) {
      srcToken = localSrcToken!;
      Log.d(_tag, 'PK relay: srcToken overridden with locally generated 007 token (uid=0)');
    } else {
      Log.d(_tag, 'PK relay: srcToken using backend token (local gen failed)');
    }
    if (localDestToken?.isNotEmpty == true) {
      destToken = localDestToken!;
      Log.d(_tag, 'PK relay: destToken overridden with locally generated 007 token');
    } else {
      Log.d(_tag, 'PK relay: destToken using backend token (local gen failed)');
    }

    // Log token source for diagnosis.
    Log.d(
      _tag,
      'PK relay token prefix: src=${srcToken.length > 10 ? srcToken.substring(0, 10) : srcToken} '
      'dest=${destToken.length > 10 ? destToken.substring(0, 10) : destToken}',
    );

    // Log source/dest token app IDs for diagnostic without exposing full token.
    if (srcToken.length >= 3) {
      Log.d(_tag, 'PK relay source token version: ${srcToken.substring(0, 3)}');
    }
    if (destToken.length >= 3) {
      Log.d(_tag, 'PK relay dest token version: ${destToken.substring(0, 3)}');
    }
    Log.d(_tag, 'PK relay appId used for token gen: $_agoraAppId');

    Log.d(
      _tag,
      'PK relay: iAmHost1=$_pkIsHost1 src=$myChannel srcUid=$srcUid dest=$otherChannel destUid=$destUid srcTokenLen=${srcToken.length} destTokenLen=${destToken.length}',
    );

    if (myChannel == null ||
        myChannel.isEmpty ||
        otherChannel == null ||
        otherChannel.isEmpty ||
        otherChannel == myChannel ||
        myUid <= 0 ||
        srcToken.isEmpty ||
        destToken.isEmpty) {
      Log.e(
        _tag,
        'PK relay config incomplete: source=$myChannel destination=$otherChannel uid=$myUid srcToken=${srcToken.isNotEmpty} destToken=${destToken.isNotEmpty}',
      );
      return;
    }

    // Update channel media options — ensure publishing camera + mic (native setUpPkBehaviour).
    try {
      await _engine.updateChannelMediaOptions(
        const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
      // Enable dual stream mode for audience low-quality fallback.
      await _engine.enableDualStreamMode(enabled: true);
    } catch (e) {
      Log.e(_tag, 'PK relay: updateChannelMediaOptions failed', e);
    }

    // Per Agora Flutter docs, source relay info uses uid 0 and the source
    // token must be generated for uid 0. The destination token/uid must
    // correspond to the UID the opponent expects (current host's UID).
    final relayConfig = ChannelMediaRelayConfiguration(
      srcInfo: ChannelMediaInfo(
        channelName: myChannel,
        token: srcToken,
        uid: 0,
      ),
      destInfos: [
        ChannelMediaInfo(
          channelName: otherChannel,
          token: destToken,
          uid: destUid,
        ),
      ],
      destCount: 1,
    );

    // Always stop existing relay first, then wait 500ms, then start.
    // Use the Ex API with explicit source connection so the relay server
    // knows exactly which source channel/uid to publish.
    if (_pkRelayStarting) {
      Log.d(_tag, 'PK relay: already starting, skipping duplicate call');
      return;
    }
    _pkRelayStarting = true;
    final srcConnection = RtcConnection(channelId: myChannel, localUid: srcUid);
    try {
      await _engine.stopChannelMediaRelayEx(srcConnection);
      _pkRelayStarted = false;
      Log.d(_tag, 'PK relay: stopChannelMediaRelayEx done (pre-start)');
    } catch (e) {
      _pkRelayStarted = false;
      Log.d(_tag, 'PK relay: stopChannelMediaRelayEx noop (expected on first start): $e');
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    try {
      await _engine.startOrUpdateChannelMediaRelayEx(
        configuration: relayConfig,
        connection: srcConnection,
      );
      Log.d(_tag, 'PK relay: startOrUpdateChannelMediaRelayEx done');
      // Set remote video stream type for opponent.
      final otherUid = _pkIsHost1 ? config.host2AgoraUID : config.host1AgoraUID;
      if (otherUid > 0) {
        try {
          await _engine.setRemoteVideoStreamType(
            uid: otherUid,
            streamType: VideoStreamType.videoStreamHigh,
          );
        } catch (e) {
          Log.d(_tag, 'PK relay: setRemoteVideoStreamType: $e');
        }
        // Start retrying remote video setup for opponent.
        _startPkVideoRetry(otherUid);
      }
    } catch (e, s) {
      _pkRelayStarted = false;
      Log.e(_tag, 'PK relay: startOrUpdateChannelMediaRelay failed', e, s);
    } finally {
      _pkRelayStarting = false;
    }
  }

  /// Periodically retry remote video setup for the opponent UID.
  /// Matches native startPkVideoRetry — retries until video is decoded or PK ends.
  void _startPkVideoRetry(int remoteUid) {
    _pkVideoRetryTimer?.cancel();
    _pkVideoRetryCount = 0;

    void bindController() {
      if (!mounted || _pkRemoteController != null) return;
      final config = _pkConfig;
      if (config == null) return;
      final myChannel = _pkIsHost1 ? config.host1Channel : config.host2Channel;
      if (myChannel?.isNotEmpty != true) return;
      setState(() {
        _pkRemoteController = VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(
            uid: remoteUid,
            renderMode: RenderModeType.renderModeHidden,
            mirrorMode: VideoMirrorModeType.videoMirrorModeDisabled,
          ),
          connection: RtcConnection(channelId: myChannel),
          useFlutterTexture: true,
          useAndroidSurfaceView: false,
        );
      });
    }

    bindController();
    _pkVideoRetryTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || !_isPkActive || _pkRemoteController != null) {
        timer.cancel();
        return;
      }
      _pkVideoRetryCount++;
      Log.d(
        _tag,
        'PK video retry $_pkVideoRetryCount/$_pkVideoMaxRetries for uid=$remoteUid',
      );
      bindController();
      if (_pkVideoRetryCount >= _pkVideoMaxRetries) {
        timer.cancel();
        Log.e(_tag, 'PK video retry: max retries reached for uid=$remoteUid');
      }
    });
  }

  void _startPkTimer() {
    _pkTimer?.cancel();
    _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isPkActive) {
        timer.cancel();
        return;
      }
      if (_pkSecondsLeft > 1) {
        setState(() => _pkSecondsLeft--);
        return;
      }
      timer.cancel();
      setState(() => _pkSecondsLeft = 0);
      _handlePkTimerFinished();
    });
  }

  void _handlePkTimerFinished() {
    final config = _pkConfig;
    if (config == null || !mounted) return;
    if (_isPkPunishment) {
      setState(() {
        _isPkPunishment = false;
        _pkPunishmentTask = null;
      });
      if (widget.isHost && _pkIsHost1) {
        SocketService.instance.emit(Const.eventPkPunishmentRound, {
          'host1Id': config.host1Id,
          'host2Id': config.host2Id,
          'host1LiveId': config.host1LiveId,
          'host2LiveId': config.host2LiveId,
          'host1Score': _pkScoreHost1,
          'host2Score': _pkScoreHost2,
          'winner': _pkWinner,
          'isPKPunishment': false,
          'showStartButton': true,
          'pkRoundCount': _pkRoundCount,
        });
      }
      return;
    }

    final winner = pkWinnerFromScores(
      host1Score: _pkScoreHost1,
      host2Score: _pkScoreHost2,
    );
    final round = _pkRoundCount + 1;
    _recordPkRound(round, _pkScoreHost1, _pkScoreHost2, winner);
    setState(() {
      _pkWinner = winner;
      _pkRoundCount = round;
      _isPkPunishment = winner != 0;
      _pkPunishmentTask =
          winner == 0 ? null : PkPunishmentTasks.getTaskForRound(round);
      if (winner != 0) {
        final duration = config.punishmentDurationSeconds;
        _pkSecondsLeft = duration > 0 ? duration : 60;
      }
    });
    if (widget.isHost && _pkIsHost1) {
      SocketService.instance.emit(Const.eventPkPunishmentRound, {
        'host1Id': config.host1Id,
        'host2Id': config.host2Id,
        'host1LiveId': config.host1LiveId,
        'host2LiveId': config.host2LiveId,
        'host1Score': _pkScoreHost1,
        'host2Score': _pkScoreHost2,
        'winner': winner,
        'isPKPunishment': winner != 0,
        'showStartButton': winner == 0,
        'pkRoundCount': round,
      });
    }
    if (winner != 0) _startPkTimer();
  }

  void _handlePkPunishmentRound(Map<String, dynamic> map) {
    final nested =
        map['pkPunishment'] is Map
            ? Map<String, dynamic>.from(map['pkPunishment'] as Map)
            : <String, dynamic>{};
    final scores = _resolveIncomingPkScores(map);
    var winner = parseInt(map['winner'], -1);
    final scoreWinner = pkWinnerFromScores(
      host1Score: scores.host1,
      host2Score: scores.host2,
    );
    if (winner < 0 || (winner == 0 && scoreWinner != 0)) winner = scoreWinner;
    final round = parseInt(
      map['pkRoundCount'] ?? map['PK_ROUND_COUNT'],
      max(1, _pkRoundCount),
    );
    final showStartButton = parseBool(map['showStartButton']);
    final isPunishment =
        !showStartButton &&
        (parseBool(
              map['isPKPunishment'] ??
                  map['isPkPunishment'] ??
                  map['isPunishment'],
            ) ||
            parseBool(nested['isPKPunishment']));
    final duration = parseInt(
      map['pkPunishmentDuration'] ??
          map['punishmentDurationSeconds'] ??
          map['pkPunishmentEndTime'],
      _pkConfig?.punishmentDurationSeconds ?? 0,
    );
    final taskValue =
        parseString(map['punishmentTask'] ?? map['task'])?.trim() ?? '';
    final task =
        taskValue.isNotEmpty
            ? taskValue
            : PkPunishmentTasks.getTaskForRound(round);

    _recordPkRound(round, scores.host1, scores.host2, winner);
    _pkTimer?.cancel();
    setState(() {
      _pkScoreHost1 = scores.host1;
      _pkScoreHost2 = scores.host2;
      _pkWinner = winner;
      _pkRoundCount = round;
      _isPkPunishment = isPunishment;
      _pkPunishmentTask = isPunishment ? task : null;
      _pkSecondsLeft = isPunishment ? (duration > 0 ? duration : 60) : 0;
    });
    if (isPunishment) {
      Fluttertoast.showToast(
        msg: 'Punishment: $task',
        toastLength: Toast.LENGTH_LONG,
      );
      _startPkTimer();
    }
  }

  /// Resolves which PK host (host1 or host2) a gift event is for.
  /// Returns the canonical receiver user ID, or null if the event is not
  /// addressable to either PK host.
  String? _resolvePkGiftReceiver(Map<String, dynamic>? map) {
    final config = _pkConfig;
    if (config == null) return null;

    final liveId = widget.liveUser.liveRoomId;
    final roomId =
        map?['liveStreamingId']?.toString() ??
        map?['receiverLiveStreamingId']?.toString() ??
        map?['toRoomId']?.toString() ??
        map?['targetRoomId']?.toString() ??
        map?['roomId']?.toString() ??
        '';

    // If the payload says which room it is for, only update when it is THIS
    // room. This prevents the cross-room echo from inflating the wrong host.
    if (roomId.isNotEmpty && liveId != null && liveId.isNotEmpty) {
      if (roomId != liveId) return null;
      return widget.liveUser.userId;
    }

    // Try to match the explicit receiver against one of the PK hosts.
    final receiverId =
        map?['receiverId']?.toString() ??
        map?['receiverUserId']?.toString() ??
        map?['toUserId']?.toString() ??
        map?['receiverUser']?['_id']?.toString() ??
        '';
    if (receiverId.isNotEmpty) {
      if (receiverId == config.host1Id ||
          receiverId == config.host1LiveId) {
        return config.host1Id;
      }
      if (receiverId == config.host2Id ||
          receiverId == config.host2LiveId) {
        return config.host2Id;
      }
      // Receiver is not one of the PK hosts — ignore.
      return null;
    }

    // Try to match by receiver name.
    final receiverName =
        map?['receiverName']?.toString() ??
        map?['receiverUserName']?.toString() ??
        map?['toName']?.toString() ??
        '';
    final h1Name = config.host1Name?.toLowerCase().trim();
    final h2Name = config.host2Name?.toLowerCase().trim();
    if (receiverName.isNotEmpty) {
      final lower = receiverName.toLowerCase().trim();
      if (h1Name != null && h1Name.isNotEmpty && lower == h1Name) {
        return config.host1Id;
      }
      if (h2Name != null && h2Name.isNotEmpty && lower == h2Name) {
        return config.host2Id;
      }
      // Receiver name doesn't match either PK host — ignore.
      return null;
    }

    // No routing info at all — this is a legacy room-wide event. Only treat
    // it as being for this room's host if we are the host of THIS room. The
    // cross-room echo will be ignored here and synced via eventPkScoreUpdate.
    if (widget.isHost) {
      Log.d(
        _tag,
        'PK gift receiver unknown — assuming local host ${widget.liveUser.userId}',
      );
      return widget.liveUser.userId;
    }
    return null;
  }

  void _applyOptimisticPkGiftScore(String receiverId, int coins) {
    final config = _pkConfig;
    if (config == null ||
        !_isPkActive ||
        _isPkPunishment ||
        _pkWinner >= 0 ||
        coins <= 0) {
      return;
    }
    final isHost1 =
        receiverId == config.host1Id || receiverId == config.host1LiveId;
    final isHost2 =
        receiverId == config.host2Id || receiverId == config.host2LiveId;
    if (!isHost1 && !isHost2) return;
    setState(() {
      if (isHost1) {
        _pkScoreHost1 += coins;
      } else {
        _pkScoreHost2 += coins;
      }
    });
    // Broadcast the updated scores to the PK partner and viewers.
    _emitPkScoreUpdate();
  }

  /// Resolves incoming PK score update payloads to this device's local
  /// perspective. Each device considers itself host1 in its own config, so
  /// when the opponent emits a score update, their host1 is our host2. This
  /// method compares the incoming host1Id with the local config's host1Id
  /// and swaps scores if needed.
  ({int host1, int host2}) _resolveIncomingPkScores(Map<String, dynamic> map) {
    final config = _pkConfig;
    int? resolve(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        final parsed =
            value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
        if (parsed != null && parsed >= 0) return parsed;
      }
      return null;
    }

    final incomingH1 = resolve(const ['host1Score', 'score1', 'host1Rank']);
    final incomingH2 = resolve(const ['host2Score', 'score2', 'host2Rank']);
    if (incomingH1 == null && incomingH2 == null) {
      return (host1: _pkScoreHost1, host2: _pkScoreHost2);
    }

    final h1v = incomingH1 ?? _pkScoreHost1;
    final h2v = incomingH2 ?? _pkScoreHost2;

    // Check if the incoming host1Id matches our local config's host1Id.
    // If not, the scores are from the opponent's perspective and need swapping.
    final incomingHost1Id = map['host1Id']?.toString() ?? '';
    final localHost1Id = config?.host1Id ?? '';
    final incomingHost1LiveId = map['host1LiveId']?.toString() ?? '';
    final localHost1LiveId = config?.host1LiveId ?? '';

    final samePerspective = (incomingHost1Id.isNotEmpty && incomingHost1Id == localHost1Id) ||
        (incomingHost1LiveId.isNotEmpty && incomingHost1LiveId == localHost1LiveId);

    if (samePerspective) {
      return (host1: h1v, host2: h2v);
    }
    // Scores are from opponent's perspective — swap them.
    Log.d(_tag, 'PK scores swapped: incoming h1=$h1v h2=$h2v -> local h1=$h2v h2=$h1v');
    return (host1: h2v, host2: h1v);
  }

  void _emitPkScoreUpdate() {
    final config = _pkConfig;
    if (config == null) return;
    try {
      SocketService.instance.emit(Const.eventPkScoreUpdate, {
        'pkId': config.pkId,
        'host1Id': config.host1Id,
        'host2Id': config.host2Id,
        'host1LiveId': config.host1LiveId,
        'host2LiveId': config.host2LiveId,
        'host1Score': _pkScoreHost1,
        'host2Score': _pkScoreHost2,
        'liveStreamingId': widget.liveUser.liveRoomId,
        'targetRoomId': _pkIsHost1 ? config.host2LiveId : config.host1LiveId,
        'toRoomId': _pkIsHost1 ? config.host2LiveId : config.host1LiveId,
        'userId': context.read<SessionManager>().userId,
      });
      Log.d(_tag, 'PK score update emitted: h1=$_pkScoreHost1 h2=$_pkScoreHost2');
    } catch (e) {
      Log.e(_tag, 'PK score update emit failed', e);
    }
  }

  void _recordPkRound(int round, int host1Score, int host2Score, int winner) {
    final exists = _pkRoundHistory.any(
      (result) =>
          result.roundNumber == round &&
          result.host1Score == host1Score &&
          result.host2Score == host2Score,
    );
    if (exists) return;
    _pkRoundHistory.add(
      PkRoundResult(
        roundNumber: round,
        host1Score: host1Score,
        host2Score: host2Score,
        winner: winner,
        host1Name: _pkConfig?.host1Name,
        host2Name: _pkConfig?.host2Name,
      ),
    );
  }

  void _resetPkState() {
    if (!mounted) return;
    setState(() {
      _isPkActive = false;
      _pkRemoteAgoraUid = null;
      _isPkPunishment = false;
      _pkPunishmentTask = null;
      _pkConfig = null;
      _pendingPkRequest = null;
      _pkRemoteController = null;
      _pkSecondsLeft = 0;
      _pkWinner = -1;
      _pkRoundCount = 0;
      _pkVideoRetryCount = 0;
      _pkRelayRetryCount = 0;
      _pkRelayStarted = false;
    });
    _pkTimer?.cancel();
    _pkTimer = null;
    _pkVideoRetryTimer?.cancel();
    _pkVideoRetryTimer = null;
    _pkRelayRetryTimer?.cancel();
    _pkRelayRetryTimer = null;
    _pkResultResetTimer?.cancel();
    _pkResultResetTimer = null;
    unawaited(_stopPkMediaRelay());
    _pkSupporters.clear();
    _pkSupporterAnnounced.clear();
    _multiplier.deactivate();
  }

  Future<void> _stopPkMediaRelay() async {
    _pkTimer?.cancel();
    _pkTimer = null;
    _pkVideoRetryTimer?.cancel();
    _pkVideoRetryTimer = null;
    _pkRelayRetryTimer?.cancel();
    _pkRelayRetryTimer = null;
    _pkVideoRetryCount = 0;
    _pkRelayRetryCount = 0;
    if (!_pkRelayStarted) return;
    final config = _pkConfig;
    final myChannel = _pkIsHost1 ? config?.host1Channel : config?.host2Channel;
    final srcUid = _pkIsHost1 ? config?.host1AgoraUID : config?.host2AgoraUID;
    try {
      if (myChannel != null && myChannel.isNotEmpty && (srcUid ?? 0) > 0) {
        await _engine.stopChannelMediaRelayEx(
          RtcConnection(channelId: myChannel, localUid: srcUid!),
        );
        Log.d(_tag, 'PK relay: stopped on PK end');
      } else {
        await _engine.stopChannelMediaRelay();
        Log.d(_tag, 'PK relay: stopped on PK end (no connection)');
      }
    } catch (_) {
      Log.d(_tag, 'PK relay: stop on PK end failed');
    } finally {
      _pkRelayStarted = false;
      _pkRelayStarting = false;
    }
  }

  void _sendPkRequest(lur.LiveUser opponent) {
    final host1Id =
        widget.liveUser.userId ?? context.read<SessionManager>().userId;
    final host1LiveId = widget.liveUser.liveRoomId ?? '';
    final host2Id = opponent.liveUserId ?? '';
    final host2LiveId = opponent.liveStreamingId ?? '';
    if (host1Id.isEmpty ||
        host1LiveId.isEmpty ||
        host2Id.isEmpty ||
        host2LiveId.isEmpty) {
      Fluttertoast.showToast(msg: 'PK host information is incomplete');
      return;
    }
    final payload = {
      'host1Id': host1Id,
      'requesterId': host1Id,
      'fromUserId': host1Id,
      'host1LiveId': host1LiveId,
      'host1LiveStreamingId': host1LiveId,
      'fromRoomId': host1LiveId,
      'host1Image': widget.liveUser.image,
      'host1Name': widget.liveUser.name,
      'host1AgoraId': widget.liveUser.agoraUID,
      'host1AgoraUID': widget.liveUser.agoraUID,
      'host1Channel': widget.liveUser.channel,
      'host2Id': host2Id,
      'targetHostId': host2Id,
      'toUserId': host2Id,
      'host2LiveId': host2LiveId,
      'targetRoomId': host2LiveId,
      'toRoomId': host2LiveId,
      'liveStreamingId': host1LiveId,
      'host2Image': opponent.image,
      'host2Name': opponent.name,
      'host2AgoraId': opponent.agoraUID,
      'host2AgoraUID': opponent.agoraUID,
      'host2Channel': opponent.channel,
    };
    _pendingPkRequest = Map<String, dynamic>.from(payload);
    SocketService.instance.emit(Const.eventPkRequest, payload);
    Fluttertoast.showToast(msg: 'PK invite sent to ${opponent.name ?? 'host'}');
  }

  void _handleLiveEndedByHost({String? reason, bool isAdmin = false}) {
    if (_isRoomEnded) return;
    _isRoomEnded = true;

    Log.d(_tag, '=== VIDEO LIVE ENDED BY ${isAdmin ? 'ADMIN' : 'HOST'} ===');

    try {
      context.read<MinimizedLiveProvider>().clear();
    } catch (_) {}

    _durationTimer?.cancel();
    _liveTimeTimer?.cancel();
    _videoStartFallbackTimer?.cancel();
    _fromChatBannerTimer?.cancel();
    _reactionTimer?.cancel();
    _gift3DReactionTimer?.cancel();
    _reconnectSub?.cancel();

    try {
      _coWatchController?.dispose();
    } catch (_) {}

    try {
      _musicController?.stop();
    } catch (_) {}

    try {
      _engine.leaveChannel();
    } catch (_) {}

    if (mounted) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((r) => r.isFirst || r.settings.name == AppRoutes.liveRoom);
    }

    Fluttertoast.showToast(
      msg:
          reason ??
          (isAdmin
              ? 'Live stream ended by admin'
              : 'Live stream ended by host'),
      backgroundColor: Colors.red,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_LONG,
    );

    if (mounted) {
      if (widget.isHost) {
        context.goNamed(AppRoutes.main);
      } else {
        context.goNamed(
          AppRoutes.guestProfile,
          extra: {'userId': widget.liveUser.userId ?? ''},
        );
      }
    }
  }

  Future<void> _endLive({bool confirm = true}) async {
    if (confirm) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A2E),
              title: const Text(
                'End Live?',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Are you sure you want to end this live stream? All viewers will be removed immediately.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'End Live',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;

    if (_isRoomEnded) return;
    _isRoomEnded = true;

    final session = context.read<SessionManager>();
    final liveId = widget.liveUser.liveRoomId ?? widget.liveUser.id ?? '';
    final myUserId = session.userId;

    // Flush the latest duration / earnings to the local cache before ending,
    // so the Host Center shows the progress even if the backend is 404/empty.
    _syncHostCache(myUserId);

    final minimized = context.read<MinimizedLiveProvider>();
    minimized.clear();

    _durationTimer?.cancel();
    _liveTimeTimer?.cancel();
    _videoStartFallbackTimer?.cancel();
    _fromChatBannerTimer?.cancel();
    _reactionTimer?.cancel();
    _gift3DReactionTimer?.cancel();
    _reconnectSub?.cancel();

    try {
      _coWatchController?.dispose();
    } catch (_) {}

    try {
      _musicController?.stop();
    } catch (_) {}

    try {
      _engine.leaveChannel();
    } catch (_) {}

    // If PK was active, emit pkEnd
    if (_isPkActive) {
      try {
        SocketService.instance.emit(Const.eventPkEnd, {
          'liveStreamingId': liveId,
          'winner': 0,
          'reason': 'host_ended',
        });
      } catch (_) {}
    }

    // Broadcast socket end events to all viewers
    try {
      final endPayload = {
        'liveStreamingId': liveId,
        'liveRoom': liveId,
        'liveHostRoom': myUserId,
        'liveUserId': myUserId,
        'userId': myUserId,
        'time': _durationSeconds,
        'reason': 'Live stream ended by host',
      };
      SocketService.instance.emit(Const.eventLiveHostEnd, endPayload);
      SocketService.instance.emit(Const.liveEndByEnd, endPayload);
      SocketService.instance.emit(Const.eventEndLive, endPayload);
      SocketService.instance.emit('liveEnd', endPayload);
      SocketService.instance.emit(Const.eventLessView, {
        'liveStreamingId': liveId,
        'userId': myUserId,
      });
    } catch (_) {}

    // Call backend APIs to end live stream
    try {
      await Future.wait([
        ApiService.endLiveStream(liveId).catchError((e) {
          Log.w(_tag, 'endLiveStream err: $e');
          return RestResponse(status: false);
        }),
        ApiService.userHostLiveEnd(myUserId, liveId).catchError((e) {
          Log.w(_tag, 'userHostLiveEnd err: $e');
          return RestResponse(status: false);
        }),
      ]);
    } catch (e, s) {
      Log.e(_tag, 'endLive API failed', e, s);
    }

    // Stop the background foreground service — the stream is over.
    AudioQualityService.stopForegroundService();

    if (mounted) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((r) => r.isFirst || r.settings.name == AppRoutes.liveRoom);
    }

    if (mounted) {
      context.goNamed(
        AppRoutes.liveSummary,
        extra: {
          'liveStreamingId': liveId,
          'durationSeconds': _durationSeconds,
          'liveType': 'video',
          'commentsCount': _clientCommentCount,
          'viewersCount': _viewerCount,
          'giftsCount': _giftStatsController.totalGiftCount,
          'fansCount': _clientFanCount,
          'beansCount': diamondsToBeans(
            _giftStatsController.hostEarnings,
            context.read<SessionManager>().getSetting(),
          ),
          'earnings': _giftStatsController.hostEarnings.toString(),
        },
      );
    }
  }

  void _showExitDialog() {
    if (widget.isHost) {
      _endLive();
      return;
    }
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.black87,
            title: const Text(
              'Leave Live?',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Do you want to exit or minimize?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _minimizeRoom();
                },
                child: const Text(
                  'Minimize',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _leaveRoom();
                },
                child: const Text('Exit', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  void _leaveRoom() {
    context.read<MinimizedLiveProvider>().clear();
    // Full Agora cleanup — leaveChannel + release to avoid memory leaks.
    _leaveAndRelease();
    // Notify backend that viewer left (single emit — no duplicate).
    try {
      final session = context.read<SessionManager>();
      SocketService.instance.emit(Const.eventLessView, {
        'liveStreamingId': widget.liveUser.liveRoomId ?? '',
        'userId': session.userId,
      });
    } catch (_) {}
    if (mounted) context.goNamed(AppRoutes.main);
  }

  void _minimizeRoom() {
    final minLive = context.read<MinimizedLiveProvider>();
    minLive.minimize(widget.liveUser, isHost: widget.isHost);
    if (mounted) context.goNamed(AppRoutes.main);
  }

  /// Play the gift receive chime, skipping the local user's own gift echo
  /// (the send chime already played in GiftBottomSheet). Mirrors native
  /// SVGA sound + a reliable default chime for all gift types.
  void _playGiftReceiveSound(GiftEvent event) {
    try {
      final myId = context.read<SessionManager>().userId;
      if (event.senderId.isNotEmpty && event.senderId == myId) return;
      GiftSoundService.instance.playReceiveSound();
    } catch (_) {}
  }

  /// Compute co-host box screen positions and trigger gift fly animation
  /// when a gift is sent to a specific co-host (not the host).
  void _maybeFlyGiftToCoHost(Map<String, dynamic> map, GiftEvent event) {
    if (!_effectSettings.showGiftEffect) return;
    try {
      final receiverId =
          (map['receiverUserId'] ?? map['receiverId'])?.toString() ?? '';
      if (receiverId.isEmpty || receiverId == widget.liveUser.userId)
        return; // gift to host — no fly

      // Find the co-host box key for this receiver.
      final key = _coHostBoxKeys[receiverId];
      if (key?.currentContext == null) return;

      final renderBox = key!.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;

      final pos = renderBox.localToGlobal(Offset.zero);
      final rect = Rect.fromLTWH(
        pos.dx,
        pos.dy,
        renderBox.size.width,
        renderBox.size.height,
      );

      _giftFlyKey.currentState?.flyGiftToSeats(
        giftImageUrl: event.giftImage,
        senderName: event.senderName,
        receiverName: event.receiverName,
        count: event.count,
        seatPositions: [
          0,
        ], // GiftFlyOverlay uses position index, but we override via setSeatPositions
      );

      // Override seat 0 position with the actual co-host box rect.
      _giftFlyKey.currentState?.setSeatPositions({0: rect});
    } catch (e) {
      Log.e(_tag, 'flyGiftToCoHost failed', e);
    }
  }

  void _emitAddView() {
    try {
      final session = context.read<SessionManager>();
      final user = session.getUser();
      // Ports native addLessView: send FULL profile so the backend can
      // construct a join comment with the user's avatar/name/VIP status
      // and broadcast it to all viewers. Without these fields the backend
      // has no profile data to show in the entry comment.
      SocketService.instance.emit(Const.eventAddView, {
        'liveStreamingId': widget.liveUser.liveRoomId ?? '',
        'liveUserMongoId': widget.liveUser.id ?? '',
        'userId': session.userId,
        'isVIP': user?.isVIP ?? false,
        'image': session.userImage,
        'name': session.userName,
        'userName': session.userName,
        'gender': user?.gender ?? '',
        'country': user?.country ?? '',
        'avatarFrame':
            user?.avatarFrameImage ?? user?.vipDetails?.profileFrameUrl ?? '',
        'isHost': false,
        'level': user?.level ?? '1',
        'Invisible': false,
        'liveType': 'video',
        'isVipProtected': user?.isVipProtected ?? false,
        'vipBadgeUrl': user?.vipDetails?.levelBadgeUrl ?? '',
        'entrySvga':
            user?.vipDetails?.entranceAnimationUrl ?? user?.svgaImage ?? '',
        if (user?.vipDetails != null) 'vipDetails': user!.vipDetails!.toJson(),
      });

      // Also broadcast a join comment directly (mirrors audio_room_screen).
      // This ensures other viewers see the entry profile even if the backend
      // doesn't construct a join comment from the addView event.
      // NOTE: never gate this on local effect settings — those control only
      // what THIS device displays, not what the room receives.
      SocketService.instance.emit(Const.eventComment, {
        'comment': '',
        'liveStreamingId': widget.liveUser.liveRoomId ?? '',
        'liveUserId': widget.liveUser.userId ?? '',
        'liveUserMongoId': widget.liveUser.id ?? '',
        'userId': session.userId,
        'isSystem': true,
        'isJoined': true,
        'type': 'comment',
        'imageUrl': '',
        'isVIP': user?.isVIP ?? false,
        'isVip': user?.isVIP ?? false,
        'name': session.userName,
        'image': session.userImage,
        'avatarFrame':
            user?.avatarFrameImage ?? user?.vipDetails?.profileFrameUrl ?? '',
        'vipBadgeUrl': user?.vipDetails?.levelBadgeUrl ?? '',
        'entrySvga':
            user?.vipDetails?.entranceAnimationUrl ?? user?.svgaImage ?? '',
        'country': user?.country ?? '',
        'level': user?.level ?? '1',
        if (user?.vipDetails != null) 'vipDetails': user!.vipDetails!.toJson(),
        'user': {
          'id': user?.id,
          'userId': session.userId,
          'name': user?.name ?? session.userName,
          'image': user?.image ?? session.userImage,
          'isVIP': user?.isVIP ?? false,
          'isVip': user?.isVIP ?? false,
          'avatarFrameImage':
              user?.avatarFrameImage ?? user?.vipDetails?.profileFrameUrl ?? '',
          if (user?.vipDetails != null)
            'vipDetails': user!.vipDetails!.toJson(),
        },
      });

      // Add current user to local viewers list immediately so count is correct.
      if (!widget.isHost) {
        final me = ViewerEntry(
          userId: session.userId,
          name: session.userName,
          image: session.userImage,
          isAdd: true,
        );
        if (!_viewers.any((v) => v.userId == me.userId)) {
          setState(() {
            _viewers.insert(0, me);
            _viewerCount = _viewers.length;
          });
        }
      }
    } catch (e) {
      Log.e(_tag, 'emitAddView failed', e);
    }
  }

  void _openGifts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => GiftBottomSheet(
            receiverId: widget.liveUser.userId ?? '',
            type: 'live',
            liveStreamingId: widget.liveUser.liveRoomId,
            isHost: widget.isHost,
            onGiftSent: ({
              required giftId,
              required giftName,
              required giftImage,
              svgaImage,
              giftType = 0,
              required count,
              required totalCoins,
            }) {
              final user = context.read<AuthProvider>().user;
              final session = context.read<SessionManager>();
              // Local score update only when this device is the host. Viewers
              // will see the authoritative update from the host's eventGift.
              if (widget.isHost) {
                _applyOptimisticPkGiftScore(
                  widget.liveUser.userId ?? '',
                  totalCoins,
                );
              }
              // 1. Add chat comment bubble for the gift.
              setState(
                () => _comments.add(
                  _LiveComment(
                    name: user?.name ?? session.userName,
                    text: '',
                    userId: session.userId,
                    isGift: true,
                    isMine: true,
                    userImage: VideoUtil.getFullImageUrl(
                      user?.image ?? session.userImage,
                    ),
                    giftImage: giftImage,
                    giftCount: count,
                    giftCoins: totalCoins,
                    familyName: user?.familyName ?? user?.family,
                    familyBadgeUrl: VideoUtil.getFullImageUrl(
                      user?.familyBadgeUrl ?? '',
                    ),
                  ),
                ),
              );
              _scrollToBottom();

              // 2. Show gift animation IMMEDIATELY on sender side — don't wait
              //    for backend socket echo. This fixes "gift animation not playing"
              //    when backend doesn't echo back to sender.
              final giftEvent = GiftEvent(
                giftId: giftId,
                giftName: giftName,
                giftImage: giftImage,
                svgaImage: svgaImage,
                giftType: giftType,
                coin: totalCoins ~/ count,
                senderName: user?.name ?? session.userName,
                senderId: session.userId,
                senderImage: VideoUtil.getFullImageUrl(
                  user?.image ?? session.userImage,
                ),
                receiverName: widget.liveUser.name ?? 'Host',
                count: count,
                timeStamp: DateTime.now().millisecondsSinceEpoch,
              );
              _giftStatsController.recordGift(giftEvent);
              _broadcastOverlayKey.currentState?.enqueue(
                BroadcastEvent(
                  type: BroadcastType.giftBroadcast,
                  title:
                      '${giftEvent.senderName} sent ${giftEvent.receiverName} a gift',
                  subtitle: '${giftEvent.giftName} x${giftEvent.count}',
                  avatar: giftEvent.senderImage,
                  image: giftEvent.giftImage,
                  rightText: 'Go',
                  durationSeconds: 5,
                ),
              );
              // Record local sender to top contributor leaderboard.
              _topContributorController.recordGift(
                userId: session.userId,
                name: user?.name ?? session.userName,
                avatar: VideoUtil.getFullImageUrl(
                  user?.image ?? session.userImage,
                ),
                coins: totalCoins,
                count: count,
              );

              // 3. Route to the correct overlay — BIG gifts go to the
              //    full-screen BigGiftOverlay, SMALL gifts go to the small
              //    GiftOverlay. Previously ALL gifts were added to
              //    _giftController AND big gifts also to _bigGiftController,
              //    causing both overlays to compete for the same SVGA
              //    decoder — neither played. Now we match the socket
              //    handler pattern (line ~2953) which correctly separates.
              if (_effectSettings.showGiftEffect) {
                if (_bigGiftController.isBigGift(giftEvent)) {
                  _bigGiftController.showBigGift(giftEvent);
                  if (_bigGiftController.shouldShake(giftEvent)) {
                    _shakeController.shake(
                      (totalCoins / 200).clamp(6.0, 18.0).toDouble(),
                    );
                  }
                } else {
                  _giftController.addGift(giftEvent);
                }
              }
            },
          ),
    );
  }

  void _openHandRaise() {
    if (widget.isHost) return;
    showPkHandRaiseSheet(
      context,
      isHost: widget.isHost,
      liveStreamingId: widget.liveUser.liveRoomId ?? '',
    );
  }

  void _openSubscription() {
    showSubscriptionSheet(
      context,
      hostUserId: widget.liveUser.userId ?? '',
      hostName: widget.liveUser.name ?? 'Host',
      hostImage: widget.liveUser.userImage ?? widget.liveUser.image,
    );
  }

  void _openGames() {
    final session = context.read<SessionManager>();
    showGameListSheet(context, games: session.getSetting()?.games);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitDialog();
      },
      child: Scaffold(
        // Keep the video/background Stack fixed in place when the keyboard opens.
        // Only the bottom bar (chat input) and comments overlay lift above the keyboard,
        // so the live screen does not shrink/shift. Matches native UnilivePro behavior.
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,
        body:
            !_engineReady
                ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Preloader(),
                      SizedBox(height: 12),
                      Text('Connecting to live room...'),
                    ],
                  ),
                )
                : MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  removeBottom: true,
                  child: ScreenShakeWidget(
                    controller: _shakeController,
                    child: Stack(
                      alignment: Alignment.topLeft,
                      children: [
                        const SizedBox.expand(),
                        if (!_isPkActive || _pkConfig == null)
                          _buildVideoArea(),
                        if (_isPkActive && _pkConfig != null) _buildPkOverlay(),
                        if (!_isPkActive) _buildCoHostGrid(),
                        _buildTopBar(),
                        _buildLuckyGiftBanner(),
                        if (_showFromChatBanner) _buildFromChatBanner(),
                        if (_hostOffline) _buildOfflineBanner(),
                        _buildCommentsOverlay(),
                        if (widget.isHost) _buildHostControls(),
                        if (widget.isHost && _joinRequests.isNotEmpty)
                          _buildJoinRequestFab(),
                        if (_isJoined) _buildCoHostControls(),
                        if (!widget.isHost && !_isJoined)
                          _buildAudienceRightControls(),
                        if (_isPkActive && _pkConfig == null)
                          _buildPkVoteBadges(),
                        if (_activeRoomPoll case final poll?)
                          Positioned(
                            left: 36,
                            right: 36,
                            bottom:
                                MediaQuery.of(context).viewPadding.bottom + 116,
                            child: RoomPollCard(
                              poll: poll,
                              onVote: _voteRoomPoll,
                            ),
                          ),
                        _buildBottomBar(),
                        VipEntryOverlay(key: _vipEntryKey),
                        CpEntryOverlay(key: _cpEntryKey),
                        RelationshipEntryOverlay(key: _relationshipEntryKey),
                        CpLevelUpOverlay(
                          cpLevelUpStream:
                              SocketHandlers.instance.cpLevelUpStream,
                          friendLevelUpStream:
                              SocketHandlers.instance.friendLevelUpStream,
                        ),
                        IntimacyFlyOverlay(key: _intimacyFlyKey),
                        GiftOverlay(
                          controller: _giftController,
                          comboBurstController: _comboBurstController,
                        ),
                        BigGiftOverlay(controller: _bigGiftController),
                        GiftFlyOverlay(key: _giftFlyKey),
                        GiftTrailOverlay(controller: _giftTrailController),
                        GiftComboBurstOverlay(
                          controller: _comboBurstController,
                          onShake: _shakeController.shake,
                        ),
                        LiveBroadcastOverlay(key: _broadcastOverlayKey),
                        CheerAnimationOverlay(key: _cheerKey),
                        if (_reactionImage != null || _reactionName != null)
                          _buildReactionOverlay(),
                        if (widget.isHost)
                          HostComplianceBanner(service: _presenceGuard),
                        if (_showGift3DReaction) _buildGift3DReactionBar(),
                        GiftPredictorBanner(
                          controller: _giftPredictor,
                          isVip:
                              context.read<SessionManager>().getUser()?.isVIP ??
                              false,
                          onQuickGift: _openGifts,
                        ),
                        if (!_isPkActive)
                          GiftingMultiplierBanner(controller: _multiplier),
                        // Bigo-parity overlays.
                        const ArStickerOverlay(),
                        const VirtualAvatarWidget(),
                        if (_coWatchController != null)
                          CoWatchWidget(controller: _coWatchController!),
                        VoiceEmojiOverlay(
                          key: _voiceEmojiKey,
                          localUserId: context.read<SessionManager>().userId,
                        ),
                        if (_showDrawAndGuess &&
                            _drawAndGuessController != null)
                          DrawAndGuessWidget(
                            controller: _drawAndGuessController!,
                          ),
                        LuckyTreasureBoxOverlay(
                          key: _luckyTreasureKey,
                          liveStreamingId:
                              widget.liveUser.liveRoomId ??
                              widget.liveUser.id ??
                              '',
                          userId: context.read<SessionManager>().userId,
                          isHost: widget.isHost,
                          roomType: 'video',
                          onClaimed: (payload) {
                            if (!mounted) return;
                            final coins =
                                (payload['coin'] as num?)?.toInt() ?? 0;
                            final name =
                                payload['name']?.toString() ?? 'Someone';
                            setState(
                              () => _comments.add(
                                _LiveComment(
                                  name: name,
                                  text:
                                      'won $coins diamonds from the lucky bag',
                                  isGift: true,
                                  userImage: payload['image']?.toString(),
                                  userId: payload['userId']?.toString() ?? '',
                                ),
                              ),
                            );
                            _scrollToBottom();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Positioned(
      top: MediaQuery.of(context).viewPadding.top + 60,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Host connection lost. Reconnecting...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _hostOffline = false),
              child: const Icon(Icons.close, color: Colors.white70, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  /// Highlight banner shown briefly when the viewer joined from a chat
  /// conversation. Mirrors native UnilivePro: lets the user know they came
  /// from a chat message and the host can see "joined from chat".
  Widget _buildFromChatBanner() {
    return Positioned(
      top: MediaQuery.of(context).viewPadding.top + 60,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: _showFromChatBanner ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 400),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7E3FF2), Color(0xFFE94057)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Joined from chat — ${widget.liveUser.name ?? 'host'} is live!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showFromChatBanner = false),
                child: const Icon(Icons.close, color: Colors.white70, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoArea() {
    return Positioned.fill(
      child: GestureDetector(
        // Tap on the video area closes the keyboard and returns to the action bar.
        onTap: () {
          if (_commentFocus.hasFocus) {
            _commentFocus.unfocus();
          }
        },
        child: Container(color: Colors.black, child: _buildVideoView()),
      ),
    );
  }

  Widget _buildVideoView() {
    // If background image is set, show it as base layer
    final activeBg = AnimatedRoomBackgroundService.instance.activeBackground;
    // Filter out SVGA URLs — they can't be decoded by CachedNetworkImageProvider.
    final bgUrl =
        (_backgroundImage ?? '').isNotEmpty
            ? VideoUtil.getFullImageUrl(_backgroundImage!)
            : '';
    final hasValidBg = bgUrl.isNotEmpty && !SvgaHelper.isSvgaUrl(bgUrl);
    final decor = BoxDecoration(
      image:
          hasValidBg
              ? DecorationImage(
                image: ResizeImage(
                  SafeImageProvider(bgUrl),
                  width: 720,
                  height: 1280,
                ),
                fit: BoxFit.cover,
              )
              : null,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors:
            hasValidBg
                ? [Colors.black, Colors.black87]
                : (activeBg?.gradientColors.isNotEmpty == true
                    ? activeBg!.gradientColors
                    : const [Colors.black, Colors.black87]),
      ),
    );

    if (widget.isHost && !_cameraEnabled) {
      return Container(
        decoration: decor,
        child: Center(
          child: UserAvatar(
            imageUrl: widget.liveUser.userImage ?? widget.liveUser.image,
            size: 112,
            isVIP: widget.liveUser.isVIP,
          ),
        ),
      );
    }
    if (!widget.isHost && _remoteHostCameraOff) {
      return Container(
        decoration: decor,
        child: Center(
          child: UserAvatar(
            imageUrl: widget.liveUser.userImage ?? widget.liveUser.image,
            size: 112,
            isVIP: widget.liveUser.isVIP,
          ),
        ),
      );
    }
    if (widget.isHost && _localController != null) {
      return RepaintBoundary(
        key: _videoBoundaryKey,
        child: Container(
          decoration: decor,
          child: SizedBox.expand(
            child: AgoraVideoView(
              controller: _localController!,
              onAgoraVideoViewCreated: _onAgoraVideoViewCreated,
            ),
          ),
        ),
      );
    } else if (_remoteUid != null && _remoteController != null) {
      return Container(
        decoration: decor,
        child: SizedBox.expand(
          child: AgoraVideoView(
            controller: _remoteController!,
            onAgoraVideoViewCreated: _onAgoraVideoViewCreated,
          ),
        ),
      );
    }
    return Container(
      decoration: decor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((widget.liveUser.userImage ?? '').isNotEmpty) ...[
              UserAvatar(
                imageUrl: widget.liveUser.userImage,
                size: 80,
                isVIP: widget.liveUser.isVIP,
              ),
              const SizedBox(height: 12),
            ] else
              const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
            const SizedBox(height: 8),
            Text(
              widget.liveUser.name ?? 'Host',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Waiting for host video...',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: Preloader(strokeWidth: 2, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoHostGrid() {
    if (_coHosts.isEmpty && _coHostControllers.isEmpty)
      return const SizedBox.shrink();
    // UnilivePro-style right-side co-host strip: small vertical boxes on the
    // right so the host video stays large and no guest ever covers the whole
    // screen (fixes the large overlay issue).
    final topPad = MediaQuery.of(context).viewPadding.top;
    final controlsTop =
        (topPad == 0 ? 12.0 : topPad + 6.0) + (widget.isHost ? 100.0 : 120.0);
    final stripTop = controlsTop + (widget.isHost || _isJoined ? 240.0 : 120.0);
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    const boxW = 90.0;
    const boxH = 120.0;

    // Collect all co-hosts: entries in _coHosts + any active remote controllers
    final displayedCoHosts = <Map<String, dynamic>>[];
    for (final h in _coHosts) {
      final userId = h['userId']?.toString();
      final agoraUid = _coHostAgoraUid(h);
      if (userId == widget.liveUser.userId ||
          (agoraUid > 0 && agoraUid == widget.liveUser.agoraUID)) {
        continue;
      }
      if (userId != null &&
          !displayedCoHosts.any((d) => d['userId'] == userId)) {
        displayedCoHosts.add(h);
      }
    }
    for (final cUid in _coHostControllers.keys) {
      if (cUid == widget.liveUser.agoraUID) continue;
      if (!displayedCoHosts.any((h) => _coHostAgoraUid(h) == cUid)) {
        displayedCoHosts.add({'agoraUid': cUid, 'name': 'Guest'});
      }
    }

    if (displayedCoHosts.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: stripTop,
      right: 8.0,
      bottom: bottomPad + 86.0,
      width: boxW + 8.0,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children:
              displayedCoHosts.map((coHost) {
                final agoraUid = _coHostAgoraUid(coHost);
                final controller =
                    agoraUid > 0 ? _coHostControllers[agoraUid] : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildCoHostBox(coHost, controller, boxW, boxH),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildCoHostBox(
    Map<String, dynamic> coHost,
    VideoViewController? controller,
    double boxW,
    double boxH,
  ) {
    final agoraUid = _coHostAgoraUid(coHost);
    if (agoraUid > 0 && agoraUid == widget.liveUser.agoraUID)
      return const SizedBox.shrink();

    final isMuted = coHost['isMute'] == true;
    final isCameraOff = coHost['isCameraOff'] == true;
    final isSpeaking = coHost['isSpeaking'] == true;
    final isVip = coHost['isVIP'] == true;
    final coHostFrame =
        coHost['avatarFrame']?.toString() ??
        coHost['avatarFrameImage']?.toString() ??
        coHost['frameUrl']?.toString() ??
        coHost['profileFrameUrl']?.toString() ??
        coHost['vipDetails']?['profileFrameUrl']?.toString();
    final roomCardUrl =
        coHost['vipDetails']?['roomCardUrl']?.toString() ??
        coHost['vipDetails']?['backgroundImage']?.toString() ??
        coHost['roomCardUrl']?.toString();
    final fullRoomCard =
        roomCardUrl != null && roomCardUrl.isNotEmpty
            ? VideoUtil.getFullImageUrl(roomCardUrl)
            : null;
    // Track co-host box position for gift fly animation.
    final coHostUserId = coHost['userId']?.toString() ?? '';
    if (coHostUserId.isNotEmpty) {
      _coHostBoxKeys[coHostUserId] ??= GlobalKey();
    }
    return GestureDetector(
      onTap:
          () => _showLiveProfileCard(
            userId: coHostUserId,
            name: coHost['name']?.toString(),
            image: coHost['image']?.toString(),
            avatarFrame: coHostFrame,
            isVIP: isVip,
            vipBadgeUrl: coHost['vipBadgeUrl']?.toString(),
            country: coHost['country']?.toString(),
          ),
      onLongPress: widget.isHost ? () => _openCoHostOptions(coHost) : null,
      child: Container(
        key: coHostUserId.isNotEmpty ? _coHostBoxKeys[coHostUserId] : null,
        width: boxW,
        height: boxH,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isSpeaking
                    ? const Color(0xFF00E5FF)
                    : (isVip
                        ? Colors.amber.withValues(alpha: 0.6)
                        : Colors.white24),
            width: isSpeaking ? 2.5 : 1.5,
          ),
          boxShadow:
              isSpeaking
                  ? [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ]
                  : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            // VIP room card background behind the video/avatar.
            if (fullRoomCard != null && fullRoomCard.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: fullRoomCard,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            // Video or avatar.
            if (controller != null && !isCameraOff)
              AgoraVideoView(controller: controller)
            else
              Center(
                child: UserAvatar(
                  imageUrl: coHost['image']?.toString(),
                  frameUrl: coHostFrame,
                  size: boxW * 0.5,
                  isVIP: isVip,
                ),
              ),
            // Gradient overlay at bottom for name readability.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                child: Row(
                  children: [
                    if (isVip)
                      const Padding(
                        padding: EdgeInsets.only(right: 3),
                        child: Icon(Icons.star, color: Colors.amber, size: 10),
                      ),
                    Expanded(
                      child: Text(
                        coHost['name']?.toString() ?? 'Guest',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: boxW > 80 ? 11 : 9,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Mute badge.
            if (isMuted)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.mic_off,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            // Speaking indicator (pulsing dot).
            if (isSpeaking && !isMuted)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E5FF),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoHostControls() {
    final topPad = MediaQuery.of(context).viewPadding.top;
    return Positioned(
      right: 8,
      top: (topPad == 0 ? 12 : topPad + 6) + 120,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bottomAction(
              _micEnabled ? Icons.mic : Icons.mic_off,
              Colors.white,
              _toggleCoHostMute,
            ),
            const SizedBox(height: 8),
            _bottomAction(
              _isCameraOff ? Icons.videocam_off : Icons.videocam,
              Colors.white,
              _toggleCoHostCamera,
            ),
            const SizedBox(height: 8),
            _bottomAction(
              Icons.cameraswitch,
              Colors.white,
              _switchCoHostCamera,
            ),
            const SizedBox(height: 8),
            _bottomAction(
              Icons.call_end,
              Colors.white,
              _leaveCall,
              bg: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceRightControls() {
    final topPad = MediaQuery.of(context).viewPadding.top;
    return Positioned(
      right: 8,
      top: (topPad == 0 ? 12 : topPad + 6) + 120,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bottomAction(Icons.call, const Color(0xFFFFA000), _openHandRaise),
            const SizedBox(height: 8),
            _bottomAction(
              Icons.group_add,
              const Color(0xFF7E3FF2),
              _sendJoinRequest,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _followHost() async {
    if (widget.isHost) return;
    final session = context.read<SessionManager>();
    setState(() => _isFollowing = !_isFollowing);
    try {
      await ApiService.followUnfollow({
        'userId': session.userId,
        'followingUserId': widget.liveUser.userId,
      });
      if (mounted)
        Fluttertoast.showToast(
          msg:
              _isFollowing
                  ? 'Following ${widget.liveUser.name ?? 'host'}'
                  : 'Unfollowed',
        );
    } catch (e, s) {
      if (mounted) setState(() => _isFollowing = !_isFollowing);
      Log.e(_tag, 'followHost failed', e, s);
    }
  }

  Future<void> _checkFollowStatus() async {
    try {
      final res = await ApiService.getGuestProfile(
        widget.liveUser.userId ?? '',
      );
      if (mounted) {
        setState(() => _isFollowing = res.user?.isFollow ?? false);
      }
    } catch (e) {
      Log.e(_tag, 'checkFollowStatus failed', e);
    }
  }

  void _onViewerTap(ViewerEntry v) {
    final userId = v.userId ?? '';
    _showLiveProfileCard(
      userId: userId,
      name: v.name,
      image: v.image,
      avatarFrame: v.avatarFrameImage,
      isVIP: v.isVIP,
      vipBadgeUrl: v.vipBadgeUrl,
      country: v.country,
      countryFlagImage: v.countryFlagImage,
      cpLevel: v.cpLevel,
      friendLevel: v.friendLevel,
      relationshipType: v.relationshipType,
    );
  }

  void _showViewerModerationOptions(ViewerEntry v) {
    if ((v.userId ?? '').isEmpty) return;
    // Host AND assigned room admins can moderate viewers (mute/kick/ban).
    // Only the host can assign new admins.
    if (_canModerate) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder:
            (ctx) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      v.name ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white12),
                  ListTile(
                    leading: const Icon(Icons.person, color: Colors.white70),
                    title: const Text(
                      'View Profile',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      showUserProfileSheet(
                        context,
                        userId: v.userId!,
                        showAdminActions: true,
                        // Only the host can assign admins.
                        onMakeAdmin:
                            widget.isHost
                                ? () {
                                  // Must include isAdmin: true — the removal flow
                                  // sends isAdmin: false, and the backend keys off
                                  // this flag. Without it the assignment is a no-op.
                                  SocketService.instance
                                      .emit(Const.updateRoomAdmins, {
                                        'userId': v.userId,
                                        'liveStreamingId':
                                            widget.liveUser.liveRoomId,
                                        'liveUserMongoId': widget.liveUser.id,
                                        'isAdmin': true,
                                      });
                                  Fluttertoast.showToast(msg: 'Admin added');
                                }
                                : null,
                        onMute: () async {
                          // Mute/unmute a viewer's chat in the room.
                          if (v.isAntiMuteEnabled) {
                            Fluttertoast.showToast(
                              msg:
                                  'This VIP user is protected from being muted',
                            );
                            return;
                          }
                          try {
                            final session = context.read<SessionManager>();
                            await ApiService.muteViewerInLive(
                              liveStreamingId: widget.liveUser.liveRoomId ?? '',
                              userId: session.userId,
                              viewerId: v.userId ?? '',
                              mute: true,
                            );
                            Fluttertoast.showToast(msg: 'User muted');
                          } catch (e) {
                            Log.e(_tag, 'muteViewer failed', e);
                            Fluttertoast.showToast(msg: 'Mute failed');
                          }
                        },
                        onKick: () {
                          // VIP anti-kick protection — cannot kick protected viewers.
                          if (v.isAntiKickEnabled) {
                            Fluttertoast.showToast(
                              msg:
                                  'This VIP user is protected from being kicked',
                            );
                            return;
                          }
                          // Ports native onBlockClick: emit updateBlockedList so
                          // the backend actually blocks the user from rejoining.
                          // Just emitting lessView only decrements the viewer
                          // count — the kicked user can immediately rejoin.
                          SocketService.instance
                              .emit(Const.eventUpdateBlockedlist, {
                                'liveStreamingId': widget.liveUser.liveRoomId,
                                'blockedUserId': v.userId,
                                'type': 'block',
                              });
                          SocketService.instance.emit(Const.eventLessView, {
                            'userId': v.userId,
                            'liveStreamingId': widget.liveUser.liveRoomId,
                          });
                          Fluttertoast.showToast(msg: 'User kicked');
                        },
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.group_add,
                      color: Color(0xFF7E3FF2),
                    ),
                    title: const Text(
                      'Invite to Call',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _inviteViewerToCall(v);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.videocam,
                      color: Color(0xFF7E3FF2),
                    ),
                    title: const Text(
                      'Private Video Call',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      startCall(
                        context,
                        otherUserId: v.userId!,
                        isAudioCall: false,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.phone, color: Color(0xFF7E3FF2)),
                    title: const Text(
                      'Private Audio Call',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      startCall(
                        context,
                        otherUserId: v.userId!,
                        isAudioCall: true,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.block, color: Colors.red),
                    title: const Text(
                      'Ban from Room',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final session = context.read<SessionManager>();
                      // Use the new dedicated ban API — backend persists the ban,
                      // emits viewerKicked to the viewer, and prevents rejoining.
                      try {
                        await ApiService.banViewerFromLive(
                          liveStreamingId: widget.liveUser.liveRoomId ?? '',
                          userId: session.userId,
                          viewerId: v.userId ?? '',
                        );
                      } catch (e) {
                        Log.e(
                          _tag,
                          'banViewer API failed, falling back to socket',
                          e,
                        );
                        // Fallback: direct socket emit if API fails.
                        SocketService.instance.emit(Const.eventUserBlock, {
                          'userId': v.userId,
                          'liveStreamingId': widget.liveUser.liveRoomId,
                          'blockedUserId': v.userId,
                        });
                        SocketService.instance.emit(Const.eventLessView, {
                          'userId': v.userId,
                          'liveStreamingId': widget.liveUser.liveRoomId,
                        });
                      }
                      if (mounted) {
                        Fluttertoast.showToast(
                          msg: '${v.name ?? 'User'} banned from room',
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.report, color: Colors.orange),
                    title: const Text(
                      'Report / Block',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      showReportOptionsSheet(context, otherUserId: v.userId!);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
      );
    } else {
      showUserProfileSheet(context, userId: v.userId!);
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text(
              'Permissions Required',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Camera and microphone access are needed to join this live stream. Please enable them in your app settings.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  void _showTopOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.isHost ? 'Host Options' : 'Room Options',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: Colors.white12),
                if (widget.isHost)
                  ListTile(
                    leading: const Icon(Icons.close, color: Colors.red),
                    title: const Text(
                      'End Live',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _endLive();
                    },
                  ),
                if (widget.isHost)
                  ListTile(
                    leading: const Icon(Icons.summarize, color: Colors.blue),
                    title: const Text(
                      'Summary',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.pushNamed(
                        AppRoutes.liveSummary,
                        extra: {
                          'liveStreamingId': widget.liveUser.liveRoomId ?? '',
                          'durationSeconds': _durationSeconds,
                          'liveType': 'video',
                          'commentsCount': _clientCommentCount,
                          'viewersCount': _viewerCount,
                          'giftsCount': _giftStatsController.totalGiftCount,
                          'fansCount': _clientFanCount,
                          'beansCount': diamondsToBeans(
                            _giftStatsController.hostEarnings,
                            context.read<SessionManager>().getSetting(),
                          ),
                          'earnings':
                              _giftStatsController.hostEarnings.toString(),
                        },
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.orange),
                  title: Text(
                    widget.isHost ? 'Close Live' : 'Leave Room',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (widget.isHost) {
                      // For host, close live means minimize (keep running in background)
                      _minimizeRoom();
                    } else {
                      // For viewer, just leave the room
                      if (mounted) Navigator.pop(context);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.orange),
                  title: const Text(
                    'Block Users',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    showViewersSheet(
                      context,
                      viewers: _viewers,
                      isHost: widget.isHost,
                      onViewerTap: _onViewerTap,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  /// Bigo/Chamet-style lucky gift winner broadcast banner.
  Widget _buildLuckyGiftBanner() {
    if (_luckyBannerName == null || _luckyBannerName!.isEmpty) {
      return const SizedBox.shrink();
    }
    String bgUrl = '';
    if (_luckyBannerUrls.isNotEmpty) {
      final idx = Random().nextInt(_luckyBannerUrls.length);
      bgUrl = _luckyBannerUrls[idx];
    }

    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFF6B00)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66FFD700),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
            image:
                bgUrl.isNotEmpty && !SvgaHelper.isSvgaUrl(bgUrl)
                    ? DecorationImage(
                      image: SafeImageProvider(bgUrl),
                      fit: BoxFit.cover,
                      opacity: 0.25,
                    )
                    : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_luckyBannerImage != null && _luckyBannerImage!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: _luckyBannerImage!,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorWidget:
                          (_, __, ___) => const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 18,
                          ),
                    ),
                  ),
                ),
              Text(
                '${_luckyBannerName!} won ${formatCount(_luckyBannerCoins)} diamonds!',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final topPad = MediaQuery.of(context).viewPadding.top;
    return Positioned(
      top: topPad == 0 ? 12 : topPad + 6,
      left: 8,
      right: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHostInfoBox(),
              const Spacer(),
              _buildAudienceAvatarStrip(),
              const SizedBox(width: 4),
              _buildAudienceCounter(),
              const SizedBox(width: 4),
              _topActionIcon(Icons.share, _openInboxShare),
              const SizedBox(width: 4),
              _topActionIcon(Icons.more_vert, _showTopOptionsMenu),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Live timer + gift beans counter — same layout as audio room.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _networkQuality <= 1
                              ? Icons.signal_cellular_4_bar
                              : _networkQuality <= 3
                              ? Icons.signal_cellular_alt_2_bar
                              : Icons.signal_cellular_alt_1_bar,
                          size: 12,
                          color:
                              _networkQuality <= 1
                                  ? Colors.green
                                  : _networkQuality <= 3
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        ValueListenableBuilder<int>(
                          valueListenable: _durationNotifier,
                          builder:
                              (_, duration, __) => Text(
                                _formatDuration(duration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  GestureDetector(
                    onTap: _openFansRanking,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.diamond,
                            size: 13,
                            color: Color(0xFFFFD54F),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            formatCount(
                              diamondsToBeans(
                                _giftStatsController.hostEarnings,
                                context.read<SessionManager>().getSetting(),
                              ),
                            ),
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_isMusicPlaying && _currentMusicName != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.music_note,
                        size: 12,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Text(
                          _currentMusicName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHostInfoBox() {
    final hostName =
        widget.liveUser.name?.isNotEmpty == true
            ? widget.liveUser.name!
            : 'Host';
    final uniqueId = _hostUniqueId ?? widget.liveUser.uniqueId ?? '';
    final displayId = uniqueId.isNotEmpty ? 'ID: $uniqueId' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap:
                () => _showLiveProfileCard(
                  userId: widget.liveUser.userId ?? '',
                  name: widget.liveUser.name,
                  image: widget.liveUser.userImage ?? widget.liveUser.image,
                  avatarFrame: widget.liveUser.avatarFrameImage,
                  isVIP: widget.liveUser.isVIP,
                  cpLevel: widget.liveUser.cpLevel,
                  friendLevel: widget.liveUser.friendLevel,
                  relationshipType: widget.liveUser.relationshipType,
                ),
            child: UserAvatar(
              imageUrl: widget.liveUser.userImage,
              frameUrl: widget.liveUser.avatarFrameImage,
              size: 34,
              isVIP: widget.liveUser.isVIP,
              familyFrameUrl: widget.liveUser.familyImage,
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 145),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        hostName,
                        style: TextStyle(
                          color:
                              CpStyleHelper.nameColorFor(
                                relationshipType:
                                    widget.liveUser.relationshipType,
                                cpLevel: widget.liveUser.cpLevel,
                                friendLevel: widget.liveUser.friendLevel,
                              ) ??
                              Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                    if (widget.liveUser.relationshipType != null) ...[
                      const SizedBox(width: 4),
                      CpStyleHelper.badgeChip(
                        relationshipType: widget.liveUser.relationshipType,
                        cpLevel: widget.liveUser.cpLevel,
                        friendLevel: widget.liveUser.friendLevel,
                        size: 14,
                      ),
                    ],
                    if (widget.liveUser.familyName != null &&
                        widget.liveUser.familyName!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      _buildHostFamilyBadge(),
                    ],
                    if (!widget.isHost) ...[
                      if (!_isFollowing)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: GestureDetector(
                            onTap: _followHost,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF7E3FF2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: GestureDetector(
                          onTap: _openSubscription,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE91E63),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.subscriptions,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (displayId.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(
                      displayId,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                if (widget.liveUser.relationshipType != null) ...[
                  const SizedBox(height: 2),
                  BondProgressBarRoom(
                    level:
                        widget.liveUser.relationshipType == 'cp'
                            ? widget.liveUser.cpLevel
                            : widget.liveUser.friendLevel,
                    currentIntimacy: widget.liveUser.intimacy,
                    targetIntimacy:
                        (widget.liveUser.relationshipType == 'cp'
                            ? widget.liveUser.cpLevel
                            : widget.liveUser.friendLevel) *
                        1000,
                    type: widget.liveUser.relationshipType!,
                    width: 120,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceCounter() {
    return GestureDetector(
      onTap:
          () => showViewersSheet(
            context,
            viewers: _viewers,
            isHost: widget.isHost,
            onViewerTap: _onViewerTap,
          ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility, color: Colors.white70, size: 12),
            const SizedBox(width: 3),
            Text(
              _formatNumber(_viewerCount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceAvatarStrip() {
    final count = _viewers.length;
    if (count == 0) return const SizedBox.shrink();
    // Native-like strip: show max 4 avatars
    final visibleWidth = (min(count, 4) * 24.0).clamp(24.0, 96.0);
    return SizedBox(
      width: visibleWidth,
      height: 24,
      child: ListView.separated(
        controller: _viewerAvatarScroll,
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 2),
        itemBuilder: (_, i) {
          final v = _viewers[i];
          return GestureDetector(
            onTap: () => _onViewerTap(v),
            onLongPress:
                _canModerate ? () => _showViewerModerationOptions(v) : null,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topLeft,
              children: [
                UserAvatar(
                  imageUrl: v.image,
                  frameUrl: v.avatarFrameImage,
                  size: 24,
                  isVIP: v.isVIP,
                  vipBadgeUrl: v.vipBadgeUrl,
                ),
                if (v.relationshipType != null)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: RelationshipBadge(
                      type: v.relationshipType,
                      level:
                          v.relationshipType == 'cp'
                              ? (v.cpLevel ?? 1)
                              : (v.friendLevel ?? 1),
                      size: 10,
                      showLevel: false,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Inline PK overlay — renders split-screen PK inside the live room,
  /// matching native UniLivePro's in-place PK composition. Comments, gifts,
  /// bottom bar, and all live-room functionality continue working.
  Widget _buildPkOverlay() {
    final config = _pkConfig;
    if (config == null) return const SizedBox.shrink();
    final topPad = MediaQuery.of(context).viewPadding.top;
    final host1Name = config.host1Name ?? config.host1Details?.name ?? 'Host 1';
    final host2Name = config.host2Name ?? config.host2Details?.name ?? 'Host 2';
    final host1Image = config.host1Image ?? config.host1Details?.image;
    final host2Image = config.host2Image ?? config.host2Details?.image;
    final myName = _pkIsHost1 ? host1Name : host2Name;
    final oppName = _pkIsHost1 ? host2Name : host1Name;
    final myImage = _pkIsHost1 ? host1Image : host2Image;
    final oppImage = _pkIsHost1 ? host2Image : host1Image;
    final myScore = _pkIsHost1 ? _pkScoreHost1 : _pkScoreHost2;
    final oppScore = _pkIsHost1 ? _pkScoreHost2 : _pkScoreHost1;
    final myVotes = _pkIsHost1 ? _pkVoteCountHost1 : _pkVoteCountHost2;
    final oppVotes = _pkIsHost1 ? _pkVoteCountHost2 : _pkVoteCountHost1;
    final mins = (_pkSecondsLeft ~/ 60).toString().padLeft(2, '0');
    final secs = (_pkSecondsLeft % 60).toString().padLeft(2, '0');
    final totalScore = myScore + oppScore;
    final myPct = totalScore > 0 ? myScore / totalScore : 0.5;

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // PK split video panel height — responsive, matching native ~340dp.
          final videoH = (constraints.maxHeight * 0.47).clamp(280.0, 340.0);
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/pk_bg_fot.webp',
                  fit: BoxFit.cover,
                ),
              ),
              // PK split video panel at top.
              Positioned(
                top: topPad + 44,
                left: 0,
                right: 0,
                height: videoH,
                child: _buildPkSplitVideo(
                  myName: myName,
                  oppName: oppName,
                  myImage: myImage,
                  oppImage: oppImage,
                ),
              ),
              // Score bar + timer below the video panel.
              Positioned(
                top: topPad + 44 + videoH + 12,
                left: 8,
                right: 8,
                child: _buildPkScoreAndTimer(
                  myScore: myScore,
                  oppScore: oppScore,
                  myPct: myPct,
                  mins: mins,
                  secs: secs,
                  myVotes: myVotes,
                  oppVotes: oppVotes,
                ),
              ),
              // Punishment overlay.
              if (_isPkPunishment && _pkPunishmentTask != null)
                Positioned(
                  top: topPad + 44 + videoH + 60,
                  left: 16,
                  right: 16,
                  child: _buildPkPunishmentBanner(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPkSplitVideo({
    required String myName,
    required String oppName,
    required String? myImage,
    required String? oppImage,
  }) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Row(
          children: [
            // Left: my video (host) / host1 video (audience).
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1A1A2E), Colors.black],
                      ),
                    ),
                    child: _buildPkMyVideo(),
                  ),
                  _buildPkHostOverlay(
                    name: myName,
                    image: myImage,
                    isLeft: true,
                  ),
                  if (_pkWinner >= 0) _buildPkResultOverlay(isLocal: true),
                ],
              ),
            ),
            // VS divider.
            Container(
              width: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF5652FF),
                    Color(0xFF39C8FF),
                    Color(0xFFDD0F6C),
                  ],
                ),
              ),
            ),
            // Right: opponent video.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF2E1A1A), Colors.black],
                      ),
                    ),
                    child: _buildPkOpponentVideo(),
                  ),
                  _buildPkHostOverlay(
                    name: oppName,
                    image: oppImage,
                    isLeft: false,
                  ),
                  if (_pkWinner >= 0) _buildPkResultOverlay(isLocal: false),
                ],
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.center,
          child: IgnorePointer(
            child: Image.asset(
              'assets/images/live_pk_icon_vs.webp',
              width: 44,
              height: 36,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPkMyVideo() {
    // Host: show local camera. Audience: show host1/host2 video based on side.
    if (widget.isHost) {
      if (_localController != null) {
        return AgoraVideoView(controller: _localController!);
      }
      return const Center(
        child: Icon(Icons.videocam_off, color: Colors.white38, size: 32),
      );
    }
    // Audience — render the host's remote video.
    final hostUid =
        _pkIsHost1 ? _pkConfig?.host1AgoraUID : _pkConfig?.host2AgoraUID;
    if (hostUid != null && hostUid > 0 && _remoteController != null) {
      return AgoraVideoView(controller: _remoteController!);
    }
    return const Center(
      child: Icon(Icons.videocam_off, color: Colors.white38, size: 32),
    );
  }

  Widget _buildPkOpponentVideo() {
    if (_pkRemoteController != null) {
      return AgoraVideoView(controller: _pkRemoteController!);
    }
    // Audience: if this side is the opponent, show remote video.
    if (!widget.isHost) {
      final oppUid = _pkRemoteAgoraUid;
      if (oppUid != null &&
          oppUid > 0 &&
          _remoteUid == oppUid &&
          _remoteController != null) {
        return AgoraVideoView(controller: _remoteController!);
      }
    }
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off, color: Colors.white38, size: 32),
          SizedBox(height: 4),
          Text(
            'Connecting...',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPkHostOverlay({
    required String name,
    required String? image,
    required bool isLeft,
  }) {
    return Positioned(
      bottom: 6,
      left: isLeft ? 6 : null,
      right: isLeft ? null : 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image != null && image.isNotEmpty)
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: VideoUtil.getFullImageUrl(image),
                  width: 18,
                  height: 18,
                  fit: BoxFit.cover,
                  placeholder:
                      (_, __) => Container(
                        width: 18,
                        height: 18,
                        color: Colors.white24,
                      ),
                  errorWidget:
                      (_, __, ___) => Container(
                        width: 18,
                        height: 18,
                        color: Colors.white24,
                      ),
                ),
              )
            else
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  size: 12,
                  color: Colors.white70,
                ),
              ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80),
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPkResultOverlay({required bool isLocal}) {
    final isTie = _pkWinner == 0;
    final localWon =
        (_pkIsHost1 && _pkWinner == 2) || (!_pkIsHost1 && _pkWinner == 1);
    final sideWon = isLocal ? localWon : !localWon;
    final resultAsset =
        isTie
            ? 'assets/pk_live/pk_tie.png'
            : (sideWon ? 'assets/pk_live/pk_winner.png' : 'assets/pk_live/pk_loser.png');
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
          ),
        ),
        child: Center(
          child: Image.asset(
            resultAsset,
            width: 110,
            height: 110,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildPkResultButton({
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? Colors.white).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 8),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  void _onPkRestartTapped() {
    _pkResultResetTimer?.cancel();
    _pkResultResetTimer = null;
    final config = _pkConfig;
    if (config == null) {
      _resetPkState();
      return;
    }
    final myId =
        widget.liveUser.userId ??
        context.read<SessionManager>().userId ??
        '';
    final isHost1 = _pkIsHost1;
    final opponentId = isHost1 ? config.host2Id : config.host1Id;
    final opponentLiveId = isHost1 ? config.host2LiveId : config.host1LiveId;
    final opponentName = isHost1 ? config.host2Name : config.host1Name;
    final opponentImage = isHost1 ? config.host2Image : config.host1Image;
    final opponentAgoraUid =
        isHost1 ? config.host2AgoraUID : config.host1AgoraUID;
    final opponentChannel =
        isHost1 ? config.host2Channel : config.host1Channel;
    if (opponentId?.isNotEmpty != true ||
        opponentLiveId?.isNotEmpty != true ||
        myId.isEmpty) {
      _resetPkState();
      return;
    }
    final opponent = lur.LiveUser(
      liveUserId: opponentId,
      liveStreamingId: opponentLiveId,
      name: opponentName,
      image: opponentImage,
      agoraUID: opponentAgoraUid,
      channel: opponentChannel,
    );
    _resetPkState();
    _sendPkRequest(opponent);
  }

  void _onPkCloseTapped() {
    _pkResultResetTimer?.cancel();
    _pkResultResetTimer = null;
    final config = _pkConfig;
    if (widget.isHost && config != null) {
      try {
        SocketService.instance.emit(Const.eventPkEnd, {
          'pkId': config.pkId,
          'host1Id': config.host1Id,
          'host2Id': config.host2Id,
          'host1LiveId': config.host1LiveId,
          'host2LiveId': config.host2LiveId,
          'winner': _pkWinner,
          'reason': 'manual',
        });
      } catch (_) {}
    }
    _resetPkState();
  }

  Widget _buildPkScoreAndTimer({
    required int myScore,
    required int oppScore,
    required double myPct,
    required String mins,
    required String secs,
    required int myVotes,
    required int oppVotes,
  }) {
    return Column(
      children: [
        // Score progress bar with VS badge.
        SizedBox(
          height: 18,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Colors.white54, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7E3FF2).withValues(alpha: 0.6),
                      blurRadius: 12,
                      spreadRadius: -4,
                      offset: const Offset(-6, 0),
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF2D55).withValues(alpha: 0.6),
                      blurRadius: 12,
                      spreadRadius: -4,
                      offset: const Offset(6, 0),
                    ),
                    const BoxShadow(color: Colors.black38, blurRadius: 6),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final leftWidth =
                          (constraints.maxWidth * myPct)
                              .clamp(2.0, constraints.maxWidth - 2.0)
                              .toDouble();
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Color(0xFFFF2D55), Color(0xFFFF6B6B)],
                              ),
                            ),
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: leftWidth,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Color(0xFF9B5FF5),
                                    Color(0xFF7E3FF2),
                                    Color(0xFF5A74FF),
                                    Color(0xFF9B5FF5),
                                  ],
                                  stops: [0.0, 0.35, 0.7, 1.0],
                                ),
                              ),
                            ),
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            left: leftWidth - 2,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 5,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.white, Color(0xFFFFD700), Colors.white],
                                ),
                                borderRadius: BorderRadius.circular(2.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                  ),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 8),
                    BoxShadow(color: Colors.orange, blurRadius: 10, spreadRadius: 1),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Colors.black45, blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Score numbers + timer + votes.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.how_to_vote,
                  color: Color(0xFF7E3FF2),
                  size: 12,
                ),
                const SizedBox(width: 2),
                Text(
                  '$myScore · $myVotes',
                  style: const TextStyle(
                    color: Color(0xFF7E3FF2),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: Colors.white70, size: 12),
                  const SizedBox(width: 3),
                  Text(
                    '$mins:$secs',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$oppScore · $oppVotes',
                  style: const TextStyle(
                    color: Color(0xFFE94057),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.how_to_vote,
                  color: Color(0xFFE94057),
                  size: 12,
                ),
              ],
            ),
          ],
        ),
        if (widget.isHost && _pkWinner >= 0) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPkResultButton(
                label: 'Restart',
                onTap: _onPkRestartTapped,
                color: const Color(0xFF7E3FF2),
              ),
              const SizedBox(width: 14),
              _buildPkResultButton(
                label: 'Close',
                onTap: _onPkCloseTapped,
                color: const Color(0xFFFF416C),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPkPunishmentBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF6B00)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gavel, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Punishment: $_pkPunishmentTask!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPkVoteBadges() {
    final topPad = MediaQuery.of(context).viewPadding.top;
    return Positioned(
      top: (topPad == 0 ? 12 : topPad + 6) + 130,
      left: 16,
      right: 16,
      child: Column(
        children: [
          // PK score bar.
          if (_pkScoreHost1 > 0 || _pkScoreHost2 > 0) ...[
            Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Expanded(
                      flex: (_score1Pct * 100).round().clamp(1, 99),
                      child: Container(color: const Color(0xFF7E3FF2)),
                    ),
                    Expanded(
                      flex: (100 - (_score1Pct * 100).round().clamp(1, 99)),
                      child: Container(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_pkScoreHost1',
                  style: const TextStyle(
                    color: Color(0xFF7E3FF2),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$_pkScoreHost2',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Vote badges.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF7E3FF2), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.how_to_vote,
                      color: Color(0xFF7E3FF2),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_pkVoteCountHost1 votes',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.how_to_vote, color: Colors.red, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$_pkVoteCountHost2 votes',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Punishment banner.
          if (_isPkPunishment && _pkPunishmentTask != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF6B00)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.5),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gavel, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Punishment: $_pkPunishmentTask!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  double get _score1Pct =>
      _pkScoreHost1 + _pkScoreHost2 > 0
          ? _pkScoreHost1 / (_pkScoreHost1 + _pkScoreHost2)
          : 0.5;

  Widget _topActionIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildCommentsOverlay() {
    // Lift above the keyboard so comments stay visible while typing.
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return Positioned(
      left: 8,
      right: 68,
      bottom: 68 + keyboardInset,
      child: Container(
        height: 145,
        color: Colors.transparent,
        child:
            _comments.isEmpty
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Be the first to comment...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
                : ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  itemCount: _comments.length,
                  itemBuilder: (_, i) {
                    final c = _comments[i];
                    return _buildCommentBubble(c);
                  },
                ),
      ),
    );
  }

  void _showLiveProfileCard({
    required String userId,
    String? name,
    String? image,
    String? avatarFrame,
    bool isVIP = false,
    String? vipBadgeUrl,
    String? country,
    String? countryFlagImage,
    int? cpLevel,
    int? friendLevel,
    String? relationshipType,
  }) {
    if (userId.isEmpty) return;
    showProfileRoomCard(
      context,
      seat: SeatItem(
        userId: userId,
        name: name,
        image: image,
        avatarFrame: avatarFrame,
        country: country,
        countryFlagImage: countryFlagImage,
        position: -2,
        reserved: true,
        isVIP: isVIP,
        vipBadgeUrl: vipBadgeUrl,
        cpLevel: cpLevel,
        friendLevel: friendLevel,
        relationshipType: relationshipType,
      ),
      isHostView: widget.isHost,
      iAmAdmin: _iAmAdmin,
      liveStreamingId:
          widget.liveUser.liveStreamingId ?? widget.liveUser.id ?? '',
      liveUserId: widget.liveUser.userId ?? '',
      liveUserMongoId: widget.liveUser.id ?? '',
      onMention: () {},
      onGift: _openGifts,
    );
  }

  void _showCommentProfileCard(_LiveComment c) {
    final userId = c.userId ?? '';
    if (userId.isEmpty) return;
    final identity = VipPrivilegeHelper.identityFromPayload({
      'isVIP': c.isVIP,
      'vipLevel': c.vipLevel,
      'vipDetails': {
        'profileFrameUrl': c.frameUrl,
        'levelBadgeUrl': c.badgeUrls.isNotEmpty ? c.badgeUrls.first : null,
      },
    });
    final seat = SeatItem(
      userId: userId,
      name: c.name,
      image: c.userImage,
      avatarFrame: c.frameUrl,
      country: c.country,
      countryFlagImage: c.countryFlagImage,
      position: -2,
      reserved: false,
      isVIP: c.isVIP || (c.vipLevel ?? 0) > 0,
      vipBadgeUrl: identity.badgeUrl,
      cpLevel: c.cpLevel,
      friendLevel: c.friendLevel,
      relationshipType: c.relationshipType,
    );
    showProfileRoomCard(
      context,
      seat: seat,
      isHostView: widget.isHost,
      iAmAdmin: _iAmAdmin,
      liveStreamingId:
          widget.liveUser.liveStreamingId ?? widget.liveUser.id ?? '',
      liveUserId: widget.liveUser.userId ?? '',
      liveUserMongoId: widget.liveUser.id ?? '',
      onMention: () {},
      onGift: _openGifts,
    );
  }

  /// Bigo/Chamet-style chat bubble — reuse the audio room bubble design
  /// so video live comments look identical to audio live comments.
  Widget _buildCommentBubble(_LiveComment c) {
    return AudioRoomCommentBubble(
      comment: _toAudioRoomComment(c),
      myUserId: context.read<SessionManager>().userId,
      isHost: widget.isHost,
      iAmAdmin: _iAmAdmin,
      onTapUser: () => _showCommentProfileCard(c),
      onAcceptSeatRequest:
          c.isSeatRequest && widget.isHost
              ? () => _acceptSeatRequestFromComment(c)
              : null,
      onLongPressName: () => _copyComment(c.text ?? ''),
      onCopy: () => _copyComment(c.text ?? ''),
    );
  }

  void _acceptSeatRequestFromComment(_LiveComment c) {
    final reqUserId = c.seatRequestUserId ?? c.userId ?? '';
    final req = _joinRequests.firstWhere(
      (r) => r['userId'] == reqUserId,
      orElse:
          () => {
            'userId': reqUserId,
            'name': c.name ?? 'User',
            'image': c.userImage ?? '',
            'avatarFrame': c.frameUrl,
            'agoraUid': 0,
            'isVIP': c.isVIP,
            'country': c.country ?? '',
          },
    );
    _acceptJoinRequest(req);
  }

  AudioRoomComment _toAudioRoomComment(_LiveComment c) {
    final isSystem = c.isJoined || (c.name == 'System') || c.isSystem;
    final isLuckyWin =
        (c.isGift || c.isSystem) &&
        (c.giftImage ?? '').isEmpty &&
        (c.text ?? '').toLowerCase().contains('lucky bag');
    int? luckyCoins;
    if (isLuckyWin) {
      final match = RegExp(r'(\d+)').firstMatch(c.text ?? '');
      luckyCoins = match != null ? int.tryParse(match.group(0) ?? '') : null;
    }
    return AudioRoomComment(
      name: c.name,
      text: c.text,
      isMine: c.isMine,
      isVIP: c.isVIP,
      isGift: c.isGift && !isSystem && !isLuckyWin,
      isSystem: isSystem,
      isAdmin: c.isAdmin,
      isHost: c.isHost,
      isAgency: c.isAgency,
      isBd: c.isBd,
      imageUrl: c.imageUrl,
      userImage: c.userImage,
      frameUrl: c.frameUrl,
      giftImage: c.giftImage,
      giftReceiverName: c.giftReceiverName,
      giftReceiverImage: c.giftReceiverImage,
      giftCoin: c.giftCoins,
      giftCount: c.giftCount,
      isLuckyWin: isLuckyWin,
      luckyCoins: luckyCoins,
      vipStyle: c.vipStyle,
      vipLevel: c.vipLevel,
      chatBubbleId: c.vipStyle?.chatBubbleId ?? c.vipLevel,
      levelName: c.levelName,
      country: c.country,
      countryFlagImage: c.countryFlagImage,
      familyName: c.familyName,
      familyBadgeUrl: c.familyBadgeUrl,
      userId: c.userId,
      isCard: c.isCard,
      cardImage: c.cardImage,
      cardCta: c.cardCta,
      cardAction: c.cardAction,
      mentionedUserId: c.mentionedUserId,
      mentionedUserName: c.mentionedUserName,
      relationshipType: c.relationshipType,
      cpLevel: c.cpLevel,
      friendLevel: c.friendLevel,
      isSeatRequest: c.isSeatRequest,
      seatRequestUserId: c.seatRequestUserId,
      badgeUrls: c.badgeUrls,
      tagLabels: c.tagLabels,
    );
  }

  /// Host family badge for the top bar — mirrors audio room's host
  /// family name chip.
  Widget _buildHostFamilyBadge() {
    final name = widget.liveUser.familyName ?? '';
    final badgeUrl = VideoUtil.getFullImageUrl(
      widget.liveUser.familyBadgeUrl ?? '',
    );
    if (badgeUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: badgeUrl,
        width: 18,
        height: 18,
        errorWidget: (_, __, ___) => _buildHostFamilyTextChip(name),
      );
    }
    return _buildHostFamilyTextChip(name);
  }

  Widget _buildHostFamilyTextChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _copyComment(String text) {
    Clipboard.setData(ClipboardData(text: text));
    Fluttertoast.showToast(msg: 'Comment copied');
  }

  Widget _buildBottomBar() {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    // Lift the bar above the keyboard (resizeToAvoidBottomInset is false on the
    // Scaffold, so we handle the inset manually here).
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return Positioned(
      // Keep the composer flush with the keyboard (no extra air gap).
      bottom: keyboardInset + bottomPad,
      left: 8,
      right: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Background music is controlled from the host menu (Music)
          // to match the audio room layout.
          Container(
            padding:
                _isTyping
                    ? const EdgeInsets.fromLTRB(10, 10, 10, 2)
                    : const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color:
                  _isTyping
                      ? const Color(0xFFF3F4F8)
                      : Colors.black.withValues(alpha: 0.4),
              borderRadius:
                  _isTyping
                      ? const BorderRadius.vertical(top: Radius.circular(24))
                      : BorderRadius.circular(24),
              boxShadow:
                  _isTyping
                      ? const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 12,
                          offset: Offset(0, -4),
                        ),
                      ]
                      : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
            ),
            child: _isTyping ? _buildTypingBar() : _buildActionBar(),
          ),
        ],
      ),
    );
  }

  /// Quick chat templates shown above the message field in the open keyboard.
  static const List<String> _quickChatMessages = [
    'Nice to meet everyone!',
    '😂😂😂😂😂',
    'Hi',
    'Nice',
    'Follow',
  ];

  /// Send a pre-defined quick chat message.
  void _sendQuickComment(String text) {
    _commentCtrl.text = text;
    _sendComment();
    if (_commentFocus.hasFocus) {
      _commentFocus.unfocus();
    }
  }

  /// Horizontal strip of quick message chips (Bigo/Chamet-style open keyboard).
  Widget _buildQuickChatChips() {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children:
              _quickChatMessages.map((text) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _sendQuickComment(text),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        text,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  /// Bigo/Chamet-style open keyboard composer: quick chips, rounded message
  /// field with emoji icon, circular send button, and a toolbar above the
  /// system keyboard (emoji, message, GIF, settings, sticker, palette, mic).
  Widget _buildTypingBar() {
    final session = context.read<SessionManager>();
    final canSendPhoto = VipPrivilegeHelper.canSendMessagePictures(session);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuickChatChips(),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF7E3FF2).withValues(alpha: 0.18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _commentCtrl,
                  focusNode: _commentFocus,
                  onSubmitted: (_) => _sendComment(),
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Send a message...',
                    hintStyle: TextStyle(
                      color: Colors.black.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.emoji_emotions,
                        color: Color(0xFFFFD54F),
                        size: 22,
                      ),
                      onPressed: _openReactions,
                    ),
                  ),
                ),
              ),
            ),
            // Photo comment is a VIP-only privilege.
            if (canSendPhoto)
              _bottomAction(
                Icons.photo_camera,
                Colors.black54,
                _sendPhoto,
                bg: const Color(0xFFE8E9ED),
              ),
            _bottomAction(
              Icons.send,
              Colors.white,
              _sendComment,
              bg: const Color(0xFF7E3FF2),
            ),
          ],
        ),
        _buildKeyboardToolbar(),
      ],
    );
  }

  /// Custom accessory toolbar shown directly above the system keyboard
  /// (apps / chat / GIF / settings / voice emoji / room settings / mic).
  Widget _buildKeyboardToolbar() {
    const iconColor = Color(0xFF5F6273);
    return Container(
      height: 46,
      margin: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _toolbarIcon(Icons.apps, _openReactions, iconColor),
          _toolbarIcon(Icons.chat_bubble_outline, _openMessages, iconColor),
          _toolbarText('GIF', iconColor, () {}),
          _toolbarIcon(
            Icons.settings_outlined,
            widget.isHost ? _openHostMenu : _openAudienceMenu,
            iconColor,
          ),
          _toolbarIcon(
            Icons.sentiment_very_satisfied,
            _openVoiceEmoji,
            iconColor,
          ),
          _toolbarIcon(
            Icons.color_lens_outlined,
            _openRoomBackgroundPicker,
            iconColor,
          ),
          _toolbarIcon(
            _micEnabled ? Icons.mic : Icons.mic_off,
            widget.isHost
                ? _toggleMic
                : (_isJoined ? _toggleCoHostMute : _toggleMic),
            iconColor,
          ),
        ],
      ),
    );
  }

  void _openVoiceEmoji() {
    final session = context.read<SessionManager>();
    final isVip = session.getUser()?.isVIP ?? false;
    VoiceEmojiPicker.show(
      context,
      canUseVipExclusive: isVip,
      onSelected: (emoji) {
        SocketService.instance.emit('voiceEmoji', {
          'liveStreamingId': widget.liveUser.liveRoomId ?? '',
          'emojiId': emoji.id,
          'senderId': session.userId,
          'senderName': session.getUser()?.name ?? '',
          'senderAvatar': session.getUser()?.image ?? '',
        });
      },
    );
  }

  Widget _toolbarIcon(IconData icon, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _toolbarText(String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  /// Full action bar shown when the keyboard is closed: speaker | text field (tap
  /// to open keyboard) | message | mic (host or joined co-host only) | gift |
  /// cheer | menu.
  Widget _buildActionBar() {
    return Row(
      children: [
        _bottomAction(
          _speakerEnabled ? Icons.volume_up : Icons.volume_off,
          Colors.white,
          _toggleSpeaker,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              // Switch to typing bar first (which has the real TextField),
              // then request focus after the rebuild so the keyboard opens.
              setState(() => _isTyping = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _commentFocus.requestFocus();
              });
            },
            child: Container(
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Send a message...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
        _bottomAction(Icons.message, Colors.white, _openMessages),
        // Mic: only show for host (always) or co-host who has joined the call.
        if (widget.isHost)
          _bottomAction(
            _micEnabled ? Icons.mic : Icons.mic_off,
            Colors.white,
            _toggleMic,
          )
        else if (_isJoined)
          _bottomAction(
            _micEnabled ? Icons.mic : Icons.mic_off,
            Colors.white,
            _toggleCoHostMute,
          ),
        if (!widget.isHost && _isJoined)
          _bottomAction(
            _isCameraOff ? Icons.videocam_off : Icons.videocam,
            Colors.white,
            _toggleCoHostCamera,
          ),
        _bottomAction(
          null,
          Colors.white,
          _openGifts,
          imageAsset: 'assets/gift/icon_gift.png',
          bg: const Color(0xFFFFEA00),
        ),
        _bottomAction(Icons.favorite, const Color(0xFFFF4081), _sendCheer),
        _bottomAction(
          Icons.menu,
          Colors.white,
          widget.isHost ? _openHostMenu : _openAudienceMenu,
        ),
      ],
    );
  }

  Widget _buildHostControls() {
    final topPad = MediaQuery.of(context).viewPadding.top;
    return Positioned(
      right: 8,
      top: topPad == 0 ? 110 : topPad + 100,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bottomAction(
              _cameraEnabled ? Icons.videocam : Icons.videocam_off,
              Colors.white,
              _toggleCamera,
            ),
            const SizedBox(height: 8),
            _bottomAction(Icons.cameraswitch, Colors.white, _switchCamera),
            const SizedBox(height: 8),
            AIFeatureGuard(
              featureKey: AIFeatureKeys.beautyMakeup,
              child: _bottomAction(
                Icons.face_retouching_natural,
                Colors.white,
                () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder:
                      (_) => BeautyOptionsSheet(
                        engine: _engine,
                        initialSmoothness: widget.smoothness,
                        initialLightening: widget.lightening,
                        initialRedness: widget.redness,
                        initialLighteningContrast: _currentLighteningContrast,
                        onBeautyActiveChanged: (active) {
                          if (mounted) {
                            setState(() => _beautyModeActive = active);
                          }
                        },
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Quick reaction bar shown to the host after receiving a high-tier gift.
  /// Tapping a reaction fires the 3D gift trigger (simulates the voice trigger
  /// without needing speech-to-text).
  Widget _buildGift3DReactionBar() {
    final size = MediaQuery.of(context).size;
    return Positioned(
      bottom: 120,
      left: size.width / 2 - 140,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.purple.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.3),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'React:',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(width: 8),
            _reactionChip('Wow!', 'wow'),
            const SizedBox(width: 6),
            _reactionChip('Thank You!', 'thank you'),
            const SizedBox(width: 6),
            _reactionChip('Amazing!', 'amazing'),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _showGift3DReaction = false),
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.close, color: Colors.white38, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reactionChip(String label, String triggerWord) {
    return GestureDetector(
      onTap: () {
        final ai = context.read<AIFeatureManager>();
        DynamicAIFeaturesService.instance.onHostUtterance(triggerWord, ai);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple, Colors.pink.shade700],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Bigo/Chamet-style reaction overlay on the host video.
  /// Ports native `imgHostReaction` — shows for 7 seconds.
  Widget _buildReactionOverlay() {
    final image = _reactionImage;
    final name = _reactionName;
    if (image == null && name == null) return const SizedBox.shrink();
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.elasticOut,
        builder:
            (context, value, child) =>
                Transform.scale(scale: value, child: child),
        child: SizedBox(
          width: 150,
          height: 150,
          child:
              image != null && image.isNotEmpty
                  ? CachedNetworkImage(
                    imageUrl: image,
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                    errorWidget:
                        (_, __, ___) => Text(
                          name ?? '😊',
                          style: const TextStyle(
                            fontSize: 90,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                  )
                  : Text(
                    name ?? '😊',
                    style: const TextStyle(fontSize: 90, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
        ),
      ),
    );
  }

  String _formatCoins(int coins) {
    if (coins >= 1000000) return '${(coins / 1000000).toStringAsFixed(1)}M';
    if (coins >= 1000) return '${(coins / 1000).toStringAsFixed(1)}K';
    return '$coins';
  }

  bool _isSpecialGiftEffect(String giftName) {
    final lower = giftName.toLowerCase();
    return lower.contains('teddy') ||
        lower.contains('couple') ||
        lower.contains('ring') ||
        lower.contains('crown') ||
        lower.contains('car') ||
        lower.contains('vehicle') ||
        lower.contains('yacht') ||
        lower.contains('plane');
  }

  /// Track a supporter's cumulative diamonds during PK and fire a broadcast
  /// banner when they cross the 100k support threshold.
  void _checkPkSupport(
    String senderId,
    String senderName,
    String? senderImage,
    int coin,
    int count,
  ) {
    if (!_isPkActive || senderId.isEmpty) return;
    final total = coin * count;
    if (total <= 0) return;
    final previous = _pkSupporters[senderId] ?? 0;
    final current = previous + total;
    _pkSupporters[senderId] = current;
    if (current >= _pkSupportThreshold &&
        !_pkSupporterAnnounced.contains(senderId)) {
      _pkSupporterAnnounced.add(senderId);
      _broadcastOverlayKey.currentState?.enqueue(
        BroadcastEvent(
          type: BroadcastType.pkBroadcast,
          title:
              '$senderName got over ${_formatCoins(_pkSupportThreshold)} diamonds support',
          subtitle: 'in PK',
          avatar: senderImage,
          rightText: 'GO',
          durationSeconds: 5,
        ),
      );
    }
  }

  Widget _bottomAction(
    IconData? icon,
    Color color,
    VoidCallback onTap, {
    Color? bg,
    String? imageAsset,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: bg ?? Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          boxShadow: imageAsset != null
              ? [
                  BoxShadow(
                    color: (bg ?? const Color(0xFFFFEA00)).withValues(
                      alpha: 0.6,
                    ),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: imageAsset != null
            ? Image.asset(imageAsset, width: 16, height: 16)
            : Icon(icon, color: color, size: 22),
      ),
    );
  }
}

/// Virtual Avatar picker bottom sheet — Bigo-style VTuber mode selection.
class _VirtualAvatarPickerSheet extends StatelessWidget {
  const _VirtualAvatarPickerSheet();

  @override
  Widget build(BuildContext context) {
    final svc = VirtualAvatarService.instance;
    final avatars = svc.avatars;
    final activeId = svc.activeAvatar?.id;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.account_circle,
                  color: Colors.tealAccent,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Virtual Avatar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (activeId != null)
                  GestureDetector(
                    onTap: () {
                      svc.clearAvatar();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Remove',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: avatars.length,
              itemBuilder: (ctx, i) {
                final a = avatars[i];
                final isActive = a.id == activeId;
                return GestureDetector(
                  onTap: () {
                    svc.selectAvatar(a);
                    svc.startTracking();
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          isActive
                              ? Colors.teal.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          isActive
                              ? Border.all(color: Colors.tealAccent, width: 2)
                              : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child:
                                a.previewUrl.startsWith('http')
                                    ? CachedNetworkImage(
                                      imageUrl: a.previewUrl,
                                      fit: BoxFit.cover,
                                      errorWidget:
                                          (_, __, ___) => const Center(
                                            child: Icon(
                                              Icons.account_circle,
                                              color: Colors.tealAccent,
                                              size: 40,
                                            ),
                                          ),
                                    )
                                    : Image.asset(
                                      a.previewUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (_, __, ___) => const Center(
                                            child: Icon(
                                              Icons.account_circle,
                                              color: Colors.tealAccent,
                                              size: 40,
                                            ),
                                          ),
                                    ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          a.name,
                          style: TextStyle(
                            color:
                                isActive ? Colors.tealAccent : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (a.isVipExclusive)
                          const Icon(Icons.star, color: Colors.amber, size: 10),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveComment {
  _LiveComment({
    this.name,
    this.text,
    this.userId,
    this.isMine = false,
    this.isVIP = false,
    this.isGift = false,
    this.isJoined = false,
    this.isSystem = false,
    this.isAdmin = false,
    this.isHost = false,
    this.isAgency = false,
    this.isBd = false,
    this.imageUrl,
    this.userImage,
    this.frameUrl,
    this.giftImage,
    this.giftCount = 1,
    this.giftCoins = 0,
    this.giftReceiverName,
    this.giftReceiverImage,
    this.cpLevel,
    this.friendLevel,
    this.relationshipType,
    this.vipStyle,
    this.vipLevel,
    this.levelName,
    this.country,
    this.countryFlagImage,
    this.familyName,
    this.familyBadgeUrl,
    this.isCard = false,
    this.cardImage,
    this.cardCta,
    this.cardAction,
    this.mentionedUserId,
    this.mentionedUserName,
    this.isSeatRequest = false,
    this.seatRequestUserId,
    this.badgeUrls = const [],
    this.tagLabels = const [],
  });
  final String? name;
  String? text;
  String? translatedText;
  final String? userId;
  final bool isMine;
  final bool isVIP;
  final bool isGift;
  final bool isJoined;
  final bool isSystem;
  final bool isAdmin;
  final bool isHost;
  final bool isAgency;
  final bool isBd;
  final String? imageUrl;
  final String? userImage;
  final String? frameUrl;
  final String? giftImage;
  final int giftCount;
  final int giftCoins;
  final String? giftReceiverName;
  final String? giftReceiverImage;
  final int? cpLevel;
  final int? friendLevel;
  final String? relationshipType;
  final VipChatStyle? vipStyle;
  final int? vipLevel;
  final String? levelName;
  final String? country;
  final String? countryFlagImage;
  final String? familyName;
  final String? familyBadgeUrl;
  final bool isCard;
  final String? cardImage;
  final String? cardCta;
  final String? cardAction;
  final String? mentionedUserId;
  final String? mentionedUserName;
  final bool isSeatRequest;
  final String? seatRequestUserId;
  final List<String> badgeUrls;
  final List<String> tagLabels;
}
