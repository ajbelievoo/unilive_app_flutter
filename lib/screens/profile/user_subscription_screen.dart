import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../constants/const.dart';
import '../../models/subscription_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../utils/media_utils.dart';
import '../../widgets/user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'UserSubscription';

/// Full-screen subscription page for a host.
///
/// Pass [hostUserId], [hostName], and optional [hostImage] via route extra.
class UserSubscriptionScreen extends StatefulWidget {
  final String hostUserId;
  final String hostName;
  final String? hostImage;

  const UserSubscriptionScreen({
    super.key,
    required this.hostUserId,
    required this.hostName,
    this.hostImage,
  });

  @override
  State<UserSubscriptionScreen> createState() => _UserSubscriptionScreenState();
}

class _UserSubscriptionScreenState extends State<UserSubscriptionScreen> {
  bool _isLoading = true;
  bool _isSubscribed = false;
  List<SubscriptionTier> _tiers = [];
  UserSubscription? _activeSubscription;
  List<String> _exclusiveImages = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final session = context.read<SessionManager>();
    if (session.userId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final checkRes = await ApiService.checkSubscription(
        userId: session.userId,
        hostUserId: widget.hostUserId,
      );
      _isSubscribed = checkRes.isSubscribed;
      _activeSubscription = checkRes.subscription;

      final tiersRes = await ApiService.getHostSubscriptionTiers(
        hostUserId: widget.hostUserId,
      );
      _tiers = tiersRes.tiers;

      if (_isSubscribed && _activeSubscription != null) {
        _exclusiveImages = _activeSubscription!.tierImages;
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e, s) {
      Log.e(_tag, 'loadData failed', e, s);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _subscribe(SubscriptionTier tier) async {
    final session = context.read<SessionManager>();
    final user = context.read<AuthProvider>().user;
    if (user != null && user.coin < tier.price) {
      Fluttertoast.showToast(msg: 'Not enough diamonds. Please recharge.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.subscribeToHost(
        userId: session.userId,
        hostUserId: widget.hostUserId,
        tierId: tier.id ?? '',
      );
      if (res.status) {
        Fluttertoast.showToast(msg: 'Subscribed to ${widget.hostName}!');
        if (mounted) context.read<AuthProvider>().refreshUser();
        await _loadData();
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Subscription failed');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e, s) {
      Log.e(_tag, 'subscribe failed', e, s);
      Fluttertoast.showToast(msg: 'Subscription failed');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.themed(context, 0xFF0E0E13, 0xFFF6F5FB),
      body: _isLoading
          ? const Center(child: Preloader(color: AppTheme.primary))
          : CustomScrollView(
              slivers: [
                _buildSliverHeader(),
                SliverToBoxAdapter(
                  child: _isSubscribed ? _buildSubscribedBody() : _buildTiersBody(),
                ),
              ],
            ),
    );
  }

  // ---- Header with host info --------------------------------------------------
  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppTheme.themed(context, 0xFF1A1A2E),
      foregroundColor: Colors.white, // back icon sits over the banner image
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Host banner image
            CachedNetworkImage(
              imageUrl: VideoUtil.getFullImageUrl(widget.hostImage ?? ''),
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.brandGradient,
                ),
              ),
            ),
            // Dark gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            // Host info at bottom
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                children: [
                  UserAvatar(imageUrl: widget.hostImage, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.hostName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (_isSubscribed) ...[
                              const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
                              const SizedBox(width: 4),
                              const Text(
                                'Subscribed',
                                style: TextStyle(color: Color(0xFF4CAF50), fontSize: 13),
                              ),
                            ] else ...[
                              const Icon(Icons.lock, color: Colors.white54, size: 16),
                              const SizedBox(width: 4),
                              const Text(
                                'Subscribe to unlock exclusive content',
                                style: TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Tiers view (not subscribed) --------------------------------------------
  Widget _buildTiersBody() {
    if (_tiers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.subscriptions_outlined, color: AppTheme.fg(context, 0.38), size: 56),
            const SizedBox(height: 16),
            Text(
              'No Subscription Plans',
              style: TextStyle(color: AppTheme.fg(context), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.hostName} hasn\'t created any subscription plans yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.fg(context, 0.54), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a Plan',
            style: TextStyle(
              color: AppTheme.fg(context),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Subscribe with diamonds and unlock exclusive photos',
            style: TextStyle(color: AppTheme.fg(context, 0.54), fontSize: 14),
          ),
          const SizedBox(height: 20),
          ..._tiers.map((tier) => _buildTierCard(tier)),
        ],
      ),
    );
  }

  Widget _buildTierCard(SubscriptionTier tier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.themed(context, 0xFF1B1B26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.hairline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tier.name ?? 'Tier',
                  style: TextStyle(
                    color: AppTheme.fg(context),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${tier.price} ${Const.coinName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tier.description?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              tier.description!,
              style: TextStyle(color: AppTheme.fg(context, 0.7), fontSize: 14),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time, color: AppTheme.fg(context, 0.38), size: 16),
              const SizedBox(width: 4),
              Text(
                '${tier.durationDays} days',
                style: TextStyle(color: AppTheme.fg(context, 0.54), fontSize: 13),
              ),
              const SizedBox(width: 16),
              Icon(Icons.photo_library, color: AppTheme.fg(context, 0.38), size: 16),
              const SizedBox(width: 4),
              Text(
                '${tier.images.length} exclusive photos',
                style: TextStyle(color: AppTheme.fg(context, 0.54), fontSize: 13),
              ),
            ],
          ),
          if (tier.images.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tier.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: VideoUtil.getFullImageUrl(tier.images[i]),
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 90,
                            height: 90,
                            color: AppTheme.fg(context, 0.12),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 90,
                            height: 90,
                            color: AppTheme.fg(context, 0.12),
                            child: Icon(Icons.broken_image, color: AppTheme.fg(context, 0.38)),
                          ),
                        ),
                        Container(
                          width: 90,
                          height: 90,
                          color: Colors.black.withValues(alpha: 0.4),
                          child: const Center(
                            child: Icon(Icons.lock, color: Colors.white70, size: 28),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _subscribe(tier),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Subscribe for ${tier.price} ${Const.coinName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Subscribed view --------------------------------------------------------
  Widget _buildSubscribedBody() {
    final sub = _activeSubscription;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subscription info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.themed(context, 0xFF1B1B26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active: ${sub?.tierName ?? "Subscribed"}',
                        style: TextStyle(
                          color: AppTheme.fg(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (sub?.expiresAt != null)
                        Text(
                          'Expires: ${_formatDate(sub!.expiresAt!)}',
                          style: TextStyle(color: AppTheme.fg(context, 0.54), fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Exclusive photos
          if (_exclusiveImages.isEmpty) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.photo_library_outlined, color: AppTheme.fg(context, 0.38), size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'No exclusive photos yet',
                      style: TextStyle(color: AppTheme.fg(context, 0.54), fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.lock_open, color: Color(0xFF4CAF50), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Exclusive Photos',
                  style: TextStyle(
                    color: AppTheme.fg(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${_exclusiveImages.length})',
                  style: TextStyle(color: AppTheme.fg(context, 0.54), fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Photo grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.75,
              ),
              itemCount: _exclusiveImages.length,
              itemBuilder: (_, i) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: VideoUtil.getFullImageUrl(_exclusiveImages[i]),
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppTheme.fg(context, 0.12)),
                    errorWidget: (_, __, ___) => Container(
                      color: AppTheme.fg(context, 0.12),
                      child: Icon(Icons.broken_image, color: AppTheme.fg(context, 0.38)),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
