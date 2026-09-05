/// Voice Emoji feature for audio rooms.
///
/// Interactive emojis that combine a visual animation (SVGA) with a sound
/// effect. A viewer taps an emoji in the [VoiceEmojiPicker] sheet; the client
/// emits a socket event and the room renders a [VoiceEmojiOverlay] for every
/// participant (animation + sound) when the backend broadcasts it back.
///
/// Socket events (to be added to `lib/constants/const.dart` + backend):
///   - `voiceEmoji` (emit)  : client -> server, payload:
///       {
///         "liveStreamingId": "<room id>",
///         "emojiId": "applause",
///         "senderId": "<user id>",
///         "senderName": "<name>",
///         "senderAvatar": "<url>"
///       }
///   - `voiceEmoji` (listen): server -> all room members, payload:
///       {
///         "emojiId": "applause",
///         "senderId": "<user id>",
///         "senderName": "<name>",
///         "senderAvatar": "<url>",
///         "timestamp": 1700000000000
///       }
///   - The local sender should ignore its own echo (the picker already plays
///     a send sound) to avoid double playback — same pattern as gifts.
library;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/api_service.dart';
import '../utils/log.dart';
import 'preloader.dart';
import 'svga_player_widget.dart';

/// ---------------------------------------------------------------------------
/// Model
/// ---------------------------------------------------------------------------

/// A single voice emoji definition.
///
/// [animationUrl] is an SVGA file played by [SvgaPlayer]; [soundUrl] is a
/// short audio clip played via [just_audio]. When [isVipExclusive] is true
/// only VIP users may send it (enforced in [VoiceEmojiPicker]).
class VoiceEmoji {
  const VoiceEmoji({
    required this.id,
    required this.name,
    required this.iconUrl,
    required this.animationUrl,
    required this.soundUrl,
    this.isVipExclusive = false,
  });

  /// Stable identifier sent over the socket (e.g. `applause`).
  final String id;
  /// Display name shown under the icon.
  final String name;
  /// Static thumbnail URL (network or asset).
  final String iconUrl;
  /// SVGA animation URL played in the overlay.
  final String animationUrl;
  /// Sound effect URL played alongside the animation.
  final String soundUrl;
  /// When true, only VIP users may send this emoji.
  final bool isVipExclusive;

