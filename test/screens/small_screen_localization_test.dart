import 'package:fitforge/core/localization/l10n.dart';
import 'package:fitforge/data/models/diet_log.dart';
import 'package:fitforge/data/models/food.dart';
import 'package:fitforge/data/models/user_profile.dart';
import 'package:fitforge/data/models/workout_log.dart';
import 'package:fitforge/features/body/body_screen.dart';
import 'package:fitforge/features/diet/screens/diet_log_screen.dart';
import 'package:fitforge/features/settings/screens/profile_screen.dart';
import 'package:fitforge/features/settings/screens/settings_screen.dart';
import 'package:fitforge/features/subscription/screens/paywall_screen.dart';
import 'package:fitforge/providers/app_providers.dart';
import 'package:fitforge/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test_helpers.dart';

const _profile = UserProfile(
  id: 'test',
  gender: Gender.male,
  age: 30,
  heightCm: 180,
  weightKg: 80,
  goal: FitnessGoal.buildMuscle,
);

class _LoadedProfileNotifier extends UserProfileNotifier {
  @override
  Future<UserProfile?> build() async => _profile;
}

class _ImmediateProNotifier extends IsProNotifier {
  @override
  Future<void> setPro(bool value) async => state = value;
}

class _EmptyFoodListNotifier extends FoodListNotifier {
  @override
  Future<List<Food>> build() async => [];
}

class _EmptyRemote implements UserDataRemote {
  @override
  Future<List<DietLog>> getDietLogs(String userId, DateTime date) async => [];

  @override
  Future<List<Food>> getPublicFoods(String userId) async => [];

  @override
  Future<UserProfile?> getProfile(String userId) async => null;

  @override
  Future<List<WorkoutLog>> getWorkoutLogs(String userId, DateTime date) async =>
      [];

  @override
  Future<List<WorkoutLog>> getWorkoutLogsForMonth(
    String userId,
    DateTime month,
  ) async => [];

  @override
  Future<void> upsertProfile(String userId, UserProfile profile) async {}
}

Widget _profileApp() {
  return ProviderScope(
    overrides: [
      localeProvider.overrideWith((ref) => AppLocale.zh),
      currentUserIdProvider.overrideWith((ref) => 'test'),
      userProfileProvider.overrideWith(_LoadedProfileNotifier.new),
      isProProvider.overrideWith((ref) => IsProNotifier()),
    ],
    child: const MaterialApp(home: ProfileScreen()),
  );
}

Widget _dietApp() {
  return ProviderScope(
    overrides: [
      localeProvider.overrideWith((ref) => AppLocale.zh),
      currentUserIdProvider.overrideWith((ref) => 'test'),
      userDataRemoteProvider.overrideWith((ref) => _EmptyRemote()),
      foodListProvider.overrideWith(_EmptyFoodListNotifier.new),
    ],
    child: const MaterialApp(home: DietLogScreen()),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('small-screen localization keys have English and Chinese values', () {
    const en = L10n(AppLocale.en);
    const zh = L10n(AppLocale.zh);
    const keys = [
      'saveMealTemplate',
      'noTemplatesSaved',
      'subscriptionDemoSuccess',
      'bodyMeasurements',
      'accountDeletionUnavailableBody',
      'kilogram',
      'ounce',
    ];

    for (final key in keys) {
      expect(en.get(key), isNot(key), reason: 'missing English $key');
      expect(zh.get(key), isNot(key), reason: 'missing Chinese $key');
      expect(zh.get(key), isNot(en.get(key)), reason: 'untranslated $key');
    }
    expect(zh.format('templateSaved', {'name': '午餐'}), '模板“午餐”已保存');
  });

  testWidgets('settings radio groups update each provider', (tester) async {
    await tester.pumpWidget(
      testApp(child: const SettingsScreen(), locale: AppLocale.zh),
    );
    await tester.pumpAndSettle();

    expect(find.text('千克 (kg)'), findsOneWidget);
    expect(find.text('磅 (lb)'), findsOneWidget);

    final settingsContext = tester.element(find.byType(SettingsScreen));
    final container = ProviderScope.containerOf(settingsContext);
    final poundsRadio = find.byWidgetPredicate(
      (widget) => widget is Radio<WeightUnit> && widget.value == WeightUnit.lb,
    );
    await tester.tap(poundsRadio);
    await tester.pump();
    expect(container.read(trainingWeightUnitProvider), WeightUnit.lb);

    await tester.tap(find.text('English').first);
    await tester.pump();
    expect(container.read(localeProvider), AppLocale.en);
    expect(find.text('Kilogram (kg)'), findsOneWidget);
  });

  testWidgets('profile confirmation dialogs use the selected locale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_profileApp());
    await tester.pumpAndSettle();

    final logOutButton = find.text('退出登录');
    await tester.ensureVisible(logOutButton);
    await tester.tap(logOutButton);
    await tester.pumpAndSettle();
    expect(find.text('确认退出登录？'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final deleteButton = find.text('注销账户');
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('注销账户需要服务端流程，此开发版本暂不支持。'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
  });

  testWidgets('body validation error is localized', (tester) async {
    await tester.pumpWidget(
      testApp(child: const BodyScreen(), locale: AppLocale.zh),
    );
    await tester.pumpAndSettle();

    expect(find.text('身体测量'), findsOneWidget);
    expect(find.text('体重 (kg)'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(find.text('请输入有效数字'), findsOneWidget);
  });

  testWidgets('diet empty-template feedback is localized', (tester) async {
    await tester.pumpWidget(_dietApp());
    await tester.pumpAndSettle();

    expect(find.text('今天还没有记录饮食'), findsOneWidget);
    await tester.tap(find.byTooltip('载入饮食模板'));
    await tester.pumpAndSettle();
    expect(find.text('暂无已保存模板'), findsOneWidget);
  });

  testWidgets('paywall plan copy follows locale and selection', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      testApp(child: const PaywallScreen(), locale: AppLocale.zh),
    );
    await tester.pumpAndSettle();

    expect(find.text('升级至 FitForge Pro'), findsOneWidget);
    expect(find.text('年度订阅'), findsOneWidget);
    expect(find.text('相当于每月 \$4.99'), findsOneWidget);
    expect(find.text('订阅年度方案'), findsOneWidget);

    await tester.tap(find.text('月度订阅'));
    await tester.pump();
    expect(find.text('订阅月度方案'), findsOneWidget);
  });

  testWidgets('paywall closes before showing localized success feedback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: FilledButton(
              onPressed: () => context.push('/paywall'),
              child: const Text('Open paywall'),
            ),
          ),
        ),
        GoRoute(
          path: '/paywall',
          builder: (context, state) => const PaywallScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeProvider.overrideWith((ref) => AppLocale.zh),
          currentUserIdProvider.overrideWith((ref) => 'test'),
          isProProvider.overrideWith((ref) => _ImmediateProNotifier()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('Open paywall'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('订阅年度方案'));
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsNothing);
    expect(find.text('订阅已启用（演示模式）'), findsOneWidget);
  });
}
