part of 'program_detail_screen.dart';

enum _ExercisePickerMode { existing, custom }

class _ExercisePickerDialog extends StatefulWidget {
  final List<Exercise> exercises;
  final L10n l10n;
  final bool isEnglish;
  final Future<void> Function(Exercise exercise) onCreateExercise;

  const _ExercisePickerDialog({
    required this.exercises,
    required this.l10n,
    required this.isEnglish,
    required this.onCreateExercise,
  });

  @override
  State<_ExercisePickerDialog> createState() => _ExercisePickerDialogState();
}

class _ExercisePickerDialogState extends State<_ExercisePickerDialog> {
  final _customNameCtrl = TextEditingController();
  String _query = '';
  _ExercisePickerMode _mode = _ExercisePickerMode.existing;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _customNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lower = _query.toLowerCase();
    final filtered = lower.isEmpty
        ? widget.exercises
        : widget.exercises.where((exercise) {
            return exercise.name.toLowerCase().contains(lower) ||
                (exercise.nameEn?.toLowerCase().contains(lower) ?? false);
          }).toList();
    return AlertDialog(
      title: Text(widget.l10n.get('addExerciseToDay')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<_ExercisePickerMode>(
              segments: [
                ButtonSegment(
                  value: _ExercisePickerMode.existing,
                  icon: const Icon(Icons.list_alt),
                  label: Text(widget.l10n.get('chooseExistingExercise')),
                ),
                ButtonSegment(
                  value: _ExercisePickerMode.custom,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(widget.l10n.get('createCustomExercise')),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _mode = value.first;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 12),
            if (_mode == _ExercisePickerMode.existing) ...[
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: widget.l10n.get('searchEx'),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: filtered.isEmpty
                    ? Center(child: Text(widget.l10n.get('noExercises')))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final exercise = filtered[i];
                          return ListTile(
                            title: Text(exercise.displayName(widget.isEnglish)),
                            subtitle: Text(
                              exercise.displayBodyPart(widget.isEnglish),
                            ),
                            onTap: () => Navigator.pop(ctx, exercise),
                          );
                        },
                      ),
              ),
            ] else ...[
              TextField(
                controller: _customNameCtrl,
                autofocus: true,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: widget.l10n.get('exerciseName'),
                  helperText: widget.l10n.get('customExercisePlanHelp'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(widget.l10n.get('cancel')),
        ),
        if (_mode == _ExercisePickerMode.custom)
          FilledButton(
            onPressed: _saving ? null : _createCustomExercise,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.l10n.get('add')),
          ),
      ],
    );
  }

  Future<void> _createCustomExercise() async {
    final name = _customNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = widget.l10n.get('pleaseEnterValid'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final exercise = Exercise(
      id: 'custom_${_newProgramId()}',
      name: name,
      bodyPart: '自定义',
      bodyPartEn: 'Custom',
    );
    try {
      await widget.onCreateExercise(exercise);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = widget.l10n.get('failedToLoad');
      });
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, exercise);
  }
}

class _ProgramExerciseDialog extends StatefulWidget {
  final ProgramExercise exercise;
  final String title;
  final L10n l10n;

  const _ProgramExerciseDialog({
    required this.exercise,
    required this.title,
    required this.l10n,
  });

  @override
  State<_ProgramExerciseDialog> createState() => _ProgramExerciseDialogState();
}

