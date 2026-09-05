/// Emoji / reaction picker sheet — Bigo/Chamet-style white bottom panel.
///
/// Ports native `EmojiBottomsheetFragment.java` with a tabbed grid of
/// reactions and gift emojis. Tabs sit at the bottom, the grid is 4 columns,
/// and cells use the backend image (or a text fallback) without heavy
/// containers so the emojis look like the reference screenshots.
library emoji_picker;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../models/gift_models.dart';
import '../models/missing_models.dart' show ReactionItem, ReactionRoot;
import '../services/api_service.dart';
import '../services/session_manager.dart';
import '../theme/app_theme.dart';
import '../utils/log.dart';
import '../utils/media_utils.dart';
import '../utils/vip_privilege_helper.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'EmojiPicker';

void showEmojiPickerSheet(
  BuildContext context, {
  required ValueChanged<GiftItem> onSelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EmojiPickerSheet(onSelected: onSelected),
  );
}

class _EmojiPickerSheet extends StatefulWidget {
  const _EmojiPickerSheet({required this.onSelected});

  final ValueChanged<GiftItem> onSelected;

  @override
  State<_EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<_EmojiPickerSheet>
    with TickerProviderStateMixin {
  final _categories = <GiftCategory>[];
  final _giftsByCategory = <String, List<GiftItem>>{};
  final _reactions = <ReactionItem>[];
  bool _loading = true;
  bool _reactionsLoaded = false;
  TabController? _tabController;

  /// Built-in emoji reactions used as fallback when the backend
  /// `/reaction/getReaction` endpoint returns no data.
  static const _builtinEmojis = [
    '❤️', '😂', '😍', '🔥',
    '👍', '👏', '🎉', '😡',
    '😢', '😮', '🤔', '💪',
    '🌹', '💋', '😎', '🙏',
  ];

  List<ReactionItem> get _builtinReactions => _builtinEmojis
      .map((e) => ReactionItem(id: e, name: e, image: ''))
      .toList();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final session = context.read<SessionManager>();
    try {
      // Load reactions first so the user can react immediately.
      final reactionRes = await ApiService.getReactions().catchError((e) {
        Log.e(_tag, 'reactions failed', e);
        return ReactionRoot();
      });
      if (mounted) {
        setState(() {
          _reactions.addAll(reactionRes.data);
          // Fallback: if backend has no reactions, use built-in emoji reactions
          // so the reaction tab is never empty.
          if (_reactions.isEmpty) {
            _reactions.addAll(_builtinReactions);
          }
          _reactionsLoaded = true;
          _loading = false;
        });
      }

      // Then load gift categories in the background for the extra gift tabs.
      try {
        final bulkRes = await ApiService.getAllGiftsWithCategories(session.userId);
        if (bulkRes.isNotEmpty) {
          final catList = bulkRes['category'];
          if (catList is List) {
            for (final c in catList) {
              if (c is Map) {
                final cat = GiftCategory.fromJson(c.cast<String, dynamic>());
                _categories.add(cat);
                final gifts = c['gift'];
                if (gifts is List) {
                  _giftsByCategory[cat.id ?? ''] = gifts
                      .map((g) => GiftItem.fromJson((g as Map).cast<String, dynamic>()))
                      .toList();
                }
              }
            }
          }
        } else {
          // Fallback: load categories individually
          final catRes = await ApiService.getGiftCategories();
          _categories.addAll(catRes.category);
          for (final cat in _categories) {
            _loadGifts(cat.id ?? '');
          }
        }
        if (mounted && _categories.isNotEmpty) {
          setState(() {
            _tabController = TabController(length: _categories.length + 1, vsync: this);
          });
        }
      } catch (e) {
        Log.e(_tag, 'gift categories failed', e);
      }
    } catch (e, s) {
      Log.e(_tag, 'loadAll failed', e, s);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadGifts(String categoryId) async {
    try {
      final res = await ApiService.getGifts(categoryId: categoryId);
      if (mounted) {
        setState(() => _giftsByCategory[categoryId] = res.gift);
      }
    } catch (e, s) {
      Log.e(_tag, 'gifts failed for $categoryId', e, s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Container(
      height: height * 0.55,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, -8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            _dragHandle(),
            if (_loading)
              const Expanded(child: Center(child: Preloader()))
            else if (_reactions.isEmpty && _categories.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No reactions',
                    style: TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                ),
              )
            else if (_categories.isNotEmpty && _tabController != null) ...[
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _reactionGrid(),
                    ..._categories.map((c) => _giftGrid(c.id ?? '')),
                  ],
                ),
              ),
              _bottomTabBar(),
            ] else
              Expanded(child: _reactionGrid()),
          ],
        ),
      ),
    );
  }

  Widget _dragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _bottomTabBar() {
    final tabs = <Widget>[
      const Tab(icon: Icon(Icons.emoji_emotions, size: 24)),
      ..._categories.map(_categoryTab),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
      ),
      child: SafeArea(
        top: false,
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicator: BoxDecoration(
            color: const Color(0xFFF1F2F4),
            borderRadius: BorderRadius.circular(22),
          ),
          indicatorPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Colors.black45,
          tabs: tabs,
        ),
      ),
    );
  }

  Widget _categoryTab(GiftCategory cat) {
    final image = cat.image;
    final hasImage = image != null && image.isNotEmpty;
    return Tab(
      icon: hasImage
          ? CachedNetworkImage(
              imageUrl: VideoUtil.getFullImageUrl(image),
              width: 26,
              height: 26,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const ImageIcon(const AssetImage("assets/gift/official_gift.png"), size: 22),
            )
          : const ImageIcon(const AssetImage("assets/gift/official_gift.png"), size: 22),
    );
  }

  Widget _reactionGrid() {
    if (!_reactionsLoaded) {
      return const Center(child: Preloader(color: Colors.black26));
    }
    if (_reactions.isEmpty) {
      return const Center(
        child: Text('No reactions', style: TextStyle(color: Colors.black54, fontSize: 14)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _reactions.length,
      itemBuilder: (_, i) {
        final r = _reactions[i];
        return _EmojiCell(
          id: r.id,
          name: r.name,
          image: r.image,
          onTap: () {
            Navigator.pop(context);
            widget.onSelected(GiftItem(
              id: r.id,
              name: r.name,
              image: r.image,
              coin: 0,
            ));
          },
        );
      },
    );
  }

  Widget _giftGrid(String categoryId) {
    final gifts = _giftsByCategory[categoryId] ?? [];
    if (gifts.isEmpty) {
      return const Center(child: Preloader(color: Colors.black26));
    }
    final session = context.read<SessionManager>();
    final canUsePremiumEmoji = VipPrivilegeHelper.canUsePremiumEmoji(session);
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: gifts.length,
      itemBuilder: (_, i) {
        final g = gifts[i];
        final isVipLocked = (g.isVipGift || g.isVipExclusive) && !canUsePremiumEmoji;
        return _EmojiCell(
          id: g.id,
          name: g.name,
          image: g.image,
          coin: g.coin,
          locked: isVipLocked,
          onTap: () {
            if (isVipLocked) {
              Fluttertoast.showToast(
                msg: 'VIP membership with Premium Emoji privilege required',
              );
              return;
            }
            Navigator.pop(context);
            widget.onSelected(g);
          },
        );
      },
    );
  }
}

/// One selectable emoji/sticker cell — text or image, no heavy container.
class _EmojiCell extends StatelessWidget {
  const _EmojiCell({
    this.id,
    this.name,
    this.image,
    this.coin,
    this.locked = false,
    this.onTap,
  });

  final String? id;
  final String? name;
  final String? image;
  final int? coin;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = image != null && image!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: VideoUtil.getFullImageUrl(image),
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => _textFallback,
                    )
                  : _textFallback,
            ),
          ),
          if (coin != null && !locked) ...[
            const SizedBox(height: 2),
            Text(
              '$coin',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFFB800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget get _textFallback => Text(
        name ?? '😊',
        style: const TextStyle(fontSize: 28),
      );
}

