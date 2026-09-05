/// Audio quality settings bottom sheet.
///
/// Lets users configure echo cancellation, noise suppression, AGC,
/// in-ear monitoring, Bluetooth routing, and audio scenario.
library audio_quality_sheet;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../services/audio_quality_service.dart';
import '../theme/app_theme.dart';

void showAudioQualitySheet(
  BuildContext context, {
  required AudioQualitySettings settings,
  required ValueChanged<AudioQualitySettings> onSaved,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AudioQualitySheet(
      settings: settings,
      onSaved: onSaved,
    ),
  );
}

class _AudioQualitySheet extends StatefulWidget {
  const _AudioQualitySheet({required this.settings, required this.onSaved});
  final AudioQualitySettings settings;
  final ValueChanged<AudioQualitySettings> onSaved;

  @override
  State<_AudioQualitySheet> createState() => _AudioQualitySheetState();
}

class _AudioQualitySheetState extends State<_AudioQualitySheet> {
  late AudioQualitySettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 16),
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
        const Text('Audio Quality Settings',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Audio Profile
              _buildSectionTitle('Audio Profile'),
              _buildDropdown<AudioProfileType>(
                value: _settings.audioProfile,
                items: const [
                  DropdownMenuItem(value: AudioProfileType.audioProfileDefault, child: Text('Default')),
                  DropdownMenuItem(value: AudioProfileType.audioProfileSpeechStandard, child: Text('Speech Standard')),
                  DropdownMenuItem(value: AudioProfileType.audioProfileMusicStandard, child: Text('Music Standard')),
                  DropdownMenuItem(value: AudioProfileType.audioProfileMusicStandardStereo, child: Text('Music Stereo')),
                  DropdownMenuItem(value: AudioProfileType.audioProfileMusicHighQuality, child: Text('Music High Quality')),
                  DropdownMenuItem(value: AudioProfileType.audioProfileMusicHighQualityStereo, child: Text('Music HQ Stereo')),
                ],
                onChanged: (v) => setState(() => _settings = _settings.copyWith(audioProfile: v)),
              ),
              const SizedBox(height: 12),

              // Audio Scenario
              _buildSectionTitle('Audio Scenario'),
              _buildDropdown<AudioScenarioType>(
                value: _settings.scenario,
                items: AudioQualityService.scenarios.entries.map((e) =>
                  DropdownMenuItem(value: e.value, child: Text(e.key))).toList(),
                onChanged: (v) => setState(() => _settings = _settings.copyWith(scenario: v)),
              ),
              const SizedBox(height: 16),

              // Toggles
              _buildToggle('Echo Cancellation', _settings.echoCancellation,
                (v) => setState(() => _settings = _settings.copyWith(echoCancellation: v))),
              _buildToggle('Noise Suppression', _settings.noiseSuppression,
                (v) => setState(() => _settings = _settings.copyWith(noiseSuppression: v))),
              _buildToggle('Deep Learning AI Noise Filter', _settings.deepLearningAI,
                (v) => setState(() => _settings = _settings.copyWith(deepLearningAI: v))),
              _buildToggle('Auto Gain Control', _settings.autoGainControl,
                (v) => setState(() => _settings = _settings.copyWith(autoGainControl: v))),
              _buildToggle('Bluetooth Audio Routing', _settings.bluetoothRouting,
                (v) => setState(() => _settings = _settings.copyWith(bluetoothRouting: v))),
              _buildToggle('In-Ear Monitoring', _settings.inEarMonitoring,
                (v) => setState(() => _settings = _settings.copyWith(inEarMonitoring: v))),

              // In-ear monitoring volume slider
              if (_settings.inEarMonitoring) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.volume_up, color: Colors.white54, size: 18),
                  Expanded(
                    child: Slider(
                      value: _settings.inEarMonitoringVolume.toDouble(),
                      min: 0, max: 100,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => setState(() =>
                        _settings = _settings.copyWith(inEarMonitoringVolume: v.round())),
                    ),
                  ),
                  Text('${_settings.inEarMonitoringVolume}%',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              ],
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    widget.onSaved(_settings);
                    AudioQualityService.saveSettings(_settings);
                    Fluttertoast.showToast(msg: 'Audio settings saved');
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: const Text('Save Settings'),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        dropdownColor: const Color(0xFF1A1A2E),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        underline: const SizedBox.shrink(),
        isExpanded: true,
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primary,
      contentPadding: EdgeInsets.zero,
    );
  }
}
