import 'dart:async';
import 'package:flutter/foundation.dart';

import '../constants/const.dart';
import '../models/chat_root.dart';
import '../models/chat_user_list_root.dart';
import '../models/live_stream_root.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/log.dart';

class ChatProvider extends ChangeNotifier {
  static const String _tag = 'ChatProvider';

  /// Static flag used by [PushNotificationService] to check whether a chat
  /// with a specific user is currently open, so we can suppress duplicate
  /// notifications. Mirrors native `ChatActivity.isOPEN`.
  static String? activeChatUserId;

  final SocketService _socket = SocketService.instance;

  final List<ChatUserItem> _chatList = [];
  List<ChatUserItem> get chatList => _chatList;

  /// Map of userId → LiveUser for chat partners who are currently live.
  /// Populated by [checkLiveStatuses] after loading the chat list.
  final Map<String, LiveUser> _liveUsers = {};
  Map<String, LiveUser> get liveUsers => _liveUsers;

  /// Returns the live info for [userId] if they are currently live, else null.
  LiveUser? liveInfoFor(String? userId) =>
      (userId == null) ? null : _liveUsers[userId];

  final List<ChatItem> _messages = [];
  List<ChatItem> get messages => _messages;

  String? _currentTopicId;
  String? get currentTopicId => _currentTopicId;

  String? _otherUserId;
  String? get otherUserId => _otherUserId;

  String? _otherUserName;
  String? get otherUserName => _otherUserName;

  bool _isTyping = false;
  bool get isTyping => _isTyping;

  bool _loading = false;
  bool get loading => _loading;

  bool _refreshing = false;
  bool get refreshing => _refreshing;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  bool _hasMore = true;
  bool get hasMore => _hasMore;
  int _start = 0;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  final _messageController = StreamController<ChatItem>.broadcast();
  Stream<ChatItem> get messageStream => _messageController.stream;

  final List<void Function()> _unsubscribers = [];

