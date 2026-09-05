import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/const.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../services/socket_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';

class AudioCallScreen extends StatefulWidget {
  const AudioCallScreen({super.key, this.userId, this.callId});

  final String? userId;
  final String? callId;

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  static const String _tag = 'AudioCall';
  bool _muted = false;
  bool _speakerOn = false;
  bool _connected = false;
  bool _ending = false;
  int _seconds = 0;
  Timer? _timer;
  Function? _cancelCallReceive;
  Function? _cancelCallConfirmed;
  Function? _cancelCallDisconnect;

  @override
  void initState() {
    super.initState();
    _initCall();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancelCallReceive?.call();
    _cancelCallConfirmed?.call();
    _cancelCallDisconnect?.call();
    super.dispose();
  }

  void _initCall() {
    final socket = SocketService.instance;
    if (!socket.isConnected) {
      final session = context.read<SessionManager>();
      socket.connect(session.userId).then((_) => _registerSocketEvents());
    } else {
      _registerSocketEvents();
    }
  }

  void _registerSocketEvents() {
    final socket = SocketService.instance;
    _cancelCallConfirmed = socket.on(Const.eventCallConfirmed, (data) {
      if (mounted) setState(() => _connected = true);
      _startTimer();
    });
    _cancelCallDisconnect = socket.on(Const.eventCallDisconnect, (data) {
      _endCall();
    });
    _cancelCallReceive = socket.on(Const.eventCallReceive, (data) {
      if (mounted) setState(() => _connected = true);
      _startTimer();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _duration {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _endCall() async {
    if (_ending) return;
    setState(() => _ending = true);
    _timer?.cancel();
    try {
      if (widget.callId != null) {
        await ApiService.callDisconnect(callRoomId: widget.callId!);
      }
    } catch (e) {
      Log.e(_tag, 'endCall failed', e);
    }
    final socket = SocketService.instance;
    final session = SessionManager.instance;
    final myId = session?.userId ?? '';
    final otherId = widget.userId ?? '';
    socket.emit(Const.eventCallDisconnect, {
      Const.userId1: otherId,
      Const.userId2: myId,
      Const.callRoomId: widget.callId,
    });
    if (mounted) context.pop();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    final socket = SocketService.instance;
    socket.emit('muteInCallJoin', {'isMuted': _muted});
  }

  void _toggleSpeaker() {
    setState(() => _speakerOn = !_speakerOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                _connected ? 'Connected' : 'Calling...',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _duration,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const Spacer(flex: 2),
              _buildAvatar(),
              const SizedBox(height: 24),
              Text(
                widget.userId ?? 'Unknown',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_muted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Muted', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                ],
              ),
              const Spacer(flex: 3),
              _buildControls(),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 60),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _controlButton(
          icon: _muted ? Icons.mic_off : Icons.mic,
          label: _muted ? 'Unmute' : 'Mute',
          color: _muted ? Colors.red : Colors.white,
          onTap: _toggleMute,
        ),
        _controlButton(
          icon: Icons.phone,
          label: 'End',
          color: Colors.red,
          size: 72,
          onTap: _ending ? null : _endCall,
        ),
        _controlButton(
          icon: _speakerOn ? Icons.volume_up : Icons.volume_down,
          label: 'Speaker',
          color: _speakerOn ? AppTheme.primary : Colors.white,
          onTap: _toggleSpeaker,
        ),
      ],
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required Color color,
    double size = 56,
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color == Colors.red ? Colors.red : Colors.white.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
