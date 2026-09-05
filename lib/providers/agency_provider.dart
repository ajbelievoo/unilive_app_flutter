import 'package:flutter/foundation.dart';

import '../models/agency_models.dart';
import '../services/api_service.dart';
import '../utils/log.dart';

class AgencyProvider extends ChangeNotifier {
  static const String _tag = 'AgencyProvider';

  final List<Agency> _agencies = [];
  List<Agency> get agencies => _agencies;

  Agency? _myAgency;
  Agency? get myAgency => _myAgency;

  final List<Map<String, dynamic>> _hosts = [];
  List<Map<String, dynamic>> get hosts => _hosts;

  Map<String, dynamic>? _revenue;
  Map<String, dynamic>? get revenue => _revenue;

  final List<Map<String, dynamic>> _withdrawals = [];
  List<Map<String, dynamic>> get withdrawals => _withdrawals;

  bool _loading = false;
  bool get loading => _loading;

  Future<void> loadAgencies({bool refresh = false}) async {
    if (_loading && !refresh) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getAgencies(limit: 50);
      _agencies
        ..clear()
        ..addAll(res.agencies);
    } catch (e, s) {
      Log.e(_tag, 'loadAgencies failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMyAgency(String userId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getMyAgency(userId);
      _myAgency = res.agency;
    } catch (e, s) {
      Log.e(_tag, 'loadMyAgency failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadAgencyHosts(String agencyId) async {
    try {
      final res = await ApiService.getAgencyHosts(agencyId: agencyId, limit: 50);
      final hostsList = res['hosts'] as List? ?? [];
      _hosts
        ..clear()
        ..addAll(hostsList.cast<Map<String, dynamic>>());
    } catch (e, s) {
      Log.e(_tag, 'loadAgencyHosts failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadRevenue(String agencyId, {String period = 'monthly'}) async {
    try {
      _revenue = await ApiService.getAgencyRevenue(agencyId: agencyId, period: period);
    } catch (e, s) {
      Log.e(_tag, 'loadRevenue failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadWithdrawals(String agencyId) async {
    try {
      final res = await ApiService.getAgencyWithdrawals(agencyId: agencyId, limit: 50);
      final list = res['withdrawals'] as List? ?? [];
      _withdrawals
        ..clear()
        ..addAll(list.cast<Map<String, dynamic>>());
    } catch (e, s) {
      Log.e(_tag, 'loadWithdrawals failed', e, s);
    }
    notifyListeners();
  }

  Future<bool> createAgency({
    required String userId,
    required String name,
    required String description,
  }) async {
    try {
      final res = await ApiService.createAgency(
        userId: userId,
        name: name,
        description: description,
      );
      if (res.status) {
        _myAgency = res.agency;
        notifyListeners();
        return true;
      }
    } catch (e, s) {
      Log.e(_tag, 'createAgency failed', e, s);
    }
    return false;
  }

  Future<bool> joinAgency({
    required String userId,
    required String agencyId,
  }) async {
    try {
      final res = await ApiService.joinAgency(userId: userId, agencyId: agencyId);
      if (res.status) {
        await loadMyAgency(userId);
        return true;
      }
    } catch (e, s) {
      Log.e(_tag, 'joinAgency failed', e, s);
    }
    return false;
  }

  Future<bool> leaveAgency(String userId) async {
    try {
      final res = await ApiService.leaveAgency(userId);
      if (res.status) {
        _myAgency = null;
        notifyListeners();
        return true;
      }
    } catch (e, s) {
      Log.e(_tag, 'leaveAgency failed', e, s);
    }
    return false;
  }

  Future<bool> requestWithdrawal({
    required String agencyId,
    required int amount,
    required String paymentMethod,
    String? accountDetails,
  }) async {
    try {
      final res = await ApiService.requestAgencyWithdrawal(
        agencyId: agencyId,
        amount: amount,
        paymentMethod: paymentMethod,
        accountDetails: accountDetails,
      );
      if (res.status) {
        await loadWithdrawals(agencyId);
        return true;
      }
    } catch (e, s) {
      Log.e(_tag, 'requestWithdrawal failed', e, s);
    }
    return false;
  }
}
