import 'package:flutter/foundation.dart';

import '../models/vip_models.dart';
import '../models/vip_history_models.dart';
import '../models/vip_extended_models.dart';
import '../models/user_root.dart';
import '../services/api_service.dart';
import '../utils/log.dart';

class VipProvider extends ChangeNotifier {
  static const String _tag = 'VipProvider';

  final List<VipPlanItem> _plans = [];
  List<VipPlanItem> get plans => _plans;

  final List<VipTier> _tiers = [];
  List<VipTier> get tiers => _tiers;

  final List<VipPointsHistoryItem> _pointsHistory = [];
  List<VipPointsHistoryItem> get pointsHistory => _pointsHistory;

  final List<VipPurchaseRecord> _purchaseRecords = [];
  List<VipPurchaseRecord> get purchaseRecords => _purchaseRecords;

  VipStatus? _vipStatusObj;
  VipStatus? get vipStatusObj => _vipStatusObj;

  Map<String, dynamic>? _vipDetails;
  Map<String, dynamic>? get vipDetails => _vipDetails;

  final Map<String, int> _rulesMinPoints = {};
  Map<String, int> get rulesMinPoints => _rulesMinPoints;

  final Map<String, int> _rulesBonusPoints = {};
  Map<String, int> get rulesBonusPoints => _rulesBonusPoints;

  String? _lastUserId;
  bool _loading = false;
  bool get loading => _loading;

  Future<void> init(String userId) async {
    if (_lastUserId == userId && _tiers.isNotEmpty) return;
    _lastUserId = userId;
    await refreshAll(userId);
  }

  Future<void> refreshAll(String userId) async {
    _loading = true;
    notifyListeners();
    try {
      await Future.wait([
        loadTiers(force: true),
        loadVipStatus(userId),
        loadVipRules(),
      ]);
    } catch (e) {
      Log.e(_tag, 'refreshAll failed', e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadTiers({bool force = false}) async {
    if (_tiers.isNotEmpty && !force) return;
    try {
      final res = await ApiService.getVipTiers();
      if (res.status) {
        _tiers.clear();
        _tiers.addAll(res.data);
        _tiers.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      }
    } catch (e, s) {
      Log.e(_tag, 'loadTiers failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadVipStatus(String userId) async {
    if (userId.isEmpty) return;
    try {
      final res = await ApiService.getVipStatus(userId);
      final data = res['data'] as Map<String, dynamic>?;
      final statusObj = data?['vipStatus'] as Map<String, dynamic>? ?? data;
      if (statusObj != null) {
        _vipStatusObj = VipStatus.fromJson(statusObj);
      }
    } catch (e, s) {
      Log.e(_tag, 'loadVipStatus failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadVipRules() async {
    try {
      final rules = await ApiService.getVipRules();
      final levels = rules['levels'] as List?;
      if (levels != null) {
        _rulesMinPoints.clear();
        for (int i = 0; i < levels.length; i++) {
          final lvl = levels[i] as Map<String, dynamic>;
          final level = (lvl['level'] as String?) ?? (lvl['name'] as String?) ?? 'VIP${i + 1}';
          final minPoints = (lvl['minPoints'] as num?)?.toInt() ?? 0;
          _rulesMinPoints[level.toUpperCase()] = minPoints;
        }
      }
      final bonuses = rules['bonusPoints'] as List?;
      if (bonuses != null) {
        _rulesBonusPoints.clear();
        for (int i = 0; i < bonuses.length; i++) {
          final b = bonuses[i] as Map<String, dynamic>;
          final level = (b['level'] as String?) ?? (b['name'] as String?) ?? 'VIP${i + 1}';
          final bonus = (b['bonusPoints'] as num?)?.toInt() ?? 0;
          _rulesBonusPoints[level.toUpperCase()] = bonus;
        }
      }
    } catch (e, s) {
      Log.e(_tag, 'loadVipRules failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadVipDetails(String userId) async {
    try {
      _vipDetails = await ApiService.getVipDetails(userId);
    } catch (e, s) {
      Log.e(_tag, 'loadVipDetails failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadPointsHistory(String userId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getVipPointsHistory(userId);
      _pointsHistory
        ..clear()
        ..addAll(res.data);
    } catch (e, s) {
      Log.e(_tag, 'loadPointsHistory failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadPurchaseRecords(String userId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getVipPurchaseRecords(userId);
      _purchaseRecords
        ..clear()
        ..addAll(res.data);
    } catch (e, s) {
      Log.e(_tag, 'loadPurchaseRecords failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> purchaseVip({
    required String userId,
    required String planId,
    required String paymentType,
    String? receipt,
  }) async {
    try {
      final res = await ApiService.purchaseVip(
        userId: userId,
        planId: planId,
        paymentType: paymentType,
        receipt: receipt,
      );
      if (res.status) {
        await loadVipStatus(userId);
        return true;
      }
    } catch (e, s) {
      Log.e(_tag, 'purchaseVip failed', e, s);
    }
    return false;
  }

  /// Buys a VIP tier. Returns `(success, message, celebration)` so the UI can
  /// surface the backend's failure reason and drive the level-up celebration
  /// overlay with backend-provided asset URLs + tier color.
  /// On success it refreshes both the VIP status and the user's coin balance
  /// (diamonds were deducted by the purchase).
  Future<(bool success, String? message, VipCelebration? celebration)> buyVipTier({
    required String userId,
    required String tierId,
    int? clientCoinBalance,
    int? clientDiamondBalance,
  }) async {
    try {
      final res = await ApiService.buyVipTier(
        userId: userId,
        tierId: tierId,
        clientCoinBalance: clientCoinBalance,
        clientDiamondBalance: clientDiamondBalance,
      );
      if (res.status) {
        await loadVipStatus(userId);
        final celeb = VipCelebration.fromResponse(res.data);
        return (true, res.message, celeb);
      }
      return (false, res.message, null);
    } catch (e, s) {
      Log.e(_tag, 'buyVipTier failed', e, s);
      return (false, 'Network error: $e', null);
    }
  }

  Future<bool> updateVipSetting({
    required String userId,
    required String settingKey,
    required bool value,
  }) async {
    try {
      final res = await ApiService.updateVipSetting(
        userId: userId,
        settingKey: settingKey,
        value: value,
      );
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'updateVipSetting failed', e, s);
      return false;
    }
  }

  void reset() {
    _tiers.clear();
    _vipStatusObj = null;
    _vipDetails = null;
    _pointsHistory.clear();
    _purchaseRecords.clear();
    _rulesMinPoints.clear();
    _rulesBonusPoints.clear();
    _lastUserId = null;
    notifyListeners();
  }
}
