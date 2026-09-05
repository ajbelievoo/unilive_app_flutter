import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../constants/const.dart';
import '../utils/log.dart';
import 'device_identity_service.dart';

/// Ported from native `MySocketManager.java`.
///
/// Wraps a single [sio.Socket] connection to the UnilivePro backend
/// (`/socket.io/` namespace) and exposes typed helpers for the events
/// used by Belive.
///
/// Usage:
///   final socket = SocketService();
///   await socket.connect(userId);
///   socket.on(Const.eventChat, (data) => ...);
///   socket.emit(Const.eventChat, payload);
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  static const String _tag = 'SocketService';

  sio.Socket? _socket;
  bool _connected = false;
  String? _userId;
  // ignore: unused_field
  String? _authToken;
  int _reconnectAttempts = 0;
  Timer? _manualReconnectTimer;

  /// Pending listeners registered before socket was ready.
  /// Key = event name, Value = list of handlers.
  final Map<String, List<void Function(dynamic)>> _pendingListeners = {};

  /// Pending emits queued before socket was ready.
  final List<(String, dynamic)> _pendingEmits = [];

  /// Stream that emits `true` when connected, `false` when disconnected.
  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Stream that emits a void event each time the socket successfully reconnects.
  final _reconnectController = StreamController<void>.broadcast();
  Stream<void> get reconnectStream => _reconnectController.stream;

  bool get isConnected => _connected;

  /// Connect to the socket server with the given user id and optional auth token.
  /// Non-blocking: starts connection and returns after short wait.
  ///
  /// Sends the device id in the socket handshake query so the backend can
  /// enforce device-level blocks in real time (the backend joins
  /// `deviceRoom:<deviceId>` and kicks all sockets on that device when a
  /// device block is applied). If [deviceId] is not supplied, it is resolved
  /// from [DeviceIdentityService].
  Future<void> connect(
    String userId, {
    String? authToken,
    String? deviceId,
  }) async {
    if (_socket != null && _connected) {
      Log.d(_tag, 'already connected');
      return;
    }
    _userId = userId;
    _authToken = authToken;
    _reconnectAttempts = 0;
    // Remove trailing slash for socket_io_client compatibility
    final socketUrl = Const.baseUrl.replaceAll(RegExp(r'/+$'), '');
    Log.d(_tag, 'connecting to $socketUrl as $userId');

    // Resolve device id for backend device-room enforcement.
    String devId = deviceId ?? '';
    if (devId.isEmpty) {
      try {
        devId = await DeviceIdentityService.getDeviceId();
      } catch (e) {
        Log.w(_tag, 'deviceId resolve failed: $e');
      }
    }

    // Dispose old socket if any
    if (_socket != null) {
      try {
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }

    final query = <String, String>{'globalRoom': 'globalRoom:$userId'};
    if (devId.isNotEmpty) query['deviceId'] = devId;

    final optionsBuilder = sio.OptionBuilder()
        .setPath('/socket.io/')
        .setTransports(['websocket'])
        .disableAutoConnect()
        .setQuery(query)
        .enableReconnection()
        .setReconnectionAttempts(999)
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(30000)
        .setRandomizationFactor(0.5);

    // Pass auth token if available for server-side validation
    if (authToken != null && authToken.isNotEmpty) {
      optionsBuilder.setAuth({'token': authToken});
      optionsBuilder.setExtraHeaders({'Authorization': 'Bearer $authToken'});
    }

    _socket = sio.io(socketUrl, optionsBuilder.build());

    _socket!.onConnect((_) {
      _connected = true;
      _reconnectAttempts = 0;
      Log.d(_tag, 'connected successfully!');
      _connectionController.add(true);
      _registerPendingListeners();
      _flushPendingEmits();
    });

    _socket!.onConnectError((e) {
      Log.e(_tag, 'connect error: $e', e);
      _scheduleManualReconnect();
    });

    _socket!.onError((e) {
      Log.e(_tag, 'socket error: $e', e);
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      Log.d(_tag, 'disconnected');
      _connectionController.add(false);
      _scheduleManualReconnect();
    });

    _socket!.onReconnectAttempt((attempt) {
      _reconnectAttempts = attempt;
      final delay = (1000 * (1 << attempt.clamp(0, 5))).clamp(1000, 30000);
      Log.d(_tag, 'reconnect attempt #$attempt (delay: ${delay}ms)');
    });

    _socket!.onReconnect((_) {
      Log.d(_tag, 'reconnected successfully');
      _reconnectAttempts = 0;
      _reconnectController.add(null);
      _registerPendingListeners();
      _flushPendingEmits();
    });

    _socket!.onReconnectError((e) {
      Log.e(_tag, 'reconnect error: $e', e);
    });

    Log.d(_tag, 'calling socket.connect()...');
    _socket!.connect();

    // Wait up to 3 seconds for connection (non-blocking like native app)
    for (int i = 0; i < 30 && !_connected; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    Log.d(_tag, 'connect() returned, connected=$_connected');
  }

  /// Manual reconnect with exponential backoff as a backup to socket.io's
  /// built-in reconnection.
  void _scheduleManualReconnect() {
    _manualReconnectTimer?.cancel();
    if (_userId == null) return;

    final delay = (1000 * (1 << _reconnectAttempts.clamp(0, 5))).clamp(
      1000,
      30000,
    );
    _reconnectAttempts++;
    Log.d(
      _tag,
      'scheduling manual reconnect in ${delay}ms (attempt #$_reconnectAttempts)',
    );

    _manualReconnectTimer = Timer(Duration(milliseconds: delay), () {
      if (!_connected && _userId != null) {
        Log.d(_tag, 'manual reconnect triggered');
        _socket?.connect();
      }
    });
  }

  /// Manually trigger a reconnection.
  Future<void> reconnect() async {
    if (_userId == null) {
      Log.w(_tag, 'cannot reconnect: no userId set');
      return;
    }
    Log.d(_tag, 'manual reconnect requested');
    _socket?.disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    _socket?.connect();
  }

  /// Register all pending listeners on the current socket.
  void _registerPendingListeners() {
    if (_socket == null || _pendingListeners.isEmpty) return;
    for (final entry in _pendingListeners.entries) {
      for (final handler in entry.value) {
        _socket!.on(entry.key, handler);
        Log.d(_tag, 'registered pending listener: ${entry.key}');
      }
    }
    _pendingListeners.clear();
  }

  /// Flush all pending emits.
  void _flushPendingEmits() {
    if (_socket == null || _pendingEmits.isEmpty) return;
    for (final (event, data) in _pendingEmits) {
      Log.d(_tag, 'flushing pending emit($event)');
      _socket!.emit(event, data);
    }
    _pendingEmits.clear();
  }

  /// Subscribe to a socket event. Returns a function to cancel the
  /// subscription. If socket isn't connected yet, the listener is queued
  /// and registered when the socket connects.
  void Function() on(String event, void Function(dynamic data) handler) {
    if (_socket != null) {
      _socket!.on(event, handler);
    } else {
      Log.d(_tag, 'socket not ready — queueing listener for: $event');
      _pendingListeners.putIfAbsent(event, () => []).add(handler);
    }
    return () {
      _socket?.off(event, handler);
      _pendingListeners[event]?.remove(handler);
    };
  }

  /// Subscribe once.
  void once(String event, void Function(dynamic data) handler) {
    _socket?.once(event, handler);
  }

  /// Emit an event with an optional payload.
  /// If socket isn't connected yet, the emit is queued and sent on connect.
  void emit(String event, [dynamic data]) {
    if (_connected && _socket != null) {
      Log.d(_tag, 'emit($event)');
      _socket!.emit(event, data);
    } else {
      Log.d(_tag, 'socket not ready — queueing emit($event)');
      _pendingEmits.add((event, data));
    }
  }

  /// Emit with ack callback.
  void emitWithAck(String event, dynamic data, void Function(dynamic) ack) {
    if (!_connected || _socket == null) {
      Log.w(_tag, 'emitWithAck($event) called but socket not connected');
      return;
    }
    _socket!.emitWithAck(event, data, ack: ack);
  }

  /// Disconnect and dispose the socket.
  void disconnect() {
    _manualReconnectTimer?.cancel();
    _manualReconnectTimer = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
    _userId = null;
    _authToken = null;
    _reconnectAttempts = 0;
    _pendingListeners.clear();
    _pendingEmits.clear();
    _connectionController.add(false);
    Log.d(_tag, 'disconnected and disposed');
  }

  void dispose() {
    disconnect();
    _connectionController.close();
    _reconnectController.close();
  }
}
