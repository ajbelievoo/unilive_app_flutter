/// Audio room host features service.
///
/// Ports native host features:
/// - Earnings dashboard
/// - Host level/XP system
/// - Host achievements
/// - Daily/weekly tasks
/// - Host analytics
/// - Co-host mode
/// - Host break mode
/// - Auto-end timer
library host_features_service;

import 'dart:async';
import 'dart:math';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/json_annotation_helper.dart';
import '../services/session_manager.dart';
import '../utils/format_utils.dart';
import '../utils/log.dart';
import 'api_service.dart';

/// Host earnings data.
class HostEarnings {
  final int totalCoins;
  final int todayCoins;
  final int weekCoins;
  final int monthCoins;
  final int totalHours;
  final int totalSessions;

  HostEarnings({
    this.totalCoins = 0,
    this.todayCoins = 0,
    this.weekCoins = 0,
    this.monthCoins = 0,
    this.totalHours = 0,
    this.totalSessions = 0,
  });

  factory HostEarnings.fromJson(Map<String, dynamic> json) => HostEarnings(
    totalCoins: parseInt(json['totalCoins']),
    todayCoins: parseInt(json['todayCoins']),
    weekCoins: parseInt(json['weekCoins']),
    monthCoins: parseInt(json['monthCoins']),
    totalHours: parseInt(json['totalHours']),
    totalSessions: parseInt(json['totalSessions']),
  );
}

/// Host level/XP system.
class HostLevel {
  final int level;
  final int currentXp;
  final int nextLevelXp;
  final String title;
  final String? badgeUrl;

  HostLevel({
    this.level = 1,
    this.currentXp = 0,
    this.nextLevelXp = 1000,
    this.title = 'Rookie',
    this.badgeUrl,
  });

  double get progress =>
      nextLevelXp > 0 ? (currentXp / nextLevelXp).clamp(0.0, 1.0) : 0.0;

  factory HostLevel.fromJson(Map<String, dynamic> json) => HostLevel(
    level: parseInt(json['level']),
    currentXp: parseInt(json['currentXp'] ?? json['currentExp'] ?? json['exp']),
    nextLevelXp: parseInt(
      json['nextLevelXp'] ?? json['nextExp'] ?? json['nextLevelExp'],
    ),
    title: parseString(json['title'] ?? json['name']) ?? 'Rookie',
    badgeUrl: parseString(json['badgeUrl']),
  );
}

/// Host achievement.
class HostAchievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool unlocked;
  final int? progress;
  final int? target;

  HostAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.unlocked = false,
    this.progress,
    this.target,
  });

  factory HostAchievement.fromJson(Map<String, dynamic> json) =>
      HostAchievement(
        id: parseString(json['_id'] ?? json['id']) ?? '',
        title: parseString(json['title']) ?? '',
        description: parseString(json['description']) ?? '',
        icon: parseString(json['icon']) ?? '🏆',
        unlocked: parseBool(json['unlocked']),
        progress: parseInt(json['progress']),
        target: parseInt(json['target']),
      );
}

/// Daily/weekly host task.
class HostTask {
  final String id;
  final String title;
  final String description;
  final String rules;
  final int rewardCoins;
  final int progress;
  final int target;
  final bool completed;
  final bool claimed;
  final String type; // 'daily' | 'weekly'

  HostTask({
    required this.id,
    required this.title,
    required this.description,
    this.rules = '',
    this.rewardCoins = 0,
    this.progress = 0,
    this.target = 1,
    this.completed = false,
    this.claimed = false,
    this.type = 'daily',
  });

  factory HostTask.fromJson(Map<String, dynamic> json) => HostTask(
    id: parseString(json['_id'] ?? json['id']) ?? '',
    title: parseString(json['title']) ?? '',
    description: parseString(json['description']) ?? '',
    rules:
        parseString(json['rules'] ?? json['taskRules'] ?? json['rule']) ?? '',
    rewardCoins: parseInt(json['rewardCoins'] ?? json['coinsRewarded']),
    progress: parseInt(json['progress']),
    target: parseInt(json['target']),
    completed: parseBool(json['completed']),
    claimed: parseBool(json['claimed'] ?? json['isClaimed']),
    type:
        parseString(json['type'] ?? json['frequency'] ?? json['category']) ??
        'daily',
  );
}

/// Host analytics data point.
class HostAnalyticsPoint {
  final DateTime date;
  final int viewers;
  final int coins;
  final int watchTimeMinutes;

  HostAnalyticsPoint({
    required this.date,
    this.viewers = 0,
    this.coins = 0,
    this.watchTimeMinutes = 0,
  });

  factory HostAnalyticsPoint.fromJson(Map<String, dynamic> json) =>
      HostAnalyticsPoint(
        date:
            DateTime.tryParse(
              parseString(json['date'] ?? json['createdAt']) ?? '',
            ) ??
            DateTime.now(),
        viewers: parseInt(
          json['viewers'] ?? json['viewersCount'] ?? json['peakViewers'],
        ),
        coins: parseInt(json['coins'] ?? json['coin']),
        watchTimeMinutes: parseInt(
          json['watchTimeMinutes'] ?? json['watchMinutes'],
        ),
      );
}

/// Host features service — manages host progression, earnings, tasks.
class HostFeaturesService {
  static const String _tag = 'HostFeatures';

