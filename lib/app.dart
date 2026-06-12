import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/home/home_shell.dart';
import 'features/workout/screens/workout_day_screen.dart';
import 'features/subscription/screens/paywall_screen.dart';
import 'features/settings/screens/profile_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/body/body_screen.dart';
import 'core/services/sync_service.dart';
import 'providers/app_providers.dart';
import 'core/theme/app_theme.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/paywall', builder: (c, s) => const PaywallScreen()),
      GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/body', builder: (c, s) => const BodyScreen()),
      GoRoute(path: '/home', builder: (c, s) => const HomeShell(child: SizedBox.shrink()), routes: [
        GoRoute(path: 'day/:date', builder: (c, s) => WorkoutDayScreen(date: DateTime.parse(s.pathParameters['date']!))),
      ]),
    ],
  );
});

class FitForgeApp extends ConsumerStatefulWidget {
  const FitForgeApp({super.key});
  @override
  ConsumerState<FitForgeApp> createState() => _FitForgeAppState();
}

class _FitForgeAppState extends ConsumerState<FitForgeApp> with WidgetsBindingObserver {
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SyncService.instance.fullSync();
      ref.read(workoutCacheProvider.notifier).loadAll();
      ref.read(dietCacheProvider.notifier).loadDate(DateTime.now());
    }
  }
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: 'FitForge', debugShowCheckedModeBanner: false,
      theme: AppTheme.light, darkTheme: AppTheme.dark, themeMode: ThemeMode.system,
      routerConfig: router,
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
    );
  }
}
