import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_provider.dart';
import '../../features/auth/presentation/screens/phone_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/run/presentation/screens/run_screen.dart';
import '../../features/permissions/presentation/location_setup_sheet.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../features/club/presentation/screens/club_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/shoes/presentation/screens/shoes_screen.dart';
import '../../features/offline_maps/presentation/screens/offline_maps_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../shared/widgets/main_scaffold.dart';

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authProvider);
    final isAuth = auth.status == AuthStatus.authenticated;
    final loc = state.matchedLocation;

    if (loc == '/splash') return null; // сплэш сам управляет навигацией
    if (!isAuth && !loc.startsWith('/auth')) return '/auth/phone';
    if (isAuth && loc.startsWith('/auth')) return null;
    if (loc == '/auth/otp' && auth.status != AuthStatus.codeSent) {
      return '/auth/phone';
    }
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, __) => const NoTransitionPage(child: SplashScreen()),
      ),
      GoRoute(
        path: '/auth/phone',
        pageBuilder: (_, __) => const NoTransitionPage(child: PhoneScreen()),
      ),
      GoRoute(
        path: '/auth/otp',
        pageBuilder: (_, __) => const NoTransitionPage(child: OtpScreen()),
      ),
      GoRoute(
        path: '/offline-onboarding',
        pageBuilder: (_, __) =>
            const NoTransitionPage(child: OfflineMapsScreen(onboarding: true)),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/map',
            pageBuilder: (_, __) => const NoTransitionPage(child: MapScreen()),
          ),
          GoRoute(
            path: '/run',
            pageBuilder: (_, __) => const NoTransitionPage(child: RunScreen()),
          ),
          // Настройка доступа к геолокации — маршрут внутри шелла, чтобы таб-бар
          // продолжал переключать экраны (а не модальный лист, который залипал).
          GoRoute(
            path: '/run/location-access',
            builder: (_, __) => const LocationSetupScreen(),
          ),
          GoRoute(
            path: '/leaderboard',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: LeaderboardScreen()),
          ),
          GoRoute(
            path: '/club',
            pageBuilder: (_, __) => const NoTransitionPage(child: ClubScreen()),
          ),
          GoRoute(
            path: '/offline-maps',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: OfflineMapsScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),
          // Под-экраны профиля — маршруты внутри шелла, чтобы таб-бар их переключал
          // (раньше открывались Navigator.push и «залипали» поверх вкладок).
          GoRoute(
            path: '/profile/points',
            builder: (_, __) => const PointsHistoryScreen(),
          ),
          GoRoute(
            path: '/profile/shoes',
            builder: (_, __) => const ShoesScreen(),
          ),
          GoRoute(
            path: '/profile/edit',
            builder: (_, __) => const EditProfileScreen(),
          ),
          GoRoute(
            path: '/profile/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
