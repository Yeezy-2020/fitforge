import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/exercise.dart';
import '../../../data/models/training_program.dart';
import '../../../core/localization/l10n.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';
import 'program_activation_dialog.dart';
import 'program_settings_dialog.dart';

int _idSeq = 0;

String _newProgramId() {
  _idSeq += 1;
  return '${DateTime.now().microsecondsSinceEpoch}_$_idSeq';
}

enum _DeloadInsertPosition { afterSelectedDay, endOfCycle }

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
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.get('program'))),
        body: Center(child: Text('${l10n.get('failedToLoad')}: $error')),
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
    final settings = await showProgramSettingsDialog(
      context: context,
      l10n: l10n,
      title: l10n.get('editProgramSettings'),
      initialName: program.name,
      initialCycleCount: program.plannedCycleCount,
      dayCount: program.days.length,
    );
    if (settings == null) return;
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
    final config = await showProgramActivationDialog(
      context: context,
      l10n: l10n,
      program: program,
    );
    if (config == null) return;
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
    await ref
        .read(trainingProgramsProvider.notifier)
        .save(program.pauseFrom(start, now: today));
    if (!context.mounted) return;
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
    await ref
        .read(trainingProgramsProvider.notifier)
        .end(program.id, expectedUserId: program.userId);
    if (!context.mounted) return;
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
    await ref
        .read(trainingProgramsProvider.notifier)
        .save(program.resumeFrom(resume, now: today));
    if (!context.mounted) return;
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
    final day = ProgramDay(
      id: _newProgramId(),
      name: name,
      kind: rest ? DayKind.rest : DayKind.training,
    );
    await _saveProgram(
      ref,
      program.copyWith(days: [...program.days, day], updatedAt: DateTime.now()),
    );
  }

  static Future<void> _editDay(
    BuildContext context,
    WidgetRef ref,
    TrainingProgram program,
    int dayIndex,
    L10n l10n,
  ) async {
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
    final days = [...program.days];
    days[dayIndex] = day.copyWith(
      name: result.name,
      kind: result.kind,
      exercises: result.kind == DayKind.rest ? const [] : day.exercises,
    );
    await _saveProgram(
      ref,
      program.copyWith(days: days, updatedAt: DateTime.now()),
    );
  }

  static Future<void> _deleteDay(
    BuildContext context,
    WidgetRef ref,
    TrainingProgram program,
    int dayIndex,
    L10n l10n,
  ) async {
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
    await _saveProgram(ref, program.removeDayAt(dayIndex));
  }

  static Future<void> _reorderDay(
    WidgetRef ref,
    TrainingProgram program,
    int oldIndex,
    int newIndex,
  ) {
    return _saveProgram(
      ref,
      program.reorderDay(oldIndex, newIndex, reorderedAt: DateTime.now()),
    );
  }

  static Future<void> _addDeloadDay(
    BuildContext context,
    WidgetRef ref,
    TrainingProgram program,
    int? selectedDayIndex,
    L10n l10n,
  ) async {
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
    await _saveProgram(
      ref,
      program.insertDayAt(
        result.insertIndex,
        deloadDay,
        insertedAt: DateTime.now(),
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
    final selected = await showDialog<Exercise>(
      context: context,
      builder: (ctx) => _ExercisePickerDialog(
        exercises: exercises,
        l10n: l10n,
        isEnglish: l10n.locale == AppLocale.en,
        onCreateExercise: (exercise) =>
            ref.read(exerciseListProvider.notifier).addExercise(exercise),
      ),
    );
    if (selected == null) return;
    if (!context.mounted) return;
    final days = [...program.days];
    final day = days[dayIndex];
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
    days[dayIndex] = day.copyWith(
      exercises: [
        ...day.exercises,
        configured.copyWith(sortOrder: day.exercises.length),
      ],
    );
    var updatedProgram = program.copyWith(
      days: days,
      updatedAt: DateTime.now(),
    );
    if (day.kind == DayKind.training) {
      updatedProgram = updatedProgram.refreshLinkedDeloadsForDay(
        day.id,
        refreshedAt: DateTime.now(),
      );
    }
    await _saveProgram(ref, updatedProgram);
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
    final days = [...program.days];
    final day = days[dayIndex];
    final dayExercises = [...day.exercises];
    dayExercises[exerciseIndex] = updated;
    days[dayIndex] = day.copyWith(exercises: dayExercises);
    var updatedProgram = program.copyWith(
      days: days,
      updatedAt: DateTime.now(),
    );
    if (day.kind == DayKind.training) {
      updatedProgram = updatedProgram.refreshLinkedDeloadsForDay(
        day.id,
        refreshedAt: DateTime.now(),
      );
    }
    await _saveProgram(ref, updatedProgram);
  }

  static Future<void> _removeExercise(
    WidgetRef ref,
    TrainingProgram program,
    int dayIndex,
    int exerciseIndex,
  ) async {
    final days = [...program.days];
    final day = days[dayIndex];
    final exercises = [...day.exercises]..removeAt(exerciseIndex);
    days[dayIndex] = day.copyWith(
      exercises: [
        for (var i = 0; i < exercises.length; i++)
          exercises[i].copyWith(sortOrder: i),
      ],
    );
    var updatedProgram = program.copyWith(
      days: days,
      updatedAt: DateTime.now(),
    );
    if (day.kind == DayKind.training) {
      updatedProgram = updatedProgram.refreshLinkedDeloadsForDay(
        day.id,
        refreshedAt: DateTime.now(),
      );
    }
    await _saveProgram(ref, updatedProgram);
  }

  static Future<void> _saveProgram(WidgetRef ref, TrainingProgram program) {
    return ref.read(trainingProgramsProvider.notifier).save(program);
  }
}

class _DeloadDayDialog extends StatefulWidget {
  final TrainingProgram program;
  final int? selectedDayIndex;
  final List<ProgramDay> baseDays;
  final ProgramDay initialBaseDay;
  final L10n l10n;

  const _DeloadDayDialog({
    required this.program,
    required this.selectedDayIndex,
    required this.baseDays,
    required this.initialBaseDay,
    required this.l10n,
  });

  @override
  State<_DeloadDayDialog> createState() => _DeloadDayDialogState();
}

class _DeloadDayDialogState extends State<_DeloadDayDialog> {
  final _weightPercentCtrl = TextEditingController(text: '70');
  final _setRatioCtrl = TextEditingController(text: '100');
  final _repRatioCtrl = TextEditingController(text: '100');
  late _DeloadInsertPosition _position;
  late ProgramDay _baseDay;
  DeloadDayPreset _preset = DeloadDayPreset.standard;
  String? _error;

  @override
  void initState() {
    super.initState();
    _position = widget.selectedDayIndex == null
        ? _DeloadInsertPosition.endOfCycle
        : _DeloadInsertPosition.afterSelectedDay;
    _baseDay = widget.initialBaseDay;
  }

  @override
  void dispose() {
    _weightPercentCtrl.dispose();
    _setRatioCtrl.dispose();
    _repRatioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = <Widget>[
      _insertPositionField(),
      _baseDayField(),
      _presetField(),
      _summary(theme),
      if (_preset == DeloadDayPreset.custom) _customFields(),
      if (_error != null)
        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
    ];

    return AlertDialog(
      title: Text(widget.l10n.get('addDeloadDay')),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.l10n.get('deloadDayHelp'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                fields[i],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.l10n.get('cancel')),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.l10n.get('createDeloadDay')),
        ),
      ],
    );
  }

  Widget _insertPositionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.l10n.get('insertPosition')),
        const SizedBox(height: 6),
        SegmentedButton<_DeloadInsertPosition>(
          segments: [
            ButtonSegment(
              value: _DeloadInsertPosition.afterSelectedDay,
              label: Text(widget.l10n.get('afterSelectedDay')),
            ),
            ButtonSegment(
              value: _DeloadInsertPosition.endOfCycle,
              label: Text(widget.l10n.get('endOfCycle')),
            ),
          ],
          selected: {_position},
          onSelectionChanged: widget.selectedDayIndex == null
              ? null
              : (value) {
                  final nextPosition = value.first;
                  setState(() {
                    _position = nextPosition;
                    _baseDay =
                        _defaultDeloadBaseDay(
                          widget.program,
                          _insertIndexFor(nextPosition),
                        ) ??
                        widget.baseDays.first;
                    _error = null;
                  });
                },
        ),
      ],
    );
  }

  Widget _baseDayField() {
    return DropdownButtonFormField<ProgramDay>(
      initialValue: _baseDay,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: widget.l10n.get('baseTrainingDay'),
      ),
      items: [
        for (final day in widget.baseDays)
          DropdownMenuItem(value: day, child: Text(day.name)),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _baseDay = value;
          _error = null;
        });
      },
    );
  }

  Widget _presetField() {
    return DropdownButtonFormField<DeloadDayPreset>(
      initialValue: _preset,
      isExpanded: true,
      decoration: InputDecoration(labelText: widget.l10n.get('deloadPreset')),
      items: [
        DropdownMenuItem(
          value: DeloadDayPreset.standard,
          child: Text(widget.l10n.get('standardDeload')),
        ),
        DropdownMenuItem(
          value: DeloadDayPreset.volume,
          child: Text(widget.l10n.get('volumeDeload')),
        ),
        DropdownMenuItem(
          value: DeloadDayPreset.custom,
          child: Text(widget.l10n.get('customDeload')),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _preset = value;
          _error = null;
        });
      },
    );
  }

  Widget _summary(ThemeData theme) {
    final key = switch (_preset) {
      DeloadDayPreset.standard => 'standardDeloadSummary',
      DeloadDayPreset.volume => 'volumeDeloadSummary',
      DeloadDayPreset.custom => 'customDeloadSummary',
    };
    return Text(
      widget.l10n.get(key),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outline,
      ),
    );
  }

  Widget _customFields() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 132,
          child: _ratioField(_weightPercentCtrl, 'loadPercent'),
        ),
        SizedBox(width: 132, child: _ratioField(_setRatioCtrl, 'setRatio')),
        SizedBox(width: 132, child: _ratioField(_repRatioCtrl, 'repRatio')),
      ],
    );
  }

  Widget _ratioField(TextEditingController controller, String labelKey) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.l10n.get(labelKey),
        suffixText: '%',
      ),
    );
  }

  int _insertIndexFor(_DeloadInsertPosition position) {
    if (position == _DeloadInsertPosition.endOfCycle) {
      return widget.program.days.length;
    }
    final selected = widget.selectedDayIndex;
    if (selected == null) return widget.program.days.length;
    return (selected + 1).clamp(0, widget.program.days.length).toInt();
  }

  void _save() {
    final weightPercent = switch (_preset) {
      DeloadDayPreset.standard => 70.0,
      DeloadDayPreset.volume => 70.0,
      DeloadDayPreset.custom => double.tryParse(_weightPercentCtrl.text),
    };
    final setRatio = switch (_preset) {
      DeloadDayPreset.standard => 1.0,
      DeloadDayPreset.volume => 1.0,
      DeloadDayPreset.custom =>
        (double.tryParse(_setRatioCtrl.text) ?? 0) / 100,
    };
    final repRatio = switch (_preset) {
      DeloadDayPreset.standard => 1.0,
      DeloadDayPreset.volume => 0.5,
      DeloadDayPreset.custom =>
        (double.tryParse(_repRatioCtrl.text) ?? 0) / 100,
    };

    if (weightPercent == null ||
        weightPercent <= 0 ||
        weightPercent > 100 ||
        setRatio <= 0 ||
        setRatio > 1 ||
        repRatio <= 0 ||
        repRatio > 1) {
      setState(() => _error = widget.l10n.get('invalidConfig'));
      return;
    }

    Navigator.pop(context, (
      insertIndex: _insertIndexFor(_position),
      baseDay: _baseDay,
      preset: _preset,
      weightPercent: weightPercent,
      setRatio: setRatio,
      repRatio: repRatio,
    ));
  }
}

