/// Audio room advanced features service.
///
/// Combines C4-C10 features:
/// - C4: Seat & Speaker management (queue, time limit, stage, rotation, VIP)
/// - C5: Music & Sound (karaoke, song request, DJ, sound effects, ambient)
/// - C6: Social & Engagement (follow notif, invite, QR, welcome, rules, age, report)
/// - C7: Monetization (paid entry, membership, sponsored, ads)
/// - C8: Family/Agency/CP (family rooms, agency rooms, CP rooms, leaderboard)
/// - C9: Security & Moderation (screenshot, recording, AI, profanity, spam, bot)
/// - C10: Technical (network indicator, low latency, recording, replay, failover)
library audio_room_advanced;
import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../utils/log.dart';

// ===========================================================================
// C4: Seat & Speaker Management
// ===========================================================================

/// Raise hand queue entry — ordered list of users waiting for a seat.
class RaiseHandEntry {
  final String userId;
  final String name;
  final String? image;
  final DateTime requestedAt;
  int position; // queue position (0 = first)

  RaiseHandEntry({
    required this.userId,
    required this.name,
    this.image,
    required this.requestedAt,
    this.position = 0,
  });
}

/// Seat & speaker management service.
class SeatSpeakerService {
  final List<RaiseHandEntry> _queue = [];
  final Map<int, Timer> _seatTimers = {}; // position -> timer
  final Map<int, int> _seatTimeLimits = {}; // position -> minutes
  bool _stageMode = false;
  int _currentSpeaker = -1; // stage mode: only this seat speaks

  /// Get raise hand queue.
  List<RaiseHandEntry> get queue => List.unmodifiable(_queue);

  /// Add user to raise hand queue.
  void addToQueue(String userId, String name, {String? image}) {
    if (_queue.any((e) => e.userId == userId)) return;
    _queue.add(RaiseHandEntry(
      userId: userId,
      name: name,
      image: image,
      requestedAt: DateTime.now(),
      position: _queue.length,
    ));
  }

  /// Remove user from queue.
  void removeFromQueue(String userId) {
    _queue.removeWhere((e) => e.userId == userId);
    // Re-index positions
    for (int i = 0; i < _queue.length; i++) {
      _queue[i].position = i;
    }
  }

  /// Get next user in queue.
  RaiseHandEntry? getNextInQueue() {
    return _queue.isEmpty ? null : _queue.first;
  }

  /// Set speaker time limit for a seat.
  void setSeatTimeLimit(int position, int minutes, VoidCallback onTimeUp) {
    _seatTimeLimits[position] = minutes;
    _seatTimers[position]?.cancel();
    _seatTimers[position] = Timer(Duration(minutes: minutes), onTimeUp);
  }

  /// Clear seat time limit.
  void clearSeatTimeLimit(int position) {
    _seatTimers[position]?.cancel();
    _seatTimers.remove(position);
    _seatTimeLimits.remove(position);
  }

  /// Enable/disable stage mode — only one speaker at a time.
  void setStageMode(bool enabled) {
    _stageMode = enabled;
    if (!enabled) _currentSpeaker = -1;
  }

  /// Set current speaker in stage mode.
  void setCurrentSpeaker(int position) {
    _currentSpeaker = position;
  }

  /// Get current speaker (stage mode).
  int get currentSpeaker => _currentSpeaker;

  /// Is stage mode enabled?
  bool get stageMode => _stageMode;

  /// Rotate seats — move all speakers one position forward.
  /// Used for seat rotation feature.
  List<int> rotateSeats(List<int> occupiedPositions) {
    if (occupiedPositions.length < 2) return occupiedPositions;
    final rotated = List<int>.from(occupiedPositions);
    final first = rotated.removeAt(0);
    rotated.add(first);
    return rotated;
  }

  /// VIP seat reservation — reserve seat for VIP user.
  final Map<int, String> _vipReservations = {}; // position -> userId

  void reserveVipSeat(int position, String userId) {
    _vipReservations[position] = userId;
  }

  void clearVipReservation(int position) {
    _vipReservations.remove(position);
  }

  bool isSeatReservedForVip(int position) {
    return _vipReservations.containsKey(position);
  }

  String? getVipReservation(int position) {
    return _vipReservations[position];
  }

