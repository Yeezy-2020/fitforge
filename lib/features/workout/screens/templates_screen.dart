import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/workout_template.dart';
import '../../../data/models/exercise.dart';
import '../../../data/repositories/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../core/localization/l10n.dart';

class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});
  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  List<WorkoutTemplate> _templates = [];
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final userId = ref.read(currentUserIdProvider);
    AppDatabase.instance.getTemplates(userId).then((v) => setState(() => _templates = v));
  }

  void _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final pending = _getPendingFromCaller();
    if (pending.isEmpty) return;
    final template = WorkoutTemplate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      exercises: pending.map((p) => TemplateExercise(exerciseId: p['id'] as String, defaultSets: p['sets'] as int, defaultReps: p['reps'] as int, defaultWeight: (p['weight'] as num).toDouble())).toList(),
    );
    final userId = ref.read(currentUserIdProvider);
    await AppDatabase.instance.saveTemplate(userId, template);
    _nameCtrl.clear();
    _load();
  }

  void _loadTemplate(WorkoutTemplate t) {
    Navigator.of(context).pop(t);
  }

  void _deleteTemplate(String id) async {
    final userId = ref.read(currentUserIdProvider);
    await AppDatabase.instance.deleteTemplate(userId, id);
    _load();
  }

  List<Map<String, dynamic>> _getPendingFromCaller() {
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Training Templates')),
      body: _templates.isEmpty
          ? const Center(child: Text('No templates yet'))
          : ListView.builder(
              itemCount: _templates.length,
              itemBuilder: (context, i) {
                final t = _templates[i];
                return ListTile(
                  title: Text(t.name),
                  subtitle: Text('${t.exercises.length} exercises'),
                  trailing: IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: () => _deleteTemplate(t.id)),
                  onTap: () => _loadTemplate(t),
                );
              },
            ),
    );
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }
}
