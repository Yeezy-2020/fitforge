import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/home/home_shell.dart';
import 'features/workout/screens/workout_day_screen.dart';
import 'features/workout/screens/training_programs_screen.dart';
import 'features/subscription/screens/paywall_screen.dart';
import 'features/settings/screens/profile_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/body/body_screen.dart';
import 'core/services/sync_service.dart';
import 'providers/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/metallic_surface.dart';
import 'providers/settings_providers.dart';
import 'core/localization/l10n.dart';

Page<void> _instantPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

final _routerProvider = Provider<GoRouter>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return GoRouter(
    initialLocation: userId.isEmpty ? '/login' : '/home',
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isLogin = location == '/login';
      final isOnboarding = location == '/onboarding';

      if (userId.isEmpty && !isLogin) return '/login';
      if (userId.isNotEmpty && isLogin) return '/home';
      if (userId.isEmpty && isOnboarding) return '/login';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (c, s) => _instantPage(s, const LoginScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (c, s) => _instantPage(s, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/paywall',
        pageBuilder: (c, s) => _instantPage(s, const PaywallScreen()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (c, s) => _instantPage(s, const ProfileScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (c, s) => _instantPage(s, const SettingsScreen()),
      ),
      GoRoute(
        path: '/body',
        pageBuilder: (c, s) => _instantPage(s, const BodyScreen()),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (c, s) =>
            _instantPage(s, const HomeShell(child: SizedBox.shrink())),
        routes: [
          GoRoute(
            path: 'day/:date',
            pageBuilder: (c, s) => _instantPage(
              s,
              WorkoutDayScreen(date: DateTime.parse(s.pathParameters['date']!)),
            ),
          ),
          GoRoute(
            path: 'programs',
            pageBuilder: (c, s) =>
                _instantPage(s, const TrainingProgramsScreen()),
          ),
        ],
      ),
    ],
  );
});

class FitForgeApp extends ConsumerStatefulWidget {
  const FitForgeApp({super.key});
  @override
  ConsumerState<FitForgeApp> createState() => _FitForgeAppState();
}

class _FitForgeAppState extends ConsumerState<FitForgeApp>
    with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final userId = data.session?.user.id ?? '';
      ref.read(currentUserIdProvider.notifier).state = userId;
      if (userId.isNotEmpty) {
        ref.read(workoutCacheProvider.notifier).loadAll();
        ref.read(dietCacheProvider.notifier).loadDate(DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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
    final appLocale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'FitForge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) =>
          MetallicBackground(child: child ?? const SizedBox.shrink()),
      locale: appLocale == AppLocale.zh
          ? const Locale('zh', 'CN')
          : const Locale('en', 'US'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
    );
  }
}
