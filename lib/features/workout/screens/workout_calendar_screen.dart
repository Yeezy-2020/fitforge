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

class WorkoutCalendarScreen extends ConsumerStatefulWidget {
  const WorkoutCalendarScreen({super.key});
  @override
  ConsumerState<WorkoutCalendarScreen> createState() => _WorkoutCalendarScreenState();
}

class _WorkoutCalendarScreenState extends ConsumerState<WorkoutCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _calendarExpanded = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    ref.read(workoutCacheProvider.notifier).loadMonth(_focusedDay);
    if (_selectedDay != null) {
      ref.read(workoutLogCacheProvider.notifier).loadDate(_selectedDay!);
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
    ref.read(selectedDateProvider.notifier).state = selectedDay;
    ref.read(workoutLogCacheProvider.notifier).loadDate(selectedDay);
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
      appBar: AppBar(
        title: Text(l10n.get('training')),
        actions: [
          if (_selectedDay != null)
            IconButton(
              icon: Icon(_calendarExpanded ? Icons.expand_less : Icons.expand_more),
              tooltip: _calendarExpanded ? 'Hide calendar' : 'Show calendar',
              onPressed: () => setState(() => _calendarExpanded = !_calendarExpanded),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_workout',
        onPressed: () {
          final date = _selectedDay ?? DateTime.now();
          context.push('/home/day/${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.get('logWorkout')),
      ),
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _calendarExpanded
                ? TableCalendar(
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
                  )
                : const SizedBox.shrink(),
          ),
          if (!_calendarExpanded)
            GestureDetector(
              onTap: () => setState(() => _calendarExpanded = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Center(child: Icon(Icons.expand_more, size: 20, color: Colors.grey.shade500)),
              ),
            ),
          Expanded(
            child: _selectedDay != null
                ? _WorkoutDaySummary(l10n: l10n, date: _selectedDay!)
                : Center(child: Text(l10n.get('selectBodyPart'))),
          ),
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
          TextButton.icon(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), label: Text(l10n.get('delete'), style: const TextStyle(color: Colors.red)), onPressed: () { Navigator.pop(ctx); _confirmDelete(ctx, ref, log); }),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.get('cancel'))),
          FilledButton(onPressed: () {
            final newSets = int.tryParse(setsCtrl.text)?.clamp(1, 999) ?? log.sets;
            final newReps = int.tryParse(repsCtrl.text)?.clamp(1, 9999) ?? log.reps;
            double newWeight = double.tryParse(weightCtrl.text) ?? log.weightKg;
            if (trainUnit == WeightUnit.lb) newWeight = newWeight / kgToLb;
            final updated = WorkoutLog(id: log.id, userId: log.userId, exerciseId: log.exerciseId, date: log.date, sets: newSets, reps: newReps, weightKg: newWeight, createdAt: log.createdAt);
            AppDatabase.instance.deleteWorkoutLog(ref.read(currentUserIdProvider), log.id);
            AppDatabase.instance.addWorkoutLog(ref.read(currentUserIdProvider), updated);
            try { ref.read(supabaseProvider).addWorkoutLog(updated); } catch (_) {}
            ref.read(workoutLogCacheProvider.notifier).loadDate(date);
            Navigator.pop(ctx);
          }, child: Text(l10n.get('save'))),
        ],
      ),
    );
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
            ref.read(workoutLogCacheProvider.notifier).loadDate(date);
            ref.read(workoutCacheProvider.notifier).loadMonth(date);
            Navigator.pop(ctx);
          }, child: Text(l10n.get('delete'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final logsToShow = cachedLogs.isNotEmpty ? cachedLogs : [];
    if (logsToShow.isEmpty) {
      return Center(child: Text('No workout for ${DateFormat('MMM d').format(date)}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)));
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: logsToShow.length,
      onReorder: (oldIndex, newIndex) {
        // Reorder in cache
        final list = List<WorkoutLog>.from(logsToShow);
        if (newIndex > oldIndex) newIndex--;
        final item = list.removeAt(oldIndex);
        list.insert(newIndex, item);
        ref.read(workoutLogCacheProvider.notifier).addLogs(date, []);
        for (final l in list) {
          ref.read(workoutLogCacheProvider.notifier).addLogs(date, [l]);
        }
      },
      buildDefaultDragHandles: true,
      proxyDecorator: (child, index, animation) => Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
      itemBuilder: (context, index) {
        final log = logsToShow[index];
        return Card(
          key: ValueKey(log.id),
          margin: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _editWorkout(context, ref, log, exName(log.exerciseId)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.drag_handle, size: 20, color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(exName(log.exerciseId), style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text('${log.sets} x ${log.reps}  ${formatTrainingWeight(log.weightKg, trainUnit)}', style: Theme.of(context).textTheme.bodyMedium),
                  ]),
                ),
                const Icon(Icons.edit, size: 14, color: Colors.grey),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _GroupedSet {
  final int sets, reps;
  final double weight;
  _GroupedSet(this.sets, this.reps, this.weight);
}
