import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../data/models/exercise.dart';
import '../../../data/models/workout_log.dart';
import '../../../data/repositories/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../core/localization/l10n.dart';
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
        title: const Text('Save as Template'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(hintText: 'Template name'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Template "$name" saved')));
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

  void _addToPending(String exerciseId, int sets, int reps, double weight) {
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
      bodyPart: _selectedBodyPart ?? 'Custom',
      category: 'Custom',
    );
    ref.read(exerciseListProvider.notifier).addExercise(exercise);
    _addToPending(exId, sets, reps, weight);
    _customNameCtrl.clear();
    _customRepsCtrl.clear();
    _customWeightCtrl.clear();
    _customSetsCtrl.text = '3';
  }

  Future<void> _saveAll() async {
    final l10n = ref.read(l10nProvider);
    final userId = ref.read(currentUserIdProvider);
    final savedLogs = <WorkoutLog>[];
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
      ).showSnackBar(SnackBar(content: Text(l10n.get('workoutSaved'))));
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
        title: Text(
          '${DateFormat('MMM d').format(widget.date)} ${l10n.get('workout')}',
        ),
        actions: [
          if (_pendingSets.isNotEmpty)
            TextButton.icon(
              onPressed: _saveAll,
              icon: const Icon(Icons.save),
              label: Text('${l10n.get('save')} (${_pendingSets.length})'),
            ),
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            tooltip: 'Templates',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TemplatesScreen()),
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
              tooltip: 'Save as Template',
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
                        '${l10n.get('pending')}: ${_pendingSets.length} sets',
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
            child: _buildMainContent(l10n, bodyParts, filtered, trainUnit),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    L10n l10n,
    List<String> bodyParts,
    List<Exercise> filtered,
    WeightUnit trainUnit,
  ) {
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
              : _buildExerciseList(l10n, filtered, trainUnit),
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
              onAdd: (id, sets, reps, weight) =>
                  _addToPending(id, sets, reps, weight),
            ),
          )
          .toList(),
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  final Exercise exercise;
  final L10n l10n;
  final WeightUnit trainUnit;
  final void Function(String exerciseId, int sets, int reps, double weight)
  onAdd;
  const _ExerciseCard({
    super.key,
    required this.exercise,
    required this.l10n,
    required this.trainUnit,
    required this.onAdd,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  late TextEditingController _setsCtrl, _repsCtrl, _weightCtrl;

  @override
  void initState() {
    super.initState();
    _setsCtrl = TextEditingController();
    _repsCtrl = TextEditingController();
    _weightCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = widget.trainUnit == WeightUnit.kg ? 'kg' : 'lb';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExerciseDetailScreen(exercise: widget.exercise),
          ),
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
                      final sets = int.tryParse(_setsCtrl.text) ?? 3;
                      final reps = int.tryParse(_repsCtrl.text) ?? 0;
                      double w = double.tryParse(_weightCtrl.text) ?? 0;
                      if (widget.trainUnit == WeightUnit.lb) w = w / kgToLb;
                      widget.onAdd(widget.exercise.id, sets, reps, w);
                      _repsCtrl.clear();
                      _weightCtrl.clear();
                      _setsCtrl.clear();
                      _repsCtrl.clear();
                      _weightCtrl.clear();
                      _setsCtrl.clear();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add', style: TextStyle(fontSize: 12)),
                  ),
                ],
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

class _PendingSet {
  final String exerciseId;
  final int sets, reps;
  final double weight;
  _PendingSet({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.weight,
  });
}
