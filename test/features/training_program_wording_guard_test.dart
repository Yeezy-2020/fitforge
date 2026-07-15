import 'dart:io';

import 'package:fitforge/core/localization/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

const _trainingProgramModelPath = 'lib/data/models/training_program.dart';
const _prescriptionCalculatorPath =
    'lib/core/utils/program_prescription_calculator.dart';
const _workoutScreensPath = 'lib/features/workout/screens';
const _sharedProgramUiPath =
    'lib/features/workout/screens/workout_day_screen.dart';
const _sharedProgramL10nKeys = <String>{
  'completeRestDay',
  'deloadDayLabel',
  'extendedBreakDialogBody',
  'extendedBreakDialogTitle',
  'extendedBreakPrompt',
  'programAdvanced',
  'scheduledProgram',
  'todayProgram',
  'useLastLoad',
  'usePlannedLoad',
};

final _englishCalendarWeek = RegExp(r'\bweek(?:s|ly)?\b', caseSensitive: false);
final _chineseNaturalWeekProgression = RegExp(
  r'自然\s*周(?!期)|'
  r'每\s*(?:个\s*)?(?:(?:\d+|[一二两三四五六七八九十]+)\s*)?'
  r'(?:周(?!期)|星期)|'
  r'(?:按|本|上|下|这|一|两|训练)\s*周(?!期)|'
  r'第\s*(?:\d+|[一二两三四五六七八九十]+)\s*周(?!期)|'
  r'周(?!期)\s*(?:进度|增|计划|安排|训练)',
);

void main() {
  test('training-program model keeps week semantics legacy-read-only', () {
    final source = _readProjectFile(_trainingProgramModelPath);
    final code = _withoutDartComments(source);
    final weekNames = RegExp(
      r'[A-Za-z_$][A-Za-z0-9_$]*week[A-Za-z0-9_$]*',
      caseSensitive: false,
    ).allMatches(code).map((match) => match.group(0)).toList();

    expect(
      weekNames,
      equals(const ['periodWeeks']),
      reason:
          'Only the one-time periodWeeks storage compatibility read is allowed; '
          'new fields, identifiers, or JSON keys must use cycle/round semantics.',
    );

    final legacyRead = RegExp(
      r'''json\s*\[\s*['"]periodWeeks['"]\s*\]''',
    ).allMatches(code).toList();
    expect(legacyRead, hasLength(1));

    final fromJsonStart = code.indexOf('factory ProgressionScheme.fromJson');
    final toJsonStart = code.indexOf(
      'Map<String, dynamic> toJson()',
      fromJsonStart,
    );
    expect(fromJsonStart, greaterThanOrEqualTo(0));
    expect(toJsonStart, greaterThan(fromJsonStart));
    expect(
      legacyRead.single.start,
      inInclusiveRange(fromJsonStart, toJsonStart),
    );
    expect(
      code.substring(legacyRead.single.end).trimLeft().startsWith('='),
      isFalse,
      reason: 'periodWeeks must remain a read-only compatibility key.',
    );
  });

  test('Chinese week matcher preserves cycle wording', () {
    for (final wording in const [
      '每周加重',
      '每 1 周加重',
      '每两周加重',
      '每个星期调整',
      '按周进阶',
      '第一周',
      '训练周',
      '周计划',
      '自然周',
    ]) {
      expect(
        _chineseNaturalWeekProgression.hasMatch(wording),
        isTrue,
        reason: 'Expected natural-week wording to be rejected: $wording',
      );
    }
    for (final wording in const ['周期', '训练周期', '每个周期', '按周期进阶']) {
      expect(
        _chineseNaturalWeekProgression.hasMatch(wording),
        isFalse,
        reason: 'Cycle wording must remain allowed: $wording',
      );
    }
  });

  test('program UI localization uses cycle/round wording', () {
    final programUiPaths = _discoverProgramUiPaths();
    final english = const L10n(AppLocale.en);
    final chinese = const L10n(AppLocale.zh);
    final allLocalizedKeys = <String>{};

    expect(
      programUiPaths,
      isNotEmpty,
      reason:
          'This guard must discover program-dedicated workout screen files.',
    );
    expect(
      programUiPaths.map(_basename),
      containsAll(const [
        'program_activation_dialog.dart',
        'program_detail_screen.dart',
        'program_settings_dialog.dart',
        'training_programs_screen.dart',
      ]),
      reason:
          'Discovery should include current program_*.dart screens and '
          'training_programs_screen.dart.',
    );

    for (final path in programUiPaths) {
      final source = _withoutDartComments(_readProjectFile(path));
      final keys = _identifierStringLiterals(source).where((key) {
        return english.get(key) != key || chinese.get(key) != key;
      }).toSet();
      allLocalizedKeys.addAll(keys);

      expect(
        keys,
        isNotEmpty,
        reason: '$path should expose localized literal keys to this guard.',
      );

      for (final key in keys) {
        _expectNoCalendarWeekWording(
          english.get(key),
          label: '$path: L10n(en)[\'$key\']',
        );
        _expectNoCalendarWeekWording(
          chinese.get(key),
          label: '$path: L10n(zh)[\'$key\']',
        );
      }

      _expectNoCalendarWeekWording(source, label: '$path source');
    }

    final sharedSource = _withoutDartComments(
      _readProjectFile(_sharedProgramUiPath),
    );
    final sharedKeys = _identifierStringLiterals(
      sharedSource,
    ).where(_sharedProgramL10nKeys.contains).toSet();
    expect(
      sharedKeys,
      containsAll(_sharedProgramL10nKeys),
      reason: 'Shared workout-day program copy must remain explicitly covered.',
    );
    expect(sharedKeys, hasLength(_sharedProgramL10nKeys.length));
    allLocalizedKeys.addAll(sharedKeys);
    for (final key in sharedKeys) {
      _expectNoCalendarWeekWording(
        english.get(key),
        label: '$_sharedProgramUiPath: L10n(en)[\'$key\']',
      );
      _expectNoCalendarWeekWording(
        chinese.get(key),
        label: '$_sharedProgramUiPath: L10n(zh)[\'$key\']',
      );
    }

    expect(
      allLocalizedKeys,
      containsAll(const [
        'linearPeriodizationHint',
        'activationScheduleLength',
      ]),
      reason:
          'Dynamic program copy should stay covered by discovered screen keys.',
    );
  });

  test('program prescription reasons avoid calendar-week wording', () {
    final source = _withoutDartComments(
      _readProjectFile(_prescriptionCalculatorPath),
    );
    _expectNoCalendarWeekWording(
      source,
      label: 'program prescription calculator source',
    );
  });
}

