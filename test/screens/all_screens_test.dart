import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitforge/features/auth/screens/login_screen.dart';
import 'package:fitforge/features/auth/screens/onboarding_screen.dart';
import 'package:fitforge/features/settings/screens/settings_screen.dart';
import 'package:fitforge/features/workout/screens/exercise_detail_screen.dart';
import 'package:fitforge/core/localization/l10n.dart';
import '../test_helpers.dart';

void main() {
  group('Golden Tests - LoginScreen', () {
    testWidgets('EN', (tester) async {
      await expectGolden(tester, testApp(child: const LoginScreen()), 'login_en.png');
    });
    testWidgets('ZH', (tester) async {
      await expectGolden(tester, testApp(child: const LoginScreen(), locale: AppLocale.zh), 'login_zh.png');
    });
  });

  group('Golden Tests - OnboardingScreen', () {
    testWidgets('EN', (tester) async {
      await expectGolden(tester, testApp(child: const OnboardingScreen()), 'onboarding_en.png');
    });
    testWidgets('ZH', (tester) async {
      await expectGolden(tester, testApp(child: const OnboardingScreen(), locale: AppLocale.zh), 'onboarding_zh.png');
    });
  });

  group('Golden Tests - SettingsScreen', () {
    testWidgets('EN', (tester) async {
      await expectGolden(tester, testApp(child: const SettingsScreen()), 'settings_en.png');
    });
    testWidgets('ZH', (tester) async {
      await expectGolden(tester, testApp(child: const SettingsScreen(), locale: AppLocale.zh), 'settings_zh.png');
    });
  });

  group('Golden Tests - ExerciseDetailScreen', () {
    testWidgets('EN', (tester) async {
      await expectGolden(tester,
        testApp(child: ExerciseDetailScreen(exercise: testExercises.first)),
        'exercise_detail_en.png',
      );
    });
    testWidgets('ZH', (tester) async {
      await expectGolden(tester,
        testApp(child: ExerciseDetailScreen(exercise: testExercises.first), locale: AppLocale.zh),
        'exercise_detail_zh.png',
      );
    });
  });
}
