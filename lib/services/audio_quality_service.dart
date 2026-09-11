/// Audio quality settings service for audio rooms.
///
/// Ports native Agora audio configuration from `WatchAudioLiveActivity.java`:
/// - Echo cancellation
/// - Noise suppression (deep learning AI)
/// - Auto gain control (AGC)
/// - Audio bitrate/scenario selection
/// - In-ear monitoring
/// - Bluetooth routing
///
/// Also manages:
/// - Wake lock (screen stays on during audio room)
/// - Audio session (pause music on phone call)
library audio_quality_service;
import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../utils/log.dart';

class AudioQualityService {
  static const String _tag = 'AudioQuality';
  static const String _prefKey = 'audio_quality_settings';

  /// Audio scenario presets — match Agora's AudioScenarioType.
  /// Different scenarios optimize for different use cases.
  static const Map<String, AudioScenarioType> scenarios = {
    'Default': AudioScenarioType.audioScenarioDefault,
    'Chatroom': AudioScenarioType.audioScenarioChatroom,
    'GameStreaming': AudioScenarioType.audioScenarioGameStreaming,
    'Chorus': AudioScenarioType.audioScenarioChorus,
    'Meeting': AudioScenarioType.audioScenarioMeeting,
  };

  /// Apply audio quality settings to the Agora engine.
  static Future<void> applySettings(RtcEngine engine, AudioQualitySettings settings) async {
    try {
      // Set audio profile (sample rate, bitrate, stereo)
      await engine.setAudioProfile(
        profile: settings.audioProfile,
        scenario: settings.scenario,
      );

      // Echo cancellation
      await engine.setParameters('{"che.audio.enable_aec": ${settings.echoCancellation}}');

      // Noise suppression
      await engine.setParameters('{"che.audio.enable_ns": ${settings.noiseSuppression}}');
      if (settings.deepLearningAI) {
        await engine.setParameters('{"che.audio.ains_mode": true}');
      }

      // Auto gain control
      await engine.setParameters('{"che.audio.enable_agc": ${settings.autoGainControl}}');

      // In-ear monitoring (for host to hear their own voice)
      if (settings.inEarMonitoring) {
        await engine.setParameters('{"che.audio.enable_in_ear_monitoring": true}');
        await engine.setInEarMonitoringVolume(settings.inEarMonitoringVolume);
      } else {
        await engine.setParameters('{"che.audio.enable_in_ear_monitoring": false}');
      }

      // Bluetooth audio routing
      await engine.setParameters('{"che.audio.enable_bluetooth": ${settings.bluetoothRouting}}');

      Log.d(_tag, 'Audio quality settings applied: ${settings.toJson()}');
    } catch (e) {
      Log.e(_tag, 'Failed to apply audio settings', e);
    }
  }

  /// Enable wake lock — screen stays on during audio room.
  static Future<void> enableWakeLock() async {
    try {
      await WakelockPlus.enable();
      Log.d(_tag, 'Wake lock enabled');
    } catch (e) {
      Log.e(_tag, 'Failed to enable wake lock', e);
    }
  }

  /// Disable wake lock — when leaving audio room.
  static Future<void> disableWakeLock() async {
    try {
      await WakelockPlus.disable();
      Log.d(_tag, 'Wake lock disabled');
    } catch (e) {
      Log.e(_tag, 'Failed to disable wake lock', e);
    }
  }

  /// Start foreground service — keeps audio/video running in background.
  /// Pass [title]/[text] to customize the notification (e.g. "Live Stream").
  static Future<void> startForegroundService({
    String? title,
    String? text,
  }) async {
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'live_foreground',
          channelName: 'Live Stream',
          channelDescription: 'Live stream is running in background',
          priority: NotificationPriority.LOW,
          channelImportance: NotificationChannelImportance.LOW,
          visibility: NotificationVisibility.VISIBILITY_PUBLIC,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          allowWakeLock: true,
          allowWifiLock: true,
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
        ),
      );
      await FlutterForegroundTask.startService(
        notificationTitle: title ?? 'Live Stream',
        notificationText: text ?? 'Live stream is active in background',
      );
      Log.d(_tag, 'Foreground service started: ${title ?? 'Live Stream'}');
    } catch (e) {
      Log.e(_tag, 'Failed to start foreground service', e);
    }
  }

  /// Stop foreground service.
  static Future<void> stopForegroundService() async {
    try {
      FlutterForegroundTask.stopService();
      Log.d(_tag, 'Foreground service stopped');
    } catch (e) {
      Log.e(_tag, 'Failed to stop foreground service', e);
    }
  }

  /// Save settings to shared preferences as JSON.
  static Future<void> saveSettings(AudioQualitySettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(settings.toJson()));
    } catch (e) {
      Log.e(_tag, 'Failed to save settings', e);
    }
  }

  /// Load settings from shared preferences.
  static Future<AudioQualitySettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return AudioQualitySettings.defaults();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AudioQualitySettings.fromJson(map);
    } catch (e) {
      Log.e(_tag, 'Failed to load settings', e);
      return AudioQualitySettings.defaults();
    }
  }
}