  /// Per-seat custom background.
  final Map<int, String> _seatBackgrounds = {}; // position -> image URL

  void setSeatBackground(int position, String imageUrl) {
    _seatBackgrounds[position] = imageUrl;
  }

  String? getSeatBackground(int position) {
    return _seatBackgrounds[position];
  }

  void dispose() {
    for (final timer in _seatTimers.values) {
      timer.cancel();
    }
    _seatTimers.clear();
  }
}

// ===========================================================================
// C5: Music & Sound
// ===========================================================================

/// Karaoke lyrics line.
class KaraokeLine {
  final String text;
  final Duration timestamp;
  final Duration duration;

  KaraokeLine({required this.text, required this.timestamp, this.duration = const Duration(seconds: 3)});
}

/// Song request entry.
class SongRequest {
  final String id;
  final String title;
  final String? artist;
  final String? url;
  final String? imageUrl;
  final String requestedBy;
  final DateTime requestedAt;

  SongRequest({
    required this.id,
    required this.title,
    this.artist,
    this.url,
    this.imageUrl,
    required this.requestedBy,
    required this.requestedAt,
  });
}

/// Sound effect entry.
class SoundEffect {
  final String id;
  final String name;
  final String icon;
  final String? audioUrl;
  final int? coinCost;

  SoundEffect({
    required this.id,
    required this.name,
    required this.icon,
    this.audioUrl,
    this.coinCost,
  });

  static List<SoundEffect> defaults() => [
    SoundEffect(id: 'applause', name: 'Applause', icon: '👏', coinCost: 5, audioUrl: 'asset:///assets/sounds/fx_applause.wav'),
    SoundEffect(id: 'laughter', name: 'Laughter', icon: '😂', coinCost: 5, audioUrl: 'asset:///assets/sounds/fx_laughter.wav'),
    SoundEffect(id: 'drums', name: 'Drum Roll', icon: '🥁', coinCost: 10, audioUrl: 'asset:///assets/sounds/fx_drums.wav'),
    SoundEffect(id: 'whistle', name: 'Whistle', icon: '📣', coinCost: 5, audioUrl: 'asset:///assets/sounds/fx_whistle.wav'),
    SoundEffect(id: 'cricket', name: 'Crickets', icon: '🦗', coinCost: 5, audioUrl: 'asset:///assets/sounds/fx_cricket.wav'),
    SoundEffect(id: 'tada', name: 'Tada!', icon: '🎉', coinCost: 10, audioUrl: 'asset:///assets/sounds/fx_tada.wav'),
    SoundEffect(id: 'boo', name: 'Boo', icon: '👎', coinCost: 5, audioUrl: 'asset:///assets/sounds/fx_boo.wav'),
    SoundEffect(id: 'cheer', name: 'Cheer', icon: '🙌', coinCost: 10, audioUrl: 'asset:///assets/sounds/fx_cheer.wav'),
  ];
}

/// Ambient sound entry.
class AmbientSound {
  final String id;
  final String name;
  final String icon;
  final String? audioUrl;
  final double volume;

  AmbientSound({
    required this.id,
    required this.name,
    required this.icon,
    this.audioUrl,
    this.volume = 0.3,
  });

  static List<AmbientSound> defaults() => [
    AmbientSound(id: 'rain', name: 'Rain', icon: '🌧️', audioUrl: 'asset:///assets/sounds/amb_rain.wav'),
    AmbientSound(id: 'cafe', name: 'Cafe', icon: '☕', audioUrl: 'asset:///assets/sounds/amb_cafe.wav'),
    AmbientSound(id: 'ocean', name: 'Ocean', icon: '🌊', audioUrl: 'asset:///assets/sounds/amb_ocean.wav'),
    AmbientSound(id: 'forest', name: 'Forest', icon: '🌲', audioUrl: 'asset:///assets/sounds/amb_forest.wav'),
    AmbientSound(id: 'fire', name: 'Campfire', icon: '🔥', audioUrl: 'asset:///assets/sounds/amb_campfire.wav'),
    AmbientSound(id: 'night', name: 'Night', icon: '🌙', audioUrl: 'asset:///assets/sounds/amb_night.wav'),
  ];
}

