import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/exercise.dart';
import '../../../data/models/training_program.dart';
import '../../../core/localization/l10n.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';

int _idSeq = 0;

String _newProgramId() {
  _idSeq += 1;
  return '${DateTime.now().microsecondsSinceEpoch}_$_idSeq';
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
                tooltip: l10n.get('rename'),
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
                    : () => ref
                          .read(trainingProgramsProvider.notifier)
                          .setActive(program.id),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _ProgramHeader(program: program, l10n: l10n),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.fitness_center, size: 18),
                      label: Text(l10n.get('trainingDayBtn')),
                      onPressed: () =>
                          _addDay(context, ref, program, false, l10n),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.hotel, size: 18),
                      label: Text(l10n.get('restDayBtn')),
                      onPressed: () =>
                          _addDay(context, ref, program, true, l10n),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < program.days.length; i++) ...[
                _ProgramDaySection(
                  program: program,
                  day: program.days[i],
                  dayIndex: i,
                  exercises: exercises,
                  isEnglish: isEnglish,
                  l10n: l10n,
                  onEditDay: () => _editDay(context, ref, program, i, l10n),
                  onDeleteDay: () => _deleteDay(context, ref, program, i, l10n),
                  onAddExercise: () =>
                      _addExercise(context, ref, program, i, exercises, l10n),
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
                const SizedBox(height: 10),
              ],
              if (program.days.isEmpty)
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
    final controller = TextEditingController(text: program.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.get('renameProgram')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.get('programName')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.get('save')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await ref
        .read(trainingProgramsProvider.notifier)
        .save(program.copyWith(name: name, updatedAt: DateTime.now()));
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
    final days = [...program.days];
    final day = days[dayIndex];
    final exercise = ProgramExercise(
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
    days[dayIndex] = day.copyWith(exercises: [...day.exercises, exercise]);
    await _saveProgram(
      ref,
      program.copyWith(days: days, updatedAt: DateTime.now()),
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
    await _saveProgram(
      ref,
      program.copyWith(days: days, updatedAt: DateTime.now()),
    );
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
    await _saveProgram(
      ref,
      program.copyWith(days: days, updatedAt: DateTime.now()),
    );
  }

  static Future<void> _saveProgram(WidgetRef ref, TrainingProgram program) {
    return ref.read(trainingProgramsProvider.notifier).save(program);
  }
}

class _ProgramHeader extends StatelessWidget {
  final TrainingProgram program;
  final L10n l10n;

  const _ProgramHeader({required this.program, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final trainingDays = program.days
        .where((d) => d.kind == DayKind.training)
        .length;
    final restDays = program.days.length - trainingDays;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              program.active ? Icons.check_circle : Icons.assignment_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.format('trainingDaysCount', {
                  'training': trainingDays.toString(),
                  'rest': restDays.toString(),
                }),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              l10n.format('currentDayN', {
                'n': (program.normalizedCurrentDayIndex + 1).toString(),
              }),
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
  final List<Exercise> exercises;
  final bool isEnglish;
  final L10n l10n;
  final VoidCallback onEditDay;
  final VoidCallback onDeleteDay;
  final VoidCallback onAddExercise;
  final void Function(int exerciseIndex) onEditExercise;
  final void Function(int exerciseIndex) onRemoveExercise;

  const _ProgramDaySection({
    required this.program,
    required this.day,
    required this.dayIndex,
    required this.exercises,
    required this.isEnglish,
    required this.l10n,
    required this.onEditDay,
    required this.onDeleteDay,
    required this.onAddExercise,
    required this.onEditExercise,
    required this.onRemoveExercise,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRest = day.kind == DayKind.rest;
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
                Icon(
                  isRest ? Icons.hotel : Icons.fitness_center,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.format('daySectionN', {
                      'n': (dayIndex + 1).toString(),
                      'name': day.name,
                    }),
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
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
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.get('restDay')),
              )
            else ...[
              const SizedBox(height: 8),
              if (sortedExercises.isEmpty)
                Text(
                  l10n.get('noExercisesInDay'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                )
              else
                for (var i = 0; i < sortedExercises.length; i++)
                  _ProgramExerciseTile(
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

class _ProgramExerciseTile extends StatelessWidget {
  final ProgramExercise exercise;
  final String name;
  final L10n l10n;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ProgramExerciseTile({
    required this.exercise,
    required this.name,
    required this.l10n,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = exercise.progressionScheme;
    final schemeLabel = _progressionSchemeLabel(scheme.type, l10n);
    final reps = '${exercise.minReps}-${exercise.maxReps}';
    final increment = scheme.weightIncrementKg.toStringAsFixed(1);
    final subtitle = exercise.startingWeightKg > 0
        ? l10n.format('exSummaryWt', {
            'sets': exercise.targetSets.toString(),
            'reps': reps,
            'weight': exercise.startingWeightKg.toStringAsFixed(1),
            'scheme': schemeLabel,
            'inc': increment,
          })
        : l10n.format('exSummaryNoWt', {
            'sets': exercise.targetSets.toString(),
            'reps': reps,
            'scheme': schemeLabel,
            'inc': increment,
          });
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
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
    _type = exercise.progressionScheme.type;
  }

  @override
  void dispose() {
    _setsCtrl.dispose();
    _minRepsCtrl.dispose();
    _maxRepsCtrl.dispose();
    _weightCtrl.dispose();
    _incrementCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, overflow: TextOverflow.ellipsis),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _numberField(_setsCtrl, widget.l10n.get('sets')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numberField(_minRepsCtrl, widget.l10n.get('minReps')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numberField(_maxRepsCtrl, widget.l10n.get('maxReps')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _numberField(
                    _weightCtrl,
                    widget.l10n.get('startWeightKg'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numberField(
                    _incrementCtrl,
                    widget.l10n.get('incrementKg'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProgressionSchemeType>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: widget.l10n.get('progressionOpt'),
              ),
              items: [
                DropdownMenuItem(
                  value: ProgressionSchemeType.doubleProgression,
                  child: Text(widget.l10n.get('progDouble')),
                ),
                DropdownMenuItem(
                  value: ProgressionSchemeType.linearWeight,
                  child: Text(widget.l10n.get('progLinear')),
                ),
                DropdownMenuItem(
                  value: ProgressionSchemeType.periodized,
                  child: Text(widget.l10n.get('progPeriodized')),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.l10n.get('cancel')),
        ),
        FilledButton(onPressed: _save, child: Text(widget.l10n.get('save'))),
      ],
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }

  void _save() {
    final sets = int.tryParse(_setsCtrl.text);
    final minReps = int.tryParse(_minRepsCtrl.text);
    final maxReps = int.tryParse(_maxRepsCtrl.text);
    final weight = double.tryParse(_weightCtrl.text);
    final increment = double.tryParse(_incrementCtrl.text);
    if (sets == null ||
        minReps == null ||
        maxReps == null ||
        weight == null ||
        increment == null ||
        sets < 1 ||
        minReps < 1 ||
        maxReps < minReps ||
        weight < 0 ||
        increment < 0) {
      setState(() {
        _error = widget.l10n.get('invalidConfig');
      });
      return;
    }
    Navigator.pop(
      context,
      widget.exercise.copyWith(
        targetSets: sets,
        minReps: minReps,
        maxReps: maxReps,
        startingWeightKg: weight,
        progressionScheme: widget.exercise.progressionScheme.copyWith(
          type: _type,
          weightIncrementKg: increment,
        ),
      ),
    );
  }
}

String _exerciseName(String id, List<Exercise> exercises, bool isEnglish) {
  final exercise = exercises.where((e) => e.id == id).firstOrNull;
  if (exercise == null) return id;
  return exercise.displayName(isEnglish);
}

String _progressionSchemeLabel(ProgressionSchemeType type, L10n l10n) {
  return switch (type) {
    ProgressionSchemeType.doubleProgression => l10n.get('progDouble'),
    ProgressionSchemeType.linearWeight => l10n.get('progLinear'),
    ProgressionSchemeType.periodized => l10n.get('progPeriodized'),
  };
}
