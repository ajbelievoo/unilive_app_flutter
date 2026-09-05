import 'package:flutter/foundation.dart';

import '../models/call_rate_model.dart';
import '../services/api_service.dart';
import '../utils/log.dart';

class CallRateProvider extends ChangeNotifier {
  static const String _tag = 'CallRateProvider';

  List<CallRateLevel> _levels = [];
  List<CallRateLevel> get levels => _levels;

  HostCallRate? _hostRate;
  HostCallRate? get hostRate => _hostRate;

  bool _loading = false;
  bool get loading => _loading;

  bool _updating = false;
  bool get updating => _updating;

  String? _error;
  String? get error => _error;

  /// Load the global level-to-rate config.
  Future<void> loadConfig() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.getCallRateConfig();
      _levels = res.levels;
    } catch (e, s) {
      Log.e(_tag, 'loadConfig failed', e, s);
      _error = 'Failed to load rate config';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Load the host's current call rate info.
  Future<void> loadHostRate(String userId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _hostRate = await ApiService.getHostCallRate(userId);
    } catch (e, s) {
      Log.e(_tag, 'loadHostRate failed', e, s);
      _error = 'Failed to load host rate';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Set a custom call rate for the host.
  Future<bool> setRate(String userId, int rate) async {
    _updating = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.setCallRate(userId: userId, rate: rate);
      if (res.status && res.data != null) {
        _hostRate = res.data;
        notifyListeners();
        return true;
      }
      _error = res.message ?? 'Failed to set rate';
      return false;
    } catch (e, s) {
      Log.e(_tag, 'setRate failed', e, s);
      _error = 'Failed to set rate';
      return false;
    } finally {
      _updating = false;
      notifyListeners();
    }
  }

  /// Reset the host's call rate to their level default.
  Future<bool> resetRate(String userId) async {
    _updating = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.resetCallRate(userId);
      if (res.status && res.data != null) {
        _hostRate = res.data;
        notifyListeners();
        return true;
      }
      _error = res.message ?? 'Failed to reset rate';
      return false;
    } catch (e, s) {
      Log.e(_tag, 'resetRate failed', e, s);
      _error = 'Failed to reset rate';
      return false;
    } finally {
      _updating = false;
      notifyListeners();
    }
  }

  /// Convenience: get the effective rate for the current host.
  int get effectiveRate => _hostRate?.effectiveRate ?? 0;

  /// Convenience: available rates the host can choose from.
  List<int> get availableRates => _hostRate?.availableRates ?? [];
}
