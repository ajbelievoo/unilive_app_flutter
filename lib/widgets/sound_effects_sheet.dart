/// Sound effects & ambient sounds bottom sheet for audio rooms.
///
/// Wires the `MusicSoundService` (C5 advanced features) to the UI.
/// - Sound effects: one-shot clips (applause, laughter, drums, etc.)
///   that cost a few diamonds each.
/// - Ambient sounds: looping background ambience (rain, cafe, ocean, etc.)
library sound_effects_sheet;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../services/audio_room_advanced_service.dart';
import '../services/session_manager.dart';
import '../services/socket_service.dart';

/// Shows the sound effects & ambient sounds bottom sheet.
void showSoundEffectsSheet(
  BuildContext context, {
  required MusicSoundService service,
  String? liveStreamingId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SoundEffectsSheet(service: service, liveStreamingId: liveStreamingId),
  );
}

class _SoundEffectsSheet extends StatefulWidget {
  const _SoundEffectsSheet({required this.service, this.liveStreamingId});
  final MusicSoundService service;
  /// When set, played sound effects are broadcast to the whole room via
  /// the `roomSoundEffect` socket event so everyone hears them.
  final String? liveStreamingId;

  @override
  State<_SoundEffectsSheet> createState() => _SoundEffectsSheetState();
}

class _SoundEffectsSheetState extends State<_SoundEffectsSheet> {
  final _effects = SoundEffect.defaults();
  final _ambients = AmbientSound.defaults();
  AmbientSound? _activeAmbient;

  @override
  void initState() {
    super.initState();
    _activeAmbient = widget.service.currentAmbient;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Sound Effects & Ambience',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            // Sound effects section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sound Effects',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _effects.map((effect) {
                  return GestureDetector(
                    onTap: () async {
                      final session = context.read<SessionManager>();
                      await widget.service.playSoundEffect(effect);
                      // Broadcast to the room so all viewers hear the effect.
                      final roomId = widget.liveStreamingId;
                      if (roomId != null && roomId.isNotEmpty) {
                        SocketService.instance.emit('roomSoundEffect', {
                          'liveStreamingId': roomId,
                          'effectId': effect.id,
                          'userId': session.userId,
                          'name': session.userName,
                        });
                      }
                      Fluttertoast.showToast(
                        msg: '${effect.icon} ${effect.name}',
                        toastLength: Toast.LENGTH_SHORT,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7E3FF2).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF7E3FF2).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(effect.icon, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(
                            effect.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          if (effect.coinCost != null && effect.coinCost! > 0)
                            Text(
                              '${effect.coinCost} 💎',
                              style: TextStyle(
                                color: Colors.amber.withValues(alpha: 0.8),
                                fontSize: 9,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            // Ambient sounds section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ambient Sounds',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _ambients.map((ambient) {
                  final isActive = _activeAmbient?.id == ambient.id;
                  return GestureDetector(
                    onTap: () async {
                      if (isActive) {
                        await widget.service.stopAmbient();
                        setState(() => _activeAmbient = null);
                        Fluttertoast.showToast(msg: 'Ambient stopped');
                      } else {
                        await widget.service.startAmbient(ambient);
                        setState(() => _activeAmbient = ambient);
                        Fluttertoast.showToast(
                          msg: '${ambient.icon} ${ambient.name}',
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF00E5FF)
                              : Colors.white24,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(ambient.icon, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(
                            ambient.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            isActive ? 'On' : 'Off',
                            style: TextStyle(
                              color: isActive
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white54,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            if (_activeAmbient != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Volume',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 1,
                        value: _activeAmbient!.volume,
                        activeColor: const Color(0xFF00E5FF),
                        onChanged: (v) {
                          widget.service.setAmbientVolume(v);
                          setState(() => _activeAmbient = AmbientSound(
                            id: _activeAmbient!.id,
                            name: _activeAmbient!.name,
                            icon: _activeAmbient!.icon,
                            audioUrl: _activeAmbient!.audioUrl,
                            volume: v,
                          ));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
