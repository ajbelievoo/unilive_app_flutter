/// VIP Store screen — refactored for smoothness, state isolation, and stabilized UI.
///
/// Features:
/// - PageView-based tier navigation for state isolation
/// - Synced tab selector for quick navigation
/// - Reactive state management via VipProvider (removed static cache)
/// - Smooth background color/image transitions
/// - Optimized SVGA previews (non-animated in grid, animated in dialog)
/// - Stabilized privilege grids with ValueKeys and placeholders
/// - Reactive purchase logic based on current tier and balance
library vip;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/const.dart';
import '../../models/vip_models.dart';
// import '../../models/vip_extended_models.dart' show VipCelebration; // unused after refactor
import '../../models/user_root.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vip_provider.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import '../../utils/media_utils.dart';
import '../../widgets/currency_icon.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/svga_player_widget.dart';
import '../../widgets/vip_animated_background.dart';
import '../../widgets/vip_countdown_timer.dart';
import '../../widgets/vip_level_up_celebration.dart';
import '../../widgets/vip_profile_preview.dart';
// import '../../widgets/vip_tilt_badge.dart'; // unused after refactor
import 'package:belive/widgets/preloader.dart';

class VipScreen extends StatefulWidget {
  const VipScreen({super.key});

  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends State<VipScreen> with TickerProviderStateMixin {
  static const String _tag = 'VipScreen';

  late final PageController _pageController;
  late final ScrollController _tabScrollController;
  late final AnimationController _entrance;
  int _selectedTierIndex = 0;
  bool _purchasing = false;
  /// Guards one-shot background-image pre-caching so we don't repeat it on
  /// every provider rebuild.
  bool _imagesPrecached = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _tabScrollController = ScrollController();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    // Initialize data from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<VipProvider>().init(auth.userId);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabScrollController.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_selectedTierIndex == index) return;
    setState(() {
      _selectedTierIndex = index;
    });
    _scrollToTab(index);
  }

  void _scrollToTab(int index) {
    if (!_tabScrollController.hasClients) return;
    // Simple logic to keep the selected tab visible
    final offset = index * 80.0; // Estimate width of a tab
    _tabScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onTabTap(int index) {
    if (_selectedTierIndex == index) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuart,
    );
  }

  List<Color> _tierGradientColors(int level) {
    switch (level) {
      case 1:
        return [const Color(0xFF8B6914), const Color(0xFF4A3508)];
      case 2:
        return [const Color(0xFF5D6D7E), const Color(0xFF212F3D)];
      case 3:
        return [const Color(0xFF7D3C98), const Color(0xFF4A235A)];
      case 4:
        return [const Color(0xFF1E8449), const Color(0xFF0E3B1E)];
      case 5:
        return [const Color(0xFF922B21), const Color(0xFF4A0F0A)];
      case 6:
        return [const Color(0xFF7D6608), const Color(0xFF3D3003)];
      case 7:
        return [const Color(0xFF9C3C0A), const Color(0xFF5A1E05)];
      case 8:
        return [const Color(0xFF145A32), const Color(0xFF0A2E1A)];
      case 9:
        return [const Color(0xFF1A1A1A), const Color(0xFF000000)];
      default:
        return [const Color(0xFF8B6914), const Color(0xFF4A3508)];
    }
  }

  Color _tierStrokeColor(int level) {
    switch (level) {
      case 1:
        return const Color(0xFFD4A24E);
      case 2:
        return const Color(0xFFD0D0D8);
      case 3:
        return const Color(0xFFC39BD3);
      case 4:
        return const Color(0xFF52BE80);
      case 5:
        return const Color(0xFFE74C3C);
      case 6:
        return const Color(0xFFF1C40F);
      case 7:
        return const Color(0xFFF5B041);
      case 8:
        return const Color(0xFF28B463);
      case 9:
        return const Color(0xFFFFD700);
      default:
        return const Color(0xFFD4A24E);
    }
  }

