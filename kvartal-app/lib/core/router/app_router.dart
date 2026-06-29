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
import '../../features/club/presentation/screens/club_scan_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/privacy_screen.dart';
import '../../features/shoes/presentation/screens/shoes_screen.dart';
import '../../features/tools/presentation/screens/tools_hub_screen.dart';
import '../../features/tools/presentation/screens/pace_converter_screen.dart';
import '../../features/tools/presentation/screens/hr_zones_screen.dart';
import '../../features/tools/presentation/screens/shoe_size_screen.dart';
import '../../features/tools/presentation/screens/cadence_metronome_screen.dart';
import '../../features/tools/presentation/screens/interval_timer_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../shared/widgets/main_scaffold.dart';

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    // redirect зависит только от auth.status (вход/выход). Рефрешим GoRouter
    // лишь при смене статуса — иначе сохранение профиля/аватара/isLoading
    // дёргает весь стек роутера, и экран редактирования мелькает («перекрытие»
    // редактора, проблеск предыдущего экрана при «Сохранить»).
    _ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.status != next.status) notifyListeners();
    });
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

// Ключ навигатора шелла (под таб-баром). Нужен, чтобы при переключении вкладок
// закрывать открытые модальные листы (погода, выбор кроссовок и т.п.) — иначе они
// висят поверх новой вкладки (см. [[feedback-no-repeat-fixed-bugs]]).
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

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
      // Скан QR приглашения — полноэкранный (вне шелла), как камера в Тинькофф.
      GoRoute(
        path: '/club/scan',
        builder: (_, __) => const ClubScanScreen(),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
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
          GoRoute(
            path: '/profile/notifications',
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/profile/privacy',
            builder: (_, __) => const PrivacyScreen(),
          ),
          // Инструменты бегуна — офлайн-калькуляторы/таймеры (вход из профиля).
          GoRoute(
            path: '/tools',
            builder: (_, __) => const ToolsHubScreen(),
          ),
          GoRoute(
            path: '/tools/pace',
            builder: (_, __) => const PaceConverterScreen(),
          ),
          GoRoute(
            path: '/tools/hr-zones',
            builder: (_, __) => const HrZonesScreen(),
          ),
          GoRoute(
            path: '/tools/shoe-size',
            builder: (_, __) => const ShoeSizeScreen(),
          ),
          GoRoute(
            path: '/tools/metronome',
            builder: (_, __) => const CadenceMetronomeScreen(),
          ),
          GoRoute(
            path: '/tools/interval',
            builder: (_, __) => const IntervalTimerScreen(),
          ),
        ],
      ),
    ],
  );
});
