/// Audio PK battle overlay — shows score bar at top during PK battle.
///
/// Ported from native PK score bar in `WatchAudioLiveActivity.java`.
/// Displays both hosts' avatars, names, scores, and a progress bar showing
/// who's winning. Also shows PK timer and round info.
library pk_battle_overlay;
import 'package:flutter/material.dart';

import 'user_avatar.dart';

/// Audio PK battle participant seat — a lightweight seat representation for
/// the split-room PK layout. Each room shows its host + guests.
class PkBattleSeat {
  final String? userId;
  final String? name;
  final String? image;
  final int position;
  final int mute;
  final bool isHost;
  final bool isSpeaking;
  final String? voiceWaveUrl;

  const PkBattleSeat({
    this.userId,
    this.name,
    this.image,
    required this.position,
    this.mute = 0,
    this.isHost = false,
    this.isSpeaking = false,
    this.voiceWaveUrl,
  });

  bool get isOccupied => (userId ?? '').isNotEmpty;
  bool get isMuted => mute > 0;
  bool get isSelfMuted => mute == 2;

  factory PkBattleSeat.fromJson(Map<String, dynamic> json) {
    final role = json['role']?.toString() ?? 'user';
    return PkBattleSeat(
      userId: json['userId']?.toString(),
      name: json['name']?.toString(),
      image: json['image']?.toString(),
      position: (json['position'] as num?)?.toInt() ??
          int.tryParse(json['position']?.toString() ?? '') ??
          0,
      mute: (json['mute'] as num?)?.toInt() ??
          int.tryParse(json['mute']?.toString() ?? '') ??
          0,
      isHost: role == 'host' || json['isHost'] == true,
      isSpeaking: json['isSpeaking'] == true,
      voiceWaveUrl: json['voiceWaveUrl']?.toString(),
    );
  }
}

/// One side of an audio PK battle — a host + their room's guest seats.
class PkBattleRoom {
  final String hostName;
  final String? hostImage;
  final String? hostId;
  final String? roomId;
  final int score;
  final List<PkBattleSeat> seats;

  const PkBattleRoom({
    required this.hostName,
    this.hostImage,
    this.hostId,
    this.roomId,
    this.score = 0,
    this.seats = const [],
  });

  PkBattleRoom copyWith({
    String? hostName,
    String? hostImage,
    String? hostId,
    String? roomId,
    int? score,
    List<PkBattleSeat>? seats,
  }) =>
      PkBattleRoom(
        hostName: hostName ?? this.hostName,
        hostImage: hostImage ?? this.hostImage,
        hostId: hostId ?? this.hostId,
        roomId: roomId ?? this.roomId,
        score: score ?? this.score,
        seats: seats ?? this.seats,
      );
}

/// State data for an active PK battle.
class PkBattleState {
  final String host1Name;
  final String? host1Image;
  final String host2Name;
  final String? host2Image;
  final int host1Score;
  final int host2Score;
  final int round;
  final int totalRounds;
  final int remainingSeconds;
  final bool isPunishment;

  /// Extended split-room data for the two-room audio PK layout.
  final PkBattleRoom? room1;
  final PkBattleRoom? room2;

  PkBattleState({
    required this.host1Name,
    this.host1Image,
    required this.host2Name,
    this.host2Image,
    this.host1Score = 0,
    this.host2Score = 0,
    this.round = 1,
    this.totalRounds = 3,
    this.remainingSeconds = 300,
    this.isPunishment = false,
    this.room1,
    this.room2,
  });

  PkBattleState copyWith({
    String? host1Name,
    String? host1Image,
    String? host2Name,
    String? host2Image,
    int? host1Score,
    int? host2Score,
    int? round,
    int? totalRounds,
    int? remainingSeconds,
    bool? isPunishment,
    PkBattleRoom? room1,
    PkBattleRoom? room2,
  }) =>
      PkBattleState(
        host1Name: host1Name ?? this.host1Name,
        host1Image: host1Image ?? this.host1Image,
        host2Name: host2Name ?? this.host2Name,
        host2Image: host2Image ?? this.host2Image,
        host1Score: host1Score ?? this.host1Score,
        host2Score: host2Score ?? this.host2Score,
        round: round ?? this.round,
        totalRounds: totalRounds ?? this.totalRounds,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        isPunishment: isPunishment ?? this.isPunishment,
        room1: room1 ?? this.room1,
        room2: room2 ?? this.room2,
      );