class _ProgramHeader extends StatelessWidget {
  final TrainingProgram program;
  final L10n l10n;
  final VoidCallback? onActivate;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onEnd;

  const _ProgramHeader({
    required this.program,
    required this.l10n,
    required this.onActivate,
    required this.onPause,
    required this.onResume,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trainingDays = program.days
        .where((d) => d.kind == DayKind.training || d.kind == DayKind.deload)
        .length;
    final restDays = program.days.length - trainingDays;
    final isPaused = program.isPausedNow();
    final isScheduled = _isProgramScheduled(program);
    final openPause = program.pausePeriods
        .where((period) => period.endDate == null)
        .lastOrNull;
    final status = isPaused
        ? l10n.format('pausedSince', {
            'date': l10n.shortDate(openPause?.startDate ?? DateTime.now()),
          })
        : isScheduled
        ? l10n.format('scheduledStartDate', {
            'date': l10n.shortDate(program.activatedAt!),
          })
        : program.active
        ? l10n.get('active')
        : l10n.get('program');
    final cycles = program.plannedCycleCount;
    final plannedEnd = program.plannedEndDate();
    final durationText = cycles == null
        ? l10n.get('plannedContinuously')
        : program.active && plannedEnd != null
        ? l10n.format('plannedThrough', {'date': l10n.shortDate(plannedEnd)})
        : l10n.format('plannedCycles', {'count': cycles.toString()});
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPaused
                      ? Icons.pause_circle_outline
                      : isScheduled
                      ? Icons.event_available
                      : program.active
                      ? Icons.check_circle
                      : Icons.assignment_outlined,
                  color: isPaused
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.format('trainingDaysCount', {
                'training': trainingDays.toString(),
                'rest': restDays.toString(),
              }),
              style: theme.textTheme.bodyMedium,
            ),
            if (!isScheduled) ...[
              const SizedBox(height: 2),
              Text(
                l10n.format('currentDayN', {
                  'n': (program.normalizedCurrentDayIndex + 1).toString(),
                }),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: 2),
            Text(
              durationText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!program.active)
                  FilledButton.icon(
                    onPressed: onActivate,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(l10n.get('activateProgram')),
                  ),
                if (program.active)
                  if (isScheduled)
                    OutlinedButton.icon(
                      onPressed: onEnd,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      icon: const Icon(Icons.event_busy, size: 18),
                      label: Text(l10n.get('endProgram')),
                    )
                  else if (isPaused)
                    FilledButton.icon(
                      onPressed: onResume,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(l10n.get('resumeProgram')),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: onPause,
                      icon: const Icon(Icons.pause, size: 18),
                      label: Text(l10n.get('pauseProgram')),
                    ),
                if (program.active && !isScheduled)
                  OutlinedButton.icon(
                    onPressed: onEnd,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: Text(l10n.get('endProgram')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramDaySection extends StatelessWidget {
  final TrainingProgram program;
  final ProgramDay day;
  final int dayIndex;
  final int dragIndex;
  final List<Exercise> exercises;
  final bool isEnglish;
  final L10n l10n;
  final VoidCallback onEditDay;
  final VoidCallback onDeleteDay;
  final VoidCallback onAddDeloadAfterDay;
  final VoidCallback onAddExercise;
  final void Function(int exerciseIndex) onEditExercise;
  final void Function(int exerciseIndex) onRemoveExercise;

  const _ProgramDaySection({
    required this.program,
    required this.day,
    required this.dayIndex,
    required this.dragIndex,
    required this.exercises,
    required this.isEnglish,
    required this.l10n,
    required this.onEditDay,
    required this.onDeleteDay,
    required this.onAddDeloadAfterDay,
    required this.onAddExercise,
    required this.onEditExercise,
    required this.onRemoveExercise,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRest = day.kind == DayKind.rest;
    final isDeload = day.kind == DayKind.deload;
    final sortedExercises = [...day.exercises]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDelayedDragStartListener(
                  index: dragIndex,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRest
                            ? Icons.hotel
                            : isDeload
                            ? Icons.speed_outlined
                            : Icons.fitness_center,
                        size: 20,
                        color: isDeload
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableDelayedDragStartListener(
                    index: dragIndex,
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        l10n.format('daySectionN', {
                          'n': (dayIndex + 1).toString(),
                          'name': day.name,
                        }),
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.get('addDeloadDay'),
                  icon: const Icon(Icons.playlist_add, size: 20),
                  onPressed: onAddDeloadAfterDay,
                ),
                IconButton(
                  tooltip: l10n.get('editDay'),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEditDay,
                ),
                IconButton(
                  tooltip: l10n.get('deleteDay'),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onDeleteDay,
                ),
              ],
            ),
            if (isRest)
              ReorderableDelayedDragStartListener(
                index: dragIndex,
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(l10n.get('restDay')),
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              if (isDeload) ...[
                ReorderableDelayedDragStartListener(
                  index: dragIndex,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      l10n.get('deloadDaySubtitle'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (sortedExercises.isEmpty)
                ReorderableDelayedDragStartListener(
                  index: dragIndex,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      l10n.get('noExercisesInDay'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                )
              else
                for (var i = 0; i < sortedExercises.length; i++)
                  _ProgramExerciseTile(
                    dragIndex: dragIndex,
                    exercise: sortedExercises[i],
                    name: _exerciseName(
                      sortedExercises[i].exerciseId,
                      exercises,
                      isEnglish,
                    ),
                    l10n: l10n,
                    onEdit: () => onEditExercise(
                      day.exercises.indexWhere(
                        (e) => e.id == sortedExercises[i].id,
                      ),
                    ),
                    onRemove: () => onRemoveExercise(
                      day.exercises.indexWhere(
                        (e) => e.id == sortedExercises[i].id,
                      ),
                    ),
                  ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.get('addExerciseToDay')),
                  onPressed: onAddExercise,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<ProgramDay> _regularTrainingDays(TrainingProgram program) {
  return program.days.where((day) => day.kind == DayKind.training).toList();
}

bool _isProgramScheduled(TrainingProgram program) {
  final activatedAt = program.activatedAt;
  if (!program.active || activatedAt == null) return false;
  return _dateOnly(activatedAt).isAfter(_dateOnly(DateTime.now()));
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

ProgramDay? _defaultDeloadBaseDay(TrainingProgram program, int insertIndex) {
  final end = insertIndex.clamp(0, program.days.length).toInt();
  for (var i = end - 1; i >= 0; i--) {
    final day = program.days[i];
    if (day.kind == DayKind.training) return day;
  }
  return _regularTrainingDays(program).firstOrNull;
}

class _ProgramExerciseTile extends StatelessWidget {
  final int dragIndex;
  final ProgramExercise exercise;
  final String name;
  final L10n l10n;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ProgramExerciseTile({
    required this.dragIndex,
    required this.exercise,
    required this.name,
    required this.l10n,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = _programExerciseSubtitle(exercise, l10n);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: ReorderableDelayedDragStartListener(
        index: dragIndex,
        child: SizedBox(
          width: double.infinity,
          child: Text(name, overflow: TextOverflow.ellipsis),
        ),
      ),
      subtitle: ReorderableDelayedDragStartListener(
        index: dragIndex,
        child: SizedBox(width: double.infinity, child: Text(subtitle)),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') onEdit();
          if (value == 'remove') onRemove();
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'edit', child: Text(l10n.get('editEx'))),
          PopupMenuItem(
            value: 'remove',
            child: Text(
              l10n.get('removeEx'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ExercisePickerMode { existing, custom }

class _ExercisePickerDialog extends StatefulWidget {
  final List<Exercise> exercises;
  final L10n l10n;
  final bool isEnglish;
  final Future<void> Function(Exercise exercise) onCreateExercise;

  const _ExercisePickerDialog({
    required this.exercises,
    required this.l10n,
    required this.isEnglish,
    required this.onCreateExercise,
  });

  @override
  State<_ExercisePickerDialog> createState() => _ExercisePickerDialogState();
}

class _ExercisePickerDialogState extends State<_ExercisePickerDialog> {
  final _customNameCtrl = TextEditingController();
  String _query = '';
  _ExercisePickerMode _mode = _ExercisePickerMode.existing;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _customNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lower = _query.toLowerCase();
    final filtered = lower.isEmpty
        ? widget.exercises
        : widget.exercises.where((exercise) {
            return exercise.name.toLowerCase().contains(lower) ||
                (exercise.nameEn?.toLowerCase().contains(lower) ?? false);
          }).toList();
    return AlertDialog(
      title: Text(widget.l10n.get('addExerciseToDay')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<_ExercisePickerMode>(
              segments: [
                ButtonSegment(
                  value: _ExercisePickerMode.existing,
                  icon: const Icon(Icons.list_alt),
                  label: Text(widget.l10n.get('chooseExistingExercise')),
                ),
                ButtonSegment(
                  value: _ExercisePickerMode.custom,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(widget.l10n.get('createCustomExercise')),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _mode = value.first;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 12),
            if (_mode == _ExercisePickerMode.existing) ...[
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: widget.l10n.get('searchEx'),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: filtered.isEmpty
                    ? Center(child: Text(widget.l10n.get('noExercises')))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final exercise = filtered[i];
                          return ListTile(
                            title: Text(exercise.displayName(widget.isEnglish)),
                            subtitle: Text(
                              exercise.displayBodyPart(widget.isEnglish),
                            ),
                            onTap: () => Navigator.pop(ctx, exercise),
                          );
                        },
                      ),
              ),
            ] else ...[
              TextField(
                controller: _customNameCtrl,
                autofocus: true,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: widget.l10n.get('exerciseName'),
                  helperText: widget.l10n.get('customExercisePlanHelp'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(widget.l10n.get('cancel')),
        ),
        if (_mode == _ExercisePickerMode.custom)
          FilledButton(
            onPressed: _saving ? null : _createCustomExercise,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.l10n.get('add')),
          ),
      ],
    );
  }

  Future<void> _createCustomExercise() async {
    final name = _customNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = widget.l10n.get('pleaseEnterValid'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final exercise = Exercise(
      id: 'custom_${_newProgramId()}',
      name: name,
      bodyPart: '自定义',
      bodyPartEn: 'Custom',
    );
    try {
      await widget.onCreateExercise(exercise);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = widget.l10n.get('failedToLoad');
      });
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, exercise);
  }
}

class _ProgramExerciseDialog extends StatefulWidget {
  final ProgramExercise exercise;
  final String title;
  final L10n l10n;

  const _ProgramExerciseDialog({
    required this.exercise,
    required this.title,
    required this.l10n,
  });

  @override
  State<_ProgramExerciseDialog> createState() => _ProgramExerciseDialogState();
}

class _ProgramExerciseDialogState extends State<_ProgramExerciseDialog> {
  late final TextEditingController _setsCtrl;
  late final TextEditingController _minRepsCtrl;
  late final TextEditingController _maxRepsCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _incrementCtrl;
  late final TextEditingController _percentCtrl;
  late ProgressionSchemeType _type;
  String? _error;

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;
    _setsCtrl = TextEditingController(text: exercise.targetSets.toString());
    _minRepsCtrl = TextEditingController(text: exercise.minReps.toString());
    _maxRepsCtrl = TextEditingController(text: exercise.maxReps.toString());
    _weightCtrl = TextEditingController(
      text: exercise.startingWeightKg.toStringAsFixed(1),
    );
    _incrementCtrl = TextEditingController(
      text: exercise.progressionScheme.weightIncrementKg.toStringAsFixed(1),
    );
    _percentCtrl = TextEditingController(
      text: exercise.progressionScheme.percentIncrement > 0
          ? exercise.progressionScheme.percentIncrement.toStringAsFixed(1)
          : '2.5',
    );
    _type = exercise.progressionScheme.type;
  }

  @override
  void dispose() {
    _setsCtrl.dispose();
    _minRepsCtrl.dispose();
    _maxRepsCtrl.dispose();
    _weightCtrl.dispose();
    _incrementCtrl.dispose();
    _percentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progressionHintKey = _progressionHintKey(_type);
    final fields = <Widget>[
      _numberField(_setsCtrl, widget.l10n.get('sets')),
      ..._repFields(),
      _numberField(_weightCtrl, widget.l10n.get('startWeightKg')),
      if (_usesWeightIncrement(_type))
        _numberField(_incrementCtrl, widget.l10n.get('incrementKg')),
      if (_usesPercentIncrement(_type))
        _numberField(_percentCtrl, widget.l10n.get('cyclePercent')),
      _progressionField(),
    ];

    return AlertDialog(
      title: Text(widget.title, overflow: TextOverflow.ellipsis),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _fieldWrap(fields),
              if (progressionHintKey != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.l10n.get(progressionHintKey),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.l10n.get('cancel')),
        ),
        FilledButton(onPressed: _save, child: Text(widget.l10n.get('save'))),
      ],
    );
  }

  List<Widget> _repFields() {
    if (_type == ProgressionSchemeType.doubleProgression) {
      return [
        _numberField(_minRepsCtrl, widget.l10n.get('startReps')),
        _numberField(_maxRepsCtrl, widget.l10n.get('finalReps')),
      ];
    }
    if (_type == ProgressionSchemeType.linearPeriodization) {
      return [
        _numberField(_maxRepsCtrl, widget.l10n.get('startReps')),
        _numberField(_minRepsCtrl, widget.l10n.get('finalReps')),
      ];
    }
    return [_numberField(_maxRepsCtrl, widget.l10n.get('reps'))];
  }

  Widget _fieldWrap(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var columns = fields.length > 3 ? 3 : fields.length;
        if (width < 420 && columns > 2) columns = 2;
        if (width < 292) columns = 1;
        final fieldWidth = (width - (8 * (columns - 1))) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [
            for (final field in fields)
              SizedBox(width: fieldWidth, child: field),
          ],
        );
      },
    );
  }

  Widget _progressionField() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.l10n.get('progressionOpt'),
          maxLines: 2,
          overflow: TextOverflow.visible,
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<ProgressionSchemeType>(
          initialValue: _type,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          decoration: const InputDecoration(isDense: true),
          items: [
            DropdownMenuItem(
              value: ProgressionSchemeType.doubleProgression,
              child: Text(
                widget.l10n.get('progDouble'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: ProgressionSchemeType.linearWeight,
              child: Text(
                widget.l10n.get('progLinear'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: ProgressionSchemeType.fixedLoad,
              child: Text(
                widget.l10n.get('progFixedLoad'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: ProgressionSchemeType.linearPeriodization,
              child: Text(
                widget.l10n.get('progLinearPeriodization'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              final wasIncrementScheme = _usesWeightIncrement(_type);
              final isIncrementScheme = _usesWeightIncrement(value);
              final wasTwoReps = _usesTwoRepValues(_type);
              final isTwoReps = _usesTwoRepValues(value);
              _type = value;
              if (!wasIncrementScheme && isIncrementScheme) {
                final current = double.tryParse(_incrementCtrl.text);
                if (current == null || current <= 0) {
                  _incrementCtrl.text = '2.5';
                }
              }
              if (value == ProgressionSchemeType.linearPeriodization) {
                final current = double.tryParse(_percentCtrl.text);
                if (current == null || current <= 0) {
                  _percentCtrl.text = '2.5';
                }
              }
              if (!wasTwoReps && isTwoReps) {
                _restoreTwoRepValues(value);
              }
            });
          },
        ),
      ],
    );
  }

  void _restoreTwoRepValues(ProgressionSchemeType type) {
    final target = int.tryParse(_maxRepsCtrl.text);
    if (target == null || target < 2) return;
    final currentMin = int.tryParse(_minRepsCtrl.text);
    if (type == ProgressionSchemeType.doubleProgression &&
        (currentMin == null || currentMin >= target)) {
      _minRepsCtrl.text = (target - 4).clamp(1, target - 1).toString();
    }
    if (type == ProgressionSchemeType.linearPeriodization &&
        (currentMin == null || currentMin >= target)) {
      _minRepsCtrl.text = (target - 4).clamp(1, target - 1).toString();
    }
  }

  Widget _numberField(TextEditingController controller, String label) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.visible,
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(isDense: true),
        ),
      ],
    );
  }

  void _save() {
    final sets = int.tryParse(_setsCtrl.text);
    final minReps = int.tryParse(_minRepsCtrl.text);
    final targetReps = int.tryParse(_maxRepsCtrl.text);
    final weight = double.tryParse(_weightCtrl.text);
    final usesTwoReps = _usesTwoRepValues(_type);
    final usesIncrement = _usesWeightIncrement(_type);
    final usesPercent = _usesPercentIncrement(_type);
    final increment = usesIncrement
        ? double.tryParse(_incrementCtrl.text)
        : 0.0;
    final percent = usesPercent ? double.tryParse(_percentCtrl.text) : null;
    if (sets == null ||
        targetReps == null ||
        weight == null ||
        (usesTwoReps && minReps == null) ||
        (usesIncrement && increment == null) ||
        (usesPercent && percent == null) ||
        sets < 1 ||
        targetReps < 1 ||
        (usesTwoReps && minReps! < 1) ||
        weight < 0 ||
        (usesIncrement && increment! < 0) ||
        (usesPercent && percent! <= 0)) {
      setState(() {
        _error = widget.l10n.get('invalidConfig');
      });
      return;
    }
    final reps = _repsForSave(_type, minReps, targetReps);
    if (_type == ProgressionSchemeType.doubleProgression &&
        reps.max < reps.min) {
      setState(() {
        _error = widget.l10n.get('invalidConfig');
      });
      return;
    }
    if (_type == ProgressionSchemeType.linearPeriodization &&
        reps.max <= reps.min) {
      setState(() {
        _error = widget.l10n.get('invalidConfig');
      });
      return;
    }
    Navigator.pop(
      context,
      widget.exercise.copyWith(
        targetSets: sets,
        minReps: reps.min,
        maxReps: reps.max,
        startingWeightKg: weight,
        progressionScheme: widget.exercise.progressionScheme.copyWith(
          type: _type,
          weightIncrementKg: usesIncrement ? increment! : 0.0,
          percentIncrement: _type == ProgressionSchemeType.linearPeriodization
              ? percent!
              : widget.exercise.progressionScheme.percentIncrement,
        ),
      ),
    );
  }
}

bool _usesTwoRepValues(ProgressionSchemeType type) {
  return type == ProgressionSchemeType.doubleProgression ||
      type == ProgressionSchemeType.linearPeriodization;
}

({int min, int max}) _repsForSave(
  ProgressionSchemeType type,
  int? minReps,
  int reps,
) {
  if (type == ProgressionSchemeType.linearPeriodization) {
    return (min: minReps!, max: reps);
  }
  if (_usesTwoRepValues(type)) return (min: minReps!, max: reps);
  return (min: reps, max: reps);
}

bool _usesWeightIncrement(ProgressionSchemeType type) {
  return switch (type) {
    ProgressionSchemeType.doubleProgression ||
    ProgressionSchemeType.linearWeight => true,
    ProgressionSchemeType.fixedLoad ||
    ProgressionSchemeType.linearPeriodization => false,
  };
}

bool _usesPercentIncrement(ProgressionSchemeType type) {
  return type == ProgressionSchemeType.linearPeriodization;
}

String? _progressionHintKey(ProgressionSchemeType type) {
  return switch (type) {
    ProgressionSchemeType.doubleProgression => 'doubleProgressionHint',
    ProgressionSchemeType.linearWeight => 'linearWeightHint',
    ProgressionSchemeType.fixedLoad => 'fixedLoadHint',
    ProgressionSchemeType.linearPeriodization => 'linearPeriodizationHint',
  };
}

String _exerciseName(String id, List<Exercise> exercises, bool isEnglish) {
  final exercise = exercises.where((e) => e.id == id).firstOrNull;
  if (exercise == null) return id;
  return exercise.displayName(isEnglish);
}

String _programExerciseSubtitle(ProgramExercise exercise, L10n l10n) {
  final scheme = exercise.progressionScheme;
  final schemeLabel = _progressionSchemeLabel(scheme.type, l10n);
  final reps = _repsSummary(exercise);
  final values = {
    'sets': exercise.targetSets.toString(),
    'reps': reps,
    'weight': exercise.startingWeightKg.toStringAsFixed(1),
    'scheme': schemeLabel,
    'inc': scheme.weightIncrementKg.toStringAsFixed(1),
    'percent': scheme.percentIncrement.toStringAsFixed(1),
  };

  final key = switch (scheme.type) {
    ProgressionSchemeType.fixedLoad =>
      exercise.startingWeightKg > 0 ? 'exSummaryFixedWt' : 'exSummaryFixedNoWt',
    ProgressionSchemeType.linearPeriodization =>
      exercise.startingWeightKg > 0
          ? 'exSummaryLinearPeriodizationWt'
          : 'exSummaryLinearPeriodizationNoWt',
    _ => exercise.startingWeightKg > 0 ? 'exSummaryWt' : 'exSummaryNoWt',
  };
  return l10n.format(key, values);
}

String _repsSummary(ProgramExercise exercise) {
  if (exercise.progressionScheme.type ==
      ProgressionSchemeType.doubleProgression) {
    return '${exercise.minReps}-${exercise.maxReps}';
  }
  if (exercise.progressionScheme.type ==
      ProgressionSchemeType.linearPeriodization) {
    return '${exercise.maxReps}->${exercise.minReps}';
  }
  return exercise.maxReps.toString();
}

String _progressionSchemeLabel(ProgressionSchemeType type, L10n l10n) {
  return switch (type) {
    ProgressionSchemeType.doubleProgression => l10n.get('progDouble'),
    ProgressionSchemeType.linearWeight => l10n.get('progLinear'),
    ProgressionSchemeType.fixedLoad => l10n.get('progFixedLoad'),
    ProgressionSchemeType.linearPeriodization => l10n.get(
      'progLinearPeriodization',
    ),
  };
}
