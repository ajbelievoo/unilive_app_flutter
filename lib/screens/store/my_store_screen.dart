/// My Store screen — premium dark design showing the user's owned items
/// organized by category and by source (Buy / CP / Friend / Family / VIP).
///
/// Every item the user owns — whether bought or granted by CP / Friend /
/// Family / VIP / reward — appears here under its item category. Each
/// category tab has a sub-filter by source. Expired items are hidden;
/// permanent items stay forever. Selecting an item equips it.
library my_store;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../models/store_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/store_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../utils/log.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/store_widgets.dart';

class MyStoreScreen extends StatefulWidget {
  const MyStoreScreen({super.key});

  @override
  State<MyStoreScreen> createState() => _MyStoreScreenState();
}

class _MyStoreScreenState extends State<MyStoreScreen>
    with SingleTickerProviderStateMixin {
  static const String _tag = 'MyStore';

  late TabController _tabController;
  bool _isLoading = true;
  bool _isToggling = false;
  String? _loadError;
  final Map<String, String> _sourceFilter = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: StoreProvider.storeCategories.length,
      vsync: this,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (mounted) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final session = context.read<SessionManager>();
      if (session.userId.isEmpty) {
        setState(() => _loadError = 'Not logged in — please sign in again.');
        return;
      }
      Log.d(_tag, 'loadMyItems userId=${session.userId}');
      final provider = context.read<StoreProvider>();
      await provider.loadMyItems(userId: session.userId);
      if (!mounted) return;
      final items = provider.myItems;
      Log.d(_tag, 'loaded ${items.length} owned items');
      if (provider.myItemsError != null) {
        setState(() => _loadError = provider.myItemsError);
      } else if (items.isEmpty) {
        setState(
          () =>
              _loadError =
                  'No items yet. Buy from Store or earn via CP/Friend/VIP/Levels.',
        );
      }
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
      setState(() => _loadError = 'Failed to load: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleItem(OwnedStoreItem item) async {
    if (_isToggling) return;
    setState(() => _isToggling = true);
    try {
      final session = context.read<SessionManager>();
      final auth = context.read<AuthProvider>();
      final type = item.type ?? '';
      final id = item.id ?? item.itemId ?? '';
      if (id.isEmpty) {
        Fluttertoast.showToast(msg: 'Item id missing — cannot toggle');
        return;
      }
      Log.d(_tag, 'toggle id=$id type=$type selected=${item.isSelected}');
      if (item.isSelected) {
        final res = await ApiService.deselectStoreItem(
          id: id,
          userId: session.userId,
          type: type,
        );
        if (res.status) {
          auth.setUser(res.user);
          Fluttertoast.showToast(msg: 'Unequipped');
        } else {
          Fluttertoast.showToast(msg: res.message ?? 'Failed to unequip');
        }
      } else {
        final res = await ApiService.selectStoreItem(
          id: id,
          userId: session.userId,
          type: type,
        );
        if (res.status) {
          // Backend often returns updated user WITHOUT avatarFrameImage.
          // If the selected item is an avatar frame, manually patch the
          // frame URL so it renders immediately across the app.
          final originalUser = res.user;
          if (originalUser != null) {
            var updated = originalUser;
            if (type.toLowerCase() == 'avatarframe' ||
                type.toLowerCase() == 'avatar_frame') {
              final selectedFrameUrl = item.image ?? item.thumbnail;
              if (selectedFrameUrl != null && selectedFrameUrl.isNotEmpty) {
                updated = originalUser.copyWith(
                  avatarFrameImage: selectedFrameUrl,
                );
                Log.d(_tag, 'patched avatarFrameImage: $selectedFrameUrl');
              }
            }
            auth.setUser(updated);
          }
          Fluttertoast.showToast(msg: 'Equipped!');
        } else {
          Fluttertoast.showToast(msg: res.message ?? 'Failed to equip');
        }
      }
      await _loadData();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final body = e.response?.data;
      Log.e(_tag, 'toggle DioException code=$code body=$body');
      final msg =
          (body is Map && body['message'] is String)
              ? body['message']
              : 'Failed ($code)';
      Fluttertoast.showToast(msg: msg);
    } catch (e, s) {
      Log.e(_tag, 'toggle failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to update. Try again.');
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  String _currentSource(String type) => _sourceFilter[type] ?? 'all';
  void _setSource(String type, String source) =>
      setState(() => _sourceFilter[type] = source);

  List<OwnedStoreItem> _itemsForTab(int index) {
    final type = StoreProvider.storeCategories[index]['type']!;
    return context.read<StoreProvider>().myItemsByCategory(
      type,
      source: _currentSource(type),
    );
  }

  CategoryStyle get _currentStyle {
    final type = StoreProvider.storeCategories[_tabController.index]['type']!;
    return categoryStyles[type] ?? categoryStyles['avatarFrame']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        alignment: Alignment.topLeft,
        children: [
          StoreBackground(glowColor: _currentStyle.glow),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                StoreTabBar(
                  controller: _tabController,
                  glowColor: _currentStyle.glow,
                  tabs:
                      StoreProvider.storeCategories.map((c) {
                        final s = categoryStyles[c['type']]!;
                        return Tab(icon: Icon(s.icon, size: 16), text: s.label);
                      }).toList(),
                ),
                if (!_isLoading) _buildInventorySummary(),
                Expanded(
                  child:
                      _isLoading
                          ? const Center(child: PremiumLoading())
                          : RefreshIndicator(
                            onRefresh: _loadData,
                            color: _currentStyle.glow,
                            backgroundColor: Colors.black87,
                            child: TabBarView(
                              controller: _tabController,
                              children: List.generate(
                                StoreProvider.storeCategories.length,
                                (i) => _buildTab(
                                  i,
                                  StoreProvider.storeCategories[i]['type']!,
                                  StoreProvider.storeCategories[i]['label']!,
                                ),
                              ),
                            ),
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          ShaderMask(
            shaderCallback:
                (b) => LinearGradient(
                  colors: [
                    Colors.white,
                    _currentStyle.glow.withValues(alpha: 0.7),
                  ],
                ).createShader(b),
            child: const Text(
              'My Items',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          AppBarPillButton(
            icon: Icons.storefront,
            label: 'Store',
            onTap: () => context.pushNamed(AppRoutes.store),
          ),
        ],
      ),
    );
  }

  Widget _buildInventorySummary() {
    final provider = context.read<StoreProvider>();
    final total = provider.myItems.length;
    final equipped = provider.myItems.where((i) => i.isSelected).length;
    final permanent = provider.myItems.where((i) => i.isPermanent).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: StoreGlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        borderRadius: 18,
        glow: _currentStyle.glow,
        glowBlur: 12,
        child: Row(
          children: [
            _StatTile(
              icon: Icons.inventory_2,
              label: 'Total',
              value: '$total',
              color: _currentStyle.glow,
            ),
            Container(
              width: 1,
              height: 36,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            _StatTile(
              icon: Icons.check_circle,
              label: 'Equipped',
              value: '$equipped',
              color: const Color(0xFF34C759),
            ),
            Container(
              width: 1,
              height: 36,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            _StatTile(
              icon: Icons.all_inclusive,
              label: 'Permanent',
              value: '$permanent',
              color: const Color(0xFFFFB800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String type, String label) {
    final items = _itemsForTab(index);
    return Column(
      children: [
        _buildSourceFilter(type),
        Expanded(child: _buildGrid(items, type, label)),
      ],
    );
  }

  Widget _buildSourceFilter(String type) {
    final current = _currentSource(type);
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              StoreProvider.storeSources.map((s) {
                final src = sourceStyles[s['source']] ?? sourceStyles['all']!;
                final selected = s['source'] == current;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SourceFilterChip(
                    label: src.label,
                    icon: src.icon,
                    color: src.color,
                    selected: selected,
                    onSelected: (_) => _setSource(type, s['source']!),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildGrid(List<OwnedStoreItem> items, String type, String label) {
    if (items.isEmpty) {
      final style = categoryStyles[type] ?? categoryStyles['avatarFrame']!;
      final showError = _loadError != null;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      style.glow.withValues(alpha: 0.2),
                      style.glow.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: style.glow.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  showError ? Icons.error_outline : style.icon,
                  size: 40,
                  color: style.glow.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                showError ? 'Could not load' : 'No $label owned',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                showError
                    ? _loadError!
                    : 'Buy items or earn from CP, Friend, Family, VIP & Levels',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (showError)
                TextButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white70,
                    size: 18,
                  ),
                  label: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                )
              else
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: style.gradient,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: style.glow.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.pushNamed(AppRoutes.store),
                      borderRadius: BorderRadius.circular(22),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Padding(
                            padding: EdgeInsets.only(right: 20),
                            child: Text(
                              'Browse Store',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: items.length,
      itemBuilder:
          (_, i) => _OwnedItemCard(
            item: items[i],
            isToggling: _isToggling,
            onToggle: () => _toggleItem(items[i]),
          ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.5)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium owned-item card with source badge, expiry indicator, and equip
/// toggle. Equipped items get a green glow border.
class _OwnedItemCard extends StatelessWidget {
  const _OwnedItemCard({
    required this.item,
    required this.isToggling,
    required this.onToggle,
  });
  final OwnedStoreItem item;
  final bool isToggling;
  final VoidCallback onToggle;

  SourceStyle get _sourceInfo {
    if (item.source != null && sourceStyles.containsKey(item.source)) {
      return sourceStyles[item.source]!;
    }
    return const SourceStyle(
      icon: Icons.inventory_2,
      color: Color(0xFF6A5AE0),
      label: 'Owned',
    );
  }

  String _expiryLabel() {
    if (item.isPermanent) return 'Permanent';
    final exp = item.expiryDateTime;
    if (exp == null) return item.validationTag ?? '';
    final remaining = exp.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    if (remaining.inDays > 0) return '${remaining.inDays}d left';
    if (remaining.inHours > 0) return '${remaining.inHours}h left';
    return '${remaining.inMinutes}m left';
  }

  @override
  Widget build(BuildContext context) {
    final equipped = item.isSelected;
    final src = _sourceInfo;
    final expiry = _expiryLabel();
    final isExpiringSoon =
        !item.isPermanent &&
        item.expiryDateTime != null &&
        item.expiryDateTime!.difference(DateTime.now()).inDays <= 3 &&
        !item.expiryDateTime!.isBefore(DateTime.now());
    final expiryColor =
        item.isPermanent
            ? const Color(0xFF34C759)
            : (isExpiringSoon
                ? const Color(0xFFFFB800)
                : Colors.white.withValues(alpha: 0.5));

    return GestureDetector(
      onTap: isToggling ? null : onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: (equipped ? const Color(0xFF34C759) : src.color).withValues(
              alpha: equipped ? 0.6 : 0.15,
            ),
            width: equipped ? 1.5 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: (equipped ? const Color(0xFF34C759) : src.color)
                  .withValues(alpha: equipped ? 0.25 : 0.08),
              blurRadius: equipped ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            alignment: Alignment.topLeft,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.topLeft,
                      children: [
                        StoreNetworkImage(
                          url: item.thumbnail ?? item.image ?? '',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          allowAnimation: false,
                        ),
                        // Bottom gradient
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 55,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Source badge (top-left)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  src.color,
                                  src.color.withValues(alpha: 0.6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: src.color.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(src.icon, color: Colors.white, size: 10),
                                const SizedBox(width: 3),
                                Text(
                                  src.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Equipped badge (top-right)
                        if (equipped)
                          const Positioned(
                            top: 8,
                            right: 8,
                            child: PillBadge(
                              icon: Icons.check,
                              label: 'On',
                              gradient: LinearGradient(
                                colors: [Color(0xFF34C759), Color(0xFF30D158)],
                              ),
                              fontSize: 8,
                            ),
                          ),
                        // Expiry label (bottom-left, on image)
                        Positioned(
                          bottom: 6,
                          left: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.isPermanent
                                    ? Icons.all_inclusive
                                    : Icons.schedule,
                                size: 11,
                                color: expiryColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                expiry,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: expiryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name ?? 'Item',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child:
                              equipped
                                  ? OutlinedButton.icon(
                                    onPressed: isToggling ? null : onToggle,
                                    icon: const Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: Color(0xFF34C759),
                                    ),
                                    label: const Text(
                                      'Equipped',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF34C759),
                                      side: const BorderSide(
                                        color: Color(0xFF34C759),
                                        width: 1.2,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  )
                                  : Container(
                                    height: 32,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          src.color,
                                          src.color.withValues(alpha: 0.7),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: src.color.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: isToggling ? null : onToggle,
                                        borderRadius: BorderRadius.circular(10),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Equip',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
