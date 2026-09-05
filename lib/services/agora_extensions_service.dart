/// Agora AI extensions service — wraps the native Agora RTC extensions for
/// the **AI Real-time Voice Changer** (`ai_realtime_voice_changer`) and
/// **3D Spatial Audio** (`ai_3d_spatial_audio`) features.
///
/// Both extensions are gated by the Master AI Control Engine. The caller
/// MUST check [AIFeatureManager.isFeatureEnabled] (or use the convenience
/// methods on this service which take the [AIFeatureManager] instance)
/// before calling any initialisation method, so that when the admin turns
/// a feature off the underlying native extension is never loaded — keeping
/// cloud / SDK costs at zero.
///
/// The service uses the public `agora_rtc_engine` Dart API:
///  * Voice changer  → `RtcEngine.setVoiceBeautifierPreset`,
///                      `setVoiceConversionPreset`, `setVoiceAITuner`
///  * 3D spatial     → `RtcEngine.enableSpatialAudio` +
///                      `getLocalSpatialAudioEngine().updateSelfPosition`
///                      / `updateRemotePosition`
library;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../models/ai_feature_model.dart';
import '../providers/ai_feature_manager.dart';
import '../utils/log.dart';

/// Preset bundle for the voice changer feature exposed to the UI.
class VoiceChangerPreset {
  const VoiceChangerPreset({
    required this.key,
    required this.label,
    required this.apply,
  });

  /// Stable key persisted to prefs.
  final String key;
  final String label;
  final Future<void> Function(RtcEngine engine) apply;
}

/// Preset list for the voice changer feature.
///
/// Combines the modern `VoiceAiTunerType` (real-time AI voice changer) with
/// the legacy `VoiceConversionPreset` and `VoiceBeautifierPreset` so the
/// host can pick from a single list. The "Off" entry resets every chain.
final List<VoiceChangerPreset> kVoiceChangerPresets = [
  VoiceChangerPreset(
    key: 'off',
    label: 'Off',
    apply: (e) async {
      await e.setVoiceBeautifierPreset(VoiceBeautifierPreset.voiceBeautifierOff);
      await e.setVoiceConversionPreset(VoiceConversionPreset.voiceConversionOff);
    },
  ),
  // ---- AI Real-time Voice Tuner (the headline extension) ----
  VoiceChangerPreset(
    key: 'ai_mature_male',
    label: 'Mature Male (AI)',
    apply: (e) => e.enableVoiceAITuner(enabled: true, type: VoiceAiTunerType.voiceAiTunerMatureMale),
  ),
  VoiceChangerPreset(
    key: 'ai_fresh_male',
    label: 'Fresh Male (AI)',
    apply: (e) => e.enableVoiceAITuner(enabled: true, type: VoiceAiTunerType.voiceAiTunerFreshMale),
  ),
  VoiceChangerPreset(
    key: 'ai_elegant_female',
    label: 'Elegant Female (AI)',
    apply: (e) => e.enableVoiceAITuner(enabled: true, type: VoiceAiTunerType.voiceAiTunerElegantFemale),
  ),
  VoiceChangerPreset(
    key: 'ai_sweet_female',
    label: 'Sweet Female (AI)',
    apply: (e) => e.enableVoiceAITuner(enabled: true, type: VoiceAiTunerType.voiceAiTunerSweetFemale),
  ),
  VoiceChangerPreset(
    key: 'ai_warm_male_sing',
    label: 'Warm Male Singing (AI)',
    apply: (e) => e.enableVoiceAITuner(enabled: true, type: VoiceAiTunerType.voiceAiTunerWarmMaleSinging),
  ),
  VoiceChangerPreset(
    key: 'ai_gentle_female_sing',
    label: 'Gentle Female Singing (AI)',
    apply: (e) => e.enableVoiceAITuner(enabled: true, type: VoiceAiTunerType.voiceAiTunerGentleFemaleSinging),
  ),
  // ---- Legacy voice conversion (still useful, no extra extension needed) ----
  VoiceChangerPreset(
    key: 'vc_sweet',
    label: 'Sweet',
    apply: (e) => e.setVoiceConversionPreset(VoiceConversionPreset.voiceChangerSweet),
  ),
  VoiceChangerPreset(
    key: 'vc_solid',
    label: 'Solid',
    apply: (e) => e.setVoiceConversionPreset(VoiceConversionPreset.voiceChangerSolid),
  ),
  VoiceChangerPreset(
    key: 'vc_bass',
    label: 'Bass',
    apply: (e) => e.setVoiceConversionPreset(VoiceConversionPreset.voiceChangerBass),
  ),
  VoiceChangerPreset(
    key: 'vc_cartoon',
    label: 'Cartoon',
    apply: (e) => e.setVoiceConversionPreset(VoiceConversionPreset.voiceChangerCartoon),
  ),
];

