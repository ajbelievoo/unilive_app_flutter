/// Ported from native `HostPKLiveActivity.java` (8217 lines) + PK bottom sheets.
///
/// Full PK battle implementation: split-screen video, multi-round support,
/// score bars with Host1/Host2 perspective mapping, countdown timer with
/// network latency compensation, punishment round with task display,
/// top gifters tracking from gift events, PK invitation flow with waiting
/// popup, disconnect handling, vote system, PK comments overlay, and
/// rematch with full state reset.
library pk_battle;

import 'dart:async';
import 'dart:collection';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_token_generator/agora_token_generator.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../constants/const.dart';
import '../../models/pk_call_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../services/socket_service.dart';
import '../../utils/log.dart';
import '../../widgets/big_gift_overlay.dart';
import '../../widgets/gift_bottom_sheet.dart';
import '../../widgets/gift_overlay.dart';
import '../../widgets/pk_battle_sheets.dart';
import '../../widgets/pk_hand_raise_sheet.dart';
import '../../widgets/user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

const String _agoraAppIdFallback = String.fromEnvironment(
  'AGORA_APP_ID',
  defaultValue: '',
);

/// Network latency compensation in ms — subtracted from timer duration
/// so both hosts end at approximately the same time.
const int _networkLatencyMs = 500;

/// PK Battle screen — split-screen video with score bars.
class PkBattleScreen extends StatefulWidget {
  const PkBattleScreen({
    super.key,
    required this.config,
    required this.isHost1,
    this.isHost = false,
    this.existingEngine,
  });

  final PkConfig config;
  final bool isHost1;
  final bool isHost;
  final RtcEngine? existingEngine;

  @override
  State<PkBattleScreen> createState() => _PkBattleScreenState();
}

class _PkBattleScreenState extends State<PkBattleScreen> {
  static const String _tag = 'PK';

  // --- Agora engine ---
  late RtcEngine _engine;
  bool _engineReady = false;
  bool _engineInitialized = false;
  bool _ownsEngine = false;
  RtcEngineEventHandler? _eventHandler;

  // --- PK state (ported from native) ---
  int _pkRoundCount = 0;
  bool _isPkStart = false;
  bool _isPunishmentRound = false;
  bool _isPkStarting = false;
  bool _pkAutoStartBlocked = false;
  bool _isPkWinner = false;

  // --- Scores (Host1 perspective from backend) ---
  int _host1Score = 0;
  int _host2Score = 0;

  // --- Timer ---
  late int _secondsRemaining;
  int _battleDuration = 300;
  int _punishmentDuration = 0;
  Timer? _timer;

  // --- Top gifters (tracked locally from gift events) ---
  final Map<String, PkGifter> _host1Gifters = {};
  final Map<String, PkGifter> _host2Gifters = {};

  // --- Round history ---
  final _roundHistory = <PkRoundResult>[];

  // --- Vote counts ---
  int _pkVoteHost1 = 0;
  int _pkVoteHost2 = 0;
  bool _hasVoted = false;

  // --- PK comments overlay ---
  final Queue<PkComment> _comments = Queue();
  final int _maxComments = 50;

  // --- Gift overlay ---
  final _giftController = GiftQueueController();
  final _bigGiftController = BigGiftController();

  // --- Punishment task ---
  String? _punishmentTask;

  // --- Socket cancellers ---
  Function? _cancelPkStart;
  Function? _cancelPkEnd;
  Function? _cancelPkScore;
  Function? _cancelPkCheer;
  Function? _cancelPkPunishment;
  Function? _cancelPkRematch;
  Function? _cancelPkRequest;
  Function? _cancelPkRequestAnswer;
  Function? _cancelPkVote;
  Function? _cancelPkContinue;
  Function? _cancelGiftSub;
  Function? _cancelNormalGiftSub;
  Function? _cancelLiveUserGiftSub;
  Function? _cancelCommentSub;

