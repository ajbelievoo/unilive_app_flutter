import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/const.dart';
import '../../models/chat_root.dart';
import '../../models/family_models.dart';
import '../../models/json_annotation_helper.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../services/socket_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../utils/media_utils.dart';
import '../../widgets/user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

class FamilyChatScreen extends StatefulWidget {
  const FamilyChatScreen({
    super.key,
    required this.familyId,
    this.familyName,
  });

  final String familyId;
  final String? familyName;

  @override
  State<FamilyChatScreen> createState() => _FamilyChatScreenState();
}

class _FamilyChatScreenState extends State<FamilyChatScreen> {
  static const String _tag = 'FamilyChat';
  static const String _prefKeyMessages = 'family_msgs_';

  final _messages = <ChatItem>[];
  final _ctrl = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  late String _myUserId;
  late String _myUserName;
  late String? _myUserImage;
  bool _loading = true;
  FamilyItem? _family;
  Function? _cancelChatSub;
  Function? _cancelTypingSub;
  Function? _cancelTypingStopSub;
  bool _someoneTyping = false;
  String _typingName = '';
  Timer? _typingTimer;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionManager>();
    _myUserId = session.userId;
    _myUserName = session.userName;
    _myUserImage = session.userImage;
    _initChat();
  }

  @override
  void dispose() {
    _cancelChatSub?.call();
    _cancelTypingSub?.call();
    _cancelTypingStopSub?.call();
    _typingTimer?.cancel();
    _typingDebounce?.cancel();
    _ctrl.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    await _loadPersistedMessages();
    await _loadFamily();
    _connectSocket();
    await _loadHistory();
  }

  Future<void> _loadFamily() async {
    try {
      final res = await ApiService.getFamilyDetail(widget.familyId);
      if (res.status && res.data.isNotEmpty) {
        setState(() => _family = res.data.first);
      }
    } catch (e) {
      Log.e(_tag, 'loadFamily failed', e);
    }
  }

  Future<void> _loadHistory() async {
    try {
      // Family chat should use the group-chat history endpoint with the
      // familyId as the group/topic identifier.
      final res = await ApiService.groupOldChat(
        groupId: 'family_${widget.familyId}',
      );
      if (res.status) {
        setState(() {
          _messages.clear();
          _messages.addAll(res.chat);
          _loading = false;
        });
        _scrollToBottom();
        _persistMessages();
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      Log.e(_tag, 'loadHistory failed', e);
      setState(() => _loading = false);
    }
  }

  void _connectSocket() {
    final socket = SocketService.instance;
    // Connect to the family room
    socket.emit(Const.eventFamilyRoomConnect, {'familyId': widget.familyId});

    _cancelChatSub = socket.on(Const.eventFamilyChat, (data) {
      try {
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;

        // Filter by familyId if the server doesn't use namespaced rooms
        if (map['familyId'] != widget.familyId) return;

        final item = ChatItem.fromJson(map);
        if (item.senderId != _myUserId) {
          setState(() {
            _messages.add(item);
            _someoneTyping = false;
          });
          _scrollToBottom();
          _persistMessages();
        }
      } catch (e) {
        Log.e(_tag, 'familyChat socket error', e);
      }
    });

    // Typing indicators for family chat.
    _cancelTypingSub = socket.on(Const.eventTyping, (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      if (map == null) return;
      if (map['familyId'] != widget.familyId) return;
      final senderId = map['senderId'] as String?;
      if (senderId != null && senderId != _myUserId) {
        setState(() {
          _someoneTyping = true;
          _typingName = map['senderName'] as String? ?? 'Someone';
        });
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _someoneTyping = false);
        });
      }
    });
    _cancelTypingStopSub = socket.on(Const.eventTypingStop, (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      if (map == null) return;
      if (map['familyId'] != widget.familyId) return;
      setState(() => _someoneTyping = false);
    });
  }

  Future<void> _loadPersistedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefKeyMessages${widget.familyId}';
    final saved = prefs.getString(key);
    if (saved != null && saved.isNotEmpty) {
      final list = jsonDecode(saved) as List;
      setState(() {
        _messages.addAll(list.map((j) => ChatItem.fromJson(j)).toList());
      });
      _scrollToBottom();
    }
  }

  Future<void> _persistMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefKeyMessages${widget.familyId}';
    final json = jsonEncode(_messages.map((m) => m.toJson()).toList());
    await prefs.setString(key, json);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    _focusNode.requestFocus();

    final now = DateTime.now();
    final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    // Find my role
    final myRole = _family?.members.where((m) => m.userId == _myUserId).firstOrNull?.role ?? 'member';

    // Stop typing indicator.
    SocketService.instance.emit(Const.eventTypingStop, {
      'senderId': _myUserId,
      'familyId': widget.familyId,
    });

    final msg = ChatItem(
      senderId: _myUserId,
      receiverId: 'family_${widget.familyId}', // Group target
      message: text,
      messageType: 'message',
      time: timeStr,
      status: 'sent',
      topic: 'family_${widget.familyId}',
    );

    setState(() => _messages.add(msg));
    _scrollToBottom();
    _persistMessages();

    // Emit via socket
    SocketService.instance.emit(Const.eventFamilyChat, {
      ...msg.toJson(),
      'familyId': widget.familyId,
      'senderName': _myUserName,
      'senderImage': _myUserImage,
      'senderRole': myRole,
    });
  }

  /// Send an image to the family chat.
  Future<void> _sendImage() async {
    try {
      final picker = ImagePicker();
      final result = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (result == null) return;

      final file = File(result.path);
      final res = await ApiService.uploadChatImage(
        file: file,
        userId: _myUserId,
        topic: 'family_${widget.familyId}',
        messageType: 'image',
      );

      if (res.status && res.chat != null) {
        final url = parseString(res.chat!['image'] ?? res.chat!['url']);
        if (url != null && url.isNotEmpty) {
          final now = DateTime.now();
          final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
          final msg = ChatItem(
            senderId: _myUserId,
            receiverId: 'family_${widget.familyId}',
            message: 'image',
            messageType: 'image',
            image: url,
            time: timeStr,
            status: 'sent',
            topic: 'family_${widget.familyId}',
          );
          setState(() => _messages.add(msg));
          _scrollToBottom();
          _persistMessages();

          SocketService.instance.emit(Const.eventFamilyChat, {
            ...msg.toJson(),
            'familyId': widget.familyId,
            'senderName': _myUserName,
            'senderImage': _myUserImage,
          });
        }
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to send image');
      }
    } catch (e) {
      Log.e(_tag, 'sendImage failed', e);
      Fluttertoast.showToast(msg: 'Failed to send image');
    }
  }

  /// Emit typing event when user is typing (debounced to avoid socket spam).
  void _onTextChanged(String value) {
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 300), () {
      if (value.trim().isNotEmpty) {
        SocketService.instance.emit(Const.eventTyping, {
          'senderId': _myUserId,
          'familyId': widget.familyId,
          'senderName': _myUserName,
          'isTyping': true,
        });
      } else {
        SocketService.instance.emit(Const.eventTypingStop, {
          'senderId': _myUserId,
          'familyId': widget.familyId,
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.familyName ?? 'Family Chat'),
            if (_family != null)
              Text(
                '${_family!.memberCount} members online',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_someoneTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$_typingName is typing...',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          Expanded(
            child: _loading && _messages.isEmpty
                ? const Center(child: Preloader())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
                  ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatItem msg) {
    final mine = msg.isMine(_myUserId);
    final isLuckyBag = msg.messageType == 'luckyBag';
    final member = _family?.members.where((m) => m.userId == msg.senderId).firstOrNull;
    final senderName = member?.name ?? (mine ? 'Me' : 'Member');
    final senderRole = member?.role ?? 'member';
    final senderImage = member?.image;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            UserAvatar(size: 32, imageUrl: senderImage),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!mine)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          senderName,
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                        ),
                        if (senderRole == 'leader' || senderRole == 'co-leader') ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                            decoration: BoxDecoration(
                              color: senderRole == 'leader' ? Colors.amber : Colors.purple,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              senderRole.toUpperCase(),
                              style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (isLuckyBag)
                  _buildLuckyBagBubble(msg, mine)
                else if (msg.messageType == 'image' && msg.image != null)
                  GestureDetector(
                    onTap: () {
                      // Open image preview
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Image')),
                          body: Center(
                            child: CachedNetworkImage(
                              imageUrl: VideoUtil.getFullImageUrl(msg.image),
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                            ),
                          ),
                        ),
                      ));
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: VideoUtil.getFullImageUrl(msg.image),
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 180, height: 180,
                          color: Colors.grey.shade300,
                        ),
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: mine ? AppTheme.primary : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg.message ?? '',
                      style: TextStyle(color: mine ? Colors.white : AppTheme.textPrimary),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  msg.time ?? '',
                  style: const TextStyle(fontSize: 9, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          if (mine) ...[
            const SizedBox(width: 8),
            UserAvatar(size: 32, imageUrl: _myUserImage),
          ],
        ],
      ),
    );
  }

  Widget _buildLuckyBagBubble(ChatItem msg, bool mine) {
    return GestureDetector(
      onTap: () => _claimLuckyBag(msg),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.wallet_giftcard, color: Colors.amber, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Red Packet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(msg.message ?? 'Open to get diamonds!', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade800,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: const Text('Belive Family', style: TextStyle(color: Colors.white54, fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _claimLuckyBag(ChatItem msg) async {
    final luckyBagId = msg.id;
    if (luckyBagId == null || luckyBagId.isEmpty) {
      Fluttertoast.showToast(msg: 'Invalid red packet');
      return;
    }
    Fluttertoast.showToast(msg: 'Opening Red Packet...');
    try {
      final res = await ApiService.claimFamilyLuckyBag(
        familyId: widget.familyId,
        luckyBagId: luckyBagId,
        userId: _myUserId,
      );
      if (res.status) {
        final got = res.coins;
        if (got != null && got > 0) {
          Fluttertoast.showToast(msg: 'Congratulations! You received $got diamonds.');
        } else {
          Fluttertoast.showToast(msg: res.message ?? 'Congratulations! You received diamonds.');
        }
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Bag empty or already claimed');
      }
    } catch (e) {
      Log.e(_tag, 'claim red packet failed', e);
      Fluttertoast.showToast(msg: 'Already claimed or expired');
    }
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppTheme.surface,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.photo_outlined, color: Colors.blue),
              onPressed: _sendImage,
              tooltip: 'Send Image',
            ),
            IconButton(
              icon: const Icon(Icons.wallet_giftcard, color: Colors.red),
              onPressed: _showRedPacketDialog,
              tooltip: 'Red Packet',
            ),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focusNode,
                textInputAction: TextInputAction.send,
                onChanged: _onTextChanged,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send, color: AppTheme.primary),
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }

  void _showRedPacketDialog() async {
    final amountCtrl = TextEditingController();
    final countCtrl = TextEditingController();

    final data = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Red Packet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Diamonds')),
            TextField(controller: countCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Winner Count')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () {
            final a = int.tryParse(amountCtrl.text);
            final c = int.tryParse(countCtrl.text);
            if (a != null && c != null) Navigator.pop(ctx, {'amount': a, 'count': c});
          }, child: const Text('Send')),
        ],
      ),
    );

    if (data == null) return;

    final amount = data['amount']!;
    final count = data['count']!;

    setState(() => _loading = true);
    try {
      final res = await ApiService.createFamilyLuckyBag(
        familyId: widget.familyId,
        userId: _myUserId,
        totalCoins: amount,
        winnerCount: count,
      );
      if (!res.status) {
        if (mounted) {
          Fluttertoast.showToast(msg: res.message ?? 'Failed to create red packet');
          setState(() => _loading = false);
        }
        return;
      }

      final luckyBagId = parseString(res.data?['_id'] ?? res.data?['id'] ?? res.data?['luckyBagId']);
      final now = DateTime.now();
      final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      final msg = ChatItem(
        id: luckyBagId,
        senderId: _myUserId,
        receiverId: 'family_${widget.familyId}',
        message: 'Sent a Red Packet!',
        messageType: 'luckyBag',
        time: timeStr,
        giftCoin: amount,
        count: count,
        status: 'sent',
        topic: 'family_${widget.familyId}',
      );

      setState(() {
        _messages.add(msg);
        _loading = false;
      });
      _scrollToBottom();
      _persistMessages();

      SocketService.instance.emit(Const.eventFamilyChat, {
        ...msg.toJson(),
        'familyId': widget.familyId,
        'senderName': _myUserName,
        'senderImage': _myUserImage,
      });
    } catch (e) {
      Log.e(_tag, 'send red packet failed', e);
      if (mounted) {
        Fluttertoast.showToast(msg: 'Failed to send red packet');
        setState(() => _loading = false);
      }
    }
  }
}
