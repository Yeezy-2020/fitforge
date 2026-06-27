import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n.dart';
import '../../../data/models/exercise.dart';
import '../../../data/models/training_program.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';
import 'program_detail_screen.dart';

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
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.get('createStarterProgram'),
            onPressed: _createStarter,
          ),
        ],
      ),
      body: programsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProgramDetailScreen(programId: id)),
    );
  }

  Future<void> _createStarter() async {
    final l10n = ref.read(l10nProvider);
    final userId = ref.read(currentUserIdProvider);
    if (userId.isEmpty) return;
    final existing = ref.read(trainingProgramsProvider).valueOrNull ?? [];
    final now = DateTime.now();
    final program = TrainingProgram(
      id: _newId(),
      userId: userId,
      name: 'PPL',
      active: !existing.any((p) => p.active),
      createdAt: now,
      updatedAt: now,
      days: [
        ProgramDay(
          id: _newId(),
          name: 'Push',
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
          name: 'Pull',
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
          name: 'Legs',
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
        ProgramDay(id: _newId(), name: 'Rest', kind: DayKind.rest),
      ],
    );
    await ref.read(trainingProgramsProvider.notifier).save(program);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.get('starterProgramCreated'))),
      );
    }
  }

  Future<void> _renameProgram(TrainingProgram program) async {
    final l10n = ref.read(l10nProvider);
    final controller = TextEditingController(text: program.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.get('renameProgram')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.get('programName')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.get('rename')),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      final updated = program.copyWith(name: name, updatedAt: DateTime.now());
      await ref.read(trainingProgramsProvider.notifier).save(updated);
    }
  }

  Future<void> _setActive(TrainingProgram program) async {
    await ref.read(trainingProgramsProvider.notifier).setActive(program.id);
  }

  Future<void> _deleteProgram(TrainingProgram program) async {
    final l10n = ref.read(l10nProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.get('deleteProgram')),
        content: Text(
          l10n.get('deleteProgramConfirm').replaceFirst('{name}', program.name),
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
      await ref.read(trainingProgramsProvider.notifier).delete(program.id);
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
    final trainingDays = program.days
        .where((d) => d.kind == DayKind.training)
        .length;

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
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n.get('active'),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${program.days.length} ${l10n.get('days')}, $trainingDays ${l10n.get('trainingDays')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
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
                    child: Text(l10n.get('rename')),
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
}
