import 'package:fitforge/app.dart';
import 'package:fitforge/core/localization/l10n.dart';
import 'package:fitforge/data/models/user_profile.dart';
import 'package:fitforge/features/auth/screens/login_screen.dart';
import 'package:fitforge/features/auth/screens/onboarding_screen.dart';
import 'package:fitforge/providers/app_providers.dart';
import 'package:fitforge/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

const _existingProfile = UserProfile(
  id: 'existing-user',
  gender: Gender.male,
  age: 30,
  heightCm: 180,
  weightKg: 80,
  goal: FitnessGoal.buildMuscle,
);

class _RetryableProfileNotifier extends UserProfileNotifier {
  static int buildCount = 0;

  @override
  Future<UserProfile?> build() async {
    buildCount += 1;
    if (buildCount == 1) throw StateError('profile unavailable');
    return null;
  }
}

class _MutableProfileNotifier extends UserProfileNotifier {
  @override
  Future<UserProfile?> build() async => _existingProfile;

  void publish(AsyncValue<UserProfile?> profileState) {
    state = profileState;
  }
}

Widget _routerApp({
  required String userId,
  required AsyncValue<UserProfile?> profileState,
  AppLocale locale = AppLocale.en,
}) {
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => userId),
      authRoutingProfileProvider.overrideWith((ref) => profileState),
      localeProvider.overrideWith((ref) => locale),
    ],
    child: Consumer(
      builder: (context, ref, child) {
        return MaterialApp.router(
          routerConfig: ref.watch(fitForgeRouterProvider),
        );
      },
    ),
  );
}

Widget _retryableRouterApp() {
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 'retry-user'),
      userProfileProvider.overrideWith(_RetryableProfileNotifier.new),
    ],
    child: Consumer(
      builder: (context, ref, child) {
        return MaterialApp.router(
          routerConfig: ref.watch(fitForgeRouterProvider),
        );
      },
    ),
  );
}