  /// Get host earnings from live history API.
  ///
  /// Merges audio and video live stats and the local on-device cache so the
  /// host dashboard never shows 0 while the host is actively streaming. Earnings
  /// are returned in Beans (rCoin) — the host's withdrawable currency.
  static Future<HostEarnings> getEarnings(
    String userId, {
    String liveType = 'all',
  }) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      Future<HostEarnings> fetchOne(String type) async {
        try {
          final res = await ApiService.getHostApi(
            hostId: userId,
            liveType: type,
            date: today,
          );
          final payload = res.data;
          final data =
              payload?['data'] as Map<String, dynamic>? ??
              (payload is Map<String, dynamic> ? payload : null);
          if (data == null) return HostEarnings();
          return _hostEarningsFromApiData(data);
        } catch (e) {
          Log.e(_tag, 'getEarnings $type failed', e);
          return HostEarnings();
        }
      }

      HostEarnings backend;
      if (liveType == 'audio' || liveType == 'video') {
        backend = await fetchOne(liveType);
      } else {
        final results = await Future.wait([
          fetchOne('audio'),
          fetchOne('video'),
        ]);
        final audio = results[0];
        final video = results[1];
        backend = _mergeEarnings(audio, video);
      }

      // Always merge with the local on-device cache. The cache is updated in
      // real-time while the host is live and is the only source that works when
      // the backend endpoints are missing or return 0.
      backend = await _mergeCacheIntoEarnings(userId, backend, liveType);

      // If the backend did not provide week/month data, try to compute it from
      // this month's live history. Falls back to today's cache if history empty.
      if (backend.weekCoins <= 0 && backend.monthCoins <= 0) {
        try {
          final history = await _earningsFromHistory(userId);
          backend = _mergeEarnings(backend, history);
        } catch (e) {
          Log.e(_tag, 'earnings history fill failed', e);
        }
      }