  factory PkBattleState.fromSocketJson(Map<String, dynamic> json) {
    final host1 = json['host1'] is Map
        ? Map<String, dynamic>.from(json['host1'] as Map)
        : <String, dynamic>{};
    final host2 = json['host2'] is Map
        ? Map<String, dynamic>.from(json['host2'] as Map)
        : <String, dynamic>{};

    // Parse room1 / room2 extended data if present.
    PkBattleRoom? parseRoom(Map<String, dynamic>? m, String fallbackName, String? fallbackImage) {
      if (m == null) return null;
      final seatsRaw = m['seats'] ?? m['seat'];
      final seats = <PkBattleSeat>[];
      if (seatsRaw is List) {
        for (final s in seatsRaw) {
          if (s is Map) {
            seats.add(PkBattleSeat.fromJson(Map<String, dynamic>.from(s)));
          }
        }
      }
      return PkBattleRoom(
        hostName: m['name']?.toString() ?? m['hostName']?.toString() ?? fallbackName,
        hostImage: m['image']?.toString() ?? m['hostImage']?.toString() ?? fallbackImage,
        hostId: m['hostId']?.toString() ?? m['userId']?.toString() ?? m['liveUserId']?.toString(),
        roomId: m['roomId']?.toString() ?? m['liveStreamingId']?.toString(),
        score: (m['score'] as num?)?.toInt() ?? 0,
        seats: seats,
      );
    }

    final room1 = parseRoom(
      json['room1'] is Map ? Map<String, dynamic>.from(json['room1'] as Map) : null,
      host1['name']?.toString() ?? json['host1Name']?.toString() ?? 'Host 1',
      host1['image']?.toString() ?? json['host1Image']?.toString(),
    );
    final room2 = parseRoom(
      json['room2'] is Map ? Map<String, dynamic>.from(json['room2'] as Map) : null,
      host2['name']?.toString() ?? json['host2Name']?.toString() ?? 'Host 2',
      host2['image']?.toString() ?? json['host2Image']?.toString(),
    );

    return PkBattleState(
      host1Name: host1['name']?.toString() ?? json['host1Name']?.toString() ?? 'Host 1',
      host1Image: host1['image']?.toString() ?? json['host1Image']?.toString(),
      host2Name: host2['name']?.toString() ?? json['host2Name']?.toString() ?? 'Host 2',
      host2Image: host2['image']?.toString() ?? json['host2Image']?.toString(),
      host1Score: (json['host1Score'] as num?)?.toInt() ?? room1?.score ?? 0,
      host2Score: (json['host2Score'] as num?)?.toInt() ?? room2?.score ?? 0,
      round: (json['round'] as num?)?.toInt() ?? 1,
      totalRounds: (json['totalRounds'] as num?)?.toInt() ?? 3,
      remainingSeconds: (json['remainingSeconds'] as num?)?.toInt() ?? 300,
      isPunishment: json['isPunishment'] == true,
      room1: room1,
      room2: room2,
    );
  }
}

/// PK battle overlay widget — embed in a Stack to display PK score bar.
/// Bigo-style polished design with animated score bars, glow effects,
/// punishment visuals, and dramatic VS badge.
class PkBattleOverlay extends StatefulWidget {
  final PkBattleState state;
  final bool isHost1Me;
  final int? host1Votes;
  final int? host2Votes;
  final VoidCallback? onVote;
  final VoidCallback? onCheer;

  const PkBattleOverlay({
    super.key,
    required this.state,
    this.isHost1Me = false,
    this.host1Votes,
    this.host2Votes,
    this.onVote,
    this.onCheer,
  });

  @override
  State<PkBattleOverlay> createState() => _PkBattleOverlayState();
}

