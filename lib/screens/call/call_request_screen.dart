import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../constants/const.dart';
import '../../models/pk_call_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../services/socket_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../routes/app_routes.dart';
import '../../screens/chat/chat_screen.dart';
import 'package:belive/widgets/preloader.dart';

class CallRequestScreen extends StatefulWidget {
  const CallRequestScreen({
    super.key,
    required this.userId2,
    required this.userName,
    required this.userImage,
    required this.isAudioCall,
    this.callRate = 0,
    this.callType,
    this.isFreeCall = false,
    this.freeTrialSeconds = 0,
  });

  final String userId2;
  final String userName;
  final String? userImage;
  final bool isAudioCall;
  final int callRate;
  final String? callType;
  final bool isFreeCall;
  final int freeTrialSeconds;

  @override
  State<CallRequestScreen> createState() => _CallRequestScreenState();
}

class _CallRequestScreenState extends State<CallRequestScreen> {
  static const String _tag = 'CallRequest';
  Timer? _timeoutTimer;
  Timer? _pulseTimer;
  bool _cancelling = false;
  String? _callRoomId;
  int _callRate = 0;
  int _freeTrialSeconds = 0;
  Function? _cancelCallCancel;
  Function? _cancelCallReceive;
  Function? _cancelCallAnswer;
  final AudioPlayer _ringbackPlayer = AudioPlayer();