  // --- Current PK config (updated on rematch) ---
  late PkConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _pkRoundCount = _config.pkRoundCount;
    _host1Score = _config.localRank;
    _host2Score = _config.remoteRank;
    _battleDuration = _config.durationSeconds;
    _punishmentDuration =
        _config.punishmentDurationSeconds > 0
            ? _config.punishmentDurationSeconds
            : _config.pkPunishmentEndTime;
    _isPunishmentRound = _config.isPunishmentActive;
    _pkAutoStartBlocked = _config.pkAutoStartBlocked;
    _punishmentTask = _config.punishmentTask;
    _secondsRemaining =
        _isPunishmentRound
            ? (_punishmentDuration > 0 ? _punishmentDuration : 60)
            : _battleDuration;
    // Apply network latency compensation to initial timer
    if (_secondsRemaining > 0) {
      _secondsRemaining = (_secondsRemaining - _networkLatencyMs ~/ 1000).clamp(
        0,
        _secondsRemaining,
      );
    }
    _initAgora();
    _listenSocketEvents();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancelPkStart?.call();
    _cancelPkEnd?.call();
    _cancelPkScore?.call();
    _cancelPkCheer?.call();
    _cancelPkPunishment?.call();
    _cancelPkRematch?.call();
    _cancelPkRequest?.call();
    _cancelPkRequestAnswer?.call();
    _cancelPkVote?.call();
    _cancelPkContinue?.call();
    _cancelGiftSub?.call();
    _cancelNormalGiftSub?.call();
    _cancelLiveUserGiftSub?.call();
    _cancelCommentSub?.call();
    _leaveAndRelease();
    super.dispose();
  }

  // ===========================================================================
  // Agora RTC — dual channel: own channel as broadcaster, opponent as audience
  // ===========================================================================
  Future<void> _initAgora() async {
    try {
      final session = context.read<SessionManager>();
      final appId = session.getSetting()?.agoraKey ?? _agoraAppIdFallback;
      if (appId.isEmpty) {
        Log.e(_tag, 'Agora app ID not configured', null, null);
        if (mounted) setState(() => _engineReady = true);
        return;
      }

      if (widget.existingEngine case final existing?) {
        _engine = existing;
        _engineInitialized = true;
        await _engine.enableVideo();
        await _engine.enableDualStreamMode(enabled: true);
        if (widget.isHost) {
          await _engine.setClientRole(
            role: ClientRoleType.clientRoleBroadcaster,
          );
          await _engine.updateChannelMediaOptions(
            const ChannelMediaOptions(
              clientRoleType: ClientRoleType.clientRoleBroadcaster,
              publishMicrophoneTrack: true,
              publishCameraTrack: true,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
            ),
          );
          await _startMediaRelay();
        } else {
          await _engine.setClientRole(role: ClientRoleType.clientRoleAudience);
          await _engine.updateChannelMediaOptions(
            const ChannelMediaOptions(
              clientRoleType: ClientRoleType.clientRoleAudience,
              publishMicrophoneTrack: false,
              publishCameraTrack: false,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
            ),
          );
        }
      } else {
        if (widget.isHost) {
          await [Permission.microphone, Permission.camera].request();
        }
        _engine = createAgoraRtcEngine();
        _ownsEngine = true;
        await _engine.initialize(
          RtcEngineContext(
            appId: appId,
            channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          ),
        );
        _engineInitialized = true;
        _registerAgoraEventHandler();
        await _engine.enableVideo();
        await _engine.enableAudio();
        await _engine.setAudioProfile(
          profile: AudioProfileType.audioProfileMusicHighQuality,
          scenario: AudioScenarioType.audioScenarioGameStreaming,
        );
        await _engine.enableDualStreamMode(enabled: true);

        final myChannel =
            widget.isHost1 ? _config.host1Channel : _config.host2Channel;
        if (widget.isHost) {
          final myToken =
              widget.isHost1 ? _config.host1Token : _config.host2Token;
          final myUid =
              widget.isHost1 ? _config.host1AgoraUID : _config.host2AgoraUID;
          await _engine.setClientRole(
            role: ClientRoleType.clientRoleBroadcaster,
          );
          await _engine.startPreview();
          await _engine.joinChannel(
            token: myToken ?? '',
            channelId: myChannel ?? '',
            options: const ChannelMediaOptions(
              clientRoleType: ClientRoleType.clientRoleBroadcaster,
              publishMicrophoneTrack: true,
              publishCameraTrack: true,
            ),
            uid: myUid,
          );
          await _startMediaRelay();
        } else {
          final appCertificate = session.getSetting()?.agoraCertificate;
          final audienceToken = _buildAudienceToken(
            appId: appId,
            appCertificate: appCertificate,
            channel: myChannel ?? '',
          );
          await _engine.setClientRole(role: ClientRoleType.clientRoleAudience);
          await _engine.joinChannel(
            token: audienceToken,
            channelId: myChannel ?? '',
            options: const ChannelMediaOptions(
              clientRoleType: ClientRoleType.clientRoleAudience,
              publishMicrophoneTrack: false,
              publishCameraTrack: false,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
            ),
            uid: 0,
          );
        }
      }

      _isPkStart = true;
      if (mounted) setState(() => _engineReady = true);
    } catch (e, s) {
      Log.e(_tag, 'initAgora failed', e, s);
      if (mounted) setState(() => _engineReady = true);
    }
  }

  void _registerAgoraEventHandler() {
    final handler = RtcEngineEventHandler(
      onJoinChannelSuccess:
          (conn, elapsed) => Log.d(_tag, 'joined ${conn.channelId}'),
      onUserJoined: (conn, uid, elapsed) => Log.d(_tag, 'remote joined: $uid'),
      onUserOffline:
          (conn, uid, reason) =>
              Log.d(_tag, 'remote offline: $uid reason=$reason'),
      onError: (err, msg) => Log.e(_tag, 'agora error $err: $msg'),
      onChannelMediaRelayStateChanged: (state, code) {
        Log.d(_tag, 'media relay state=$state, code=$code');
      },
    );
    _eventHandler = handler;
    _engine.registerEventHandler(handler);
  }

  Future<void> _startMediaRelay() async {
    final myChannel =
        widget.isHost1 ? _config.host1Channel : _config.host2Channel;
    final otherChannel =
        widget.isHost1 ? _config.host2Channel : _config.host1Channel;
    final myUid =
        widget.isHost1 ? _config.host1AgoraUID : _config.host2AgoraUID;
    final setting = context.read<SessionManager>().getSetting();
    final generatedSrcToken = _buildTokenForUid(
      appId: setting?.agoraKey ?? _agoraAppIdFallback,
      appCertificate: setting?.agoraCertificate,
      channel: myChannel ?? '',
      uid: myUid,
    );
    final generatedDestToken = _buildTokenForUid(
      appId: setting?.agoraKey ?? _agoraAppIdFallback,
      appCertificate: setting?.agoraCertificate,
      channel: otherChannel ?? '',
      uid: myUid,
    );
    final mySrcToken =
        generatedSrcToken.isNotEmpty
            ? generatedSrcToken
            : widget.isHost1
            ? (_config.host1SrcToken ?? _config.host1Token ?? '')
            : (_config.host2SrcToken ?? _config.host2Token ?? '');
    final destToken =
        generatedDestToken.isNotEmpty
            ? generatedDestToken
            : widget.isHost1
            ? (_config.host1RelayDestToken ?? _config.host2Token)
            : (_config.host2RelayDestToken ?? _config.host1Token);
    if (myChannel == null ||
        myChannel.isEmpty ||
        otherChannel == null ||
        otherChannel.isEmpty ||
        otherChannel == myChannel ||
        myUid <= 0 ||
        mySrcToken.isEmpty ||
        destToken?.isNotEmpty != true) {
      Log.e(
        _tag,
        'relay config incomplete: source=$myChannel destination=$otherChannel uid=$myUid sourceToken=${mySrcToken.isNotEmpty} destinationToken=${destToken?.isNotEmpty == true}',
      );
      return;
    }
    final relayConfig = ChannelMediaRelayConfiguration(
      srcInfo: ChannelMediaInfo(
        channelName: myChannel,
        token: mySrcToken,
        uid: myUid,
      ),
      destInfos: [
        ChannelMediaInfo(
          channelName: otherChannel,
          token: destToken,
          uid: myUid,
        ),
      ],
      destCount: 1,
    );
    Log.d(
      _tag,
      'startMediaRelay: src=$myChannel uid=$myUid -> dest=$otherChannel',
    );
    try {
      await _engine.stopChannelMediaRelay();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _engine.startOrUpdateChannelMediaRelay(relayConfig);
    final otherUid =
        widget.isHost1 ? _config.host2AgoraUID : _config.host1AgoraUID;
    if (otherUid > 0) {
      await _engine.setRemoteVideoStreamType(
        uid: otherUid,
        streamType: VideoStreamType.videoStreamHigh,
      );
    }
  }

  String _buildAudienceToken({
    required String appId,
    required String? appCertificate,
    required String channel,
  }) => _buildTokenForUid(
    appId: appId,
    appCertificate: appCertificate,
    channel: channel,
    uid: 0,
  );

  String _buildTokenForUid({
    required String appId,
    required String? appCertificate,
    required String channel,
    required int uid,
  }) {
    if (appId.isEmpty ||
        appCertificate == null ||
        appCertificate.isEmpty ||
        channel.isEmpty ||
        uid < 0) {
      return '';
    }
    try {
      return RtcTokenBuilder.buildTokenWithUid(
        appId: appId,
        appCertificate: appCertificate,
        channelName: channel,
        uid: uid,
        tokenExpireSeconds: 36000,
      );
    } catch (e) {
      Log.e(_tag, 'Agora UID token generation failed', e);
      return '';
    }
  }

  Future<void> _leaveAndRelease() async {
    if (!_engineInitialized) return;
    _engineInitialized = false;
    final handler = _eventHandler;
    if (handler != null) {
      _engine.unregisterEventHandler(handler);
      _eventHandler = null;
    }
    if (widget.isHost) {
      try {
        await _engine.stopChannelMediaRelay();
      } catch (_) {}
    }
    if (!_ownsEngine) return;
    try {
      await _engine.leaveChannel();
      await _engine.release();
    } catch (e) {
      Log.e(_tag, 'leave failed', e);
    }
  }

  // ===========================================================================
  // Socket events — all PK-related events
  // ===========================================================================
  void _listenSocketEvents() {
    // PK Start — restart countdown with new duration
    _cancelPkStart = SocketService.instance.on(Const.eventPkStart, (data) {
      Log.d(_tag, 'PK started');
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      if (map == null) return;
      final rawConfig = map['pkConfig'] ?? map['data'] ?? map;
      if (rawConfig is! Map) return;
      final config = PkConfig.fromJson(Map<String, dynamic>.from(rawConfig));
      if (config.pkId?.isNotEmpty != true || config.durationSeconds <= 0) {
        return;
      }
      _config = config;
      _pkRoundCount = config.pkRoundCount;
      _battleDuration = config.durationSeconds;
      _isPunishmentRound = false;
      _isPkStart = true;
      setState(() => _secondsRemaining = config.durationSeconds);
      _startCountdown();
    });

    // PK End — handle normal end and disconnect
    _cancelPkEnd = SocketService.instance.on(Const.eventPkEnd, (data) {
      Log.d(_tag, 'PK ended: $data');
      _timer?.cancel();
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      if (map == null) return;

      // Check for disconnect
      final isDisconnect =
          map['isDisconnect'] == true || map['disconnect'] == true;
      if (isDisconnect) {
        _handleDisconnect(map);
        return;
      }

      // Normal PK end
      final winner =
          (map['isWinner'] as num?)?.toInt() ??
          (map['winner'] as num?)?.toInt() ??
          0;
      final canRematch = map['canRematch'] == true;
      final h1Score = (map['host1Score'] as num?)?.toInt() ?? _host1Score;
      final h2Score = (map['host2Score'] as num?)?.toInt() ?? _host2Score;

      // Record round result
      _recordRoundResult(_pkRoundCount, h1Score, h2Score, winner);

      // Reset PK state
      _isPkStart = false;
      _isPunishmentRound = false;
      _pkAutoStartBlocked = true;
      _isPkStarting = false;

      setState(() {
        _host1Score = h1Score;
        _host2Score = h2Score;
      });

      _showResultSheet(winner, canRematch);
    });

    // PK Score Update — from backend, always Host1 perspective
    _cancelPkScore = SocketService.instance.on(Const.eventPkScoreUpdate, (
      data,
    ) {
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      if (map == null) return;
      final h1Score = (map['host1Score'] as num?)?.toInt();
      final h2Score = (map['host2Score'] as num?)?.toInt();
      setState(() {
        if (h1Score != null) _host1Score = h1Score;
        if (h2Score != null) _host2Score = h2Score;
      });
    });

    // PK Cheer
    _cancelPkCheer = SocketService.instance.on(Const.eventPkCheer, (data) {
      Log.d(_tag, 'cheer received: $data');
    });

    // PK Punishment Round — start punishment or show start button
    _cancelPkPunishment = SocketService.instance.on(
      Const.eventPkPunishmentRound,
      (data) {
        Log.d(_tag, 'punishment round: $data');
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;

        final showStartButton = map['showStartButton'] == true;
        if (showStartButton) {
          // Punishment complete — show start button for next round
          setState(() {
            _isPunishmentRound = false;
            _punishmentTask = null;
          });
          return;
        }

        // Check if punishment is active
        final isPunishment =
            map['isPKPunishment'] == true || map['isPunishmentActive'] == true;
        final punishmentDuration =
            (map['pkPunishmentDuration'] as num?)?.toInt() ?? 0;
        final winner = (map['winner'] as num?)?.toInt() ?? 0;
        final h1Score = (map['host1Score'] as num?)?.toInt() ?? _host1Score;
        final h2Score = (map['host2Score'] as num?)?.toInt() ?? _host2Score;

        // Record round result
        _recordRoundResult(_pkRoundCount, h1Score, h2Score, winner);

        if (isPunishment && punishmentDuration > 0) {
          // Start punishment round
          _punishmentDuration = punishmentDuration;
          _punishmentTask = PkPunishmentTasks.getTaskForRound(_pkRoundCount);
          setState(() {
            _isPunishmentRound = true;
            _host1Score = h1Score;
            _host2Score = h2Score;
            _secondsRemaining = punishmentDuration;
          });
          _startCountdown();
        } else {
          // No punishment (tie) — show start button
          setState(() {
            _isPunishmentRound = false;
            _host1Score = h1Score;
            _host2Score = h2Score;
          });
        }
      },
    );

    // PK Rematch / Continue PK — full state reset and restart
    _cancelPkRematch = SocketService.instance.on(Const.eventPkRematch, (data) {
      Log.d(_tag, 'PK rematch: $data');
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      final configMap = map?['pkConfig'] ?? map?['data'];
      if (configMap is Map<String, dynamic> && mounted) {
        // Full state reset
        _resetPkState();
        _config = PkConfig.fromJson(configMap);
        _pkRoundCount = _config.pkRoundCount;
        _battleDuration = _config.durationSeconds;
        setState(() {
          _host1Score = 0;
          _host2Score = 0;
          _secondsRemaining = _battleDuration;
          _isPunishmentRound = false;
        });
        _startCountdown();
      }
    });

    // PK Continue PK — alternative rematch event
    _cancelPkContinue = SocketService.instance.on(Const.eventPkContinuePk, (
      data,
    ) {
      Log.d(_tag, 'PK continue: $data');
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      final configMap = map?['data'] ?? map?['pkConfig'];
      if (configMap is Map<String, dynamic> && mounted) {
        _resetPkState();
        _config = PkConfig.fromJson(configMap);
        _pkRoundCount = _config.pkRoundCount;
        _battleDuration = _config.durationSeconds;
        setState(() {
          _host1Score = 0;
          _host2Score = 0;
          _secondsRemaining = _battleDuration;
          _isPunishmentRound = false;
        });
        _startCountdown();
      }
    });

    // PK Request — receive invitation from another host
    _cancelPkRequest = SocketService.instance.on(Const.eventPkRequest, (data) {
      Log.d(_tag, 'PK request received: $data');
      if (_isPkStarting) {
        Log.d(_tag, 'PK already starting, ignoring request');
        return;
      }
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      if (map == null) return;
      final host2Id = map['host2Id']?.toString() ?? '';
      final session = context.read<SessionManager>();
      final myId = session.userId;
      final isForMe = host2Id == myId;
      if (!isForMe) return;

      // Auto-accept for rematch (round count > 0 and not blocked)
      if (_pkRoundCount > 0 && !_pkAutoStartBlocked) {
        _isPkStarting = true;
        _emitPkRequestAnswer(map, accept: true);
        return;
      }

      // Show invitation popup
      if (mounted) {
        _showInvitationPopup(map);
      }
    });

    // PK Request Answer — response from invited host
    _cancelPkRequestAnswer = SocketService.instance.on(
      Const.eventPkRequestAnswer,
      (data) {
        Log.d(_tag, 'PK answer received: $data');
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;
        final isAccept = map['isAccept'] == true || map['ISACCEPT'] == true;
        _isPkStarting = false;
        if (isAccept) {
          Fluttertoast.showToast(msg: 'PK accepted. Connecting...');
        } else {
          Fluttertoast.showToast(msg: 'PK request rejected');
        }
      },
    );

    // PK Vote — update vote counts
    _cancelPkVote = SocketService.instance.on(Const.eventPkVote, (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      if (map == null) return;
      final host1Id = map['host1Id']?.toString();
      final host2Id = map['host2Id']?.toString();
      final count = (map['count'] as num?)?.toInt();
      final voteHost1 = (map['pkVoteHost1'] as num?)?.toInt();
      final voteHost2 = (map['pkVoteHost2'] as num?)?.toInt();
      setState(() {
        if (voteHost1 != null) {
          _pkVoteHost1 = voteHost1;
        } else if (host1Id != null && count != null) {
          _pkVoteHost1 = count;
        }
        if (voteHost2 != null) {
          _pkVoteHost2 = voteHost2;
        } else if (host2Id != null && count != null) {
          _pkVoteHost2 = count;
        }
      });
    });

    // Gift events — track gifters per host + display
    _cancelGiftSub = SocketService.instance.on(Const.eventGift, (data) {
      _processGift(data);
    });
    _cancelNormalGiftSub = SocketService.instance.on(
      Const.eventNormalUserGift,
      (data) {
        _processGift(data);
      },
    );
    _cancelLiveUserGiftSub = SocketService.instance.on(
      Const.eventLiveUserGift,
      (data) {
        _processGift(data);
      },
    );

    // PK Comments
    _cancelCommentSub = SocketService.instance.on(Const.eventComment, (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      if (map == null) return;
      final comment = PkComment.fromJson(map);
      _comments.add(comment);
      while (_comments.length > _maxComments) {
        _comments.removeFirst();
      }
      setState(() {});
    });
  }

  // ===========================================================================
  // Gift processing — track gifters per host + display gift animation
  // ===========================================================================
  void _processGift(dynamic data) {
    final event = GiftQueueController.fromSocketData(data);
    if (event != null) {
      // Full-screen big overlay for SVGA / video / high-coin gifts, small
      // overlay for cheap image gifts — matches video/audio room behavior.
      if (_bigGiftController.isBigGift(event)) {
        _bigGiftController.showBigGift(event);
      } else {
        _giftController.addGift(event);
      }
    }

    // Extract sender/receiver IDs and coin amount for gifter tracking
    try {
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      if (map == null) return;
      final senderId =
          map['senderId']?.toString() ?? map['userId']?.toString() ?? '';
      final senderName =
          map['senderName']?.toString() ?? map['name']?.toString() ?? 'Someone';
      final senderImage =
          map['senderImage']?.toString() ?? map['userImage']?.toString() ?? '';
      final receiverId =
          map['receiverId']?.toString() ?? map['liveUserId']?.toString() ?? '';
      final nested =
          map['gift'] is Map
              ? Map<String, dynamic>.from(map['gift'] as Map)
              : <String, dynamic>{};
      final coin =
          (map['coin'] as num?)?.toInt() ??
          (nested['coin'] as num?)?.toInt() ??
          0;
      final count =
          (map['count'] as num?)?.toInt() ??
          (map['giftCount'] as num?)?.toInt() ??
          1;
      final giftAmount = coin * count;

      if (giftAmount <= 0 || senderId.isEmpty) return;

      // Determine which host received the gift
      final h1Id = _config.host1Id ?? '';
      final h2Id = _config.host2Id ?? '';
      if (receiverId == h1Id) {
        _updateGifterMap(
          _host1Gifters,
          senderId,
          senderName,
          senderImage,
          giftAmount,
        );
        _host1Score += giftAmount;
      } else if (receiverId == h2Id) {
        _updateGifterMap(
          _host2Gifters,
          senderId,
          senderName,
          senderImage,
          giftAmount,
        );
        _host2Score += giftAmount;
      }
      setState(() {});
    } catch (e) {
      Log.e(_tag, 'processGift error', e);
    }
  }

  void _updateGifterMap(
    Map<String, PkGifter> map,
    String senderId,
    String name,
    String image,
    int amount,
  ) {
    final existing = map[senderId];
    if (existing != null) {
      existing.amount += amount;
    } else {
      map[senderId] = PkGifter(
        userId: senderId,
        name: name,
        image: image,
        amount: amount,
      );
    }
  }

  List<PkGifter> _getTopGifters(Map<String, PkGifter> map, {int limit = 3}) {
    final list = map.values.toList();
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list.take(limit).toList();
  }

  // ===========================================================================
  // Timer — with network latency compensation and punishment/battle modes
  // ===========================================================================
  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        _onTimerFinish();
      }
    });
  }

  /// Called when the countdown timer reaches 0.
  /// Host emits PK end/punishment event with final scores and winner.
  void _onTimerFinish() {
    if (!widget.isHost || !widget.isHost1) return; // Only Host1 emits

    final h1Id = _config.host1Id ?? '';
    final h2Id = _config.host2Id ?? '';

    // Determine winner from scores (Host1 perspective)
    int winner;
    if (_host1Score > _host2Score) {
      winner = 2; // Host1 wins
    } else if (_host2Score > _host1Score) {
      winner = 1; // Host2 wins
    } else {
      winner = 0; // Tie
    }

    Log.d(
      _tag,
      'onTimerFinish: winner=$winner h1=$_host1Score h2=$_host2Score punishment=$_isPunishmentRound',
    );

    try {
      final payload = <String, dynamic>{
        Const.pkHost1Id: h1Id,
        Const.pkHost2Id: h2Id,
        Const.pkHost1LiveId: _config.host1LiveId,
        Const.pkHost2LiveId: _config.host2LiveId,
        Const.pkHost1Score: _host1Score,
        Const.pkHost2Score: _host2Score,
        Const.pkWinner: winner,
      };

      if (_isPunishmentRound) {
        // Punishment timer ended — show start button for next round
        setState(() => _isPunishmentRound = false);
        payload[Const.pkShowStartButton] = true;
        payload[Const.pkRoundCount] = _pkRoundCount;
        SocketService.instance.emit(Const.eventPkPunishmentRound, payload);
        Log.d(
          _tag,
          'onTimerFinish: punishment complete, emitted showStartButton',
        );
      } else {
        // Battle timer ended — determine winner, start punishment or end
        if (winner == 2) {
          _isPkWinner = widget.isHost1; // Host1 wins
          _isPunishmentRound = !_isPunishmentRound;
          setState(() {});
        } else if (winner == 1) {
          _isPkWinner = !widget.isHost1; // Host2 wins
          _isPunishmentRound = !_isPunishmentRound;
          setState(() {});
        } else {
          _isPunishmentRound = false;
          payload[Const.pkShowStartButton] = true;
        }
        payload[Const.pkIsPunishment] = _isPunishmentRound;
        payload[Const.pkRoundCount] = _pkRoundCount;
        SocketService.instance.emit(Const.eventPkPunishmentRound, payload);
        Log.d(_tag, 'onTimerFinish: battle ended, emitted punishment round');
      }
    } catch (e) {
      Log.e(_tag, 'onTimerFinish error', e);
    }
  }

  // ===========================================================================
  // Round history recording
  // ===========================================================================
  void _recordRoundResult(
    int roundNumber,
    int h1Score,
    int h2Score,
    int winner,
  ) {
    final h1Name = _config.host1Name ?? 'Host 1';
    final h2Name = _config.host2Name ?? 'Host 2';
    if (_roundHistory.isEmpty ||
        _roundHistory.last.roundNumber != roundNumber) {
      _roundHistory.add(
        PkRoundResult(
          roundNumber: roundNumber,
          host1Score: h1Score,
          host2Score: h2Score,
          winner: winner,
          host1Name: h1Name,
          host2Name: h2Name,
        ),
      );
    } else {
      final idx = _roundHistory.length - 1;
      _roundHistory[idx] = PkRoundResult(
        roundNumber: roundNumber,
        host1Score: h1Score,
        host2Score: h2Score,
        winner: winner,
        host1Name: h1Name,
        host2Name: h2Name,
      );
    }
  }

  // ===========================================================================
  // PK state reset
  // ===========================================================================
  void _resetPkState() {
    _pkRoundCount = 0;
    _isPkStart = false;
    _isPunishmentRound = false;
    _isPkStarting = false;
    _pkAutoStartBlocked = false;
    _isPkWinner = false;
    _host1Score = 0;
    _host2Score = 0;
    _pkVoteHost1 = 0;
    _pkVoteHost2 = 0;
    _hasVoted = false;
    _punishmentTask = null;
    _host1Gifters.clear();
    _host2Gifters.clear();
    _comments.clear();
  }

  // ===========================================================================
  // Disconnect handling
  // ===========================================================================
  void _handleDisconnect(Map<String, dynamic> map) {
    final liveUserId = map['liveUserId']?.toString();
    final session = context.read<SessionManager>();
    final myId = session.userId;

    if (liveUserId == myId) {
      // Current user disconnected — end live
      Navigator.pop(context);
      return;
    }

    // Clean up PK state for non-disconnected users
    _pkAutoStartBlocked = true;
    _isPunishmentRound = false;
    _isPkStarting = false;
    _host1Gifters.clear();
    _host2Gifters.clear();
    setState(() {
      _host1Score = 0;
      _host2Score = 0;
      _pkRoundCount = 0;
      _isPkStart = false;
      _punishmentTask = null;
    });
    Fluttertoast.showToast(msg: 'Opponent disconnected');
  }

  // ===========================================================================
  // PK invitation — show popup and handle accept/reject
  // ===========================================================================
  void _showInvitationPopup(Map<String, dynamic> map) {
    final host1Name = map['host1Name']?.toString() ?? 'Host';
    final host1Image = map['host1Image']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => PkInvitationSheet(
            hostName: host1Name,
            hostImage: host1Image,
            onAccept: () {
              Navigator.pop(ctx);
              _emitPkRequestAnswer(map, accept: true);
            },
            onReject: () {
              Navigator.pop(ctx);
              _emitPkRequestAnswer(map, accept: false);
            },
          ),
    );
  }

  void _emitPkRequestAnswer(
    Map<String, dynamic> requestMap, {
    required bool accept,
  }) {
    try {
      final payload = <String, dynamic>{
        ...requestMap,
        Const.pkHost1Id: requestMap['host1Id'],
        Const.pkHost2Id: requestMap['host2Id'],
        Const.pkHost1LiveId: requestMap['host1LiveId'],
        Const.pkHost2LiveId: requestMap['host2LiveId'],
        Const.pkHost1Name: requestMap['host1Name'],
        Const.pkHost2Name: requestMap['host2Name'],
        Const.pkHost1Image: requestMap['host1Image'],
        Const.pkHost2Image: requestMap['host2Image'],
        Const.pkHost1Channel: requestMap['host1Channel'],
        Const.pkHost2Channel: requestMap['host2Channel'],
        Const.pkHost1AgoraId:
            requestMap['host1AgoraId'] ?? requestMap['host1AgoraUID'],
        Const.pkHost2AgoraId:
            requestMap['host2AgoraId'] ?? requestMap['host2AgoraUID'],
        Const.pkIsAccept: accept,
      };
      SocketService.instance.emit(Const.eventPkRequestAnswer, payload);
      Log.d(_tag, 'emitPkRequestAnswer: accept=$accept');
    } catch (e) {
      Log.e(_tag, 'emitPkRequestAnswer error', e);
    }
  }

  // ===========================================================================
  // PK actions
  // ===========================================================================
  Future<void> _endPk() async {
    if (!widget.isHost) {
      if (mounted) Navigator.pop(context);
      return;
    }
    try {
      // Emit PK end event
      final payload = <String, dynamic>{
        'pkId': _config.pkId,
        Const.pkHost1Id: _config.host1Id,
        Const.pkHost2Id: _config.host2Id,
        Const.pkHost1LiveId: _config.host1LiveId,
        Const.pkHost2LiveId: _config.host2LiveId,
        Const.pkIsPunishment: false,
      };
      SocketService.instance.emit(Const.eventPkEnd, payload);
      if (_config.pkId?.isNotEmpty == true) {
        await ApiService.endPkCall(pkId: _config.pkId!, winnerId: '');
      }
    } catch (e) {
      Log.e(_tag, 'endPk failed', e);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _requestRematch() async {
    try {
      // Emit rematch via socket
      final payload = <String, dynamic>{
        Const.pkHost1Id: _config.host1Id,
        Const.pkHost2Id: _config.host2Id,
      };
      SocketService.instance.emit(Const.eventPkRematch, payload);
      // Also call API to create new PK
      await ApiService.createPkCall(
        hostId: _config.host1Id ?? '',
        guestId: _config.host2Id ?? '',
      );
      Fluttertoast.showToast(msg: 'Rematch request sent');
    } catch (e) {
      Log.e(_tag, 'rematch failed', e);
      Fluttertoast.showToast(msg: 'Rematch failed');
    }
  }

  void _sendCheer() {
    SocketService.instance.emit(Const.eventPkCheer, {
      Const.pkHost1Id: _config.host1Id,
      Const.pkHost2Id: _config.host2Id,
    });
  }

  void _sendVote(int hostNumber) {
    if (_hasVoted) {
      Fluttertoast.showToast(msg: 'You already voted');
      return;
    }
    final voteHostId = hostNumber == 1 ? _config.host1Id : _config.host2Id;
    SocketService.instance.emit(Const.eventPkVote, {
      Const.pkHost1Id: _config.host1Id,
      Const.pkHost2Id: _config.host2Id,
      'voteHostId': voteHostId,
      'hostNumber': hostNumber,
    });
    setState(() {
      _hasVoted = true;
      if (hostNumber == 1) {
        _pkVoteHost1++;
      } else {
        _pkVoteHost2++;
      }
    });
  }

  // ===========================================================================
  // Result sheet
  // ===========================================================================
  void _showResultSheet(int winner, bool canRematch) {
    _isPkWinner =
        (winner == 2 && widget.isHost1) || (winner == 1 && !widget.isHost1);
    Log.d(_tag, 'showResultSheet: winner=$winner isPkWinner=$_isPkWinner');
    showPkResultSheet(
      context,
      winner: winner,
      isHost1: widget.isHost1,
      host1Score: _host1Score,
      host2Score: _host2Score,
      host1Name: _config.host1Name,
      host2Name: _config.host2Name,
      canRematch: canRematch && widget.isHost,
      onDone: () => Navigator.pop(context),
      onRematch: widget.isHost ? _requestRematch : () {},
    );
  }

  // ===========================================================================
  // UI — build
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body:
            !_engineReady
                ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Preloader(),
                      SizedBox(height: 12),
                      Text(
                        'Starting PK battle...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                )
                : LayoutBuilder(
                  builder: (context, constraints) {
                    final widthBasedHeight = (constraints.maxWidth * 0.86)
                        .clamp(220.0, 340.0);
                    final heightBasedLimit = (constraints.maxHeight - 320)
                        .clamp(220.0, 340.0);
                    final videoHeight =
                        widthBasedHeight < heightBasedLimit
                            ? widthBasedHeight
                            : heightBasedLimit;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/images/pk_bg_fot.webp',
                            fit: BoxFit.cover,
                          ),
                        ),
                        SafeArea(
                          child: Column(
                            children: [
                              _buildTopBar(),
                              _buildMatchHeader(),
                              SizedBox(
                                height: videoHeight,
                                child: _buildSplitVideo(),
                              ),
                              _buildScoreBars(),
                              _buildVoteBars(),
                              _buildTopGifters(),
                              const Spacer(),
                              _buildBottomControls(),
                            ],
                          ),
                        ),
                        // PK comments overlay
                        Positioned(
                          left: 12,
                          bottom: 118,
                          child: _buildCommentsOverlay(),
                        ),
                        // Gift animation overlay
                        GiftOverlay(controller: _giftController),
                        BigGiftOverlay(controller: _bigGiftController),
                      ],
                    );
                  },
                ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.black87,
            title: const Text(
              'Leave PK?',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Do you want to exit the PK battle?',
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
                  _endPk();
                },
                child: const Text('Exit', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  // --- Top bar with timer, round count, history, ranking ---
  String _hostDisplayName(bool host1) {
    final name =
        host1
            ? (_config.host1Name ?? _config.host1Details?.name)
            : (_config.host2Name ?? _config.host2Details?.name);
    if (name?.trim().isNotEmpty == true) return name!.trim();
    final id = host1 ? _config.host1Id : _config.host2Id;
    if (id?.isNotEmpty == true) {
      return 'Host ${id!.length > 6 ? id.substring(id.length - 6) : id}';
    }
    return host1 ? 'Host 1' : 'Host 2';
  }

  String? _hostDisplayImage(bool host1) =>
      host1
          ? (_config.host1Image ?? _config.host1Details?.image)
          : (_config.host2Image ?? _config.host2Details?.image);

  String get _leftHostName => _hostDisplayName(widget.isHost1);
  String get _rightHostName => _hostDisplayName(!widget.isHost1);
  String? get _leftHostImage => _hostDisplayImage(widget.isHost1);
  String? get _rightHostImage => _hostDisplayImage(!widget.isHost1);

  Widget _buildTopBar() {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final timerColor = _isPunishmentRound ? Colors.purple : Colors.red;
    final timerLabel = _isPunishmentRound ? 'PUNISHMENT' : 'PK';

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => _showExitDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Round History',
            onPressed:
                () => showPkRoundHistorySheet(
                  context,
                  history: _roundHistory,
                  host1Name: _config.host1Name ?? 'Host 1',
                  host2Name: _config.host2Name ?? 'Host 2',
                ),
          ),
          if (_pkRoundCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Round $_pkRoundCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              final hostId = widget.isHost1 ? _config.host1Id : _config.host2Id;
              if (hostId != null && hostId.isNotEmpty) {
                showFansRankingSheet(context, hostUserId: hostId);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: timerColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$timerLabel \u00b7 $minutes:$seconds',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.emoji_events, color: Colors.amber),
            tooltip: 'Fans Ranking',
            onPressed: () {
              final hostId = widget.isHost1 ? _config.host1Id : _config.host2Id;
              if (hostId != null && hostId.isNotEmpty) {
                showFansRankingSheet(context, hostUserId: hostId);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMatchHeader() {
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: _buildMatchHost(
                name: _leftHostName,
                image: _leftHostImage,
                color: const Color(0xFF168CFF),
                alignEnd: false,
              ),
            ),
            Image.asset(
              'assets/images/live_pk_blue.webp',
              width: 48,
              height: 40,
              fit: BoxFit.contain,
            ),
            Expanded(
              child: _buildMatchHost(
                name: _rightHostName,
                image: _rightHostImage,
                color: const Color(0xFFFF2D75),
                alignEnd: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchHost({
    required String name,
    required String? image,
    required Color color,
    required bool alignEnd,
  }) {
    final avatar = UserAvatar(imageUrl: image, size: 36);
    final label = Flexible(
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisAlignment:
            alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children:
            alignEnd
                ? [label, const SizedBox(width: 7), avatar]
                : [avatar, const SizedBox(width: 7), label],
      ),
    );
  }

  // --- Split-screen video with punishment overlay ---
  Widget _buildSplitVideo() {
    // With media relay, the opponent's video is relayed into OUR channel,
    // so we render it using our own channel + the opponent's UID.
    final myChannel =
        widget.isHost1 ? _config.host1Channel : _config.host2Channel;
    final localUid =
        widget.isHost1 ? _config.host1AgoraUID : _config.host2AgoraUID;
    final otherUid =
        widget.isHost1 ? _config.host2AgoraUID : _config.host1AgoraUID;

    // Host1 perspective: local on left, remote on right
    // Host2 perspective: local on left (mirrored), remote on right
    final localName = _leftHostName;
    final remoteName = _rightHostName;
    final localImage = _leftHostImage;
    final remoteImage = _rightHostImage;

    return Stack(
      children: [
        Row(
          children: [
            // Local video
            Expanded(
              child: _buildPkVideoTile(
                uid: localUid,
                name: localName,
                image: localImage,
                channel: myChannel ?? '',
                isLocal: widget.isHost,
                isLeft: true,
              ),
            ),
            // Remote video
            Expanded(
              child: _buildPkVideoTile(
                uid: otherUid,
                name: remoteName,
                image: remoteImage,
                channel: myChannel ?? '',
                isLocal: false,
                isLeft: false,
              ),
            ),
          ],
        ),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset(
              'assets/images/live_pk_icon_vs.webp',
              width: 58,
              height: 48,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          left: MediaQuery.sizeOf(context).width / 2 - 0.5,
          child: Container(
            width: 1,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
        // Punishment overlay
        if (_isPunishmentRound)
          Positioned.fill(
            child: Container(
              color: Colors.red.withValues(alpha: 0.25),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.gavel, color: Colors.red, size: 40),
                      const SizedBox(height: 8),
                      const Text(
                        'PUNISHMENT ROUND',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_punishmentTask != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _punishmentTask!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${_secondsRemaining}s remaining',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPkVideoTile({
    required int uid,
    required String name,
    required String channel,
    required bool isLocal,
    required bool isLeft,
    String? image,
  }) {
    final color = isLeft ? const Color(0xFF168CFF) : const Color(0xFFFF2D75);
    final video =
        isLocal
            ? AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _engine,
                canvas: const VideoCanvas(
                  uid: 0,
                  renderMode: RenderModeType.renderModeHidden,
                  mirrorMode: VideoMirrorModeType.videoMirrorModeEnabled,
                ),
                useFlutterTexture: true,
                useAndroidSurfaceView: false,
              ),
            )
            : uid > 0 && channel.isNotEmpty
            ? AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine,
                canvas: VideoCanvas(
                  uid: uid,
                  renderMode: RenderModeType.renderModeHidden,
                  mirrorMode: VideoMirrorModeType.videoMirrorModeDisabled,
                ),
                connection: RtcConnection(channelId: channel),
                useFlutterTexture: true,
                useAndroidSurfaceView: false,
              ),
            )
            : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(imageUrl: image, size: 76),
                  const SizedBox(height: 10),
                  const Text(
                    'Connecting...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.3), Colors.black],
        ),
        border: Border(bottom: BorderSide(color: color, width: 3)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          video,
          Positioned(
            top: 8,
            left: isLeft ? 8 : null,
            right: isLeft ? null : 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isLocal ? 'YOU' : (isLeft ? 'HOST' : 'RIVAL'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: isLeft ? 8 : null,
            right: isLeft ? null : 8,
            child: _buildNameLabel(name),
          ),
        ],
      ),
    );
  }

  Widget _buildNameLabel(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        name,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  // --- Score bars (Host1 perspective: left=Host1, right=Host2) ---
  Widget _buildScoreBars() {
    final total = (_host1Score + _host2Score).clamp(1, 999999999);
    final host1Percent = (_host1Score / total * 100).clamp(0.0, 100.0);
    // For Host2 perspective, mirror the bars
    final leftScore = widget.isHost1 ? _host1Score : _host2Score;
    final rightScore = widget.isHost1 ? _host2Score : _host1Score;
    final leftPercent = widget.isHost1 ? host1Percent : (100.0 - host1Percent);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$leftScore',
                  style: const TextStyle(
                    color: Color(0xFF35A7FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              Image.asset(
                'assets/images/live_pk_blue.webp',
                width: 38,
                height: 24,
              ),
              Expanded(
                child: Text(
                  '$rightScore',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Color(0xFFFF4F87),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: leftPercent / 100,
              minHeight: 9,
              backgroundColor: const Color(0xFFFF2D75),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF168CFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Vote bars (viewer voting) ---
  Widget _buildVoteBars() {
    if (!_isPkStart) return const SizedBox.shrink();
    final totalVotes = (_pkVoteHost1 + _pkVoteHost2).clamp(1, 999999);
    final host1VotePercent = (_pkVoteHost1 / totalVotes * 100).clamp(
      0.0,
      100.0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _sendVote(1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _hasVoted
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: Colors.blue,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_pkVoteHost1',
                      style: const TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Text(
                'Vote',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              GestureDetector(
                onTap: () => _sendVote(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_pkVoteHost2',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _hasVoted
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: Colors.orange,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: host1VotePercent / 100,
              minHeight: 4,
              backgroundColor: Colors.orange,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  // --- Top gifters (per host, tracked from gift events) ---
  Widget _buildTopGifters() {
    final leftGifters =
        widget.isHost1
            ? _getTopGifters(_host1Gifters)
            : _getTopGifters(_host2Gifters);
    final rightGifters =
        widget.isHost1
            ? _getTopGifters(_host2Gifters)
            : _getTopGifters(_host1Gifters);

    if (leftGifters.isEmpty && rightGifters.isEmpty) {
      // Fall back to config top gifters if no live tracking
      if (_config.topGifters.isEmpty) return const SizedBox.shrink();
      return _buildConfigTopGifters();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(child: _buildGifterList(leftGifters, Colors.blue)),
          const SizedBox(width: 4),
          Expanded(child: _buildGifterList(rightGifters, Colors.orange)),
        ],
      ),
    );
  }

  Widget _buildConfigTopGifters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Gifters',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _config.topGifters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final g = _config.topGifters[i];
                return Chip(
                  avatar: UserAvatar(imageUrl: g.image, size: 24),
                  label: Text(
                    '${g.name ?? ''} ${g.coin}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.white10,
                  padding: EdgeInsets.zero,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGifterList(List<PkGifter> gifters, Color color) {
    if (gifters.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: gifters.length,
        itemBuilder: (_, i) {
          final g = gifters[i];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(imageUrl: g.image, size: 28),
                const SizedBox(height: 2),
                Text(
                  '${g.amount}',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Bottom controls ---
  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _showCommentInput,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white70,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Say hi...',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          _pkActionButton(Icons.celebration, _sendCheer),
          const SizedBox(width: 7),
          _pkActionButton(
            null,
            _showGiftSheet,
            imageAsset: 'assets/gift/icon_gift.png',
            bg: const Color(0xFFFFEA00),
          ),
          const SizedBox(width: 7),
          _pkActionButton(Icons.pan_tool_alt, _showHandRaise),
          if (widget.isHost) ...[
            const SizedBox(width: 7),
            _pkActionButton(Icons.close, _showExitDialog, color: Colors.red),
          ],
        ],
      ),
    );
  }

  Widget _pkActionButton(
    IconData? icon,
    VoidCallback onTap, {
    Color color = Colors.white,
    String? imageAsset,
    Color? bg,
  }) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: bg ??
              color.withValues(alpha: color == Colors.white ? 0.15 : 0.8),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12),
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
              : null,
        ),
        child: imageAsset != null
            ? Image.asset(imageAsset, width: 16, height: 16)
            : Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // --- Comments overlay ---
  Widget _buildCommentsOverlay() {
    if (_comments.isEmpty) return const SizedBox.shrink();
    final list = _comments.toList();
    return Container(
      constraints: const BoxConstraints(maxWidth: 250, maxHeight: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            List.generate(list.length.clamp(0, 6), (i) {
              final idx = list.length - 1 - i;
              if (idx < 0) return const SizedBox.shrink();
              final c = list[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.image != null && c.image!.isNotEmpty)
                        UserAvatar(imageUrl: c.image, size: 20),
                      if (c.image != null && c.image!.isNotEmpty)
                        const SizedBox(width: 6),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${c.name ?? ''}: ',
                                style: const TextStyle(
                                  color: Colors.yellow,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: c.message ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).reversed.toList(),
      ),
    );
  }

  // --- Comment input ---
  void _showCommentInput() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Send a comment...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          SocketService.instance.emit(Const.eventComment, {
                            'liveStreamingId': _config.host1LiveId,
                            'message': value,
                            'type': 'comment',
                          });
                        }
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.purple),
                    onPressed: () {
                      if (controller.text.isNotEmpty) {
                        SocketService.instance.emit(Const.eventComment, {
                          'liveStreamingId': _config.host1LiveId,
                          'message': controller.text,
                          'type': 'comment',
                        });
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // --- Gift sheet ---
  void _showGiftSheet() {
    final receiverId = widget.isHost1 ? _config.host2Id : _config.host1Id;
    final session = context.read<SessionManager>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => GiftBottomSheet(
            receiverId: receiverId ?? '',
            liveStreamingId: _config.host1LiveId,
            type: 'pk',
            // PK live was missing onGiftSent — the sender never saw the
            // gift animation locally (only the screen shake fired from the
            // socket echo, which may not arrive). Now we play the gift
            // immediately on the sender side, matching video/audio live.
            onGiftSent: ({
              required giftId,
              required giftName,
              required giftImage,
              svgaImage,
              giftType = 0,
              required count,
              required totalCoins,
              bool isLucky = false,
            }) {
              final giftEvent = GiftEvent(
                giftId: giftId,
                giftName: giftName,
                giftImage: giftImage,
                svgaImage: svgaImage,
                giftType: giftType,
                coin: totalCoins ~/ count,
                senderName: session.userName,
                senderId: session.userId,
                senderImage: session.userImage,
                receiverName: 'Opponent',
                count: count,
                timeStamp: DateTime.now().millisecondsSinceEpoch,
              );
              if (_bigGiftController.isBigGift(giftEvent)) {
                _bigGiftController.showBigGift(giftEvent);
              } else {
                _giftController.addGift(giftEvent);
              }
            },
          ),
    );
  }

  // --- Hand raise ---
  void _showHandRaise() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => PkHandRaiseSheet(
            isHost: true,
            liveStreamingId: _config.host1LiveId ?? '',
          ),
    );
  }
}

/// PK Invitation bottom sheet — shows when a PK request is received.
class PkInvitationSheet extends StatelessWidget {
  const PkInvitationSheet({
    super.key,
    required this.hostName,
    required this.hostImage,
    required this.onAccept,
    required this.onReject,
  });

  final String hostName;
  final String? hostImage;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const Text(
            'PK Battle Invitation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          UserAvatar(imageUrl: hostImage, size: 80),
          const SizedBox(height: 12),
          Text(
            hostName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'wants to start a PK battle with you',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7E3FF2),
                  ),
                  child: const Text('Accept PK'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
