part of 'workout_day_screen.dart';

Future<void> showProgressionRuleSheet(
  BuildContext context,
  WidgetRef ref, {
  required Exercise exercise,
  required L10n l10n,
}) async {
  final userScope = ref.read(currentUserScopeProvider);
  final userId = userScope.userId;
  if (userId.isEmpty) return;
  final existing = ref.read(progressionRuleForExerciseProvider(exercise.id));

  bool isCurrentUserScope() {
    if (!context.mounted) return false;
    return identical(ref.read(currentUserScopeProvider), userScope);
  }

  var type = existing?.type ?? ProgressionType.fixedWeight;
  var enabled = existing?.enabled ?? true;
  var onlyIfCompleted = existing?.onlyIfCompleted ?? true;
  final incrementCtrl = TextEditingController(
    text: (existing?.increment ?? 2.5).toString(),
  );
  final targetSetsCtrl = TextEditingController(
    text: (existing?.targetSets ?? 3).toString(),
  );
  final targetRepsCtrl = TextEditingController(
    text: (existing?.targetReps ?? 8).toString(),
  );
  final minRepsCtrl = TextEditingController(
    text: (existing?.minReps ?? 8).toString(),
  );
  final maxRepsCtrl = TextEditingController(
    text: (existing?.maxReps ?? 12).toString(),
  );
  final defWeightCtrl = TextEditingController(
    text: existing?.defaultWeightKg?.toString() ?? '',
  );
  final defSetsCtrl = TextEditingController(
    text: existing?.defaultSets?.toString() ?? '',
  );
  final defRepsCtrl = TextEditingController(
    text: existing?.defaultReps?.toString() ?? '',
  );

  String typeLabel(ProgressionType t) {
    switch (t) {
      case ProgressionType.fixedWeight:
        return l10n.get('typeFixedWeight');
      case ProgressionType.percentWeight:
        return l10n.get('typePercentWeight');
      case ProgressionType.reps:
        return l10n.get('typeReps');
      case ProgressionType.doubleProgression:
        return l10n.get('typeDoubleProgression');
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget numField(TextEditingController c, String label) => Expanded(
            child: TextField(
              controller: c,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: label, isDense: true),
            ),
          );

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.trending_up, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l10n.get('progressiveOverload')} · '
                          '${l10n.exerciseName(exercise.id, exercise.name)}',
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.get('enabled')),
                    value: enabled,
                    onChanged: (v) => setSheet(() => enabled = v),
                  ),
                  DropdownButtonFormField<ProgressionType>(
                    initialValue: type,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.get('progressionType'),
                      isDense: true,
                    ),
                    items: ProgressionType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(typeLabel(t)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSheet(() => type = v ?? type),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [numField(incrementCtrl, l10n.get('increment'))],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      numField(targetSetsCtrl, l10n.get('targetSets')),
                      const SizedBox(width: 8),
                      numField(targetRepsCtrl, l10n.get('targetReps')),
                    ],
                  ),
                  if (type == ProgressionType.doubleProgression) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        numField(minRepsCtrl, l10n.get('minReps')),
                        const SizedBox(width: 8),
                        numField(maxRepsCtrl, l10n.get('maxReps')),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      numField(
                        defWeightCtrl,
                        '${l10n.get('defaultWeight')} (kg)',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      numField(defSetsCtrl, l10n.get('defaultSets')),
                      const SizedBox(width: 8),
                      numField(defRepsCtrl, l10n.get('defaultReps')),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.get('onlyIfCompleted')),
                    value: onlyIfCompleted,
                    onChanged: (v) =>
                        setSheet(() => onlyIfCompleted = v ?? true),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (existing != null)
                        TextButton.icon(
                          onPressed: () async {
                            if (!isCurrentUserScope()) {
                              if (ctx.mounted) Navigator.pop(ctx);
                              return;
                            }
                            final rulesNotifier = ref.read(
                              progressionRulesProvider.notifier,
                            );
                            await rulesNotifier.delete(exercise.id);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (!context.mounted) return;
                            if (!identical(
                              ref.read(currentUserScopeProvider),
                              userScope,
                            )) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.get('ruleDeleted'))),
                            );
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          label: Text(
                            l10n.get('delete'),
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(l10n.get('cancel')),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          if (!isCurrentUserScope()) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            return;
                          }
                          final rulesNotifier = ref.read(
                            progressionRulesProvider.notifier,
                          );
                          final rule = ProgressionRule(
                            id:
                                existing?.id ??
                                DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                            userId: userId,
                            exerciseId: exercise.id,
                            type: type,
                            enabled: enabled,
                            increment:
                                double.tryParse(incrementCtrl.text) ?? 2.5,
                            targetSets: int.tryParse(targetSetsCtrl.text) ?? 3,
                            targetReps: int.tryParse(targetRepsCtrl.text) ?? 8,
                            minReps: type == ProgressionType.doubleProgression
                                ? int.tryParse(minRepsCtrl.text)
                                : existing?.minReps,
                            maxReps: type == ProgressionType.doubleProgression
                                ? int.tryParse(maxRepsCtrl.text)
                                : existing?.maxReps,
                            defaultWeightKg: double.tryParse(
                              defWeightCtrl.text,
                            ),
                            defaultSets: int.tryParse(defSetsCtrl.text),
                            defaultReps: int.tryParse(defRepsCtrl.text),
                            onlyIfCompleted: onlyIfCompleted,
                          );
                          await rulesNotifier.save(rule);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!context.mounted) return;
                          if (!identical(
                            ref.read(currentUserScopeProvider),
                            userScope,
                          )) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.get('ruleSaved'))),
                          );
                        },
                        child: Text(l10n.get('save')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  incrementCtrl.dispose();
  targetSetsCtrl.dispose();
  targetRepsCtrl.dispose();
  minRepsCtrl.dispose();
  maxRepsCtrl.dispose();
  defWeightCtrl.dispose();
  defSetsCtrl.dispose();
  defRepsCtrl.dispose();
}
