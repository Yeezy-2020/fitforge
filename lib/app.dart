import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/models/user_profile.dart';
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

const _loginLocation = '/login';
const _authLoadingLocation = '/auth-loading';
const _authErrorLocation = '/auth-error';
const _onboardingLocation = '/onboarding';
const _homeLocation = '/home';

final authRoutingProfileProvider = Provider<AsyncValue<UserProfile?>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(userProfileProvider);
});

enum AuthRouteCategory { loggedOut, loading, error, onboarding, authenticated }

AuthRouteCategory authRouteCategory({
  required String userId,
  required AsyncValue<UserProfile?> profileState,
}) {
  if (userId.isEmpty) return AuthRouteCategory.loggedOut;
  final profile = profileState.valueOrNull;
  if (profile?.id == userId) return AuthRouteCategory.authenticated;
  if (profileState.isLoading) return AuthRouteCategory.loading;
  if (profileState.hasError) return AuthRouteCategory.error;
  if (profile != null) return AuthRouteCategory.error;
  return AuthRouteCategory.onboarding;
}

final authRouteCategoryProvider = Provider<AuthRouteCategory>((ref) {
  return authRouteCategory(
    userId: ref.watch(currentUserIdProvider),
    profileState: ref.watch(authRoutingProfileProvider),
  );
});

String _initialLocationForCategory(AuthRouteCategory category) {
  return switch (category) {
    AuthRouteCategory.loggedOut => _loginLocation,
    AuthRouteCategory.loading => _authLoadingLocation,
    AuthRouteCategory.error => _authErrorLocation,
    AuthRouteCategory.onboarding => _onboardingLocation,
    AuthRouteCategory.authenticated => _homeLocation,
  };
}

String? _routeRedirectForCategory({
  required AuthRouteCategory category,
  required String location,
}) {
  return switch (category) {
    AuthRouteCategory.loggedOut =>
      location == _loginLocation ? null : _loginLocation,
    AuthRouteCategory.loading =>
      location == _authLoadingLocation ? null : _authLoadingLocation,
    AuthRouteCategory.error =>
      location == _authErrorLocation ? null : _authErrorLocation,
    AuthRouteCategory.onboarding =>
      location == _onboardingLocation ? null : _onboardingLocation,
    AuthRouteCategory.authenticated =>
      location == _loginLocation ||
              location == _authLoadingLocation ||
              location == _authErrorLocation ||
              location == _onboardingLocation
          ? _homeLocation
          : null,
  };
}

String authInitialLocation({
  required String userId,
  required AsyncValue<UserProfile?> profileState,
}) {
  return _initialLocationForCategory(
    authRouteCategory(userId: userId, profileState: profileState),
  );
}

String? authRouteRedirect({
  required String userId,
  required AsyncValue<UserProfile?> profileState,
  required String location,
}) {
  return _routeRedirectForCategory(
    category: authRouteCategory(userId: userId, profileState: profileState),
    location: location,
  );
}

final _authRouteRefreshProvider = Provider<ValueNotifier<AuthRouteCategory>>((
  ref,
) {
  final notifier = ValueNotifier(ref.read(authRouteCategoryProvider));
  ref.listen<AuthRouteCategory>(authRouteCategoryProvider, (previous, next) {
    notifier.value = next;
  });
  ref.onDispose(notifier.dispose);
  return notifier;
});

final fitForgeRouterProvider = Provider<GoRouter>((ref) {
  final authRouteRefresh = ref.watch(_authRouteRefreshProvider);
  final router = GoRouter(
    initialLocation: _initialLocationForCategory(authRouteRefresh.value),
    refreshListenable: authRouteRefresh,
    redirect: (context, state) {
      return _routeRedirectForCategory(
        category: authRouteRefresh.value,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: _loginLocation,
        pageBuilder: (c, s) => _instantPage(s, const LoginScreen()),
      ),
      GoRoute(
        path: _authLoadingLocation,
        pageBuilder: (c, s) => _instantPage(
          s,
          const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
      GoRoute(
        path: _authErrorLocation,
        pageBuilder: (c, s) => _instantPage(s, const _ProfileLoadErrorScreen()),
      ),
      GoRoute(
        path: _onboardingLocation,
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
        path: _homeLocation,
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
  ref.onDispose(router.dispose);
  return router;
});

class _ProfileLoadErrorScreen extends ConsumerWidget {
  const _ProfileLoadErrorScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.get('profileLoadErrorTitle'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.get('profileLoadErrorBody'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(userProfileProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.get('retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FitForgeApp extends ConsumerStatefulWidget {
  const FitForgeApp({super.key});
  @override
  ConsumerState<FitForgeApp> createState() => _FitForgeAppState();
}

class AuthTransitionHandler {
  final String Function() _readCurrentUserId;
  final void Function(String userId) _setCurrentUserId;
  final void Function() _invalidateProfile;
  final void Function() _initializeWorkoutCache;
  final void Function() _initializeDietCache;
  final void Function() _startFullSync;
  String? _lastSyncedUserId;

  factory AuthTransitionHandler({
    required String Function() readCurrentUserId,
    required void Function(String userId) setCurrentUserId,
    required void Function() invalidateProfile,
    required void Function() initializeWorkoutCache,
    required void Function() initializeDietCache,
    required void Function() startFullSync,
  }) {
    return AuthTransitionHandler._(
      readCurrentUserId,
      setCurrentUserId,
      invalidateProfile,
      initializeWorkoutCache,
      initializeDietCache,
      startFullSync,
    );
  }

  AuthTransitionHandler._(
    this._readCurrentUserId,
    this._setCurrentUserId,
    this._invalidateProfile,
    this._initializeWorkoutCache,
    this._initializeDietCache,
    this._startFullSync,
  );

  void handle(String userId, {bool forceProfileRefresh = false}) {
    final userChanged = _readCurrentUserId() != userId;
    if (userChanged) _setCurrentUserId(userId);
    if (userChanged || (forceProfileRefresh && userId.isNotEmpty)) {
      _invalidateProfile();
    }

    if (userId.isEmpty) {
      _lastSyncedUserId = null;
      return;
    }
    if (_lastSyncedUserId != userId) {
      _lastSyncedUserId = userId;
      _startFullSync();
    }
    _initializeWorkoutCache();
    _initializeDietCache();
  }
}

class _FitForgeAppState extends ConsumerState<FitForgeApp>
    with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSubscription;
  late final AuthTransitionHandler _authTransitionHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authTransitionHandler = AuthTransitionHandler(
      readCurrentUserId: () => ref.read(currentUserIdProvider),
      setCurrentUserId: (userId) {
        ref.read(currentUserIdProvider.notifier).state = userId;
      },
      invalidateProfile: () => ref.invalidate(userProfileProvider),
      initializeWorkoutCache: () {
        ref.read(workoutCacheProvider.notifier).loadAll();
      },
      initializeDietCache: () {
        ref.read(dietCacheProvider.notifier).loadDate(DateTime.now());
      },
      startFullSync: () => unawaited(SyncService.instance.fullSync()),
    );
    _authTransitionHandler.handle(
      Supabase.instance.client.auth.currentUser?.id ?? '',
      forceProfileRefresh: true,
    );
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      _authTransitionHandler.handle(data.session?.user.id ?? '');
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
    final router = ref.watch(fitForgeRouterProvider);
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