class _PkBattleOverlayState extends State<PkBattleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.state.isPunishment) _glowCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PkBattleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.isPunishment && !_glowCtrl.isAnimating) {
      _glowCtrl.repeat(reverse: true);
    } else if (!widget.state.isPunishment && _glowCtrl.isAnimating) {
      _glowCtrl.stop();
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final totalScore = state.host1Score + state.host2Score;
    final host1Ratio = totalScore > 0 ? state.host1Score / totalScore : 0.5;
    final host1Winning = state.host1Score > state.host2Score;
    final host2Winning = state.host2Score > state.host1Score;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 4,
      left: 8,
      right: 8,
      child: AnimatedBuilder(
        animation: _glowCtrl,
        builder: (ctx, child) {
          final glowAlpha = state.isPunishment ? 0.3 + (_glowCtrl.value * 0.4) : 0.0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: state.isPunishment
                    ? Colors.red.withValues(alpha: glowAlpha)
                    : const Color(0xFF7E3FF2).withValues(alpha: 0.5),
                width: state.isPunishment ? 2 : 1,
              ),
              boxShadow: state.isPunishment
                  ? [BoxShadow(color: Colors.red.withValues(alpha: glowAlpha * 0.5), blurRadius: 16)]
                  : [BoxShadow(color: const Color(0xFF7E3FF2).withValues(alpha: 0.2), blurRadius: 8)],
            ),
            child: child,
          );
        },
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Top row: avatars + VS + timer
          Row(children: [
            // Host 1 (left)
            Expanded(child: Row(children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: host1Winning ? const Color(0xFFFFD700) : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: host1Winning
                      ? [const BoxShadow(color: Color(0x66FFD700), blurRadius: 8)]
                      : null,
                ),
                child: UserAvatar(imageUrl: state.host1Image, size: 34),
              ),
              const SizedBox(width: 6),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(state.host1Name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      shadows: host1Winning
                          ? [const Shadow(color: Color(0xFFFFD700), blurRadius: 4)]
                          : null,
                    )),
                Row(children: [
                  const Icon(Icons.diamond, color: Color(0xFF00E5FF), size: 10),
                  const SizedBox(width: 2),
                  Text('${state.host1Score}',
                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.bold)),
                ]),
                if (widget.host1Votes != null && widget.host1Votes! > 0)
                  Text('${widget.host1Votes} votes',
                      style: const TextStyle(color: Colors.white54, fontSize: 8)),
              ])),
            ])),
            // Center: VS badge with glow + timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: state.isPunishment
                      ? [Colors.red, Colors.orange]
                      : [const Color(0xFF7E3FF2), const Color(0xFFE91E63)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: (state.isPunishment ? Colors.red : const Color(0xFFE91E63))
                        .withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(children: [
                Text(
                  state.isPunishment ? 'PUNISH' : 'VS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: state.isPunishment ? 10 : 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(_formatTime(state.remainingSeconds),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
            // Host 2 (right)
            Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(state.host2Name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      shadows: host2Winning
                          ? [const Shadow(color: Color(0xFFFFD700), blurRadius: 4)]
                          : null,
                    )),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('${state.host2Score}',
                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 2),
                  const Icon(Icons.diamond, color: Color(0xFF00E5FF), size: 10),
                ]),
                if (widget.host2Votes != null && widget.host2Votes! > 0)
                  Text('${widget.host2Votes} votes',
                      style: const TextStyle(color: Colors.white54, fontSize: 8)),
              ])),
              const SizedBox(width: 6),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: host2Winning ? const Color(0xFFFFD700) : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: host2Winning
                      ? [const BoxShadow(color: Color(0x66FFD700), blurRadius: 8)]
                      : null,
                ),
                child: UserAvatar(imageUrl: state.host2Image, size: 34),
              ),
            ])),
          ]),
          const SizedBox(height: 6),
          // Animated score progress bar with gradient
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(children: [
                Expanded(
                  flex: (host1Ratio * 100).round().clamp(1, 99),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF7E3FF2), Color(0xFF9C27B0)],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                Container(width: 2, color: Colors.white),
                Expanded(
                  flex: ((1 - host1Ratio) * 100).round().clamp(1, 99),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFFFF5722)],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          // Round pills + action buttons
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            // Round indicator pills
            Row(children: List.generate(state.totalRounds, (i) {
              final roundNum = i + 1;
              final isCurrent = roundNum == state.round;
              final isPast = roundNum < state.round;
              return Container(
                width: 18,
                height: 4,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF7E3FF2)
                      : isPast
                          ? Colors.white30
                          : Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            })),
            Row(children: [
              if (widget.onVote != null)
                GestureDetector(
                  onTap: widget.onVote,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7E3FF2), Color(0xFF9C27B0)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7E3FF2).withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.how_to_vote, color: Colors.white, size: 11),
                      SizedBox(width: 3),
                      Text('Vote', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              const SizedBox(width: 6),
              if (widget.onCheer != null)
                GestureDetector(
                  onTap: widget.onCheer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFFFF5722)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.favorite, color: Colors.white, size: 11),
                      SizedBox(width: 3),
                      Text('Cheer', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
            ]),
          ]),
        ]),
      ),
    );
  }
}

