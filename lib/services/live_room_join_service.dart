/// Reusable helper to join a live room by host userId + liveStreamingId.
///
/// Extracted from the live-list join flow so that any screen (e.g. the user
/// profile sheet) can send a user into a live room they're currently sitting
/// in. Mirrors the socket-based join used by the home live list:
///   1. Ensure the socket is connected.
///   2. Emit `eventSingleLiveUser` with the host's userId + liveStreamingId.
///   3. Wait for the `eventDummy` room payload (or `eventIsLiveUser` = ended).
///   4. Fall back to `retrieveRoomParticipantDetails` HTTP API on timeout.
///   5. Navigate to the audio room / video live room / PK battle / fake watch.
///
/// [viaProfileUserId] — when set, the join is "via a profile". The backend
/// uses this to emit a profile-visit mention to the room (only the profile
/// owner sees it; everyone else sees a normal entry). See
/// `docs/PROFILE_LIVE_INDICATOR_BACKEND_API.md`.
library live_room_join_service;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/const.dart';
import '../models/audio_room_root.dart';
import '../models/live_stream_root.dart' as live_stream;
import '../models/live_user_root.dart' as live_user;
import '../routes/app_routes.dart';
import 'api_service.dart';
import 'session_manager.dart';
import 'socket_service.dart';
import '../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'LiveRoomJoin';

/// Joins the live room hosted by [liveUserId] (with optional
/// [liveStreamingId]).
///
/// [isAudio] hints whether the room is an audio room (affects the socket
/// `type` field and the fallback navigation). [viaProfileUserId] is the
/// profile owner's userId when joining from a profile tap — passed to the
/// backend so it can emit a profile-visit mention.
///
/// Shows a loading dialog while resolving the room, then navigates. Returns
/// `true` if the user was navigated into a room.
Future<bool> joinLiveRoom({
  required BuildContext context,
  required String liveUserId,
  String? liveStreamingId,
  bool isAudio = false,
  String? viaProfileUserId,
}) async {
  final session = context.read<SessionManager>();
  if (session.userId.isEmpty) {
    Fluttertoast.showToast(msg: 'Please login again');
    return false;
  }
  if (liveUserId.isEmpty) {
    Fluttertoast.showToast(msg: 'Invalid live');
    return false;
  }

  if (!context.mounted) return false;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: Preloader()),
  );

  try {
    if (!SocketService.instance.isConnected) {
      await SocketService.instance.connect(
        session.userId,
        authToken: session.token,
      );
    }

    final completer = Completer<live_user.LiveUser?>();
    Function? cancelDummy;
    Function? cancelIsLive;
    Timer? timeout;

    void cleanup() {
      cancelDummy?.call();
      cancelIsLive?.call();
      timeout?.cancel();
    }

    cancelDummy = SocketService.instance.on(Const.eventDummy, (data) {
      try {
        final map =
            data is Map<String, dynamic>
                ? data
                : (data is String
                    ? jsonDecode(data) as Map<String, dynamic>
                    : null);
        if (map == null) return;
        final room = live_user.LiveUser.fromJson(map);
        if (!completer.isCompleted) completer.complete(room);
      } catch (e, s) {
        Log.e(_tag, 'dummy parse failed', e, s);
      }
    });

    cancelIsLive = SocketService.instance.on(Const.eventIsLiveUser, (data) {
      if (!completer.isCompleted) completer.complete(null);
    });

    timeout = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        ApiService.retrieveRoomParticipantDetails(toUserId: liveUserId)
            .then((participantRes) {
              if (participantRes.status &&
                  participantRes.user != null &&
                  !completer.isCompleted) {
                completer.complete(participantRes.user!);
              } else if (!completer.isCompleted) {
                completer.complete(null);
              }
            })
            .catchError((e) {
              if (!completer.isCompleted) completer.complete(null);
            });
      }
    });

    SocketService.instance.emit(Const.eventSingleLiveUser, {
      'userId': liveUserId,
      'liveStreamingId': liveStreamingId ?? '',
      'type': isAudio ? 'audio' : 'other',
      if (viaProfileUserId != null) 'viaProfileUserId': viaProfileUserId,
    });

    final room = await completer.future;
    cleanup();

    if (!context.mounted) return false;
    Navigator.of(context, rootNavigator: true).pop();

    if (!context.mounted) return false;
    if (room == null) {
      Fluttertoast.showToast(msg: 'Live ended or unavailable');
      return false;
    }

    final isAudioRoom = room.isAudio || isAudio;
    if (isAudioRoom && !room.isPkMode) {
      final audioUser = AudioRoomUser.fromJson(room.toJson());
      context.pushNamed(
        AppRoutes.audioRoom,
        extra: {'roomUser': audioUser, 'isHost': false},
      );
      return true;
    } else if (room.isPkMode && room.pkConfig != null) {
      final isHost1 =
          room.pkConfig!.host1LiveId == room.liveStreamingId ||
          room.pkConfig!.host1Id == room.liveUserId;
      context.pushNamed(
        AppRoutes.pkBattle,
        extra: {'config': room.pkConfig!, 'isHost1': isHost1, 'isHost': false},
      );
      return true;
    } else if (room.isFake) {
      if (room.link == null || room.link!.isEmpty) {
        Fluttertoast.showToast(msg: 'Stream link not available');
        return false;
      }
      context.pushNamed(AppRoutes.fakeWatchLive, extra: {'host': room});
      return true;
    } else {
      final liveStreamUser = live_stream.LiveUser(
        id: room.id,
        liveStreamingId: room.liveStreamingId ?? room.id,
        userId: room.liveUserId,
        name: room.name,
        image: room.image,
        userImage: room.image,
        roomName: room.roomName,
        roomImage: room.roomImage,
        roomWelcome: room.roomWelcome,
        channel: room.channel,
        agoraUID: room.agoraUID,
        token: room.token,
        livekitToken: room.livekitToken,
        livekitUrl: room.livekitUrl,
        service: room.service,
        isAudio: false,
        liveType: 'video',
        view: room.view,
        uniqueId: room.uniqueId,
        createdAt: room.createdAt,
      );
      context.pushNamed(
        AppRoutes.liveRoom,
        extra: {'liveUser': liveStreamUser, 'isHost': false},
      );
      return true;
    }
  } catch (e, s) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    Log.e(_tag, 'joinLiveRoom failed', e, s);
    Fluttertoast.showToast(msg: 'Failed to join live');
    return false;
  }
}