  // Local controls while waiting for answer.
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _cameraOff = false;
  bool _isAudio = false;

  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _isAudio = widget.isAudioCall;
    _statusText = _isAudio ? 'Audio calling...' : 'Video calling...';
    _startRingback();
    _initiateCall();
  }

  @override
  void dispose() {
    _stopRingback();
    _timeoutTimer?.cancel();
    _pulseTimer?.cancel();
    _cancelCallCancel?.call();
    _cancelCallReceive?.call();
    _cancelCallAnswer?.call();
    super.dispose();
  }

  Future<void> _startRingback() async {
    try {
      await _ringbackPlayer.setVolume(1.0);
      await _ringbackPlayer.setLoopMode(LoopMode.one);
      await _ringbackPlayer.setAsset('assets/sounds/ringtone.mp3');
      await _ringbackPlayer.play();
      Log.d(_tag, 'ringback playing');
    } catch (e) {
      Log.e(_tag, 'ringback failed', e);
      _startVibration();
    }
  }

  void _startVibration() {
    HapticFeedback.vibrate();
  }

  void _stopRingback() {
    try {
      // Stop then dispose in a chained future; calling stop() and dispose()
      // synchronously can trigger just_audio's "complete a future with itself"
      // error when the platform future is still in flight.
      _ringbackPlayer.stop().then((_) => _ringbackPlayer.dispose()).catchError((e) {
        Log.e(_tag, 'ringback dispose error', e);
      });
    } catch (e) {
      Log.e(_tag, 'stop ringback failed', e);
    }
  }

  Future<void> _initiateCall() async {
    final session = context.read<SessionManager>();
    final navigator = Navigator.of(context);
    try {
      final res = await ApiService.callRequest(
        callerUserId: session.userId,
        receiverUserId: widget.userId2,
        callType: widget.callType ?? session.getUser()?.gender ?? 'Male',
        isFreeCall: widget.isFreeCall,
        freeTrialSeconds: widget.freeTrialSeconds,
      );

      if (res.status && res.callId != null) {
        _callRoomId = res.callId;
        _callRate = res.callRate;
        _freeTrialSeconds = res.freeTrialSeconds;
        // After API success, emit socket event to notify receiver (matches native)
        SocketService.instance.emit(Const.eventCallRequest, {
          Const.userId1: widget.userId2,
          Const.userId2: session.userId,
          'user2Name': session.userName,
          'user2Image': session.userImage,
          'user2ImageFrameImage': session.getUser()?.avatarFrameImage,
          Const.callRoomId: res.callId,
          Const.token: res.token,
          Const.channel: widget.userId2,
          Const.isAudioCall: widget.isAudioCall,
          'callRate': _callRate,
          'freeTrialSeconds': _freeTrialSeconds,
        });

        // Listen for callConfirmed (receiver got the call)
        _cancelCallReceive = SocketService.instance.on(
          Const.eventCallConfirmed,
          (data) {
            if (!mounted) return;
            Log.d(_tag, 'Call confirmed by receiver (Ringing)');
            setState(() {
              _statusText = 'Ringing...';
            });
          },
        );

        // Listen for callAnswer (receiver accepted/rejected)
        _cancelCallAnswer = SocketService.instance.on(Const.eventCallAnswer, (
          data,
        ) {
          if (!mounted) return;
          final map = data is Map ? data : <String, dynamic>{};
          final isAccept = map['isAccept'] == true;
          if (isAccept) {
            final callData = IncomingCallData(
              callRoomId: _callRoomId,
              token: map['token']?.toString() ?? res.token,
              channel: map['channel']?.toString() ?? widget.userId2,
              userId2: widget.userId2,
              user2Name: widget.userName,
              user2Image: widget.userImage,
              isAudioCall: widget.isAudioCall,
              callByMe: true,
              callRate: _callRate,
              freeTrialSeconds: _freeTrialSeconds,
              isFreeCall: widget.isFreeCall,
            );
            Navigator.pop(context, callData);
          } else {
            final reason = map['reason']?.toString();
            if (reason == 'busy') {
              Fluttertoast.showToast(msg: 'User is busy on another call');
            } else {
              Fluttertoast.showToast(msg: 'Call Declined');
            }
            Navigator.pop(context, null);
          }
        });

        _cancelCallCancel = SocketService.instance.on(Const.eventCallCancel, (
          data,
        ) {
          if (!mounted) return;
          Navigator.pop(context, null);
        });

        _timeoutTimer = Timer(const Duration(seconds: 45), () {
          if (mounted) {
            Fluttertoast.showToast(msg: 'Call not answered');
            Navigator.pop(context, null);
          }
        });
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Call request failed');
        navigator.pop();
      }
    } catch (e, s) {
      Log.e(_tag, 'initiateCall failed', e, s);
      if (mounted) {
        Fluttertoast.showToast(msg: 'Call failed: $e');
        navigator.pop(null);
      }
    }
  }

  Future<void> _cancelCall() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    try {
      final session = context.read<SessionManager>();
      // Emit callCancel matching native CallRequestActivity.onBackPressed
      SocketService.instance.emit(Const.eventCallCancel, {
        Const.userId1: widget.userId2,
        Const.userId2: session.userId,
        'user2Name': session.userName,
        'user2Image': session.userImage,
        Const.callRoomId: _callRoomId ?? '',
        Const.channel: widget.userId2,
      });

      // Log the cancelled call in the 1-1 chat thread.
      ChatScreen.addCallLog(
        myUserId: session.userId,
        otherUserId: widget.userId2,
        callType: widget.isAudioCall ? 'audio' : 'video',
        callStatus: 'cancelled',
        callDuration: 0,
        otherUserName: widget.userName,
        otherUserImage: widget.userImage,
      );
    } catch (e) {
      Log.e(_tag, 'cancel failed', e);
    } finally {
      if (mounted) _safePop();
    }
  }

  /// Pop back to the previous screen, or to chat if this is the only route.
  void _safePop() {
    try {
      if (AppRoutes.router.canPop()) {
        AppRoutes.router.pop();
      } else {
        AppRoutes.router.goNamed(
          AppRoutes.chatDetail,
          extra: {
            'otherUserId': widget.userId2,
            'otherUserName': widget.userName,
          },
        );
      }
    } catch (e, s) {
      Log.e(_tag, 'safePop failed', e, s);
      AppRoutes.router.goNamed(AppRoutes.main);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.topLeft,
        fit: StackFit.expand,
        children: [
          // Blurred background image of callee
          if (widget.userImage != null && widget.userImage!.isNotEmpty)
            Image.network(
              widget.userImage!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A0A2E)),
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(color: const Color(0xFF1A0A2E)),
            )
          else
            Container(color: const Color(0xFF1A0A2E)),
          // Dark gradient overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99000000), Color(0xCC000000)],
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Avatar with glow
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.brandGradient,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: ClipOval(
                      child:
                          widget.userImage != null &&
                                  widget.userImage!.isNotEmpty
                              ? Image.network(
                                widget.userImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppTheme.primary,
                                  child: const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                ),
                                loadingBuilder: (_, child, progress) => progress == null
                                    ? child
                                    : Container(
                                        color: AppTheme.primary,
                                        child: const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.white,
                                        ),
                                      ),
                              )
                              : Container(
                                color: AppTheme.primary,
                                child: const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Name
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                // Status with icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isAudioCall ? Icons.phone_in_talk : Icons.videocam,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _statusText,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // Ringing animation
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Preloader(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Call controls while waiting
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _controlButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      onTap: () => setState(() => _isMuted = !_isMuted),
                      active: _isMuted,
                    ),
                    _controlButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_mute,
                      label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                      onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                      active: _isSpeakerOn,
                    ),
                    if (!_isAudio)
                      _controlButton(
                        icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
                        label: _cameraOff ? 'Cam Off' : 'Cam On',
                        onTap: () => setState(() => _cameraOff = !_cameraOff),
                        active: _cameraOff,
                      ),
                  ],
                ),
                const Spacer(flex: 2),
                // Cancel button
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: GestureDetector(
                    onTap: _cancelCall,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x4DFF5252),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child:
                          _cancelling
                              ? const Padding(
                                padding: EdgeInsets.all(18),
                                child: Preloader(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : Image.asset(
                                'assets/icon/invite_reject.webp',
                                width: 30,
                                height: 30,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.call_end,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  active
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.12),
              border: active ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
