part of 'workout_day_screen.dart';

class _ExerciseCard extends ConsumerStatefulWidget {
  final Exercise exercise;
  final L10n l10n;
  final WeightUnit trainUnit;
  final DateTime date;
  final bool showProgressionControls;
  final bool addEnabled;
  final void Function(String exerciseId, int sets, int reps, double weight)
  onAdd;
  const _ExerciseCard({
    super.key,
    required this.exercise,
    required this.l10n,
    required this.trainUnit,
    required this.date,
    required this.showProgressionControls,
    required this.addEnabled,
    required this.onAdd,
  });

  @override
  ConsumerState<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends ConsumerState<_ExerciseCard> {
  late TextEditingController _setsCtrl, _repsCtrl, _weightCtrl;
  bool _applying = false;
  bool _userEdited = false;
  String? _appliedKey;

  @override
  void initState() {
    super.initState();
    _setsCtrl = TextEditingController();
    _repsCtrl = TextEditingController();
    _weightCtrl = TextEditingController();
    for (final c in [_setsCtrl, _repsCtrl, _weightCtrl]) {
      c.addListener(() {
        if (!_applying) _userEdited = true;
      });
    }
  }

  @override
  void dispose() {
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  String _suggestionKey(ProgressionSuggestion s) =>
      '${s.sets}-${s.reps}-${s.weightKg}';

  void _applySuggestion(ProgressionSuggestion s) {
    _applying = true;
    _setsCtrl.text = s.sets.toString();
    _repsCtrl.text = s.reps.toString();
    final w = widget.trainUnit == WeightUnit.lb
        ? s.weightKg * kgToLb
        : s.weightKg;
    _weightCtrl.text = w.toStringAsFixed(1);
    _applying = false;
    _appliedKey = _suggestionKey(s);
  }

  void _clearForNext() {
    _applying = true;
    _setsCtrl.clear();
    _repsCtrl.clear();
    _weightCtrl.clear();
    _applying = false;
    setState(() {
      _userEdited = false;
      _appliedKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = widget.trainUnit == WeightUnit.kg ? 'kg' : 'lb';
    final rule = widget.showProgressionControls
        ? ref.watch(progressionRuleForExerciseProvider(widget.exercise.id))
        : null;
    final suggestion = widget.showProgressionControls
        ? ref.watch(
            progressionSuggestionProvider((
              exerciseId: widget.exercise.id,
              before: widget.date,
            )),
          )
        : null;

    if (suggestion != null &&
        !_userEdited &&
        _appliedKey != _suggestionKey(suggestion)) {
      final s = suggestion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_userEdited || _appliedKey == _suggestionKey(s)) return;
        setState(() => _applySuggestion(s));
      });
    }

    final ruleActive = rule != null && rule.enabled;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          instantPageRoute(ExerciseDetailScreen(exercise: widget.exercise)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.l10n.exerciseName(
                        widget.exercise.id,
                        widget.exercise.name,
                      ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (widget.showProgressionControls)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 18,
                      tooltip: widget.l10n.get('progressiveOverload'),
                      icon: Icon(
                        Icons.trending_up,
                        size: 18,
                        color: ruleActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).disabledColor,
                      ),
                      onPressed: () => showProgressionRuleSheet(
                        context,
                        ref,
                        exercise: widget.exercise,
                        l10n: widget.l10n,
                      ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.info_outline, size: 16),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _numField(
                    controller: _setsCtrl,
                    label: widget.l10n.get('sets'),
                    width: 64,
                  ),
                  const SizedBox(width: 6),
                  _numField(
                    controller: _repsCtrl,
                    label: widget.l10n.get('reps'),
                    width: 86,
                  ),
                  const SizedBox(width: 6),
                  _numField(
                    controller: _weightCtrl,
                    label: unitLabel,
                    width: 72,
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: !widget.addEnabled
                        ? null
                        : () {
                            final sets =
                                int.tryParse(_setsCtrl.text) ??
                                (suggestion?.sets ?? 3);
                            final reps = int.tryParse(_repsCtrl.text) ?? 0;
                            double w = double.tryParse(_weightCtrl.text) ?? 0;
                            if (widget.trainUnit == WeightUnit.lb) {
                              w = w / kgToLb;
                            }
                            widget.onAdd(widget.exercise.id, sets, reps, w);
                            _clearForNext();
                          },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      widget.l10n.get('add'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (ruleActive && suggestion != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${widget.l10n.get('suggested')}: '
                    '${widget.l10n.format(suggestion.reasonKey, suggestion.reasonParams)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField({
    required TextEditingController controller,
    required String label,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 4,
          ),
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}
