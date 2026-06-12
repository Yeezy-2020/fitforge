import 'package:flutter_test/flutter_test.dart';
import 'package:fitforge/data/models/user_profile.dart';
import 'package:fitforge/data/models/exercise.dart';
import 'package:fitforge/data/models/diet_log.dart';
import 'package:fitforge/core/utils/nutrition_calculator.dart';
import 'package:fitforge/core/localization/l10n.dart';
import 'package:fitforge/providers/settings_providers.dart';

void main() {
  group('Models', () {
    test('UserProfile roundtrip', () {
      final p = UserProfile(id: 't', gender: Gender.male, age: 30, heightCm: 180, weightKg: 80, goal: FitnessGoal.buildMuscle);
      expect(UserProfile.fromJson(p.toJson()).age, 30);
    });
    test('Exercise toJson', () {
      final ex = Exercise(id: '1', name: '卧推', bodyPart: '胸部');
      expect(ex.toJson()['name'], '卧推');
    });
    test('DietLog mealType serialization', () {
      final log = DietLog(id: '1', userId: 'u', foodId: 'f', date: DateTime(2025, 1, 1), mealType: MealType.breakfast, grams: 200, calories: 300);
      expect(DietLog.fromJson(log.toJson()).mealType, MealType.breakfast);
    });
  });

  group('NutritionCalculator', () {
    final profile = UserProfile(id: 't', gender: Gender.male, age: 25, heightCm: 175, weightKg: 80, goal: FitnessGoal.loseFat);
    test('cutting generates lower calories than maintain', () {
      final cut = const NutritionCalculator().calculate(profile);
      final maintain = const NutritionCalculator().calculate(UserProfile(id: 't', gender: Gender.male, age: 25, heightCm: 175, weightKg: 80, goal: FitnessGoal.maintain));
      expect(cut.tdee, lessThan(maintain.tdee));
    });
    test('cutting protein higher than maintain', () {
      final cut = const NutritionCalculator().calculate(profile);
      final maintain = const NutritionCalculator().calculate(UserProfile(id: 't', gender: Gender.male, age: 25, heightCm: 175, weightKg: 80, goal: FitnessGoal.maintain));
      expect(cut.protein, greaterThan(maintain.protein));
    });
  });

  group('L10n', () {
    test('EN returns key when not found', () {
      expect(L10n(AppLocale.en).get('nonexistent'), 'nonexistent');
    });
    test('ZH exercise name', () {
      expect(L10n(AppLocale.zh).exerciseName('ex_bench_press', '杠铃卧推'), '杠铃卧推');
    });
    test('EN exercise name translates', () {
      expect(L10n(AppLocale.en).exerciseName('ex_bench_press', '杠铃卧推'), 'Barbell Bench Press');
    });
    test('ZH body part name', () {
      expect(L10n(AppLocale.zh).bodyPartName('胸部'), '胸部');
    });
    test('EN body part name translates', () {
      expect(L10n(AppLocale.en).bodyPartName('胸部'), 'Chest');
    });
    test('all 29 exercise keys have EN translation', () {
      final en = L10n(AppLocale.en);
      for (final id in ['ex_bench_press','ex_dumbbell_press','ex_incline_press','ex_cable_fly','ex_pushup','ex_pullup','ex_barbell_row','ex_lat_pulldown','ex_deadlift','ex_seated_row','ex_squat','ex_legpress','ex_romanian_deadlift','ex_lunge','ex_leg_curl','ex_shoulder_press','ex_lateral_raise','ex_front_raise','ex_face_pull','ex_bicep_curl','ex_hammer_curl','ex_tricep_pushdown','ex_skull_crusher','ex_plank','ex_crunch','ex_leg_raise','ex_russian_twist','ex_treadmill','ex_cycling','ex_jump_rope']) {
        final result = en.get(id);
        expect(result, isNot(id), reason: 'Missing EN translation for $id');
      }
    });
  });

  group('WeightUnit', () {
    test('kg format', () {
      expect(formatTrainingWeight(80.5, WeightUnit.kg), '80.5 kg');
    });
    test('lb converts correctly', () {
      final result = formatTrainingWeight(80.0, WeightUnit.lb);
      expect(result, contains('176.4 lb'));
    });
    test('diet weight g format', () {
      expect(formatDietWeight(200, DietWeightUnit.g), '200 g');
    });
    test('diet weight oz converts', () {
      expect(formatDietWeight(200, DietWeightUnit.oz), '7.1 oz');
    });
  });
}