  int _tierLevel(VipTier tier, int index) {
    final name = tier.name ?? '';
    final digits = name.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) return int.tryParse(digits) ?? index + 1;
    return index + 1;
  }

  int _vipPointsForLevel(int level) {
    switch (level) {
      case 1:
        return 6000000;
      case 2:
        return 18000000;
      case 3:
        return 60000000;
      case 4:
        return 150000000;
      case 5:
        return 300000000;
      case 6:
        return 600000000;
      case 7:
        return 1020000000;
      case 8:
        return 1620000000;
      case 9:
        return 2700000000;
      default:
        return 0;
    }
  }

  Future<void> _purchaseTier(VipTier tier, int userDiamonds) async {
    if (_purchasing) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      Fluttertoast.showToast(msg: 'Please login first');
      return;
    }

    if (tier.id == null || tier.id!.isEmpty) {
      Fluttertoast.showToast(msg: 'Invalid tier selected');
      return;
    }

    if (tier.effectiveCoinPrice > userDiamonds) {
      Fluttertoast.showToast(
        msg:
            'Not enough ${Const.coinName.toLowerCase()}! You have $userDiamonds but need ${tier.effectiveCoinPrice}.',
      );
      context.pushNamed(AppRoutes.recharge);
      return;
    }

    final confirmed = await _showPurchaseDialog(tier, userDiamonds);
    if (!confirmed) return;

    setState(() => _purchasing = true);

    try {
      final result = await context.read<VipProvider>().buyVipTier(
        userId: auth.userId,
        tierId: tier.id!,
        clientCoinBalance: userDiamonds,
        clientDiamondBalance: (auth.user?.diamond ?? 0).toInt(),
      );

      if (result.$1) {
        Fluttertoast.showToast(msg: result.$2 ?? 'VIP purchase successful!');
        // Diamonds were deducted — refresh the user's coin balance so the
        // wallet / balance shown elsewhere stays in sync.
        if (mounted) await auth.refreshUser();
        // Auto-enable all VIP privacy toggles on purchase (like Bigo Live).
        if (mounted) await _autoEnableVipToggles();
        // Bigo-style full-screen level-up celebration.
        // Prefer backend-provided celebration data (asset URLs, tier color,
        // parsed VIP level); fall back to client-derived tier fields.
        if (mounted) {
          final celeb = result.$3;
          final tierLevel =
              celeb?.newVipLevel ?? _tierLevel(tier, _selectedTierIndex);
          showVipLevelUpCelebration(
            context,
            vipLevel: tierLevel,
            badgeUrl: celeb?.levelBadgeUrl ?? tier.effectiveLevelBadgeUrl,
            tierName: celeb?.tierName ?? tier.name,
            frameUrl: celeb?.profileFrameUrl ?? tier.effectiveProfileFrameUrl,
            userImage: auth.user?.image,
            tierColor: celeb?.colorOrDefault(_tierStrokeColor(tierLevel)),
          );
        }
      } else {
        Fluttertoast.showToast(msg: result.$2 ?? 'Purchase failed');
      }
    } catch (e, s) {
      Log.e(_tag, 'purchaseTier failed', e, s);
      Fluttertoast.showToast(msg: 'Purchase error: $e');
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  /// Auto-enables all VIP privacy toggles in SharedPreferences after a
  /// successful VIP purchase (like Bigo Live / Ola Party — sab kuch active
  /// ho jaaye, user baad mein OFF kar sakta hai).
  Future<void> _autoEnableVipToggles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const toggles = [
        'hide_visitor_records',
        'avoid_disturbing',
        'hide_online_status',
      ];
      for (final key in toggles) {
        if (!prefs.containsKey(key)) {
          await prefs.setBool(key, true);
        }
      }
    } catch (e) {
      Log.e('VipScreen', 'autoEnableVipToggles failed', e);
    }
  }

  Future<bool> _showPurchaseDialog(VipTier tier, int userDiamonds) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.workspace_premium,
                  color: Color(0xFFFFD700),
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('Confirm ${tier.name ?? 'VIP'} Purchase')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogRow('Tier', tier.name ?? 'VIP'),
                _dialogRow(
                  'Price',
                  '${formatCount(tier.effectiveCoinPrice)} ${Const.coinName.toLowerCase()}',
                ),
                _dialogRow('Validity', '${tier.effectiveValidityDays} days'),
                _dialogRow('Your balance', formatCount(userDiamonds)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.goldGradient.colors.first.withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFFFFB800),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'After purchase: ${formatCount(userDiamonds - tier.effectiveCoinPrice)} ${Const.coinName.toLowerCase()} remaining',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldGradient.colors.first,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  Widget _dialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<VipProvider, AuthProvider>(
      builder: (context, provider, auth, child) {
        final tiers = provider.tiers;
        final loading = provider.loading && tiers.isEmpty;

        if (loading) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: PremiumLoading()),
          );
        }

        if (tiers.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: const Center(
              child: Text(
                'No VIP tiers available',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        // Pre-cache all tier background images once so swipes are stutter-free.
        if (!_imagesPrecached && tiers.isNotEmpty) {
          _imagesPrecached = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            for (final t in tiers) {
              final bg = t.backgroundImage;
              if (bg != null && bg.isNotEmpty) {
                precacheImage(NetworkImage(bg), context);
              }
            }
          });
        }

        final currentTier =
            _selectedTierIndex < tiers.length
                ? tiers[_selectedTierIndex]
                : tiers.first;
        final tierLevel = _tierLevel(currentTier, _selectedTierIndex);
        final gradColors = _tierGradientColors(tierLevel);
        final userDiamonds = (auth.user?.coin ?? 0).toInt();

        return Scaffold(
          extendBodyBehindAppBar: true,
          body: Stack(
            alignment: Alignment.topLeft,
            children: [
              // --- Animated colorful + glassmorphic tier background ---
              VipAnimatedBackground(
                gradientColors: gradColors,
                strokeColor: _tierStrokeColor(tierLevel),
                backgroundImageUrl: currentTier.backgroundImage,
                blurSigma: 18,
                overlayOpacity: 0.5,
              ),

              // --- Content (staggered entrance) ---
              SafeArea(
                child: AnimatedBuilder(
                  animation: _entrance,
                  builder: (context, child) {
                    final t = Curves.easeOutCubic.transform(_entrance.value);
                    return Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 36 * (1 - t)),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      _buildAppBar(),
                      _buildTierTabs(tiers),
                      Expanded(
                        child: RepaintBoundary(
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: _onPageChanged,
                            pageSnapping: true,
                            physics: const PageScrollPhysics(),
                            itemCount: tiers.length,
                            itemBuilder: (context, index) {
                              final tier = tiers[index];
                              return VipTierPage(
                                key: ValueKey('tier_page_${tier.id}'),
                                tier: tier,
                                index: index,
                                vipStatus: provider.vipStatusObj,
                                rulesMinPoints: provider.rulesMinPoints,
                                strokeColor: _tierStrokeColor(
                                  _tierLevel(tier, index),
                                ),
                                userImage: auth.user?.image,
                                userName: auth.user?.name,
                                vipExpiresAt: auth.user?.vip?.expiresAt,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Purchase Bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: _buildBottomPurchaseBar(
                    currentTier,
                    userDiamonds,
                    provider.vipStatusObj,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'VIP Store',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.history_rounded,
              color: Colors.white70,
              size: 21,
            ),
            onPressed: () => context.pushNamed(AppRoutes.vipHistory),
          ),
          IconButton(
            icon: const Icon(
              Icons.help_outline_rounded,
              color: Colors.white70,
              size: 21,
            ),
            onPressed: () => context.pushNamed(AppRoutes.svipRules),
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: Colors.white70,
              size: 21,
            ),
            onPressed: () => context.pushNamed(AppRoutes.vipSettings),
          ),
        ],
      ),
    );
  }

  Widget _buildTierTabs(List<VipTier> tiers) {
    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tiers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tier = tiers[index];
          final isSelected = index == _selectedTierIndex;
          final tierLevel = _tierLevel(tier, index);
          final stroke = _tierStrokeColor(tierLevel);

          return GestureDetector(
            onTap: () => _onTabTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                gradient:
                    isSelected
                        ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            stroke.withValues(alpha: 0.4),
                            stroke.withValues(alpha: 0.1),
                          ],
                        )
                        : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.10),
                            Colors.white.withValues(alpha: 0.04),
                          ],
                        ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color:
                      isSelected
                          ? stroke.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.12),
                  width: isSelected ? 1.4 : 1.0,
                ),
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: stroke.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 3),
                          ),
                        ]
                        : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Center(
                  child: Text(
                    'VIP$tierLevel',
                    style: TextStyle(
                      color:
                          isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomPurchaseBar(
    VipTier tier,
    int userDiamonds,
    VipStatus? status,
  ) {
    final stroke = _tierStrokeColor(_tierLevel(tier, _selectedTierIndex));
    final price = tier.effectiveCoinPrice;
    final canAfford = userDiamonds >= price;

    final currentLevel = status?.currentLevel ?? 0;
    final isVipActive = status?.isVip ?? false;
    final tierLevel = _tierLevel(tier, _selectedTierIndex);
    final isThisTierJoined =
        isVipActive && currentLevel > 0 && tierLevel == currentLevel;

    final buttonText =
        isThisTierJoined
            ? 'Joined'
            : (canAfford && price > 0 ? 'Join Now' : 'Recharge');
    final buttonEnabled = !isThisTierJoined;

    final monthPoints = status?.currentMonthEarnedPoints ?? 0;
    final monthTarget = _vipPointsForLevel(tierLevel);
    final progress =
        monthTarget > 0 ? (monthPoints / monthTarget).clamp(0.0, 1.0) : 0.0;

    final statusTitle =
        isVipActive && currentLevel > 0
            ? 'Your VIP $currentLevel is active'
            : (isVipActive ? 'Your VIP is active' : "You don't have VIP");

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: stroke.withValues(alpha: 0.4), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: stroke.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, -2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Avatar + status + record + join button
            Row(
              children: [
                // User avatar
                ClipOval(
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: _buildMiniAvatar(),
                  ),
                ),
                const SizedBox(width: 10),
                // Status text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'This Month: ${formatCount(monthPoints)} pts',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                // Record button
                GestureDetector(
                  onTap: () => context.pushNamed(AppRoutes.vipHistory),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Record',
                        style: TextStyle(
                          color: stroke,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.chevron_right, color: stroke, size: 16),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Join / Recharge button
                GestureDetector(
                  onTap:
                      buttonEnabled && !_purchasing
                          ? () {
                            if (!canAfford && !isThisTierJoined) {
                              context.pushNamed(AppRoutes.recharge);
                            } else {
                              _purchaseTier(tier, userDiamonds);
                            }
                          }
                          : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient:
                          buttonEnabled
                              ? LinearGradient(
                                colors: [stroke, stroke.withValues(alpha: 0.8)],
                              )
                              : null,
                      color:
                          buttonEnabled
                              ? null
                              : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow:
                          buttonEnabled
                              ? [
                                BoxShadow(
                                  color: stroke.withValues(alpha: 0.5),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                              : null,
                    ),
                    child:
                        _purchasing
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: Preloader(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(
                              buttonText,
                              style: TextStyle(
                                color:
                                    buttonEnabled
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.3),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Row 2: Monthly points progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(stroke),
              ),
            ),
            const SizedBox(height: 6),
            // Row 3: current points + balance + target
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${formatCount(monthPoints)} pts',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CurrencyIcon(CurrencyType.diamond, size: 11),
                    const SizedBox(width: 3),
                    Text(
                      '${formatCount(userDiamonds)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!isThisTierJoined) ...[
                      const SizedBox(width: 8),
                      Text(
                        '/ ${formatCount(price)}',
                        style: TextStyle(
                          color: canAfford ? stroke : const Color(0xFFE74C3C),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${formatCount(monthTarget)} pts',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniAvatar() {
    final auth = context.read<AuthProvider>();
    final img = auth.user?.image;
    if (img != null && img.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: img,
        fit: BoxFit.cover,
        errorWidget:
            (_, __, ___) => Container(
              color: Colors.grey.shade800,
              child: const Icon(Icons.person, color: Colors.white54, size: 20),
            ),
      );
    }
    return Container(
      color: Colors.grey.shade800,
      child: const Icon(Icons.person, color: Colors.white54, size: 20),
    );
  }
}

/// A standalone page for a specific VIP tier, ensuring state isolation.
///
/// Implemented as a [StatefulWidget] with [AutomaticKeepAliveClientMixin] so
/// that Flutter keeps the page alive when the user swipes past it in the
/// [PageView], preventing expensive rebuilds (SVGA players, network images,
/// animated progress bars) every time the user swipes back.
class VipTierPage extends StatefulWidget {
  final VipTier tier;
  final int index;
  final VipStatus? vipStatus;
  final Map<String, int> rulesMinPoints;
  final Color strokeColor;
  final String? userImage;
  final String? userName;
  final String? vipExpiresAt;

  const VipTierPage({
    super.key,
    required this.tier,
    required this.index,
    this.vipStatus,
    required this.rulesMinPoints,
    required this.strokeColor,
    this.userImage,
    this.userName,
    this.vipExpiresAt,
  });

  @override
  State<VipTierPage> createState() => _VipTierPageState();
}

class _VipTierPageState extends State<VipTierPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ---------------------------------------------------------------------------
  // Shorthand getters — delegate to widget fields so the method bodies below
  // can reference them without prefixing everything with "widget.".
  // ---------------------------------------------------------------------------
  VipTier get tier => widget.tier;
  int get index => widget.index;
  VipStatus? get vipStatus => widget.vipStatus;
  Map<String, int> get rulesMinPoints => widget.rulesMinPoints;
  Color get strokeColor => widget.strokeColor;
  String? get userImage => widget.userImage;
  String? get userName => widget.userName;
  String? get vipExpiresAt => widget.vipExpiresAt;

  int _getVipPointsForLevel(int level) {
    final key = 'VIP$level';
    if (rulesMinPoints.containsKey(key)) return rulesMinPoints[key]!;
    switch (level) {
      case 1:
        return 6000000;
      case 2:
        return 18000000;
      case 3:
        return 60000000;
      case 4:
        return 150000000;
      case 5:
        return 300000000;
      case 6:
        return 600000000;
      case 7:
        return 1020000000;
      case 8:
        return 1620000000;
      case 9:
        return 2700000000;
      default:
        return 0;
    }
  }

  String _formatPoints(int points) {
    if (points >= 1000000000)
      return '${(points / 1000000000).toStringAsFixed(1)}B';
    if (points >= 1000000) return '${(points / 1000000).toStringAsFixed(1)}M';
    if (points >= 1000) return '${(points / 1000).toStringAsFixed(1)}K';
    return '$points';
  }

  int _tierLevel() {
    final name = tier.name ?? '';
    final digits = name.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) return int.tryParse(digits) ?? index + 1;
    return index + 1;
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFFFFFFFF);
  }

  Widget _buildVehiclePreview(BuildContext context, String url, Color stroke) {
    return GestureDetector(
      onTap: () => _showVehicleDialog(context, url, stroke),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stroke.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: stroke.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.directions_car, color: stroke, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VIP Vehicle / Ride',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to preview entrance animation',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_circle_outline, color: stroke, size: 24),
          ],
        ),
      ),
    );
  }

  void _showVehicleDialog(BuildContext context, String url, Color stroke) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Vehicle Preview',
      barrierColor: Colors.black87,
      pageBuilder:
          (ctx, _, __) => Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(ctx).size.width * 0.9,
                height: MediaQuery.of(ctx).size.height * 0.6,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: stroke.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'VIP Vehicle Preview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Center(
                        child:
                            SvgaHelper.isSvgaUrl(url)
                                ? SvgaPlayer(url: url, allowAnimation: true)
                                : CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.contain,
                                  errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, color: Colors.white24),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin.
    final tierLvl = _tierLevel();
    final monthPoints = vipStatus?.currentMonthEarnedPoints ?? 0;
    final monthTarget = _getVipPointsForLevel(tierLvl);
    final progress =
        monthTarget > 0 ? (monthPoints / monthTarget).clamp(0.0, 1.0) : 0.0;

    return SingleChildScrollView(
      // ClampingScrollPhysics prevents the inner vertical scroll from
      // competing with the outer horizontal PageView swipe gesture.
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        children: [
          // Hero Section — Bigo-style profile + frame preview
          VipProfilePreview(
            userImage: userImage,
            frameUrl: tier.effectiveProfileFrameUrl,
            badgeUrl: tier.effectiveLevelBadgeUrl,
            glowColor: strokeColor,
            userName: userName,
            nameColor: _parseColor(tier.effectiveNameColor),
            size: 100,
            frameSize: 140,
          ),
          const SizedBox(height: 8),
          Text(
            tier.name ?? 'VIP$tierLvl',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: strokeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: strokeColor.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Text(
              '${tier.effectiveValidityDays} days validity',
              style: TextStyle(
                color: strokeColor.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Active VIP expiry countdown
          if (vipExpiresAt != null && vipExpiresAt!.isNotEmpty) ...[
            const SizedBox(height: 8),
            VipCountdownTimer(
              expiresAt: vipExpiresAt!,
              compact: true,
              style: const TextStyle(fontSize: 12),
            ),
          ],
          // Vehicle / Ride preview (Bigo-style entrance effect preview)
          if (tier.effectiveEntranceAnimationUrl != null &&
              tier.effectiveEntranceAnimationUrl!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildVehiclePreview(
              context,
              tier.effectiveEntranceAnimationUrl!,
              strokeColor,
            ),
          ],
          const SizedBox(height: 20),

          // Monthly Progress
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildPointsProgress(progress, monthPoints, monthTarget),
          ),
          const SizedBox(height: 16),

          // Identity Privileges — isolated in its own repaint layer so that
          // neighbouring animations don't trigger expensive grid repaints.
          RepaintBoundary(child: _buildIdentityGrid(context)),
          const SizedBox(height: 12),

          // Exclusive Privileges — same isolation.
          RepaintBoundary(child: _buildExclusiveGrid(context)),

          const SizedBox(height: 16),
          _buildFooterActions(context),
        ],
      ),
    );
  }

  Widget _buildPointsProgress(double progress, int points, int target) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: strokeColor.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: strokeColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Points',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    const CurrencyIcon(CurrencyType.diamond, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatPoints(points)} / ${_formatPoints(target)}',
                      style: TextStyle(
                        color: strokeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: progress),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(strokeColor),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityGrid(BuildContext context) {
    final items = _buildIdentityItems();
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 32 - 32 - 30) / 4;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: strokeColor.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: strokeColor.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('VIP Identity'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 14,
              children:
                  items
                      .map(
                        (p) => SizedBox(
                          width: itemWidth,
                          height: itemWidth / 0.72,
                          child: _PrivilegeCard(
                            item: p,
                            strokeColor: strokeColor,
                            tierLevel: _tierLevel(),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExclusiveGrid(BuildContext context) {
    final items = _buildExclusiveItems();
    if (items.isEmpty) return const SizedBox.shrink();
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 32 - 32 - 20) / 3;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.015),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: strokeColor.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: strokeColor.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Exclusive Privileges'),
            const SizedBox(height: 4),
            Text(
              '${items.where((e) => !e.isLocked).length} unlocked',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 12,
              children:
                  items
                      .map(
                        (e) => SizedBox(
                          width: itemWidth,
                          height: itemWidth / 0.78,
                          child: _ExclusiveCardWidget(
                            item: e,
                            strokeColor: strokeColor,
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: strokeColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  List<_PrivilegeItem> _buildIdentityItems() {
    return [
      _PrivilegeItem(Icons.label, 'VIP Tag', tier.tagUrl),
      _PrivilegeItem(Icons.title, 'VIP Title', tier.nameUrl),
      _PrivilegeItem(
        Icons.military_tech,
        'VIP Medal',
        tier.effectiveLevelBadgeUrl,
      ),
      _PrivilegeItem(Icons.graphic_eq, 'Mic Wave', tier.voiceWaveUrl),
      _PrivilegeItem(
        Icons.crop_free,
        'VIP Frame',
        tier.effectiveProfileFrameUrl,
      ),
      _PrivilegeItem(
        Icons.card_giftcard,
        'Room Card',
        tier.effectiveRoomCardUrl,
      ),
      _PrivilegeItem(
        Icons.chat_bubble_outline,
        'VIP Bubble',
        tier.chatBubbleUrl,
      ),
      _PrivilegeItem(
        Icons.directions_car,
        'Vehicle',
        tier.effectiveEntranceAnimationUrl,
      ),
    ];
  }

  List<_ExclusiveItem> _buildExclusiveItems() {
    final items = <_ExclusiveItem>[];
    final flags = tier.getPrivilegeFlags();

    if (flags['isViewVisitorRecordsEnabled'] == true)
      items.add(_ExclusiveItem('View visitor\nrecords', Icons.visibility));
    if (flags['isRoomOnlineListTopEnabled'] == true)
      items.add(_ExclusiveItem('Room online\nlist on top', Icons.arrow_upward));
    if (flags['isSendRoomPicturesEnabled'] == true)
      items.add(_ExclusiveItem('Send Room\nPictures', Icons.camera_alt));
    if (flags['isProfileBackgroundEnabled'] == true)
      items.add(_ExclusiveItem('Profile\nbackground', Icons.wallpaper));
    if (flags['isLudoDiceSkinEnabled'] == true)
      items.add(_ExclusiveItem('Ludo Dice\nSkin', Icons.casino));
    if (flags['isLudoDiceRefreshEnabled'] == true)
      items.add(_ExclusiveItem('Ludo dice\nrefresh', Icons.refresh));
    if (flags['isPremiumEmojiAndStickersEnabled'] == true)
      items.add(_ExclusiveItem('VIP Emoji', Icons.emoji_emotions));
    if (flags['isSendMessagePicturesEnabled'] == true)
      items.add(_ExclusiveItem('Send Message\nPictures', Icons.image));
    if (flags['isSvipGiftsEnabled'] == true)
      items.add(_ExclusiveItem('VIP Gifts', Icons.card_giftcard));
    if (flags['isGoldenNameEnabled'] == true)
      items.add(_ExclusiveItem('Golden name', Icons.star));
    if (flags['isExpBoostEnabled'] == true)
      items.add(_ExclusiveItem('EXP*120%\nSpeed up', Icons.speed));
    if (flags['isHideVisitRecordsEnabled'] == true)
      items.add(_ExclusiveItem('Hide visit\nrecords', Icons.visibility_off));
    if (flags['isCustomizedThemeEnabled'] == true)
      items.add(_ExclusiveItem('Customized\ntheme', Icons.palette));
    if (flags['isPremiumThemeEnabled'] == true)
      items.add(_ExclusiveItem('Premium\nTheme', Icons.style));
    if (flags['isBadgeAndFrameEnabled'] == true)
      items.add(_ExclusiveItem('Badge &\nFrame', Icons.badge));
    if (flags['isColoredChatEnabled'] == true)
      items.add(_ExclusiveItem('Colored\nChat', Icons.chat_bubble));
    if (flags['isSpecialRoomEntranceAnimationEnabled'] == true)
      items.add(_ExclusiveItem('Special\nEntrance', Icons.celebration));
    if (flags['isAntiKickEnabled'] == true)
      items.add(_ExclusiveItem('Anti\nKick', Icons.shield));
    if (flags['isAntiMuteEnabled'] == true)
      items.add(_ExclusiveItem('Anti\nMute', Icons.volume_up));
    if (flags['isDedicatedSupportEnabled'] == true)
      items.add(_ExclusiveItem('Dedicated\nSupport', Icons.support_agent));

    if (vipStatus != null && vipStatus!.hiddenItems.isNotEmpty) {
      for (final hidden in vipStatus!.hiddenItems) {
        items.add(
          _ExclusiveItem(
            hidden.name ?? 'Hidden Item',
            null,
            imageUrl: hidden.iconUrl,
            isLocked: !hidden.active,
          ),
        );
      }
    }
    return items;
  }

  Widget _buildFooterActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _footerBtn(
            context,
            Icons.history_rounded,
            'History',
            () => context.pushNamed(AppRoutes.vipHistory),
          ),
          const SizedBox(width: 8),
          _footerBtn(
            context,
            Icons.help_outline_rounded,
            'VIP Rules',
            () => context.pushNamed(AppRoutes.svipRules),
          ),
          const SizedBox(width: 8),
          _footerBtn(
            context,
            Icons.settings_outlined,
            'Settings',
            () => context.pushNamed(AppRoutes.vipSettings),
          ),
        ],
      ),
    );
  }

  Widget _footerBtn(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: strokeColor.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: strokeColor.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: strokeColor.withValues(alpha: 0.85),
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivilegeCard extends StatelessWidget {
  final _PrivilegeItem item;
  final Color strokeColor;
  final int tierLevel;

  const _PrivilegeCard({
    required this.item,
    required this.strokeColor,
    required this.tierLevel,
  });

  @override
  Widget build(BuildContext context) {
    final url = item.imageUrl;
    final hasUrl =
        url != null && url.trim().isNotEmpty && url.startsWith('http');
    final isSvga = SvgaHelper.isSvgaUrl(url);

    return GestureDetector(
      onTap: () => _showPreview(context),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: strokeColor.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: strokeColor.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: strokeColor.withValues(alpha: 0.18),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                    if (hasUrl)
                      isSvga
                          ? SvgaPlayer(
                            key: ValueKey('grid_svga_${url.hashCode}'),
                            url: url,
                            width: 48,
                            height: 48,
                            allowAnimation: false,
                          )
                          : CachedNetworkImage(
                            imageUrl: url,
                            width: 48,
                            height: 48,
                            fit: BoxFit.contain,
                            placeholder:
                                (_, __) => Icon(
                                  item.icon,
                                  color: strokeColor.withValues(alpha: 0.2),
                                  size: 24,
                                ),
                            errorWidget:
                                (_, __, ___) => Icon(
                                  item.icon,
                                  color: strokeColor.withValues(alpha: 0.3),
                                  size: 24,
                                ),
                          )
                    else
                      Icon(
                        item.icon,
                        color: strokeColor.withValues(alpha: 0.6),
                        size: 26,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  item.label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPreview(BuildContext context) {
    final url = item.imageUrl;
    if (url == null || url.isEmpty) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Preview',
      barrierColor: Colors.black87,
      pageBuilder:
          (ctx, _, __) => Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(ctx).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: strokeColor.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: strokeColor.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SvgaHelper.isSvgaUrl(url)
                          ? SvgaPlayer(
                            url: url,
                            width: 200,
                            height: 200,
                            allowAnimation: true,
                          )
                          : CachedNetworkImage(
                            imageUrl: url,
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, color: Colors.white24, size: 48),
                          ),
                      const SizedBox(height: 16),
                      Text(
                        'VIP $tierLevel Exclusive',
                        style: TextStyle(
                          color: strokeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

class _ExclusiveCardWidget extends StatelessWidget {
  final _ExclusiveItem item;
  final Color strokeColor;

  const _ExclusiveCardWidget({required this.item, required this.strokeColor});

  @override
  Widget build(BuildContext context) {
    final url = item.imageUrl;
    final isSvga = SvgaHelper.isSvgaUrl(url);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: item.isLocked ? 0.03 : 0.08),
            Colors.white.withValues(alpha: item.isLocked ? 0.005 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              item.isLocked
                  ? Colors.white12
                  : strokeColor.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow:
            item.isLocked
                ? null
                : [
                  BoxShadow(
                    color: strokeColor.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child:
                        url != null && url.isNotEmpty
                            ? isSvga
                                ? SvgaPlayer(
                                  url: url,
                                  width: 32,
                                  height: 32,
                                  allowAnimation: false,
                                )
                                : CachedNetworkImage(
                                  imageUrl: url,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.contain,
                                  errorWidget:
                                      (_, __, ___) => Icon(
                                        item.icon ?? Icons.star,
                                        color:
                                            item.isLocked
                                                ? Colors.white12
                                                : strokeColor,
                                        size: 26,
                                      ),
                                )
                            : Icon(
                              item.icon ?? Icons.star,
                              color:
                                  item.isLocked ? Colors.white12 : strokeColor,
                              size: 28,
                            ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Text(
                    item.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: item.isLocked ? Colors.white24 : Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (item.isLocked)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.lock_rounded,
                  size: 10,
                  color: Colors.white24,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrivilegeItem {
  final IconData icon;
  final String label;
  final String? imageUrl;
  _PrivilegeItem(this.icon, this.label, this.imageUrl);
}

class _ExclusiveItem {
  final String name;
  final IconData? icon;
  final String? imageUrl;
  final bool isLocked;
  _ExclusiveItem(this.name, this.icon, {this.imageUrl, this.isLocked = false});
}
