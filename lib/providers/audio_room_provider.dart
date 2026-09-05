import 'dart:async';
import 'package:flutter/foundation.dart';

import '../constants/const.dart';
import '../models/audio_room_root.dart';
import '../services/socket_service.dart';

class AudioRoomProvider extends ChangeNotifier {

  final SocketService _socket = SocketService.instance;

  AudioRoomUser? _roomUser;
  AudioRoomUser? get roomUser => _roomUser;

  final List<SeatItem> _seats = [];
  List<SeatItem> get seats => _seats;

  int _seatCount = 9;
  int get seatCount => _seatCount;

  final List<Map<String, dynamic>> _joinRequests = [];
  List<Map<String, dynamic>> get joinRequests => _joinRequests;

  final List<String> _bannedUserIds = [];
  List<String> get bannedUserIds => _bannedUserIds;

  final List<String> _adminIds = [];
  List<String> get adminIds => _adminIds;

  String? _roomName;
  String? get roomName => _roomName;

  String? _welcomeMessage;
  String? get welcomeMessage => _welcomeMessage;

  bool get loading => _loading;
  final bool _loading = false;

  final _seatController = StreamController<List<SeatItem>>.broadcast();
  Stream<List<SeatItem>> get seatStream => _seatController.stream;

  final List<void Function()> _unsubscribers = [];

  void setRoomUser(AudioRoomUser? user) {
    _roomUser = user;
    _roomName = user?.roomName;
    _welcomeMessage = user?.roomWelcome;
    _initSeats();
    notifyListeners();
  }

  void _initSeats() {
    _seats.clear();
    for (int i = 0; i < _seatCount; i++) {
      _seats.add(SeatItem(position: i));
    }
    if (_roomUser != null) {
      _seats[0] = SeatItem(
        position: 0,
        userId: _roomUser!.id,
        name: _roomUser!.name,
        image: _roomUser!.image,
        reserved: true,
        role: 'host',
        agoraUid: _roomUser!.agoraUID,
      );
    }
    notifyListeners();
  }

  void subscribeAudioRoomEvents() {
    _unsubscribers.add(_socket.on(Const.eventSeat, (data) {
      final d = data as Map<String, dynamic>;
      final position = (d['position'] as num?)?.toInt() ?? 0;
      if (position < _seats.length) {
        _seats[position] = SeatItem.fromJson(d);
        _seatController.add(_seats);
        notifyListeners();
      }
    }));

    _unsubscribers.add(_socket.on(Const.eventMuteSeat, (data) {
      final d = data as Map<String, dynamic>;
      final position = (d['position'] as num?)?.toInt() ?? 0;
      final mute = (d['mute'] as num?)?.toInt() ?? 0;
      if (position < _seats.length) {
        _seats[position].mute = mute;
        notifyListeners();
      }
    }));

    _unsubscribers.add(_socket.on(Const.eventLockSeat, (data) {
      final d = data as Map<String, dynamic>;
      final position = (d['position'] as num?)?.toInt() ?? 0;
      final lock = d['lock'] as bool? ?? false;
      if (position < _seats.length) {
        _seats[position].lock = lock;
        notifyListeners();
      }
    }));

    _unsubscribers.add(_socket.on(Const.eventUpdateSeatCount, (data) {
      final d = data is Map ? data : (data is List && data.isNotEmpty ? data.first : null) as Map?;
      final count = d?['seatCount'] as int? ?? d?['count'] as int? ?? 0;
      if (count >= 9 && count <= 21) {
        _seatCount = count;
        _initSeats();
      }
    }));

    _unsubscribers.add(_socket.on(Const.eventRoomName, (data) {
      _roomName = (data as Map?)?['roomName'] as String?;
      notifyListeners();
    }));

    _unsubscribers.add(_socket.on(Const.eventRoomWelcome, (data) {
      _welcomeMessage = (data as Map?)?['roomWelcome'] as String?;
      notifyListeners();
    }));

    _unsubscribers.add(_socket.on(Const.eventAddRequested, (data) {
      final req = data as Map<String, dynamic>? ?? {};
      _joinRequests.add(req);
      notifyListeners();
    }));

    _unsubscribers.add(_socket.on(Const.eventUpdateBlockedlist, (data) {
      final userId = (data as Map?)?['userId'] as String?;
      if (userId != null) {
        _bannedUserIds.add(userId);
        notifyListeners();
      }
    }));

    _unsubscribers.add(_socket.on(Const.eventRoomAdminList, (data) {
      final admins = (data as Map?)?['admins'] as List? ?? [];
      _adminIds
        ..clear()
        ..addAll(admins.cast<String>());
      notifyListeners();
    }));
  }

  void requestSeat(int position) {
    _socket.emit(Const.eventSeat, {
      'position': position,
      'action': 'request',
    });
  }

  void leaveSeat(int position) {
    if (position < _seats.length) {
      _seats[position] = SeatItem(position: position);
      _socket.emit(Const.eventSeat, {
        'position': position,
        'action': 'leave',
      });
      notifyListeners();
    }
  }

  void muteSeat(int position, int mute) {
    if (position < _seats.length) {
      _seats[position].mute = mute;
      _socket.emit(Const.eventMuteSeat, {
        'position': position,
        'mute': mute,
      });
      notifyListeners();
    }
  }

  void lockSeat(int position, bool lock) {
    if (position < _seats.length) {
      _seats[position].lock = lock;
      _socket.emit(Const.eventLockSeat, {
        'position': position,
        'lock': lock,
      });
      notifyListeners();
    }
  }

  void acceptJoinRequest(String userId, int position) {
    _socket.emit(Const.acceptJoinRequest, {
      'userId': userId,
      'position': position,
    });
    _joinRequests.removeWhere((r) => r['userId'] == userId);
    notifyListeners();
  }

  void rejectJoinRequest(String userId) {
    _socket.emit(Const.rejectJoinRequest, {'userId': userId});
    _joinRequests.removeWhere((r) => r['userId'] == userId);
    notifyListeners();
  }

  void updateRoomName(String name) {
    _socket.emit(Const.eventRoomName, {'roomName': name});
    _roomName = name;
    notifyListeners();
  }

  void updateWelcomeMessage(String message) {
    _socket.emit(Const.eventRoomWelcome, {'roomWelcome': message});
    _welcomeMessage = message;
    notifyListeners();
  }

  void banUser(String userId) {
    _socket.emit(Const.eventUserBlock, {'userId': userId});
    _bannedUserIds.add(userId);
    notifyListeners();
  }

  void makeAdmin(String userId) {
    _socket.emit(Const.eventMakeAdmin, {'userId': userId});
    _adminIds.add(userId);
    notifyListeners();
  }

  void clearRoom() {
    for (final unsub in _unsubscribers) {
      try {
        unsub();
      } catch (_) {}
    }
    _unsubscribers.clear();
    _roomUser = null;
    _seats.clear();
    _joinRequests.clear();
    _bannedUserIds.clear();
    _adminIds.clear();
    _roomName = null;
    _welcomeMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    clearRoom();
    _seatController.close();
    super.dispose();
  }
}
