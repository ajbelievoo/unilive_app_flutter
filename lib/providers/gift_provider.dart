import 'package:flutter/foundation.dart';

import '../models/gift_models.dart';
import '../services/api_service.dart';
import '../utils/log.dart';

class GiftProvider extends ChangeNotifier {
  static const String _tag = 'GiftProvider';

  final List<GiftCategory> _categories = [];
  List<GiftCategory> get categories => _categories;

  final List<GiftItem> _gifts = [];
  List<GiftItem> get gifts => _gifts;

  final List<StickerItem> _stickers = [];
  List<StickerItem> get stickers => _stickers;

  GiftItem? _selectedGift;
  GiftItem? get selectedGift => _selectedGift;

  int _selectedCount = 1;
  int get selectedCount => _selectedCount;

  String? _selectedCategoryId;
  String? get selectedCategoryId => _selectedCategoryId;

  bool _loading = false;
  bool get loading => _loading;

  Future<void> loadGiftCategories() async {
    if (_categories.isNotEmpty) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getGiftCategories();
      _categories
        ..clear()
        ..addAll(res.category);
      if (_categories.isNotEmpty) {
        await loadGifts(_categories.first.id);
      }
    } catch (e, s) {
      Log.e(_tag, 'loadGiftCategories failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadGifts(String? categoryId) async {
    _selectedCategoryId = categoryId;
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getGifts(categoryId: categoryId);
      _gifts
        ..clear()
        ..addAll(res.gift);
    } catch (e, s) {
      Log.e(_tag, 'loadGifts failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadStickers() async {
    if (_stickers.isNotEmpty) return;
    try {
      final res = await ApiService.getStickers();
      _stickers
        ..clear()
        ..addAll(res.sticker);
    } catch (e, s) {
      Log.e(_tag, 'loadStickers failed', e, s);
    }
    notifyListeners();
  }

  void selectGift(GiftItem gift) {
    _selectedGift = gift;
    _selectedCount = 1;
    notifyListeners();
  }

  void setGiftCount(int count) {
    _selectedCount = count > 0 ? count : 1;
    notifyListeners();
  }

  void clearSelection() {
    _selectedGift = null;
    _selectedCount = 1;
    notifyListeners();
  }

  int get totalCost {
    if (_selectedGift == null) return 0;
    return _selectedGift!.coin * _selectedCount;
  }

  bool canAfford(int userCoins) => totalCost <= userCoins;
}
