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
}) {
  return showDialog<ProgramSettingsResult>(
    context: context,
    builder: (_) => _ProgramSettingsDialog(
      l10n: l10n,
      title: title,
      initialName: initialName,
      initialCycleCount: initialCycleCount,
      confirmLabel: confirmLabel,
      dayCount: dayCount,
    ),
  );
}

class _ProgramSettingsDialog extends StatefulWidget {
  final L10n l10n;
  final String title;
  final String initialName;
  final int? initialCycleCount;
  final String? confirmLabel;
  final int dayCount;

  const _ProgramSettingsDialog({
    required this.l10n,
    required this.title,
    required this.initialName,
    required this.initialCycleCount,
    required this.confirmLabel,
    required this.dayCount,
  });

  @override
  State<_ProgramSettingsDialog> createState() => _ProgramSettingsDialogState();
}

class _ProgramSettingsDialogState extends State<_ProgramSettingsDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _cyclesController;
  late _ProgramDurationMode _mode;
  String? _nameErrorText;
  String? _cycleErrorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _cyclesController = TextEditingController(
      text: (widget.initialCycleCount ?? 4).toString(),
    );
    _mode = widget.initialCycleCount == null
        ? _ProgramDurationMode.continuous
        : _ProgramDurationMode.finite;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cyclesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final cycles = int.tryParse(_cyclesController.text.trim());
    final totalDays =
        _mode == _ProgramDurationMode.finite &&
            cycles != null &&
            cycles > 0 &&
            widget.dayCount > 0
        ? widget.dayCount * cycles
        : null;
    final durationPreview = _mode == _ProgramDurationMode.continuous
        ? l10n.get('continuousDurationHelp')
        : totalDays == null
        ? l10n.get('programCycleCountHelp')
        : l10n.format('activationScheduleLength', {
            'days': widget.dayCount.toString(),
            'cycles': cycles.toString(),
            'total': totalDays.toString(),
          });

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.get('programName'),
                errorText: _nameErrorText,
              ),
              onChanged: (_) => setState(() => _nameErrorText = null),
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
              selected: {_mode},
              onSelectionChanged: (value) => setState(() {
                _mode = value.first;
                _cycleErrorText = null;
              }),
            ),
            if (_mode == _ProgramDurationMode.finite) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _cyclesController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.get('programCycleCount'),
                  helperText: l10n.get('programCycleCountHelp'),
                  errorText: _cycleErrorText,
                ),
                onChanged: (_) => setState(() => _cycleErrorText = null),
              ),
            ],
            const SizedBox(height: 12),
            Text(durationPreview, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.get('cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel ?? l10n.get('save')),
        ),
      ],
    );
  }

  void _submit() {
    final l10n = widget.l10n;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameErrorText = l10n.get('programNameRequired'));
      return;
    }
    if (_mode == _ProgramDurationMode.continuous) {
      Navigator.pop(
        context,
        ProgramSettingsResult(name: name, plannedCycleCount: null),
      );
      return;
    }
    final cycles = int.tryParse(_cyclesController.text.trim());
    if (cycles == null || cycles < 1) {
      setState(() => _cycleErrorText = l10n.get('invalidCycleCount'));
      return;
    }
    Navigator.pop(
      context,
      ProgramSettingsResult(name: name, plannedCycleCount: cycles),
    );
  }
}
