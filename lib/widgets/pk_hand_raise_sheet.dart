/// Phase 8 implementation: PK hand raise bottom sheet.
///
/// Ported from native `HostPKLiveActivity.java` lines 6802-7002.
///
/// Two modes:
/// - **Audience**: Shows "Raise Hand" button that emits `pkHandRaise`.
/// - **Host**: Shows list of raised hands with Accept/Reject buttons
///   that emit `pkHandRaiseAccept` / `pkHandRaiseReject`.
library pk_hand_raise;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../constants/const.dart';
import '../services/session_manager.dart';
import '../services/socket_service.dart';
import '../utils/log.dart';
import '../widgets/user_avatar.dart';

class PkHandRaiseSheet extends StatefulWidget {
  const PkHandRaiseSheet({
    super.key,
    required this.isHost,
    required this.liveStreamingId,
  });

  final bool isHost;
  final String liveStreamingId;

  @override
  State<PkHandRaiseSheet> createState() => _PkHandRaiseSheetState();
}

class _PkHandRaiseSheetState extends State<PkHandRaiseSheet> {
  static const String _tag = 'PkHandRaise';
  final _raisedHands = <_HandRaise>[];
  bool _myHandRaised = false;
  Function? _cancelRaise;
  Function? _cancelAccept;
  Function? _cancelReject;

  @override
  void initState() {
    super.initState();
    _listenSocketEvents();
  }

  @override
  void dispose() {
    _cancelRaise?.call();
    _cancelAccept?.call();
    _cancelReject?.call();
    super.dispose();
  }

  void _listenSocketEvents() {
    // Host receives hand raise requests.
    if (widget.isHost) {
      _cancelRaise = SocketService.instance.on(Const.eventPkHandRaise, (data) {
        try {
          final map = data as Map<String, dynamic>;
          final userId = map['userId']?.toString() ?? '';
          if (userId.isEmpty) return;
          // Avoid duplicates.
          if (_raisedHands.any((h) => h.userId == userId)) return;
          setState(() {
            _raisedHands.add(_HandRaise(
              userId: userId,
              name: map['name']?.toString() ?? 'User',
              image: map['image']?.toString(),
            ));
          });
          Fluttertoast.showToast(msg: '${map['name'] ?? 'Someone'} raised hand');
        } catch (e, s) {
          Log.e(_tag, 'handleRaise failed', e, s);
        }
      });
    }

    // Audience receives accept/reject for their own hand raise.
    _cancelAccept = SocketService.instance.on(Const.eventPkHandRaiseAccept, (data) {
      try {
        final map = data as Map<String, dynamic>;
        final userId = map['userId']?.toString() ?? '';
        final session = context.read<SessionManager>();
        if (userId == session.userId) {
          Fluttertoast.showToast(msg: 'Hand raise accepted!');
          if (mounted) {
            setState(() => _myHandRaised = false);
            Navigator.pop(context);
          }
        }
      } catch (e, s) {
        Log.e(_tag, 'handleAccept failed', e, s);
      }
    });

    _cancelReject = SocketService.instance.on(Const.eventPkHandRaiseReject, (data) {
      try {
        final map = data as Map<String, dynamic>;
        final userId = map['userId']?.toString() ?? '';
        final session = context.read<SessionManager>();
        if (userId == session.userId) {
          Fluttertoast.showToast(msg: 'Hand raise rejected');
          if (mounted) setState(() => _myHandRaised = false);
        }
      } catch (e, s) {
        Log.e(_tag, 'handleReject failed', e, s);
      }
    });
  }

  void _raiseHand() {
    final session = context.read<SessionManager>();
    final user = session.getUser();
    if (user == null) {
      Fluttertoast.showToast(msg: 'Please login first');
      return;
    }
    SocketService.instance.emit(Const.eventPkHandRaise, {
      'userId': session.userId,
      'name': user.name ?? '',
      'image': user.image ?? '',
      'liveStreamingId': widget.liveStreamingId,
    });
    setState(() => _myHandRaised = true);
    Fluttertoast.showToast(msg: 'Hand raised');
  }

  void _accept(String userId) {
    SocketService.instance.emit(Const.eventPkHandRaiseAccept, {
      'userId': userId,
      'liveStreamingId': widget.liveStreamingId,
    });
    setState(() => _raisedHands.removeWhere((h) => h.userId == userId));
  }

  void _reject(String userId) {
    SocketService.instance.emit(Const.eventPkHandRaiseReject, {
      'userId': userId,
      'liveStreamingId': widget.liveStreamingId,
    });
    setState(() => _raisedHands.removeWhere((h) => h.userId == userId));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text(
          widget.isHost ? 'Raised Hands' : 'Raise Hand',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        if (widget.isHost) ...[
          if (_raisedHands.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text('No raised hands yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _raisedHands.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (_, i) {
                  final h = _raisedHands[i];
                  return ListTile(
                    leading: UserAvatar(imageUrl: h.image, size: 40),
                    title: Text(h.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _accept(h.userId),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => _reject(h.userId),
                      ),
                    ]),
                  );
                },
              ),
            ),
        ] else ...[
          // Audience view.
          Icon(
            _myHandRaised ? Icons.pan_tool : Icons.back_hand,
            size: 64,
            color: _myHandRaised ? Colors.amber : Colors.white70,
          ),
          const SizedBox(height: 16),
          Text(
            _myHandRaised ? 'Hand raised â€” waiting for host' : 'Raise your hand to join the PK',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _myHandRaised ? null : _raiseHand,
              icon: const Icon(Icons.back_hand),
              label: Text(_myHandRaised ? 'Hand Raised' : 'Raise Hand'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7E3FF2),
                disabledBackgroundColor: Colors.amber.withValues(alpha: 0.3),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _HandRaise {
  _HandRaise({required this.userId, required this.name, this.image});
  final String userId;
  final String name;
  final String? image;
}

/// Helper to show the PK hand raise bottom sheet.
Future<void> showPkHandRaiseSheet(
  BuildContext context, {
  required bool isHost,
  required String liveStreamingId,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => PkHandRaiseSheet(isHost: isHost, liveStreamingId: liveStreamingId),
  );
}

