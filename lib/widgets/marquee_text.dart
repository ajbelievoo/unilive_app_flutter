import 'package:flutter/material.dart';

/// Marquee text widget — scrolls text horizontally in a loop.
///
/// Ported from native `UniUtils.marqueeText` used for host name in audio room.
/// When text fits within available width, no scrolling occurs.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double velocity; // pixels per second
  final Axis direction;
  final double blankSpace;
  final int pauseDurationMs;
  final bool startAfterMargin;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.velocity = 40,
    this.direction = Axis.horizontal,
    this.blankSpace = 60,
    this.pauseDurationMs = 1000,
    this.startAfterMargin = false,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> with SingleTickerProviderStateMixin {
  late ScrollController _controller;
  double _textWidth = 0;
  double _containerWidth = 0;
  bool _needsScroll = false;
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _measured = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
    }
  }

  void _measureAndStart() {
    if (!mounted) return;
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
    )..layout();
    _textWidth = tp.width;
    _containerWidth = context.size?.width ?? 0;
    _needsScroll = _textWidth > _containerWidth;
    _measured = true;
    if (_needsScroll) _startScrolling();
    if (mounted) setState(() {});
  }

  void _startScrolling() async {
    while (mounted && _needsScroll) {
      await Future.delayed(Duration(milliseconds: widget.pauseDurationMs));
      if (!mounted || !_needsScroll) break;
      final maxExtent = _controller.position.maxScrollExtent;
      if (maxExtent <= 0) break;
      await _controller.animateTo(
        maxExtent,
        duration: Duration(milliseconds: (maxExtent / widget.velocity * 1000).round()),
        curve: Curves.linear,
      );
      if (!mounted) break;
      await Future.delayed(Duration(milliseconds: widget.pauseDurationMs));
      if (!mounted) break;
      await _controller.animateTo(
        0,
        duration: Duration(milliseconds: (maxExtent / widget.velocity * 1000).round()),
        curve: Curves.linear,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_measured || !_needsScroll) {
      return Text(widget.text, style: widget.style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(children: [
        Text(widget.text, style: widget.style, maxLines: 1),
        SizedBox(width: widget.blankSpace),
      ]),
    );
  }
}
