import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/subscription_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionService>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Go Premium',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: sub.loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Unlock Premium Features',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sub.error ?? 'Get the most out of Prediction League',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  const _FeatureCard(
                    icon: Icons.bar_chart_rounded,
                    title: 'Advanced Stats',
                    description: 'xG predictions, goal difference heatmaps, '
                        'and detailed accuracy analysis',
                    color: Color(0xFF29B6F6),
                  ),
                  const SizedBox(height: 14),
                  const _FeatureCard(
                    icon: Icons.emoji_events_rounded,
                    title: 'Custom Leagues',
                    description: 'Create leagues with up to 50 members '
                        'and custom scoring rules',
                    color: Color(0xFF4CAF50),
                  ),
                  const SizedBox(height: 14),
                  const _FeatureCard(
                    icon: Icons.history_rounded,
                    title: 'Full History',
                    description: 'Export your prediction history and stats '
                        'as CSV',
                    color: Color(0xFFFFD700),
                  ),
                  const SizedBox(height: 14),
                  const _FeatureCard(
                    icon: Icons.block,
                    title: 'Ad-Free',
                    description: 'No banners or interstitial ads anywhere '
                        'in the app',
                    color: Color(0xFF9C27B0),
                  ),
                  const SizedBox(height: 32),
                  ...sub.products.map((product) => _ProductButton(
                        product: product,
                        service: sub,
                      )),
                  TextButton(
                    onPressed: sub.restorePurchases,
                    child: const Text(
                      'Restore Purchases',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductButton extends StatelessWidget {
  final ProductDetails product;
  final SubscriptionService service;

  const _ProductButton({required this.product, required this.service});

  @override
  Widget build(BuildContext context) {
    final isCurrentlyPurchased = service.isPremium;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: service.loading || isCurrentlyPurchased
              ? null
              : () => service.buy(product),
          style: ElevatedButton.styleFrom(
            backgroundColor: isCurrentlyPurchased
                ? const Color(0xFF333344)
                : const Color(0xFF4CAF50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: service.loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isCurrentlyPurchased ? 'Purchased' : product.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      product.price,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
