import 'package:flutter/material.dart';
import 'package:svgaplayer_3/svgaplayer_flutter.dart';

/// Mic wave animation rendered below a seat avatar when the seat is speaking.
/// Loads `master_wave.svga` from assets once and toggles playback with [active].
class MicWaveWidget extends StatefulWidget {
  const MicWaveWidget({
    super.key,
    this.active = true,
    this.width = 44,
    this.height = 16,
    this.asset = 'assets/mic_wave/master_wave.svga',
  });

  final bool active;
  final double width;
  final double height;
  final String asset;

  @override
  State<MicWaveWidget> createState() => _MicWaveWidgetState();
}

class _MicWaveWidgetState extends State<MicWaveWidget>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  MovieEntity? _movie;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAsset();
  }

  Future<void> _loadAsset() async {
    try {
      final movie = await SVGAParser.shared.decodeFromAssets(widget.asset);
      if (!mounted) return;
      _controller ??= SVGAAnimationController(vsync: this);
      _controller!.videoItem = movie;
      _movie = movie;
      if (mounted) {
        setState(() => _loaded = true);
        _syncAnimation();
      }
    } catch (_) {
      // Asset missing or corrupt — silently ignore, widget renders nothing.
    }
  }

  void _syncAnimation() {
    final c = _controller;
    if (c == null || _movie == null) return;
    if (widget.active) {
      c.repeat();
    } else {
      c.stop();
    }
  }

  @override
  void didUpdateWidget(covariant MicWaveWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _controller == null || _movie == null) {
      if (widget.active) {
        return _buildFallbackWave();
      }
      return SizedBox(width: widget.width, height: widget.height);
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: SVGAImage(_controller!, fit: BoxFit.contain),
    );
  }

  Widget _buildFallbackWave() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) => _buildBar(index)),
      ),
    );
  }

  Widget _buildBar(int index) {
    return Container(
      width: 3,
      height: widget.height * 0.6,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF),
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

/// Circular pulse animation for audio room seats.
class SeatPulseWave extends StatefulWidget {
  const SeatPulseWave({super.key, this.size = 72, this.color = const Color(0xFF00E5FF)});
  final double size;
  final Color color;

  @override
  State<SeatPulseWave> createState() => _SeatPulseWaveState();
}

class _SeatPulseWaveState extends State<SeatPulseWave> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            _buildPulse(1.0, 0.0),
            _buildPulse(0.66, 0.33),
            _buildPulse(0.33, 0.66),
          ],
        );
      },
    );
  }

  Widget _buildPulse(double startScale, double delay) {
    final progress = (_controller.value + delay) % 1.0;
    final opacity = 1.0 - progress;
    final scale = startScale + (progress * 0.4);

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: widget.color, width: 2),
          ),
        ),
      ),
    );
  }
}
