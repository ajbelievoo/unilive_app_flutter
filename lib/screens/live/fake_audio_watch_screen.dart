import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class FakeAudioWatchScreen extends StatelessWidget {
  const FakeAudioWatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.themed(context, 0xFF000000, 0xFFFAFAFE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Demo Audio Room', style: TextStyle(color: AppTheme.fg(context))),
        iconTheme: IconThemeData(color: AppTheme.fg(context)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.purple.shade400, Colors.blue.shade400]),
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'Demo Audio Room',
              style: TextStyle(color: AppTheme.fg(context), fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'For testing only',
              style: TextStyle(color: AppTheme.fg(context, 0.54), fontSize: 14),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _AnimatedBar(delay: i * 200),
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedBar extends StatefulWidget {
  const _AnimatedBar({required this.delay});
  final int delay;

  @override
  State<_AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<_AnimatedBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Container(
        width: 6,
        height: 20 + (_ctrl.value * 40),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
