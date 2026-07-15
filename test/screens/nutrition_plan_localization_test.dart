import 'dart:convert';
import 'dart:io';

import 'package:fitforge/core/localization/l10n.dart';
import 'package:fitforge/data/models/diet_log.dart';
import 'package:fitforge/data/models/food.dart';
import 'package:fitforge/data/models/user_profile.dart';
import 'package:fitforge/data/models/workout_log.dart';
import 'package:fitforge/features/nutrition_plan/screens/nutrition_plan_screen.dart';
import 'package:fitforge/providers/app_providers.dart';
import 'package:fitforge/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = UserProfile(
  id: 'nutrition-localization-test',
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

class _EmptyDietCacheNotifier extends DietCacheNotifier {
  _EmptyDietCacheNotifier()
    : super(_EmptyRemote(), 'nutrition-localization-test');
}

class _EmptyFoodListNotifier extends FoodListNotifier {
  @override
  Future<List<Food>> build() async => [];
}

Widget _testApp(AppLocale locale) {
  return ProviderScope(
    overrides: [
      localeProvider.overrideWith((ref) => locale),
      currentUserIdProvider.overrideWith(
        (ref) => 'nutrition-localization-test',
      ),
      userProfileProvider.overrideWith(_LoadedProfileNotifier.new),
      dietCacheProvider.overrideWith((ref) => _EmptyDietCacheNotifier()),
      foodListProvider.overrideWith(_EmptyFoodListNotifier.new),
    ],
    child: const MaterialApp(home: NutritionPlanScreen()),
  );
}

void _setSavedBulkPlan() {
  FlutterSecureStorage.setMockInitialValues({
    'nutrition-localization-test:nutrition_plan': jsonEncode({
      'goal': 'bulk',
      'planType': 'bulk',
      'experience': 'intermediate',
      'activityFactor': 1.55,
      'cycleTemplate': ['low', 'medium', 'high'],
      'planDurationDays': 56,
    }),
  });
}

Finder _dialogText(String text) {
  return find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text(text),
  );
}

Future<void> _verifyDialogs(
  WidgetTester tester, {
  required AppLocale locale,
  required String editActivity,
  required String editSettings,
  required String activityLevel,
  required String trainingExperience,
  required String planDuration,
  required String customButton,
  required String customDuration,
  required String durationExample,
  required String cancel,
  required String resetPlan,
  required String resetDescription,
  required String reset,
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  _setSavedBulkPlan();
  await tester.pumpWidget(_testApp(locale));
  await tester.pumpAndSettle();

  final editButton = find.text(editActivity);
  await tester.ensureVisible(editButton);
  await tester.tap(editButton);
  await tester.pumpAndSettle();

  expect(_dialogText(editSettings), findsOneWidget);
  expect(_dialogText(activityLevel), findsOneWidget);
  expect(_dialogText(trainingExperience), findsOneWidget);
  expect(_dialogText(planDuration), findsOneWidget);

  await tester.tap(_dialogText(customButton));
  await tester.pumpAndSettle();
  expect(_dialogText(customDuration), findsOneWidget);
  expect(find.text(durationExample), findsOneWidget);
  expect(_dialogText(cancel), findsOneWidget);

  await tester.tap(_dialogText(cancel));
  await tester.pumpAndSettle();

  final resetButton = find.text(resetPlan);
  await tester.ensureVisible(resetButton);
  await tester.tap(resetButton);
  await tester.pumpAndSettle();

  expect(_dialogText(resetPlan), findsOneWidget);
  expect(_dialogText(resetDescription), findsOneWidget);
  expect(_dialogText(cancel), findsOneWidget);
  expect(_dialogText(reset), findsOneWidget);
}

void main() {
  test('nutrition plan localization keys have English and Chinese values', () {
    const en = L10n(AppLocale.en);
    const zh = L10n(AppLocale.zh);
    const keys = [
      'nutritionGoalQuestion',
      'nutritionCutDescription',
      'nutritionChooseMethod',
      'carbCycling',
      'beginnerExperience',
      'activityLevel',
      'activitySedentary',
      'trainingFrequency',
      'planDuration',
      'durationWeeksDays',
      'customDuration',
      'dailyTargets',
      'todaysIntake',
      'nextRefeed',
      'cyclePattern',
      'editSettings',
      'trainingExperience',
      'editCyclePattern',
      'presetClassicSevenDay',
      'cycleDayLabel',
      'cycleStartDateHint',
      'resetPlanDescription',
    ];

    for (final key in keys) {
      expect(en.get(key), isNot(key), reason: 'missing English $key');
      expect(zh.get(key), isNot(key), reason: 'missing Chinese $key');
      expect(zh.get(key), isNot(en.get(key)), reason: 'untranslated $key');
    }

    expect(zh.format('trainingFrequency', {'range': '3-4'}), '每周训练 3-4 次');
    expect(
      en.format('durationWeeksDays', {'weeks': '8', 'days': '56'}),
      '8 Weeks (56 days)',
    );
  });

  test(
    'nutrition plan screen does not restore direct visible English copy',
    () {
      final source = File(
        'lib/features/nutrition_plan/screens/nutrition_plan_screen.dart',
      ).readAsStringSync();
      const forbidden = [
        "What's your goal?",
        'Choose your method',
        'Activity Level',
        'Plan Duration',
        'Custom Duration',
        'Daily Targets',
        "Today's Intake",
        'Edit Settings',
        'Reset Plan',
        'Edit Cycle Pattern',
        'Classic 7-Day',
        'Cycle starts from this date',
      ];

      for (final text in forbidden) {
        expect(source, isNot(contains(text)), reason: 'hardcoded copy: $text');
      }
    },
  );

  testWidgets('English nutrition plan dialogs stay consistently localized', (
    tester,
  ) async {
    await _verifyDialogs(
      tester,
      locale: AppLocale.en,
      editActivity: 'Edit Activity',
      editSettings: 'Edit Settings',
      activityLevel: 'Activity Level',
      trainingExperience: 'Training Experience',
      planDuration: 'Plan Duration',
      customButton: 'Custom...',
      customDuration: 'Custom Duration',
      durationExample: 'e.g. 45',
      cancel: 'Cancel',
      resetPlan: 'Reset Plan',
      resetDescription:
          'This will restart the plan selection process. Your current settings will be replaced.',
      reset: 'Reset',
    );
  });

  testWidgets('Chinese nutrition plan dialogs stay consistently localized', (
    tester,
  ) async {
    await _verifyDialogs(
      tester,
      locale: AppLocale.zh,
      editActivity: '编辑活动量',
      editSettings: '编辑设置',
      activityLevel: '活动水平',
      trainingExperience: '训练经验',
      planDuration: '计划时长',
      customButton: '自定义...',
      customDuration: '自定义时长',
      durationExample: '例如 45',
      cancel: '取消',
      resetPlan: '重置计划',
      resetDescription: '这将重新开始计划选择流程，并替换当前设置。',
      reset: '重置',
    );
  });
}
