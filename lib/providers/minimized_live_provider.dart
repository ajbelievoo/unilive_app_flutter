import 'package:flutter/material.dart';

import '../models/live_stream_root.dart' as live_stream;

/// Tracks a minimized live room session so the user can return to it.
///
/// When a user minimizes a live room, the [LiveUser] data is stored here.
/// [MainScreen] shows a floating "return to live" box when a session is active.
class MinimizedLiveProvider extends ChangeNotifier {
  live_stream.LiveUser? _liveUser;
  bool _isHost = false;

  live_stream.LiveUser? get liveUser => _liveUser;
  bool get isHost => _isHost;
  bool get hasMinimizedLive => _liveUser != null;

  void minimize(live_stream.LiveUser user, {bool isHost = false}) {
    _liveUser = user;
    _isHost = isHost;
    notifyListeners();
  }

  void clear() {
    _liveUser = null;
    _isHost = false;
    notifyListeners();
  }
}
