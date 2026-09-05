/// Beauty options bottom sheet â€” Agora beauty / filter settings.
///
/// Ports native `BeautyOptionsSheet` â€” provides sliders for smoothness,
/// lightening, and redness, plus a "reset" button.
library beauty_options;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../utils/log.dart';

/// Shows the beauty options bottom sheet.
class BeautyOptionsSheet extends StatefulWidget {
  const BeautyOptionsSheet({
    super.key,
    required this.engine,
    this.initialSmoothness = 0.0,
    this.initialLightening = 0.0,
    this.initialRedness = 0.0,
    this.initialLighteningContrast = LighteningContrastLevel.lighteningContrastNormal,
    this.onBeautyActiveChanged,
  });

  final RtcEngine engine;
  final double initialSmoothness;
  final double initialLightening;
  final double initialRedness;
  final LighteningContrastLevel initialLighteningContrast;
  /// Notifies the caller whenever beauty mode is toggled on/off. The host
  /// presence guard uses this to pause compliance checks while a face
  /// filter / beauty effect is active (Bigo Live style exemption).
  final ValueChanged<bool>? onBeautyActiveChanged;

  @override
  State<BeautyOptionsSheet> createState() => _BeautyOptionsSheetState();
}

class _BeautyOptionsSheetState extends State<BeautyOptionsSheet> {
  late double _smoothness;
  late double _lightening;
  late double _redness;
  late LighteningContrastLevel _lighteningContrast;

  @override
  void initState() {
    super.initState();
    _smoothness = widget.initialSmoothness;
    _lightening = widget.initialLightening;
    _redness = widget.initialRedness;
    _lighteningContrast = widget.initialLighteningContrast;
  }

  void _applyBeauty() {
    try {
      widget.engine.setBeautyEffectOptions(
        enabled: true,
        options: BeautyOptions(
          lighteningContrastLevel: _lighteningContrast,
          lighteningLevel: _lightening,
          smoothnessLevel: _smoothness,
          rednessLevel: _redness,
          sharpnessLevel: 0,
        ),
      );
      widget.onBeautyActiveChanged?.call(_smoothness > 0 ||
          _lightening > 0 || _redness > 0);
    } catch (e) {
      Log.e('BeautySheet', 'applyBeauty failed', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding > 0 ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('Beauty Options',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Lightening Contrast', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _contrastChip('Low', LighteningContrastLevel.lighteningContrastLow),
                  const SizedBox(width: 8),
                  _contrastChip('Normal', LighteningContrastLevel.lighteningContrastNormal),
                  const SizedBox(width: 8),
                  _contrastChip('High', LighteningContrastLevel.lighteningContrastHigh),
                ],
              ),
              const SizedBox(height: 16),
              _sliderRow('Smoothness', _smoothness, (v) {
                setState(() => _smoothness = v);
                _applyBeauty();
              }),
              _sliderRow('Lightening', _lightening, (v) {
                setState(() => _lightening = v);
                _applyBeauty();
              }),
              _sliderRow('Redness', _redness, (v) {
                setState(() => _redness = v);
                _applyBeauty();
              }),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _smoothness = 0;
                        _lightening = 0;
                        _redness = 0;
                        _lighteningContrast = LighteningContrastLevel.lighteningContrastNormal;
                      });
                      try {
                        widget.engine.setBeautyEffectOptions(enabled: false, options: const BeautyOptions());
                      } catch (e) {
                        Log.e('BeautySheet', 'reset failed', e);
                      }
                      widget.onBeautyActiveChanged?.call(false);
                    },
                    child: const Text('Reset', style: TextStyle(color: Colors.white70, fontSize: 15)),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7E3FF2),
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contrastChip(String label, LighteningContrastLevel value) {
    final selected = _lighteningContrast == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _lighteningContrast = value);
          _applyBeauty();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? const LinearGradient(colors: [Color(0xFF7E3FF2), Color(0xFF00E5FF)]) : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sliderRow(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Slider(
            value: value,
            min: 0,
            max: 1,
            divisions: 10,
            thumbColor: Colors.purple,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

