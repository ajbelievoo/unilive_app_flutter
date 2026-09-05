import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../constants/const.dart';
import '../models/subscription_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import '../theme/app_theme.dart';
import '../utils/log.dart';
import '../utils/media_utils.dart';
import 'user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

/// Shows the subscription bottom sheet for a host.
///
/// Displays the host's subscription tiers. If the user is already subscribed,
/// shows the exclusive photos. If not, shows a subscribe button.
void showSubscriptionSheet(
  BuildContext context, {
  required String hostUserId,
  required String hostName,
  String? hostImage,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SubscriptionSheet(
      hostUserId: hostUserId,
      hostName: hostName,
      hostImage: hostImage,
    ),
  );
}

class _SubscriptionSheet extends StatefulWidget {
  const _SubscriptionSheet({
    required this.hostUserId,
    required this.hostName,
    this.hostImage,
  });

  final String hostUserId;
  final String hostName;
  final String? hostImage;

  @override
  State<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<_SubscriptionSheet> {
  static const String _tag = 'SubscriptionSheet';
  bool _isLoading = true;
  bool _isSubscribed = false;
  List<SubscriptionTier> _tiers = [];
  UserSubscription? _activeSubscription;
  List<String> _exclusiveImages = [];
  int _currentImageIndex = 0;

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
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const Divider(color: Colors.white12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Preloader(color: AppTheme.primary),
              ),
            )
          else if (_isSubscribed)
            _buildSubscribedView()
          else
            _buildTiersView(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          UserAvatar(imageUrl: widget.hostImage, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.hostName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isSubscribed ? 'Subscribed' : 'Subscribe to unlock exclusive content',
                  style: TextStyle(
                    color: _isSubscribed ? const Color(0xFF4CAF50) : Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildTiersView() {
    if (_tiers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.subscriptions_outlined, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No subscription tiers available',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.hostName} hasn\'t created any subscription tiers yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
            ),
          ],
        ),
      );
    }
    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tiers.length,
        itemBuilder: (_, i) {
          final tier = _tiers[i];
          return _buildTierCard(tier);
        },
      ),
    );
  }

  Widget _buildTierCard(SubscriptionTier tier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tier.name ?? 'Tier',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tier.price} ${Const.coinName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (tier.description != null && tier.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              tier.description!,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.white.withValues(alpha: 0.4), size: 14),
              const SizedBox(width: 4),
              Text(
                '${tier.durationDays} days',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
              const SizedBox(width: 12),
              Icon(Icons.photo_library, color: Colors.white.withValues(alpha: 0.4), size: 14),
              const SizedBox(width: 4),
              Text(
                '${tier.images.length} exclusive photos',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
            ],
          ),
          if (tier.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tier.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      alignment: Alignment.topLeft,
                      children: [
                        CachedNetworkImage(
                          imageUrl: VideoUtil.getFullImageUrl(tier.images[i]),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.white12),
                          errorWidget: (_, __, ___) => Container(color: Colors.white12),
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          color: Colors.black.withValues(alpha: 0.5),
                          child: const Center(
                            child: Icon(Icons.lock, color: Colors.white70, size: 24),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _subscribe(tier),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E3FF2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Subscribe for ${tier.price} ${Const.coinName}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribedView() {
    if (_exclusiveImages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 48),
            const SizedBox(height: 12),
            const Text(
              'You are subscribed!',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'No exclusive photos available yet.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
            ),
          ],
        ),
      );
    }
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.lock_open, color: Color(0xFF4CAF50), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Exclusive Photos (${_exclusiveImages.length})',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: PageView.builder(
              itemCount: _exclusiveImages.length,
              onPageChanged: (i) => setState(() => _currentImageIndex = i),
              itemBuilder: (_, i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: VideoUtil.getFullImageUrl(_exclusiveImages[i]),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.white12),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.white12,
                        child: const Center(child: Icon(Icons.broken_image, color: Colors.white38)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_exclusiveImages.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _exclusiveImages.length,
                (i) => Container(
                  width: i == _currentImageIndex ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i == _currentImageIndex ? AppTheme.primary : Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