  /// Parse a backend payload into a [VoiceEmoji].
  factory VoiceEmoji.fromJson(Map<String, dynamic> json) {
    return VoiceEmoji(
      id: parseString(json, 'id') ?? parseString(json, 'emojiId') ?? '',
      name: parseString(json, 'name') ?? '',
      iconUrl: parseString(json, 'iconUrl') ?? '',
      animationUrl: parseString(json, 'animationUrl') ?? '',
      soundUrl: parseString(json, 'soundUrl') ?? '',
      isVipExclusive: parseBool(json, 'isVipExclusive'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconUrl': iconUrl,
        'animationUrl': animationUrl,
        'soundUrl': soundUrl,
        'isVipExclusive': isVipExclusive,
      };

  // ---- small JSON helpers (kept local to avoid an extra import) -----------
  static String? parseString(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return null;
    return v.toString();
  }

  static bool parseBool(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.toLowerCase() == 'true' || v == '1';
    return false;
  }

  /// Built-in default emoji catalogue. Asset paths are placeholders — swap
  /// for production URLs once the backend serves the catalogue endpoint
  /// (`GET /api/v1/voice-emoji/list`).
  static List<VoiceEmoji> get defaults => const [
        VoiceEmoji(
          id: 'applause',
          name: 'Applause',
          iconUrl: 'assets/voice_emoji/applause.webp',
          animationUrl: 'assets/voice_emoji/applause.svga',
          soundUrl: 'assets/sounds/voice_emoji/applause.mp3',
        ),
        VoiceEmoji(
          id: 'laughter',
          name: 'Laughter',
          iconUrl: 'assets/voice_emoji/laughter.webp',
          animationUrl: 'assets/voice_emoji/laughter.svga',
          soundUrl: 'assets/sounds/voice_emoji/laughter.mp3',
        ),
        VoiceEmoji(
          id: 'heart',
          name: 'Heart',
          iconUrl: 'assets/voice_emoji/heart.webp',
          animationUrl: 'assets/voice_emoji/heart.svga',
          soundUrl: 'assets/sounds/voice_emoji/heart.mp3',
        ),
        VoiceEmoji(
          id: 'thumbsup',
          name: 'Thumbs Up',
          iconUrl: 'assets/voice_emoji/thumbsup.webp',
          animationUrl: 'assets/voice_emoji/thumbsup.svga',
          soundUrl: 'assets/sounds/voice_emoji/thumbsup.mp3',
        ),
        VoiceEmoji(
          id: 'crying',
          name: 'Crying',
          iconUrl: 'assets/voice_emoji/crying.webp',
          animationUrl: 'assets/voice_emoji/crying.svga',
          soundUrl: 'assets/sounds/voice_emoji/crying.mp3',
        ),
        VoiceEmoji(
          id: 'angry',
          name: 'Angry',
          iconUrl: 'assets/voice_emoji/angry.webp',
          animationUrl: 'assets/voice_emoji/angry.svga',
          soundUrl: 'assets/sounds/voice_emoji/angry.mp3',
        ),
        VoiceEmoji(
          id: 'surprise',
          name: 'Surprise',
          iconUrl: 'assets/voice_emoji/surprise.webp',
          animationUrl: 'assets/voice_emoji/surprise.svga',
          soundUrl: 'assets/sounds/voice_emoji/surprise.mp3',
        ),
        VoiceEmoji(
          id: 'cool',
          name: 'Cool',
          iconUrl: 'assets/voice_emoji/cool.webp',
          animationUrl: 'assets/voice_emoji/cool.svga',
          soundUrl: 'assets/sounds/voice_emoji/cool.mp3',
        ),
        VoiceEmoji(
          id: 'fire',
          name: 'Fire',
          iconUrl: 'assets/voice_emoji/fire.webp',
          animationUrl: 'assets/voice_emoji/fire.svga',
          soundUrl: 'assets/sounds/voice_emoji/fire.mp3',
        ),
        VoiceEmoji(
          id: 'party',
          name: 'Party',
          iconUrl: 'assets/voice_emoji/party.webp',
          animationUrl: 'assets/voice_emoji/party.svga',
          soundUrl: 'assets/sounds/voice_emoji/party.mp3',
          isVipExclusive: true,
        ),
      ];
}

/// ---------------------------------------------------------------------------
/// Sound player
/// ---------------------------------------------------------------------------

/// Lazy singleton wrapping [just_audio] for voice-emoji sound effects.
///
/// Reuses a single [AudioPlayer] and swaps the [AudioSource] per emoji so we
/// don't pay the native player creation cost on every tap. Errors are logged
/// but never thrown — sound is best-effort and must never crash the room.
class VoiceEmojiSoundService {
  VoiceEmojiSoundService._();
  static final VoiceEmojiSoundService instance = VoiceEmojiSoundService._();

  final _tag = 'VoiceEmojiSound';
  AudioPlayer? _player;

  /// Mute/unmute all voice-emoji sounds (e.g. when the room is muted).
  bool muted = false;

  AudioPlayer _playerInstance() {
    _player ??= AudioPlayer();
    return _player!;
  }

  /// Play the sound for [emoji]. Safe to call from any isolate-aware callback.
  Future<void> play(VoiceEmoji emoji) async {
    if (muted) return;
    final url = emoji.soundUrl;
    if (url.isEmpty) return;
    try {
      final player = _playerInstance();
      await player.setAudioSource(
        url.startsWith('http')
            ? AudioSource.uri(Uri.parse(url))
            : AudioSource.asset(url),
      );
      await player.seek(Duration.zero);
      await player.play();
    } catch (e, st) {
      Log.e(_tag, 'play failed for ${emoji.id}', e, st);
    }
  }

  /// Stop any currently playing sound.
  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (e, st) {
      Log.e(_tag, 'stop failed', e, st);
    }
  }

  /// Release native resources. Call on app teardown / room exit.
  Future<void> dispose() async {
    try {
      await _player?.dispose();
    } catch (e, st) {
      Log.e(_tag, 'dispose failed', e, st);
    }
    _player = null;
  }
}

/// ---------------------------------------------------------------------------
/// Picker sheet
/// ---------------------------------------------------------------------------

/// Bottom sheet that shows a horizontally scrollable grid of voice emojis.
///
/// Tapping an emoji calls [onSelected] (the caller emits the socket event and
/// plays the send sound). VIP-exclusive emojis are rendered with a lock badge
/// and are disabled when [canUseVipExclusive] is false.
class VoiceEmojiPicker extends StatefulWidget {
  const VoiceEmojiPicker({
    super.key,
    this.emojis,
    this.canUseVipExclusive = false,
    this.onSelected,
  });

