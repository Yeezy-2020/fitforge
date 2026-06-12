import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
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
  const _WorkoutDaySummary({required this.l10n, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(workoutLogsForDateProvider(date));
    final logCache = ref.watch(workoutLogCacheProvider);
    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final cachedLogs = logCache[dateKey] ?? [];
    // Use cached logs if available (instant), otherwise fall back to async provider
    final exercises = ref.watch(exerciseListProvider).valueOrNull ?? [];
    final trainUnit = ref.watch(trainingWeightUnitProvider);
    final l10n = ref.watch(l10nProvider);
  Widget _buildLogList(List<WorkoutLog> logs, List<Exercise> exercises, L10n l10n, WeightUnit trainUnit) {
    String exerciseName(String id) {
      final ex = exercises.where((e) => e.id == id).firstOrNull;
      if (ex == null) return id;
      return l10n.exerciseName(ex.id, ex.name);
    }
    if (logs.isEmpty) {
      return Center(child: Text('No workout for ${DateFormat('MMM d').format(date)}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)));
    }
    final grouped = <String, List<_GroupedSet>>{};
    for (final log in logs) { grouped.putIfAbsent(log.exerciseId, () => []); grouped[log.exerciseId]!.add(_GroupedSet(log.sets, log.reps, log.weightKg)); }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: grouped.entries.map((entry) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exerciseName(entry.key), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            ...entry.value.map((s) => Text(formatTrainingWeight(s.weight, trainUnit), style: Theme.of(context).textTheme.bodyMedium)),
          ]),
        ),
      )).toList(),
    );
  }

    return Expanded(
      child: cachedLogs.isNotEmpty
          ? _buildLogList(cachedLogs, exercises, l10n, trainUnit)
          : logsAsync.when(
              data: (logs) => _buildLogList(logs, exercises, l10n, trainUnit),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(child: Text(l10n.get('failedToLoad'))),
            ),
    );
  }
}

class _GroupedSet {
  final int sets, reps;
  final double weight;
  _GroupedSet(this.sets, this.reps, this.weight);
}
