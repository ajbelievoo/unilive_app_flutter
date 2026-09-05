import 'package:flutter/foundation.dart';

import '../constants/const.dart';
import '../models/store_models.dart';
import '../models/user_root.dart';
import '../services/api_service.dart';
import '../utils/log.dart';

class StoreProvider extends ChangeNotifier {
  static const String _tag = 'StoreProvider';

  final List<StoreItem> _items = [];
  List<StoreItem> get items => _items;

  final List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> get categories => _categories;

  String? _selectedCategory;
  String? get selectedCategory => _selectedCategory;

  bool _loading = false;
  bool get loading => _loading;

  /// The user's full inventory (bought + CP/Friend/Family/VIP rewards).
  final List<OwnedStoreItem> _myItems = [];
  List<OwnedStoreItem> get myItems => _myItems;

  bool _myItemsLoading = false;
  bool get myItemsLoading => _myItemsLoading;

  String? _myItemsError;
  String? get myItemsError => _myItemsError;

  final Set<String> _equippedIds = {};
  Set<String> get equippedIds => _equippedIds;

  /// All store item categories shown as tabs in the Store and My Store.
  static const List<Map<String, String>> storeCategories = [
    {'type': Const.avatarFrame, 'label': 'Avatar Frame'},
    {'type': Const.chatBubble, 'label': 'Chat Bubble'},
    {'type': Const.roomCard, 'label': 'Room Card'},
    {'type': Const.micWave, 'label': 'Mic Wave'},
    {'type': Const.roomTheme, 'label': 'Room Theme'},
    {'type': Const.entryEffect, 'label': 'Entry Effect'},
    {'type': Const.entrance, 'label': 'Entrance'},
    {'type': Const.badge, 'label': 'Badge'},
  ];

  /// All ownership sources shown as the My Store subcategory filter.
  /// Matches the backend spec: buy | cp | friend | family | vip | reward | admin.
  static const List<Map<String, String>> storeSources = [
    {'source': 'all', 'label': 'All'},
    {'source': Const.sourceBuy, 'label': 'Buy'},
    {'source': Const.sourceCp, 'label': 'CP'},
    {'source': Const.sourceFriend, 'label': 'Friend'},
    {'source': Const.sourceFamily, 'label': 'Family'},
    {'source': Const.sourceVip, 'label': 'VIP'},
    {'source': Const.sourceReward, 'label': 'Reward'},
    {'source': Const.sourceAdmin, 'label': 'Admin'},
  ];

  Future<void> loadStoreItems({String? type, String? userId}) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getStoreItems(type: type, userId: userId);
      _items
        ..clear()
        ..addAll(res.data);
    } catch (e, s) {
      Log.e(_tag, 'loadStoreItems failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategories() async {
    try {
      final res = await ApiService.getStoreCategories();
      final cats = res['categories'] as List? ?? [];
      _categories
        ..clear()
        ..addAll(cats.cast<Map<String, dynamic>>());
    } catch (e, s) {
      Log.e(_tag, 'loadCategories failed', e, s);
    }
    notifyListeners();
  }

  void selectCategory(String? categoryId) {
    _selectedCategory = categoryId;
    notifyListeners();
  }

  /// Loads the user's full inventory from `/store/my`. Expired items are
  /// filtered out client-side as well (in case the backend still returns them).
  Future<void> loadMyItems({required String userId}) async {
    _myItemsLoading = true;
    _myItemsError = null;
    notifyListeners();
    try {
      Log.d(_tag, 'loadMyItems: calling /store/my userId=$userId');
      final res = await ApiService.getMyStoreItems(userId: userId);
      Log.d(
        _tag,
        'loadMyItems: backend returned status=${res.status} count=${res.data.length}',
      );
      if (!res.status) {
        _myItems.clear();
        _myItemsError = res.message ?? 'Store inventory request failed';
        return;
      }
      final now = DateTime.now();
      final filtered =
          res.data.where((item) {
            if (item.isExpired) return false;
            final exp = item.expiryDateTime;
            return exp == null || exp.isAfter(now);
          }).toList();
      Log.d(_tag, 'loadMyItems: after expiry filter count=${filtered.length}');
      _myItems
        ..clear()
        ..addAll(filtered);
    } catch (e, s) {
      _myItems.clear();
      _myItemsError = 'Could not load inventory';
      Log.e(_tag, 'loadMyItems failed', e, s);
    } finally {
      _myItemsLoading = false;
      notifyListeners();
    }
  }

  /// Owned items for a given category tab, optionally filtered by source.
  List<OwnedStoreItem> myItemsByCategory(String type, {String? source}) {
    return _myItems.where((i) {
      if (i.type != type) return false;
      if (source == null || source == 'all') return true;
      return i.source == source;
    }).toList();
  }

  Future<User?> purchaseItem({
    required String userId,
    required String itemId,
    required String type,
  }) async {
    try {
      final res = await ApiService.purchaseStoreItem(
        userId: userId,
        itemId: itemId,
        type: type,
      );
      if (res.status && res.user != null) {
        return res.user;
      }
    } catch (e, s) {
      Log.e(_tag, 'purchaseItem failed', e, s);
    }
    return null;
  }

  Future<User?> selectItem({
    required String id,
    required String userId,
    required String type,
  }) async {
    try {
      final res = await ApiService.selectStoreItem(
        id: id,
        userId: userId,
        type: type,
      );
      if (res.status && res.user != null) {
        _equippedIds.add(id);
        // Mark only this item equipped within its type.
        for (final e in _myItems) {
          if (e.type == type) e.isSelected = (e.id == id);
        }
        notifyListeners();
        return res.user;
      }
    } catch (e, s) {
      Log.e(_tag, 'selectItem failed', e, s);
    }
    return null;
  }

  Future<User?> deselectItem({
    required String id,
    required String userId,
    required String type,
  }) async {
    try {
      final res = await ApiService.deselectStoreItem(
        id: id,
        userId: userId,
        type: type,
      );
      if (res.status && res.user != null) {
        _equippedIds.remove(id);
        for (final e in _myItems) {
          if (e.id == id) e.isSelected = false;
        }
        notifyListeners();
        return res.user;
      }
    } catch (e, s) {
      Log.e(_tag, 'deselectItem failed', e, s);
    }
    return null;
  }

  List<StoreItem> itemsByCategory(String? categoryId) {
    if (categoryId == null) return _items;
    return _items.where((i) => i.type == categoryId).toList();
  }
}
