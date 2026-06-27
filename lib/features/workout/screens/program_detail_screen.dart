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
    final isEnglish = ref.watch(localeProvider) == AppLocale.en;

    return programsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Program')),
        body: Center(child: Text('Error: $error')),
      ),
      data: (programs) {
        final program = programs.where((p) => p.id == programId).firstOrNull;
        if (program == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Program')),
            body: const Center(child: Text('Program not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(program.name),
            actions: [
              IconButton(
                tooltip: 'Rename',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _renameProgram(context, ref, program),
              ),
              IconButton(
                tooltip: 'Set active',
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
              _ProgramHeader(program: program),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.fitness_center, size: 18),
                      label: const Text('Training day'),
                      onPressed: () => _addDay(context, ref, program, false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.hotel, size: 18),
                      label: const Text('Rest day'),
                      onPressed: () => _addDay(context, ref, program, true),
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
                  onEditDay: () => _editDay(context, ref, program, i),
                  onDeleteDay: () => _deleteDay(context, ref, program, i),
                  onAddExercise: () =>
                      _addExercise(context, ref, program, i, exercises),
                  onEditExercise: (exerciseIndex) => _editProgramExercise(
                    context,
                    ref,
                    program,
                    i,
                    exerciseIndex,
                    exercises,
                    isEnglish,
                  ),
                  onRemoveExercise: (exerciseIndex) =>
                      _removeExercise(ref, program, i, exerciseIndex),
                ),
                const SizedBox(height: 10),
              ],
              if (program.days.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: Text('No days yet')),
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
  ) async {
    final controller = TextEditingController(text: program.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename program'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Program name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
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
  ) async {
    final controller = TextEditingController(
      text: rest ? 'Rest' : 'Training Day ${program.days.length + 1}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(rest ? 'Add rest day' : 'Add training day'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Day name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
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
  ) async {
    final day = program.days[dayIndex];
    final nameCtrl = TextEditingController(text: day.name);
    var kind = day.kind;
    final result = await showDialog<({String name, DayKind kind})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Day name'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<DayKind>(
                segments: const [
                  ButtonSegment(
                    value: DayKind.training,
                    label: Text('Training'),
                    icon: Icon(Icons.fitness_center),
                  ),
                  ButtonSegment(
                    value: DayKind.rest,
                    label: Text('Rest'),
                    icon: Icon(Icons.hotel),
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, (name: nameCtrl.text.trim(), kind: kind)),
              child: const Text('Save'),
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
  ) async {
    final day = program.days[dayIndex];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete day'),
        content: Text('Delete "${day.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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
  ) async {
    final selected = await showDialog<Exercise>(
      context: context,
      builder: (ctx) => _ExercisePickerDialog(exercises: exercises),
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
  ) async {
    final current = program.days[dayIndex].exercises[exerciseIndex];
    final updated = await showDialog<ProgramExercise>(
      context: context,
      builder: (ctx) => _ProgramExerciseDialog(
        exercise: current,
        title: _exerciseName(current.exerciseId, exercises, isEnglish),
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

  const _ProgramHeader({required this.program});

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
                '$trainingDays training days, $restDays rest days',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text('Day ${program.normalizedCurrentDayIndex + 1}'),
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
                    'Day ${dayIndex + 1}: ${day.name}',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Edit day',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEditDay,
                ),
                IconButton(
                  tooltip: 'Delete day',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onDeleteDay,
                ),
              ],
            ),
            if (isRest)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Rest day'),
              )
            else ...[
              const SizedBox(height: 8),
              if (sortedExercises.isEmpty)
                Text(
                  'No exercises',
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
                  label: const Text('Add exercise'),
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
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ProgramExerciseTile({
    required this.exercise,
    required this.name,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = exercise.progressionScheme;
    final schemeLabel = switch (scheme.type) {
      ProgressionSchemeType.doubleProgression => 'Double',
      ProgressionSchemeType.linearWeight => 'Linear',
      ProgressionSchemeType.periodized => 'Periodized',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${exercise.targetSets} x ${exercise.minReps}-${exercise.maxReps} · '
        '${exercise.startingWeightKg.toStringAsFixed(1)} kg · '
        '$schemeLabel +${scheme.weightIncrementKg.toStringAsFixed(1)} kg',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') onEdit();
          if (value == 'remove') onRemove();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(
            value: 'remove',
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ExercisePickerDialog extends StatefulWidget {
  final List<Exercise> exercises;

  const _ExercisePickerDialog({required this.exercises});

  @override
  State<_ExercisePickerDialog> createState() => _ExercisePickerDialogState();
}

class _ExercisePickerDialogState extends State<_ExercisePickerDialog> {
  String _query = '';

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
      title: const Text('Add exercise'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final exercise = filtered[i];
                  return ListTile(
                    title: Text(exercise.nameEn ?? exercise.name),
                    subtitle: Text(exercise.bodyPartEn ?? exercise.bodyPart),
                    onTap: () => Navigator.pop(ctx, exercise),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ProgramExerciseDialog extends StatefulWidget {
  final ProgramExercise exercise;
  final String title;

  const _ProgramExerciseDialog({required this.exercise, required this.title});

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
                Expanded(child: _numberField(_setsCtrl, 'Sets')),
                const SizedBox(width: 8),
                Expanded(child: _numberField(_minRepsCtrl, 'Min reps')),
                const SizedBox(width: 8),
                Expanded(child: _numberField(_maxRepsCtrl, 'Max reps')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numberField(_weightCtrl, 'Start kg')),
                const SizedBox(width: 8),
                Expanded(child: _numberField(_incrementCtrl, 'Add kg')),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProgressionSchemeType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Progression'),
              items: const [
                DropdownMenuItem(
                  value: ProgressionSchemeType.doubleProgression,
                  child: Text('Double progression'),
                ),
                DropdownMenuItem(
                  value: ProgressionSchemeType.linearWeight,
                  child: Text('Linear weight'),
                ),
                DropdownMenuItem(
                  value: ProgressionSchemeType.periodized,
                  child: Text('Periodized'),
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
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
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
        _error = 'Enter valid sets, reps, weight, and increment.';
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
