import 'package:flutter_test/flutter_test.dart';
import 'package:fitforge/data/models/user_profile.dart';
import 'package:fitforge/data/models/nutrition_plan.dart';
import 'package:fitforge/core/utils/nutrition_calculator.dart';

void main() {
  final male = UserProfile(id: 't', gender: Gender.male, age: 30, heightCm: 180, weightKg: 80, goal: FitnessGoal.buildMuscle);
  final calc = const NutritionCalculator();

  group('Nutrition Module Logic', () {
    test('BMR male formula correct', () {
      expect(calc.bmr(male), closeTo(1780, 1));
    });

    test('TDEE with moderate activity', () {
      final tdee = calc.tdee(calc.bmr(male), 1.55);
      expect(tdee, closeTo(2759, 1));
    });

    test('TEF is 10% of TDEE', () {
      expect(calc.tef(2000), 200);
    });

    test('carb cycle high day has most carbs', () {
      final high = calc.carbCycleDay(male, 'high', 1.55, 500);
      final low = calc.carbCycleDay(male, 'low', 1.55, 500);
      expect(high.carbs, greaterThan(low.carbs));
      expect(low.fat, greaterThan(high.fat));
    });

    test('bulk beginner gets higher carbs', () {
      final beginner = calc.bulk(male, 1.55, 500, 'beginner');
      final advanced = calc.bulk(male, 1.55, 500, 'advanced');
      expect(beginner.carbs, greaterThan(advanced.carbs));
    });

    test('carb taper protein in Helms range', () {
      final r = calc.carbTaper(male, 1.55, 500, 3.0, 1.0);
      expect(r.protein / male.weightKg, greaterThanOrEqualTo(2.0));
      expect(r.protein / male.weightKg, lessThanOrEqualTo(2.5));
    });

    test('all plans return positive values', () {
      for (final dayType in ['high', 'medium', 'low']) {
        final r = calc.carbCycleDay(male, dayType, 1.55, 500);
        expect(r.protein, greaterThan(0));
        expect(r.carbs, greaterThan(0));
        expect(r.fat, greaterThan(0));
      }
      final r2 = calc.carbTaper(male, 1.55, 500, 3.0, 1.0);
      expect(r2.protein, greaterThan(0));
      final r3 = calc.bulk(male, 1.55, 500, 'intermediate');
      expect(r3.protein, greaterThan(0));
    });

    test('NutritionPlanConfig serialization roundtrip', () {
      final c = NutritionPlanConfig(planType: 'carb_cycle', cycleTemplate: ['low', 'medium', 'high'], deficit: 500);
      final restored = NutritionPlanConfig.fromJson(c.toJson());
      expect(restored.planType, 'carb_cycle');
      expect(restored.cycleTemplate!.length, 3);
      expect(restored.deficit, 500);
    });
  });
}
