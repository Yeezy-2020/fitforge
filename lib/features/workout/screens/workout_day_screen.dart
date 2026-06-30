import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/exercise.dart';
import '../../../data/models/workout_log.dart';
import '../../../data/models/progression_rule.dart';
import '../../../data/models/training_program.dart';
import '../../../data/repositories/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/navigation/instant_page_route.dart';
import '../../../core/utils/progression_calculator.dart';
import '../../../data/models/workout_template.dart';
import '../../workout/screens/templates_screen.dart';
import 'exercise_detail_screen.dart';

const _uuid = Uuid();

class WorkoutDayScreen extends ConsumerStatefulWidget {
  final DateTime date;
  const WorkoutDayScreen({super.key, required this.date});

  @override
  ConsumerState<WorkoutDayScreen> createState() => _WorkoutDayScreenState();
}

class _WorkoutDayScreenState extends ConsumerState<WorkoutDayScreen> {
  String? _selectedBodyPart;
  List<_PendingSet> _pendingSets = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final _customNameCtrl = TextEditingController();
  final _customSetsCtrl = TextEditingController(text: '3');
  final _customRepsCtrl = TextEditingController();
  final _customWeightCtrl = TextEditingController();

  void _saveAsTemplate() async {
    final l10n = ref.read(l10nProvider);
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.get('saveAsTemplate')),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(hintText: l10n.get('templateName')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: Text(l10n.get('save')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final template = WorkoutTemplate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      exercises: _pendingSets
          .map(
            (p) => TemplateExercise(
              exerciseId: p.exerciseId,
              defaultSets: p.sets,
              defaultReps: p.reps,
              defaultWeight: p.weight,
            ),
          )
          .toList(),
    );
    final userId = ref.read(currentUserIdProvider);
    await AppDatabase.instance.saveTemplate(userId, template);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.format('templateSaved', {'name': name}))),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customNameCtrl.dispose();
    _customSetsCtrl.dispose();
    _customRepsCtrl.dispose();
    _customWeightCtrl.dispose();
    super.dispose();
  }

  void _addToPending(
    String exerciseId,
    int sets,
    int reps,
    double weight, {
    String? programId,
    String? programDayId,
    String? programExerciseId,
  }) {
    final l10n = ref.read(l10nProvider);
    if (reps <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.get('pleaseEnterValid'))));
      return;
    }
    setState(
      () => _pendingSets.add(
        _PendingSet(
          exerciseId: exerciseId,
          sets: sets,
          reps: reps,
          weight: weight,
          programId: programId,
          programDayId: programDayId,
          programExerciseId: programExerciseId,
        ),
      ),
    );
  }

  void _addCustomExercise() {
    final l10n = ref.read(l10nProvider);
    final name = _customNameCtrl.text.trim();
    final sets = int.tryParse(_customSetsCtrl.text) ?? 3;
    final reps = int.tryParse(_customRepsCtrl.text) ?? 0;
    final weight = double.tryParse(_customWeightCtrl.text) ?? 0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.get('pleaseEnterValid'))));
      return;
    }
    final exId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final exercise = Exercise(
      id: exId,
      name: name,
      bodyPart: '自定义',
      bodyPartEn: 'Custom',
    );
    ref.read(exerciseListProvider.notifier).addExercise(exercise);
    _addToPending(exId, sets, reps, weight);
    _customNameCtrl.clear();
    _customRepsCtrl.clear();
    _customWeightCtrl.clear();
    _customSetsCtrl.text = '3';
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _selectedDateIsToday => _isSameDate(widget.date, DateTime.now());

  Future<void> _advanceActiveProgram(L10n l10n) async {
    await ref.read(trainingProgramsProvider.notifier).advanceDay();
    ref.invalidate(workoutPrescriptionsForDateProvider(widget.date));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.get('programAdvanced'))));
  }

  Future<void> _saveAll() async {
    final l10n = ref.read(l10nProvider);
    final userId = ref.read(currentUserIdProvider);
    final savedLogs = <WorkoutLog>[];
    final activeProgram = ref.read(activeTrainingProgramProvider);
    final activeProgramDay = activeProgram?.currentDay;
    final savedCurrentProgramExerciseIds = <String>{};
    for (final p in _pendingSets) {
      final log = WorkoutLog(
        id: _uuid.v4(),
        userId: userId,
        exerciseId: p.exerciseId,
        date: widget.date,
        sets: p.sets,
        reps: p.reps,
        weightKg: p.weight,
        createdAt: DateTime.now(),
      );
      savedLogs.add(log);
      await AppDatabase.instance.addWorkoutLog(userId, log);

      // Save WorkoutSetLog records for program-derived items (local only)
      final programId = p.programId;
      final programDayId = p.programDayId;
      final programExerciseId = p.programExerciseId;
      if (programId != null &&
          programDayId != null &&
          programExerciseId != null) {
        if (activeProgram != null &&
            activeProgramDay != null &&
            programId == activeProgram.id &&
            programDayId == activeProgramDay.id) {
          savedCurrentProgramExerciseIds.add(programExerciseId);
        }
        final setLogs = <WorkoutSetLog>[];
        for (int i = 0; i < p.sets; i++) {
          setLogs.add(
            WorkoutSetLog(
              id: _uuid.v4(),
              workoutLogId: log.id,
              programId: programId,
              programExerciseId: programExerciseId,
              setIndex: i,
              reps: p.reps,
              weightKg: p.weight,
              completed: true,
            ),
          );
        }
        await AppDatabase.instance.saveWorkoutSetLogs(userId, setLogs);
      }
    }

    // Program advance: only when every planned exercise is covered
    String message = l10n.get('workoutSaved');
    if (shouldAdvanceProgram(
      currentDay: activeProgramDay,
      savedProgramExerciseIds: savedCurrentProgramExerciseIds,
      advanceMode: activeProgram?.advanceMode ?? AdvanceMode.manual,
      selectedDateIsToday: _selectedDateIsToday,
    )) {
      await ref.read(trainingProgramsProvider.notifier).advanceDay();
      message = '${l10n.get('workoutSaved')} · ${l10n.get('programAdvanced')}';
    }

    // Update cache IMMEDIATELY so calendar shows instant results
    ref.read(workoutCacheProvider.notifier).addDate(widget.date);
    ref.read(workoutLogCacheProvider.notifier).addLogs(widget.date, savedLogs);
    // Push to Supabase in background (non-blocking)
    for (final log in savedLogs) {
      try {
        await ref.read(supabaseProvider).addWorkoutLog(log);
      } catch (_) {
        await AppDatabase.instance.addUnsyncedWorkout(userId, log);
      }
    }
    ref.invalidate(workoutLogsForDateProvider);
    if (mounted) {
      setState(() => _pendingSets = []);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      context.pop();
    }
  }

  void _confirmDeletePending(int idx) {
    final l10n = ref.read(l10nProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.get('delete')),
        content: Text(l10n.get('deleteConfirmShort')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _pendingSets.removeAt(idx));
              Navigator.pop(ctx);
            },
            child: Text(l10n.get('delete')),
          ),
        ],
      ),
    );
  }

  void _editPending(int idx, _PendingSet p, L10n l10n, WeightUnit trainUnit) {
    final setsCtrl = TextEditingController(text: p.sets.toString());
    final repsCtrl = TextEditingController(text: p.reps.toString());
    final weightCtrl = TextEditingController(
      text: (trainUnit == WeightUnit.lb ? (p.weight * kgToLb) : p.weight)
          .toStringAsFixed(1),
    );
    final unitLabel = trainUnit == WeightUnit.kg ? 'kg' : 'lb';
    final exercises = ref.read(exerciseListProvider).valueOrNull ?? [];
    final exName =
        exercises.where((e) => e.id == p.exerciseId).firstOrNull?.name ??
        p.exerciseId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(exName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: setsCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: l10n.get('sets'),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: repsCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: l10n.get('reps'),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: weightCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: unitLabel,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.get('cancel')),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDeletePending(idx);
            },
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            label: Text(
              l10n.get('delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              final newSets = int.tryParse(setsCtrl.text) ?? p.sets;
              final newReps = int.tryParse(repsCtrl.text) ?? p.reps;
              double newWeight = double.tryParse(weightCtrl.text) ?? p.weight;
              if (trainUnit == WeightUnit.lb) newWeight = newWeight / kgToLb;
              setState(() {
                _pendingSets[idx] = _PendingSet(
                  exerciseId: p.exerciseId,
                  sets: newSets.clamp(1, 999),
                  reps: newReps.clamp(1, 9999),
                  weight: newWeight,
                  programId: p.programId,
                  programDayId: p.programDayId,
                  programExerciseId: p.programExerciseId,
                );
              });
              Navigator.pop(ctx);
            },
            child: Text(l10n.get('save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final bodyParts = ref.watch(bodyPartsProvider);
    final allExercises = ref.watch(exerciseListProvider).valueOrNull ?? [];
    final trainUnit = ref.watch(trainingWeightUnitProvider);
    final exercises = ref.watch(exerciseListProvider).valueOrNull ?? [];
    final l10n2 = ref.watch(l10nProvider);
    final activeProgram = ref.watch(activeTrainingProgramProvider);
    final programPrescriptions =
        ref
            .watch(workoutPrescriptionsForDateProvider(widget.date))
            .valueOrNull ??
        [];
    String exName(String id) {
      final ex = exercises.where((e) => e.id == id).firstOrNull;
      if (ex == null) return id;
      return l10n2.exerciseName(ex.id, ex.name);
    }

    final filtered = allExercises.where((ex) {
      if (_selectedBodyPart != null && ex.bodyPart != _selectedBodyPart) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        return ex.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.shortDate(widget.date)} ${l10n.get('workout')}'),
        actions: [
          if (_pendingSets.isNotEmpty)
            TextButton.icon(
              onPressed: _saveAll,
              icon: const Icon(Icons.save),
              label: Text('${l10n.get('save')} (${_pendingSets.length})'),
            ),
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            tooltip: l10n.get('templates'),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                instantPageRoute(const TemplatesScreen()),
              );
              if (result != null && result is WorkoutTemplate) {
                for (final ex in result.exercises) {
                  _addToPending(
                    ex.exerciseId,
                    ex.defaultSets,
                    ex.defaultReps,
                    ex.defaultWeight,
                  );
                }
              }
            },
          ),
          if (_pendingSets.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bookmark_add),
              tooltip: l10n.get('saveAsTemplate'),
              onPressed: _saveAsTemplate,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_pendingSets.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.checklist, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        l10n.format('pendingSetCount', {
                          'count': _pendingSets.length.toString(),
                        }),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _pendingSets = []),
                        child: Text(
                          l10n.get('clear'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _pendingSets.toList().asMap().entries.map((e) {
                      final idx = e.key;
                      final p = e.value;
                      return GestureDetector(
                        onTap: () => _editPending(idx, p, l10n, trainUnit),
                        child: Container(
                          padding: const EdgeInsets.only(
                            left: 10,
                            right: 4,
                            top: 4,
                            bottom: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${exName(p.exerciseId)}  ${p.sets}x${p.reps} ${formatTrainingWeight(p.weight, trainUnit)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              GestureDetector(
                                onTap: () => _confirmDeletePending(idx),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.close, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          if (activeProgram != null)
            _buildProgramPanel(
              activeProgram,
              programPrescriptions,
              l10n,
              exercises,
              trainUnit,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.get('searchExercises'),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: _buildMainContent(
              l10n,
              bodyParts,
              filtered,
              trainUnit,
              showExerciseProgression: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramPanel(
    TrainingProgram program,
    List<WorkoutPrescription> prescriptions,
    L10n l10n,
    List<Exercise> exercises,
    WeightUnit trainUnit,
  ) {
    final day = program.currentDay;
    if (day == null) return const SizedBox.shrink();

    String exName(String id) {
      final ex = exercises.where((e) => e.id == id).firstOrNull;
      if (ex == null) return id;
      return l10n.exerciseName(ex.id, ex.name);
    }

    if (day.kind == DayKind.rest) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.hotel, size: 18, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${l10n.get('restDay')} — ${day.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            if (_selectedDateIsToday)
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _advanceActiveProgram(l10n),
                child: Text(
                  l10n.get('completeRestDay'),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
          ],
        ),
      );
    }

    if (prescriptions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                const Icon(Icons.fitness_center, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${l10n.get('todayProgram')}: ${day.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ...prescriptions.map(
            (rx) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      exName(rx.exerciseId),
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${rx.sets} × ${rx.reps} @ ${formatTrainingWeight(rx.weightKg, trainUnit)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _addToPending(
                      rx.exerciseId,
                      rx.sets,
                      rx.reps,
                      rx.weightKg,
                      programId: rx.programId,
                      programDayId: rx.programDayId,
                      programExerciseId: rx.programExerciseId,
                    ),
                    child: Text(
                      l10n.get('add'),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              children: [
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: Text(
                    l10n.get('addAll'),
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () {
                    for (final rx in prescriptions) {
                      _addToPending(
                        rx.exerciseId,
                        rx.sets,
                        rx.reps,
                        rx.weightKg,
                        programId: rx.programId,
                        programDayId: rx.programDayId,
                        programExerciseId: rx.programExerciseId,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    L10n l10n,
    List<String> bodyParts,
    List<Exercise> filtered,
    WeightUnit trainUnit, {
    required bool showExerciseProgression,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: ListView(
            children: [
              ...bodyParts.map((part) {
                final isSelected = _selectedBodyPart == part;
                return ListTile(
                  dense: true,
                  selected: isSelected,
                  title: Text(
                    l10n.bodyPartName(part),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  onTap: () => setState(() {
                    _selectedBodyPart = _selectedBodyPart == part ? null : part;
                    _searchController.clear();
                    _searchQuery = '';
                  }),
                );
              }),
              ListTile(
                dense: true,
                selected: _selectedBodyPart == '__custom__',
                title: Column(
                  children: [
                    Text(
                      l10n.get('custom'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _selectedBodyPart == '__custom__'
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    Icon(
                      Icons.add_circle_outline,
                      size: 20,
                      color: _selectedBodyPart == '__custom__'
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ],
                ),
                onTap: () => setState(() {
                  _selectedBodyPart = '__custom__';
                  _searchController.clear();
                  _searchQuery = '';
                }),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _selectedBodyPart == null && _searchQuery.isEmpty
              ? Center(child: Text(l10n.get('selectBodyPart')))
              : _selectedBodyPart == '__custom__'
              ? _buildCustomExerciseForm(l10n)
              : _buildExerciseList(
                  l10n,
                  filtered,
                  trainUnit,
                  showExerciseProgression,
                ),
        ),
      ],
    );
  }

  Widget _buildCustomExerciseForm(L10n l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _customNameCtrl,
          decoration: InputDecoration(
            labelText: l10n.get('exerciseName'),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customSetsCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: l10n.get('sets'),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _customRepsCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: l10n.get('reps'),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _customWeightCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: l10n.get('kg'),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _addCustomExercise,
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.get('addToWorkout')),
        ),
      ],
    );
  }

  Widget _buildExerciseList(
    L10n l10n,
    List<Exercise> exercises,
    WeightUnit trainUnit,
    bool showExerciseProgression,
  ) {
    if (exercises.isEmpty) return Center(child: Text(l10n.get('noExercises')));
    return ListView(
      padding: const EdgeInsets.all(8),
      children: exercises
          .map(
            (ex) => _ExerciseCard(
              key: ValueKey(ex.id),
              exercise: ex,
              l10n: l10n,
              trainUnit: trainUnit,
              date: widget.date,
              showProgressionControls: showExerciseProgression,
              onAdd: (id, sets, reps, weight) =>
                  _addToPending(id, sets, reps, weight),
            ),
          )
          .toList(),
    );
  }
}

class _ExerciseCard extends ConsumerStatefulWidget {
  final Exercise exercise;
  final L10n l10n;
  final WeightUnit trainUnit;
  final DateTime date;
  final bool showProgressionControls;
  final void Function(String exerciseId, int sets, int reps, double weight)
  onAdd;
  const _ExerciseCard({
    super.key,
    required this.exercise,
    required this.l10n,
    required this.trainUnit,
    required this.date,
    required this.showProgressionControls,
    required this.onAdd,
  });

  @override
  ConsumerState<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends ConsumerState<_ExerciseCard> {
  late TextEditingController _setsCtrl, _repsCtrl, _weightCtrl;
  bool _applying = false;
  bool _userEdited = false;
  String? _appliedKey;

  @override
  void initState() {
    super.initState();
    _setsCtrl = TextEditingController();
    _repsCtrl = TextEditingController();
    _weightCtrl = TextEditingController();
    for (final c in [_setsCtrl, _repsCtrl, _weightCtrl]) {
      c.addListener(() {
        if (!_applying) _userEdited = true;
      });
    }
  }

  @override
  void dispose() {
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  String _suggestionKey(ProgressionSuggestion s) =>
      '${s.sets}-${s.reps}-${s.weightKg}';

  void _applySuggestion(ProgressionSuggestion s) {
    _applying = true;
    _setsCtrl.text = s.sets.toString();
    _repsCtrl.text = s.reps.toString();
    final w = widget.trainUnit == WeightUnit.lb
        ? s.weightKg * kgToLb
        : s.weightKg;
    _weightCtrl.text = w.toStringAsFixed(1);
    _applying = false;
    _appliedKey = _suggestionKey(s);
  }

  void _clearForNext() {
    _applying = true;
    _setsCtrl.clear();
    _repsCtrl.clear();
    _weightCtrl.clear();
    _applying = false;
    setState(() {
      _userEdited = false;
      _appliedKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = widget.trainUnit == WeightUnit.kg ? 'kg' : 'lb';
    final rule = widget.showProgressionControls
        ? ref.watch(progressionRuleForExerciseProvider(widget.exercise.id))
        : null;
    final suggestion = widget.showProgressionControls
        ? ref.watch(
            progressionSuggestionProvider((
              exerciseId: widget.exercise.id,
              before: widget.date,
            )),
          )
        : null;

    if (suggestion != null &&
        !_userEdited &&
        _appliedKey != _suggestionKey(suggestion)) {
      final s = suggestion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_userEdited || _appliedKey == _suggestionKey(s)) return;
        setState(() => _applySuggestion(s));
      });
    }

    final ruleActive = rule != null && rule.enabled;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          instantPageRoute(ExerciseDetailScreen(exercise: widget.exercise)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.l10n.exerciseName(
                        widget.exercise.id,
                        widget.exercise.name,
                      ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (widget.showProgressionControls)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 18,
                      tooltip: widget.l10n.get('progressiveOverload'),
                      icon: Icon(
                        Icons.trending_up,
                        size: 18,
                        color: ruleActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).disabledColor,
                      ),
                      onPressed: () => showProgressionRuleSheet(
                        context,
                        ref,
                        exercise: widget.exercise,
                        l10n: widget.l10n,
                      ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.info_outline, size: 16),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _numField(
                    controller: _setsCtrl,
                    label: widget.l10n.get('sets'),
                    width: 64,
                  ),
                  const SizedBox(width: 6),
                  _numField(
                    controller: _repsCtrl,
                    label: widget.l10n.get('reps'),
                    width: 86,
                  ),
                  const SizedBox(width: 6),
                  _numField(
                    controller: _weightCtrl,
                    label: unitLabel,
                    width: 72,
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      final sets =
                          int.tryParse(_setsCtrl.text) ??
                          (suggestion?.sets ?? 3);
                      final reps = int.tryParse(_repsCtrl.text) ?? 0;
                      double w = double.tryParse(_weightCtrl.text) ?? 0;
                      if (widget.trainUnit == WeightUnit.lb) w = w / kgToLb;
                      widget.onAdd(widget.exercise.id, sets, reps, w);
                      _clearForNext();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      widget.l10n.get('add'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (ruleActive && suggestion != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${widget.l10n.get('suggested')}: '
                    '${widget.l10n.format(suggestion.reasonKey, suggestion.reasonParams)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField({
    required TextEditingController controller,
    required String label,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 4,
          ),
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}

Future<void> showProgressionRuleSheet(
  BuildContext context,
  WidgetRef ref, {
  required Exercise exercise,
  required L10n l10n,
}) async {
  final userId = ref.read(currentUserIdProvider);
  final existing = ref.read(progressionRuleForExerciseProvider(exercise.id));

  var type = existing?.type ?? ProgressionType.fixedWeight;
  var enabled = existing?.enabled ?? true;
  var onlyIfCompleted = existing?.onlyIfCompleted ?? true;
  final incrementCtrl = TextEditingController(
    text: (existing?.increment ?? 2.5).toString(),
  );
  final targetSetsCtrl = TextEditingController(
    text: (existing?.targetSets ?? 3).toString(),
  );
  final targetRepsCtrl = TextEditingController(
    text: (existing?.targetReps ?? 8).toString(),
  );
  final minRepsCtrl = TextEditingController(
    text: (existing?.minReps ?? 8).toString(),
  );
  final maxRepsCtrl = TextEditingController(
    text: (existing?.maxReps ?? 12).toString(),
  );
  final defWeightCtrl = TextEditingController(
    text: existing?.defaultWeightKg?.toString() ?? '',
  );
  final defSetsCtrl = TextEditingController(
    text: existing?.defaultSets?.toString() ?? '',
  );
  final defRepsCtrl = TextEditingController(
    text: existing?.defaultReps?.toString() ?? '',
  );

  String typeLabel(ProgressionType t) {
    switch (t) {
      case ProgressionType.fixedWeight:
        return l10n.get('typeFixedWeight');
      case ProgressionType.percentWeight:
        return l10n.get('typePercentWeight');
      case ProgressionType.reps:
        return l10n.get('typeReps');
      case ProgressionType.doubleProgression:
        return l10n.get('typeDoubleProgression');
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget numField(TextEditingController c, String label) => Expanded(
            child: TextField(
              controller: c,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: label, isDense: true),
            ),
          );

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.trending_up, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l10n.get('progressiveOverload')} · '
                          '${l10n.exerciseName(exercise.id, exercise.name)}',
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.get('enabled')),
                    value: enabled,
                    onChanged: (v) => setSheet(() => enabled = v),
                  ),
                  DropdownButtonFormField<ProgressionType>(
                    initialValue: type,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.get('progressionType'),
                      isDense: true,
                    ),
                    items: ProgressionType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(typeLabel(t)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSheet(() => type = v ?? type),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [numField(incrementCtrl, l10n.get('increment'))],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      numField(targetSetsCtrl, l10n.get('targetSets')),
                      const SizedBox(width: 8),
                      numField(targetRepsCtrl, l10n.get('targetReps')),
                    ],
                  ),
                  if (type == ProgressionType.doubleProgression) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        numField(minRepsCtrl, l10n.get('minReps')),
                        const SizedBox(width: 8),
                        numField(maxRepsCtrl, l10n.get('maxReps')),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      numField(
                        defWeightCtrl,
                        '${l10n.get('defaultWeight')} (kg)',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      numField(defSetsCtrl, l10n.get('defaultSets')),
                      const SizedBox(width: 8),
                      numField(defRepsCtrl, l10n.get('defaultReps')),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.get('onlyIfCompleted')),
                    value: onlyIfCompleted,
                    onChanged: (v) =>
                        setSheet(() => onlyIfCompleted = v ?? true),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (existing != null)
                        TextButton.icon(
                          onPressed: () async {
                            await ref
                                .read(progressionRulesProvider.notifier)
                                .delete(exercise.id);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.get('ruleDeleted')),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          label: Text(
                            l10n.get('delete'),
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(l10n.get('cancel')),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final rule = ProgressionRule(
                            id:
                                existing?.id ??
                                DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                            userId: userId,
                            exerciseId: exercise.id,
                            type: type,
                            enabled: enabled,
                            increment:
                                double.tryParse(incrementCtrl.text) ?? 2.5,
                            targetSets: int.tryParse(targetSetsCtrl.text) ?? 3,
                            targetReps: int.tryParse(targetRepsCtrl.text) ?? 8,
                            minReps: type == ProgressionType.doubleProgression
                                ? int.tryParse(minRepsCtrl.text)
                                : existing?.minReps,
                            maxReps: type == ProgressionType.doubleProgression
                                ? int.tryParse(maxRepsCtrl.text)
                                : existing?.maxReps,
                            defaultWeightKg: double.tryParse(
                              defWeightCtrl.text,
                            ),
                            defaultSets: int.tryParse(defSetsCtrl.text),
                            defaultReps: int.tryParse(defRepsCtrl.text),
                            onlyIfCompleted: onlyIfCompleted,
                          );
                          await ref
                              .read(progressionRulesProvider.notifier)
                              .save(rule);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.get('ruleSaved'))),
                            );
                          }
                        },
                        child: Text(l10n.get('save')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  incrementCtrl.dispose();
  targetSetsCtrl.dispose();
  targetRepsCtrl.dispose();
  minRepsCtrl.dispose();
  maxRepsCtrl.dispose();
  defWeightCtrl.dispose();
  defSetsCtrl.dispose();
  defRepsCtrl.dispose();
}

class _PendingSet {
  final String exerciseId;
  final int sets, reps;
  final double weight;
  final String? programId;
  final String? programDayId;
  final String? programExerciseId;
  _PendingSet({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.weight,
    this.programId,
    this.programDayId,
    this.programExerciseId,
  });
}
