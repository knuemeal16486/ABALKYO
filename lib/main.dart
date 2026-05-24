
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/app_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  await initializeDateFormatting('ko_KR', null);
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..load(),
      child: const MindDiaryApp(),
    ),
  );
}

class MindDiaryApp extends StatelessWidget {
  const MindDiaryApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '마음 정원',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (!provider.isLoaded) return const _SplashScreen();
    if (!provider.onboarded) return const OnboardingScreen();
    return const MainScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1F14), Color(0xFF1B3A2D)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🌱', style: TextStyle(fontSize: 64)),
              SizedBox(height: 16),
              Text('마음 정원',
                  style: TextStyle(
                      color: AppTheme.dawnGlow,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