      return backend;
    } catch (e) {
      Log.e(_tag, 'getEarnings failed', e);
      // If the whole flow crashes, try the cache as a last resort.
      try {
        return await HostLiveCache.getEarnings(userId);
      } catch (_) {
        return HostEarnings();
      }
    }
  }

  /// Build [HostEarnings] from a backend `/hostLiveHistory/hostLive` response.
  ///
  /// Host earnings are in Beans (rCoin). Diamond/coin fields are converted to
  /// Beans only when no rCoin value is present.
  static HostEarnings _hostEarningsFromApiData(Map<String, dynamic> data) {
    final todayBeans = _readHostEarning(
      data,
      rCoinKeys: const ['rCoinToday', 'todayRcoin', 'todayRCoin'],
      diamondKeys: const ['todayEarning', 'coin', 'todayCoins', 'todayCoin'],
    );
    return HostEarnings(
      todayCoins: todayBeans,
      totalCoins: max(
        todayBeans,
        _readHostEarning(
          data,
          rCoinKeys: const [
            'totalRcoin',
            'totalRCoin',
            'totalRcoin',
            'rCoin',
          ],
          diamondKeys: const [
            'totalEarning',
            'totalCoins',
            'totalCoin',
            'coin',
          ],
        ),
      ),
      weekCoins: _readHostEarning(
        data,
        rCoinKeys: const ['weekRcoin', 'weekRCoin'],
        diamondKeys: const ['weekCoins', 'weekCoin'],
      ),
      monthCoins: _readHostEarning(
        data,
        rCoinKeys: const ['monthRcoin', 'monthRCoin'],
        diamondKeys: const ['monthCoins', 'monthCoin'],
      ),
      totalHours:
          _parseCoin(
            data['totalHours'] ?? data['totalHour'] ?? data['hours'],
          ) ??
          0,
      totalSessions:
          _parseCoin(
            data['totalSessions'] ??
                data['totalSession'] ??
                data['sessions'],
          ) ??
          0,
    );
  }

  /// Merge two [HostEarnings] by taking the maximum of each field. This lets the
  /// local cache, backend summary, and backend history all contribute real data.
  static HostEarnings _mergeEarnings(HostEarnings a, HostEarnings b) {
    return HostEarnings(
      todayCoins: max(a.todayCoins, b.todayCoins),
      totalCoins: max(a.totalCoins, b.totalCoins),
      weekCoins: max(a.weekCoins, b.weekCoins),
      monthCoins: max(a.monthCoins, b.monthCoins),
      totalHours: max(a.totalHours, b.totalHours),
      totalSessions: max(a.totalSessions, b.totalSessions),
    );
  }

  /// Merge local cache values into a [HostEarnings] object.
  ///
  /// Cache `todayEarning` is stored in Diamonds (gift coin value), so it is
  /// converted to Beans before comparison. Durations are stored in seconds but
  /// [HostLiveCache.getTodayProgress] returns them in minutes.
  static Future<HostEarnings> _mergeCacheIntoEarnings(
    String userId,
    HostEarnings backend,
    String liveType,
  ) async {
    try {
      final cache = await HostLiveCache.getTodayProgress(userId);
      final cacheEarning = diamondsToBeans(
        parseInt(cache['todayEarning']),
        SessionManager.instance?.getSetting(),
      );
      final cacheAudioMin = parseInt(cache['audioDuration']);
      final cacheVideoMin = parseInt(cache['videoDuration']);
      final cacheMinutes =
          liveType == 'audio'
              ? cacheAudioMin
              : liveType == 'video'
              ? cacheVideoMin
              : cacheAudioMin + cacheVideoMin;
      final cacheHours = cacheMinutes ~/ 60;
      final cacheSessions = await HostLiveCache.getTotalSessions(userId);

      return HostEarnings(
        todayCoins: max(backend.todayCoins, cacheEarning),
        totalCoins: max(backend.totalCoins, cacheEarning),
        weekCoins: max(backend.weekCoins, cacheEarning),
        monthCoins: max(backend.monthCoins, cacheEarning),
        totalHours: max(backend.totalHours, cacheHours),
        totalSessions: max(backend.totalSessions, cacheSessions),
      );
    } catch (e) {
      Log.e(_tag, 'merge cache into earnings failed', e);
      return backend;
    }
  }

  /// Compute week/month earnings from this month's live history.
  ///
  /// Sums rCoin/coin for the last 7 days and the full month. Falls back to 0
  /// if the history endpoint is unavailable.
  static Future<HostEarnings> _earningsFromHistory(String userId) async {
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    final response = await ApiService.getHostLiveHistory(
      hostId: userId,
      month: month,
    );
    final raw =
        response['data'] ??
        response['history'] ??
        response['liveHistory'] ??
        response['sessions'];
    final entries = raw is List ? raw : (raw is Map ? [raw] : const []);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int weekCoins = 0;
    int monthCoins = 0;
    int totalHours = 0;
    int totalSessions = 0;

    for (final entry in entries.whereType<Map>()) {
      final map = Map<String, dynamic>.from(entry);
      final date = DateTime.tryParse(
        parseString(
              map['date'] ??
                  map['createdAt'] ??
                  map['startTime'] ??
                  map['liveDate'],
            ) ??
            '',
      );
      if (date == null) continue;

      final daysAgo = today.difference(DateTime(date.year, date.month, date.day)).inDays;
      if (daysAgo < 0 || daysAgo > 30) {
        continue;
      }

      final coins = _readHostEarning(
        map,
        rCoinKeys: const ['rCoin', 'todayRcoin', 'totalRcoin', 'rcoin'],
        diamondKeys: const ['coin', 'coins', 'todayCoins', 'todayCoin'],
      );
      if (daysAgo <= 6) {
        weekCoins += coins;
      }
      monthCoins += coins;

      final minutes = parseInt(
        map['totalMinutes'] ??
            map['minutes'] ??
            map['duration'] ??
            map['watchTimeMinutes'] ??
            map['watchMinutes'],
      );
      if (minutes > 0) {
        totalHours += minutes ~/ 60;
        totalSessions += 1;
      }
    }

    return HostEarnings(
      todayCoins: 0,
      totalCoins: monthCoins,
      weekCoins: weekCoins,
      monthCoins: monthCoins,
      totalHours: totalHours,
      totalSessions: totalSessions,
    );
  }

  /// Read a host earning value from [data], preferring rCoin (Bean) keys and
  /// converting diamond/coin values to Beans when rCoin is not present.
  static int _readHostEarning(
    Map<String, dynamic> data, {
    required List<String> rCoinKeys,
    required List<String> diamondKeys,
  }) {
    for (final key in rCoinKeys) {
      if (data.containsKey(key) && data[key] != null) {
        return _parseCoin(data[key]) ?? 0;
      }
    }
    for (final key in diamondKeys) {
      if (data.containsKey(key) && data[key] != null) {
        final parsed = _parseCoin(data[key]) ?? 0;
        return diamondsToBeans(
          parsed,
          SessionManager.instance?.getSetting(),
        );
      }
    }
    return 0;
  }

  static int? _parseCoin(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    final s = value.toString().replaceAll(RegExp(r'[^\d.]'), '');
    return int.tryParse(s) ?? double.tryParse(s)?.toInt();
  }

  /// Get host level/XP.
  static Future<HostLevel> getLevel(String userId) async {
    try {
      final res = await ApiService.getHostProfile(userId);
      final data = res['data'] as Map<String, dynamic>? ?? res;
      final hostLevel = data['hostLevel'];

      if (hostLevel is Map<String, dynamic>) {
        return HostLevel.fromJson(hostLevel);
      }

      // Some backends send hostLevel as a raw MongoDB ObjectId string or level
      // name. Never show a long hex ID in the UI.
      if (hostLevel is String &&
          hostLevel.isNotEmpty &&
          !_looksLikeObjectId(hostLevel)) {
        return HostLevel(title: hostLevel);
      }

      final level = parseInt(data['level']);
      if (level > 0) {
        return HostLevel(
          level: level,
          title:
              parseString(data['levelName'] ?? data['hostLevelName']) ??
              'Rookie',
          currentXp: parseInt(data['exp'] ?? data['currentXp']),
          nextLevelXp: parseInt(data['nextExp'] ?? data['nextLevelXp']),
        );
      }
      return HostLevel();
    } catch (e) {
      Log.e(_tag, 'getLevel failed', e);
      return HostLevel();
    }
  }

  static bool _looksLikeObjectId(String s) {
    if (s.length != 24) return false;
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(s);
  }

  /// Get host achievements.
  static Future<List<HostAchievement>> getAchievements(String userId) async {
    try {
      // Backend achievements endpoint is not live yet; fall back to the
      // default milestone list. When /host/achievements is ready, swap to it.
      return _defaultAchievements();
    } catch (e) {
      Log.e(_tag, 'getAchievements failed', e);
      return [];
    }
  }

  /// Get host tasks (daily/weekly).
  ///
  /// The backend merges legacy `Task` documents and dashboard `HostDashboardTask`
  /// documents in `GET /task/getTask`. Only dashboard tasks (`frequency` of
  /// `daily` or `weekly`, or a present `targetType`) are shown in the Host
  /// Dashboard Tasks tab. Legacy audio/video room tasks are filtered out.
  static Future<List<HostTask>> getTasks(String userId) async {
    try {
      final res = await ApiService.getHostTasks(userId);
      final list = res['data'] as List?;
      final today = await _loadTodayProgress(userId);
      if (list != null && list.isNotEmpty) {
        final tasks =
            list
                .map((t) {
                  final map =
                      t is Map
                          ? t.cast<String, dynamic>()
                          : <String, dynamic>{};
                  return _parseDashboardTask(map, today);
                })
                .whereType<HostTask>()
                .toList();
        return tasks.isNotEmpty ? tasks : _defaultTasksWithProgress(today);
      }
      return _defaultTasksWithProgress(today);
    } catch (e) {
      Log.e(_tag, 'getTasks failed', e);
      try {
        final today = await _loadTodayProgress(userId);
        return _defaultTasksWithProgress(today);
      } catch (_) {
        return _defaultTasks();
      }
    }
  }

  /// Apply today's local progress to the default dashboard task list.
  ///
  /// Used when the backend task endpoint is empty or fails. Time-based tasks
  /// get real-time progress from the on-device cache; gift/viewer tasks keep
  /// 0 because the local cache only tracks duration and earnings.
  static List<HostTask> _defaultTasksWithProgress(Map<String, dynamic> today) {
    final completedAudioMin = parseInt(today['audioDuration']);
    final completedVideoMin = parseInt(today['videoDuration']);
    final completedTimeMin = completedAudioMin + completedVideoMin;

    return _defaultTasks().map((task) {
      int progress;
      switch (task.id) {
        case 'd1':
        case 'w1':
          progress = completedTimeMin.clamp(0, task.target);
          break;
        case 'd2':
        case 'w2':
          // Local cache doesn't track gift count, so we can't compute progress.
          progress = 0;
          break;
        default:
          progress = 0;
      }
      final completed = progress >= task.target && task.target > 0;
      return HostTask(
        id: task.id,
        title: task.title,
        description: task.description,
        rewardCoins: task.rewardCoins,
        progress: progress,
        target: task.target,
        completed: completed,
        claimed: task.claimed,
        type: task.type,
      );
    }).toList();
  }

  /// Load today's live progress from the backend. Tries the today-history
  /// endpoint first, then falls back to the per-type `hostLive` endpoint,
  /// and finally overwrites any backend 0s with the local on-device cache.
  ///
  /// Returns durations in minutes and earnings in Beans (rCoin) so the Host
  /// Dashboard task progress is always consistent.
  static Future<Map<String, dynamic>> _loadTodayProgress(String userId) async {
    Map<String, dynamic> today = {};
    try {
      final todayRes = await ApiService.getHostLiveHistoryToday(userId);
      final raw = todayRes['data'];
      List? todayData;
      if (raw is List) {
        todayData = raw;
      } else if (raw is Map) {
        todayData = [raw];
      }
      if (todayData?.isNotEmpty == true) {
        final first = todayData!.first;
        if (first is Map) {
          today = first.cast<String, dynamic>();
        }
      }
    } catch (e) {
      Log.e(_tag, 'getHostLiveHistoryToday failed, using fallback', e);
    }

    // Normalize the today-history fields so we don't compare strings to ints.
    today['audioDuration'] = parseInt(today['audioDuration']);
    today['videoDuration'] = parseInt(today['videoDuration']);
    today['totalMinutes'] = parseInt(today['totalMinutes']);
    today['todayEarning'] = _readHostEarning(
      today,
      rCoinKeys: const ['rCoin', 'todayRcoin', 'todayRCoin', 'todayEarning'],
      diamondKeys: const ['coin', 'todayCoins', 'todayCoin'],
    );

    // If today-history did not return progress fields, try hostLive per type.
    if ((today['audioDuration'] ?? 0) == 0 &&
        (today['videoDuration'] ?? 0) == 0 &&
        (today['todayEarning'] ?? 0) == 0) {
      final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      try {
        final audioRes = await ApiService.getHostApi(
          hostId: userId,
          liveType: 'audio',
          date: todayDate,
        );
        final audioData =
            audioRes.data?['data'] as Map<String, dynamic>? ??
            (audioRes.data is Map<String, dynamic>
                ? audioRes.data as Map<String, dynamic>
                : null);
        if (audioData != null) {
          final audioMinutes = parseInt(
            audioData['todayMinutes'] ??
                audioData['minutes'] ??
                audioData['audioDuration'] ??
                audioData['duration'] ??
                0,
          );
          today['audioDuration'] = max(
            today['audioDuration'] ?? 0,
            audioMinutes,
          );
          today['todayEarning'] = max(
            today['todayEarning'] ?? 0,
            _readHostEarning(
              audioData,
              rCoinKeys: const ['rCoin', 'todayRcoin', 'todayRCoin'],
              diamondKeys: const [
                'todayEarning',
                'coin',
                'todayCoins',
                'todayCoin',
              ],
            ),
          );
        }
      } catch (e) {
        Log.e(_tag, 'getHostApi audio fallback failed', e);
      }
      try {
        final videoRes = await ApiService.getHostApi(
          hostId: userId,
          liveType: 'video',
          date: todayDate,
        );
        final videoData =
            videoRes.data?['data'] as Map<String, dynamic>? ??
            (videoRes.data is Map<String, dynamic>
                ? videoRes.data as Map<String, dynamic>
                : null);
        if (videoData != null) {
          final videoMinutes = parseInt(
            videoData['todayMinutes'] ??
                videoData['minutes'] ??
                videoData['videoDuration'] ??
                videoData['duration'] ??
                0,
          );
          today['videoDuration'] = max(
            today['videoDuration'] ?? 0,
            videoMinutes,
          );
          today['todayEarning'] = max(
            today['todayEarning'] ?? 0,
            _readHostEarning(
              videoData,
              rCoinKeys: const ['rCoin', 'todayRcoin', 'todayRCoin'],
              diamondKeys: const [
                'todayEarning',
                'coin',
                'todayCoins',
                'todayCoin',
              ],
            ),
          );
        }
      } catch (e) {
        Log.e(_tag, 'getHostApi video fallback failed', e);
      }
    }

    // Last resort: use the local on-device cache for today. This is the
    // only fallback that works when backend endpoints are 404 / not implemented.
    // Overwrite backend 0s with cache values, and convert cache earnings
    // (stored as gift Diamonds) to Beans.
    if ((today['audioDuration'] ?? 0) == 0 &&
        (today['videoDuration'] ?? 0) == 0 &&
        (today['todayEarning'] ?? 0) == 0) {
      try {
        final cache = await HostLiveCache.getTodayProgress(userId);
        final cacheAudioMin = parseInt(cache['audioDuration']);
        final cacheVideoMin = parseInt(cache['videoDuration']);
        final cacheEarning = diamondsToBeans(
          parseInt(cache['todayEarning']),
          SessionManager.instance?.getSetting(),
        );
        today['audioDuration'] = max(today['audioDuration'] ?? 0, cacheAudioMin);
        today['videoDuration'] = max(today['videoDuration'] ?? 0, cacheVideoMin);
        today['todayEarning'] = max(today['todayEarning'] ?? 0, cacheEarning);
        today['totalMinutes'] = max(
          today['totalMinutes'] ?? 0,
          cacheAudioMin + cacheVideoMin,
        );
      } catch (e) {
        Log.e(_tag, 'local cache fallback failed', e);
      }
    }

    return today;
  }

  static HostTask? _parseDashboardTask(
    Map<String, dynamic> json,
    Map<String, dynamic> today,
  ) {
    final id = parseString(json['_id'] ?? json['id']) ?? '';
    final targetType = parseString(json['targetType']);
    final frequency = parseString(json['frequency'] ?? json['category']);

    // Legacy room tasks have `type: audio|video` and `timeRequired`/`coinRequired`
    // and no `frequency` or `targetType`. They are meant for the Host Center, not
    // the Host Dashboard Tasks tab, so skip them here.
    final isDashboard =
        frequency == 'daily' ||
        frequency == 'weekly' ||
        (targetType?.isNotEmpty == true &&
            const {
              'time',
              'coin',
              'viewers',
              'gifts',
              'mixed',
            }.contains(targetType));
    if (!isDashboard) return null;

    // Legacy audio/video fields (kept for backward compat fallback only).
    final legacyType = json['type']?.toString() ?? 'all';
    final timeRequired = parseInt(json['timeRequired']);
    final coinRequired = parseInt(json['coinRequired']);

    final title = parseString(json['title']) ?? '';
    final description = parseString(json['description']) ?? '';
    final rewardCoins = parseInt(json['rewardCoins'] ?? json['coinsRewarded']);
    final isClaimed = parseBool(json['claimed'] ?? json['isClaimed']);

    // Dashboard tasks count combined audio + video time and total earnings.
    final completedAudioMin = parseInt(today['audioDuration']);
    final completedVideoMin = parseInt(today['videoDuration']);
    final completedTimeMin =
        legacyType == 'audio'
            ? completedAudioMin
            : legacyType == 'video'
            ? completedVideoMin
            : completedAudioMin + completedVideoMin;
    final completedEarning = parseInt(today['todayEarning']);

    int target;
    int progress;
    final providedTarget = (json['target'] as num?)?.toInt() ?? 0;
    final providedProgress = (json['progress'] as num?)?.toInt() ?? 0;

    if (providedTarget > 0) {
      // New dashboard tasks provide pre-computed target and progress.
      target = providedTarget;
      if (providedProgress > 0) {
        progress = providedProgress;
      } else if (targetType == 'time' || timeRequired > 0) {
        progress = completedTimeMin.clamp(0, target);
      } else if (targetType == 'coin' || coinRequired > 0) {
        progress = completedEarning.clamp(0, target);
      } else if (targetType == 'viewers' || targetType == 'gifts') {
        // Viewers/gifts cannot be computed locally unless the backend provides progress.
        progress = 0;
      } else {
        progress = completedTimeMin.clamp(0, target);
      }
    } else if (timeRequired > 0) {
      target = timeRequired;
      progress = completedTimeMin.clamp(0, target);
    } else if (coinRequired > 0) {
      target = coinRequired;
      progress = completedEarning.clamp(0, target);
    } else {
      target = providedTarget > 0 ? providedTarget : 1;
      progress = 0;
    }

    final completed =
        json['completed'] == true || (progress >= target && target > 0);

    return HostTask(
      id: id,
      title:
          title.isNotEmpty
              ? title
              : _generatedTaskTitle(
                target,
                timeRequired,
                coinRequired,
                targetType ?? 'time',
                frequency ?? 'daily',
              ),
      description:
          description.isNotEmpty
              ? description
              : _generatedTaskDescription(
                target,
                timeRequired,
                coinRequired,
                targetType ?? 'time',
                frequency ?? 'daily',
              ),
      rewardCoins: rewardCoins,
      progress: progress,
      target: target,
      completed: completed,
      claimed: isClaimed,
      type: frequency == 'weekly' ? 'weekly' : 'daily',
    );
  }

  static String _generatedTaskTitle(
    int target,
    int timeRequired,
    int coinRequired,
    String targetType,
    String frequency,
  ) {
    final label = frequency == 'weekly' ? 'this week' : 'today';
    if (timeRequired > 0 || targetType == 'time') {
      final minutes = timeRequired > 0 ? timeRequired : target;
      final hours = minutes ~/ 60;
      if (hours >= 1) {
        return 'Stream $hours hour${hours > 1 ? 's' : ''} $label';
      }
      return 'Stream $minutes minutes $label';
    }
    if (coinRequired > 0 || targetType == 'coin') {
      final amount = coinRequired > 0 ? coinRequired : target;
      return 'Earn $amount Beans $label';
    }
    if (targetType == 'viewers') {
      return 'Reach $target viewers $label';
    }
    if (targetType == 'gifts') {
      return 'Get $target gifts $label';
    }
    if (targetType == 'mixed') {
      return 'Complete all targets $label';
    }
    return frequency == 'weekly' ? 'Weekly Task' : 'Daily Task';
  }

  static String _generatedTaskDescription(
    int target,
    int timeRequired,
    int coinRequired,
    String targetType,
    String frequency,
  ) {
    final label = frequency == 'weekly' ? 'this week' : 'today';
    if (timeRequired > 0 || targetType == 'time') {
      final minutes = timeRequired > 0 ? timeRequired : target;
      return 'Host for $minutes minutes $label';
    }
    if (coinRequired > 0 || targetType == 'coin') {
      final amount = coinRequired > 0 ? coinRequired : target;
      return 'Receive $amount Beans as gifts $label';
    }
    if (targetType == 'viewers') {
      return 'Have $target viewers in your room $label';
    }
    if (targetType == 'gifts') {
      return 'Receive $target gifts $label';
    }
    if (targetType == 'mixed') {
      return 'Complete the mixed daily/weekly target';
    }
    return 'Complete $label target';
  }

  /// Get host analytics (viewer count graph, watch time).
  static Future<List<HostAnalyticsPoint>> getAnalytics(
    String userId, {
    int days = 7,
  }) async {
    try {
      final safeDays = days.clamp(1, 31);
      final now = DateTime.now();
      final dates = List.generate(
        safeDays,
        (index) => DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: safeDays - index - 1)),
      );
      String dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
      final totals = <String, Map<String, int>>{
        for (final date in dates)
          dateKey(date): {'viewers': 0, 'coins': 0, 'watchTimeMinutes': 0},
      };
      final months =
          dates.map((date) => DateFormat('yyyy-MM').format(date)).toSet();
      final responses = await Future.wait(
        months.map((month) async {
          try {
            return await ApiService.getHostLiveHistory(
              hostId: userId,
              month: month,
            );
          } catch (e) {
            Log.e(_tag, 'getAnalytics $month failed', e);
            return <String, dynamic>{};
          }
        }),
      );
      for (final response in responses) {
        final raw =
            response['data'] ??
            response['history'] ??
            response['liveHistory'] ??
            response['sessions'];
        final entries = raw is List ? raw : (raw is Map ? [raw] : const []);
        for (final entry in entries.whereType<Map>()) {
          final map = Map<String, dynamic>.from(entry);
          final parsedDate = DateTime.tryParse(
            parseString(
                  map['date'] ??
                      map['createdAt'] ??
                      map['startTime'] ??
                      map['liveDate'],
                ) ??
                '',
          );
          if (parsedDate == null) continue;
          final day = totals[dateKey(parsedDate)];
          if (day == null) continue;
          final viewers = parseInt(
            map['viewers'] ??
                map['view'] ??
                map['viewerCount'] ??
                map['totalView'] ??
                map['peakViewers'],
          );
          final coins = parseInt(
            map['coins'] ??
                map['coin'] ??
                map['rCoin'] ??
                map['earning'] ??
                map['totalCoins'],
          );
          final watchMinutes = parseInt(
            map['watchTimeMinutes'] ??
                map['watchMinutes'] ??
                map['totalMinutes'] ??
                map['durationMinutes'] ??
                map['duration'],
          );
          if (viewers > day['viewers']!) day['viewers'] = viewers;
          day['coins'] = day['coins']! + coins;
          day['watchTimeMinutes'] = day['watchTimeMinutes']! + watchMinutes;
        }
      }
      final today = await HostLiveCache.getTodayProgress(userId);
      final todayTotals = totals[dateKey(now)];
      if (todayTotals != null) {
        final cachedCoins = parseInt(today['todayEarning']);
        final cachedMinutes = parseInt(today['totalMinutes']);
        if (cachedCoins > todayTotals['coins']!) {
          todayTotals['coins'] = cachedCoins;
        }
        if (cachedMinutes > todayTotals['watchTimeMinutes']!) {
          todayTotals['watchTimeMinutes'] = cachedMinutes;
        }
      }
      return dates.map((date) {
        final day = totals[dateKey(date)]!;
        return HostAnalyticsPoint(
          date: date,
          viewers: day['viewers']!,
          coins: day['coins']!,
          watchTimeMinutes: day['watchTimeMinutes']!,
        );
      }).toList();
    } catch (e) {
      Log.e(_tag, 'getAnalytics failed', e);
      return [];
    }
  }

  /// Claim task reward.
  static Future<bool> claimTaskReward({
    required String userId,
    required String taskId,
  }) async {
    try {
      final res = await ApiService.claimTaskReward(
        hostId: userId,
        taskId: taskId,
      );
      return res['status'] == true;
    } catch (e) {
      Log.e(_tag, 'claimTaskReward failed', e);
      return false;
    }
  }

  /// Default achievements list.
  static List<HostAchievement> _defaultAchievements() => [
    HostAchievement(
      id: 'first_stream',
      title: 'First Stream',
      description: 'Host your first audio room',
      icon: '🎤',
      unlocked: false,
      progress: 0,
      target: 1,
    ),
    HostAchievement(
      id: '100_viewers',
      title: 'Crowd Pleaser',
      description: 'Reach 100 viewers in one room',
      icon: '👥',
      unlocked: false,
      progress: 0,
      target: 100,
    ),
    HostAchievement(
      id: '1000_hours',
      title: 'Dedicated Host',
      description: 'Stream for 1000 total hours',
      icon: '⏰',
      unlocked: false,
      progress: 0,
      target: 1000,
    ),
    HostAchievement(
      id: '10000_coins',
      title: 'Diamond Collector',
      description: 'Earn 10,000 diamonds total',
      icon: '💰',
      unlocked: false,
      progress: 0,
      target: 10000,
    ),
    HostAchievement(
      id: '50_sessions',
      title: 'Veteran',
      description: 'Host 50 audio sessions',
      icon: '🎖️',
      unlocked: false,
      progress: 0,
      target: 50,
    ),
    HostAchievement(
      id: '7_day_streak',
      title: 'On Fire',
      description: 'Stream 7 days in a row',
      icon: '🔥',
      unlocked: false,
      progress: 0,
      target: 7,
    ),
  ];

  /// Default daily/weekly tasks.
  static List<HostTask> _defaultTasks() => [
    HostTask(
      id: 'd1',
      title: 'Stream 1 hour',
      description: 'Host for 1 hour today',
      rewardCoins: 50,
      progress: 0,
      target: 60,
      type: 'daily',
    ),
    HostTask(
      id: 'd2',
      title: 'Get 10 gifts',
      description: 'Receive 10 gifts today',
      rewardCoins: 100,
      progress: 0,
      target: 10,
      type: 'daily',
    ),
    HostTask(
      id: 'd3',
      title: 'Reach 20 viewers',
      description: 'Have 20 viewers in your room',
      rewardCoins: 75,
      progress: 0,
      target: 20,
      type: 'daily',
    ),
    HostTask(
      id: 'w1',
      title: 'Stream 10 hours this week',
      description: 'Host for 10 hours this week',
      rewardCoins: 500,
      progress: 0,
      target: 600,
      type: 'weekly',
    ),
    HostTask(
      id: 'w2',
      title: 'Get 100 gifts this week',
      description: 'Receive 100 gifts this week',
      rewardCoins: 1000,
      progress: 0,
      target: 100,
      type: 'weekly',
    ),
  ];
}

