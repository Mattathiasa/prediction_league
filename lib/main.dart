import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'firebase_options.dart';
import 'providers/fixture_provider.dart';
import 'providers/league_provider.dart';
import 'providers/prediction_provider.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone data required by flutter_local_notifications zonedSchedule
  tz.initializeTimeZones();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      ],
      child: MaterialApp(
        title: 'Prediction League',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4CAF50),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
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
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
        ),
      );
    }

    return auth.userModel != null ? const HomeScreen() : const AuthScreen();
  }
}