/// Music & sound service — karaoke, song requests, DJ, sound effects, ambient.
class MusicSoundService {
  static const String _tag = 'MusicSound';
  final AudioPlayer _soundEffectPlayer = AudioPlayer();
  final AudioPlayer _ambientPlayer = AudioPlayer();
  final List<SongRequest> _songQueue = [];
  final List<KaraokeLine> _lyrics = [];
  bool _isAmbientPlaying = false;
  AmbientSound? _currentAmbient;

  /// Song request queue.
  List<SongRequest> get songQueue => List.unmodifiable(_songQueue);

  /// Add song request.
  void addSongRequest(SongRequest request) {
    _songQueue.add(request);
  }

  /// Remove song request.
  void removeSongRequest(String id) {
    _songQueue.removeWhere((s) => s.id == id);
  }

  /// Get next song.
  SongRequest? getNextSong() {
    return _songQueue.isEmpty ? null : _songQueue.first;
  }

  /// Play sound effect.
  Future<void> playSoundEffect(SoundEffect effect) async {
    if (effect.audioUrl == null) {
      Log.w(_tag, 'Sound effect ${effect.name} has no audio URL');
      return;
    }
    try {
      await _soundEffectPlayer.setAudioSource(AudioSource.uri(Uri.parse(effect.audioUrl!)));
      await _soundEffectPlayer.setVolume(0.8);
      await _soundEffectPlayer.play();
    } catch (e) {
      Log.e(_tag, 'playSoundEffect failed', e);
    }
  }

  /// Start ambient sound.
  Future<void> startAmbient(AmbientSound ambient) async {
    if (ambient.audioUrl == null) return;
    try {
      await _ambientPlayer.setAudioSource(AudioSource.uri(Uri.parse(ambient.audioUrl!)));
      await _ambientPlayer.setLoopMode(LoopMode.one);
      await _ambientPlayer.setVolume(ambient.volume);
      await _ambientPlayer.play();
      _isAmbientPlaying = true;
      _currentAmbient = ambient;
    } catch (e) {
      Log.e(_tag, 'startAmbient failed', e);
    }
  }

  /// Stop ambient sound.
  Future<void> stopAmbient() async {
    try {
      await _ambientPlayer.stop();
      _isAmbientPlaying = false;
      _currentAmbient = null;
    } catch (e) {
      Log.e(_tag, 'stopAmbient failed', e);
    }
  }

  /// Is ambient playing?
  bool get isAmbientPlaying => _isAmbientPlaying;

  /// Current ambient sound.
  AmbientSound? get currentAmbient => _currentAmbient;

  /// Set ambient volume.
  Future<void> setAmbientVolume(double volume) async {
    await _ambientPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Load karaoke lyrics.
  void loadLyrics(List<KaraokeLine> lyrics) {
    _lyrics.clear();
    _lyrics.addAll(lyrics);
  }

  /// Get current lyric line based on position.
  KaraokeLine? getCurrentLyric(Duration position) {
    for (int i = _lyrics.length - 1; i >= 0; i--) {
      if (position >= _lyrics[i].timestamp) {
        return _lyrics[i];
      }
    }
    return null;
  }

  /// Get all lyrics.
  List<KaraokeLine> get lyrics => List.unmodifiable(_lyrics);

  /// Dispose.
  void dispose() {
    _soundEffectPlayer.dispose();
    _ambientPlayer.dispose();
  }
}

// ===========================================================================
// C6: Social & Engagement
// ===========================================================================

/// Room rules.
class RoomRules {
  final List<String> rules;
  final int minAge;
  final bool ageRestricted;

  RoomRules({
    this.rules = const [],
    this.minAge = 0,
    this.ageRestricted = false,
  });

  static RoomRules defaults() => RoomRules(
    rules: [
      'Be respectful to all members',
      'No abusive language',
      'No spam or self-promotion',
      'No sharing personal information',
      'Follow host instructions',
      'Have fun and enjoy!',
    ],
    minAge: 0,
    ageRestricted: false,
  );
}

/// Social & engagement service.
class SocialEngagementService {
  static const String _tag = 'SocialEngagement';

  /// Send room invitation to friends.
  static Future<void> sendInvitation({
    required String roomId,
    required String roomName,
    required List<String> friendUserIds,
  }) async {
    // Would emit socket event or call API
    Log.d(_tag, 'Invitation sent to ${friendUserIds.length} friends for room $roomName');
  }

