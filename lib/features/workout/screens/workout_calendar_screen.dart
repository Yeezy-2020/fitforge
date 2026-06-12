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
  }

  void _onDaySelected(DateTime d, DateTime f) {
    setState(() { _selectedDay = d; _focusedDay = f; });
    ref.read(selectedDateProvider.notifier).state = d;
  }

  void _onPageChanged(DateTime m) {
    setState(() => _focusedDay = m);
    ref.read(workoutCacheProvider.notifier).loadMonth(m);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final cache = ref.watch(workoutCacheProvider);
    final k = '${_focusedDay.year}-${_focusedDay.month.toString().padLeft(2, '0')}';
    final workoutDates = cache[k] ?? {};
    if (_selectedDay != null) ref.read(workoutLogCacheProvider.notifier).loadDate(_selectedDay!);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.get('training'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_workout',
        onPressed: () {
          final d = _selectedDay ?? DateTime.now();
          context.push('/home/day/${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
        },
        icon: const Icon(Icons.add), label: Text(l10n.get('logWorkout')),
      ),
      body: Column(children: [
        AnimatedSize(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut, alignment: Alignment.topCenter,
          child: _calendarExpanded ? TableCalendar(
            firstDay: DateTime(2020), lastDay: DateTime(2030), focusedDay: _focusedDay,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
            onDaySelected: _onDaySelected, onPageChanged: _onPageChanged,
            locale: ref.watch(localeProvider) == AppLocale.zh ? 'zh_CN' : 'en_US',
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (c, d, _) => workoutDates.any((w) => isSameDay(w, d))
                  ? Positioned(bottom: 1, child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)))
                  : null,
            ),
          ) : const SizedBox.shrink(),
        ),
        Expanded(
          child: _selectedDay != null
              ? NotificationListener<ScrollUpdateNotification>(
                  onNotification: (n) {
                    final px = n.metrics.pixels;
                    if (px > 30 && (n.scrollDelta ?? 0) > 0 && _calendarExpanded) setState(() => _calendarExpanded = false);
                    if (px <= 0 && !_calendarExpanded) setState(() => _calendarExpanded = true);
                    return false;
                  },
                  child: _DaySummary(l10n: l10n, date: _selectedDay!),
                )
              : Center(child: Text(l10n.get('selectBodyPart'))),
        ),
      ]),
    );
  }
}

class _DaySummary extends ConsumerWidget {
  final L10n l10n;
  final DateTime date;
  const _DaySummary({required this.l10n, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logCache = ref.watch(workoutLogCacheProvider);
    final dk = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final logs = logCache[dk] ?? [];
    final exercises = ref.watch(exerciseListProvider).valueOrNull ?? [];
    final trainUnit = ref.watch(trainingWeightUnitProvider);
    String exName(String id) => ref.read(l10nProvider).exerciseName(id, exercises.where((e) => e.id == id).firstOrNull?.name ?? id);

    if (logs.isEmpty) return Center(child: Text(l10n.get('noWorkout'), style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)));

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(8), itemCount: logs.length,
      onReorder: (oldI, newI) {
        final list = List<WorkoutLog>.from(logs);
        if (newI > oldI) newI--;
        list.insert(newI, list.removeAt(oldI));
        ref.read(workoutLogCacheProvider.notifier).loadDate(date);
      },
      buildDefaultDragHandles: true,
      proxyDecorator: (child, i, _) => Material(elevation: 4, borderRadius: BorderRadius.circular(12), child: child),
      itemBuilder: (context, i) {
        final log = logs[i];
        return Card(
          key: ValueKey(log.id), margin: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _edit(context, ref, log, exName(log.exerciseId), date),
            child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
              ReorderableDragStartListener(index: i, child: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.drag_handle, size: 20, color: Colors.grey))),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(exName(log.exerciseId), style: Theme.of(context).textTheme.titleSmall),
                Text('${log.sets} x ${log.reps}  ${formatTrainingWeight(log.weightKg, trainUnit)}', style: Theme.of(context).textTheme.bodyMedium),
              ])),
              const Icon(Icons.edit, size: 14, color: Colors.grey),
            ])),
          ),
        );
      },
    );
  }

  void _edit(BuildContext context, WidgetRef ref, WorkoutLog log, String name, DateTime date) {
    final trainUnit = ref.read(trainingWeightUnitProvider);
    final l = ref.read(l10nProvider);
    final s = TextEditingController(text: log.sets.toString());
    final r = TextEditingController(text: log.reps.toString());
    final w = TextEditingController(text: (trainUnit == WeightUnit.lb ? (log.weightKg * kgToLb) : log.weightKg).toStringAsFixed(1));
    final u = trainUnit == WeightUnit.kg ? 'kg' : 'lb';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(name),
      content: Column(mainAxisSize: MainAxisSize.min, children: [Row(children: [
        Expanded(child: TextField(controller: s, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(labelText: l.get('sets'), isDense: true))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: r, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(labelText: l.get('reps'), isDense: true))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: w, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(labelText: u, isDense: true))),
      ])]),
      actions: [
        TextButton.icon(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), label: Text(l.get('delete'), style: const TextStyle(color: Colors.red)), onPressed: () { Navigator.pop(ctx); _delConfirm(ctx, ref, log, date); }),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.get('cancel'))),
        FilledButton(onPressed: () {
          final ns = int.tryParse(s.text)?.clamp(1, 999) ?? log.sets;
          final nr = int.tryParse(r.text)?.clamp(1, 9999) ?? log.reps;
          double nw = double.tryParse(w.text) ?? log.weightKg;
          if (trainUnit == WeightUnit.lb) nw = nw / kgToLb;
          final u = WorkoutLog(id: log.id, userId: log.userId, exerciseId: log.exerciseId, date: log.date, sets: ns, reps: nr, weightKg: nw, createdAt: log.createdAt);
          AppDatabase.instance.deleteWorkoutLog(ref.read(currentUserIdProvider), log.id);
          AppDatabase.instance.addWorkoutLog(ref.read(currentUserIdProvider), u);
          try { ref.read(supabaseProvider).addWorkoutLog(u); } catch (_) {}
          ref.read(workoutLogCacheProvider.notifier).loadDate(date);
          Navigator.pop(ctx);
        }, child: Text(l.get('save'))),
      ],
    ));
  }

  void _delConfirm(BuildContext context, WidgetRef ref, WorkoutLog log, DateTime date) {
    final l = ref.read(l10nProvider);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(l.get('delete')), content: Text(l.get('deleteConfirmShort')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.get('cancel'))),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () {
          AppDatabase.instance.deleteWorkoutLog(ref.read(currentUserIdProvider), log.id);
          try { ref.read(supabaseProvider).deleteWorkoutLog(log.id); } catch (_) {}
          ref.read(workoutLogCacheProvider.notifier).loadDate(date);
          ref.read(workoutCacheProvider.notifier).loadMonth(date);
          Navigator.pop(ctx);
        }, child: Text(l.get('delete'))),
      ],
    ));
  }
}
