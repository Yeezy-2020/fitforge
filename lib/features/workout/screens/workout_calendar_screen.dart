import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../data/models/workout_log.dart';
import '../../../data/models/exercise.dart';
import '../../../data/repositories/app_database.dart';
import '../../../core/services/supabase_service.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../core/localization/l10n.dart';
import '../../../data/models/workout_log.dart';
import '../../../data/models/exercise.dart';

class WorkoutCalendarScreen extends ConsumerStatefulWidget {
  const WorkoutCalendarScreen({super.key});

  @override
  ConsumerState<WorkoutCalendarScreen> createState() => _WorkoutCalendarScreenState();
}

class _WorkoutCalendarScreenState extends ConsumerState<WorkoutCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    ref.read(workoutCacheProvider.notifier).loadMonth(_focusedDay);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
    ref.read(selectedDateProvider.notifier).state = selectedDay;
  }

  void _onPageChanged(DateTime focusedDay) {
    setState(() => _focusedDay = focusedDay);
    ref.read(workoutCacheProvider.notifier).loadMonth(focusedDay);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final cache = ref.watch(workoutCacheProvider);
    final k = '${_focusedDay.year}-${_focusedDay.month.toString().padLeft(2, '0')}';
    final workoutDates = cache[k] ?? {};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.get('training'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_workout',
        onPressed: () {
          final date = _selectedDay ?? DateTime.now();
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          context.push('/home/day/$dateStr');
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.get('logWorkout')),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime(2020), lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            onPageChanged: _onPageChanged,
            locale: ref.watch(localeProvider) == AppLocale.zh ? 'zh_CN' : 'en_US',
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (workoutDates.any((d) => isSameDay(d, date))) {
                  return Positioned(bottom: 1, child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)));
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 8),
          if (_selectedDay != null) _WorkoutDaySummary(l10n: l10n, date: _selectedDay!),
        ],
      ),
    );
  }
}

class _WorkoutDaySummary extends ConsumerWidget {
  final L10n l10n;
  final DateTime date;
  _WorkoutDaySummary({required this.l10n, required this.date});

  void _editWorkout(BuildContext context, WidgetRef ref, WorkoutLog log, String exerciseName) {
    final trainUnit = ref.read(trainingWeightUnitProvider);
    final l10n = ref.read(l10nProvider);
    final setsCtrl = TextEditingController(text: log.sets.toString());
    final repsCtrl = TextEditingController(text: log.reps.toString());
    final weightCtrl = TextEditingController(text: (trainUnit == WeightUnit.lb ? (log.weightKg * kgToLb) : log.weightKg).toStringAsFixed(1));
    final unitLabel = trainUnit == WeightUnit.kg ? 'kg' : 'lb';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(exerciseName),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: TextField(controller: setsCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(labelText: l10n.get('sets'), isDense: true))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: repsCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(labelText: l10n.get('reps'), isDense: true))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: weightCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(labelText: unitLabel, isDense: true))),
          ]),
        ]),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            label: Text(l10n.get('delete'), style: const TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete(ctx, ref, log);
            },
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.get('cancel'))),
          FilledButton(onPressed: () {
            final newSets = int.tryParse(setsCtrl.text)?.clamp(1, 999) ?? log.sets;
            final newReps = int.tryParse(repsCtrl.text)?.clamp(1, 9999) ?? log.reps;
            double newWeight = double.tryParse(weightCtrl.text) ?? log.weightKg;
            if (trainUnit == WeightUnit.lb) newWeight = newWeight / kgToLb;
            final updated = WorkoutLog(id: log.id, userId: log.userId, exerciseId: log.exerciseId, date: log.date, sets: newSets, reps: newReps, weightKg: newWeight, createdAt: log.createdAt);
            _updateInCache(ref, log, updated);
            Navigator.pop(ctx);
          }, child: Text(l10n.get('save'))),
        ],
      ),
    );
  }

  void _updateInCache(WidgetRef ref, WorkoutLog oldLog, WorkoutLog newLog) {
    // Our cache stores lists of logs per date. We need to replace the old log.
    // Simplest approach: delete old from Supabase, add new, then reload.
    AppDatabase.instance.deleteWorkoutLog(ref.read(currentUserIdProvider), oldLog.id);
    AppDatabase.instance.addWorkoutLog(ref.read(currentUserIdProvider), newLog);
    try { ref.read(supabaseProvider).addWorkoutLog(newLog); } catch (_) {}
    ref.invalidate(workoutLogsForDateProvider);
    // Force cache reload
    ref.read(workoutLogCacheProvider.notifier).loadDate(date);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, WorkoutLog log) {
    final l10n = ref.read(l10nProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.get('delete')),
        content: Text(l10n.get('deleteConfirmShort')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.get('cancel'))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () {
            AppDatabase.instance.deleteWorkoutLog(ref.read(currentUserIdProvider), log.id);
            try { ref.read(supabaseProvider).deleteWorkoutLog(log.id); } catch (_) {}
            ref.invalidate(workoutLogsForDateProvider);
            ref.read(workoutLogCacheProvider.notifier).loadDate(date);
            ref.read(workoutCacheProvider.notifier).loadMonth(date);
            Navigator.pop(ctx);
          }, child: Text(l10n.get('delete'))),
        ],
      ),
    );
  }

  BuildContext? _lastContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _lastContext = context;
    final logCache = ref.watch(workoutLogCacheProvider);
    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final cachedLogs = logCache[dateKey] ?? [];
    final exercises = ref.watch(exerciseListProvider).valueOrNull ?? [];
    final trainUnit = ref.watch(trainingWeightUnitProvider);
    String exName(String id) {
      final ex = exercises.where((e) => e.id == id).firstOrNull;
      if (ex == null) return id;
      return ref.read(l10nProvider).exerciseName(ex.id, ex.name);
    }

    return Expanded(
      child: cachedLogs.isNotEmpty
          ? _buildLogList(context, ref, cachedLogs, exName, trainUnit)
          : ref.watch(workoutLogsForDateProvider(date)).when(
              data: (logs) => _buildLogList(context, ref, logs, exName, trainUnit),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(child: Text(l10n.get('failedToLoad'))),
            ),
    );
  }

  Widget _buildLogList(BuildContext context, WidgetRef ref, List<WorkoutLog> logs, String Function(String) exName, WeightUnit trainUnit) {
    if (logs.isEmpty) return Center(child: Text('No workout for ${DateFormat('MMM d').format(date)}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)));
    final grouped = <String, List<WorkoutLog>>{};
    for (final log in logs) { grouped.putIfAbsent(log.exerciseId, () => []); grouped[log.exerciseId]!.add(log); }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: grouped.entries.map((entry) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exName(entry.key), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            ...entry.value.map((log) => InkWell(
              onTap: () => _editWorkout(context, ref, log, exName(entry.key)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(child: Text('${log.sets} x ${log.reps}  ${formatTrainingWeight(log.weightKg, trainUnit)}', style: Theme.of(context).textTheme.bodyMedium)),
                  const Icon(Icons.edit, size: 14, color: Colors.grey),
                ]),
              ),
            )),
          ]),
        ),
      )).toList(),
    );
  }
}

class _GroupedSet {
  final int sets, reps;
  final double weight;
  _GroupedSet(this.sets, this.reps, this.weight);
}
