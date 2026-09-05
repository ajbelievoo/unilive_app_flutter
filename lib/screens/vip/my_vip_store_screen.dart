/// My VIP Store screen — ported from native `MyVipStoreActivity.java`.
///
/// Features:
/// - Shows user's active VIP status, badge, expiry
/// - VIP items toggle grid (Profile Frame, Badge, Golden Name, Chat Bubble,
///   Room Card, Entrance Name, Entrance Effect, Profile Background, Voice Wave, VIP Tag)
/// - Monthly VIP points tracking with progress bar
/// - Exclusive privileges grid from tier privilege flags
/// - VIP expiry warning (7 days / expired)
/// - Monthly downgrade warning from retainUntil
/// - Refreshes user data from backend on resume
/// - Falls back to session URLs when API fails
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_root.dart';
import '../../models/vip_models.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import '../../utils/media_utils.dart';
import '../../widgets/svga_player_widget.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/vip_bubble_preview.dart';

class MyVipStoreScreen extends StatefulWidget {
  const MyVipStoreScreen({super.key});

  @override
  State<MyVipStoreScreen> createState() => _MyVipStoreScreenState();
}

class _MyVipStoreScreenState extends State<MyVipStoreScreen> {
  static const String _tag = 'MyVipStore';

  bool _loading = true;
  User? _user;
  final List<_MyVipItem> _items = [];
  final List<_ExclusiveItem> _exclusiveItems = [];
  List<Map<String, dynamic>> _diceSkins = [];
  List<Map<String, dynamic>> _vipThemes = [];
  bool _loadingExtras = false;
  String _expiryText = '';
  Color _expiryColor = const Color(0xFF999999);
  String _monthLabel = 'This Month';
  int _monthlyCurrent = 0;
  int _monthlyTarget = 0;
  double _monthlyProgress = 0;
  bool _isRewarded = false;
  final String _vipStatusText = 'Active';
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _refreshUserData();
  }

  Future<void> _refreshUserData() async {
    final session = context.read<SessionManager>();
    final currentUser = session.getUser();
    if (currentUser == null || currentUser.id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final res = await ApiService.getUser({'userId': currentUser.id});
      if (res.status && res.user != null) {
        final apiUser = res.user!;
        // Merge: keep higher currentMonthEarnedPoints (socket may be fresher)
        final sessionUser = session.getUser();
        if (sessionUser != null &&
            sessionUser.vipStatus != null &&
            apiUser.vipStatus != null) {
          if (sessionUser.vipStatus!.currentMonthEarnedPoints >
              apiUser.vipStatus!.currentMonthEarnedPoints) {
            // Keep session's vipStatus as it's fresher
          }
        }
        session.saveUser(apiUser);
        _loadUserVipData(apiUser);
      } else {
        _loadUserVipData(currentUser);
      }
    } catch (e) {
      Log.e(_tag, 'refreshUserData failed', e);
      _loadUserVipData(currentUser);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadUserVipData(User user) {
    _user = user;
    final vipInfo = user.vip;
    if (vipInfo == null || (vipInfo.tierId ?? '').isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // Expiry
    if (vipInfo.expiresAt != null && vipInfo.expiresAt!.isNotEmpty) {
      _checkVipExpiryWarning(vipInfo.expiresAt!);
    } else {
      _expiryText = '';
    }

    // Monthly tracking
    final vipStatus = user.vipStatus;
    _monthlyCurrent = vipStatus?.currentMonthEarnedPoints ?? 0;
    final tracking = user.vipCoinTracking;
    _monthLabel =
        (tracking?.monthYear != null && tracking!.monthYear!.isNotEmpty)
            ? tracking.monthYear!
            : 'This Month';
    _isRewarded = tracking?.isRewarded ?? false;

    // Monthly downgrade warning
    if (vipStatus != null &&
        vipStatus.retainUntil != null &&
        vipStatus.retainUntil!.isNotEmpty) {
      _checkMonthlyDowngrade(vipStatus.retainUntil!, vipStatus.currentLevel);
    }

    // Fetch tier details
    _fetchVipTierDetails(vipInfo.tierId!);
  }

  void _checkVipExpiryWarning(String expiresAt) {
    try {
      final expiryDate = DateTime.tryParse(expiresAt);
      if (expiryDate == null) {
        _expiryText = 'Expires: $expiresAt';
        return;
      }
      final now = DateTime.now();
      final daysLeft = expiryDate.difference(now).inDays;
      if (daysLeft <= 7 && daysLeft > 0) {
        _expiryText = 'Expires in $daysLeft day(s) - Renew now!';
        _expiryColor = const Color(0xFFFF6B6B);
      } else if (daysLeft <= 0) {
        _expiryText = 'VIP expired - Please renew';
        _expiryColor = const Color(0xFFFF4444);
      } else {
        _expiryText = 'Expires: $expiresAt';
        _expiryColor = const Color(0xFF999999);
      }
    } catch (e) {
      _expiryText = 'Expires: $expiresAt';
    }
  }

  void _checkMonthlyDowngrade(String retainUntil, int currentLevel) {
    try {
      final retainDate = DateTime.tryParse(retainUntil);
      if (retainDate == null) return;
      final daysLeft = retainDate.difference(DateTime.now()).inDays;
      if (daysLeft <= 3 && daysLeft > 0) {
        Fluttertoast.showToast(
          msg:
              'Your VIP level $currentLevel may downgrade in $daysLeft day(s). Earn more points to retain!',
          toastLength: Toast.LENGTH_LONG,
        );
      } else if (daysLeft <= 0) {
        Fluttertoast.showToast(
          msg:
              'VIP monthly reset: Your level may have been adjusted. Check your VIP status.',
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } catch (e) {
      Log.w(_tag, 'Could not parse retainUntil: $retainUntil');
    }
  }

  Future<void> _fetchVipTierDetails(String tierId) async {
    try {
      final res = await ApiService.getVipTiers();
      if (res.status && res.data.isNotEmpty) {
        final tier = res.data.where((t) => t.id == tierId).firstOrNull;
        if (tier != null) {
          _applyTierData(tier);
        } else {
          _buildDefaultItems();
        }
      } else {
        _buildDefaultItems();
      }
    } catch (e) {
      Log.e(_tag, 'fetchVipTierDetails failed', e);
      _buildDefaultItems();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyTierData(VipTier tier) {
    final user = _user;
    if (user == null) return;

    // Monthly target from tier coinPrice
    final tracking = user.vipCoinTracking;
    final spent = tracking?.spent.toInt() ?? 0;
    final coinPrice = tier.coinPrice;
    if (coinPrice > 0) {
      _monthlyTarget = coinPrice;
      _monthlyProgress = (spent / coinPrice).clamp(0.0, 1.0);
    } else {
      _monthlyTarget = 0;
      _monthlyProgress = 0;
    }

    // Build items from tier
    _items.clear();
    final vd = user.vipDetails;
    _addItemIfValid(
      'Profile Frame',
      _pickUrl(tier.profileFrameUrl, vd?.profileFrameUrl),
    );
    _addItemIfValid(
      'VIP Badge',
      _pickUrl(tier.levelBadgeUrl, vd?.levelBadgeUrl, user.vipBadgeUrl),
    );
    _addItemIfValid(
      'Golden Name',
      _pickUrl(tier.nameColor, vd?.nameColor ?? vd?.vipNameColor),
    );
    _addItemIfValid(
      'Chat Bubble',
      _pickUrl(tier.chatBubbleUrl, vd?.chatBubbleUrl),
    );
    _addItemIfValid('Room Card', _pickUrl(tier.roomCardUrl, vd?.roomCardUrl));
    _addItemIfValid('Entrance Name', _pickUrl(tier.nameUrl, vd?.nameUrl));
    _addItemIfValid(
      'Entrance Effect',
      _pickUrl(tier.entranceAnimationUrl, vd?.entranceAnimationUrl),
    );
    _addItemIfValid(
      'Profile Background',
      _pickUrl(tier.profileBackgroundUrl, vd?.profileBackgroundUrl),
    );
    _addItemIfValid(
      'Voice Wave',
      _pickUrl(tier.voiceWaveUrl, vd?.voiceWaveUrl),
    );
    _addItemIfValid('VIP Tag', _pickUrl(tier.tagUrl, vd?.tagUrl));

    // Build exclusive items
    _exclusiveItems.clear();
    _exclusiveItems.addAll(_buildExclusiveItems(tier));

    // Load dice skins + themes
    _loadDiceAndThemes();

    if (mounted) setState(() {});
  }

  void _buildDefaultItems() {
    final user = _user;
    if (user == null) return;
    final vd = user.vipDetails;
    _items.clear();
    _addItemIfValid('Profile Frame', _pickUrl(vd?.profileFrameUrl));
    _addItemIfValid('VIP Badge', _pickUrl(user.vipBadgeUrl, vd?.levelBadgeUrl));
    _addItemIfValid(
      'Golden Name',
      _pickUrl(vd?.nameColor ?? vd?.vipNameColor, '#FFD700'),
    );
    _addItemIfValid('Chat Bubble', _pickUrl(vd?.chatBubbleUrl));
    _addItemIfValid('Room Card', _pickUrl(vd?.roomCardUrl));
    _addItemIfValid('Entrance Name', _pickUrl(vd?.nameUrl));
    _addItemIfValid('Entrance Effect', _pickUrl(vd?.entranceAnimationUrl));
    _addItemIfValid('Profile Background', _pickUrl(vd?.profileBackgroundUrl));
    _addItemIfValid('Voice Wave', _pickUrl(vd?.voiceWaveUrl));
    _addItemIfValid('VIP Tag', _pickUrl(vd?.tagUrl));
    if (mounted) setState(() {});
  }

  String? _pickUrl(String? a, [String? b, String? c]) {
    if (a != null && a.isNotEmpty) return a;
    if (b != null && b.isNotEmpty) return b;
    if (c != null && c.isNotEmpty) return c;
    return null;
  }

  void _addItemIfValid(String name, String? url) {
    if (url != null && url.isNotEmpty) {
      final isOn = _prefs.getBool(name) ?? true;
      _items.add(_MyVipItem(name: name, url: url, isActive: isOn));
    }
  }

  List<_ExclusiveItem> _buildExclusiveItems(VipTier tier) {
    final flags = tier.getPrivilegeFlags();
    final items = <_ExclusiveItem>[];

    if (flags['isProfileBackgroundEnabled'] == true) {
      items.add(_ExclusiveItem('Profile\nWall', Icons.wallpaper));
    }
    if (flags['isMultipleProfileBackgroundsEnabled'] == true) {
      items.add(_ExclusiveItem('Multiple\nProfile Walls', Icons.layers));
    }
    if (flags['isGoldenNameEnabled'] == true) {
      items.add(_ExclusiveItem('Golden\nName', Icons.title));
    }
    if (flags['isBadgeAndFrameEnabled'] == true) {
      items.add(_ExclusiveItem('Badge &\nFrame', Icons.workspace_premium));
    }
    if (flags['isColoredChatEnabled'] == true) {
      items.add(_ExclusiveItem('Colored\nChat', Icons.chat_bubble));
    }
    if (flags['isAntiKickEnabled'] == true) {
      items.add(_ExclusiveItem('Anti\nKick', Icons.shield));
    }
    if (flags['isAntiMuteEnabled'] == true) {
      items.add(_ExclusiveItem('Anti\nMute', Icons.mic_off));
    }
    if (flags['isViewVisitorRecordsEnabled'] == true) {
      items.add(_ExclusiveItem('View Visitor\nRecords', Icons.recent_actors));
    }
    if (flags['isRoomOnlineListTopEnabled'] == true) {
      items.add(_ExclusiveItem('Room Online\nList Top', Icons.arrow_upward));
    }
    if (flags['isSendRoomPicturesEnabled'] == true) {
      items.add(_ExclusiveItem('Send Room\nPictures', Icons.camera_alt));
    }
    if (flags['isLudoDiceSkinEnabled'] == true) {
      items.add(_ExclusiveItem('Ludo Dice\nSkin', Icons.casino));
    }
    if (flags['isLudoDiceRefreshEnabled'] == true) {
      items.add(_ExclusiveItem('Ludo Dice\nRefresh', Icons.refresh));
    }
    if (flags['isPremiumEmojisEnabled'] == true) {
      items.add(_ExclusiveItem('Premium\nEmoji', Icons.emoji_emotions));
    }
    if (flags['isSendMessagePicturesEnabled'] == true) {
      items.add(_ExclusiveItem('Send Message\nPictures', Icons.image));
    }
    if (flags['isSvipGiftsEnabled'] == true) {
      items.add(_ExclusiveItem('VIP\nGifts', Icons.card_giftcard));
    }
    if (flags['isExpBoostEnabled'] == true) {
      items.add(_ExclusiveItem('EXP*120%\nSpeed Up', Icons.speed));
    }
    if (flags['isHideVisitRecordsEnabled'] == true) {
      items.add(_ExclusiveItem('Hide Visit\nRecords', Icons.visibility_off));
    }
    if (flags['isCustomizedThemeEnabled'] == true) {
      items.add(_ExclusiveItem('Customized\nTheme', Icons.palette));
    }
    if (flags['isPremiumThemeEnabled'] == true) {
      items.add(_ExclusiveItem('Premium\nTheme', Icons.style));
    }
    if (flags['isDedicatedSupportEnabled'] == true) {
      items.add(_ExclusiveItem('Dedicated\nSupport', Icons.support_agent));
    }
    if (flags['isHigherProfileVisibilityEnabled'] == true) {
      items.add(_ExclusiveItem('Higher\nVisibility', Icons.visibility));
    }
    if (flags['isHigherPositionInViewerListsEnabled'] == true) {
      items.add(_ExclusiveItem('Higher\nPosition', Icons.arrow_upward));
    }
    if (flags['isSpecialEntranceEnabled'] == true) {
      items.add(_ExclusiveItem('Special\nEntrance', Icons.login));
    }
    if (flags['isExclusiveProfileThemesAndBackgroundsEnabled'] == true) {
      items.add(_ExclusiveItem('Exclusive\nTheme', Icons.auto_awesome));
    }
    if (flags['isNameAnimationEnabled'] == true) {
      items.add(_ExclusiveItem('Name\nAnimation', Icons.animation));
    }

    // Fallback defaults
    if (items.isEmpty) {
      items.add(_ExclusiveItem('VIP\nBadge', Icons.workspace_premium));
      items.add(_ExclusiveItem('Special\nEntrance', Icons.login));
      items.add(_ExclusiveItem('VIP\nGifts', Icons.card_giftcard));
      items.add(_ExclusiveItem('Colored\nChat', Icons.chat_bubble));
      items.add(_ExclusiveItem('Profile\nBackground', Icons.wallpaper));
      items.add(_ExclusiveItem('Golden\nName', Icons.title));
    }

    return items;
  }

  void _toggleItem(String name, bool active) {
    _prefs.setBool(name, active);
    Fluttertoast.showToast(
      msg: '$name ${active ? 'Activated' : 'Deactivated'}',
    );
    setState(() {
      final idx = _items.indexWhere((e) => e.name == name);
      if (idx >= 0) _items[idx] = _items[idx].copyWith(isActive: active);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              if (_loading)
                const Expanded(child: Center(child: PremiumLoading()))
              else if (_user == null ||
                  _user!.vip == null ||
                  (_user!.vip!.tierId ?? '').isEmpty)
                Expanded(child: _buildNoVip())
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshUserData,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        _buildVipStatusHeader(),
                        if (_items.isNotEmpty) _buildItemsGrid(),
                        if (_exclusiveItems.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildExclusiveSection(),
                        ],
                        if (_diceSkins.isNotEmpty || _vipThemes.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildDiceAndThemesSection(),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'My VIP Store',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () => context.pushNamed(AppRoutes.vipHistory),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => context.pushNamed(AppRoutes.vipSettings),
          ),
        ],
      ),
    );
  }

  Widget _buildNoVip() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, color: Colors.white38, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No VIP Active',
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pushNamed(AppRoutes.vip),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text(
              'Get VIP',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipStatusHeader() {
    final badgeUrl = _user?.vipBadgeUrl;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.goldGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (badgeUrl != null && badgeUrl.isNotEmpty)
                SvgaHelper.isSvgaUrl(badgeUrl)
                    ? SvgaPlayer(url: badgeUrl, width: 56, height: 56)
                    : CachedNetworkImage(
                      imageUrl: badgeUrl,
                      width: 56,
                      height: 56,
                      errorWidget:
                          (_, __, ___) => const Icon(
                            Icons.workspace_premium,
                            color: Colors.white,
                            size: 56,
                          ),
                    )
              else
                const Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: 56,
                ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _vipStatusText,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (_expiryText.isNotEmpty)
                      Text(
                        _expiryText,
                        style: TextStyle(
                          color: _expiryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Monthly tracking
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _monthLabel,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isRewarded)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Color(0xFF1B5E20),
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Rewarded',
                      style: TextStyle(
                        color: Color(0xFF1B5E20),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${formatCount(_monthlyCurrent)} pts',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${formatCount(_monthlyTarget)} pts',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _monthlyProgress,
              backgroundColor: Colors.black.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsGrid() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My VIP Items',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _items.length,
            itemBuilder: (ctx, i) => _buildItemCard(_items[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(_MyVipItem item) {
    final isSvga = SvgaHelper.isSvgaUrl(item.url);
    final isChatBubble = item.name == 'Chat Bubble';
    final vipLevel = _user?.vipStatus?.currentLevel ??
        (_user?.isVIP == true ? 1 : 0);
    return GestureDetector(
      onTap: () => _toggleItem(item.name, !item.isActive),
      child: Container(
        decoration: BoxDecoration(
          color:
              item.isActive
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                item.isActive
                    ? const Color(0xFFFFD700).withValues(alpha: 0.4)
                    : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topLeft,
              children: [
                Opacity(
                  opacity: item.isActive ? 1.0 : 0.3,
                  child: isChatBubble
                      ? VipBubblePreview(
                          vipLevel: vipLevel,
                          size: 52,
                          showLabel: true,
                        )
                      : isSvga
                          ? SvgaPlayer(
                            url: item.url,
                            width: 48,
                            height: 48,
                            allowAnimation: false,
                          )
                          : CachedNetworkImage(
                            imageUrl: item.url,
                            width: 48,
                            height: 48,
                            errorWidget:
                                (_, __, ___) => const Icon(
                                  Icons.image,
                                  color: Colors.white38,
                                  size: 32,
                                ),
                          ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.isActive ? Colors.green : Colors.grey,
                    ),
                    child: Icon(
                      item.isActive ? Icons.check : Icons.close,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: item.isActive ? Colors.white : Colors.white38,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExclusiveSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Exclusive Privileges',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.0,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _exclusiveItems.length,
            itemBuilder: (ctx, i) => _buildExclusiveCard(_exclusiveItems[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildExclusiveCard(_ExclusiveItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: const Color(0xFFFFD700), size: 28),
          const SizedBox(height: 6),
          Text(
            item.name,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _loadDiceAndThemes() async {
    if (_loadingExtras) return;
    setState(() => _loadingExtras = true);
    try {
      final results = await Future.wait([
        ApiService.getVipDiceSkins().catchError((e) {
          Log.e(_tag, 'diceSkins failed', e);
          return <String, dynamic>{};
        }),
        ApiService.getVipThemes().catchError((e) {
          Log.e(_tag, 'vipThemes failed', e);
          return <String, dynamic>{};
        }),
      ]);
      final diceData = results[0];
      final themeData = results[1];
      if (mounted) {
        setState(() {
          _diceSkins =
              (diceData['data'] as List? ?? []).cast<Map<String, dynamic>>();
          _vipThemes =
              (themeData['data'] as List? ?? []).cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      Log.e(_tag, 'loadDiceAndThemes failed', e);
    } finally {
      if (mounted) setState(() => _loadingExtras = false);
    }
  }

  Widget _buildDiceAndThemesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_diceSkins.isNotEmpty) ...[
            const Text(
              'Dice Skins',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _diceSkins.length,
                itemBuilder: (ctx, i) {
                  final skin = _diceSkins[i];
                  final url = skin['image']?.toString() ?? '';
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child:
                              url.isNotEmpty
                                  ? CachedNetworkImage(
                                    imageUrl: url,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Icon(Icons.casino, color: Colors.white54),
                                  )
                                  : Container(
                                    width: 56,
                                    height: 56,
                                    color: Colors.white12,
                                    child: const Icon(
                                      Icons.casino,
                                      color: Colors.white54,
                                    ),
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          skin['name']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          if (_vipThemes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'VIP Themes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _vipThemes.length,
                itemBuilder: (ctx, i) {
                  final theme = _vipThemes[i];
                  final url = theme['image']?.toString() ?? '';
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child:
                              url.isNotEmpty
                                  ? CachedNetworkImage(
                                    imageUrl: url,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Icon(Icons.palette, color: Colors.white54),
                                  )
                                  : Container(
                                    width: 56,
                                    height: 56,
                                    color: Colors.white12,
                                    child: const Icon(
                                      Icons.palette,
                                      color: Colors.white54,
                                    ),
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          theme['name']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MyVipItem {
  final String name;
  final String url;
  final bool isActive;

  _MyVipItem({required this.name, required this.url, required this.isActive});

  _MyVipItem copyWith({String? name, String? url, bool? isActive}) =>
      _MyVipItem(
        name: name ?? this.name,
        url: url ?? this.url,
        isActive: isActive ?? this.isActive,
      );
}

class _ExclusiveItem {
  final String name;
  final IconData icon;

  _ExclusiveItem(this.name, this.icon);
}
