part of 'program_detail_screen.dart';

class _ProgramHeader extends StatelessWidget {
  final TrainingProgram program;
  final L10n l10n;
  final VoidCallback? onActivate;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onEnd;

  const _ProgramHeader({
    required this.program,
    required this.l10n,
    required this.onActivate,
    required this.onPause,
    required this.onResume,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trainingDays = program.days
        .where((d) => d.kind == DayKind.training || d.kind == DayKind.deload)
        .length;
    final restDays = program.days.length - trainingDays;
    final isPaused = program.isPausedNow();
    final isScheduled = _isProgramScheduled(program);
    final openPause = program.pausePeriods
        .where((period) => period.endDate == null)
        .lastOrNull;
    final status = isPaused
        ? l10n.format('pausedSince', {
            'date': l10n.shortDate(openPause?.startDate ?? DateTime.now()),
          })
        : isScheduled
        ? l10n.format('scheduledStartDate', {
            'date': l10n.shortDate(program.activatedAt!),
          })
        : program.active
        ? l10n.get('active')
        : l10n.get('program');
    final cycles = program.plannedCycleCount;
    final plannedEnd = program.plannedEndDate();
    final durationText = cycles == null
        ? l10n.get('plannedContinuously')
        : program.active && plannedEnd != null
        ? l10n.format('plannedThrough', {'date': l10n.shortDate(plannedEnd)})
        : l10n.format('plannedCycles', {'count': cycles.toString()});
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPaused
                      ? Icons.pause_circle_outline
                      : isScheduled
                      ? Icons.event_available
                      : program.active
                      ? Icons.check_circle
                      : Icons.assignment_outlined,
                  color: isPaused
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.format('trainingDaysCount', {
                'training': trainingDays.toString(),
                'rest': restDays.toString(),
              }),
              style: theme.textTheme.bodyMedium,
            ),
            if (!isScheduled) ...[
              const SizedBox(height: 2),
              Text(
                l10n.format('currentDayN', {
                  'n': (program.normalizedCurrentDayIndex + 1).toString(),
                }),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: 2),
            Text(
              durationText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!program.active)
                  FilledButton.icon(
                    onPressed: onActivate,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(l10n.get('activateProgram')),
                  ),
                if (program.active)
                  if (isScheduled)
                    OutlinedButton.icon(
                      onPressed: onEnd,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      icon: const Icon(Icons.event_busy, size: 18),
                      label: Text(l10n.get('endProgram')),
                    )
                  else if (isPaused)
                    FilledButton.icon(
                      onPressed: onResume,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(l10n.get('resumeProgram')),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: onPause,
                      icon: const Icon(Icons.pause, size: 18),
                      label: Text(l10n.get('pauseProgram')),
                    ),
                if (program.active && !isScheduled)
                  OutlinedButton.icon(
                    onPressed: onEnd,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: Text(l10n.get('endProgram')),
                  ),
              ],
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
  final int dragIndex;
  final List<Exercise> exercises;
  final bool isEnglish;
  final L10n l10n;
  final VoidCallback onEditDay;
  final VoidCallback onDeleteDay;
  final VoidCallback onAddDeloadAfterDay;
  final VoidCallback onAddExercise;
  final void Function(int exerciseIndex) onEditExercise;
  final void Function(int exerciseIndex) onRemoveExercise;

  const _ProgramDaySection({
    required this.program,
    required this.day,
    required this.dayIndex,
    required this.dragIndex,
    required this.exercises,
    required this.isEnglish,
    required this.l10n,
    required this.onEditDay,
    required this.onDeleteDay,
    required this.onAddDeloadAfterDay,
    required this.onAddExercise,
    required this.onEditExercise,
    required this.onRemoveExercise,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRest = day.kind == DayKind.rest;
    final isDeload = day.kind == DayKind.deload;
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
                ReorderableDelayedDragStartListener(
                  index: dragIndex,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRest
                            ? Icons.hotel
                            : isDeload
                            ? Icons.speed_outlined
                            : Icons.fitness_center,
                        size: 20,
                        color: isDeload
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableDelayedDragStartListener(
                    index: dragIndex,
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        l10n.format('daySectionN', {
                          'n': (dayIndex + 1).toString(),
                          'name': day.name,
                        }),
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.get('addDeloadDay'),
                  icon: const Icon(Icons.playlist_add, size: 20),
                  onPressed: onAddDeloadAfterDay,
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
              ReorderableDelayedDragStartListener(
                index: dragIndex,
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(l10n.get('restDay')),
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              if (isDeload) ...[
                ReorderableDelayedDragStartListener(
                  index: dragIndex,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      l10n.get('deloadDaySubtitle'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (sortedExercises.isEmpty)
                ReorderableDelayedDragStartListener(
                  index: dragIndex,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      l10n.get('noExercisesInDay'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                )
              else
                for (var i = 0; i < sortedExercises.length; i++)
                  _ProgramExerciseTile(
                    dragIndex: dragIndex,
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

bool _isProgramScheduled(TrainingProgram program) {
  final activatedAt = program.activatedAt;
  if (!program.active || activatedAt == null) return false;
  return _dateOnly(activatedAt).isAfter(_dateOnly(DateTime.now()));
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class _ProgramExerciseTile extends StatelessWidget {
  final int dragIndex;
  final ProgramExercise exercise;
  final String name;
  final L10n l10n;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ProgramExerciseTile({
    required this.dragIndex,
    required this.exercise,
    required this.name,
    required this.l10n,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = _programExerciseSubtitle(exercise, l10n);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: ReorderableDelayedDragStartListener(
        index: dragIndex,
        child: SizedBox(
          width: double.infinity,
          child: Text(name, overflow: TextOverflow.ellipsis),
        ),
      ),
      subtitle: ReorderableDelayedDragStartListener(
        index: dragIndex,
        child: SizedBox(width: double.infinity, child: Text(subtitle)),
      ),
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

String _exerciseName(String id, List<Exercise> exercises, bool isEnglish) {
  final exercise = exercises.where((e) => e.id == id).firstOrNull;
  if (exercise == null) return id;
  return exercise.displayName(isEnglish);
}

String _programExerciseSubtitle(ProgramExercise exercise, L10n l10n) {
  final scheme = exercise.progressionScheme;
  final schemeLabel = _progressionSchemeLabel(scheme.type, l10n);
  final reps = _repsSummary(exercise);
  final values = {
    'sets': exercise.targetSets.toString(),
    'reps': reps,
    'weight': exercise.startingWeightKg.toStringAsFixed(1),
    'scheme': schemeLabel,
    'inc': scheme.weightIncrementKg.toStringAsFixed(1),
    'percent': scheme.percentIncrement.toStringAsFixed(1),
  };

  final key = switch (scheme.type) {
    ProgressionSchemeType.fixedLoad =>
      exercise.startingWeightKg > 0 ? 'exSummaryFixedWt' : 'exSummaryFixedNoWt',
    ProgressionSchemeType.linearPeriodization =>
      exercise.startingWeightKg > 0
          ? 'exSummaryLinearPeriodizationWt'
          : 'exSummaryLinearPeriodizationNoWt',
    _ => exercise.startingWeightKg > 0 ? 'exSummaryWt' : 'exSummaryNoWt',
  };
  return l10n.format(key, values);
}

String _repsSummary(ProgramExercise exercise) {
  if (exercise.progressionScheme.type ==
      ProgressionSchemeType.doubleProgression) {
    return '${exercise.minReps}-${exercise.maxReps}';
  }
  if (exercise.progressionScheme.type ==
      ProgressionSchemeType.linearPeriodization) {
    return '${exercise.maxReps}->${exercise.minReps}';
  }
  return exercise.maxReps.toString();
}

String _progressionSchemeLabel(ProgressionSchemeType type, L10n l10n) {
  return switch (type) {
    ProgressionSchemeType.doubleProgression => l10n.get('progDouble'),
    ProgressionSchemeType.linearWeight => l10n.get('progLinear'),
    ProgressionSchemeType.fixedLoad => l10n.get('progFixedLoad'),
    ProgressionSchemeType.linearPeriodization => l10n.get(
      'progLinearPeriodization',
    ),
  };
}