class _ProgramExerciseDialogState extends State<_ProgramExerciseDialog> {
  late final TextEditingController _setsCtrl;
  late final TextEditingController _minRepsCtrl;
  late final TextEditingController _maxRepsCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _incrementCtrl;
  late final TextEditingController _percentCtrl;
  late ProgressionSchemeType _type;
  String? _error;

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;
    _setsCtrl = TextEditingController(text: exercise.targetSets.toString());
    _minRepsCtrl = TextEditingController(text: exercise.minReps.toString());
    _maxRepsCtrl = TextEditingController(text: exercise.maxReps.toString());
    _weightCtrl = TextEditingController(
      text: exercise.startingWeightKg.toStringAsFixed(1),
    );
    _incrementCtrl = TextEditingController(
      text: exercise.progressionScheme.weightIncrementKg.toStringAsFixed(1),
    );
    _percentCtrl = TextEditingController(
      text: exercise.progressionScheme.percentIncrement > 0
          ? exercise.progressionScheme.percentIncrement.toStringAsFixed(1)
          : '2.5',
    );
    _type = exercise.progressionScheme.type;
  }

  @override
  void dispose() {
    _setsCtrl.dispose();
    _minRepsCtrl.dispose();
    _maxRepsCtrl.dispose();
    _weightCtrl.dispose();
    _incrementCtrl.dispose();
    _percentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progressionHintKey = _progressionHintKey(_type);
    final fields = <Widget>[
      _numberField(_setsCtrl, widget.l10n.get('sets')),
      ..._repFields(),
      _numberField(_weightCtrl, widget.l10n.get('startWeightKg')),
      if (_usesWeightIncrement(_type))
        _numberField(_incrementCtrl, widget.l10n.get('incrementKg')),
      if (_usesPercentIncrement(_type))
        _numberField(_percentCtrl, widget.l10n.get('cyclePercent')),
      _progressionField(),
    ];

    return AlertDialog(
      title: Text(widget.title, overflow: TextOverflow.ellipsis),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _fieldWrap(fields),
              if (progressionHintKey != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.l10n.get(progressionHintKey),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
        FilledButton(onPressed: _save, child: Text(widget.l10n.get('save'))),
      ],
    );
  }

  List<Widget> _repFields() {
    if (_type == ProgressionSchemeType.doubleProgression) {
      return [
        _numberField(_minRepsCtrl, widget.l10n.get('startReps')),
        _numberField(_maxRepsCtrl, widget.l10n.get('finalReps')),
      ];
    }
    if (_type == ProgressionSchemeType.linearPeriodization) {
      return [
        _numberField(_maxRepsCtrl, widget.l10n.get('startReps')),
        _numberField(_minRepsCtrl, widget.l10n.get('finalReps')),
      ];
    }
    return [_numberField(_maxRepsCtrl, widget.l10n.get('reps'))];
  }

  Widget _fieldWrap(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var columns = fields.length > 3 ? 3 : fields.length;
        if (width < 420 && columns > 2) columns = 2;
        if (width < 292) columns = 1;
        final fieldWidth = (width - (8 * (columns - 1))) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [
            for (final field in fields)
              SizedBox(width: fieldWidth, child: field),
          ],
        );
      },
    );
  }

  Widget _progressionField() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.l10n.get('progressionOpt'),
          maxLines: 2,
          overflow: TextOverflow.visible,
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<ProgressionSchemeType>(
          initialValue: _type,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          decoration: const InputDecoration(isDense: true),
          items: [
            DropdownMenuItem(
              value: ProgressionSchemeType.doubleProgression,
              child: Text(
                widget.l10n.get('progDouble'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: ProgressionSchemeType.linearWeight,
              child: Text(
                widget.l10n.get('progLinear'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: ProgressionSchemeType.fixedLoad,
              child: Text(
                widget.l10n.get('progFixedLoad'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: ProgressionSchemeType.linearPeriodization,
              child: Text(
                widget.l10n.get('progLinearPeriodization'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              final wasIncrementScheme = _usesWeightIncrement(_type);
              final isIncrementScheme = _usesWeightIncrement(value);
              final wasTwoReps = _usesTwoRepValues(_type);
              final isTwoReps = _usesTwoRepValues(value);
              _type = value;
              if (!wasIncrementScheme && isIncrementScheme) {
                final current = double.tryParse(_incrementCtrl.text);
                if (current == null || current <= 0) {
                  _incrementCtrl.text = '2.5';
                }
              }
              if (value == ProgressionSchemeType.linearPeriodization) {
                final current = double.tryParse(_percentCtrl.text);
                if (current == null || current <= 0) {
                  _percentCtrl.text = '2.5';
                }
              }
              if (!wasTwoReps && isTwoReps) {
                _restoreTwoRepValues(value);
              }
            });
          },
        ),
      ],
    );
  }

  void _restoreTwoRepValues(ProgressionSchemeType type) {
    final target = int.tryParse(_maxRepsCtrl.text);
    if (target == null || target < 2) return;
    final currentMin = int.tryParse(_minRepsCtrl.text);
    if (type == ProgressionSchemeType.doubleProgression &&
        (currentMin == null || currentMin >= target)) {
      _minRepsCtrl.text = (target - 4).clamp(1, target - 1).toString();
    }
    if (type == ProgressionSchemeType.linearPeriodization &&
        (currentMin == null || currentMin >= target)) {
      _minRepsCtrl.text = (target - 4).clamp(1, target - 1).toString();
    }
  }

  Widget _numberField(TextEditingController controller, String label) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.visible,
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(isDense: true),
        ),
      ],
    );
  }

  void _save() {
    final sets = int.tryParse(_setsCtrl.text);
    final minReps = int.tryParse(_minRepsCtrl.text);
    final targetReps = int.tryParse(_maxRepsCtrl.text);
    final weight = double.tryParse(_weightCtrl.text);
    final usesTwoReps = _usesTwoRepValues(_type);
    final usesIncrement = _usesWeightIncrement(_type);
    final usesPercent = _usesPercentIncrement(_type);
    final increment = usesIncrement
        ? double.tryParse(_incrementCtrl.text)
        : 0.0;
    final percent = usesPercent ? double.tryParse(_percentCtrl.text) : null;
    if (sets == null ||
        targetReps == null ||
        weight == null ||
        (usesTwoReps && minReps == null) ||
        (usesIncrement && increment == null) ||
        (usesPercent && percent == null) ||
        sets < 1 ||
        targetReps < 1 ||
        (usesTwoReps && minReps! < 1) ||
        weight < 0 ||
        (usesIncrement && increment! < 0) ||
        (usesPercent && percent! <= 0)) {
      setState(() {
        _error = widget.l10n.get('invalidConfig');
      });
      return;
    }
    final reps = _repsForSave(_type, minReps, targetReps);
    if (_type == ProgressionSchemeType.doubleProgression &&
        reps.max < reps.min) {
      setState(() {
        _error = widget.l10n.get('invalidConfig');
      });
      return;
    }
    if (_type == ProgressionSchemeType.linearPeriodization &&
        reps.max <= reps.min) {
      setState(() {
        _error = widget.l10n.get('invalidConfig');
      });
      return;
    }
    Navigator.pop(
      context,
      widget.exercise.copyWith(
        targetSets: sets,
        minReps: reps.min,
        maxReps: reps.max,
        startingWeightKg: weight,
        progressionScheme: widget.exercise.progressionScheme.copyWith(
          type: _type,
          weightIncrementKg: usesIncrement ? increment! : 0.0,
          percentIncrement: _type == ProgressionSchemeType.linearPeriodization
              ? percent!
              : widget.exercise.progressionScheme.percentIncrement,
        ),
      ),
    );
  }
}

