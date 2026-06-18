import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitforge/data/models/exercise.dart';
import 'package:fitforge/data/models/food.dart';
import 'package:fitforge/data/models/diet_log.dart';
import 'package:fitforge/data/models/user_profile.dart';
import 'package:fitforge/providers/app_providers.dart';
import 'package:fitforge/providers/settings_providers.dart';
import 'package:fitforge/core/localization/l10n.dart';

/// Golden test target size (mobile portrait)
const goldenWidth = 390.0;
const goldenHeight = 844.0;

/// Sample exercises for tests
final testExercises = [
  Exercise(id: 'ex_bench_press', name: '杠铃卧推', nameEn: 'Barbell Bench Press', bodyPart: '胸部', bodyPartEn: 'Chest', targetMuscle: 'Chest', instructions: '1. Lie on bench\n2. Lower bar\n3. Push up', commonMistakes: 'Arching back'),
  Exercise(id: 'ex_squat', name: '杠铃深蹲', nameEn: 'Barbell Squat', bodyPart: '腿部', bodyPartEn: 'Legs', targetMuscle: 'Quads', instructions: '1. Bar on shoulders\n2. Squat down\n3. Stand up', commonMistakes: 'Knees caving in'),
  Exercise(id: 'ex_deadlift', name: '硬拉', nameEn: 'Deadlift', bodyPart: '背部', bodyPartEn: 'Back', targetMuscle: 'Posterior chain', instructions: '1. Grip bar\n2. Pull up\n3. Lock out', commonMistakes: 'Rounded back'),
];

final testProfile = UserProfile(id: 'test', gender: Gender.male, age: 30, heightCm: 180, weightKg: 80, goal: FitnessGoal.buildMuscle);

final testFoods = [
  Food(id: 'food1', name: 'Chicken Breast', caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6),
  Food(id: 'food2', name: 'White Rice', caloriesPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3),
];

final testDietLogs = [
  DietLog(id: 'd1', userId: 'test', foodId: 'food1', date: DateTime.now(), mealType: MealType.lunch, grams: 200, calories: 330),
  DietLog(id: 'd2', userId: 'test', foodId: 'food2', date: DateTime.now(), mealType: MealType.lunch, grams: 150, calories: 195),
];

/// Build a ProviderScope with mocked dependencies for widget testing
Widget testApp({
  required Widget child,
  AppLocale locale = AppLocale.en,
  bool isPro = false,
}) {
  return ProviderScope(
    overrides: [
      localeProvider.overrideWith((ref) => locale),
      isProProvider.overrideWith((ref) {
        final n = IsProNotifier();
        n.state = isPro;
        return n;
      }),
      currentUserIdProvider.overrideWith((ref) => 'test'),
    ],
    child: MaterialApp(
      locale: locale == AppLocale.zh ? const Locale('zh') : const Locale('en'),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: SizedBox(
        width: goldenWidth,
        height: goldenHeight,
        child: child,
      ),
    ),
  );
}

/// Golden test helper
Future<void> expectGolden(WidgetTester tester, Widget widget, String filename) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../goldens/screens/$filename'),
  );
}