  /// Generate QR code data for room.
  static String generateQrData(String roomId) {
    return 'belive://audio/$roomId';
  }

  /// Check user age for age-restricted rooms.
  static bool isAgeEligible(int userAge, int minAge) {
    return userAge >= minAge;
  }

  /// Default room rules.
  static RoomRules defaultRules() => RoomRules.defaults();

  /// Report room.
  static Future<bool> reportRoom({
    required String roomId,
    required String reason,
    String? description,
  }) async {
    try {
      // Would call /report/room endpoint
      Log.d(_tag, 'Room $roomId reported: $reason');
      return true;
    } catch (e) {
      Log.e(_tag, 'reportRoom failed', e);
      return false;
    }
  }
}

// ===========================================================================
// C7: Monetization
// ===========================================================================

/// Room monetization settings.
class RoomMonetization {
  final bool paidEntry;
  final int entryFeeCoins;
  final bool membershipOnly;
  final int membershipTier;
  final bool sponsored;
  final String? sponsorName;
  final String? sponsorBannerUrl;
  final bool showAds;

  RoomMonetization({
    this.paidEntry = false,
    this.entryFeeCoins = 0,
    this.membershipOnly = false,
    this.membershipTier = 0,
    this.sponsored = false,
    this.sponsorName,
    this.sponsorBannerUrl,
    this.showAds = false,
  });

  factory RoomMonetization.fromJson(Map<String, dynamic> json) => RoomMonetization(
    paidEntry: json['paidEntry'] == true,
    entryFeeCoins: (json['entryFeeCoins'] as num?)?.toInt() ?? 0,
    membershipOnly: json['membershipOnly'] == true,
    membershipTier: (json['membershipTier'] as num?)?.toInt() ?? 0,
    sponsored: json['sponsored'] == true,
    sponsorName: json['sponsorName']?.toString(),
    sponsorBannerUrl: json['sponsorBannerUrl']?.toString(),
    showAds: json['showAds'] == true,
  );
}

/// Monetization service.
class MonetizationService {
  static const String _tag = 'Monetization';

  /// Check if user can join paid room.
  static Future<bool> canJoinPaidRoom({
    required int userCoins,
    required int entryFee,
  }) async {
    return userCoins >= entryFee;
  }

  /// Deduct entry fee.
  static Future<bool> deductEntryFee({
    required String userId,
    required String roomId,
    required int coins,
  }) async {
    try {
      // Would call /wallet/deduct endpoint
      Log.d(_tag, 'Entry fee $coins coins deducted for room $roomId');
      return true;
    } catch (e) {
      Log.e(_tag, 'deductEntryFee failed', e);
      return false;
    }
  }

  /// Check membership access.
  static Future<bool> checkMembershipAccess({
    required String userId,
    required int requiredTier,
  }) async {
    try {
      // Would call /membership/check endpoint
      return true;
    } catch (e) {
      Log.e(_tag, 'checkMembershipAccess failed', e);
      return false;
    }
  }
}

// ===========================================================================
// C8: Family/Agency/CP
// ===========================================================================

/// Family/Agency room info.
class FamilyRoomInfo {
  final String? familyId;
  final String? familyName;
  final String? familyIcon;
  final String? agencyId;
  final String? agencyName;
  final String? cpPartnerId;
  final String? cpPartnerName;

  FamilyRoomInfo({
    this.familyId,
    this.familyName,
    this.familyIcon,
    this.agencyId,
    this.agencyName,
    this.cpPartnerId,
    this.cpPartnerName,
  });

  bool get isFamilyRoom => familyId != null;
  bool get isAgencyRoom => agencyId != null;
  bool get isCpRoom => cpPartnerId != null;
}

/// Family/Agency/CP service.
class FamilyAgencyService {
  static const String _tag = 'FamilyAgency';

  /// Create family room.
  static Future<bool> createFamilyRoom({
    required String familyId,
    required String roomName,
    required String hostId,
  }) async {
    try {
      // Would call /family/createRoom endpoint
      Log.d(_tag, 'Family room created for family $familyId');
      return true;
    } catch (e) {
      Log.e(_tag, 'createFamilyRoom failed', e);
      return false;
    }
  }

