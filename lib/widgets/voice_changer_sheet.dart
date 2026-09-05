/// Voice changer preset picker bottom sheet.
///
/// Shows the available voice changer presets from [kVoiceChangerPresets]
/// and applies the selected one via [AgoraExtensionsService].
/// Gated by the AI feature `ai_realtime_voice_changer` — when the feature
/// is disabled/locked, the sheet shows a lock message instead.
library;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_feature_model.dart';
import '../providers/ai_feature_manager.dart';
import '../services/agora_extensions_service.dart';

/// Show the voice changer preset picker.
///
/// [engine] — the active Agora [RtcEngine] for the current room.
void showVoiceChangerSheet(BuildContext context, RtcEngine engine) {
  final ai = context.read<AIFeatureManager>();
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _VoiceChangerSheet(engine: engine, ai: ai),
  );
}

class _VoiceChangerSheet extends StatefulWidget {
  const _VoiceChangerSheet({required this.engine, required this.ai});
  final RtcEngine engine;
  final AIFeatureManager ai;

  @override
  State<_VoiceChangerSheet> createState() => _VoiceChangerSheetState();
}

class _VoiceChangerSheetState extends State<_VoiceChangerSheet> {
  String _selectedKey = 'off';

  @override
  void initState() {
    super.initState();
    // Read last-used preset from prefs if available.
    _selectedKey = widget.ai.voiceChangerPreset ?? 'off';
  }

  Future<void> _apply(VoiceChangerPreset preset) async {
    setState(() => _selectedKey = preset.key);
    await AgoraExtensionsService.instance.applyVoiceChangerPreset(
      widget.engine,
      preset,
      widget.ai,
    );
    widget.ai.setVoiceChangerPreset(preset.key);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Feature gate check — if disabled, show lock message.
    if (!widget.ai.isAvailableForCurrentUser(AIFeatureKeys.voiceChanger)) {
      final msg = widget.ai.lockedMessageFor(AIFeatureKeys.voiceChanger);
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Colors.amber, size: 48),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.graphic_eq, color: Colors.cyan, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Voice Changer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'AI Real-Time Voice Tuner',
            style: TextStyle(color: Colors.cyan, fontSize: 12),
          ),
          const SizedBox(height: 16),
          // Preset grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: kVoiceChangerPresets.length,
            itemBuilder: (ctx, i) {
              final p = kVoiceChangerPresets[i];
              final selected = p.key == _selectedKey;
              final isAi = p.key.startsWith('ai_');
              return GestureDetector(
                onTap: () => _apply(p),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? (isAi ? Colors.cyan.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.3))
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: selected
                        ? Border.all(color: isAi ? Colors.cyan : Colors.amber, width: 2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isAi ? Icons.auto_awesome : Icons.graphic_eq,
                        color: selected ? (isAi ? Colors.cyan : Colors.amber) : Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 10,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
