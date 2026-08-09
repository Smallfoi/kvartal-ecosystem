import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _clearMapAndRunDataOnStartup();
  await _runWithSentry(const ProviderScope(child: KvartalApp()));
}

/// Видимость ошибок (D-32): при заданном SENTRY_DSN (--dart-define) крэши и
/// необработанные ошибки летят в GlitchTip. Без DSN — обычный запуск (no-op).
/// PII не шлём (152-ФЗ). DSN приложения — из своего проекта GlitchTip.
Future<void> _runWithSentry(Widget app) async {
  const dsn = String.fromEnvironment('SENTRY_DSN');
  if (dsn.isEmpty) {
    runApp(app);
    return;
  }
  await SentryFlutter.init(
    (o) {
      o.dsn = dsn;
      o.environment = const String.fromEnvironment(
        'SENTRY_ENVIRONMENT',
        defaultValue: 'production',
      );
      const rel = String.fromEnvironment('SENTRY_RELEASE');
      if (rel.isNotEmpty) o.release = rel;
      o.tracesSampleRate = 0.0;
      o.sendDefaultPii = false;
    },
    appRunner: () => runApp(app),
  );
}

Future<void> _clearMapAndRunDataOnStartup() async {
  final prefs = await SharedPreferences.getInstance();
  const cleanupKey = 'kvartal.map_cleanup_2026_06_13_v3';
  if (prefs.getBool(cleanupKey) == true) return;

  const keys = [
    'kvartal.captured_zone_ids.v1',
    'kvartal.captured_areas.v1',
    'kvartal.active_run.v1',
    'kvartal.completed_runs.v1',
    'kvartal.map_cleanup_2026_06_11.v1',
  ];

  for (final key in keys) {
    await prefs.remove(key);
  }
  await prefs.setBool(cleanupKey, true);
}


class KvartalApp extends ConsumerWidget {
  const KvartalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
