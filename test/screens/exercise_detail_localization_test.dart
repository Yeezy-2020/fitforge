import 'package:fitforge/core/localization/l10n.dart';
import 'package:fitforge/data/models/exercise.dart';
import 'package:fitforge/features/workout/screens/exercise_detail_screen.dart';
import 'package:fitforge/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'maps built-in categories in both locales and preserves custom values',
    () {
      const en = L10n(AppLocale.en);
      const zh = L10n(AppLocale.zh);

      expect(en.exerciseCategoryName('Strength'), 'Strength');
      expect(en.exerciseCategoryName('Core'), 'Core');
      expect(en.exerciseCategoryName('Cardio'), 'Cardio');
      expect(zh.exerciseCategoryName('Strength'), '力量');
      expect(zh.exerciseCategoryName('Core'), '核心');
      expect(zh.exerciseCategoryName('Cardio'), '有氧');
      expect(zh.exerciseCategoryName('Mobility'), 'Mobility');
    },
  );

  testWidgets('exercise detail consumes localized and custom categories', (
    tester,
  ) async {
    await tester.pumpWidget(
      _exerciseApp(
        locale: AppLocale.zh,
        exercise: _exercise(category: 'Strength'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('力量'), findsOneWidget);
    expect(find.text('Strength'), findsNothing);

    await tester.pumpWidget(
      _exerciseApp(
        locale: AppLocale.en,
        exercise: _exercise(category: 'Strength'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Strength'), findsOneWidget);

    await tester.pumpWidget(
      _exerciseApp(
        locale: AppLocale.zh,
        exercise: _exercise(category: 'Mobility'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mobility'), findsOneWidget);
  });
}

Widget _exerciseApp({required AppLocale locale, required Exercise exercise}) {
  return ProviderScope(
    key: ValueKey('${locale.name}-${exercise.category}'),
    overrides: [localeProvider.overrideWith((ref) => locale)],
    child: MaterialApp(home: ExerciseDetailScreen(exercise: exercise)),
  );
}

Exercise _exercise({required String category}) {
  return Exercise(
    id: 'custom-exercise',
    name: '测试动作',
    nameEn: 'Test Exercise',
    bodyPart: '自定义',
    bodyPartEn: 'Custom',
    category: category,
  );
}
