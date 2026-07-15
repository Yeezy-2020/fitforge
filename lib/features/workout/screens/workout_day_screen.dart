import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/workout_log_builder.dart';
import '../../../data/models/exercise.dart';
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

part 'workout_day_exercise_card.dart';
part 'workout_day_progression_sheet.dart';

const _uuid = Uuid();

class _WorkoutSaveAttempt {
  final UserScope userScope;
  final String userId;
  final DateTime selectedDate;
  final List<WorkoutEntryDraft> drafts;
  final WorkoutSavePlan savePlan;
  final WorkoutLogWriteStore writeStore;
  final WorkoutLogRemoteWriter remoteWriter;
  final TrainingProgramsNotifier programsNotifier;
  final WorkoutCacheNotifier workoutCache;
  final WorkoutLogCacheNotifier workoutLogCache;
  int completedBundleCount = 0;
  bool programAdvanceAttempted = false;
  bool programAdvanced = false;
  bool cachePublished = false;
  final Set<String> completedRemoteLogIds = {};

  _WorkoutSaveAttempt({
    required this.userScope,
    required this.userId,
    required this.selectedDate,
    required this.drafts,
    required this.savePlan,
    required this.writeStore,
    required this.remoteWriter,
    required this.programsNotifier,
    required this.workoutCache,
    required this.workoutLogCache,
  });
}

class WorkoutDayScreen extends ConsumerStatefulWidget {
  final DateTime date;
  const WorkoutDayScreen({super.key, required this.date});

  @override
  ConsumerState<WorkoutDayScreen> createState() => _WorkoutDayScreenState();
}

class _WorkoutDayScreenState extends ConsumerState<WorkoutDayScreen> {
  String? _selectedBodyPart;
  List<WorkoutEntryDraft> _pendingSets = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final _customNameCtrl = TextEditingController();
  final _customSetsCtrl = TextEditingController(text: '3');
  final _customRepsCtrl = TextEditingController();
  final _customWeightCtrl = TextEditingController();
  UserScope? _draftUserScope;
  _WorkoutSaveAttempt? _saveAttempt;
  bool _isSaving = false;
  bool _isAdvancingRestDay = false;

  bool get _draftLocked => _isSaving || _saveAttempt != null;

  @override
  void initState() {
    super.initState();
    ref.listenManual<UserScope>(currentUserScopeProvider, (previous, next) {
      if (previous == null || identical(previous, next) || !mounted) return;
      setState(() {
        _pendingSets = [];
        _draftUserScope = null;
        _saveAttempt = null;
      });
    });
  }