/// Service that initialises / drives the two Agora AI extensions used by
/// Belive, gated by the Master AI Control Engine.
class AgoraExtensionsService {
  AgoraExtensionsService._();
  static final AgoraExtensionsService instance = AgoraExtensionsService._();

  static const String _tag = 'AgoraExt';

  LocalSpatialAudioEngine? _spatial;
  bool _spatialInitialised = false;
  bool _voiceChangerActive = false;

  /// True when the voice changer extension may be used (feature enabled
  /// AND accessible for the current user).
  bool voiceChangerAvailable(AIFeatureManager ai) =>
      ai.isAvailableForCurrentUser(AIFeatureKeys.voiceChanger);

  /// Apply a voice changer preset.
  ///
  /// Does nothing (and emits a warning) when the feature is disabled, so
  /// callers can wire this directly to a UI tap without an extra guard.
  Future<void> applyVoiceChangerPreset(
    RtcEngine engine,
    VoiceChangerPreset preset,
    AIFeatureManager ai,
  ) async {
    if (!voiceChangerAvailable(ai)) {
      Log.w(_tag, 'voice changer disabled by AI config — ignoring apply');
      return;
    }
    try {
      await preset.apply(engine);
      _voiceChangerActive = preset.key != 'off';
      Log.d(_tag, 'voice changer preset applied: ${preset.key}');
    } catch (e, s) {
      Log.e(_tag, 'applyVoiceChangerPreset failed', e, s);
    }
  }

  /// Disable the voice changer (e.g. when leaving the room).
  Future<void> disableVoiceChanger(RtcEngine engine, AIFeatureManager ai) async {
    if (!_voiceChangerActive) return;
    try {
      await engine.setVoiceBeautifierPreset(VoiceBeautifierPreset.voiceBeautifierOff);
      await engine.setVoiceConversionPreset(VoiceConversionPreset.voiceConversionOff);
    } catch (_) {}
    _voiceChangerActive = false;
  }

  // ---- 3D Spatial Audio ------------------------------------------------

  /// True when the 3D spatial audio extension may be used.
  bool spatialAudioAvailable(AIFeatureManager ai) =>
      ai.isAvailableForCurrentUser(AIFeatureKeys.spatialAudio);

  /// Initialise the 3D spatial audio engine for the given [RtcEngine].
  ///
  /// Safe to call multiple times — only the first call does the work.
  /// Returns `false` (and does nothing) when the feature is disabled.
  Future<bool> enableSpatialAudio(
    RtcEngine engine,
    AIFeatureManager ai,
  ) async {
    if (!spatialAudioAvailable(ai)) {
      Log.w(_tag, '3D spatial audio disabled by AI config — skipping init');
      return false;
    }
    if (_spatialInitialised) return true;
    try {
      await engine.enableSpatialAudio(true);
      _spatial = engine.getLocalSpatialAudioEngine();
      await _spatial?.initialize();
      _spatialInitialised = true;
      Log.d(_tag, '3D spatial audio initialised');
      return true;
    } catch (e, s) {
      Log.e(_tag, 'enableSpatialAudio failed', e, s);
      return false;
    }
  }

  /// Update the local listener's position in the 3D audio space.
  ///
  /// Coordinates are in the Agora Cartesian space (units = meters). Each
  /// axis list must have exactly 3 elements.
  Future<void> updateSelfPosition({
    required List<double> position,
    required List<double> axisForward,
    required List<double> axisRight,
    required List<double> axisUp,
  }) async {
    if (!_spatialInitialised || _spatial == null) return;
    try {
      await _spatial!.updateSelfPosition(
        position: position,
        axisForward: axisForward,
        axisRight: axisRight,
        axisUp: axisUp,
      );
    } catch (e, s) {
      Log.e(_tag, 'updateSelfPosition failed', e, s);
    }
  }

  /// Place a remote user at a fixed point in the 3D audio space.
  Future<void> setRemoteUserPosition(int uid, double x, double y, double z) async {
    if (!_spatialInitialised || _spatial == null) return;
    try {
      await _spatial!.updateRemotePosition(
        uid: uid,
        posInfo: RemoteVoicePositionInfo(
          position: [x, y, z],
          forward: [0, 0, 1],
        ),
      );
    } catch (e, s) {
      Log.e(_tag, 'setRemoteUserPosition failed', e, s);
    }
  }

  /// Tear down everything tied to this engine. Call on room leave.
  Future<void> dispose(RtcEngine engine, AIFeatureManager ai) async {
    await disableVoiceChanger(engine, ai);
    if (_spatialInitialised) {
      try {
        await _spatial?.clearRemotePositions();
        await engine.enableSpatialAudio(false);
      } catch (_) {}
      _spatialInitialised = false;
      _spatial = null;
    }
  }
}
