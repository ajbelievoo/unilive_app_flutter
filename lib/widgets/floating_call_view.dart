/// Floating call view â€” WhatsApp-style incoming call banner.
///
/// Ports native `FloatingCallView.java`. Shows a minimized banner that can be
/// expanded to a full-screen call UI with accept/reject actions.
library floating_call_view;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Callbacks for floating call actions.
typedef OnCallAction = void Function();

/// Floating call overlay widget. Mount as an overlay above the current screen.
class FloatingCallView extends StatefulWidget {
  const FloatingCallView({
    super.key,
    required this.callerName,
    required this.callerImage,
    required this.isAudio,
    required this.onAccept,
    required this.onReject,
  });

  final String callerName;
  final String callerImage;
  final bool isAudio;
  final OnCallAction onAccept;
  final OnCallAction onReject;

  @override
  State<FloatingCallView> createState() => _FloatingCallViewState();
}

class _FloatingCallViewState extends State<FloatingCallView> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    if (_expanded) return _expandedView(context);
    return _minimizedView(context);
  }

  Widget _minimizedView(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: _toggle,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: AppTheme.purpleGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: widget.callerImage,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.white.withValues(alpha: 0.2),
                      child: const Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.callerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        'Incoming ${widget.isAudio ? 'audio' : 'video'} call...',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.white, size: 20),
                  onPressed: widget.onAccept,
                  style: IconButton.styleFrom(backgroundColor: Colors.green),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.call_end, color: Colors.white, size: 20),
                  onPressed: widget.onReject,
                  style: IconButton.styleFrom(backgroundColor: Colors.red),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _expandedView(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                onPressed: _toggle,
              ),
            ),
            const Spacer(),
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: widget.callerImage,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: AppTheme.surfaceLight,
                  child: const Icon(Icons.person, color: Colors.white, size: 60),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.callerName,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Incoming ${widget.isAudio ? 'audio' : 'video'} call',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.call, color: Colors.white, size: 32),
                      onPressed: widget.onAccept,
                      style: IconButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(18)),
                    ),
                    const SizedBox(height: 8),
                    const Text('Accept', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.call_end, color: Colors.white, size: 32),
                      onPressed: widget.onReject,
                      style: IconButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.all(18)),
                    ),
                    const SizedBox(height: 8),
                    const Text('Reject', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