List<String> _discoverProgramUiPaths() {
  final directory = Directory(_workoutScreensPath);
  expect(
    directory.existsSync(),
    isTrue,
    reason: 'Missing workout screens directory: $_workoutScreensPath',
  );

  final paths =
      directory
          .listSync()
          .whereType<File>()
          .map((file) => file.path.replaceAll('\\', '/'))
          .where((path) {
            final name = _basename(path);
            return (name.startsWith('program_') && name.endsWith('.dart')) ||
                name == 'training_programs_screen.dart';
          })
          .toList()
        ..sort();
  return paths;
}

String _basename(String path) => path.split('/').last;

String _readProjectFile(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Missing project file: $path');
  return file.readAsStringSync();
}

String _withoutDartComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*$', multiLine: true), '');

Iterable<String> _identifierStringLiterals(String source) sync* {
  final patterns = <RegExp>[
    RegExp(r"'([A-Za-z][A-Za-z0-9_]*)'"),
    RegExp(r'"([A-Za-z][A-Za-z0-9_]*)"'),
  ];
  for (final pattern in patterns) {
    for (final match in pattern.allMatches(source)) {
      yield match.group(1)!;
    }
  }
}

void _expectNoCalendarWeekWording(String text, {required String label}) {
  final englishMatch = _englishCalendarWeek.firstMatch(text)?.group(0);
  expect(
    englishMatch,
    isNull,
    reason: '$label contains calendar-week wording: $englishMatch',
  );

  final chineseMatch = _chineseNaturalWeekProgression
      .firstMatch(text)
      ?.group(0);
  expect(
    chineseMatch,
    isNull,
    reason: '$label contains calendar-week wording: $chineseMatch',
  );
}
