/// SVGA effects store — browse, purchase, equip/unequip SVGA animations.
///
/// Ports native `SvgaListFragment.java`. Shows entrance, gift, and frame
/// SVGA effects in a tabbed grid. Users can purchase with diamonds and
/// equip/unequip owned effects.
library svga_store;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../models/missing_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../widgets/store_widgets.dart';
import 'package:belive/widgets/preloader.dart';

class SvgaStoreScreen extends StatefulWidget {
  const SvgaStoreScreen({super.key, this.initialType = 'all'});

  final String initialType;

  @override
  State<SvgaStoreScreen> createState() => _SvgaStoreScreenState();
}

class _SvgaStoreScreenState extends State<SvgaStoreScreen>
    with SingleTickerProviderStateMixin {
  static const String _tag = 'SvgaStore';
  late final TabController _tab;
  final _types = ['all', 'entrance', 'gift', 'frame'];
  final _labels = ['All', 'Entrance', 'Gift', 'Frame'];
  final Map<String, List<SvgaItem>> _itemsByType = {};
  final Map<String, bool> _loadingByType = {};
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    final initialIndex = _types.indexOf(widget.initialType);
    _tab = TabController(
      length: _types.length,
      vsync: this,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
    );
    _tab.addListener(() {
      if (!_tab.indexIsChanging) _loadType(_types[_tab.index]);
    });
    _loadType('all');
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadType(String type) async {
    if (_loadingByType[type] == true) return;
    setState(() => _loadingByType[type] = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.getSvgaList(
        userId: session.userId,
        type: type,
      );
      if (mounted) {
        setState(() {
          _itemsByType[type] = res.data;
          if (_initialLoading) _initialLoading = false;
        });
      }
    } catch (e, s) {
      Log.e(_tag, 'loadType($type) failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingByType[type] = false);
    }
  }

  Future<void> _purchaseSvga(SvgaItem item, String type) async {
    final session = context.read<SessionManager>();
    try {
      final res = await ApiService.purchaseSvga(
        type: type,
        svgaId: item.id ?? '',
        userId: session.userId,
      );
      if (res.status && res.user != null) {
        session.saveUser(res.user);
        Fluttertoast.showToast(msg: 'Purchased ${item.name ?? 'effect'}!');
        _loadType(type);
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Purchase failed');
      }
    } catch (e) {
      Log.e(_tag, 'purchaseSvga failed', e);
      Fluttertoast.showToast(msg: 'Purchase failed');
    }
  }

  Future<void> _toggleSelectSvga(SvgaItem item, String type) async {
    final session = context.read<SessionManager>();
    try {
      final res =
          item.isSelected
              ? await ApiService.deselectSvga(
                type: type,
                svgaId: item.id ?? '',
                userId: session.userId,
              )
              : await ApiService.selectSvga(
                type: type,
                svgaId: item.id ?? '',
                userId: session.userId,
              );
      if (res.status && res.user != null) {
        session.saveUser(res.user);
        Fluttertoast.showToast(
          msg: item.isSelected ? 'Unequipped' : 'Equipped',
        );
        _loadType(type);
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed');
      }
    } catch (e) {
      Log.e(_tag, 'toggleSelectSvga failed', e);
      Fluttertoast.showToast(msg: 'Failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SVGA Effects'),
        bottom: TabBar(
          controller: _tab,
          tabs: _labels.map((l) => Tab(text: l)).toList(),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppTheme.primary,
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: _types.map((t) => _buildGrid(t)).toList(),
      ),
    );
  }

  Widget _buildGrid(String type) {
    final items = _itemsByType[type] ?? [];
    final loading = _loadingByType[type] == true;
    if (loading && items.isEmpty) {
      return const Center(child: Preloader());
    }
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.animation, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No ${_labels[_types.indexOf(type)]} effects',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _buildSvgaCard(items[i], type),
    );
  }

  Widget _buildSvgaCard(SvgaItem item, String type) {
    final thumb = item.thumbnail ?? item.image;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.topLeft,
              fit: StackFit.expand,
              children: [
                if (thumb != null && thumb.isNotEmpty)
                  StoreNetworkImage(
                    url: thumb,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    allowAnimation: false,
                  )
                else
                  Container(
                    color: Colors.grey.shade200,
                    child: const Icon(
                      Icons.animation,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                if (item.isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Equipped',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name ?? 'Effect',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.diamond, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${item.diamond}',
                      style: const TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                    const Spacer(),
                    if (item.isPurchase)
                      IconButton(
                        icon: Icon(
                          item.isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 20,
                        ),
                        color: item.isSelected ? Colors.green : Colors.grey,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _toggleSelectSvga(item, type),
                      )
                    else
                      TextButton(
                        onPressed: () => _purchaseSvga(item, type),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('Buy'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
