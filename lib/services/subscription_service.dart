import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> init(String? userId) async {
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
      (purchases) => _onPurchasesUpdated(purchases, userId),
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );

    await _loadPremiumFromFirestore(userId);
    // Restore to sync with app store on every app start
    restorePurchases(userId: userId);
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

  Future<void> _savePremiumToFirestore(String userId) async {
    try {
      // setPremium uses context.auth.uid server-side — userId param
      // is for the current authenticated user only
      await FirebaseFunctions.instance.httpsCallable('setPremium')();
    } catch (e) {
      // Cloud Function call failed (offline or rules) — cache in memory only
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

  void _onPurchasesUpdated(List<PurchaseDetails> purchases, String userId) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        _purchased.add(purchase.productID);
        InAppPurchase.instance.completePurchase(purchase);
        _savePremiumToFirestore(userId);
      } else if (purchase.status == PurchaseStatus.error) {
        _error = purchase.error.toString();
        notifyListeners();
      }
    }
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
    _subscription?.cancel();
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