/// Local cache for a host's daily live progress.
///
/// Used as a graceful fallback when the backend's `hostLiveHistory` endpoints
/// are missing, empty, or not yet updated (e.g. the `updateLiveTime` endpoint
/// currently returns 404). The cache is keyed by `userId` and date, and it is
/// updated in real-time while the host is live.
class HostLiveCache {
  static const String _tag = 'HostLiveCache';

  static String _dateKey(String userId) => 'host_cache_date_$userId';
  static String _audioDurationKey(String userId) =>
      'host_audio_duration_$userId';
  static String _videoDurationKey(String userId) =>
      'host_video_duration_$userId';
  static String _todayEarningKey(String userId) => 'host_today_earning_$userId';
  static String _todayMinutesKey(String userId) => 'host_today_minutes_$userId';
  static String _totalSessionsKey(String userId) => 'host_total_sessions_$userId';

  /// In-memory guard so each app session only increments the session counter
  /// once per user. The counter is persisted across app restarts.
  static final _recordedSession = <String>{};

  static Future<void> _ensureDate(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final saved = prefs.getString(_dateKey(userId));
    if (saved != today) {
      await prefs.setString(_dateKey(userId), today);
      await prefs.setInt(_audioDurationKey(userId), 0);
      await prefs.setInt(_videoDurationKey(userId), 0);
      await prefs.setInt(_todayEarningKey(userId), 0);
      await prefs.setInt(_todayMinutesKey(userId), 0);
    }
  }

