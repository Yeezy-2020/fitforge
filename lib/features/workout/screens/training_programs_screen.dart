import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/navigation/instant_page_route.dart';
import '../../../data/models/exercise.dart';
import '../../../data/models/training_program.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';
import 'program_activation_dialog.dart';
import 'program_detail_screen.dart';
import 'program_settings_dialog.dart';

String _newId() {
  _idSeq += 1;
  return '${DateTime.now().microsecondsSinceEpoch}_$_idSeq';
}

int _idSeq = 0;

String exerciseName(String id, List<Exercise> exercises) {
  final ex = exercises.where((e) => e.id == id).firstOrNull;
  if (ex == null) return id;
  return ex.nameEn ?? ex.name;
}

class TrainingProgramsScreen extends ConsumerStatefulWidget {
  const TrainingProgramsScreen({super.key});

  @override
  ConsumerState<TrainingProgramsScreen> createState() =>
      _TrainingProgramsScreenState();
}

class _TrainingProgramsScreenState
    extends ConsumerState<TrainingProgramsScreen> {
  @override
  Widget build(BuildContext context) {
    final programsAsync = ref.watch(trainingProgramsProvider);
    final l10n = ref.watch(l10nProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.get('trainingPrograms')),
        actions: [
          PopupMenuButton<String>(
            tooltip: l10n.get('createProgram'),
            icon: const Icon(Icons.add),
            onSelected: (value) {
              switch (value) {
                case 'blank':
                  _createBlank();
                case 'starter':
                  _createStarter();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'blank',
                child: Text(l10n.get('createBlankProgram')),
              ),
              PopupMenuItem(
                value: 'starter',
                child: Text(l10n.get('createStarterProgram')),
              ),
            ],
          ),
        ],
      ),
      body: programsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${l10n.get('failedToLoad')}: $e')),
        data: (programs) {
          if (programs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.get('noTrainingPrograms')),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.get('createBlankProgram')),
                    onPressed: _createBlank,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(l10n.get('createStarterProgramLong')),
                    onPressed: _createStarter,
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: programs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _ProgramCard(
              program: programs[i],
              l10n: l10n,
              onTap: () => _openDetail(programs[i].id),
              onRename: () => _renameProgram(programs[i]),
              onSetActive: () => _setActive(programs[i]),
              onDelete: () => _deleteProgram(programs[i]),
            ),
          );
        },
      ),
    );
  }

  void _openDetail(String id) {
    Navigator.of(
      context,
    ).push(instantPageRoute(ProgramDetailScreen(programId: id)));
  }

  Future<void> _createBlank() async {
    final l10n = ref.read(l10nProvider);
    final userId = ref.read(currentUserIdProvider);
    if (userId.isEmpty) return;

    final settings = await showProgramSettingsDialog(
      context: context,
      l10n: l10n,
      title: l10n.get('createBlankProgram'),
      initialName: l10n.get('blankProgramName'),
      initialCycleCount: null,
      confirmLabel: l10n.get('createProgram'),
    );
    if (settings == null) return;

    final now = DateTime.now();
    final program = TrainingProgram(
      id: _newId(),
      userId: userId,
      name: settings.name,
      active: false,
      activatedAt: null,
      activatedDayIndex: 0,
      plannedCycleCount: settings.plannedCycleCount,
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(trainingProgramsProvider.notifier).save(program);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.get('blankProgramCreated'))));
    _openDetail(program.id);
  }

  Future<void> _createStarter() async {
    final l10n = ref.read(l10nProvider);
    final userId = ref.read(currentUserIdProvider);
    if (userId.isEmpty) return;
    final settings = await showProgramSettingsDialog(
      context: context,
      l10n: l10n,
      title: l10n.get('createStarterProgram'),
      initialName: l10n.get('starterPPL'),
      initialCycleCount: null,
      confirmLabel: l10n.get('createProgram'),
      dayCount: 4,
    );
    if (settings == null) return;
    final now = DateTime.now();
    final program = TrainingProgram(
      id: _newId(),
      userId: userId,
      name: settings.name,
      active: false,
      activatedAt: null,
      activatedDayIndex: 0,
      plannedCycleCount: settings.plannedCycleCount,
      createdAt: now,
      updatedAt: now,
      days: [
        ProgramDay(
          id: _newId(),
          name: l10n.get('pushDay'),
          kind: DayKind.training,
          exercises: [
            ProgramExercise(
              id: _newId(),
              exerciseId: 'ex_bench_press',
              sortOrder: 0,
            ),
            ProgramExercise(
              id: _newId(),
              exerciseId: 'ex_shoulder_press',
              sortOrder: 1,
            ),
            ProgramExercise(
              id: _newId(),
              exerciseId: 'ex_tricep_pushdown',
              sortOrder: 2,
            ),
          ],
        ),
        ProgramDay(
          id: _newId(),
          name: l10n.get('pullDay'),
          kind: DayKind.training,
          exercises: [
            ProgramExercise(
              id: _newId(),
              exerciseId: 'ex_pullup',
              sortOrder: 0,
            ),
            ProgramExercise(
              id: _newId(),
              exerciseId: 'ex_barbell_row',
              sortOrder: 1,
            ),
            ProgramExercise(
              id: _newId(),
              exerciseId: 'ex_bicep_curl',
              sortOrder: 2,
            ),
          ],
        ),
        ProgramDay(
          id: _newId(),
          name: l10n.get('legsDay'),
          kind: DayKind.training,
          exercises: [
            ProgramExercise(id: _newId(), exerciseId: 'ex_squat', sortOrder: 0),
            ProgramExercise(
              id: _newId(),
              exerciseId: 'ex_romanian_deadlift',
              sortOrder: 1,
            ),
            ProgramExercise(
              id: _newId(),
              exerciseId: 'ex_legpress',
              sortOrder: 2,
            ),
          ],
        ),
        ProgramDay(
          id: _newId(),
          name: l10n.get('restDayName'),
          kind: DayKind.rest,
        ),
      ],
    );
    await ref.read(trainingProgramsProvider.notifier).save(program);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.get('starterProgramCreated'))),
      );
      _openDetail(program.id);
    }
  }

  Future<void> _renameProgram(TrainingProgram program) async {
    final l10n = ref.read(l10nProvider);
    final settings = await showProgramSettingsDialog(
      context: context,
      l10n: l10n,
      title: l10n.get('editProgramSettings'),
      initialName: program.name,
      initialCycleCount: program.plannedCycleCount,
      dayCount: program.days.length,
    );
    if (settings == null) return;
    final updated = program.copyWith(
      name: settings.name,
      plannedCycleCount: settings.plannedCycleCount,
      clearPlannedCycleCount: settings.plannedCycleCount == null,
      updatedAt: DateTime.now(),
    );
    await ref.read(trainingProgramsProvider.notifier).save(updated);
  }

  Future<void> _setActive(TrainingProgram program) async {
    final l10n = ref.read(l10nProvider);
    final config = await showProgramActivationDialog(
      context: context,
      l10n: l10n,
      program: program,
    );
    if (config == null) return;
    await ref
        .read(trainingProgramsProvider.notifier)
        .setActive(
          program.id,
          activatedAt: config.activatedAt,
          plannedCycleCount: config.cycleCount,
          expectedUserId: program.userId,
        );
  }

  Future<void> _deleteProgram(TrainingProgram program) async {
    final l10n = ref.read(l10nProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.get('deleteProgram')),
        content: Text(
          l10n.format('deleteProgramConfirm', {'name': program.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.get('delete')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref
          .read(trainingProgramsProvider.notifier)
          .delete(program.id, expectedUserId: program.userId);
    }
  }
}

class _ProgramCard extends StatelessWidget {
  final TrainingProgram program;
  final L10n l10n;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onSetActive;
  final VoidCallback onDelete;

  const _ProgramCard({
    required this.program,
    required this.l10n,
    required this.onTap,
    required this.onRename,
    required this.onSetActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trainingDays = program.days.where((d) => d.isTrainingLike).length;
    final deloadDays = program.days
        .where((d) => d.kind == DayKind.deload)
        .length;
    final isScheduled = _isProgramScheduled(program);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(program.name, style: theme.textTheme.titleMedium),
                        if (program.active) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isScheduled
                                  ? Colors.orange.shade100
                                  : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n.get(isScheduled ? 'scheduled' : 'active'),
                              style: TextStyle(
                                fontSize: 11,
                                color: isScheduled
                                    ? Colors.orange.shade900
                                    : Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _summary(trainingDays),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    if (deloadDays > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.trending_down,
                              size: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.format('programCardDeloadBadge', {
                                'count': deloadDays.toString(),
                              }),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'activate':
                      onSetActive();
                    case 'rename':
                      onRename();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  if (!program.active)
                    PopupMenuItem(
                      value: 'activate',
                      child: Text(l10n.get('setActive')),
                    ),
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(l10n.get('editProgramSettings')),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      l10n.get('delete'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _summary(int trainingDays) {
    final base = l10n.format('programCardSummary', {
      'days': program.days.length.toString(),
      'training': trainingDays.toString(),
    });
    final cycles = program.plannedCycleCount;
    if (_isProgramScheduled(program)) {
      return '$base · ${l10n.format('scheduledStartDate', {'date': l10n.shortDate(program.activatedAt!)})}';
    }
    if (cycles == null) {
      return '$base · ${l10n.get('plannedContinuously')}';
    }
    final end = program.active ? program.plannedEndDate() : null;
    final duration = end == null
        ? l10n.format('plannedCycles', {'count': cycles.toString()})
        : l10n.format('plannedThrough', {'date': l10n.shortDate(end)});
    return '$base · $duration';
  }
}

bool _isProgramScheduled(TrainingProgram program) {
  final activatedAt = program.activatedAt;
  if (!program.active || activatedAt == null) return false;
  return _dateOnly(activatedAt).isAfter(_dateOnly(DateTime.now()));
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
