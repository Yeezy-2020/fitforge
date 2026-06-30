import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../data/models/workout_log.dart';
import '../../../data/models/training_program.dart';

import '../../../data/repositories/app_database.dart';

import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../core/theme/metallic_surface.dart';
import '../../../core/localization/l10n.dart';
import '../widgets/rest_timer.dart';

class WorkoutCalendarScreen extends ConsumerStatefulWidget {
  const WorkoutCalendarScreen({super.key});
  @override
  ConsumerState<WorkoutCalendarScreen> createState() => _State();
}

class _State extends ConsumerState<WorkoutCalendarScreen>
    with AutomaticKeepAliveClientMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _collapsed = false;
  bool _timerExpanded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectedDay = ref.read(selectedDateProvider);
    _focusedDay = _selectedDay ?? DateTime.now();
    _selectedDay ??= DateTime.now();
    ref.read(workoutCacheProvider.notifier).loadMonth(_focusedDay);
  }

  Widget _pill({required VoidCallback onTap, required String text}) {
    final c = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: c.withValues(alpha: 0.15),
        child: Container(
          width: 130,
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: c),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: c,
            ),
          ),
        ),
      ),
    );
  }

  Widget _todayBtn({required VoidCallback onTap, required String text}) {
    final c = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: c.withValues(alpha: 0.15),
        child: Container(
          width: 130,
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(width: 2, color: c),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: c,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = ref.watch(l10nProvider);
    final trainUnit = ref.watch(trainingWeightUnitProvider);
    final cache = ref.watch(workoutCacheProvider);
    final k =
        '${_focusedDay.year}-${_focusedDay.month.toString().padLeft(2, '0')}';
    final workoutDates = cache[k] ?? {};
    final cycleTemplate = ref.watch(nutritionCycleProvider);
    final cycleStartDate = ref.watch(nutritionStartDateProvider);
    final dietCache = ref.watch(dietCacheProvider);
    final activeProgram = ref.watch(activeTrainingProgramProvider);
    final exercises = ref.watch(exerciseListProvider).valueOrNull ?? [];
    final logCache = ref.watch(workoutLogCacheProvider);
    final dk = _selectedDay != null
        ? '${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}'
        : '';
    final logs = logCache[dk] ?? [];
    String exName(String id) => l10n.exerciseName(
      id,
      exercises.where((e) => e.id == id).firstOrNull?.name ?? id,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _pill(
              onTap: () {
                final d = _selectedDay ?? DateTime.now();
                context.push(
                  '/home/day/${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                );
              },
              text: l10n.get('logWorkout'),
            ),
            const Spacer(),
            Text(l10n.get('training'), style: const TextStyle(fontSize: 16)),
            const Spacer(),
            IconButton(
              tooltip: l10n.get('programsTip'),
              icon: const Icon(Icons.assignment_outlined),
              onPressed: () => context.push('/home/programs'),
            ),
            _todayBtn(
              onTap: () {
                final today = DateTime.now();
                setState(() {
                  _focusedDay = today;
                  _selectedDay = today;
                });
                ref.read(selectedDateProvider.notifier).state = today;
              },
              text: l10n.get('todayLabel'),
            ),
          ],
        ),
      ),
      floatingActionButton: null,
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _collapsed
                ? const SizedBox.shrink()
                : MetallicReadingSurface(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                    child: TableCalendar(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2030),
                      focusedDay: _focusedDay,
                      availableCalendarFormats: {
                        CalendarFormat.month: l10n.get('monthLabel'),
                      },
                      selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                      onDaySelected: (d, f) {
                        setState(() {
                          _selectedDay = d;
                          _focusedDay = f;
                        });
                        ref.read(selectedDateProvider.notifier).state = d;
                      },
                      onPageChanged: (m) {
                        setState(() => _focusedDay = m);
                        ref.read(workoutCacheProvider.notifier).loadMonth(m);
                      },
                      locale: ref.watch(localeProvider) == AppLocale.zh
                          ? 'zh_CN'
                          : 'en_US',
                      headerStyle: HeaderStyle(
                        titleCentered: true,
                        titleTextStyle: Theme.of(context).textTheme.titleMedium!
                            .copyWith(
                              color: const Color(0xFF171C20),
                              fontWeight: FontWeight.w800,
                            ),
                        formatButtonTextStyle: const TextStyle(
                          color: Color(0xFF424950),
                          fontWeight: FontWeight.w700,
                        ),
                        formatButtonDecoration: BoxDecoration(
                          color: const Color(0xFFE9EDF1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leftChevronIcon: const Icon(
                          Icons.chevron_left,
                          color: Color(0xFF424950),
                        ),
                        rightChevronIcon: const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF424950),
                        ),
                      ),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                          color: Color(0xFF5A626B),
                          fontWeight: FontWeight.w700,
                        ),
                        weekendStyle: TextStyle(
                          color: Color(0xFF5A626B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        defaultTextStyle: const TextStyle(
                          color: Color(0xFF171C20),
                          fontWeight: FontWeight.w600,
                        ),
                        weekendTextStyle: const TextStyle(
                          color: Color(0xFF171C20),
                          fontWeight: FontWeight.w600,
                        ),
                        outsideTextStyle: const TextStyle(
                          color: Color(0xFF9AA3AD),
                          fontWeight: FontWeight.w500,
                        ),
                        todayTextStyle: const TextStyle(
                          color: Color(0xFF171C20),
                          fontWeight: FontWeight.w800,
                        ),
                        selectedTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        todayDecoration: BoxDecoration(
                          color: const Color(
                            0xFFC9CED3,
                          ).withValues(alpha: 0.55),
                          border: Border.all(
                            color: const Color(0xFF7D8792),
                            width: 1.2,
                          ),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: Color(0xFF56616D),
                          shape: BoxShape.circle,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (c, d, _) {
                          final dateKey =
                              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                          final hasWorkout = workoutDates.any(
                            (w) => isSameDay(w, d),
                          );
                          final hasDiet = (dietCache[dateKey] ?? []).isNotEmpty;
                          final hasCycle = cycleTemplate != null;
                          final programDay = activeProgram?.programDayForDate(
                            d,
                          );
                          final hasProgramDay = programDay != null;
                          if (!hasWorkout &&
                              !hasDiet &&
                              !hasCycle &&
                              !hasProgramDay) {
                            return null;
                          }
                          // Only render cycle markers on or after plan start
                          if (hasCycle) {
                            final startDate = cycleStartDate ?? DateTime.now();
                            final dayIdx = d.difference(startDate).inDays;
                            if (dayIdx < 0) {
                              // Before plan start: hide cycle, show dots only if workout/diet
                              if (!hasWorkout && !hasDiet && !hasProgramDay) {
                                return null;
                              }
                              return Positioned(
                                bottom: 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (hasWorkout)
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Colors.orange,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      if (hasWorkout && hasDiet)
                                        const SizedBox(width: 2),
                                      if (hasDiet)
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      if ((hasWorkout || hasDiet) &&
                                          hasProgramDay)
                                        const SizedBox(width: 2),
                                      if (programDay != null)
                                        _ProgramDayMarker(day: programDay),
                                    ],
                                  ),
                                ),
                              );
                            }
                          }
                          return Positioned(
                            bottom: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasWorkout)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (hasWorkout &&
                                      (hasDiet || hasCycle || hasProgramDay))
                                    const SizedBox(width: 2),
                                  if (hasDiet)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (hasDiet && (hasCycle || hasProgramDay))
                                    const SizedBox(width: 2),
                                  if (hasCycle)
                                    Builder(
                                      builder: (ctx) {
                                        final startDate =
                                            cycleStartDate ?? DateTime.now();
                                        final dayIdx = d
                                            .difference(startDate)
                                            .inDays;
                                        final idx =
                                            dayIdx.clamp(0, 99999) %
                                            cycleTemplate.length;
                                        final t = cycleTemplate[idx];
                                        return Container(
                                          alignment: Alignment.center,
                                          child: Text(
                                            t[0].toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  {
                                                    'high': Colors.orange,
                                                    'medium': Colors.blue,
                                                    'low': Colors.grey,
                                                  }[t] ??
                                                  Colors.grey,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  if (hasCycle && hasProgramDay)
                                    const SizedBox(width: 2),
                                  if (programDay != null)
                                    _ProgramDayMarker(day: programDay),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
          GestureDetector(
            onVerticalDragUpdate: (d) {
              if (d.delta.dy < -10 && !_collapsed) {
                setState(() => _collapsed = true);
              }
              if (d.delta.dy > 10 && _collapsed) {
                setState(() => _collapsed = false);
              }
            },
            onTap: () => setState(() => _collapsed = !_collapsed),
            child: Container(
              height: 24,
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: MetallicReadingSurface(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _selectedDay == null
                  ? Center(child: Text(l10n.get('selectBodyPart')))
                  : logs.isEmpty
                  ? Center(
                      child: Text(
                        l10n.get('noWorkout'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF6D7680),
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: logs.length,
                      buildDefaultDragHandles: false,
                      onReorder: (oldI, newI) {
                        final list = List<WorkoutLog>.from(logs);
                        if (newI > oldI) newI--;
                        list.insert(newI, list.removeAt(oldI));
                        ref
                            .read(workoutLogCacheProvider.notifier)
                            .loadDate(_selectedDay!);
                      },
                      proxyDecorator: (child, i, _) => Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      ),
                      itemBuilder: (context, i) {
                        final log = logs[i];
                        return Card(
                          key: ValueKey(log.id),
                          margin: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _edit(
                              context,
                              ref,
                              log,
                              exName(log.exerciseId),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: i,
                                    child: const Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: Icon(
                                        Icons.drag_handle,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      exName(log.exerciseId),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  Text(
                                    '${log.sets}×${log.reps}  ${formatTrainingWeight(log.weightKg, trainUnit)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          RestTimer(
            expanded: _timerExpanded,
            onToggle: () => setState(() => _timerExpanded = !_timerExpanded),
          ),
        ],
      ),
    );
  }

  void _edit(BuildContext context, WidgetRef ref, WorkoutLog log, String name) {
    final trainUnit = ref.read(trainingWeightUnitProvider);
    final l = ref.read(l10nProvider);
    final s = TextEditingController(text: log.sets.toString());
    final r = TextEditingController(text: log.reps.toString());
    final w = TextEditingController(
      text:
          (trainUnit == WeightUnit.lb ? (log.weightKg * kgToLb) : log.weightKg)
              .toStringAsFixed(1),
    );
    final u = trainUnit == WeightUnit.kg ? 'kg' : 'lb';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: s,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: l.get('sets'),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: r,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: l.get('reps'),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: w,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(labelText: u, isDense: true),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            label: Text(
              l.get('delete'),
              style: const TextStyle(color: Colors.red),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete(ctx, ref, log);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.get('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final ns = int.tryParse(s.text)?.clamp(1, 999) ?? log.sets;
              final nr = int.tryParse(r.text)?.clamp(1, 9999) ?? log.reps;
              double nw = double.tryParse(w.text) ?? log.weightKg;
              if (trainUnit == WeightUnit.lb) nw = nw / kgToLb;
              final up = WorkoutLog(
                id: log.id,
                userId: log.userId,
                exerciseId: log.exerciseId,
                date: log.date,
                sets: ns,
                reps: nr,
                weightKg: nw,
                createdAt: log.createdAt,
              );
              final userId = ref.read(currentUserIdProvider);
              await AppDatabase.instance.deleteWorkoutLog(userId, log.id);
              await AppDatabase.instance.addWorkoutLog(userId, up);
              try {
                await ref.read(supabaseProvider).deleteWorkoutLog(log.id);
                await ref.read(supabaseProvider).addWorkoutLog(up);
              } catch (_) {
                await AppDatabase.instance.addPendingWorkoutDelete(
                  userId,
                  log.id,
                );
                await AppDatabase.instance.addUnsyncedWorkout(userId, up);
              }
              ref.read(workoutLogCacheProvider.notifier).loadDate(log.date);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l.get('save')),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, WorkoutLog log) {
    final l = ref.read(l10nProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('delete')),
        content: Text(l.get('deleteConfirmShort')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.get('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final userId = ref.read(currentUserIdProvider);
              await AppDatabase.instance.deleteWorkoutLog(userId, log.id);
              try {
                await ref.read(supabaseProvider).deleteWorkoutLog(log.id);
              } catch (_) {
                await AppDatabase.instance.addPendingWorkoutDelete(
                  userId,
                  log.id,
                );
              }
              ref.read(workoutLogCacheProvider.notifier).loadDate(log.date);
              ref.read(workoutCacheProvider.notifier).loadMonth(log.date);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l.get('delete')),
          ),
        ],
      ),
    );
  }
}

class _ProgramDayMarker extends StatelessWidget {
  final ProgramDay day;

  const _ProgramDayMarker({required this.day});

  @override
  Widget build(BuildContext context) {
    final isRest = day.kind == DayKind.rest;
    return Icon(
      isRest ? Icons.hotel_outlined : Icons.fitness_center,
      size: 11,
      color: isRest ? Colors.blueGrey : Colors.deepPurple,
    );
  }
}
