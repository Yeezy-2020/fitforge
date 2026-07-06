import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/l10n.dart';

class ProgramSettingsResult {
  final String name;
  final int? plannedCycleCount;

  const ProgramSettingsResult({
    required this.name,
    required this.plannedCycleCount,
  });
}

enum _ProgramDurationMode { finite, continuous }

Future<ProgramSettingsResult?> showProgramSettingsDialog({
  required BuildContext context,
  required L10n l10n,
  required String title,
  required String initialName,
  required int? initialCycleCount,
  String? confirmLabel,
  int dayCount = 0,
}) async {
  final nameController = TextEditingController(text: initialName);
  final cyclesController = TextEditingController(
    text: (initialCycleCount ?? 4).toString(),
  );
  var mode = initialCycleCount == null
      ? _ProgramDurationMode.continuous
      : _ProgramDurationMode.finite;
  String? nameErrorText;
  String? errorText;

  final result = await showDialog<ProgramSettingsResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final cycles = int.tryParse(cyclesController.text.trim());
        final totalDays =
            mode == _ProgramDurationMode.finite &&
                cycles != null &&
                cycles > 0 &&
                dayCount > 0
            ? dayCount * cycles
            : null;
        final durationPreview = mode == _ProgramDurationMode.continuous
            ? l10n.get('continuousDurationHelp')
            : totalDays == null
            ? l10n.get('programCycleCountHelp')
            : l10n.format('activationScheduleLength', {
                'days': dayCount.toString(),
                'cycles': cycles.toString(),
                'total': totalDays.toString(),
              });

        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.get('programName'),
                    errorText: nameErrorText,
                  ),
                  onChanged: (_) => setDialogState(() => nameErrorText = null),
                ),
                const SizedBox(height: 16),
                SegmentedButton<_ProgramDurationMode>(
                  segments: [
                    ButtonSegment(
                      value: _ProgramDurationMode.finite,
                      label: Text(l10n.get('finiteCycles')),
                      icon: const Icon(Icons.repeat),
                    ),
                    ButtonSegment(
                      value: _ProgramDurationMode.continuous,
                      label: Text(l10n.get('continuousDuration')),
                      icon: const Icon(Icons.all_inclusive),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (value) => setDialogState(() {
                    mode = value.first;
                    errorText = null;
                  }),
                ),
                if (mode == _ProgramDurationMode.finite) ...[
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
                Text(
                  durationPreview,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.get('cancel')),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  setDialogState(
                    () => nameErrorText = l10n.get('programNameRequired'),
                  );
                  return;
                }
                if (mode == _ProgramDurationMode.continuous) {
                  Navigator.pop(
                    dialogContext,
                    ProgramSettingsResult(name: name, plannedCycleCount: null),
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
                  ProgramSettingsResult(name: name, plannedCycleCount: cycles),
                );
              },
              child: Text(confirmLabel ?? l10n.get('save')),
            ),
          ],
        );
      },
    ),
  );
  nameController.dispose();
  cyclesController.dispose();
  return result;
}
