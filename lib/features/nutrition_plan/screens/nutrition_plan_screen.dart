import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../data/models/user_profile.dart';
import '../../../core/utils/nutrition_calculator.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../core/localization/l10n.dart';
import '../../../data/repositories/app_database.dart';

class NutritionPlanScreen extends ConsumerStatefulWidget {
  const NutritionPlanScreen({super.key});
  @override
  ConsumerState<NutritionPlanScreen> createState() => _NutritionPlanState();
}

class _NutritionPlanState extends ConsumerState<NutritionPlanScreen> {
  int _step = 0;
  String? _goal;
  String? _planType;
  String _experience = 'intermediate';
  double _activityFactor = 1.55;
  List<String> _cycleTemplate = ['low', 'low', 'medium', 'low', 'medium', 'medium', 'high'];
  int? _lastStep;

  static const _activityLabels = ['Sedentary', 'Lightly Active', 'Moderate', 'Very Active', 'Extremely Active'];
  static const _activityFrequency = ['0-1 ×/week', '1-2 ×/week', '3-4 ×/week', '5-6 ×/week', '6-7 ×/week'];
  static const _activityValues = [1.2, 1.375, 1.55, 1.725, 1.9];

  @override
  void initState() {
    super.initState();
    _loadSavedPlan();
  }

  Future<void> _loadSavedPlan() async {
    final userId = ref.read(currentUserIdProvider);
    final saved = await AppDatabase.instance.getNutritionPlan(userId);
    if (saved != null && mounted) {
      setState(() {
        _step = 3; // Skip to dashboard
        _goal = saved['goal'] as String?;
        _planType = saved['planType'] as String? ?? 'carb_cycle';
        _experience = saved['experience'] as String? ?? 'intermediate';
        _activityFactor = (saved['activityFactor'] as num?)?.toDouble() ?? 1.55;
        _cycleTemplate = (saved['cycleTemplate'] as List?)?.cast<String>() ?? ['low','low','medium','low','medium','medium','high'];
        if (_planType == 'carb_cycle') ref.read(nutritionCycleProvider.notifier).state = _cycleTemplate;
      });
    }
  }

  Future<void> _savePlan() async {
    final userId = ref.read(currentUserIdProvider);
    await AppDatabase.instance.saveNutritionPlan(userId, {
      'goal': _goal, 'planType': _planType, 'experience': _experience,
      'activityFactor': _activityFactor, 'cycleTemplate': _cycleTemplate,
    });
    if (_planType == 'carb_cycle') ref.read(nutritionCycleProvider.notifier).state = _cycleTemplate;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    if (profile == null) {
      return Scaffold(appBar: AppBar(title: Text(l10n.get('nutritionPlan'))), body: Center(child: Text(l10n.get('setupBodyFirst'))));
    }
    if (_step < 3) return _buildOnboarding(l10n, profile);
    return _buildDashboard(l10n, profile);
  }

