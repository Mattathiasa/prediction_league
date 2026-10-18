import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionService extends ChangeNotifier {
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  final Set<String> _purchased = {};
  bool _loading = false;
  String? _error;
  bool _isPremium = false;

  List<ProductDetails> get products => _products;
  bool get loading => _loading;
  String? get error => _error;
  bool get isPremium => _isPremium;
  Set<String> get purchased => _purchased;

  static const _kPremiumId = 'premium_monthly';
  static const _kNoAdsId = 'remove_ads';

  static const _kProductIds = {_kPremiumId, _kNoAdsId};

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _pending = false;

  /// A purchase is awaiting confirmation from a slow payment method.
  bool get pending => _pending;

  Future<void> init(String? userId) async {
    // Cancel any existing subscription to prevent memory leaks
    await _subscription?.cancel();
    _subscription = null;

    if (userId == null) {
      _isPremium = false;
      notifyListeners();
      return;
    }

    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      _error = 'Store not available on this device';
      notifyListeners();
      return;
    }

    final ProductDetailsResponse response =
        await InAppPurchase.instance.queryProductDetails(_kProductIds);

    if (response.error != null) {
      _error = response.error.toString();
      notifyListeners();
      return;
    }

    _products = response.productDetails;

    _subscription = InAppPurchase.instance.purchaseStream.listen(
      (purchases) => unawaited(_onPurchasesUpdated(purchases, userId)),
      onError: (Object e) {
        _error = e.toString();
        notifyListeners();
      },
    );

    await _loadPremiumFromFirestore(userId);
    // Restore to sync with the store on every app start.
    await restorePurchases(userId: userId);
  }

  Future<void> _loadPremiumFromFirestore(String userId) async {
    try {
      final snap = await _db.collection('users').doc(userId).get();
      _isPremium = snap.data()?['isPremium'] as bool? ?? false;
      notifyListeners();
    } catch (e) {
      // Offline — fall back to false
    }
  }

  // There is no setPremium Cloud Function on the Spark plan, so the client
  // grants itself premium directly. firestore.rules only allows this
  // transition false → true and nothing else in the same write — the same
  // "only ever grants, never revokes" invariant the callable used to
  // enforce — and there is still no receipt verification or expiry; see
  // README's known gaps.
  Future<void> _savePremiumToFirestore(String userId) async {
    // Already granted — restorePurchases re-fires on every launch, and the
    // rule only allows the false → true transition, so a repeat write here
    // would be denied every time rather than being the harmless no-op it
    // should be.
    if (_isPremium) return;

    try {
      final batch = _db.batch();
      batch.update(_db.collection('users').doc(userId), {'isPremium': true});
      batch.update(
        _db.collection('publicProfiles').doc(userId),
        {'isPremium': true},
      );
      await batch.commit();
    } catch (e) {
      // The grant did not land. Previously _isPremium was set regardless of
      // whether this threw, so cancelling a purchase offline handed out
      // premium for free. Surface it and leave entitlement unchanged.
      _error = 'Could not confirm your purchase. It will retry on next launch.';
      notifyListeners();
      return;
    }
    _isPremium = true;
    notifyListeners();
  }

  Future<void> buy(ProductDetails product, String userId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _onPurchasesUpdated(
    List<PurchaseDetails> purchases,
    String userId,
  ) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Slow payment methods (bank transfer, cash) sit here for hours.
          // Previously this fell through and the purchase silently vanished.
          _pending = true;
          _error = null;
          notifyListeners();

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _pending = false;
          _purchased.add(purchase.productID);
          await _savePremiumToFirestore(userId);

        case PurchaseStatus.error:
          _pending = false;
          _error = _friendlyPurchaseError(purchase.error);
          notifyListeners();

        case PurchaseStatus.canceled:
          _pending = false;
          _error = null;
          notifyListeners();
      }

      // Must happen for every terminal status or the store replays the
      // purchase on every launch.
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  /// Store errors are not user-facing copy; previously `error.toString()` was
  /// rendered directly as the paywall's subtitle.
  String _friendlyPurchaseError(IAPError? error) {
    if (error == null) return 'Your purchase could not be completed.';
    return 'Your purchase could not be completed (${error.code}).';
  }

  Future<void> restorePurchases({String? userId}) async {
    if (userId == null) return;

    try {
      await InAppPurchase.instance.restorePurchases();
      // After restore, the purchaseStream listener will fire with purchased
      // items and _onPurchasesUpdated will update Firestore.
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  void reset() {
    _isPremium = false;
    _purchased.clear();
    _loading = false;
    _error = null;
    _products = [];
    notifyListeners();
  }
}
