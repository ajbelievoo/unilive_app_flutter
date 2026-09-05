import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/audio_room_root.dart';
import '../models/live_stream_root.dart';
import '../routes/app_routes.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import '../utils/log.dart';

/// Audio room entry helper.
///
/// Checks whether the current user already has an active audio-only live room.
/// If so, it jumps straight to [AudioRoomScreen] (as host if the room belongs to
/// the current user). Otherwise it opens the [GoAudioLiveScreen] creation page.
class AudioRoomNavigation {
  static Future<void> openAudioRoomOrCreate(BuildContext context) async {
    final session = context.read<SessionManager>();
    final userId = session.userId;
    if (userId.isEmpty) {
      if (context.mounted) context.pushNamed(AppRoutes.goAudioLive);
      return;
    }

    LiveUser? activeLive;
    try {
      final res = await ApiService.getGuestUserLive(userId);
      if (res.status && res.user != null && res.user!.isAudio) {
        activeLive = res.user!;
      }
    } catch (e, s) {
      Log.e('AudioRoomNavigation', 'getGuestUserLive failed', e, s);
    }

    if (activeLive != null) {
      // Try to refresh the live stream record so we have the latest token and
      // room snapshot before rejoining.
      var live = activeLive;
      final roomId = live.liveRoomId ?? live.id ?? '';
      if (roomId.isNotEmpty) {
        try {
          final fullRes = await ApiService.getLiveStream(roomId);
          if (fullRes.status && fullRes.user != null) {
            live = fullRes.user!;
          }
        } catch (e, s) {
          Log.e('AudioRoomNavigation', 'getLiveStream refresh failed', e, s);
        }
      }

      if (context.mounted) {
        final isHost = (live.userId ?? live.id ?? '') == userId;
        context.pushNamed(
          AppRoutes.audioRoom,
          extra: {
            'roomUser': AudioRoomUser.fromLiveStream(live),
            'isHost': isHost,
            'fromChat': false,
          },
        );
      }
      return;
    }

    if (context.mounted) context.pushNamed(AppRoutes.goAudioLive);
  }

  /// Used by [GoAudioLiveScreen] to skip the creation page entirely when the
  /// current user already has a live audio room. [replace] removes the create
  /// page from the stack so the user cannot navigate back to it.
  static Future<bool> tryRejoinActive(BuildContext context, {bool replace = false}) async {
    final session = context.read<SessionManager>();
    final userId = session.userId;
    if (userId.isEmpty) return false;

    LiveUser? activeLive;
    try {
      final res = await ApiService.getGuestUserLive(userId);
      if (res.status && res.user != null && res.user!.isAudio) {
        activeLive = res.user!;
      }
    } catch (e, s) {
      Log.e('AudioRoomNavigation', 'getGuestUserLive rejoin check failed', e, s);
    }

    if (activeLive != null) {
      var live = activeLive;
      final roomId = live.liveRoomId ?? live.id ?? '';
      if (roomId.isNotEmpty) {
        try {
          final fullRes = await ApiService.getLiveStream(roomId);
          if (fullRes.status && fullRes.user != null) {
            live = fullRes.user!;
          }
        } catch (e, s) {
          Log.e('AudioRoomNavigation', 'getLiveStream rejoin refresh failed', e, s);
        }
      }

      if (context.mounted) {
        final isHost = (live.userId ?? live.id ?? '') == userId;
        final extra = {
          'roomUser': AudioRoomUser.fromLiveStream(live),
          'isHost': isHost,
          'fromChat': false,
        };
        if (replace) {
          context.replaceNamed(AppRoutes.audioRoom, extra: extra);
        } else {
          context.pushNamed(AppRoutes.audioRoom, extra: extra);
        }
      }
      return true;
    }

    return false;
  }
}
