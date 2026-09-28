import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'firebase_options.dart';
import 'providers/fixture_provider.dart';
import 'providers/league_provider.dart';
import 'providers/prediction_provider.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'screens/auth_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Release builds attest with the real providers. Debug builds cannot — a
  // locally-signed APK fails Play Integrity — so without this branch every
  // Firestore read and callable fails on a development device.
  // Register the token this prints in Firebase console → App Check → Debug.
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
  );

  MobileAds.instance.initialize();

  await NotificationService.initialize();
  await NotificationService.requestPermission();

  runApp(const PredictionLeagueApp());
}

class PredictionLeagueApp extends StatelessWidget {
  const PredictionLeagueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => FixtureProvider()),
        ChangeNotifierProxyProvider<AuthService, PredictionProvider>(
          create: (_) => PredictionProvider(),
          update: (_, auth, prev) {
            final provider = prev ?? PredictionProvider();
            if (auth.userModel != null) {
              provider.startListening(auth.userModel!.uid);
            } else {
              provider.stopListening();
            }
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, LeagueProvider>(
          create: (_) => LeagueProvider(),
          update: (_, auth, prev) {
            final provider = prev ?? LeagueProvider();
            if (auth.userModel != null) {
              provider.startListening(auth.userModel!.uid);
            } else {
              provider.stopListening();
            }
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, SubscriptionService>(
          create: (_) => SubscriptionService(),
          update: (_, auth, prev) {
            final provider = prev ?? SubscriptionService();
            if (auth.isEmailVerified && auth.userModel != null) {
              provider.init(auth.userModel!.uid);
            } else if (auth.userModel == null) {
              provider.reset();
            }
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Prediction League',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const _AuthWrapper(),
      ),
    );
  }
}

class _AuthWrapper extends StatelessWidget {
  const _AuthWrapper();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.initialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    // Startup reached a decision but could not complete it — almost always no
    // network. Without this the app sat on the spinner above indefinitely.
    if (auth.startupError != null && auth.userModel == null) {
      return _StartupErrorScreen(
        message: auth.startupError!,
        onRetry: auth.retryStartup,
      );
    }

    return auth.userModel != null
        ? (auth.isEmailVerified
            ? const HomeScreen()
            : const VerifyEmailScreen())
        : const AuthScreen();
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: Colors.white24),
              const SizedBox(height: 20),
              const Text(
                'Cannot connect',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
