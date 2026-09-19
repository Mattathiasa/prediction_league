import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-3210681117962880~9348060115',
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _bannerAd = ad as BannerAd;
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
      ),
      request: const AdRequest(),
    );

    await ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded && _bannerAd != null) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox.shrink();
  }
}

// Ad-free wrapper — shows ad only for non-premium users
class ConditionalBannerAd extends StatelessWidget {
  final bool isPremium;
  const ConditionalBannerAd({super.key, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    if (isPremium) return const SizedBox.shrink();
    return const Align(alignment: Alignment.bottomCenter, child: BannerAdWidget());
  }
}
