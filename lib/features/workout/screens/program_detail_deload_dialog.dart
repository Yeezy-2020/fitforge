part of 'program_detail_screen.dart';

enum _DeloadInsertPosition { afterSelectedDay, endOfCycle }

class _DeloadDayDialog extends StatefulWidget {
  final TrainingProgram program;
  final int? selectedDayIndex;
  final List<ProgramDay> baseDays;
  final ProgramDay initialBaseDay;
  final L10n l10n;

  const _DeloadDayDialog({
    required this.program,
    required this.selectedDayIndex,
    required this.baseDays,
    required this.initialBaseDay,
    required this.l10n,
  });

  @override
  State<_DeloadDayDialog> createState() => _DeloadDayDialogState();
}

class _DeloadDayDialogState extends State<_DeloadDayDialog> {
  final _weightPercentCtrl = TextEditingController(text: '70');
  final _setRatioCtrl = TextEditingController(text: '100');
  final _repRatioCtrl = TextEditingController(text: '100');
  late _DeloadInsertPosition _position;
  late ProgramDay _baseDay;
  DeloadDayPreset _preset = DeloadDayPreset.standard;
  String? _error;

  @override
  void initState() {
    super.initState();
    _position = widget.selectedDayIndex == null
        ? _DeloadInsertPosition.endOfCycle
        : _DeloadInsertPosition.afterSelectedDay;
    _baseDay = widget.initialBaseDay;
  }

  @override
  void dispose() {
    _weightPercentCtrl.dispose();
    _setRatioCtrl.dispose();
    _repRatioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = <Widget>[
      _insertPositionField(),
      _baseDayField(),
      _presetField(),
      _summary(theme),
      if (_preset == DeloadDayPreset.custom) _customFields(),
      if (_error != null)
        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
    ];

    return AlertDialog(
      title: Text(widget.l10n.get('addDeloadDay')),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.l10n.get('deloadDayHelp'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                fields[i],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.l10n.get('cancel')),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.l10n.get('createDeloadDay')),
        ),
      ],
    );
  }

  Widget _insertPositionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.l10n.get('insertPosition')),
        const SizedBox(height: 6),
        SegmentedButton<_DeloadInsertPosition>(
          segments: [
            ButtonSegment(
              value: _DeloadInsertPosition.afterSelectedDay,
              label: Text(widget.l10n.get('afterSelectedDay')),
            ),
            ButtonSegment(
              value: _DeloadInsertPosition.endOfCycle,
              label: Text(widget.l10n.get('endOfCycle')),
            ),
          ],
          selected: {_position},
          onSelectionChanged: widget.selectedDayIndex == null
              ? null
              : (value) {
                  final nextPosition = value.first;
                  setState(() {
                    _position = nextPosition;
                    _baseDay =
                        _defaultDeloadBaseDay(
                          widget.program,
                          _insertIndexFor(nextPosition),
                        ) ??
                        widget.baseDays.first;
                    _error = null;
                  });
                },
        ),
      ],
    );
  }

  Widget _baseDayField() {
    return DropdownButtonFormField<ProgramDay>(
      initialValue: _baseDay,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: widget.l10n.get('baseTrainingDay'),
      ),
      items: [
        for (final day in widget.baseDays)
          DropdownMenuItem(value: day, child: Text(day.name)),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _baseDay = value;
          _error = null;
        });
      },
    );
  }

  Widget _presetField() {
    return DropdownButtonFormField<DeloadDayPreset>(
      initialValue: _preset,
      isExpanded: true,
      decoration: InputDecoration(labelText: widget.l10n.get('deloadPreset')),
      items: [
        DropdownMenuItem(
          value: DeloadDayPreset.standard,
          child: Text(widget.l10n.get('standardDeload')),
        ),
        DropdownMenuItem(
          value: DeloadDayPreset.volume,
          child: Text(widget.l10n.get('volumeDeload')),
        ),
        DropdownMenuItem(
          value: DeloadDayPreset.custom,
          child: Text(widget.l10n.get('customDeload')),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _preset = value;
          _error = null;
        });
      },
    );
  }

  Widget _summary(ThemeData theme) {
    final key = switch (_preset) {
      DeloadDayPreset.standard => 'standardDeloadSummary',
      DeloadDayPreset.volume => 'volumeDeloadSummary',
      DeloadDayPreset.custom => 'customDeloadSummary',
    };
    return Text(
      widget.l10n.get(key),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outline,
      ),
    );
  }

  Widget _customFields() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 132,
          child: _ratioField(_weightPercentCtrl, 'loadPercent'),
        ),
        SizedBox(width: 132, child: _ratioField(_setRatioCtrl, 'setRatio')),
        SizedBox(width: 132, child: _ratioField(_repRatioCtrl, 'repRatio')),
      ],
    );
  }

  Widget _ratioField(TextEditingController controller, String labelKey) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.l10n.get(labelKey),
        suffixText: '%',
      ),
    );
  }

  int _insertIndexFor(_DeloadInsertPosition position) {
    if (position == _DeloadInsertPosition.endOfCycle) {
      return widget.program.days.length;
    }
    final selected = widget.selectedDayIndex;
    if (selected == null) return widget.program.days.length;
    return (selected + 1).clamp(0, widget.program.days.length).toInt();
  }

  void _save() {
    final weightPercent = switch (_preset) {
      DeloadDayPreset.standard => 70.0,
      DeloadDayPreset.volume => 70.0,
      DeloadDayPreset.custom => double.tryParse(_weightPercentCtrl.text),
    };
    final setRatio = switch (_preset) {
      DeloadDayPreset.standard => 1.0,
      DeloadDayPreset.volume => 1.0,
      DeloadDayPreset.custom =>
        (double.tryParse(_setRatioCtrl.text) ?? 0) / 100,
    };
    final repRatio = switch (_preset) {
      DeloadDayPreset.standard => 1.0,
      DeloadDayPreset.volume => 0.5,
      DeloadDayPreset.custom =>
        (double.tryParse(_repRatioCtrl.text) ?? 0) / 100,
    };

    if (weightPercent == null ||
        weightPercent <= 0 ||
        weightPercent > 100 ||
        setRatio <= 0 ||
        setRatio > 1 ||
        repRatio <= 0 ||
        repRatio > 1) {
      setState(() => _error = widget.l10n.get('invalidConfig'));
      return;
    }

    Navigator.pop(context, (
      insertIndex: _insertIndexFor(_position),
      baseDay: _baseDay,
      preset: _preset,
      weightPercent: weightPercent,
      setRatio: setRatio,
      repRatio: repRatio,
    ));
  }
}

List<ProgramDay> _regularTrainingDays(TrainingProgram program) {
  return program.days.where((day) => day.kind == DayKind.training).toList();
}

ProgramDay? _defaultDeloadBaseDay(TrainingProgram program, int insertIndex) {
  final end = insertIndex.clamp(0, program.days.length).toInt();
  for (var i = end - 1; i >= 0; i--) {
    final day = program.days[i];
    if (day.kind == DayKind.training) return day;
  }
  return _regularTrainingDays(program).firstOrNull;
}