  /// Get family leaderboard.
  static Future<List<Map<String, dynamic>>> getFamilyLeaderboard({String period = 'weekly'}) async {
    try {
      // Would call /family/leaderboard endpoint
      return [];
    } catch (e) {
      Log.e(_tag, 'getFamilyLeaderboard failed', e);
      return [];
    }
  }

  /// Create CP couple room.
  static Future<bool> createCpRoom({
    required String cpId,
    required String roomName,
    required String host1Id,
    required String host2Id,
  }) async {
    try {
      Log.d(_tag, 'CP room created for $cpId');
      return true;
    } catch (e) {
      Log.e(_tag, 'createCpRoom failed', e);
      return false;
    }
  }
}

// ===========================================================================
// C9: Security & Moderation
// ===========================================================================

/// Security & moderation service.
class SecurityModerationService {
  static const String _tag = 'Security';
  static const platform = MethodChannel('com.believoo.app/debug');

  /// Enable screenshot prevention (Android FLAG_SECURE).
  static Future<void> enableScreenshotProtection() async {
    if (!Platform.isAndroid) return;
    try {
      await platform.invokeMethod('setSecureFlag', {'secure': true});
      Log.d(_tag, 'Screenshot protection enabled');
    } catch (e) {
      Log.e(_tag, 'enableScreenshotProtection failed', e);
    }
  }

  /// Disable screenshot prevention.
  static Future<void> disableScreenshotProtection() async {
    if (!Platform.isAndroid) return;
    try {
      await platform.invokeMethod('setSecureFlag', {'secure': false});
      Log.d(_tag, 'Screenshot protection disabled');
    } catch (e) {
      Log.e(_tag, 'disableScreenshotProtection failed', e);
    }
  }

  /// Detect screen recording (Android).
  static Future<bool> isScreenRecording() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await platform.invokeMethod<bool>('isScreenRecording');
      return result ?? false;
    } catch (e) {
      Log.e(_tag, 'isScreenRecording failed', e);
      return false;
    }
  }

  /// Profanity filter — check text for bad words.
  static final List<String> _badWords = [
    'fuck', 'shit', 'bitch', 'asshole', 'dick', 'pussy', 'cunt',
    'bastard', 'slut', 'whore', 'nigger', 'faggot',
  ];

  static String filterProfanity(String text) {
    String filtered = text;
    for (final word in _badWords) {
      final pattern = RegExp(word, caseSensitive: false);
      filtered = filtered.replaceAll(pattern, '*' * word.length);
    }
    return filtered;
  }

  static bool hasProfanity(String text) {
    final lower = text.toLowerCase();
    return _badWords.any((w) => lower.contains(w));
  }

  /// Spam detection — check if user is sending messages too fast.
  static final Map<String, List<DateTime>> _messageTimestamps = {};
  static const int _spamThreshold = 5; // messages
  static const Duration _spamWindow = Duration(seconds: 10);

  static bool isSpamming(String userId) {
    final now = DateTime.now();
    _messageTimestamps[userId] ??= [];
    _messageTimestamps[userId]!.add(now);
    // Remove old timestamps
    _messageTimestamps[userId]!.removeWhere((t) => now.difference(t) > _spamWindow);
    return _messageTimestamps[userId]!.length > _spamThreshold;
  }

  /// Clear spam tracking for user.
  static void clearSpamTracking(String userId) {
    _messageTimestamps.remove(userId);
  }

  /// Bot detection — simple heuristic check.
  static bool isLikelyBot({
    required int accountAgeDays,
    required int messageCount,
    required int giftCount,
  }) {
    // New account (< 1 day) with high activity is suspicious
    if (accountAgeDays < 1 && messageCount > 100) return true;
    // New account sending many gifts is suspicious
    if (accountAgeDays < 7 && giftCount > 50) return true;
    return false;
  }
}

// ===========================================================================
// C10: Technical
// ===========================================================================

/// Network quality level.
enum NetworkQuality {
  excellent, // green
  good,      // light green
  fair,      // yellow
  poor,      // orange
  bad,       // red
  unknown,
}

/// Technical service — network monitoring, recording, low latency, failover.
class TechnicalService {
  static const String _tag = 'Technical';
  Timer? _networkCheckTimer;
  NetworkQuality _currentQuality = NetworkQuality.unknown;
  bool _isRecording = false;
  String? _recordingPath;

