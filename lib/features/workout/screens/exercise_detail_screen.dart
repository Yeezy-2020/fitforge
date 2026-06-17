import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/exercise.dart';
import '../../../providers/settings_providers.dart';
import '../../../core/localization/l10n.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  final Exercise exercise;
  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(l10nProvider);
    final isEn = ref.watch(localeProvider) == AppLocale.en;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.exerciseName(exercise.id, exercise.name))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (exercise.imageUrl != null) ...[
            Center(child: ClipRRect(borderRadius: BorderRadius.circular(12),
              child: Image.network(exercise.imageUrl!, height: 200, fit: BoxFit.contain,
                errorBuilder: (_, __, _) => Container(height: 200, color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.fitness_center, size: 64, color: theme.colorScheme.primary))))),
            const SizedBox(height: 16),
          ],
          _buildSection(theme, l10n.get('area'), l10n.bodyPartName(exercise.bodyPart)),
          if (exercise.category != null) _buildSection(theme, l10n.get('category'), exercise.category!),
          if (exercise.displayTargetMuscle(isEn).isNotEmpty) ...[const SizedBox(height: 12), _buildSection(theme, l10n.get('targetMuscle'), exercise.displayTargetMuscle(isEn))],
          if (exercise.displayInstructions(isEn).isNotEmpty) ...[const SizedBox(height: 16), _buildBlock(theme, l10n.get('instructions'), exercise.displayInstructions(isEn))],
          if (exercise.displayMistakes(isEn).isNotEmpty) ...[const SizedBox(height: 16), _buildBlock(theme, l10n.get('commonMistakes'), exercise.displayMistakes(isEn))],
        ]),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }

  Widget _buildBlock(ThemeData theme, String label, String content) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              content,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
