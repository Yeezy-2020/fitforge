import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/l10n.dart';
import '../../../data/models/training_program.dart';

class ProgramActivationConfig {
  final DateTime activatedAt;
  final int? cycleCount;

  const ProgramActivationConfig({
    required this.activatedAt,
    required this.cycleCount,
  });
}

enum _ActivationDurationMode { finite, continuous }

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
  var durationMode = program.plannedCycleCount == null
      ? _ActivationDurationMode.continuous
      : _ActivationDurationMode.finite;
  String? errorText;

  DateTime projectedEndDate(int cycles) =>
      startDate.add(Duration(days: program.days.length * cycles - 1));

  final result = await showDialog<ProgramActivationConfig>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final today = DateTime(now.year, now.month, now.day);
        final isFutureStart = startDate.isAfter(today);
        final cycles = int.tryParse(cyclesController.text.trim());
        final canPreview =
            durationMode == _ActivationDurationMode.finite &&
            cycles != null &&
            cycles > 0 &&
            program.days.isNotEmpty;
        final totalDays = canPreview ? program.days.length * cycles : 0;
        final preview = program.days.isEmpty
            ? l10n.get('activationScheduleNeedsDays')
            : durationMode == _ActivationDurationMode.continuous
            ? l10n.format('activationScheduleContinuousPreview', {
                'start': l10n.shortDate(startDate),
              })
            : canPreview
            ? l10n.format('activationSchedulePreview', {
                'start': l10n.shortDate(startDate),
                'end': l10n.shortDate(projectedEndDate(cycles)),
              })
            : l10n.get('invalidCycleCount');
        final lengthPreview =
            program.days.isNotEmpty &&
                durationMode == _ActivationDurationMode.continuous
            ? l10n.format('activationScheduleContinuousLength', {
                'days': program.days.length.toString(),
              })
            : canPreview
            ? l10n.format('activationScheduleLength', {
                'days': program.days.length.toString(),
                'cycles': cycles.toString(),
                'total': totalDays.toString(),
              })
            : null;

        return AlertDialog(
          title: Text(l10n.get('activateProgram')),
          content: SingleChildScrollView(
            child: Column(
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
                      startDate = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                      );
                    });
                  },
                ),
                if (isFutureStart) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.format('activationFutureStartNotice', {
                      'date': l10n.shortDate(startDate),
                    }),
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                SegmentedButton<_ActivationDurationMode>(
                  segments: [
                    ButtonSegment(
                      value: _ActivationDurationMode.finite,
                      label: Text(l10n.get('finiteCycles')),
                      icon: const Icon(Icons.repeat),
                    ),
                    ButtonSegment(
                      value: _ActivationDurationMode.continuous,
                      label: Text(l10n.get('continuousDuration')),
                      icon: const Icon(Icons.all_inclusive),
                    ),
                  ],
                  selected: {durationMode},
                  onSelectionChanged: (value) => setDialogState(() {
                    durationMode = value.first;
                    errorText = null;
                  }),
                ),
                if (durationMode == _ActivationDurationMode.finite) ...[
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
                ],
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
                      if (durationMode == _ActivationDurationMode.continuous) {
                        Navigator.pop(
                          dialogContext,
                          ProgramActivationConfig(
                            activatedAt: startDate,
                            cycleCount: null,
                          ),
                        );
                        return;
                      }

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
              child: Text(
                l10n.get(isFutureStart ? 'scheduleProgram' : 'activate'),
              ),
            ),
          ],
        );
      },
    ),
  );
  cyclesController.dispose();
  return result;
}
