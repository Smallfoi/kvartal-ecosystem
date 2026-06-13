import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'router/app_router.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'theme/app_theme.dart';

class SportStoreApp extends StatefulWidget {
  final SharedPreferences prefs;
  const SportStoreApp({super.key, required this.prefs});

  @override
  State<SportStoreApp> createState() => _SportStoreAppState();
}

class _SportStoreAppState extends State<SportStoreApp> {
  static const _onboardingKey = 'onboarding_seen';

  bool _splashDone = false;
  late bool _onboardingDone;

  @override
  void initState() {
    super.initState();
    _onboardingDone = widget.prefs.getBool(_onboardingKey) ?? false;
  }

  void _finishOnboarding() {
    widget.prefs.setBool(_onboardingKey, true);
    setState(() => _onboardingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(
          onComplete: () => setState(() => _splashDone = true),
        ),
      );
    }

    if (!_onboardingDone) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: OnboardingScreen(onComplete: _finishOnboarding),
      );
    }

    return MaterialApp.router(
      title: 'SportStore',
      theme: AppTheme.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
