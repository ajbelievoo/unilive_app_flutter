import 'package:flutter/foundation.dart';

import '../models/family_models.dart';
import '../services/api_service.dart';
import '../utils/log.dart';

class FamilyProvider extends ChangeNotifier {
  static const String _tag = 'FamilyProvider';

  final List<FamilyItem> _families = [];
  List<FamilyItem> get families => _families;

  FamilyItem? _myFamily;
  FamilyItem? get myFamily => _myFamily;

  FamilyItem? _familyDetail;
  FamilyItem? get familyDetail => _familyDetail;

  final List<FamilyTask> _tasks = [];
  List<FamilyTask> get tasks => _tasks;

  final List<FamilyRankItem> _ranking = [];
  List<FamilyRankItem> get ranking => _ranking;

  bool _loading = false;
  bool get loading => _loading;

  Future<void> loadFamilies({bool refresh = false}) async {
    if (_loading && !refresh) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getFamilies(userId: '', limit: 50);
      _families
        ..clear()
        ..addAll(res.data);
    } catch (e, s) {
      Log.e(_tag, 'loadFamilies failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMyFamily(String userId) async {
    try {
      final res = await ApiService.getUserFamily(userId);
      _myFamily = res.data.isNotEmpty ? res.data.first : null;
    } catch (e, s) {
      Log.e(_tag, 'loadMyFamily failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadFamilyDetail(String familyId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getFamilyDetail(familyId);
      _familyDetail = res.data.isNotEmpty ? res.data.first : null;
    } catch (e, s) {
      Log.e(_tag, 'loadFamilyDetail failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadFamilyTasks(String familyId) async {
    try {
      final res = await ApiService.getFamilyTasks(familyId);
      _tasks
        ..clear()
        ..addAll(res.tasks);
    } catch (e, s) {
      Log.e(_tag, 'loadFamilyTasks failed', e, s);
    }
    notifyListeners();
  }

  Future<void> loadFamilyRanking() async {
    try {
      final res = await ApiService.getFamilyRanking();
      _ranking
        ..clear()
        ..addAll(res.families);
    } catch (e, s) {
      Log.e(_tag, 'loadFamilyRanking failed', e, s);
    }
    notifyListeners();
  }

  Future<bool> createFamily({
    required String userId,
    required String name,
    required String description,
    bool isPublic = true,
    String joinCode = '',
    String welcomeMessage = '',
  }) async {
    try {
      final res = await ApiService.createFamily(
        userId: userId,
        name: name,
        description: description,
        isPublic: isPublic,
        joinCode: joinCode,
        welcomeMessage: welcomeMessage,
      );
      if (res.status && res.data.isNotEmpty) {
        _myFamily = res.data.first;
        notifyListeners();
        return true;
      }
    } catch (e, s) {
      Log.e(_tag, 'createFamily failed', e, s);
    }
    return false;
  }

  Future<bool> joinFamily({
    required String userId,
    required String familyId,
    String joinCode = '',
  }) async {
    try {
      final res = await ApiService.joinFamily(
        userId: userId,
        familyId: familyId,
        joinCode: joinCode,
      );
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'joinFamily failed', e, s);
      return false;
    }
  }

  Future<bool> leaveFamily(String userId, {String familyId = ''}) async {
    try {
      final res = await ApiService.leaveFamily(userId, familyId: familyId);
      if (res.status) {
        _myFamily = null;
        notifyListeners();
        return true;
      }
    } catch (e, s) {
      Log.e(_tag, 'leaveFamily failed', e, s);
    }
    return false;
  }

  Future<bool> kickMember({
    required String familyId,
    required String leaderId,
    required String memberId,
  }) async {
    try {
      final res = await ApiService.kickMember(
        familyId: familyId,
        leaderId: leaderId,
        memberId: memberId,
      );
      if (res.status && _familyDetail != null) {
        _familyDetail!.members.removeWhere((m) => m.userId == memberId);
        notifyListeners();
      }
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'kickMember failed', e, s);
    }
    return false;
  }

  Future<bool> claimTask({
    required String familyId,
    required String taskId,
  }) async {
    try {
      final res = await ApiService.claimFamilyTask(
        familyId: familyId,
        taskId: taskId,
      );
      if (res.status) {
        await loadFamilyTasks(familyId);
      }
      return res.status;
    } catch (e, s) {
      Log.e(_tag, 'claimTask failed', e, s);
    }
    return false;
  }

  Future<void> searchFamilies(String query) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.searchFamilies(query: query);
      _families
        ..clear()
        ..addAll(res.data);
    } catch (e, s) {
      Log.e(_tag, 'searchFamilies failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
