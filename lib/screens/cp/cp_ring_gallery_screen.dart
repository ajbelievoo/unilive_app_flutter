/// CP Ring Gallery screen — shows the collection of couple rings that can
/// be unlocked by leveling up the CP bond and equipped.
library cp_ring_gallery;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../models/cp_models.dart';
import '../../providers/cp_provider.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_ui.dart';

class CPRingGalleryScreen extends StatefulWidget {
  const CPRingGalleryScreen({super.key, required this.cpId});
  final String cpId;

  @override
  State<CPRingGalleryScreen> createState() => _CPRingGalleryScreenState();
}

class _CPRingGalleryScreenState extends State<CPRingGalleryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CpProvider>().loadRings(widget.cpId);
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CpProvider>();
    final rings = cp.rings;
    final session = context.read<SessionManager>();
    final myLevel = cp.myCP?.level ?? 1;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Ring Gallery',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            flexibleSpace: Container(
              decoration: const BoxDecoration(gradient: AppTheme.pinkGradient),
              child: const Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 20, bottom: 50),
                  child: Opacity(
                    opacity: 0.35,
                    child: Image(
                      image: AssetImage('assets/cp_friend/heart_tow.png'),
                      width: 70,
                      height: 44,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          if (rings.isEmpty)
            const SliverFillRemaining(
              child: EmptyState(
                icon: Icons.diamond_outlined,
                title: 'You don\'t have any rings yet',
                subtitle: 'Level up your CP bond to unlock beautiful couple rings!',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _RingCard(
                    ring: rings[i],
                    canEquip: myLevel >= rings[i].unlockLevel,
                    onEquip: rings[i].isUnlocked && !rings[i].isEquipped
                        ? () async {
                            final ok = await context.read<CpProvider>().equipRing(
                                  cpId: widget.cpId,
                                  ringId: rings[i].id ?? '',
                                  userId: session.userId,
                                );
                            if (ok) {
                              Fluttertoast.showToast(msg: 'Ring equipped!');
                            } else {
                              Fluttertoast.showToast(msg: 'Failed to equip');
                            }
                          }
                        : null,
                  ),
                  childCount: rings.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RingCard extends StatelessWidget {
  const _RingCard({required this.ring, required this.canEquip, this.onEquip});
  final CPRing ring;
  final bool canEquip;
  final VoidCallback? onEquip;

  @override
  Widget build(BuildContext context) {
    final locked = !ring.isUnlocked && !canEquip;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: ring.isEquipped
            ? Border.all(color: const Color(0xFFE84B8A), width: 2)
            : null,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: locked
                          ? null
                          : LinearGradient(
                              colors: AppTheme.pinkGradient.colors
                                  .map((c) => c.withValues(alpha: 0.15))
                                  .toList(),
                            ),
                      color: locked ? AppTheme.surfaceVariant : null,
                    ),
                    child: ring.image != null && ring.image!.isNotEmpty && !locked
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: ring.image!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Icon(Icons.diamond, size: 36, color: Color(0xFFE84B8A)),
                              errorWidget: (_, __, ___) => const Icon(Icons.diamond, size: 36, color: Color(0xFFE84B8A)),
                            ),
                          )
                        : Icon(
                            locked ? Icons.lock_outline : Icons.diamond,
                            size: 36,
                            color: locked ? AppTheme.textTertiary : const Color(0xFFE84B8A),
                          ),
                  ),
                ),
                if (ring.isEquipped)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: const BoxDecoration(
                        gradient: AppTheme.pinkGradient,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      child: const Text('EQUIPPED',
                          style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (locked)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Lv.${ring.unlockLevel}',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                Text(ring.name ?? 'Ring',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                if (ring.isEquipped)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: AppTheme.green),
                        SizedBox(width: 4),
                        Text('Equipped', style: TextStyle(fontSize: 11, color: AppTheme.green, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                else if (ring.isUnlocked && onEquip != null)
                  GestureDetector(
                    onTap: onEquip,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppTheme.pinkGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Equip',
                          style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  )
                else if (canEquip && !ring.isUnlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.goldGradient.colors.first.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${ring.price} diamonds',
                        style: const TextStyle(fontSize: 11, color: AppTheme.yellow, fontWeight: FontWeight.w600)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Lv.${ring.unlockLevel} to unlock',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