  /// Record a live duration delta for [liveType] (`audio` or `video`).
  static Future<void> addDuration({
    required String userId,
    required String liveType,
    required int seconds,
  }) async {
    if (seconds <= 0) return;
    await _ensureDate(userId);
    final prefs = await SharedPreferences.getInstance();

    // Count this as one streaming session for the current app session. The
    // persisted counter is only incremented once per app session.
    if (!_recordedSession.contains(userId)) {
      _recordedSession.add(userId);
      final sessions = prefs.getInt(_totalSessionsKey(userId)) ?? 0;
      await prefs.setInt(_totalSessionsKey(userId), sessions + 1);
    }

    final key =
        liveType == 'audio'
            ? _audioDurationKey(userId)
            : _videoDurationKey(userId);
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + seconds);
    // Keep a combined minutes counter for the Host Center "Today Live" card.
    final audio = prefs.getInt(_audioDurationKey(userId)) ?? 0;
    final video = prefs.getInt(_videoDurationKey(userId)) ?? 0;
    await prefs.setInt(_todayMinutesKey(userId), (audio + video) ~/ 60);
  }

  /// Record coins earned by the host today.
  static Future<void> addEarnings({
    required String userId,
    required int coins,
  }) async {
    if (coins <= 0) return;
    await _ensureDate(userId);
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_todayEarningKey(userId)) ?? 0;
    await prefs.setInt(_todayEarningKey(userId), current + coins);
  }

  /// Get today's cached progress as a map compatible with `getHostLiveHistoryToday`.
  ///
  /// Duration fields are returned in **minutes** because the Host Center / Task
  /// UI compares them to `timeRequired` in minutes.
  static Future<Map<String, dynamic>> getTodayProgress(String userId) async {
    await _ensureDate(userId);
    final prefs = await SharedPreferences.getInstance();
    final audioSec = prefs.getInt(_audioDurationKey(userId)) ?? 0;
    final videoSec = prefs.getInt(_videoDurationKey(userId)) ?? 0;
    final earning = prefs.getInt(_todayEarningKey(userId)) ?? 0;
    final audioMin = audioSec ~/ 60;
    final videoMin = videoSec ~/ 60;
    final totalMin = audioMin + videoMin;
    return {
      'audioDuration': audioMin,
      'videoDuration': videoMin,
      'todayEarning': earning,
      'totalMinutes': totalMin,
      'coin': earning,
      'rCoin': earning,
    };
  }

  /// Get total live sessions recorded locally for this user.
  static Future<int> getTotalSessions(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalSessionsKey(userId)) ?? 0;
  }

  /// Clear the in-memory session guard so the next stream in the same app
  /// session is counted as a new session.
  static void clearSessionRecorded(String userId) {
    _recordedSession.remove(userId);
  }

  /// Get today's cached earnings in the [HostEarnings] shape.
  ///
  /// Cache `todayEarning` is stored in gift Diamonds; convert to Beans before
  /// returning so the dashboard matches the host's withdrawable balance.
  static Future<HostEarnings> getEarnings(String userId) async {
    try {
      final today = await getTodayProgress(userId);
      final rawEarning = parseInt(today['todayEarning']);
      final todayCoins = diamondsToBeans(
        rawEarning,
        SessionManager.instance?.getSetting(),
      );
      final totalMinutes = parseInt(today['totalMinutes']);
      final totalSessions = await getTotalSessions(userId);
      return HostEarnings(
        todayCoins: todayCoins,
        totalCoins: todayCoins,
        weekCoins: 0,
        monthCoins: 0,
        totalHours: totalMinutes ~/ 60,
        totalSessions: totalSessions,
      );
    } catch (e) {
      Log.e(_tag, 'getEarnings failed', e);
      return HostEarnings();
    }
  }
}