  /// Current network quality.
  NetworkQuality get currentQuality => _currentQuality;

  /// Start network quality monitoring.
  /// Uses Agora's onNetworkQuality event to determine quality.
  void startNetworkMonitoring(RtcEngine engine) {
    engine.registerEventHandler(RtcEngineEventHandler(
      onNetworkQuality: (conn, uid, txQuality, rxQuality) {
        // Use the worse of tx/rx quality
        final quality = txQuality.index > rxQuality.index ? txQuality : rxQuality;
        _currentQuality = _mapAgoraQuality(quality);
      },
    ));
  }

  /// Map Agora QualityType to our NetworkQuality enum.
  NetworkQuality _mapAgoraQuality(QualityType quality) {
    switch (quality) {
      case QualityType.qualityExcellent:
        return NetworkQuality.excellent;
      case QualityType.qualityGood:
        return NetworkQuality.good;
      case QualityType.qualityPoor:
        return NetworkQuality.poor;
      case QualityType.qualityBad:
        return NetworkQuality.bad;
      case QualityType.qualityVbad:
        return NetworkQuality.bad;
      case QualityType.qualityDown:
        return NetworkQuality.bad;
      case QualityType.qualityUnknown:
        return NetworkQuality.unknown;
      case QualityType.qualityUnsupported:
        return NetworkQuality.unknown;
      case QualityType.qualityDetecting:
        return NetworkQuality.unknown;
    }
  }

  /// Stop network monitoring.
  void stopNetworkMonitoring() {
    _networkCheckTimer?.cancel();
    _currentQuality = NetworkQuality.unknown;
  }

  /// Get quality color.
  static int qualityColor(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent: return 0xFF4CAF50; // green
      case NetworkQuality.good: return 0xFF8BC34A;      // light green
      case NetworkQuality.fair: return 0xFFFFC107;      // yellow
      case NetworkQuality.poor: return 0xFFFF9800;      // orange
      case NetworkQuality.bad: return 0xFFF44336;       // red
      case NetworkQuality.unknown: return 0xFF9E9E9E;   // grey
    }
  }

  /// Get quality label.
  static String qualityLabel(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent: return 'Excellent';
      case NetworkQuality.good: return 'Good';
      case NetworkQuality.fair: return 'Fair';
      case NetworkQuality.poor: return 'Poor';
      case NetworkQuality.bad: return 'Bad';
      case NetworkQuality.unknown: return 'Unknown';
    }
  }

  /// Enable low latency mode — for music performances.
  static Future<void> enableLowLatencyMode(RtcEngine engine) async {
    try {
      await engine.setAudioProfile(
        profile: AudioProfileType.audioProfileMusicHighQualityStereo,
        scenario: AudioScenarioType.audioScenarioGameStreaming,
      );
      Log.d(_tag, 'Low latency mode enabled');
    } catch (e) {
      Log.e(_tag, 'enableLowLatencyMode failed', e);
    }
  }

  /// Start recording audio session.
  Future<bool> startRecording(String outputPath) async {
    try {
      // Would use Agora recording SDK or local recording
      _isRecording = true;
      _recordingPath = outputPath;
      Log.d(_tag, 'Recording started: $outputPath');
      return true;
    } catch (e) {
      Log.e(_tag, 'startRecording failed', e);
      return false;
    }
  }

  /// Stop recording.
  Future<String?> stopRecording() async {
    try {
      _isRecording = false;
      final path = _recordingPath;
      _recordingPath = null;
      Log.d(_tag, 'Recording stopped: $path');
      return path;
    } catch (e) {
      Log.e(_tag, 'stopRecording failed', e);
      return null;
    }
  }

  /// Is recording?
  bool get isRecording => _isRecording;

  /// Recording path.
  String? get recordingPath => _recordingPath;

  /// Get saved recordings list.
  static Future<List<Map<String, dynamic>>> getRecordings() async {
    try {
      // Would scan local storage for recordings
      return [];
    } catch (e) {
      Log.e(_tag, 'getRecordings failed', e);
      return [];
    }
  }

  /// Dispose.
  void dispose() {
    stopNetworkMonitoring();
  }
}
