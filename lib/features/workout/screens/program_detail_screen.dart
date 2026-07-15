import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/training_program_editor.dart';
import '../../../data/models/exercise.dart';
import '../../../data/models/training_program.dart';
import '../../../core/localization/l10n.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';
import 'program_activation_dialog.dart';
import 'program_settings_dialog.dart';

part 'program_detail_deload_dialog.dart';
part 'program_detail_overview_widgets.dart';
part 'program_detail_exercise_dialogs.dart';

int _idSeq = 0;

String _newProgramId() {
  _idSeq += 1;
  return '${DateTime.now().microsecondsSinceEpoch}_$_idSeq';
}

class _ProgramMutation {
  final UserScope userScope;

  const _ProgramMutation({required this.userScope});
}

class ProgramDetailScreen extends ConsumerWidget {
  final String programId;

  const ProgramDetailScreen({super.key, required this.programId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programsAsync = ref.watch(trainingProgramsProvider);
    final exercises = ref.watch(exerciseListProvider).valueOrNull ?? [];
    final l10n = ref.watch(l10nProvider);
    final isEnglish = ref.watch(localeProvider) == AppLocale.en;

    return programsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.get('program'))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.get('failedToLoad')),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(trainingProgramsProvider),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.get('retry')),
              ),
            ],
          ),
        ),
      ),
      data: (programs) {
        final program = programs.where((p) => p.id == programId).firstOrNull;
        if (program == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.get('program'))),
            body: Center(child: Text(l10n.get('programNotFound'))),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(program.name),
            actions: [
              IconButton(
                tooltip: l10n.get('editProgramSettings'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _renameProgram(context, ref, program, l10n),
              ),
              IconButton(
                tooltip: l10n.get('setActive'),
                icon: Icon(
                  program.active
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                ),
                onPressed: program.active
                    ? null
                    : () => _setActiveProgram(context, ref, program, l10n),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _ProgramHeader(
                program: program,
                l10n: l10n,
                onActivate: !program.active
                    ? () => _setActiveProgram(context, ref, program, l10n)
                    : null,
                onPause: program.active
                    ? () => _pauseProgram(context, ref, program, l10n)
                    : null,
                onResume: program.active
                    ? () => _resumeProgram(context, ref, program, l10n)
                    : null,
                onEnd: program.active
                    ? () => _endProgram(context, ref, program, l10n)
                    : null,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 520 ? 1 : 3;
                  final buttonWidth =
                      (constraints.maxWidth - (8 * (columns - 1))) / columns;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: buttonWidth,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.fitness_center, size: 18),
                          label: Text(l10n.get('trainingDayBtn')),
                          onPressed: () =>
                              _addDay(context, ref, program, false, l10n),
                        ),
                      ),
                      SizedBox(
                        width: buttonWidth,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.hotel, size: 18),
                          label: Text(l10n.get('restDayBtn')),
                          onPressed: () =>
                              _addDay(context, ref, program, true, l10n),
                        ),
                      ),
                      SizedBox(
                        width: buttonWidth,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.speed_outlined, size: 18),
                          label: Text(l10n.get('addDeloadDay')),
                          onPressed: () =>
                              _addDeloadDay(context, ref, program, null, l10n),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              if (program.days.isNotEmpty)
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: program.days.length,
                  onReorderItem: (oldIndex, newIndex) =>
                      _reorderDay(ref, program, oldIndex, newIndex),
                  itemBuilder: (context, i) => Padding(
                    key: ValueKey(program.days[i].id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProgramDaySection(
                      program: program,
                      day: program.days[i],
                      dayIndex: i,
                      dragIndex: i,
                      exercises: exercises,
                      isEnglish: isEnglish,
                      l10n: l10n,
                      onEditDay: () => _editDay(context, ref, program, i, l10n),
                      onDeleteDay: () =>
                          _deleteDay(context, ref, program, i, l10n),
                      onAddDeloadAfterDay: () =>
                          _addDeloadDay(context, ref, program, i, l10n),
                      onAddExercise: () => _addExercise(
                        context,
                        ref,
                        program,
                        i,
                        exercises,
                        l10n,
                      ),
                      onEditExercise: (exerciseIndex) => _editProgramExercise(
                        context,
                        ref,
                        program,
                        i,
                        exerciseIndex,
                        exercises,
                        isEnglish,
                        l10n,
                      ),
                      onRemoveExercise: (exerciseIndex) =>
                          _removeExercise(ref, program, i, exerciseIndex),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Center(child: Text(l10n.get('noDaysYet'))),
                ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _renameProgram(
    BuildContext context,
    WidgetRef ref,
    TrainingProgram program,
    L10n l10n,
  ) async {
    final mutation = _captureMutation(ref, program);
    if (mutation == null) return;
    final settings = await showProgramSettingsDialog(
      context: context,
      l10n: l10n,
      title: l10n.get('editProgramSettings'),
      initialName: program.name,
      initialCycleCount: program.plannedCycleCount,
      dayCount: program.days.length,
    );
    if (settings == null) return;
    if (!context.mounted) return;
    if (!_isCurrentMutation(ref, mutation)) return;
    await ref
        .read(trainingProgramsProvider.notifier)
        .save(
          program.copyWith(
            name: settings.name,
            plannedCycleCount: settings.plannedCycleCount,
            clearPlannedCycleCount: settings.plannedCycleCount == null,
            updatedAt: DateTime.now(),
          ),
        );
  }

  static Future<void> _setActiveProgram(
    BuildContext context,
    WidgetRef ref,
    TrainingProgram program,
    L10n l10n,
  ) async {
    final mutation = _captureMutation(ref, program);
    if (mutation == null) return;
    final config = await showProgramActivationDialog(
      context: context,
      l10n: l10n,
      program: program,
    );
    if (config == null) return;
    if (!context.mounted) return;
    if (!_isCurrentMutation(ref, mutation)) return;
    await ref
        .read(trainingProgramsProvider.notifier)
        .setActive(
          program.id,
          activatedAt: config.activatedAt,
          plannedCycleCount: config.cycleCount,
          expectedUserId: program.userId,
        );
  }

  static Future<void> _pauseProgram(
    BuildContext context,
    WidgetRef ref,
    TrainingProgram program,
    L10n l10n,
  ) async {
    final mutation = _captureMutation(ref, program);
    if (mutation == null) return;
    final today = DateTime.now();
    final start = await _pickPlanDate(
      context,
      l10n: l10n,
      titleKey: 'pauseProgram',
      helpKey: 'pauseProgramHelp',
      todayKey: 'fromToday',
      earlierKey: 'chooseEarlierDate',
      pickerHelpKey: 'choosePauseStartDate',
      firstDate: program.activatedAt ?? program.createdAt,
      lastDate: today,
    );
    if (start == null) return;
    if (!context.mounted) return;
    if (!_isCurrentMutation(ref, mutation)) return;
    await ref
        .read(trainingProgramsProvider.notifier)
        .save(program.pauseFrom(start, now: today));
    if (!context.mounted) return;
    if (!_isCurrentMutation(ref, mutation)) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.get('programPaused'))));
  }

  static Future<void> _endProgram(
    BuildContext context,
    WidgetRef ref,
    TrainingProgram program,
    L10n l10n,
  ) async {
    final mutation = _captureMutation(ref, program);
    if (mutation == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.get('endProgram')),
        content: Text(l10n.get('endProgramConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l10n.get('endProgram')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    if (!_isCurrentMutation(ref, mutation)) return;
    await ref
        .read(trainingProgramsProvider.notifier)
        .end(program.id, expectedUserId: program.userId);
    if (!context.mounted) return;
    if (!_isCurrentMutation(ref, mutation)) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.get('programEnded'))));
  }

  static Future<void> _resumeProgram(
    BuildContext context,
    WidgetRef ref,
    TrainingProgram program,
    L10n l10n,
  ) async {
    final mutation = _captureMutation(ref, program);
    if (mutation == null) return;
    final today = DateTime.now();
    final openPause = program.pausePeriods
        .where((period) => period.endDate == null)
        .lastOrNull;
    final resume = await _pickPlanDate(
      context,
      l10n: l10n,
      titleKey: 'resumeProgram',
      helpKey: 'resumeProgramHelp',
      todayKey: 'resumeToday',
      earlierKey: 'resumeFromEarlierDate',
      pickerHelpKey: 'chooseResumeDate',
      firstDate:
          openPause?.startDate ?? program.activatedAt ?? program.createdAt,
      lastDate: today,
    );
    if (resume == null) return;
    if (!context.mounted) return;
    if (!_isCurrentMutation(ref, mutation)) return;
    await ref
        .read(trainingProgramsProvider.notifier)
        .save(program.resumeFrom(resume, now: today));
    if (!context.mounted) return;
    if (!_isCurrentMutation(ref, mutation)) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.get('programResumed'))));
  }

  static Future<DateTime?> _pickPlanDate(
    BuildContext context, {
    required L10n l10n,
    required String titleKey,
    required String helpKey,
    required String todayKey,
    required String earlierKey,
    required String pickerHelpKey,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final useToday = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.get(titleKey)),
        content: Text(l10n.get(helpKey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.get('cancel')),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.get(earlierKey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.get(todayKey)),
          ),
        ],
      ),
    );
    if (useToday == null) return null;
    final today = DateTime(lastDate.year, lastDate.month, lastDate.day);
    if (useToday) return today;
    if (!context.mounted) return null;
    final first = DateTime(firstDate.year, firstDate.month, firstDate.day);
    final picked = await showDatePicker(
      context: context,
      helpText: l10n.get(pickerHelpKey),
      firstDate: first.isAfter(today) ? today : first,
      lastDate: today,
      initialDate: today,
    );
    if (picked == null) return null;
    return DateTime(picked.year, picked.month, picked.day);
  }

  static Future<void> _addDay(
    BuildContext context,
    WidgetRef ref,
    TrainingProgram program,
    bool rest,
    L10n l10n,
  ) async {
    final mutation = _captureMutation(ref, program);
    if (mutation == null) return;
    final controller = TextEditingController(
      text: rest
          ? l10n.get('restDayName')
          : '${l10n.get('trainingDayBtn')} ${program.days.length + 1}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(rest ? l10n.get('addRestDay') : l10n.get('addTrainingDay')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.get('dayName')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.get('add')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (!context.mounted) return;
    if (!_isCurrentMutation(ref, mutation)) return;
    final day = ProgramDay(
      id: _newProgramId(),
      name: name,
      kind: rest ? DayKind.rest : DayKind.training,
    );
    await ref
        .read(trainingProgramsProvider.notifier)
        .save(
          TrainingProgramEditor.appendDay(
            program,
            day,
            editedAt: DateTime.now(),
          ),
        );
  }

  static Future<void> _editDay(
    BuildContext context,
    WidgetRef ref,
    TrainingProgram program,
    int dayIndex,
    L10n l10n,
  ) async {
    final mutation = _captureMutation(ref, program);
    if (mutation == null) return;
    final day = program.days[dayIndex];
    final nameCtrl = TextEditingController(text: day.name);
    var kind = day.kind;
    final result = await showDialog<({String name, DayKind kind})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.get('editDay')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.get('dayName')),
              ),
              const SizedBox(height: 12),
              SegmentedButton<DayKind>(
                segments: [
                  ButtonSegment(
                    value: DayKind.training,
                    label: Text(l10n.get('trainingSeg')),
                    icon: const Icon(Icons.fitness_center),
                  ),
                  ButtonSegment(
                    value: DayKind.rest,
                    label: Text(l10n.get('restSeg')),
                    icon: const Icon(Icons.hotel),
                  ),
                  if (day.kind == DayKind.deload)
                    ButtonSegment(
                      value: DayKind.deload,
                      label: Text(l10n.get('deloadDayLabel')),
                      icon: const Icon(Icons.speed_outlined),
                    ),
                ],
                selected: {kind},
                onSelectionChanged: (value) =>
                    setDialogState(() => kind = value.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.get('cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, (name: nameCtrl.text.trim(), kind: kind)),
              child: Text(l10n.get('save')),
            ),
          ],
        ),
      ),
    );
    if (result == null || result.name.isEmpty) return;
    if (!context.mounted) return;
    if (!_isCurrentMutation(ref, mutation)) return;
    await ref
        .read(trainingProgramsProvider.notifier)
        .save(
          TrainingProgramEditor.updateDay(
            program,
            dayIndex: dayIndex,
            name: result.name,
            kind: result.kind,
            editedAt: DateTime.now(),
          ),
        );
  }

  static Future<void> _deleteDay(
    BuildContext context,
    WidgetRef ref,
    TrainingProgram program,
    int dayIndex,
    L10n l10n,
  ) async {
    final mutation = _captureMutation(ref, program);
    if (mutation == null) return;
    final day = program.days[dayIndex];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.get('deleteDay')),
        content: Text(l10n.format('deleteDayConfirm', {'name': day.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.get('delete')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    if (!_isCurrentMutation(ref, mutation)) return;
    await ref
        .read(trainingProgramsProvider.notifier)
        .save(
          TrainingProgramEditor.deleteDay(
            program,
            dayIndex,
            editedAt: DateTime.now(),
          ),
        );
  }

  static Future<void> _reorderDay(
    WidgetRef ref,
    TrainingProgram program,
    int oldIndex,
    int newIndex,
  ) {
    final mutation = _captureMutation(ref, program);
    if (mutation == null) return Future<void>.value();
    return ref
        .read(trainingProgramsProvider.notifier)
        .save(
          TrainingProgramEditor.reorderDay(
            program,
            oldIndex: oldIndex,
            newIndex: newIndex,
            editedAt: DateTime.now(),
          ),
        );
  }

  static Future<void> _addDeloadDay(
    BuildContext context,
    WidgetRef ref,
    TrainingProgram program,
    int? selectedDayIndex,
    L10n l10n,
  ) async {
    final mutation = _captureMutation(ref, program);
    if (mutation == null) return;
    final baseDays = _regularTrainingDays(program);
    if (baseDays.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.get('noBaseTrainingDay'))));
      return;
    }

    final initialInsertIndex = selectedDayIndex == null
        ? program.days.length
        : (selectedDayIndex + 1).clamp(0, program.days.length).toInt();
    final initialBaseDay =
        _defaultDeloadBaseDay(program, initialInsertIndex) ?? baseDays.first;
    final result =
        await showDialog<
          ({
            int insertIndex,
            ProgramDay baseDay,
            DeloadDayPreset preset,
            double weightPercent,
            double setRatio,
            double repRatio,
          })
        >(
          context: context,
          builder: (ctx) => _DeloadDayDialog(
            program: program,
            selectedDayIndex: selectedDayIndex,
            baseDays: baseDays,
            initialBaseDay: initialBaseDay,
            l10n: l10n,
          ),
        );
    if (result == null) return;
    if (!context.mounted) return;
    if (!_isCurrentMutation(ref, mutation)) return;

    final deloadDay = createDeloadDayFrom(
      baseDay: result.baseDay,
      id: 'deload_${_newProgramId()}',
      name: l10n.format('deloadDayName', {'name': result.baseDay.name}),
      exerciseIdBuilder: (index, source) =>
          'deload_${_newProgramId()}_${index}_${source.id}',
      preset: result.preset,
      weightPercent: result.weightPercent,
      setRatio: result.setRatio,
      repRatio: result.repRatio,
    );
    await ref
        .read(trainingProgramsProvider.notifier)
        .save(
          TrainingProgramEditor.insertDay(
            program,
            dayIndex: result.insertIndex,
            day: deloadDay,
            editedAt: DateTime.now(),
          ),
        );
  }

  static Future<void> _addExercise(
    BuildContext context,
    WidgetRef ref,
    TrainingProgram program,
    int dayIndex,
    List<Exercise> exercises,
    L10n l10n,
  ) async {
    final mutation = _captureMutation(ref, program);
    if (mutation == null) return;
    final selected = await showDialog<Exercise>(
      context: context,
      builder: (ctx) => _ExercisePickerDialog(
        exercises: exercises,
        l10n: l10n,
        isEnglish: l10n.locale == AppLocale.en,
        onCreateExercise: (exercise) {
          if (!context.mounted) return Future<void>.value();
          if (!_isCurrentMutation(ref, mutation)) return Future<void>.value();
          return ref.read(exerciseListProvider.notifier).addExercise(exercise);
        },
      ),
    );
    if (selected == null) return;
    if (!context.mounted) return;
    if (!_isCurrentMutation(ref, mutation)) return;
    final day = program.days[dayIndex];
    final defaultExercise = ProgramExercise(
      id: _newProgramId(),
      exerciseId: selected.id,
      targetSets: 3,
      minReps: 8,
      maxReps: 12,
      startingWeightKg: 0,
      progressionScheme: const ProgressionScheme(
        type: ProgressionSchemeType.doubleProgression,
        weightIncrementKg: 2.5,
      ),
      sortOrder: day.exercises.length,
    );
    final configured = await showDialog<ProgramExercise>(
      context: context,
      builder: (ctx) => _ProgramExerciseDialog(
        exercise: defaultExercise,
        title: selected.displayName(l10n.locale == AppLocale.en),
        l10n: l10n,
      ),
    );
    if (configured == null) return;
    if (!context.mounted) return;
    if (!_isCurrentMutation(ref, mutation)) return;
    await ref
        .read(trainingProgramsProvider.notifier)
        .save(
          TrainingProgramEditor.addExercise(
            program,
            dayIndex: dayIndex,
            exercise: configured,
            editedAt: DateTime.now(),
          ),
        );
  }

  static Future<void> _editProgramExercise(
    BuildContext context,
    WidgetRef ref,
    TrainingProgram program,
    int dayIndex,
    int exerciseIndex,
    List<Exercise> exercises,
    bool isEnglish,
    L10n l10n,
  ) async {
    final mutation = _captureMutation(ref, program);
    if (mutation == null) return;
    final current = program.days[dayIndex].exercises[exerciseIndex];
    final updated = await showDialog<ProgramExercise>(
      context: context,
      builder: (ctx) => _ProgramExerciseDialog(
        exercise: current,
        title: _exerciseName(current.exerciseId, exercises, isEnglish),
        l10n: l10n,
      ),
    );
    if (updated == null) return;
    if (!context.mounted) return;
    if (!_isCurrentMutation(ref, mutation)) return;
    await ref
        .read(trainingProgramsProvider.notifier)
        .save(
          TrainingProgramEditor.updateExercise(
            program,
            dayIndex: dayIndex,
            exerciseIndex: exerciseIndex,
            exercise: updated,
            editedAt: DateTime.now(),
          ),
        );
  }

  static Future<void> _removeExercise(
    WidgetRef ref,
    TrainingProgram program,
    int dayIndex,
    int exerciseIndex,
  ) async {
    final mutation = _captureMutation(ref, program);
    if (mutation == null) return;
    await ref
        .read(trainingProgramsProvider.notifier)
        .save(
          TrainingProgramEditor.deleteExercise(
            program,
            dayIndex: dayIndex,
            exerciseIndex: exerciseIndex,
            editedAt: DateTime.now(),
          ),
        );
  }

  static _ProgramMutation? _captureMutation(
    WidgetRef ref,
    TrainingProgram program,
  ) {
    final userScope = ref.read(currentUserScopeProvider);
    if (userScope.userId.isEmpty || userScope.userId != program.userId) {
      return null;
    }
    return _ProgramMutation(userScope: userScope);
  }

  static bool _isCurrentMutation(WidgetRef ref, _ProgramMutation mutation) {
    final currentScope = ref.read(currentUserScopeProvider);
    return identical(currentScope, mutation.userScope) &&
        currentScope.userId == mutation.userScope.userId;
  }
}
