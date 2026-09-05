import 'package:flutter/foundation.dart';

import '../models/leaderboard_complain_models.dart';
import '../services/api_service.dart';
import '../utils/log.dart';

class LeaderboardProvider extends ChangeNotifier {
  static const String _tag = 'LeaderboardProvider';

  // Cache: Map<type, Map<period, List<LeaderboardEntry>>>
  final Map<String, Map<String, List<LeaderboardEntry>>> _cache = {};
  
  // Per-category loading states
  final Map<String, bool> _loadingStates = {};
  
  // Per-category error states
  final Map<String, String?> _errorStates = {};

  String _type = 'user';
  String get type => _type;

  String _period = 'daily';
  String get period => _period;

  bool get loading => _loadingStates['$_type-$_period'] ?? false;
  String? get error => _errorStates['$_type-$_period'];

  List<LeaderboardEntry> getRankings(String type, String period) {
    return _cache[type]?[period] ?? [];
  }

  bool isLoading(String type, String period) {
    return _loadingStates['$type-$period'] ?? false;
  }

  String? getError(String type, String period) {
    return _errorStates['$type-$period'];
  }

  Future<void> load({
    required String userId,
    String type = 'user',
    String period = 'daily',
    bool force = false,
  }) async {
    final cacheKey = '$type-$period';
    
    // Skip if already loading
    if (_loadingStates[cacheKey] == true) return;
    
    // Skip if already cached and not forced
    if (!force && _cache[type]?[period] != null && _cache[type]![period]!.isNotEmpty) {
      // Still update _type and _period to reflect current UI intent
      _type = type;
      _period = period;
      notifyListeners();
      return;
    }

    _type = type;
    _period = period;
    _loadingStates[cacheKey] = true;
    _errorStates[cacheKey] = null;
    notifyListeners();

    try {
      final res = await ApiService.getLeaderboard(
        type: type,
        userId: userId,
        period: period,
        limit: 50,
      );
      
      final root = LeaderboardRoot.fromJson(res);
      final list = root.leaderboard;

      _cache.putIfAbsent(type, () => {});
      _cache[type]![period] = list;
    } catch (e, s) {
      Log.e(_tag, 'load failed for $cacheKey', e, s);
      _errorStates[cacheKey] = e.toString();
    } finally {
      _loadingStates[cacheKey] = false;
      notifyListeners();
    }
  }

  void setType(String type) {
    if (_type == type) return;
    _type = type;
    notifyListeners();
  }

  void setPeriod(String period) {
    if (_period == period) return;
    _period = period;
    notifyListeners();
  }

  void clearCache() {
    _cache.clear();
    _loadingStates.clear();
    notifyListeners();
  }
}
