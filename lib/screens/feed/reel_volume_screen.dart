import 'package:flutter/material.dart';

class ReelVolumeScreen extends StatefulWidget {
  const ReelVolumeScreen({super.key, required this.videoPath, this.initialVolume = 1.0, this.initialMusicVolume = 0.5});

  final String videoPath;
  final double initialVolume;
  final double initialMusicVolume;

  @override
  State<ReelVolumeScreen> createState() => _ReelVolumeScreenState();
}

class _ReelVolumeScreenState extends State<ReelVolumeScreen> {
  late double _videoVolume;
  late double _musicVolume;

  @override
  void initState() {
    super.initState();
    _videoVolume = widget.initialVolume;
    _musicVolume = widget.initialMusicVolume;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Volume', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, {'video': _videoVolume, 'music': _musicVolume}),
            child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            _volumeSlider(
              icon: Icons.videocam,
              label: 'Original Video',
              value: _videoVolume,
              onChanged: (v) => setState(() => _videoVolume = v),
            ),
            const SizedBox(height: 32),
            _volumeSlider(
              icon: Icons.music_note,
              label: 'Background Music',
              value: _musicVolume,
              onChanged: (v) => setState(() => _musicVolume = v),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _volumeSlider({required IconData icon, required String label, required double value, required ValueChanged<double> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ]),
        Slider(
          value: value,
          min: 0,
          max: 1,
          divisions: 10,
          activeColor: Colors.purple,
          inactiveColor: Colors.white24,
          onChanged: onChanged,
        ),
        Text('${(value * 100).round()}%', style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }
}
