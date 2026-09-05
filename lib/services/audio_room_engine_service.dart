import 'package:agora_rtc_engine/agora_rtc_engine.dart';

/// Holds the current Agora engine and a local-only mute list so UI outside
/// the audio room screen (e.g. profile room card) can mute/unmute a seat user
/// for the current viewer without leaving the room.
class AudioRoomEngineService {
  AudioRoomEngineService._();
  static final AudioRoomEngineService instance = AudioRoomEngineService._();

  RtcEngine? _engine;
  final _localMutedUids = <int>{};

  /// Set the active Agora engine. Called by AudioRoomScreen on init.
  void setEngine(RtcEngine? engine) {
    _engine = engine;
  }

  /// Clear the engine. Called by AudioRoomScreen on dispose.
  void clear() {
    _engine = null;
    _localMutedUids.clear();
  }

  /// Locally mute or unmute a remote user's audio for the current viewer.
  /// This does not affect other listeners and does not emit host-mute events.
  Future<void> toggleLocalMute(int agoraUid) async {
    if (_engine == null) return;
    final currentlyMuted = _localMutedUids.contains(agoraUid);
    try {
      await _engine!.muteRemoteAudioStream(
        uid: agoraUid,
        mute: !currentlyMuted,
      );
      if (currentlyMuted) {
        _localMutedUids.remove(agoraUid);
      } else {
        _localMutedUids.add(agoraUid);
      }
    } catch (e) {
      // Engine may be released already.
    }
  }

  bool isLocallyMuted(int agoraUid) => _localMutedUids.contains(agoraUid);
}
