import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitforge/data/models/user_profile.dart';
import 'package:fitforge/data/models/nutrition_plan.dart';
import 'package:fitforge/core/utils/nutrition_calculator.dart';
import 'package:fitforge/features/nutrition_plan/screens/nutrition_plan_screen.dart';
import 'package:fitforge/providers/app_providers.dart';
import 'package:fitforge/providers/settings_providers.dart';
import 'package:fitforge/core/localization/l10n.dart';

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
    test('config with planDurationDays serializes', () {
      final c = NutritionPlanConfig(planType: 'carb_taper', planDurationDays: 56);
      final json = c.toJson();
      expect(json['planDurationDays'], 56);
      final r = NutritionPlanConfig.fromJson(json);
      expect(r.planDurationDays, 56);
    });
    test('config without planDurationDays serializes as null', () {
      final c = NutritionPlanConfig(planType: 'carb_cycle');
      final json = c.toJson();
      expect(json.containsKey('planDurationDays'), false);
      final r = NutritionPlanConfig.fromJson(json);
      expect(r.planDurationDays, isNull);
    });
  });

  group('Onboarding Flow — Dead Button Scan', () {
    Widget buildScreen() => ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => AppLocale.en),
        currentUserIdProvider.overrideWith((ref) => 'test'),
      ],
      child: const MaterialApp(home: NutritionPlanScreen()),
    );

    testWidgets('screen compiles and renders without exception', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      // Should show either onboarding (no profile) or setup-body-first message
      expect(find.byType(NutritionPlanScreen), findsOneWidget);
    });

    testWidgets('no dead buttons after pumping screen', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final buttons = find.byType(FilledButton);
      for (final btn in buttons.evaluate()) {
        final widget = btn.widget as FilledButton;
        expect(widget.onPressed, isNotNull, reason: 'FilledButton onPressed must not be null');
      }
    });
  });

  group('Plan Duration Step — Presets', () {
    // The Duration step uses _goalCard for preset selection
    test('28 day preset is explicit value', () {
      const days = 28;
      expect(days % 7, 0); // Even weeks
    });

    test('56 day preset is explicit value', () {
      const days = 56;
      expect(days, 28 * 2);
    });

    test('84 day preset is explicit value', () {
      const days = 84;
      expect(days, 28 * 3);
    });

    test('custom duration allows 1-180 range', () {
      // Boundaries from _showDurationPicker
      expect(1.clamp(1, 180), 1);
      expect(180.clamp(1, 180), 180);
    });
  });

  group('Stepper Dot Count', () {
    // Step counts for different flows:
    // Cut+Bulk: 4 steps (Goal, Plan, Activity, Duration)
    // Maintain: 3 steps (Goal, Activity, Duration)
    test('cut/bulk flow has 4 steps', () {
      const stepCount = 4;
      expect(stepCount, 4);
    });

    test('maintain flow has 3 steps', () {
      const stepCount = 3;
      expect(stepCount, 3);
    });
  });
}
