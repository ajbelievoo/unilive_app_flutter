import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/pk_call_models.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart' show formatCountFull;

/// Top-of-screen incoming call overlay banner (Bigo/Chamet style).
///
/// Shows a white pill-shaped card at the top of the app instead of a
/// full-screen takeover. Contains caller/random-call info and red/green
/// circular action buttons using custom asset icons.
class IncomingCallBanner extends StatelessWidget {
  const IncomingCallBanner({
    super.key,
    required this.callData,
    required this.onAccept,
    required this.onDecline,
    required this.onDismiss,
  });

  final IncomingCallData callData;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onDismiss;

  static const String _cancelIcon = 'assets/icon/invite_reject.webp';

  @override
  Widget build(BuildContext context) {
    final isAudio = callData.isAudioCall;
    final isRandom = callData.isRandomCall;
    final rate = callData.callRate;

    final title = isRandom
        ? 'Random Call'
        : (callData.user2Name?.isNotEmpty == true
            ? callData.user2Name!
            : (isAudio ? 'Audio Call' : 'Video Call'));
    final subtitle = rate > 0
        ? 'Earn ${formatCountFull(rate)}/min'
        : (isAudio ? 'Incoming audio call...' : 'Incoming video call...');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Dismissible(
          key: const ValueKey('incoming_call_banner'),
          direction: DismissDirection.up,
          onDismissed: (_) => onDismiss(),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(28),
            color: Colors.white,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(50),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Left: random-call icon or caller avatar.
                  if (isRandom)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF7B61FF), Color(0xFF4F8DFD)],
                        ),
                      ),
                      child: const Icon(Icons.public, color: Colors.white, size: 26),
                    )
                  else
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF7B61FF), Color(0xFF4F8DFD)],
                        ),
                      ),
                      child: _buildCallerAvatar(),
                    ),
                  const SizedBox(width: 12),
                  // Middle: title + subtitle.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.diamond,
                              size: 12,
                              color: AppTheme.yellow,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Right: decline and accept action buttons.
                  _ActionButton(
                    image: _cancelIcon,
                    bg: const Color(0xFFFF5252),
                    onTap: onDecline,
                  ),
                  const SizedBox(width: 10),
                  _ActionButton(
                    image: isAudio
                        ? 'assets/icon/invite_voice.webp'
                        : 'assets/icon/invite_video.webp',
                    bg: const Color(0xFF4CAF50),
                    onTap: onAccept,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallerAvatar() {
    final image = callData.user2Image ?? '';
    if (image.isEmpty) {
      return const Icon(Icons.person, color: Colors.white, size: 26);
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: image,
        fit: BoxFit.cover,
        width: 50,
        height: 50,
        placeholder: (_, __) => const Icon(Icons.person, color: Colors.white, size: 26),
        errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 26),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.image,
    required this.bg,
    required this.onTap,
  });

  final String image;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: bg.withAlpha(90),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            image,
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              image?.contains('reject') == true ? Icons.call_end : Icons.call,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
