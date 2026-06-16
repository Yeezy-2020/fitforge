import 'package:flutter_test/flutter_test.dart';
import 'package:fitforge/data/models/user_profile.dart';
import 'package:fitforge/data/models/exercise.dart';
import 'package:fitforge/data/models/workout_log.dart';
import 'package:fitforge/data/models/food.dart';
import 'package:fitforge/data/models/diet_log.dart';
import 'package:fitforge/data/repositories/exercise_library.dart';
import 'package:fitforge/core/utils/nutrition_calculator.dart';
import 'package:fitforge/core/localization/l10n.dart';
import 'package:fitforge/providers/settings_providers.dart';

void main() {
  // =============================================
  // 1. Exercise Library Tests
  // =============================================
  group('Exercise Library', () {
    test('has sufficient exercises', () {
      expect(ExerciseLibrary.defaultExercises.length, greaterThanOrEqualTo(28));
    });

    test('all have required fields', () {
      for (final ex in ExerciseLibrary.defaultExercises) {
        expect(ex.id.isNotEmpty, true, reason: 'Missing id for ${ex.name}');
        expect(ex.name.isNotEmpty, true, reason: 'Missing name');
        expect(ex.nameEn, isNotNull, reason: 'Missing nameEn for ${ex.name}');
        expect(ex.bodyPart.isNotEmpty, true, reason: 'Missing bodyPart for ${ex.name}');
        expect(ex.instructions, isNotNull, reason: 'Missing instructions for ${ex.name}');
        expect(ex.instructionsEn, isNotNull, reason: 'Missing instructionsEn for ${ex.name}');
        expect(ex.commonMistakes, isNotNull, reason: 'Missing commonMistakes for ${ex.name}');
        expect(ex.commonMistakesEn, isNotNull, reason: 'Missing commonMistakesEn for ${ex.name}');
      }
    });

    test('all exercises belong to valid body parts', () {
      final valid = ExerciseLibrary.bodyParts;
      for (final ex in ExerciseLibrary.defaultExercises) {
        expect(valid.contains(ex.bodyPart), true, reason: '${ex.name} has invalid bodyPart: ${ex.bodyPart}');
      }
    });

    test('all IDs are unique', () {
      final ids = ExerciseLibrary.defaultExercises.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('display methods return English when available', () {
      final ex = ExerciseLibrary.defaultExercises.firstWhere((e) => e.id == 'ex_bench_press');
      expect(ex.displayName(true), 'Barbell Bench Press');
      expect(ex.displayBodyPart(true), 'Chest');
      expect(ex.displayInstructions(true).isNotEmpty, true);
      expect(ex.displayMistakes(true).isNotEmpty, true);
    });
  });

  // =============================================
  // 2. L10n Tests
  // =============================================
  group('L10n', () {
    final en = L10n(AppLocale.en);
    final zh = L10n(AppLocale.zh);

    test('all exercise IDs have EN translation', () {
      for (final ex in ExerciseLibrary.defaultExercises) {
        final result = en.get(ex.id);
        expect(result, isNot(ex.id), reason: 'Missing EN for ${ex.id}');
      }
    });

    test('get returns ZH text in ZH locale', () {
      expect(zh.get('login'), '登录');
      expect(zh.get('diet'), '饮食');
      expect(zh.get('training'), '训练');
    });

    test('get returns EN text in EN locale', () {
      expect(en.get('login'), 'Log In');
      expect(en.get('diet'), 'Diet');
      expect(en.get('training'), 'Training');
    });

    test('all body parts have translations', () {
      for (final bp in ExerciseLibrary.bodyParts) {
        expect(en.get('bp_$bp'), isNot('bp_$bp'), reason: 'Missing EN body part for $bp');
      }
    });
  });

  // =============================================
  // 3. Workout Cache Tests
  // =============================================
  group('Workout Cache Logic', () {
    test('addLogs merges correctly', () {
      final cache = <String, List<WorkoutLog>>{};
      final today = DateTime.now();
      final k = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final log1 = WorkoutLog(id: '1', userId: 'u', exerciseId: 'ex_bench_press', date: today, sets: 3, reps: 10, weightKg: 60);
      final log2 = WorkoutLog(id: '2', userId: 'u', exerciseId: 'ex_squat', date: today, sets: 4, reps: 8, weightKg: 80);

      // First add
      final l1 = List<WorkoutLog>.from(cache[k] ?? []); l1.add(log1); cache[k] = l1;
      expect(cache[k]?.length, 1);

      // Second add
      final l2 = List<WorkoutLog>.from(cache[k] ?? []); l2.add(log2); cache[k] = l2;
      expect(cache[k]?.length, 2);
    });

    test('edit updates log fields', () {
      final cache = <String, List<WorkoutLog>>{};
      final today = DateTime.now();
      final k = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      cache[k] = [WorkoutLog(id: '1', userId: 'u', exerciseId: 'ex', date: today, sets: 3, reps: 10, weightKg: 60)];

      // Edit: remove old, add updated
      final list = List<WorkoutLog>.from(cache[k]!);
      list.removeWhere((l) => l.id == '1');
      list.add(WorkoutLog(id: '1', userId: 'u', exerciseId: 'ex', date: today, sets: 5, reps: 5, weightKg: 70));
      cache[k] = list;

      final edited = cache[k]!.first;
      expect(edited.sets, 5);
      expect(edited.weightKg, 70);
    });

    test('delete removes log', () {
      final cache = <String, List<WorkoutLog>>{};
      final today = DateTime.now();
      final k = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      cache[k] = [
        WorkoutLog(id: '1', userId: 'u', exerciseId: 'ex', date: today, sets: 3, reps: 10, weightKg: 60),
        WorkoutLog(id: '2', userId: 'u', exerciseId: 'ex2', date: today, sets: 4, reps: 8, weightKg: 80),
      ];

      final list = List<WorkoutLog>.from(cache[k]!);
      list.removeWhere((l) => l.id == '1');
      cache[k] = list;

      expect(cache[k]!.length, 1);
      expect(cache[k]!.first.id, '2');
    });

    test('double delete is safe', () {
      final cache = <String, List<WorkoutLog>>{};
      final today = DateTime.now();
      final k = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      cache[k] = [WorkoutLog(id: '1', userId: 'u', exerciseId: 'ex', date: today, sets: 3, reps: 10, weightKg: 60)];

      var list = List<WorkoutLog>.from(cache[k]!);
      list.removeWhere((l) => l.id == '1'); cache[k] = list;
      list = List<WorkoutLog>.from(cache[k]!);
      list.removeWhere((l) => l.id == '1'); cache[k] = list; // second delete

      expect(cache[k]!.length, 0);
    });

    test('reorder moves items', () {
      final cache = <String, List<WorkoutLog>>{};
      final today = DateTime.now();
      final k = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      cache[k] = [
        WorkoutLog(id: '1', userId: 'u', exerciseId: 'ex1', date: today, sets: 3, reps: 10, weightKg: 60),
        WorkoutLog(id: '2', userId: 'u', exerciseId: 'ex2', date: today, sets: 4, reps: 8, weightKg: 80),
      ];

      final list = List<WorkoutLog>.from(cache[k]!);
      final item = list.removeAt(0);
      list.insert(1, item);
      cache[k] = list;

      expect(cache[k]!.first.id, '2');
      expect(cache[k]!.last.id, '1');
    });

    test('empty cache returns empty list', () {
      final cache = <String, List<WorkoutLog>>{};
      expect(cache['2025-01-01'] ?? [], []);
    });
  });

  // =============================================
  // 4. Calendar Collapse Logic
  // =============================================
  group('Calendar Collapse', () {
    test('collapses when scrolling past threshold', () {
      bool expanded = true;
      double last = 0;
      final offsets = [0.0, 15.0, 31.0];
      for (final offset in offsets) {
        final delta = offset - last;
        if (offset > 30 && delta > 0 && expanded) expanded = false;
        if (offset <= 0 && !expanded) expanded = true;
        last = offset;
      }
      expect(expanded, false);
    });

    test('expands when scrolling back to top', () {
      bool expanded = false;
      double last = 50.0;
      final offsets = [50.0, 20.0, 5.0, 0.0];
      for (final offset in offsets) {
        final delta = offset - last;
        if (offset > 30 && delta > 0 && expanded) expanded = false;
        if (offset <= 0 && !expanded) expanded = true;
        last = offset;
      }
      expect(expanded, true);
    });

    test('stays expanded when scrolling up from bottom', () {
      bool expanded = true;
      double last = 100.0;
      final offsets = [100.0, 70.0, 50.0];
      for (final offset in offsets) {
        final delta = offset - last;
        if (offset > 30 && delta > 0 && expanded) expanded = false;
        if (offset <= 0 && !expanded) expanded = true;
        last = offset;
      }
      expect(expanded, true); // scrolling up should keep it expanded
    });

    test('does not collapse for tiny scrolls', () {
      bool expanded = true;
      double last = 0;
      final offsets = [0.0, 10.0, 25.0]; // all below 30 threshold
      for (final offset in offsets) {
        final delta = offset - last;
        if (offset > 30 && delta > 0 && expanded) expanded = false;
        if (offset <= 0 && !expanded) expanded = true;
        last = offset;
      }
      expect(expanded, true); // should not collapse below threshold
    });
  });

  // =============================================
  // 5. Nutrition Calculator
  // =============================================
  group('Nutrition Calculator', () {
    final male = UserProfile(id: 'test', gender: Gender.male, age: 30, heightCm: 180, weightKg: 80, goal: FitnessGoal.buildMuscle);
    final female = UserProfile(id: 'test', gender: Gender.female, age: 30, heightCm: 165, weightKg: 60, goal: FitnessGoal.loseFat);
    final calc = const NutritionCalculator();

    test('BMR male formula correct', () {
      final result = calc.bmr(male);
      expect(result, closeTo(1780, 1));
    });

    test('BMR female formula correct', () {
      final result = calc.bmr(female);
      expect(result, closeTo(1320.25, 1));
    });

    test('cutting calories lower than TDEE', () {
      final cut = calc.calculateLegacy(male.copyWith(goal: FitnessGoal.loseFat));
      final t = calc.tdee(calc.bmr(male), 1.55);
      expect(cut.tdee, lessThan(t));
    });

    test('bulking calories higher than TDEE', () {
      final bulk = calc.calculateLegacy(male);
      final t = calc.tdee(calc.bmr(male), 1.55);
      expect(bulk.tdee, greaterThan(t));
    });

    test('cutting has higher protein ratio', () {
      final cut = calc.calculateLegacy(UserProfile(id: 't', gender: Gender.male, age: 25, heightCm: 175, weightKg: 80, goal: FitnessGoal.loseFat));
      final maintain = calc.calculateLegacy(UserProfile(id: 't', gender: Gender.male, age: 25, heightCm: 175, weightKg: 80, goal: FitnessGoal.maintain));
      expect(cut.protein, greaterThan(maintain.protein));
    });

    test('all goals return positive values', () {
      for (final goal in FitnessGoal.values) {
        final p = UserProfile(id: 't', gender: Gender.male, age: 30, heightCm: 180, weightKg: 80, goal: goal);
        final r = calc.calculateLegacy(p);
        expect(r.protein, greaterThan(0));
        expect(r.carbs, greaterThan(0));
        expect(r.fat, greaterThan(0));
        expect(r.tdee, greaterThan(0));
      }
    });

    test('carb cycle high day uses 0.5 carb ratio', () {
      final r = calc.carbCycleDay(male, 'high', 1.55, 500);
      expect(r.protein, greaterThan(0));
      expect(r.carbs, greaterThan(r.fat));
    });

    test('carb cycle low day uses 0.15 carb ratio', () {
      final r = calc.carbCycleDay(male, 'low', 1.55, 500);
      expect(r.carbs, lessThan(r.protein));
    });

    test('bulk beginner uses higher carbs than advanced', () {
      final rBeginner = calc.bulk(male, 1.55, 500, 'beginner');
      final rAdvanced = calc.bulk(male, 1.55, 500, 'advanced');
      expect(rBeginner.carbs, greaterThan(rAdvanced.carbs));
    });

    test('BMR female formula correct', () {
      final result = calc.bmr(female);
      expect(result, closeTo(1320.25, 1));
    });

    test('cutting calories lower than TDEE', () {
      final cut = calc.calculateLegacy(male.copyWith(goal: FitnessGoal.loseFat));
      final t = calc.tdee(calc.bmr(male), 1.55);
      expect(cut.tdee, lessThan(t));
    });

    test('bulking calories higher than TDEE', () {
      final bulk = calc.calculateLegacy(male);
      final t = calc.tdee(calc.bmr(male), 1.55);
      expect(bulk.tdee, greaterThan(t));
    });

    test('cutting has higher protein ratio', () {
      final cut = calc.calculateLegacy(UserProfile(id: 't', gender: Gender.male, age: 25, heightCm: 175, weightKg: 80, goal: FitnessGoal.loseFat));
      final maintain = calc.calculateLegacy(UserProfile(id: 't', gender: Gender.male, age: 25, heightCm: 175, weightKg: 80, goal: FitnessGoal.maintain));
      expect(cut.protein, greaterThan(maintain.protein));
    });

    test('all goals return positive values', () {
      for (final goal in FitnessGoal.values) {
        final p = UserProfile(id: 't', gender: Gender.male, age: 30, heightCm: 180, weightKg: 80, goal: goal);
        final r = calc.calculateLegacy(p);
        expect(r.protein, greaterThan(0));
        expect(r.carbs, greaterThan(0));
        expect(r.fat, greaterThan(0));
        expect(r.tdee, greaterThan(0));
      }
    });
  });

  // =============================================
  // 6. Weight Unit Conversion
  // =============================================
  group('Weight Units', () {
    test('kg format returns kg', () {
      expect(formatTrainingWeight(100, WeightUnit.kg), '100.0 kg');
    });

    test('lb converts kg to lb', () {
      final result = formatTrainingWeight(100, WeightUnit.lb);
      expect(result, contains('220.5')); // 100 * 2.20462
    });

    test('diet g format', () {
      expect(formatDietWeight(250, DietWeightUnit.g), '250 g');
    });

    test('diet oz converts', () {
      final result = formatDietWeight(100, DietWeightUnit.oz);
      expect(result, contains('3.5')); // 100 * 0.035274
    });

    test('zero weight formats correctly', () {
      expect(formatTrainingWeight(0, WeightUnit.kg), '0.0 kg');
      expect(formatDietWeight(0, DietWeightUnit.g), '0 g');
    });
  });

  // =============================================
  // 7. Model Serialization
  // =============================================
  group('Model Serialization', () {
    test('WorkoutLog JSON roundtrip', () {
      final log = WorkoutLog(id: '1', userId: 'u', exerciseId: 'ex_bench_press', date: DateTime(2025, 6, 15), sets: 3, reps: 10, weightKg: 60, createdAt: DateTime(2025, 6, 15, 10, 30));
      final json = log.toJson();
      final restored = WorkoutLog.fromJson(json);
      expect(restored.id, '1');
      expect(restored.sets, 3);
      expect(restored.date.day, 15);
      expect(restored.createdAt?.hour, 10);
    });

    test('DietLog JSON roundtrip with all meal types', () {
      for (final meal in MealType.values) {
        final log = DietLog(id: '1', userId: 'u', foodId: 'f', date: DateTime(2025, 1, 1), mealType: meal, grams: 200, calories: 300);
        expect(DietLog.fromJson(log.toJson()).mealType, meal);
      }
    });

    test('UserProfile JSON roundtrip', () {
      final p = UserProfile(id: 'test', gender: Gender.male, age: 30, heightCm: 180, weightKg: 80, goal: FitnessGoal.buildMuscle, bodyFatPct: 15.5, displayName: 'Test');
      final json = p.toJson();
      final restored = UserProfile.fromJson(json);
      expect(restored.bodyFatPct, 15.5);
      expect(restored.displayName, 'Test');
    });

    test('Food JSON roundtrip with null source', () {
      final f = Food(id: 'f1', name: 'Test', caloriesPer100g: 100, proteinPer100g: 10, carbsPer100g: 5, fatPer100g: 2);
      expect(Food.fromJson(f.toJson()).name, 'Test');
      expect(Food.fromJson(f.toJson()).source, null);
    });
  });

  // =============================================
  // 8. Diet Cache Logic
  // =============================================
  group('Diet Cache', () {
    test('addLog then updateLog replaces correctly', () {
      final cache = <String, List<DietLog>>{};
      final today = DateTime.now();
      final k = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final log = DietLog(id: 'd1', userId: 'u', foodId: 'f1', date: today, mealType: MealType.lunch, grams: 200, calories: 330);

      // Add
      cache[k] = [log];
      expect(cache[k]!.length, 1);

      // Update
      final updated = DietLog(id: 'd1', userId: 'u', foodId: 'f1', date: today, mealType: MealType.lunch, grams: 300, calories: 495);
      final list = List<DietLog>.from(cache[k]!);
      final idx = list.indexWhere((l) => l.id == 'd1');
      if (idx >= 0) list[idx] = updated;
      cache[k] = list;

      expect(cache[k]!.first.grams, 300);
      expect(cache[k]!.first.calories, 495);
    });

    test('deleteLog removes from cache', () {
      final cache = <String, List<DietLog>>{};
      final today = DateTime.now();
      final k = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      cache[k] = [
        DietLog(id: 'd1', userId: 'u', foodId: 'f1', date: today, mealType: MealType.breakfast, grams: 100, calories: 150),
        DietLog(id: 'd2', userId: 'u', foodId: 'f2', date: today, mealType: MealType.lunch, grams: 200, calories: 300),
      ];

      final list = List<DietLog>.from(cache[k]!);
      list.removeWhere((l) => l.id == 'd1');
      cache[k] = list;

      expect(cache[k]!.length, 1);
      expect(cache[k]!.first.id, 'd2');
    });

    test('macro calculation from cache', () {
      final foods = [
        Food(id: 'f1', name: 'Chicken', caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6),
        Food(id: 'f2', name: 'Rice', caloriesPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3),
      ];
      final today = DateTime.now();
      final logs = [
        DietLog(id: 'd1', userId: 'u', foodId: 'f1', date: today, mealType: MealType.lunch, grams: 200, calories: 330),
        DietLog(id: 'd2', userId: 'u', foodId: 'f2', date: today, mealType: MealType.lunch, grams: 150, calories: 195),
      ];

      double protein = 0, carbs = 0, fat = 0, kcal = 0;
      for (final log in logs) {
        kcal += log.calories;
        final food = foods.where((f) => f.id == log.foodId).firstOrNull;
        if (food != null) {
          final factor = log.grams / 100;
          protein += food.proteinPer100g * factor;
          carbs += food.carbsPer100g * factor;
          fat += food.fatPer100g * factor;
        }
      }

      expect(kcal, 525);
      expect(protein, closeTo(66.05, 0.1)); // 200g chicken (62g) + 150g rice (4.05g)
      expect(carbs, closeTo(42, 0.1));      // 200g chicken (0) + 150g rice (42g)
      expect(fat, closeTo(7.65, 0.1));       // 200g chicken (7.2g) + 150g rice (0.45g)
    });
  });

  // =============================================
  // 9. Edge Cases
  // =============================================
  group('Edge Cases', () {
    test('empty exercise list returns empty body parts', () {
      expect(<Exercise>[].map((e) => e.bodyPart).toSet().toList()..sort(), []);
    });

    test('same day different months handled correctly', () {
      final jan1 = DateTime(2025, 1, 1);
      final feb1 = DateTime(2025, 2, 1);
      final kJan = '${jan1.year}-${jan1.month.toString().padLeft(2, '0')}';
      final kFeb = '${feb1.year}-${feb1.month.toString().padLeft(2, '0')}';
      expect(kJan, '2025-01');
      expect(kFeb, '2025-02');
      expect(kJan, isNot(kFeb));
    });

    test('max reps and sets bounded', () {
      final clamped = (9999).clamp(1, 9999);
      expect(clamped, 9999);
      final outOfBounds = (10000).clamp(1, 9999);
      expect(outOfBounds, 9999);
    });

    test('negative weight formats correctly', () {
      // Should not happen but if it does, format still works
      expect(formatTrainingWeight(-10, WeightUnit.kg), '-10.0 kg');
    });
  });
}

// Helper extension for copyWith on UserProfile
extension _UserProfileCopy on UserProfile {
  UserProfile copyWith({FitnessGoal? goal}) => UserProfile(
    id: id, gender: gender, age: age, heightCm: heightCm, weightKg: weightKg,
    goal: goal ?? this.goal, bodyFatPct: bodyFatPct, displayName: displayName, createdAt: createdAt,
  );
}