void main() {
  group('AuthTransitionHandler', () {
    test('login transition updates identity and initializes user state', () {
      var currentUserId = '';
      final assignedUserIds = <String>[];
      var profileInvalidations = 0;
      var workoutCacheInitializations = 0;
      var dietCacheInitializations = 0;
      var fullSyncs = 0;
      final handler = AuthTransitionHandler(
        readCurrentUserId: () => currentUserId,
        setCurrentUserId: (userId) {
          currentUserId = userId;
          assignedUserIds.add(userId);
        },
        invalidateProfile: () => profileInvalidations += 1,
        initializeWorkoutCache: () => workoutCacheInitializations += 1,
        initializeDietCache: () => dietCacheInitializations += 1,
        startFullSync: () => fullSyncs += 1,
      );

      handler.handle('user-a');

      expect(currentUserId, 'user-a');
      expect(assignedUserIds, ['user-a']);
      expect(profileInvalidations, 1);
      expect(workoutCacheInitializations, 1);
      expect(dietCacheInitializations, 1);
      expect(fullSyncs, 1);

      handler.handle('user-a');
      expect(assignedUserIds, ['user-a']);
      expect(profileInvalidations, 1);
      expect(workoutCacheInitializations, 2);
      expect(dietCacheInitializations, 2);
      expect(fullSyncs, 1);

      handler.handle('');
      handler.handle('user-a');
      expect(assignedUserIds, ['user-a', '', 'user-a']);
      expect(profileInvalidations, 3);
      expect(fullSyncs, 2);
    });

    test('initial session refreshes profile, caches, and sync', () {
      var currentUserId = 'existing-user';
      var identityAssignments = 0;
      var profileInvalidations = 0;
      var workoutCacheInitializations = 0;
      var dietCacheInitializations = 0;
      var fullSyncs = 0;
      final handler = AuthTransitionHandler(
        readCurrentUserId: () => currentUserId,
        setCurrentUserId: (userId) {
          currentUserId = userId;
          identityAssignments += 1;
        },
        invalidateProfile: () => profileInvalidations += 1,
        initializeWorkoutCache: () => workoutCacheInitializations += 1,
        initializeDietCache: () => dietCacheInitializations += 1,
        startFullSync: () => fullSyncs += 1,
      );

      handler.handle('existing-user', forceProfileRefresh: true);

      expect(currentUserId, 'existing-user');
      expect(identityAssignments, 0);
      expect(profileInvalidations, 1);
      expect(workoutCacheInitializations, 1);
      expect(dietCacheInitializations, 1);
      expect(fullSyncs, 1);
    });
  });

  group('auth routing', () {
    testWidgets('authenticated user without a profile enters onboarding', (
      tester,
    ) async {
      await tester.pumpWidget(
        _routerApp(
          userId: 'new-user',
          profileState: const AsyncData<UserProfile?>(null),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Set up your body data to begin'), findsOneWidget);
    });

    test('authenticated routing distinguishes first and existing users', () {
      expect(
        authRouteRedirect(
          userId: 'new-user',
          profileState: const AsyncData<UserProfile?>(null),
          location: '/home',
        ),
        '/onboarding',
      );
      expect(
        authRouteRedirect(
          userId: 'existing-user',
          profileState: const AsyncData<UserProfile?>(_existingProfile),
          location: '/login',
        ),
        '/home',
      );
      expect(
        authRouteRedirect(
          userId: 'existing-user',
          profileState: const AsyncData<UserProfile?>(_existingProfile),
          location: '/home/programs',
        ),
        isNull,
      );
    });

    test(
      'loading and failed profile reads do not masquerade as no profile',
      () {
        final refreshingAfterMissing = const AsyncLoading<UserProfile?>()
            .copyWithPrevious(const AsyncData<UserProfile?>(null));
        final failedAfterMissing = AsyncError<UserProfile?>(
          StateError('unavailable'),
          StackTrace.empty,
        ).copyWithPrevious(const AsyncData<UserProfile?>(null));

        expect(
          authInitialLocation(
            userId: 'user',
            profileState: refreshingAfterMissing,
          ),
          '/auth-loading',
        );
        expect(
          authInitialLocation(userId: 'user', profileState: failedAfterMissing),
          '/auth-error',
        );
      },
    );

    test('profile ownership controls refresh and stale-account routing', () {
      final currentProfile = const AsyncData<UserProfile?>(_existingProfile);
      final refreshingCurrent = const AsyncLoading<UserProfile?>()
          .copyWithPrevious(currentProfile);
      final failedCurrent = AsyncError<UserProfile?>(
        StateError('refresh unavailable'),
        StackTrace.empty,
      ).copyWithPrevious(currentProfile);

      for (final state in [refreshingCurrent, failedCurrent]) {
        expect(
          authRouteCategory(userId: 'existing-user', profileState: state),
          AuthRouteCategory.authenticated,
        );
        expect(
          authRouteRedirect(
            userId: 'existing-user',
            profileState: state,
            location: '/home/programs',
          ),
          isNull,
        );
      }

      final staleLoading = const AsyncLoading<UserProfile?>().copyWithPrevious(
        currentProfile,
      );
      final staleError = AsyncError<UserProfile?>(
        StateError('new account unavailable'),
        StackTrace.empty,
      ).copyWithPrevious(currentProfile);
      expect(
        authRouteCategory(userId: 'different-user', profileState: staleLoading),
        AuthRouteCategory.loading,
      );
      expect(
        authRouteRedirect(
          userId: 'different-user',
          profileState: staleLoading,
          location: '/home/programs',
        ),
        '/auth-loading',
      );

      for (final state in [currentProfile, staleError]) {
        expect(
          authRouteCategory(userId: 'different-user', profileState: state),
          AuthRouteCategory.error,
        );
        expect(
          authRouteRedirect(
            userId: 'different-user',
            profileState: state,
            location: '/home/programs',
          ),
          '/auth-error',
        );
      }
    });

    test(
      'non-null profile updates keep the router and current location',
      () async {
        final container = ProviderContainer(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'existing-user'),
            userProfileProvider.overrideWith(_MutableProfileNotifier.new),
          ],
        );
        addTearDown(container.dispose);
        await container.read(userProfileProvider.future);

        final router = container.read(fitForgeRouterProvider);
        router.go('/home/programs');
        await Future<void>.delayed(Duration.zero);
        expect(
          router.routeInformationProvider.value.uri.path,
          '/home/programs',
        );

        final notifier =
            container.read(userProfileProvider.notifier)
                as _MutableProfileNotifier;
        const updatedProfile = UserProfile(
          id: 'existing-user',
          gender: Gender.male,
          age: 31,
          heightCm: 180,
          weightKg: 80,
          goal: FitnessGoal.buildMuscle,
          displayName: 'Updated',
        );
        notifier.publish(const AsyncData<UserProfile?>(updatedProfile));
        await Future<void>.delayed(Duration.zero);

        final refreshing = const AsyncLoading<UserProfile?>().copyWithPrevious(
          const AsyncData<UserProfile?>(updatedProfile),
        );
        final failedRefresh = AsyncError<UserProfile?>(
          StateError('refresh unavailable'),
          StackTrace.empty,
        ).copyWithPrevious(const AsyncData<UserProfile?>(updatedProfile));
        for (final state in [refreshing, failedRefresh]) {
          notifier.publish(state);
          await Future<void>.delayed(Duration.zero);

          expect(
            container.read(authRouteCategoryProvider),
            AuthRouteCategory.authenticated,
          );
          expect(container.read(fitForgeRouterProvider), same(router));
          expect(
            router.routeInformationProvider.value.uri.path,
            '/home/programs',
          );
        }
      },
    );

    testWidgets('profile failure shows localized error instead of onboarding', (
      tester,
    ) async {
      await tester.pumpWidget(
        _routerApp(
          userId: 'user',
          profileState: AsyncError<UserProfile?>(
            StateError('unavailable'),
            StackTrace.empty,
          ),
          locale: AppLocale.zh,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('无法加载个人资料'), findsOneWidget);
      expect(find.text('请检查网络连接后重试。您已保存的数据不会被更改。'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets(
      'retry invalidates profile loading and routes from fresh data',
      (tester) async {
        _RetryableProfileNotifier.buildCount = 0;
        await tester.pumpWidget(_retryableRouterApp());
        await tester.pumpAndSettle();

        expect(find.text('Unable to load your profile'), findsOneWidget);
        expect(_RetryableProfileNotifier.buildCount, 1);

        await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
        await tester.pumpAndSettle();

        expect(_RetryableProfileNotifier.buildCount, 2);
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.text('Unable to load your profile'), findsNothing);
      },
    );
  });

  group('LoginScreen localization', () {
    testWidgets('renders English copy and validation error', (tester) async {
      await tester.pumpWidget(testApp(child: const LoginScreen()));

      expect(find.text('Log every rep. Own every meal.'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('No account? Sign up'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Sign in with Apple'), findsOneWidget);
      expect(find.text('登录'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
      await tester.pump();

      expect(find.text('Please enter email and password'), findsOneWidget);
    });

    testWidgets('renders Chinese copy and validation error', (tester) async {
      await tester.pumpWidget(
        testApp(child: const LoginScreen(), locale: AppLocale.zh),
      );

      expect(find.text('记录每一次训练，掌控每一餐营养'), findsOneWidget);
      expect(find.text('邮箱'), findsOneWidget);
      expect(find.text('密码'), findsOneWidget);
      expect(find.text('没有账号？去注册'), findsOneWidget);
      expect(find.text('登录'), findsOneWidget);
      expect(find.text('使用 Google 登录'), findsOneWidget);
      expect(find.text('使用 Apple 登录'), findsOneWidget);
      expect(find.text('Email'), findsNothing);
      expect(find.text('Password'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, '登录'));
      await tester.pump();

      expect(find.text('请输入邮箱和密码'), findsOneWidget);
    });

    testWidgets('localizes sign-up mode and coming-soon feedback', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(child: const LoginScreen(), locale: AppLocale.zh),
      );

      await tester.tap(find.text('没有账号？去注册'));
      await tester.pump();
      expect(find.widgetWithText(FilledButton, '注册'), findsOneWidget);
      expect(find.text('已有账号？去登录'), findsOneWidget);

      final googleButton = find.widgetWithText(OutlinedButton, '使用 Google 登录');
      await tester.ensureVisible(googleButton);
      await tester.pumpAndSettle();
      await tester.tap(googleButton);
      await tester.pump();
      expect(find.text('Google 登录即将推出'), findsOneWidget);
    });
  });

  group('OnboardingScreen localization', () {
    testWidgets('renders English copy and validation errors', (tester) async {
      await tester.pumpWidget(testApp(child: const OnboardingScreen()));

      expect(find.text('Set up your body data to begin'), findsOneWidget);
      expect(find.text('Gender'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);
      expect(find.text('Height'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('Goal'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'not-a-number');
      await tester.enterText(fields.at(1), '');
      await tester.enterText(fields.at(2), '');
      final submitButton = find.widgetWithText(FilledButton, 'Get Started');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pump();

      expect(find.text('Please enter a valid number'), findsOneWidget);
      expect(find.text('Please enter your height'), findsOneWidget);
      expect(find.text('Please enter your weight'), findsOneWidget);
    });

    testWidgets('renders Chinese copy and validation errors', (tester) async {
      await tester.pumpWidget(
        testApp(child: const OnboardingScreen(), locale: AppLocale.zh),
      );

      expect(find.text('设置您的身体数据以开始'), findsOneWidget);
      expect(find.text('性别'), findsOneWidget);
      expect(find.text('男'), findsOneWidget);
      expect(find.text('女'), findsOneWidget);
      expect(find.text('年龄'), findsOneWidget);
      expect(find.text('身高'), findsOneWidget);
      expect(find.text('体重'), findsOneWidget);
      expect(find.text('目标'), findsOneWidget);
      expect(find.text('开始使用'), findsOneWidget);
      expect(find.text('Gender'), findsNothing);
      expect(find.text('Get Started'), findsNothing);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '');
      await tester.enterText(fields.at(1), '');
      await tester.enterText(fields.at(2), '');
      final submitButton = find.widgetWithText(FilledButton, '开始使用');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pump();

      expect(find.text('请输入年龄'), findsOneWidget);
      expect(find.text('请输入身高'), findsOneWidget);
      expect(find.text('请输入体重'), findsOneWidget);
    });
  });
}