  Future<void> _saveAsTemplate() async {
    if (_draftLocked) return;
    final l10n = ref.read(l10nProvider);
    final userScope = ref.read(currentUserScopeProvider);
    if (userScope.userId.isEmpty ||
        _pendingSets.isEmpty ||
        !identical(_draftUserScope, userScope)) {
      return;
    }
    final drafts = List<WorkoutEntryDraft>.unmodifiable(_pendingSets);
    final database = AppDatabase.instance;
    var pendingName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.get('saveAsTemplate')),
        content: TextField(
          decoration: InputDecoration(hintText: l10n.get('templateName')),
          onChanged: (value) => pendingName = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, pendingName.trim()),
            child: Text(l10n.get('save')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (!_isCurrentUserScope(userScope)) return;
    final template = WorkoutTemplate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      exercises: drafts
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
    await database.saveTemplate(userScope.userId, template);
    if (!mounted) return;
    if (!_isCurrentUserScope(userScope)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.format('templateSaved', {'name': name}))),
    );
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
    final userScope = ref.read(currentUserScopeProvider);
    if (userScope.userId.isEmpty || _draftLocked) return;
    if (reps <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.get('pleaseEnterValid'))));
      return;
    }
    setState(() {
      if (!identical(_draftUserScope, userScope)) {
        _pendingSets = [];
        _draftUserScope = userScope;
      }
      _pendingSets.add(
        WorkoutEntryDraft(
          exerciseId: exerciseId,
          sets: sets,
          reps: reps,
          weight: weight,
          programId: programId,
          programDayId: programDayId,
          programExerciseId: programExerciseId,
        ),
      );
    });
  }

  void _addProgramPrescription(
    WorkoutPrescription rx, {
    bool useLastLogged = false,
  }) {
    _addToPending(
      rx.exerciseId,
      useLastLogged ? rx.lastLoggedSets! : rx.sets,
      useLastLogged ? rx.lastLoggedReps! : rx.reps,
      useLastLogged ? rx.lastLoggedWeightKg! : rx.weightKg,
      programId: rx.programId,
      programDayId: rx.programDayId,
      programExerciseId: rx.programExerciseId,
    );
  }

  Future<void> _addAllProgramPrescriptions(
    List<WorkoutPrescription> prescriptions,
    L10n l10n,
  ) async {
    if (_draftLocked) return;
    final userScope = ref.read(currentUserScopeProvider);
    if (userScope.userId.isEmpty) return;
    final recoveryCount = prescriptions
        .where((rx) => rx.shouldOfferRecoveryLoad)
        .length;
    var useRecoveryLoads = false;
    if (recoveryCount > 0) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.get('extendedBreakDialogTitle')),
          content: Text(
            l10n.format('extendedBreakDialogBody', {
              'count': recoveryCount.toString(),
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.get('usePlannedLoad')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.get('useLastLoad')),
            ),
          ],
        ),
      );
      if (choice == null) return;
      useRecoveryLoads = choice;
    }
    if (!_isCurrentUserScope(userScope) || _draftLocked) return;
    for (final rx in prescriptions) {
      _addProgramPrescription(
        rx,
        useLastLogged: useRecoveryLoads && rx.shouldOfferRecoveryLoad,
      );
    }
  }

  void _addCustomExercise() {
    if (_draftLocked) return;
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

  bool _isCurrentUserScope(UserScope expectedScope) {
    if (!mounted) return false;
    return identical(ref.read(currentUserScopeProvider), expectedScope);
  }

  Future<void> _advanceActiveProgram(L10n l10n) async {
    if (_isAdvancingRestDay) return;
    final userScope = ref.read(currentUserScopeProvider);
    if (userScope.userId.isEmpty) return;
    final programsNotifier = ref.read(trainingProgramsProvider.notifier);
    final date = widget.date;
    setState(() => _isAdvancingRestDay = true);
    try {
      await programsNotifier.advanceDay(expectedUserId: userScope.userId);
      if (!mounted) return;
      if (!_isCurrentUserScope(userScope)) return;
      ref.invalidate(workoutPrescriptionsForDateProvider(date));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.get('programAdvanced'))));
    } catch (_) {
      if (!mounted) return;
      if (!_isCurrentUserScope(userScope)) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.get('failedToLoad'))));
    } finally {
      if (mounted) setState(() => _isAdvancingRestDay = false);
    }
  }

  Future<void> _saveAll() async {
    if (_isSaving || _pendingSets.isEmpty) return;
    final userScope = ref.read(currentUserScopeProvider);
    if (userScope.userId.isEmpty || !identical(_draftUserScope, userScope)) {
      return;
    }
    final l10n = ref.read(l10nProvider);
    setState(() => _isSaving = true);
    try {
      await _saveAllOnce(userScope, l10n);
    } catch (_) {
      if (!mounted) return;
      if (!_isCurrentUserScope(userScope)) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.get('failedToLoad'))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAllOnce(UserScope userScope, L10n l10n) async {
    final userId = userScope.userId;
    var attempt = _saveAttempt;
    if (attempt != null && !identical(attempt.userScope, userScope)) return;

    if (attempt == null) {
      final selectedDate = widget.date;
      final selectedDateIsToday = _selectedDateIsToday;
      final drafts = List<WorkoutEntryDraft>.unmodifiable(_pendingSets);
      final activeProgramFuture = ref.read(
        activeTrainingProgramProvider.future,
      );
      final writeStore = ref.read(workoutLogWriteStoreProvider);
      final remoteWriter = ref.read(workoutLogRemoteWriterProvider);
      final programsNotifier = ref.read(trainingProgramsProvider.notifier);
      final workoutCache = ref.read(workoutCacheProvider.notifier);
      final workoutLogCache = ref.read(workoutLogCacheProvider.notifier);
      final activeProgram = await activeProgramFuture;
      if (!_isCurrentUserScope(userScope) ||
          !identical(_draftUserScope, userScope)) {
        return;
      }
      final activeProgramDay = activeProgram?.isPausedOn(selectedDate) == true
          ? null
          : activeProgram?.currentDay;
      final savePlan = buildWorkoutSavePlan(
        drafts: drafts,
        userId: userId,
        workoutDate: selectedDate,
        createdAt: DateTime.now(),
        idFactory: _uuid.v4,
        activeProgram: activeProgram,
        activeProgramDay: activeProgramDay,
        selectedDateIsToday: selectedDateIsToday,
      );
      attempt = _WorkoutSaveAttempt(
        userScope: userScope,
        userId: userId,
        selectedDate: selectedDate,
        drafts: drafts,
        savePlan: savePlan,
        writeStore: writeStore,
        remoteWriter: remoteWriter,
        programsNotifier: programsNotifier,
        workoutCache: workoutCache,
        workoutLogCache: workoutLogCache,
      );
      _saveAttempt = attempt;
    }

    for (
      var index = attempt.completedBundleCount;
      index < attempt.savePlan.bundles.length;
      index += 1
    ) {
      final bundle = attempt.savePlan.bundles[index];
      await attempt.writeStore.addWorkoutLog(userId, bundle.workoutLog);
      if (bundle.setLogs.isNotEmpty) {
        await attempt.writeStore.saveWorkoutSetLogs(userId, bundle.setLogs);
      }
      attempt.completedBundleCount = index + 1;
    }
    if (!_isCurrentUserScope(userScope)) return;

    String message = l10n.get('workoutSaved');
    if (attempt.savePlan.shouldAdvanceProgram &&
        !attempt.programAdvanceAttempted) {
      if (!_isCurrentUserScope(userScope)) return;
      attempt.programAdvanceAttempted = true;
      try {
        await attempt.programsNotifier.advanceDay(expectedUserId: userId);
        attempt.programAdvanced = true;
      } catch (_) {
        // The mutation may already have committed. Never issue it twice.
      }
      if (!_isCurrentUserScope(userScope)) return;
    }
    if (attempt.programAdvanced) {
      message = '${l10n.get('workoutSaved')} · ${l10n.get('programAdvanced')}';
    }

    if (!attempt.cachePublished) {
      if (!_isCurrentUserScope(userScope)) return;
      attempt.cachePublished = true;
      attempt.workoutCache.addDate(attempt.selectedDate);
      attempt.workoutLogCache.addLogs(
        attempt.selectedDate,
        attempt.savePlan.workoutLogs,
      );
    }

    for (final log in attempt.savePlan.workoutLogs) {
      if (attempt.completedRemoteLogIds.contains(log.id)) continue;
      if (!_isCurrentUserScope(userScope)) return;
      try {
        await attempt.remoteWriter.addWorkoutLog(log, expectedUserId: userId);
      } catch (_) {
        if (!_isCurrentUserScope(userScope)) return;
        try {
          await attempt.writeStore.addUnsyncedWorkout(userId, log);
        } catch (_) {
          // Local workout success is final even if sync bookkeeping fails.
        }
      }
      attempt.completedRemoteLogIds.add(log.id);
      if (!_isCurrentUserScope(userScope)) return;
    }

    if (!mounted) return;
    if (!_isCurrentUserScope(userScope)) return;
    if (!identical(_saveAttempt, attempt) ||
        !identical(_draftUserScope, userScope)) {
      return;
    }
    ref.invalidate(workoutLogsForDateProvider);
    setState(() {
      _pendingSets = [];
      _draftUserScope = null;
      _saveAttempt = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    context.pop();
  }

  bool _matchesPendingDraft(
    UserScope userScope,
    int idx,
    WorkoutEntryDraft expectedDraft,
  ) {
    return _isCurrentUserScope(userScope) &&
        identical(_draftUserScope, userScope) &&
        idx >= 0 &&
        idx < _pendingSets.length &&
        identical(_pendingSets[idx], expectedDraft);
  }

  void _confirmDeletePending(
    int idx, {
    UserScope? expectedScope,
    WorkoutEntryDraft? expectedDraft,
  }) {
    if (_draftLocked) return;
    final UserScope userScope =
        expectedScope ?? ref.read(currentUserScopeProvider);
    if (idx < 0 || idx >= _pendingSets.length) return;
    final draft = expectedDraft ?? _pendingSets[idx];
    if (!_matchesPendingDraft(userScope, idx, draft)) return;
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
              if (_draftLocked ||
                  !_matchesPendingDraft(userScope, idx, draft)) {
                Navigator.pop(ctx);
                return;
              }
              setState(() {
                _pendingSets.removeAt(idx);
                if (_pendingSets.isEmpty) _draftUserScope = null;
              });
              Navigator.pop(ctx);
            },
            child: Text(l10n.get('delete')),
          ),
        ],
      ),
    );
  }

  void _editPending(
    int idx,
    WorkoutEntryDraft p,
    L10n l10n,
    WeightUnit trainUnit,
  ) {
    if (_draftLocked) return;
    final userScope = ref.read(currentUserScopeProvider);
    if (!_matchesPendingDraft(userScope, idx, p)) return;
    var setsText = p.sets.toString();
    var repsText = p.reps.toString();
    var weightText =
        (trainUnit == WeightUnit.lb ? (p.weight * kgToLb) : p.weight)
            .toStringAsFixed(1);
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
                  child: TextFormField(
                    initialValue: setsText,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: l10n.get('sets'),
                      isDense: true,
                    ),
                    onChanged: (value) => setsText = value,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: repsText,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: l10n.get('reps'),
                      isDense: true,
                    ),
                    onChanged: (value) => repsText = value,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: weightText,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: unitLabel,
                      isDense: true,
                    ),
                    onChanged: (value) => weightText = value,
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
              _confirmDeletePending(
                idx,
                expectedScope: userScope,
                expectedDraft: p,
              );
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
              if (_draftLocked || !_matchesPendingDraft(userScope, idx, p)) {
                Navigator.pop(ctx);
                return;
              }
              final newSets = int.tryParse(setsText) ?? p.sets;
              final newReps = int.tryParse(repsText) ?? p.reps;
              double newWeight = double.tryParse(weightText) ?? p.weight;
              if (trainUnit == WeightUnit.lb) newWeight = newWeight / kgToLb;
              setState(() {
                _pendingSets[idx] = WorkoutEntryDraft(
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
    final activeProgramAsync = ref.watch(
      activeTrainingProgramForDateProvider(widget.date),
    );
    final programPrescriptionsAsync = ref.watch(
      workoutPrescriptionsForDateProvider(widget.date),
    );
    final activeProgram = activeProgramAsync.valueOrNull;
    final programPrescriptions = programPrescriptionsAsync.valueOrNull ?? [];
    final programLoadError = switch ((
      activeProgramAsync,
      programPrescriptionsAsync,
    )) {
      (AsyncError(:final error), _) => error,
      (_, AsyncError(:final error)) => error,
      _ => null,
    };
    final programDataLoading =
        activeProgramAsync.isLoading || programPrescriptionsAsync.isLoading;
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
              onPressed: _isSaving ? null : _saveAll,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text('${l10n.get('save')} (${_pendingSets.length})'),
            ),
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            tooltip: l10n.get('templates'),
            onPressed: _draftLocked
                ? null
                : () async {
                    final userScope = ref.read(currentUserScopeProvider);
                    if (userScope.userId.isEmpty) return;
                    final result = await Navigator.push(
                      context,
                      instantPageRoute(const TemplatesScreen()),
                    );
                    if (!_isCurrentUserScope(userScope)) return;
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
              onPressed: _draftLocked ? null : _saveAsTemplate,
            ),
        ],
      ),
      body: Column(
        children: [
          if (programLoadError != null)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                dense: true,
                leading: Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                title: Text(l10n.get('failedToLoad')),
                trailing: IconButton(
                  onPressed: () {
                    ref.invalidate(trainingProgramsProvider);
                    ref.invalidate(
                      activeTrainingProgramForDateProvider(widget.date),
                    );
                    ref.invalidate(
                      workoutPrescriptionsForDateProvider(widget.date),
                    );
                  },
                  tooltip: l10n.get('failedToLoad'),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            )
          else if (programDataLoading)
            const LinearProgressIndicator(minHeight: 2),
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
                        onPressed: _draftLocked
                            ? null
                            : () => setState(() {
                                _pendingSets = [];
                                _draftUserScope = null;
                              }),
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
                        onTap: _draftLocked
                            ? null
                            : () => _editPending(idx, p, l10n, trainUnit),
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
                                onTap: _draftLocked
                                    ? null
                                    : () => _confirmDeletePending(idx),
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
    final day = program.programDayForWorkoutDate(widget.date);
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
                onPressed: _isAdvancingRestDay
                    ? null
                    : () => _advanceActiveProgram(l10n),
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

    final isDeload = day.kind == DayKind.deload;
    final theme = Theme.of(context);
    final headerLabel = isDeload
        ? '${l10n.get(_selectedDateIsToday ? 'todayProgram' : 'scheduledProgram')}: ${l10n.get('deloadDayLabel')} — ${day.name}'
        : '${l10n.get(_selectedDateIsToday ? 'todayProgram' : 'scheduledProgram')}: ${day.name}';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: isDeload
            ? Colors.teal.shade50
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
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
                Icon(
                  isDeload ? Icons.trending_down : Icons.fitness_center,
                  size: 16,
                  color: isDeload ? Colors.teal.shade700 : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    headerLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDeload ? Colors.teal.shade800 : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ...prescriptions.map(
            (rx) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Column(
                children: [
                  Row(
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
                        onPressed: _draftLocked
                            ? null
                            : () => _addProgramPrescription(rx),
                        child: Text(
                          l10n.get('add'),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  if (rx.shouldOfferRecoveryLoad) ...[
                    const SizedBox(height: 2),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.format('extendedBreakPrompt', {
                              'days': rx.daysSinceLastLog.toString(),
                            }),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: _draftLocked
                                  ? null
                                  : () => _addProgramPrescription(
                                      rx,
                                      useLastLogged: true,
                                    ),
                              child: Text(
                                l10n.get('useLastLoad'),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  onPressed: _draftLocked
                      ? null
                      : () => _addAllProgramPrescriptions(prescriptions, l10n),
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
          onPressed: _draftLocked ? null : _addCustomExercise,
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
              addEnabled: !_draftLocked,
              onAdd: (id, sets, reps, weight) =>
                  _addToPending(id, sets, reps, weight),
            ),
          )
          .toList(),
    );
  }
}