/// Two-room split-seat audio PK layout.
///
/// Renders both PK rooms side-by-side: Host 1 + their room's guest seats on
/// the left, Host 2 + their room's guest seats on the right. A central VS /
/// score / timer column separates the two rooms. This replaces the old
/// top-only score bar with a synchronized split-room presentation matching
/// the user's reference screenshots.
class AudioPkSplitRoomOverlay extends StatefulWidget {
  final PkBattleState state;
  final bool isHost1Me;
  final int? host1Votes;
  final int? host2Votes;
  final VoidCallback? onVote;
  final VoidCallback? onCheer;

  const AudioPkSplitRoomOverlay({
    super.key,
    required this.state,
    this.isHost1Me = false,
    this.host1Votes,
    this.host2Votes,
    this.onVote,
    this.onCheer,
  });

  @override
  State<AudioPkSplitRoomOverlay> createState() =>
      _AudioPkSplitRoomOverlayState();
}

class _AudioPkSplitRoomOverlayState extends State<AudioPkSplitRoomOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.state.isPunishment) _glowCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AudioPkSplitRoomOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.isPunishment && !_glowCtrl.isAnimating) {
      _glowCtrl.repeat(reverse: true);
    } else if (!widget.state.isPunishment && _glowCtrl.isAnimating) {
      _glowCtrl.stop();
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final totalScore = state.host1Score + state.host2Score;
    final host1Ratio = totalScore > 0 ? state.host1Score / totalScore : 0.5;
    final host1Winning = state.host1Score > state.host2Score;
    final host2Winning = state.host2Score > state.host1Score;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 4,
      left: 4,
      right: 4,
      child: AnimatedBuilder(
        animation: _glowCtrl,
        builder: (ctx, child) {
          final glowAlpha =
              state.isPunishment ? 0.3 + (_glowCtrl.value * 0.4) : 0.0;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: state.isPunishment
                    ? Colors.red.withValues(alpha: glowAlpha)
                    : const Color(0xFF7E3FF2).withValues(alpha: 0.5),
                width: state.isPunishment ? 2 : 1,
              ),
              boxShadow: state.isPunishment
                  ? [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: glowAlpha * 0.5),
                        blurRadius: 16,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFF7E3FF2)
                            .withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ],
            ),
            child: child,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                  Color(0xFF1A1A2E),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top: score bar + VS center
                _buildTopBar(
                  state,
                  host1Ratio,
                  host1Winning,
                  host2Winning,
                ),
                // Middle: two-room split seats
                _buildSplitRooms(state),
                // Bottom: round pills + action buttons
                _buildBottomBar(state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    PkBattleState state,
    double host1Ratio,
    bool host1Winning,
    bool host2Winning,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Host 1 (left)
              Expanded(
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: host1Winning
                              ? const Color(0xFFFFD700)
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: host1Winning
                            ? [
                                const BoxShadow(
                                  color: Color(0x66FFD700),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: UserAvatar(
                        imageUrl: state.host1Image,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.host1Name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              shadows: host1Winning
                                  ? [
                                      const Shadow(
                                        color: Color(0xFFFFD700),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.diamond,
                                color: Color(0xFF00E5FF),
                                size: 10,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${state.host1Score}',
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Center: VS badge + timer
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: state.isPunishment
                        ? [Colors.red, Colors.orange]
                        : [
                            const Color(0xFF7E3FF2),
                            const Color(0xFFE91E63),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (state.isPunishment
                              ? Colors.red
                              : const Color(0xFFE91E63))
                          .withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      state.isPunishment ? 'PUNISH' : 'VS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: state.isPunishment ? 10 : 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(state.remainingSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Host 2 (right)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            state.host2Name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              shadows: host2Winning
                                  ? [
                                      const Shadow(
                                        color: Color(0xFFFFD700),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${state.host2Score}',
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.diamond,
                                color: Color(0xFF00E5FF),
                                size: 10,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: host2Winning
                              ? const Color(0xFFFFD700)
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: host2Winning
                            ? [
                                const BoxShadow(
                                  color: Color(0x66FFD700),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: UserAvatar(
                        imageUrl: state.host2Image,
                        size: 34,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Animated score progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: (host1Ratio * 100).round().clamp(1, 99),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF7E3FF2), Color(0xFF9C27B0)],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Container(width: 2, color: Colors.white),
                  Expanded(
                    flex: ((1 - host1Ratio) * 100).round().clamp(1, 99),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFFFF5722)],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitRooms(PkBattleState state) {
    final room1 = state.room1;
    final room2 = state.room2;

    // If no extended room data is available, show a loading/placeholder.
    if (room1 == null && room2 == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildRoomPlaceholder(state.host1Name, state.host1Image, true),
            _buildRoomPlaceholder(state.host2Name, state.host2Image, false),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildRoomSide(
                room1,
                state.host1Name,
                state.host1Image,
                true,
              ),
            ),
            Container(
              width: 1,
              color: Colors.white.withValues(alpha: 0.15),
              margin: const EdgeInsets.symmetric(horizontal: 2),
            ),
            Expanded(
              child: _buildRoomSide(
                room2,
                state.host2Name,
                state.host2Image,
                false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomPlaceholder(
    String name,
    String? image,
    bool isLeft,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(imageUrl: image, size: 40),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          'Loading room…',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9),
        ),
      ],
    );
  }

  Widget _buildRoomSide(
    PkBattleRoom? room,
    String fallbackName,
    String? fallbackImage,
    bool isLeft,
  ) {
    final hostName = room?.hostName ?? fallbackName;
    final hostImage = room?.hostImage ?? fallbackImage;
    final seats = room?.seats ?? const <PkBattleSeat>[];
    // Guest seats = non-host, occupied seats.
    final guestSeats = seats.where((s) => !s.isHost && s.isOccupied).toList();
    final accent = isLeft
        ? const Color(0xFF7E3FF2)
        : const Color(0xFFE91E63);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Room label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isLeft ? 'Room 1' : 'Room 2',
              style: TextStyle(
                color: accent,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Host seat (owner)
          _buildSeatAvatar(
            name: hostName,
            image: hostImage,
            isHost: true,
            isSpeaking: false,
            isMuted: false,
            accent: accent,
            size: 44,
          ),
          const SizedBox(height: 6),
          // Guest seats grid (2 columns)
          if (guestSeats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No guests',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 9,
                ),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: isLeft
                  ? WrapAlignment.start
                  : WrapAlignment.end,
              children: guestSeats
                  .take(6)
                  .map(
                    (s) => _buildSeatAvatar(
                      name: s.name ?? 'User',
                      image: s.image,
                      isHost: false,
                      isSpeaking: s.isSpeaking,
                      isMuted: s.isMuted,
                      accent: accent,
                      size: 32,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSeatAvatar({
    required String name,
    required String? image,
    required bool isHost,
    required bool isSpeaking,
    required bool isMuted,
    required Color accent,
    required double size,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isHost
                      ? accent
                      : (isSpeaking
                          ? const Color(0xFF00E5FF)
                          : Colors.white.withValues(alpha: 0.2)),
                  width: isHost ? 2 : 1,
                ),
                boxShadow: isSpeaking
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00E5FF)
                              .withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
              child: UserAvatar(imageUrl: image, size: size),
            ),
            if (isMuted)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_off,
                    color: Colors.white,
                    size: 10,
                  ),
                ),
              ),
            if (isHost)
              Positioned(
                left: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'HOST',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: size + 10,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 9,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(PkBattleState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Round indicator pills
          Row(
            children: List.generate(state.totalRounds, (i) {
              final roundNum = i + 1;
              final isCurrent = roundNum == state.round;
              final isPast = roundNum < state.round;
              return Container(
                width: 18,
                height: 4,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF7E3FF2)
                      : isPast
                          ? Colors.white30
                          : Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
          Row(
            children: [
              if (widget.onVote != null)
                GestureDetector(
                  onTap: widget.onVote,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7E3FF2), Color(0xFF9C27B0)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7E3FF2)
                              .withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.how_to_vote, color: Colors.white, size: 11),
                        SizedBox(width: 3),
                        Text(
                          'Vote',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              if (widget.onCheer != null)
                GestureDetector(
                  onTap: widget.onCheer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFFFF5722)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite, color: Colors.white, size: 11),
                        SizedBox(width: 3),
                        Text(
                          'Cheer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
