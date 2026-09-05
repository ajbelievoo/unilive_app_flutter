/// Network quality indicator widget — shows signal strength bars.
///
/// Ports native network quality indicator from audio room top bar.
library network_quality_indicator;
import 'package:flutter/material.dart';

import '../../services/audio_room_advanced_service.dart';

class NetworkQualityIndicator extends StatefulWidget {
  final TechnicalService service;
  final double size;

  const NetworkQualityIndicator({
    super.key,
    required this.service,
    this.size = 16,
  });

  @override
  State<NetworkQualityIndicator> createState() => _NetworkQualityIndicatorState();
}

class _NetworkQualityIndicatorState extends State<NetworkQualityIndicator> {
  NetworkQuality _quality = NetworkQuality.unknown;

  @override
  void initState() {
    super.initState();
    // Poll quality every 2 seconds
    _updateQuality();
  }

  void _updateQuality() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _quality = widget.service.currentQuality);
      _updateQuality();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(TechnicalService.qualityColor(_quality));
    final bars = _qualityBars(_quality);

    return Tooltip(
      message: TechnicalService.qualityLabel(_quality),
      child: SizedBox(
        width: widget.size * 1.5,
        height: widget.size,
        child: CustomPaint(
          painter: _SignalBarsPainter(
            bars: bars,
            color: color,
            size: widget.size,
          ),
        ),
      ),
    );
  }

  int _qualityBars(NetworkQuality q) {
    switch (q) {
      case NetworkQuality.excellent: return 4;
      case NetworkQuality.good: return 3;
      case NetworkQuality.fair: return 2;
      case NetworkQuality.poor: return 1;
      case NetworkQuality.bad: return 0;
      case NetworkQuality.unknown: return 0;
    }
  }
}

class _SignalBarsPainter extends CustomPainter {
  final int bars;
  final Color color;
  final double size;

  _SignalBarsPainter({required this.bars, required this.color, required this.size});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final inactivePaint = Paint()..color = color.withValues(alpha: 0.3);
    final barWidth = this.size * 0.2;
    final gap = this.size * 0.1;
    const startX = 0.0;

    for (int i = 0; i < 4; i++) {
      final barHeight = this.size * (0.25 + i * 0.25);
      final x = startX + i * (barWidth + gap);
      final y = this.size - barHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          Radius.circular(barWidth / 2),
        ),
        i < bars ? paint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SignalBarsPainter oldDelegate) =>
      bars != oldDelegate.bars || color != oldDelegate.color;
}
