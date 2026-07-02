import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/l10n.dart';
import '../../../data/models/training_program.dart';

class ProgramActivationConfig {
  final DateTime activatedAt;
  final int cycleCount;

  const ProgramActivationConfig({
    required this.activatedAt,
    required this.cycleCount,
  });
}

Future<ProgramActivationConfig?> showProgramActivationDialog({
  required BuildContext context,
  required L10n l10n,
  required TrainingProgram program,
}) async {
  final now = DateTime.now();
  var startDate = DateTime(now.year, now.month, now.day);
  final cyclesController = TextEditingController(
    text: (program.plannedCycleCount ?? 4).toString(),
  );
  String? errorText;

  DateTime projectedEndDate(int cycles) =>
      startDate.add(Duration(days: program.days.length * cycles - 1));

  final result = await showDialog<ProgramActivationConfig>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final cycles = int.tryParse(cyclesController.text.trim());
        final canPreview =
            cycles != null && cycles > 0 && program.days.isNotEmpty;
        final totalDays = canPreview ? program.days.length * cycles : 0;
        final preview = canPreview
            ? l10n.format('activationSchedulePreview', {
                'start': l10n.shortDate(startDate),
                'end': l10n.shortDate(projectedEndDate(cycles)),
              })
            : l10n.get('activationScheduleNeedsDays');
        final lengthPreview = canPreview
            ? l10n.format('activationScheduleLength', {
                'days': program.days.length.toString(),
                'cycles': cycles.toString(),
                'total': totalDays.toString(),
              })
            : null;

        return AlertDialog(
          title: Text(l10n.get('activateProgram')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.get('activateProgramHelp')),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(
                  l10n.format('activationDateValue', {
                    'date': l10n.shortDate(startDate),
                  }),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: dialogContext,
                    helpText: l10n.get('activationDate'),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDate: startDate,
                  );
                  if (picked == null) return;
                  setDialogState(() {
                    startDate = DateTime(picked.year, picked.month, picked.day);
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cyclesController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.get('programCycleCount'),
                  helperText: l10n.get('programCycleCountHelp'),
                  errorText: errorText,
                ),
                onChanged: (_) => setDialogState(() => errorText = null),
              ),
              const SizedBox(height: 12),
              if (lengthPreview != null) ...[
                Text(
                  lengthPreview,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
              ],
              Text(preview, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.get('cancel')),
            ),
            FilledButton(
              onPressed: program.days.isEmpty
                  ? null
                  : () {
                      final cycles = int.tryParse(cyclesController.text.trim());
                      if (cycles == null || cycles < 1) {
                        setDialogState(
                          () => errorText = l10n.get('invalidCycleCount'),
                        );
                        return;
                      }
                      Navigator.pop(
                        dialogContext,
                        ProgramActivationConfig(
                          activatedAt: startDate,
                          cycleCount: cycles,
                        ),
                      );
                    },
              child: Text(l10n.get('activate')),
            ),
          ],
        );
      },
    ),
  );
  cyclesController.dispose();
  return result;
}