  // ================================
  // ONBOARDING
  // ================================
  Widget _buildOnboarding(L10n l10n, UserProfile profile) {
    final isEn = ref.watch(localeProvider) == AppLocale.en;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.get('nutritionPlan'))),
      body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
        _stepper(), const SizedBox(height: 32),
        Expanded(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            final last = _lastStep ?? _step;
            _lastStep = _step;
            final offset = _step > last ? 1.0 : -1.0;
            return SlideTransition(
              position: Tween<Offset>(begin: Offset(-offset, 0), end: Offset.zero).animate(animation),
              child: child,
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: _step == 0 ? _stepGoal(l10n, isEn) : _step == 1 ? _stepPlan(l10n, isEn) : _stepActivity(l10n, isEn),
          ),
        )),
        const SizedBox(height: 16),
        Row(children: [
              if (_step > 0) TextButton(onPressed: () { _lastStep = _step; setState(() => _step--); }, child: const Text('Back')),
              const Spacer(),
              FilledButton(onPressed: () {
                _lastStep = _step;
                if (_step == 2) { _savePlan(); setState(() => _step = 3); } else { setState(() => _step++); }
              }, child: Text(_step == 2 ? 'Get Started' : 'Next')),
        ]),
      ])),
    );
  }

  Widget _stepper() {
    final steps = _goal == 'maintain' ? 2 : 3;
    final current = _goal == 'maintain' && _step >= 2 ? _step - 1 : _step;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(steps, (i) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: i == current ? 32 : 8, height: 8,
      decoration: BoxDecoration(color: i == current ? Theme.of(context).colorScheme.primary : Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
    )));
  }

  Widget _stepGoal(L10n l10n, bool isEn) {
    return Column(children: [
      Text('What\'s your goal?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('This determines your calorie target', style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 32),
      _goalCard(Icons.trending_down, 'Cut', 'Lose fat while preserving muscle.\n500 kcal daily deficit.', _goal == 'cut', () => setState(() => _goal = 'cut')),
      const SizedBox(height: 12),
      _goalCard(Icons.trending_flat, 'Maintain', 'Keep your current body composition.\nEat at maintenance calories.', _goal == 'maintain', () => setState(() => _goal = 'maintain')),
      const SizedBox(height: 12),
      _goalCard(Icons.trending_up, 'Bulk', 'Build muscle with controlled surplus.\n+200-500 kcal daily surplus.', _goal == 'bulk', () => setState(() => _goal = 'bulk')),
    ]);
  }

  Widget _goalCard(IconData icon, String title, String desc, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(width: selected ? 2 : 1, color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300), borderRadius: BorderRadius.circular(16), color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05) : null),
        child: Row(children: [Icon(icon, size: 32, color: selected ? Theme.of(context).colorScheme.primary : Colors.grey), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]))]),
      ),
    );
  }

  Widget _stepPlan(L10n l10n, bool isEn) {
    if (_goal == 'maintain') return _stepActivity(l10n, isEn);
    return Column(children: [
      Text('Choose your method', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(_goal == 'cut' ? 'Two evidence-based approaches for fat loss' : 'Select your training experience', style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 32),
      if (_goal == 'cut') ...[
        _goalCard(Icons.loop, 'Carb Cycling', 'Rotate high/medium/low carb days\nbased on training intensity.\nMetabolically adaptive.', _planType == 'carb_cycle', () => setState(() => _planType = 'carb_cycle')),
        const SizedBox(height: 12),
        _goalCard(Icons.arrow_downward, 'Carb Taper', 'Gradually reduce carbs each phase.\nSimple and predictable.\nRefeed every 2-4 weeks.', _planType == 'carb_taper', () => setState(() => _planType = 'carb_taper')),
      ] else ...[
        _goalCard(Icons.person, 'Beginner (< 1yr)', '+500 kcal, high carb ratio.\nMaximize newbie gains.', _experience == 'beginner', () => setState(() => _experience = 'beginner')),
        const SizedBox(height: 12),
        _goalCard(Icons.person_outline, 'Intermediate (1-3yr)', '+300-400 kcal.\nBalanced macro split.', _experience == 'intermediate', () => setState(() => _experience = 'intermediate')),
        const SizedBox(height: 12),
        _goalCard(Icons.school, 'Advanced (3+yr)', '+200-300 kcal.\nHigher protein, leaner gains.', _experience == 'advanced', () => setState(() => _experience = 'advanced')),
      ],
    ]);
  }

  Widget _stepActivity(L10n l10n, bool isEn) {
    final idx = _activityValues.indexOf(_activityFactor);
    return Column(children: [
      Text('Activity Level', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('How active is your daily life\n(outside of workouts)?', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 32),
      Text(_activityLabels[idx.clamp(0, 4)], style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('Train ${_activityFrequency[idx.clamp(0, 4)]}', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
      const SizedBox(height: 24),
      Slider(value: idx.toDouble().clamp(0, 4), max: 4, divisions: 4, label: _activityLabels[idx.clamp(0, 4)], onChanged: (v) => setState(() => _activityFactor = _activityValues[v.round()])),
    ]);
  }

  // ================================
  // DASHBOARD
  // ================================
  Widget _buildDashboard(L10n l10n, UserProfile profile) {
    final calc = const NutritionCalculator();
    final b = calc.bmr(profile);
    final tdee = calc.tdee(b, _activityFactor);
    final tef = calc.tef(tdee);
    final today = DateTime.now();
    final deficit = (_goal == 'cut') ? 500 : 0;
    final surplus = (_goal == 'bulk') ? (_experience == 'beginner' ? 500 : _experience == 'intermediate' ? 350 : 250) : 0;

    // Compute targets
    ({double cals, double protein, double carbs, double fat}) targets;
    String planLabel = '';
    if (_planType == 'carb_cycle') {
      final dayIdx = (today.weekday + 6) % 7;
      final templateDay = _cycleTemplate[dayIdx % _cycleTemplate.length];
      targets = calc.carbCycleDay(profile, templateDay, _activityFactor, deficit.toDouble());
      planLabel = {'high': 'High Carb', 'medium': 'Med Carb', 'low': 'Low Carb'}[templateDay] ?? '';
    } else if (_planType == 'carb_taper') {
      targets = calc.carbTaper(profile, _activityFactor, deficit.toDouble(), 3.0, 1.0);
      planLabel = 'Carb Taper';
    } else {
      targets = calc.bulk(profile, _activityFactor, surplus, _experience);
      planLabel = 'Bulk';
    }

    // Actual intake from diet cache
    final dietCache = ref.watch(dietCacheProvider);
    final dk = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final dietLogs = dietCache[dk] ?? [];
    final foods = ref.watch(foodListProvider).valueOrNull ?? [];
    double actualKcal = 0, actualP = 0, actualC = 0, actualF = 0;
    for (final log in dietLogs) {
      actualKcal += log.calories;
      final food = foods.where((f) => f.id == log.foodId).firstOrNull;
      if (food != null) { final f = log.grams / 100; actualP += food.proteinPer100g * f; actualC += food.carbsPer100g * f; actualF += food.fatPer100g * f; }
    }

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        toolbarHeight: 4,
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        // Target macros
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Row(children: [
            _pill(label: planLabel),
            const Spacer(),
            Text('Daily Targets', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _stat(targets.cals.toStringAsFixed(0), 'kcal', Theme.of(context).colorScheme.primary),
            _stat('${targets.protein.toStringAsFixed(0)}g', 'Protein', Colors.blue),
            _stat('${targets.carbs.toStringAsFixed(0)}g', 'Carbs', Colors.orange),
            _stat('${targets.fat.toStringAsFixed(0)}g', 'Fat', Colors.red),
          ]),
        ]))),
        const SizedBox(height: 12),
        // Progress bars
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Text('Today\'s Intake', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _progress('kcal', actualKcal, targets.cals, Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          _progress('Protein', actualP, targets.protein, Colors.blue),
          const SizedBox(height: 8),
          _progress('Carbs', actualC, targets.carbs, Colors.orange),
          const SizedBox(height: 8),
          _progress('Fat', actualF, targets.fat, Colors.red),
        ]))),
        const SizedBox(height: 12),
        // TDEE info
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          _infoRow('BMR', '${b.toStringAsFixed(0)} kcal'), _infoRow('TDEE', '${tdee.toStringAsFixed(0)} kcal'), _infoRow('TEF', '${tef.toStringAsFixed(0)} kcal'),
        ]))),
        // Carb cycle week
        if (_planType == 'carb_cycle') ...[
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Weekly Cycle', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].asMap().entries.map((e) {
              final t = _cycleTemplate[e.key];
              final isToday = e.key == (today.weekday + 6) % 7;
              final colors = {'high': Colors.orange, 'medium': Colors.blue, 'low': Colors.grey};
              return Column(children: [
                Text(e.value, style: TextStyle(fontSize: 11, color: Colors.grey)),
                Container(width: 32, height: 32, margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: (colors[t] ?? Colors.grey).withValues(alpha: isToday ? 1 : 0.3), borderRadius: BorderRadius.circular(16), border: isToday ? Border.all(width: 2, color: Colors.white) : null),
                  child: Center(child: Text(t[0].toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isToday ? Colors.white : colors[t])))),
              ]);
            }).toList()),
          ]))),
        ],
        const SizedBox(height: 16),
        // Action buttons
        OutlinedButton.icon(
          onPressed: () => _showEditActivity(l10n),
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Edit Activity'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _confirmReset(l10n),
          icon: const Icon(Icons.refresh, size: 18, color: Colors.red),
          label: const Text('Reset Plan'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44), foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
        ),
      ])),
    );
  }

  Widget _stat(String value, String label, Color color) => Column(children: [
    Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
  ]);

  Widget _progress(String label, double actual, double target, Color color) {
    final pct = target > 0 ? ((actual / target).clamp(0.0, 1.0) as double) : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12)), Text('${actual.toStringAsFixed(0)} / ${target.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: color.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation(color))),
    ]);
  }

  Widget _infoRow(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)), Text(value, style: const TextStyle(fontSize: 13))]));

  Widget _pill({required String label}) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3))), child: Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)));

  void _showEditActivity(L10n l10n) {
    final idx = _activityValues.indexOf(_activityFactor);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final i = _activityValues.indexOf(_activityFactor);
          return AlertDialog(
            title: const Text('Edit Activity Level'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_activityLabels[i.clamp(0, 4)], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('Train ${_activityFrequency[i.clamp(0, 4)]}', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              Slider(value: i.toDouble().clamp(0, 4), max: 4, divisions: 4, onChanged: (v) => setDialogState(() => _activityFactor = _activityValues[v.round()])),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(onPressed: () { _savePlan(); setState(() {}); Navigator.pop(ctx); }, child: const Text('Save')),
            ],
          );
        },
      ),
    );
  }

  void _confirmReset(L10n l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Plan'),
        content: const Text('This will restart the plan selection process. Your current settings will be replaced.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async {
            Navigator.pop(ctx);
            final userId = ref.read(currentUserIdProvider);
            await AppDatabase.instance.saveNutritionPlan(userId, {}); // clear saved
            ref.read(nutritionCycleProvider.notifier).state = null;
            setState(() { _step = 0; _goal = null; _planType = null; _activityFactor = 1.55; });
          }, child: const Text('Reset')),
        ],
      ),
    );
  }
}
