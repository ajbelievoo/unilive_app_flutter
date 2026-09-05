import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/format_utils.dart';

class FamilyBattleOverlay extends StatelessWidget {
  const FamilyBattleOverlay({
    super.key,
    required this.family1Name,
    required this.family2Name,
    required this.family1Image,
    required this.family2Image,
    required this.score1,
    required this.score2,
    required this.remainingSeconds,
  });

  final String family1Name;
  final String family2Name;
  final String? family1Image;
  final String? family2Image;
  final int score1;
  final int score2;
  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final total = score1 + score2;
    final ratio = total > 0 ? (score1 / total).clamp(0.1, 0.9) : 0.5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFamilyInfo(family1Name, family1Image, true),
              _buildTimer(),
              _buildFamilyInfo(family2Name, family2Image, false),
            ],
          ),
          const SizedBox(height: 8),
          _buildProgressBar(ratio),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatCount(score1), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
              Text(formatCount(score2), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyInfo(String name, String? image, bool left) {
    return Row(
      children: [
        if (!left) const SizedBox(width: 8),
        if (left) _avatar(image),
        const SizedBox(width: 6),
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        if (!left) _avatar(image),
        if (left) const SizedBox(width: 8),
      ],
    );
  }

  Widget _avatar(String? url) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
      clipBehavior: Clip.hardEdge,
      child: url != null ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.shield, size: 16, color: Colors.white)) : const Icon(Icons.shield, size: 16, color: Colors.white),
    );
  }

  Widget _buildTimer() {
    final min = remainingSeconds ~/ 60;
    final sec = remainingSeconds % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10)),
      child: Text(
        '$min:${sec.toString().padLeft(2, '0')}',
        style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildProgressBar(double ratio) {
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
        ),
        FractionallySizedBox(
          widthFactor: ratio,
          child: Container(
            height: 12,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue, Colors.lightBlueAccent]),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(6), bottomLeft: Radius.circular(6)),
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Text('VS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
