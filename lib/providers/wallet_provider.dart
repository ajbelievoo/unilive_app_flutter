import 'package:flutter/foundation.dart';

import '../models/wallet_models.dart';
import '../models/redeem_request_root.dart';
import '../services/api_service.dart';
import '../utils/log.dart';

class WalletProvider extends ChangeNotifier {
  static const String _tag = 'WalletProvider';

  int _coins = 0;
  int get coins => _coins;

  int _diamonds = 0;
  int get diamonds => _diamonds;

  int _rCoins = 0;
  int get rCoins => _rCoins;

  int _spentCoins = 0;
  int get spentCoins => _spentCoins;

  int _earnCoins = 0;
  int get earnCoins => _earnCoins;

  final List<TransactionItem> _transactions = [];
  List<TransactionItem> get transactions => _transactions;

  final List<RedeemRequestItem> _redeemHistory = [];
  List<RedeemRequestItem> get redeemHistory => _redeemHistory;

  bool _loading = false;
  bool get loading => _loading;

  void updateFromUser({
    required int coins,
    required int diamonds,
    required int rCoins,
    int spentCoins = 0,
    int earnCoins = 0,
  }) {
    _coins = coins;
    _diamonds = diamonds;
    _rCoins = rCoins;
    _spentCoins = spentCoins;
    _earnCoins = earnCoins;
    notifyListeners();
  }

  Future<void> loadTransactions(String userId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getTransactionHistory(userId);
      _transactions
        ..clear()
        ..addAll(res.history);
    } catch (e, s) {
      Log.e(_tag, 'loadTransactions failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadRedeemHistory(String userId) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getRedeemHistory(userId: userId, limit: 50);
      _redeemHistory
        ..clear()
        ..addAll(res.redeem);
    } catch (e, s) {
      Log.e(_tag, 'loadRedeemHistory failed', e, s);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> submitRedeem({
    required String userId,
    required int coin,
    required String paymentMethod,
    required String paymentMethodId,
    required Map<String, dynamic> accountDetails,
  }) async {
    try {
      final res = await ApiService.submitRedeem(
        userId: userId,
        coin: coin,
        paymentMethod: paymentMethod,
        paymentMethodId: paymentMethodId,
        accountDetails: accountDetails,
      );
      if (res.status) {
        await loadRedeemHistory(userId);
        return true;
      }
      return false;
    } catch (e, s) {
      Log.e(_tag, 'submitRedeem failed', e, s);
      return false;
    }
  }

  Future<bool> convertRcoinToDiamond({
    required String userId,
    required int rCoin,
  }) async {
    try {
      final res = await ApiService.convertRcoinToDiamond(
        userId: userId,
        rCoin: rCoin,
      );
      if (res.status) {
        _rCoins -= rCoin;
        _diamonds += rCoin;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e, s) {
      Log.e(_tag, 'convertRcoinToDiamond failed', e, s);
      return false;
    }
  }

  void addCoins(int amount) {
    _coins += amount;
    notifyListeners();
  }

  void deductCoins(int amount) {
    _coins -= amount;
    if (_coins < 0) _coins = 0;
    notifyListeners();
  }

  void addDiamonds(int amount) {
    _diamonds += amount;
    notifyListeners();
  }

  void deductDiamonds(int amount) {
    _diamonds -= amount;
    if (_diamonds < 0) _diamonds = 0;
    notifyListeners();
  }
}
