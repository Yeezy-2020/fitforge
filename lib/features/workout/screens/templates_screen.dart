import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/workout_template.dart';
import '../../../data/repositories/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';

class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});
  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  List<WorkoutTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final userId = ref.read(currentUserIdProvider);
    AppDatabase.instance
        .getTemplates(userId)
        .then((v) => setState(() => _templates = v));
  }

  void _deleteTemplate(String id) async {
    final userId = ref.read(currentUserIdProvider);
    await AppDatabase.instance.deleteTemplate(userId, id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.get('trainingTemplates'))),
      body: _templates.isEmpty
          ? Center(child: Text(l10n.get('noTemplatesYet')))
          : ListView.builder(
              itemCount: _templates.length,
              itemBuilder: (context, i) {
                final t = _templates[i];
                return ListTile(
                  title: Text(t.name),
                  subtitle: Text(
                    l10n.format('nExercises', {
                      'n': t.exercises.length.toString(),
                    }),
                  ),
                  trailing: IconButton(
                    tooltip: l10n.get('delete'),
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: () => _deleteTemplate(t.id),
                  ),
                  onTap: () => Navigator.of(context).pop(t),
                );
              },
            ),
    );
  }
}
