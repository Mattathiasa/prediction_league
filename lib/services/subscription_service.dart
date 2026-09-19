import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService extends ChangeNotifier {
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  final Set<String> _purchased = {};
  bool _loading = false;
  String? _error;

  List<ProductDetails> get products => _products;
  bool get loading => _loading;
  String? get error => _error;
  bool get isPremium => _purchased.isNotEmpty;
  Set<String> get purchased => _purchased;

  static const _kPremiumId = 'premium_monthly';
  static const _kNoAdsId = 'remove_ads';

  static const _kProductIds = {_kPremiumId, _kNoAdsId};

  Future<void> init() async {
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
      _onPurchasesUpdated,
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );

    await _loadPremiumState();
    await restorePurchases();
  }

  Future<void> buy(ProductDetails product) async {
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

  void _onPurchasesUpdated(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        _purchased.add(purchase.productID);
        InAppPurchase.instance.completePurchase(purchase);
        _savePremiumState();
        notifyListeners();
      } else if (purchase.status == PurchaseStatus.error) {
        _error = purchase.error.toString();
        notifyListeners();
      }
    }
  }

  Future<void> _savePremiumState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', _purchased.isNotEmpty);
  }

  Future<void> _loadPremiumState() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('is_premium') ?? false;
  }

  bool _isPremium = false;
  bool get isPremiumUser => _isPremium || _purchased.isNotEmpty;

  Future<void> restorePurchases() async {
    try {
      await InAppPurchase.instance.restorePurchases();
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
}
