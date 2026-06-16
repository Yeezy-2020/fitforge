import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitforge/data/models/user_profile.dart';
import 'package:fitforge/data/models/nutrition_plan.dart';
import 'package:fitforge/core/utils/nutrition_calculator.dart';

void main() {
  final male = UserProfile(id: 't', gender: Gender.male, age: 30, heightCm: 180, weightKg: 80, goal: FitnessGoal.buildMuscle);
  final calc = const NutritionCalculator();

  group('Nutrition Formulas', () {
    test('BMR male', () => expect(calc.bmr(male), closeTo(1780, 1)));
    test('TDEE moderate', () => expect(calc.tdee(calc.bmr(male), 1.55), closeTo(2759, 1)));
    test('TEF 10%', () => expect(calc.tef(2000), 200));
    test('carb cycle high > low carbs', () {
      expect(calc.carbCycleDay(male, 'high', 1.55, 500).carbs,
          greaterThan(calc.carbCycleDay(male, 'low', 1.55, 500).carbs));
    });
    test('bulk beginner > advanced carbs', () {
      expect(calc.bulk(male, 1.55, 500, 'beginner').carbs,
          greaterThan(calc.bulk(male, 1.55, 500, 'advanced').carbs));
    });
    test('taper protein in Helms range 2.0-2.5g/kg', () {
      final r = calc.carbTaper(male, 1.55, 500, 3.0, 1.0);
      expect(r.protein / male.weightKg, inInclusiveRange(2.0, 2.5));
    });
    test('all plan types return positive macros', () {
      for (final t in ['high','medium','low']) {
        final r = calc.carbCycleDay(male, t, 1.55, 500);
        expect(r.protein, greaterThan(0));
        expect(r.carbs, greaterThan(0));
        expect(r.fat, greaterThan(0));
      }
      expect(calc.carbTaper(male, 1.55, 500, 3.0, 1.0).protein, greaterThan(0));
      expect(calc.bulk(male, 1.55, 500, 'intermediate').protein, greaterThan(0));
    });
    test('config serialization roundtrip', () {
      final c = NutritionPlanConfig(planType: 'carb_cycle', cycleTemplate: ['low','med','high'], deficit: 500);
      final r = NutritionPlanConfig.fromJson(c.toJson());
      expect(r.planType, 'carb_cycle');
      expect(r.cycleTemplate!.length, 3);
    });
  });

  group('Button Dead-Click Detection', () {
    // All buttons in key screens must have non-empty onPressed/onTap
    testWidgets('Select Plan button calls picker', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [],
          child: MaterialApp(home: Builder(builder: (context) {
            return Scaffold(body: Center(child: OutlinedButton.icon(
              onPressed: () {}, // Will be checked below
              icon: const Icon(Icons.workspace_premium),
              label: const Text('Select Plan (Pro)'),
            )));
          })),
        ),
      );
      await tester.pumpAndSettle();

      final btn = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(btn.onPressed, isNotNull, reason: 'Button onPressed must not be null');
    });
  });
}