/// Audio quality settings — user-configurable audio processing options.
class AudioQualitySettings {
  final AudioProfileType audioProfile;
  final AudioScenarioType scenario;
  final bool echoCancellation;
  final bool noiseSuppression;
  final bool deepLearningAI;
  final bool autoGainControl;
  final bool inEarMonitoring;
  final int inEarMonitoringVolume; // 0-100
  final bool bluetoothRouting;

  const AudioQualitySettings({
    this.audioProfile = AudioProfileType.audioProfileDefault,
    this.scenario = AudioScenarioType.audioScenarioChatroom,
    this.echoCancellation = true,
    this.noiseSuppression = true,
    this.deepLearningAI = false,
    this.autoGainControl = true,
    this.inEarMonitoring = false,
    this.inEarMonitoringVolume = 50,
    this.bluetoothRouting = true,
  });

  factory AudioQualitySettings.defaults() => const AudioQualitySettings(
    audioProfile: AudioProfileType.audioProfileMusicHighQuality,
    scenario: AudioScenarioType.audioScenarioChatroom,
    echoCancellation: true,
    noiseSuppression: true,
    deepLearningAI: true,
    autoGainControl: true,
    inEarMonitoring: false,
    inEarMonitoringVolume: 50,
    bluetoothRouting: true,
  );

  factory AudioQualitySettings.fromJson(Map<String, dynamic> json) {
    AudioProfileType parseAudioProfile(String? value) {
      return AudioProfileType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => AudioProfileType.audioProfileMusicHighQuality,
      );
    }

    AudioScenarioType parseScenario(String? value) {
      return AudioScenarioType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => AudioScenarioType.audioScenarioChatroom,
      );
    }

    return AudioQualitySettings(
      audioProfile: parseAudioProfile(json['audioProfile']?.toString()),
      scenario: parseScenario(json['scenario']?.toString()),
      echoCancellation: json['echoCancellation'] == true,
      noiseSuppression: json['noiseSuppression'] == true,
      deepLearningAI: json['deepLearningAI'] == true,
      autoGainControl: json['autoGainControl'] == true,
      inEarMonitoring: json['inEarMonitoring'] == true,
      inEarMonitoringVolume: (json['inEarMonitoringVolume'] as num?)?.toInt() ?? 50,
      bluetoothRouting: json['bluetoothRouting'] != false,
    );
  }

  AudioQualitySettings copyWith({
    AudioProfileType? audioProfile,
    AudioScenarioType? scenario,
    bool? echoCancellation,
    bool? noiseSuppression,
    bool? deepLearningAI,
    bool? autoGainControl,
    bool? inEarMonitoring,
    int? inEarMonitoringVolume,
    bool? bluetoothRouting,
  }) =>
      AudioQualitySettings(
        audioProfile: audioProfile ?? this.audioProfile,
        scenario: scenario ?? this.scenario,
        echoCancellation: echoCancellation ?? this.echoCancellation,
        noiseSuppression: noiseSuppression ?? this.noiseSuppression,
        deepLearningAI: deepLearningAI ?? this.deepLearningAI,
        autoGainControl: autoGainControl ?? this.autoGainControl,
        inEarMonitoring: inEarMonitoring ?? this.inEarMonitoring,
        inEarMonitoringVolume: inEarMonitoringVolume ?? this.inEarMonitoringVolume,
        bluetoothRouting: bluetoothRouting ?? this.bluetoothRouting,
      );

  Map<String, dynamic> toJson() => {
    'audioProfile': audioProfile.name,
    'scenario': scenario.name,
    'echoCancellation': echoCancellation,
    'noiseSuppression': noiseSuppression,
    'deepLearningAI': deepLearningAI,
    'autoGainControl': autoGainControl,
    'inEarMonitoring': inEarMonitoring,
    'inEarMonitoringVolume': inEarMonitoringVolume,
    'bluetoothRouting': bluetoothRouting,
  };
}