/// Host session manager — manages break mode, auto-end timer, co-host.
class HostSessionManager {
  Timer? _autoEndTimer;
  Timer? _breakTimer;
  bool _isOnBreak = false;
  DateTime? _breakStartedAt;
  int _autoEndMinutes = 0;

  /// Start auto-end timer — room will end after X minutes.
  void startAutoEnd(int minutes, VoidCallback onEnd) {
    _autoEndMinutes = minutes;
    _autoEndTimer?.cancel();
    _autoEndTimer = Timer(Duration(minutes: minutes), onEnd);
  }

  /// Cancel auto-end timer.
  void cancelAutoEnd() {
    _autoEndTimer?.cancel();
    _autoEndMinutes = 0;
  }

  /// Get remaining auto-end time in minutes.
  int get autoEndRemaining => _autoEndMinutes;

  /// Start host break — room goes to break mode.
  void startBreak() {
    _isOnBreak = true;
    _breakStartedAt = DateTime.now();
  }

  /// End host break.
  void endBreak() {
    _isOnBreak = false;
    _breakStartedAt = null;
  }

  /// Is host on break?
  bool get isOnBreak => _isOnBreak;

  /// Break duration in seconds.
  int get breakDurationSeconds {
    if (_breakStartedAt == null) return 0;
    return DateTime.now().difference(_breakStartedAt!).inSeconds;
  }

  /// Dispose all timers.
  void dispose() {
    _autoEndTimer?.cancel();
    _breakTimer?.cancel();
  }
}

typedef VoidCallback = void Function();
