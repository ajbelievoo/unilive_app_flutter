/// User effect / broadcast visibility settings.
///
/// Mirrors the native `Effect Settings` screen and controls which in-room
/// animations/broadcasts are shown to the user. Settings are persisted in
/// SharedPreferences.
library effect_settings_service;

import 'package:shared_preferences/shared_preferences.dart';

class EffectSettings {
  EffectSettings({
    this.showEnterRoomMessage = true,
    this.showEnterRoomEffect = true,
    this.showGiftEffect = true,
    this.showVehicleEffect = true,
    this.showGiftBroadcast = true,
    this.showGameBroadcast = true,
    this.showFighterBroadcast = true,
    this.showPkBroadcast = true,
    this.showLuckyBagBroadcast = true,
  });

  final bool showEnterRoomMessage;
  final bool showEnterRoomEffect;
  final bool showGiftEffect;
  final bool showVehicleEffect;
  final bool showGiftBroadcast;
  final bool showGameBroadcast;
  final bool showFighterBroadcast;
  final bool showPkBroadcast;
  final bool showLuckyBagBroadcast;

  EffectSettings copyWith({
    bool? showEnterRoomMessage,
    bool? showEnterRoomEffect,
    bool? showGiftEffect,
    bool? showVehicleEffect,
    bool? showGiftBroadcast,
    bool? showGameBroadcast,
    bool? showFighterBroadcast,
    bool? showPkBroadcast,
    bool? showLuckyBagBroadcast,
  }) =>
      EffectSettings(
        showEnterRoomMessage: showEnterRoomMessage ?? this.showEnterRoomMessage,
        showEnterRoomEffect: showEnterRoomEffect ?? this.showEnterRoomEffect,
        showGiftEffect: showGiftEffect ?? this.showGiftEffect,
        showVehicleEffect: showVehicleEffect ?? this.showVehicleEffect,
        showGiftBroadcast: showGiftBroadcast ?? this.showGiftBroadcast,
        showGameBroadcast: showGameBroadcast ?? this.showGameBroadcast,
        showFighterBroadcast: showFighterBroadcast ?? this.showFighterBroadcast,
        showPkBroadcast: showPkBroadcast ?? this.showPkBroadcast,
        showLuckyBagBroadcast: showLuckyBagBroadcast ?? this.showLuckyBagBroadcast,
      );

  Map<String, dynamic> toJson() => {
        'showEnterRoomMessage': showEnterRoomMessage,
        'showEnterRoomEffect': showEnterRoomEffect,
        'showGiftEffect': showGiftEffect,
        'showVehicleEffect': showVehicleEffect,
        'showGiftBroadcast': showGiftBroadcast,
        'showGameBroadcast': showGameBroadcast,
        'showFighterBroadcast': showFighterBroadcast,
        'showPkBroadcast': showPkBroadcast,
        'showLuckyBagBroadcast': showLuckyBagBroadcast,
      };

  factory EffectSettings.fromJson(Map<String, dynamic> json) => EffectSettings(
        showEnterRoomMessage: json['showEnterRoomMessage'] is bool ? json['showEnterRoomMessage'] as bool : true,
        showEnterRoomEffect: json['showEnterRoomEffect'] is bool ? json['showEnterRoomEffect'] as bool : true,
        showGiftEffect: json['showGiftEffect'] is bool ? json['showGiftEffect'] as bool : true,
        showVehicleEffect: json['showVehicleEffect'] is bool ? json['showVehicleEffect'] as bool : true,
        showGiftBroadcast: json['showGiftBroadcast'] is bool ? json['showGiftBroadcast'] as bool : true,
        showGameBroadcast: json['showGameBroadcast'] is bool ? json['showGameBroadcast'] as bool : true,
        showFighterBroadcast: json['showFighterBroadcast'] is bool ? json['showFighterBroadcast'] as bool : true,
        showPkBroadcast: json['showPkBroadcast'] is bool ? json['showPkBroadcast'] as bool : true,
        showLuckyBagBroadcast: json['showLuckyBagBroadcast'] is bool ? json['showLuckyBagBroadcast'] as bool : true,
      );
}

/// Service to load and persist effect settings.
class EffectSettingsService {
  static const String _key = 'effect_settings_v1';

  EffectSettingsService._();
  static final EffectSettingsService instance = EffectSettingsService._();

  EffectSettings _settings = EffectSettings();
  EffectSettings get settings => _settings;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      _settings = EffectSettings();
      return;
    }
    try {
      _settings = EffectSettings.fromJson({'showEnterRoomMessage': true}); // basic parsing fallback
      // Shared prefs only supports flat keys, so store each toggle separately.
    } catch (_) {
      _settings = EffectSettings();
    }
  }

  Future<EffectSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return EffectSettings(
      showEnterRoomMessage: prefs.getBool('${_key}_showEnterRoomMessage') ?? true,
      showEnterRoomEffect: prefs.getBool('${_key}_showEnterRoomEffect') ?? true,
      showGiftEffect: prefs.getBool('${_key}_showGiftEffect') ?? true,
      showVehicleEffect: prefs.getBool('${_key}_showVehicleEffect') ?? true,
      showGiftBroadcast: prefs.getBool('${_key}_showGiftBroadcast') ?? true,
      showGameBroadcast: prefs.getBool('${_key}_showGameBroadcast') ?? true,
      showFighterBroadcast: prefs.getBool('${_key}_showFighterBroadcast') ?? true,
      showPkBroadcast: prefs.getBool('${_key}_showPkBroadcast') ?? true,
      showLuckyBagBroadcast: prefs.getBool('${_key}_showLuckyBagBroadcast') ?? true,
    );
  }

  Future<void> saveSettings(EffectSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    _settings = s;
    await prefs.setBool('${_key}_showEnterRoomMessage', s.showEnterRoomMessage);
    await prefs.setBool('${_key}_showEnterRoomEffect', s.showEnterRoomEffect);
    await prefs.setBool('${_key}_showGiftEffect', s.showGiftEffect);
    await prefs.setBool('${_key}_showVehicleEffect', s.showVehicleEffect);
    await prefs.setBool('${_key}_showGiftBroadcast', s.showGiftBroadcast);
    await prefs.setBool('${_key}_showGameBroadcast', s.showGameBroadcast);
    await prefs.setBool('${_key}_showFighterBroadcast', s.showFighterBroadcast);
    await prefs.setBool('${_key}_showPkBroadcast', s.showPkBroadcast);
    await prefs.setBool('${_key}_showLuckyBagBroadcast', s.showLuckyBagBroadcast);
  }
}