bool _usesTwoRepValues(ProgressionSchemeType type) {
  return type == ProgressionSchemeType.doubleProgression ||
      type == ProgressionSchemeType.linearPeriodization;
}

({int min, int max}) _repsForSave(
  ProgressionSchemeType type,
  int? minReps,
  int reps,
) {
  if (type == ProgressionSchemeType.linearPeriodization) {
    return (min: minReps!, max: reps);
  }
  if (_usesTwoRepValues(type)) return (min: minReps!, max: reps);
  return (min: reps, max: reps);
}

bool _usesWeightIncrement(ProgressionSchemeType type) {
  return switch (type) {
    ProgressionSchemeType.doubleProgression ||
    ProgressionSchemeType.linearWeight => true,
    ProgressionSchemeType.fixedLoad ||
    ProgressionSchemeType.linearPeriodization => false,
  };
}

bool _usesPercentIncrement(ProgressionSchemeType type) {
  return type == ProgressionSchemeType.linearPeriodization;
}

String? _progressionHintKey(ProgressionSchemeType type) {
  return switch (type) {
    ProgressionSchemeType.doubleProgression => 'doubleProgressionHint',
    ProgressionSchemeType.linearWeight => 'linearWeightHint',
    ProgressionSchemeType.fixedLoad => 'fixedLoadHint',
    ProgressionSchemeType.linearPeriodization => 'linearPeriodizationHint',
  };
}
