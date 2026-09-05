import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/api_service.dart';
import '../utils/log.dart';

/// In-App Purchase service using Google Play billing.
///
/// Ported from native `BillingClient` setup in `MainActivity.java`.
/// Handles:
/// - Querying available products from Google Play
/// - Initiating purchases
/// - Verifying purchases with backend
/// - Restoring purchases
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  static const String _tag = 'IapService';
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final Map<String, ProductDetails> _products = {};

  /// Callback invoked after a successful purchase + backend verification.
  /// Returns the backend response message.
  void Function(bool success, String? message)? onPurchaseResult;

  /// Whether the billing service is available.
  bool _available = false;
  bool get isAvailable => _available;

  /// Initialize the IAP service and listen to purchase updates.
  Future<void> init() async {
    _available = await _iap.isAvailable();
    if (!_available) {
      Log.w(_tag, 'In-app purchase not available');
      return;
    }

    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (e) => Log.e(_tag, 'purchaseStream error', e),
    );
    Log.i(_tag, 'IAP service initialized');
  }

  /// Load product details from Google Play for the given product IDs.
  Future<List<ProductDetails>> loadProducts(Set<String> productIds) async {
    if (!_available) return [];

    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      Log.e(_tag, 'queryProductDetails error: ${response.error}');
      return [];
    }

    _products.clear();
    for (final p in response.productDetails) {
      _products[p.id] = p;
    }
    Log.i(_tag, 'Loaded ${_products.length} products');
    return response.productDetails;
  }

  /// Initiate a purchase for the given product ID.
  /// The result will be delivered via [onPurchaseResult].
  Future<bool> purchase(String productId, {String? userId, String? planId, String type = 'coin'}) async {
    if (!_available) {
      onPurchaseResult?.call(false, 'In-app purchase not available');
      return false;
    }

    if (userId != null) _currentUserId = userId;
    _currentPlanId = planId;

    final product = _products[productId];
    if (product == null) {
      onPurchaseResult?.call(false, 'Product not found: $productId');
      return false;
    }

    final param = PurchaseParam(productDetails: product);
    final ok = await _iap.buyConsumable(purchaseParam: param);
    if (!ok) {
      Log.w(_tag, 'purchase() returned false for $productId');
    }
    return ok;
  }

  /// Restore previous purchases.
  Future<void> restorePurchases() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    Log.i(_tag, 'Purchase updated: ${purchase.productID}, status=${purchase.status}');

    switch (purchase.status) {
      case PurchaseStatus.restored:
      case PurchaseStatus.purchased:
        // Verify with backend
        await _verifyWithBackend(purchase);
        break;
      case PurchaseStatus.error:
        Log.e(_tag, 'Purchase error: ${purchase.error}');
        onPurchaseResult?.call(false, purchase.error?.message ?? 'Purchase failed');
        break;
      case PurchaseStatus.canceled:
        onPurchaseResult?.call(false, 'Purchase cancelled');
        break;
      case PurchaseStatus.pending:
        Log.i(_tag, 'Purchase pending');
        break;
    }

    // Always complete the purchase on the Google Play side
    if (purchase.pendingCompletePurchase) {
      try {
        await _iap.completePurchase(purchase);
        Log.i(_tag, 'Purchase completed: ${purchase.productID}');
      } catch (e) {
        Log.e(_tag, 'completePurchase failed', e);
      }
    }
  }

  Future<void> _verifyWithBackend(PurchaseDetails purchase) async {
    try {
      final purchaseToken = purchase.verificationData.serverVerificationData;
      final productId = purchase.productID;
      final planId = _currentPlanId ?? productId;

      final res = await ApiService.purchaseWithGooglePlay(
        userId: _currentUserId ?? '',
        planId: planId,
        purchaseToken: purchaseToken,
        productId: productId,
      );

      if (res.status) {
        onPurchaseResult?.call(true, res.message ?? 'Purchase successful!');
      } else {
        onPurchaseResult?.call(false, res.message ?? 'Verification failed');
      }
    } catch (e, s) {
      Log.e(_tag, 'Backend verification failed', e, s);
      onPurchaseResult?.call(false, 'Verification failed: $e');
    }
  }

  String? _currentUserId;
  String? _currentPlanId;

  void setUserId(String userId) => _currentUserId = userId;

  void dispose() {
    _purchaseSub?.cancel();
    _purchaseSub = null;
  }
}