  /// Override the default catalogue (e.g. from the backend).
  final List<VoiceEmoji>? emojis;
  /// Whether the current user may send VIP-exclusive emojis.
  final bool canUseVipExclusive;
  /// Called with the chosen emoji. The sheet closes itself afterwards.
  final void Function(VoiceEmoji emoji)? onSelected;

  /// Show the picker as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    List<VoiceEmoji>? emojis,
    bool canUseVipExclusive = false,
    void Function(VoiceEmoji emoji)? onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => VoiceEmojiPicker(
        emojis: emojis,
        canUseVipExclusive: canUseVipExclusive,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<VoiceEmojiPicker> createState() => _VoiceEmojiPickerState();
}

class _VoiceEmojiPickerState extends State<VoiceEmojiPicker> {
  List<VoiceEmoji> _emojis = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _emojis = widget.emojis ?? VoiceEmoji.defaults;
    _fetchFromBackend();
  }

  Future<void> _fetchFromBackend() async {
    try {
      final list = await ApiService.getVoiceEmojis();
      if (list.isNotEmpty && mounted) {
        setState(() {
          _emojis = list.map((j) => VoiceEmoji.fromJson(j)).toList();
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      Log.e('VoiceEmojiPicker', 'fetchFromBackend failed', e);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleTap(VoiceEmoji emoji) {
    if (emoji.isVipExclusive && !widget.canUseVipExclusive) {
      Log.d('VoiceEmojiPicker', 'vip-exclusive emoji blocked: ${emoji.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('VIP exclusive emoji — upgrade to send.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Log.d('VoiceEmojiPicker', 'selected: ${emoji.id}');
    widget.onSelected?.call(emoji);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // 4 columns, ~88px tall cells, horizontally scrollable rows.
    const crossAxisCount = 4;
    final cellWidth = (width - 24) / crossAxisCount;
    final rows = (_emojis.length / crossAxisCount).ceil();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Voice Emoji',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: (cellWidth * 1.35 + 8) * rows.clamp(1, 2),
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: rows.clamp(1, 2),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: _emojis.length,
                itemBuilder: (context, index) {
                  final emoji = _emojis[index];
                  final locked =
                      emoji.isVipExclusive && !widget.canUseVipExclusive;
                  return _EmojiCell(
                    emoji: emoji,
                    locked: locked,
                    onTap: () => _handleTap(emoji),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiCell extends StatelessWidget {
  const _EmojiCell({
    required this.emoji,
    required this.locked,
    required this.onTap,
  });

  final VoiceEmoji emoji;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.45 : 1.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topLeft,
              children: [
                _buildIcon(),
                if (locked)
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: Icon(Icons.lock, size: 14, color: Colors.amber),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              emoji.name,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final url = emoji.iconUrl;
    final isNetwork = url.startsWith('http');
    return SizedBox(
      width: 56,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: isNetwork
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Preloader(),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.emoji_emotions_outlined,
                        color: Colors.white54, size: 32),
              )
            : Image.asset(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.emoji_emotions_outlined,
                        color: Colors.white54, size: 32),
              ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Overlay (animation + sound on receive)
/// ---------------------------------------------------------------------------

/// A single received voice-emoji event rendered by [VoiceEmojiOverlay].
class VoiceEmojiEvent {
  const VoiceEmojiEvent({
    required this.emoji,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    this.timestamp,
  });

  final VoiceEmoji emoji;
  final String senderId;
  final String? senderName;
  final String? senderAvatar;
  final int? timestamp;

  factory VoiceEmojiEvent.fromSocket(
    Map<String, dynamic> data,
    List<VoiceEmoji> catalogue,
  ) {
    final emojiId = VoiceEmoji.parseString(data, 'emojiId') ??
        VoiceEmoji.parseString(data, 'id') ??
        '';
    final emoji = catalogue.firstWhere(
      (e) => e.id == emojiId,
      orElse: () => VoiceEmoji.fromJson(data),
    );
    return VoiceEmojiEvent(
      emoji: emoji,
      senderId: VoiceEmoji.parseString(data, 'senderId') ?? '',
      senderName: VoiceEmoji.parseString(data, 'senderName'),
      senderAvatar: VoiceEmoji.parseString(data, 'senderAvatar'),
      timestamp: int.tryParse(
          (data['timestamp'] ?? data['time'] ?? '').toString()),
    );
  }
}

/// Full-room overlay that plays the SVGA animation + sound for each received
/// voice emoji. Stack this on top of the audio room (or live room) tree.
///
/// Usage:
/// ```dart
/// VoiceEmojiOverlay(
///   key: _voiceEmojiOverlayKey,
///   localUserId: currentUserId,
///   catalogue: VoiceEmoji.defaults,
/// )
/// ```
/// Then call `overlay.show(VoiceEmojiEvent(...))` from the socket handler.
class VoiceEmojiOverlay extends StatefulWidget {
  const VoiceEmojiOverlay({
    super.key,
    required this.localUserId,
    this.catalogue,
    this.duration = const Duration(seconds: 4),
  });

  /// Used to skip the sender's own echo (send sound already played locally).
  final String localUserId;
  /// Emoji catalogue used to resolve socket payloads.
  final List<VoiceEmoji>? catalogue;
  /// How long each overlay stays visible.
  final Duration duration;

  @override
  State<VoiceEmojiOverlay> createState() => VoiceEmojiOverlayState();
}

class VoiceEmojiOverlayState extends State<VoiceEmojiOverlay> {
  final _tag = 'VoiceEmojiOverlay';
  final List<_ActiveEmoji> _active = [];
  int _seq = 0;

  List<VoiceEmoji> get _catalogue => widget.catalogue ?? VoiceEmoji.defaults;

  /// Show a received voice-emoji event. If [event.senderId] matches the local
  /// user the overlay is skipped (the picker already played the send sound).
  void show(VoiceEmojiEvent event) {
    if (event.senderId == widget.localUserId) {
      Log.d(_tag, 'skipping local echo for ${event.emoji.id}');
      return;
    }
    final id = ++_seq;
    Log.d(_tag, 'show #${event.emoji.id} (slot $id)');
    setState(() => _active.add(_ActiveEmoji(id: id, event: event)));
    VoiceEmojiSoundService.instance.play(event.emoji);
    Future.delayed(widget.duration, () {
      if (!mounted) return;
      setState(() => _active.removeWhere((a) => a.id == id));
    });
  }

  /// Convenience wrapper: build a [VoiceEmojiEvent] from a raw socket payload.
  void showFromSocket(Map<String, dynamic> data) {
    show(VoiceEmojiEvent.fromSocket(data, _catalogue));
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.topLeft,
        children: _active.map(_buildSlot).toList(),
      ),
    );
  }

  Widget _buildSlot(_ActiveEmoji slot) {
    final event = slot.event;
    return Positioned.fill(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SenderChip(event: event),
              const SizedBox(height: 8),
              SvgaPlayer(
                url: event.emoji.animationUrl,
                width: 180,
                height: 180,
                playEmbeddedAudio: false,
                fallbackImage: event.emoji.iconUrl,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveEmoji {
  const _ActiveEmoji({required this.id, required this.event});
  final int id;
  final VoiceEmojiEvent event;
}

class _SenderChip extends StatelessWidget {
  const _SenderChip({required this.event});
  final VoiceEmojiEvent event;

  @override
  Widget build(BuildContext context) {
    final avatar = event.senderAvatar;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avatar != null && avatar.isNotEmpty)
            ClipOval(
              child: SizedBox(
                width: 20,
                height: 20,
                child: avatar.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: avatar,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.person, size: 14,
                                color: Colors.white70),
                      )
                    : Image.asset(avatar, fit: BoxFit.cover),
              ),
            ),
          if (event.senderName != null) ...[
            const SizedBox(width: 6),
            Text(
              event.senderName!,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