  Future<void> loadChatList(String userId, {bool refresh = false}) async {
    if (refresh) {
      if (_refreshing) return;
      _refreshing = true;
    } else {
      if (_loading) return;
      _loading = _chatList.isEmpty; // Only show full loading if list is empty
    }
    
    _refreshing = refresh;
    notifyListeners();
    try {
      // Always fetch from start (0) for the main list
      final res = await ApiService.chatList(userId: userId, start: 0, limit: 50);
      
      // Clear old list ONLY after we have the new data to avoid "blank screen"
      _chatList.clear();
      _chatList.addAll(res.chatList);
      
      _start = _chatList.length;
      _hasMore = res.chatList.length >= 50;
      _unreadCount = _chatList.fold(0, (sum, c) => sum + c.unreadCount);

      // Check live status for all chat partners in the background.
      // Don't await — let the UI update first, live badges appear as they resolve.
      checkLiveStatuses();
    } catch (e, s) {
      Log.e(_tag, 'loadChatList failed', e, s);
    } finally {
      _loading = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  /// Checks which chat partners are currently live and updates [_liveUsers].
  /// Called after chat list loads and periodically by the chat list screen.
  /// Mirrors native behaviour: each chat row shows a "LIVE" badge if the
  /// partner is streaming, and tapping it joins their live.
  Future<void> checkLiveStatuses() async {
    if (_chatList.isEmpty) return;
    bool changed = false;
    final futures = <Future<void>>[];
    for (final chat in _chatList) {
      final uid = chat.userId;
      if (uid == null || uid.isEmpty) continue;
      futures.add(() async {
        try {
          final res = await ApiService.getGuestUserLive(uid);
          final liveUser = res.user;
          if (res.status && liveUser != null) {
            if (_liveUsers[uid]?.id != liveUser.id) {
              _liveUsers[uid] = liveUser;
              changed = true;
            }
          } else {
            if (_liveUsers.containsKey(uid)) {
              _liveUsers.remove(uid);
              changed = true;
            }
          }
        } catch (e) {
          // Silently ignore — live check is best-effort.
        }
      }());
    }
    await Future.wait(futures);
    if (changed) notifyListeners();
  }

  Future<void> loadMoreChats(String userId) async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    _start = _chatList.length;
    notifyListeners();
    try {
      final res = await ApiService.chatList(userId: userId, start: _start, limit: 20);
      _chatList.addAll(res.chatList);
      _hasMore = res.chatList.length >= 20;
    } catch (e, s) {
      Log.e(_tag, 'loadMoreChats failed', e, s);
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  /// Silently update the chat list (e.g. on socket message) without clearing UI.
  Future<void> refreshChatListSilently(String userId) async {
    try {
      final res = await ApiService.chatList(userId: userId, start: 0, limit: 50);
      _chatList
        ..clear()
        ..addAll(res.chatList);
      _unreadCount = _chatList.fold(0, (sum, c) => sum + c.unreadCount);
      checkLiveStatuses();
      notifyListeners();
    } catch (e) {
      Log.e(_tag, 'refreshChatListSilently failed', e);
    }
  }

  Future<void> openChat({
    required String myUserId,
    required String otherUserId,
    String? otherUserName,
  }) async {
    _otherUserId = otherUserId;
    _otherUserName = otherUserName;
    ChatProvider.activeChatUserId = otherUserId;
    _messages.clear();
    _start = 0;
    _hasMore = true;
    notifyListeners();

    try {
      final topicRes = await ApiService.createChatTopic(
        myUserId: myUserId,
        otherUserId: otherUserId,
      );
      _currentTopicId = topicRes.topic;
      if (_currentTopicId != null) {
        await loadMessages(_currentTopicId!);
        subscribeChatEvents(_currentTopicId!);
      }
    } catch (e, s) {
      Log.e(_tag, 'openChat failed', e, s);
    }
  }

  Future<void> loadMessages(String topicId, {bool loadMore = false}) async {
    if (loadMore) {
      if (_loadingMore || !_hasMore) return;
      _loadingMore = true;
      notifyListeners();
    } else {
      _loading = true;
      notifyListeners();
    }

    try {
      final res = await ApiService.getOldChat(
        topicId: topicId,
        start: _start,
        limit: 30,
      );
      if (loadMore) {
        _messages.insertAll(0, res.chat);
      } else {
        _messages
          ..clear()
          ..addAll(res.chat);
      }
      _start += res.chat.length;
      _hasMore = res.chat.length >= 30;
    } catch (e, s) {
      Log.e(_tag, 'loadMessages failed', e, s);
    } finally {
      _loading = false;
      _loadingMore = false;
      notifyListeners();
    }
  }

  void subscribeChatEvents(String topicId) {
    for (final unsub in _unsubscribers) {
      try {
        unsub();
      } catch (_) {}
    }
    _unsubscribers.clear();

    _unsubscribers.add(_socket.on(Const.eventChat, (data) {
      final msg = ChatItem.fromJson(data as Map<String, dynamic>);
      if (msg.topic == topicId) {
        _messages.add(msg);
        _messageController.add(msg);
        notifyListeners();
      }
    }));
  }

  void sendMessage({
    required String senderId,
    required String receiverId,
    required String message,
    String messageType = 'message',
    String? image,
    String? giftId,
    String? giftImage,
    String? giftName,
    int giftCoin = 0,
    String? audioUrl,
    int audioDuration = 0,
    String? replyToId,
    String? replyToMessage,
  }) {
    final msg = ChatItem(
      senderId: senderId,
      receiverId: receiverId,
      topic: _currentTopicId,
      messageType: messageType,
      message: message,
      image: image,
      giftImage: giftImage,
      giftName: giftName,
      giftCoin: giftCoin,
      audioUrl: audioUrl,
      audioDuration: audioDuration,
      replyToId: replyToId,
      replyToMessage: replyToMessage,
      status: 'sent',
    );
    _messages.add(msg);
    _messageController.add(msg);

    _socket.emit(Const.eventChat, msg.toJson());
    notifyListeners();
  }

  void setTyping(bool typing) {
    _isTyping = typing;
    notifyListeners();
  }

  Future<void> deleteMessage(String chatId) async {
    try {
      await ApiService.deleteChat(chatId);
      _messages.removeWhere((m) => m.id == chatId);
      notifyListeners();
    } catch (e, s) {
      Log.e(_tag, 'deleteMessage failed', e, s);
    }
  }

  Future<void> clearChat(String userId) async {
    if (_currentTopicId == null) return;
    try {
      await ApiService.clearChat(_currentTopicId!, userId);
      _messages.clear();
      notifyListeners();
    } catch (e, s) {
      Log.e(_tag, 'clearChat failed', e, s);
    }
  }

  Future<void> starMessage(String chatId, bool isStarred) async {
    try {
      await ApiService.starMessage(chatId, isStarred);
      final idx = _messages.indexWhere((m) => m.id == chatId);
      if (idx >= 0) {
        _messages[idx] = _messages[idx].copyWith(isStarred: isStarred);
        notifyListeners();
      }
    } catch (e, s) {
      Log.e(_tag, 'starMessage failed', e, s);
    }
  }

  void closeChat() {
    for (final unsub in _unsubscribers) {
      try {
        unsub();
      } catch (_) {}
    }
    _unsubscribers.clear();
    _currentTopicId = null;
    _otherUserId = null;
    _otherUserName = null;
    ChatProvider.activeChatUserId = null;
    _messages.clear();
    _isTyping = false;
    notifyListeners();
  }

  @override
  void dispose() {
    closeChat();
    _messageController.close();
    super.dispose();
  }
}
