import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/user_profile.dart';
import '../../../core/utils/nutrition_calculator.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/metallic_surface.dart';
import '../../../data/repositories/app_database.dart';
import 'package:go_router/go_router.dart';

class NutritionPlanScreen extends ConsumerStatefulWidget {
  const NutritionPlanScreen({super.key});
  @override
  ConsumerState<NutritionPlanScreen> createState() => _NutritionPlanState();
}

class _NutritionPlanState extends ConsumerState<NutritionPlanScreen>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  String? _goal;
  String? _planType;
  String _experience = 'intermediate';
  double _activityFactor = 1.55;
  List<String> _cycleTemplate = [
    'low',
    'low',
    'medium',
    'low',
    'medium',
    'medium',
    'high',
  ];
  DateTime? _planStartDate;
  int? _planDurationDays;
  int? _lastStep;
  bool _didTriggerAnim = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _curvedAnim;

  static const _presetTemplates = {
    'presetClassicSevenDay': [
      'low',
      'low',
      'medium',
      'low',
      'medium',
      'medium',
      'high',
    ],
    'presetThreeDayRolling': ['low', 'medium', 'high'],
    'presetFiveDaySplit': ['low', 'low', 'medium', 'medium', 'high'],
    'presetFourDayLowFocus': ['low', 'low', 'low', 'medium'],
    'presetTwoDayAlternating': ['low', 'high'],
  };

  static const _activityLabelKeys = [
    'activitySedentary',
    'activityLight',
    'activityModerate',
    'activityVeryActive',
    'activityExtremelyActive',
  ];
  static const _activityFrequencyRanges = ['0-1', '1-2', '3-4', '5-6', '6-7'];
  static const _activityValues = [1.2, 1.375, 1.55, 1.725, 1.9];

  Color get _mutedTextColor => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _subtleBorderColor => Theme.of(context).colorScheme.outlineVariant;
  Color get _cycleLowColor => const Color(0xFF66717D);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _curvedAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadSavedPlan();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPlan() async {
    final userId = ref.read(currentUserIdProvider);
    final saved = await AppDatabase.instance.getNutritionPlan(userId);
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() {
        _step = 4; // Skip to dashboard
        _goal = saved['goal'] as String?;
        _planType = saved['planType'] as String? ?? 'carb_cycle';
        _experience = saved['experience'] as String? ?? 'intermediate';
        _activityFactor = (saved['activityFactor'] as num?)?.toDouble() ?? 1.55;
        _cycleTemplate =
            (saved['cycleTemplate'] as List?)?.cast<String>() ?? _cycleTemplate;
        _planDurationDays = saved['planDurationDays'] as int?;
        if (saved['planStartDate'] != null) {
          _planStartDate = DateTime.parse(saved['planStartDate'] as String);
        }
        if (_cycleTemplate.length < 2) _cycleTemplate = ['low', 'high'];
        if (_planType == 'carb_cycle') {
          ref.read(nutritionCycleProvider.notifier).state = _cycleTemplate;
          ref.read(nutritionStartDateProvider.notifier).state = _planStartDate;
        }
      });
    }
  }

  Future<void> _savePlan() async {
    final userId = ref.read(currentUserIdProvider);
    _planStartDate ??= DateTime.now();
    await AppDatabase.instance.saveNutritionPlan(userId, {
      'goal': _goal,
      'planType': _planType,
      'experience': _experience,
      'activityFactor': _activityFactor,
      'cycleTemplate': _cycleTemplate,
      'planStartDate': _planStartDate?.toIso8601String(),
      if (_planDurationDays != null) 'planDurationDays': _planDurationDays,
    });
    if (_planType == 'carb_cycle') {
      ref.read(nutritionCycleProvider.notifier).state = _cycleTemplate;
      ref.read(nutritionStartDateProvider.notifier).state = _planStartDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    if (profileAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.get('nutritionPlan'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.get('nutritionPlan'))),
        body: Center(child: Text(l10n.get('setupBodyFirst'))),
      );
    }
    if (_step < 4) {
      _didTriggerAnim = false;
      return _buildOnboarding(l10n, profile);
    }
    if (!_didTriggerAnim) {
      _didTriggerAnim = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animCtrl.reset();
        _animCtrl.forward();
      });
    }
    return _buildDashboard(l10n, profile);
  }

  // ================================
  // ONBOARDING
  // ================================
  Widget _buildOnboarding(L10n l10n, UserProfile profile) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.get('nutritionPlan'))),
      body: MetallicReadingSurface(
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _stepper(),
              const SizedBox(height: 32),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    final last = _lastStep ?? _step;
                    _lastStep = _step;
                    final offset = _step > last ? 1.0 : -1.0;
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(-offset, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _step == 0
                        ? _stepGoal(l10n)
                        : _step == 1
                        ? _stepPlan(l10n)
                        : _step == 2
                        ? _stepActivity(l10n)
                        : _stepDuration(l10n),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () {
                        _lastStep = _step;
                        if (_step == 3) {
                          setState(() => _step = 2);
                        } else if (_step == 2 && _goal == 'maintain') {
                          setState(() => _step = 0);
                        } else {
                          setState(() => _step--);
                        }
                      },
                      child: Text(l10n.get('back')),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      _lastStep = _step;
                      if (_step == 0 && _goal == 'maintain') {
                        setState(() => _step = 2);
                      } else if (_step == 0) {
                        setState(() => _step = 1);
                      } else if (_step == 1) {
                        setState(() => _step = 2);
                      } else if (_step == 2) {
                        setState(() => _step = 3);
                      } else if (_step == 3) {
                        _savePlan();
                        setState(() => _step = 4);
                      }
                    },
                    child: Text(l10n.get(_step == 3 ? 'getStarted' : 'next')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepper() {
    final showCount = _goal == 'maintain' ? 3 : 4;
    int displayStep;
    if (_goal == 'maintain') {
      displayStep = _step >= 2 ? _step - 1 : _step;
    } else {
      displayStep = _step;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        showCount,
        (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == displayStep ? 32 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == displayStep
                ? Theme.of(context).colorScheme.primary
                : _subtleBorderColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _stepGoal(L10n l10n) {
    return Column(
      children: [
        Text(
          l10n.get('nutritionGoalQuestion'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.get('nutritionGoalHint'),
          style: TextStyle(color: _mutedTextColor),
        ),
        const SizedBox(height: 32),
        _goalCard(
          Icons.trending_down,
          l10n.get('cut'),
          l10n.get('nutritionCutDescription'),
          _goal == 'cut',
          () => setState(() => _goal = 'cut'),
        ),
        const SizedBox(height: 12),
        _goalCard(
          Icons.trending_flat,
          l10n.get('maintain'),
          l10n.get('nutritionMaintainDescription'),
          _goal == 'maintain',
          () => setState(() => _goal = 'maintain'),
        ),
        const SizedBox(height: 12),
        _goalCard(
          Icons.trending_up,
          l10n.get('bulk'),
          l10n.get('nutritionBulkDescription'),
          _goal == 'bulk',
          () => setState(() => _goal = 'bulk'),
        ),
      ],
    );
  }

  Widget _goalCard(
    IconData icon,
    String title,
    String desc,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            width: selected ? 2 : 1,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : _subtleBorderColor,
          ),
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : _mutedTextColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(fontSize: 12, color: _mutedTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepPlan(L10n l10n) {
    if (_goal == 'maintain') return _stepActivity(l10n);
    return Column(
      children: [
        Text(
          l10n.get('nutritionChooseMethod'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _goal == 'cut'
              ? l10n.get('nutritionCutMethodHint')
              : l10n.get('nutritionExperienceHint'),
          style: TextStyle(color: _mutedTextColor),
        ),
        const SizedBox(height: 32),
        if (_goal == 'cut') ...[
          _goalCard(
            Icons.loop,
            l10n.get('carbCycling'),
            l10n.get('carbCyclingDescription'),
            _planType == 'carb_cycle',
            () => setState(() => _planType = 'carb_cycle'),
          ),
          const SizedBox(height: 12),
          _goalCard(
            Icons.arrow_downward,
            l10n.get('carbTaper'),
            l10n.get('carbTaperDescription'),
            _planType == 'carb_taper',
            () => setState(() => _planType = 'carb_taper'),
          ),
        ] else ...[
          _goalCard(
            Icons.person,
            l10n.get('beginnerExperience'),
            l10n.get('beginnerExperienceDescription'),
            _experience == 'beginner',
            () => setState(() => _experience = 'beginner'),
          ),
          const SizedBox(height: 12),
          _goalCard(
            Icons.person_outline,
            l10n.get('intermediateExperience'),
            l10n.get('intermediateExperienceDescription'),
            _experience == 'intermediate',
            () => setState(() => _experience = 'intermediate'),
          ),
          const SizedBox(height: 12),
          _goalCard(
            Icons.school,
            l10n.get('advancedExperience'),
            l10n.get('advancedExperienceDescription'),
            _experience == 'advanced',
            () => setState(() => _experience = 'advanced'),
          ),
        ],
      ],
    );
  }

  String _trainingFrequencyLabel(L10n l10n, int index) {
    return l10n.format('trainingFrequency', {
      'range': _activityFrequencyRanges[index.clamp(0, 4)],
    });
  }

  String _durationLabel(L10n l10n, {required int weeks, required int days}) {
    return l10n.format('durationWeeksDays', {
      'weeks': weeks.toString(),
      'days': days.toString(),
    });
  }

  String _carbTypeShortLabel(L10n l10n, String type) {
    return l10n.get(
      {
            'low': 'lowCarbShort',
            'medium': 'mediumCarbShort',
            'high': 'highCarbShort',
          }[type] ??
          'lowCarbShort',
    );
  }

  Widget _stepActivity(L10n l10n) {
    final idx = _activityValues.indexOf(_activityFactor);
    return Column(
      children: [
        Text(
          l10n.get('activityLevel'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.get('activityLevelDescription'),
          textAlign: TextAlign.center,
          style: TextStyle(color: _mutedTextColor),
        ),
        const SizedBox(height: 32),
        Text(
          l10n.get(_activityLabelKeys[idx.clamp(0, 4)]),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _trainingFrequencyLabel(l10n, idx),
          style: TextStyle(fontSize: 16, color: _mutedTextColor),
        ),
        const SizedBox(height: 24),
        Slider(
          value: idx.toDouble().clamp(0, 4),
          max: 4,
          divisions: 4,
          label: l10n.get(_activityLabelKeys[idx.clamp(0, 4)]),
          onChanged: (v) =>
              setState(() => _activityFactor = _activityValues[v.round()]),
        ),
      ],
    );
  }

  Widget _stepDuration(L10n l10n) {
    return Column(
      children: [
        Text(
          l10n.get('planDuration'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.get('planDurationQuestion'),
          style: TextStyle(color: _mutedTextColor),
        ),
        const SizedBox(height: 32),
        _goalCard(
          Icons.calendar_today,
          _durationLabel(l10n, weeks: 4, days: 28),
          l10n.get('durationFourWeeksDescription'),
          _planDurationDays == 28,
          () => setState(() => _planDurationDays = 28),
        ),
        const SizedBox(height: 12),
        _goalCard(
          Icons.calendar_month,
          _durationLabel(l10n, weeks: 8, days: 56),
          l10n.get('durationEightWeeksDescription'),
          _planDurationDays == 56,
          () => setState(() => _planDurationDays = 56),
        ),
        const SizedBox(height: 12),
        _goalCard(
          Icons.date_range,
          _durationLabel(l10n, weeks: 12, days: 84),
          l10n.get('durationTwelveWeeksDescription'),
          _planDurationDays == 84,
          () => setState(() => _planDurationDays = 84),
        ),
        const SizedBox(height: 12),
        _goalCard(
          Icons.edit_calendar,
          l10n.get('custom'),
          l10n.get('customDurationDescription'),
          _planDurationDays != null &&
              ![28, 56, 84].contains(_planDurationDays),
          () => _showDurationPicker(l10n),
        ),
      ],
    );
  }

  void _showDurationPicker(L10n l10n) {
    final ctrl = TextEditingController(
      text: (_planDurationDays ?? 30).toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.get('customDuration')),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            suffixText: l10n.get('days'),
            hintText: l10n.get('durationExample'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton(
            onPressed: () {
              final d = int.tryParse(ctrl.text);
              if (d != null && d >= 1 && d <= 180) {
                setState(() => _planDurationDays = d);
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.get('ok')),
          ),
        ],
      ),
    );
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
    final surplus = (_goal == 'bulk')
        ? (_experience == 'beginner'
              ? 500
              : _experience == 'intermediate'
              ? 350
              : 250)
        : 0;

    // Compute targets
    ({double cals, double protein, double carbs, double fat}) targets;
    String planLabel = '';
    if (_planType == 'carb_cycle') {
      final startDate = _planStartDate ?? DateTime.now();
      final daysSinceStart = today.difference(startDate).inDays;
      final templateDay =
          _cycleTemplate[daysSinceStart.clamp(0, 99999) %
              _cycleTemplate.length];
      targets = calc.carbCycleDay(
        profile,
        templateDay,
        _activityFactor,
        deficit.toDouble(),
      );
      planLabel =
          {
            'high': l10n.get('highCarb'),
            'medium': l10n.get('mediumCarb'),
            'low': l10n.get('lowCarb'),
          }[templateDay] ??
          '';
    } else if (_planType == 'carb_taper') {
      targets = calc.carbTaper(
        profile,
        _activityFactor,
        deficit.toDouble(),
        3.0,
        1.0,
      );
      planLabel = l10n.get('carbTaper');
    } else {
      targets = calc.bulk(profile, _activityFactor, surplus, _experience);
      planLabel = l10n.get('bulk');
    }

    // Actual intake from diet cache
    final dietCache = ref.watch(dietCacheProvider);
    final dk =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final dietLogs = dietCache[dk] ?? [];
    final foods = ref.watch(foodListProvider).valueOrNull ?? [];
    double actualKcal = 0, actualP = 0, actualC = 0, actualF = 0;
    for (final log in dietLogs) {
      actualKcal += log.calories;
      final food = foods.where((f) => f.id == log.foodId).firstOrNull;
      if (food != null) {
        final f = log.grams / 100;
        actualP += food.proteinPer100g * f;
        actualC += food.carbsPer100g * f;
        actualF += food.fatPer100g * f;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const SizedBox.shrink(), toolbarHeight: 4),
      body: MetallicReadingSurface(
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Target macros
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _pill(label: planLabel),
                          Expanded(
                            child: Center(
                              child: Text(
                                l10n.get('dailyTargets'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                          Text(
                            _buildDayLabel(l10n, today),
                            style: TextStyle(
                              fontSize: 12,
                              color: _mutedTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _stat(
                            targets.cals.toStringAsFixed(0),
                            'kcal',
                            Theme.of(context).colorScheme.primary,
                          ),
                          _stat(
                            '${targets.protein.toStringAsFixed(0)}g',
                            l10n.get('protein'),
                            Colors.blue,
                          ),
                          _stat(
                            '${targets.carbs.toStringAsFixed(0)}g',
                            l10n.get('carbs'),
                            Colors.orange,
                          ),
                          _stat(
                            '${targets.fat.toStringAsFixed(0)}g',
                            l10n.get('fat'),
                            Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Progress bars
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        l10n.get('todaysIntake'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (dietLogs.isEmpty) ...[
                        Icon(
                          Icons.restaurant_outlined,
                          size: 32,
                          color: _mutedTextColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.get('noMeals'),
                          style: TextStyle(color: _mutedTextColor),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => context.push('/home'),
                          child: Text(
                            l10n.get('goToDietTab'),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ] else ...[
                        _progress(
                          'kcal',
                          actualKcal,
                          targets.cals,
                          Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        _progress(
                          l10n.get('protein'),
                          actualP,
                          targets.protein,
                          Colors.blue,
                        ),
                        const SizedBox(height: 8),
                        _progress(
                          l10n.get('carbs'),
                          actualC,
                          targets.carbs,
                          Colors.orange,
                        ),
                        const SizedBox(height: 8),
                        _progress(
                          l10n.get('fat'),
                          actualF,
                          targets.fat,
                          Colors.red,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // TDEE info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _infoRow('BMR', '${b.toStringAsFixed(0)} kcal'),
                      _infoRow('TDEE', '${tdee.toStringAsFixed(0)} kcal'),
                      _infoRow('TEF', '${tef.toStringAsFixed(0)} kcal'),
                    ],
                  ),
                ),
              ),
              // Refeed countdown for Carb Taper
              if (_planType == 'carb_taper') ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.loop, size: 18, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          l10n.format('nextRefeed', {
                            'days': _daysUntilRefeed().toString(),
                          }),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const Spacer(),
                        Text(
                          l10n.get('everyFourteenDays'),
                          style: TextStyle(
                            fontSize: 11,
                            color: _mutedTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              // Carb cycle week
              if (_planType == 'carb_cycle') ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              l10n.get('cyclePattern'),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              onPressed: () => _showCycleEditor(l10n),
                              tooltip: l10n.get('editTemplate'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _cycleTemplate.length,
                            itemBuilder: (ctx, i) {
                              final startDate =
                                  _planStartDate ?? DateTime.now();
                              final todayIdx = DateTime.now()
                                  .difference(startDate)
                                  .inDays;
                              final isToday =
                                  todayIdx.clamp(0, 99999) %
                                      _cycleTemplate.length ==
                                  i;
                              final t = _cycleTemplate[i];
                              final colors = {
                                'high': Colors.orange,
                                'medium': Colors.blue,
                                'low': _cycleLowColor,
                              };
                              return Container(
                                width: 36,
                                height: 36,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: (colors[t] ?? _cycleLowColor)
                                      .withValues(alpha: isToday ? 1 : 0.3),
                                  borderRadius: BorderRadius.circular(18),
                                  border: isToday
                                      ? Border.all(
                                          width: 2,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isToday
                                            ? Colors.white
                                            : colors[t],
                                      ),
                                    ),
                                    Text(
                                      _carbTypeShortLabel(l10n, t),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isToday
                                            ? Colors.white
                                            : colors[t],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Action buttons
              OutlinedButton.icon(
                onPressed: () => _showEditActivity(l10n),
                icon: const Icon(Icons.tune, size: 18),
                label: Text(l10n.get('editActivity')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _confirmReset(l10n),
                icon: const Icon(Icons.refresh, size: 18, color: Colors.red),
                label: Text(l10n.get('resetPlan')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: color,
        ),
      ),
      Text(label, style: TextStyle(fontSize: 11, color: _mutedTextColor)),
    ],
  );

  Widget _progress(String label, double actual, double target, Color color) {
    final pct = target > 0 ? ((actual / target).clamp(0.0, 1.0)) : 0.0;
    return AnimatedBuilder(
      animation: _curvedAnim,
      builder: (context, child) {
        final v = _curvedAnim.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 12)),
                Text(
                  '${(actual * v).toStringAsFixed(0)} / ${target.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct * v,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: _mutedTextColor, fontSize: 13)),
        Text(value, style: const TextStyle(fontSize: 13)),
      ],
    ),
  );

  Widget _pill({required String label}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  String _buildDayLabel(L10n l10n, DateTime today) {
    final startDate = _planStartDate ?? DateTime.now();
    final dayCount = today.difference(startDate).inDays + 1;
    final d = _planDurationDays;
    return d != null
        ? l10n.format('planDayWithDuration', {
            'current': dayCount.toString(),
            'total': d.toString(),
          })
        : l10n.format('planDay', {'current': dayCount.toString()});
  }

  void _showEditActivity(L10n l10n) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final i = _activityValues.indexOf(_activityFactor);
          return AlertDialog(
            title: Text(l10n.get('editSettings')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.get('activityLevel'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.get(_activityLabelKeys[i.clamp(0, 4)]),
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  _trainingFrequencyLabel(l10n, i),
                  style: TextStyle(color: _mutedTextColor),
                ),
                Slider(
                  value: i.toDouble().clamp(0, 4),
                  max: 4,
                  divisions: 4,
                  onChanged: (v) => setDialogState(
                    () => _activityFactor = _activityValues[v.round()],
                  ),
                ),
                if (_goal == 'bulk') ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.get('trainingExperience'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'beginner',
                        label: Text(l10n.get('beginner')),
                      ),
                      ButtonSegment(
                        value: 'intermediate',
                        label: Text(l10n.get('intermediateShort')),
                      ),
                      ButtonSegment(
                        value: 'advanced',
                        label: Text(l10n.get('advanced')),
                      ),
                    ],
                    selected: {_experience},
                    onSelectionChanged: (v) =>
                        setDialogState(() => _experience = v.first),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  l10n.get('planDuration'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [28, 56, 84]
                      .map(
                        (d) => ChoiceChip(
                          label: Text(
                            l10n.format('durationDays', {'days': d.toString()}),
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: _planDurationDays == d,
                          onSelected: (_) =>
                              setDialogState(() => _planDurationDays = d),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showDurationPicker(l10n);
                  },
                  child: Text(l10n.get('customEllipsis')),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.get('cancel')),
              ),
              FilledButton(
                onPressed: () {
                  _savePlan();
                  setState(() {});
                  Navigator.pop(ctx);
                },
                child: Text(l10n.get('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCycleEditor(L10n l10n) {
    final labels = {
      'low': l10n.get('lowCarb'),
      'medium': l10n.get('mediumCarb'),
      'high': l10n.get('highCarb'),
    };
    final template = List<String>.from(_cycleTemplate);
    final startCtrl = TextEditingController(
      text: _planStartDate != null
          ? DateFormat('yyyy-MM-dd').format(_planStartDate!)
          : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            expand: false,
            builder: (ctx, scrollCtrl) => SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.get('editCyclePattern'),
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.format('cycleDaysHighlighted', {
                      'days': template.length.toString(),
                    }),
                    style: TextStyle(color: _mutedTextColor, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  // Presets
                  Text(
                    l10n.get('presets'),
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 10,
                    children: _presetTemplates.entries
                        .map(
                          (e) => ActionChip(
                            label: Text(
                              l10n.get(e.key),
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              _cycleTemplate = e.value;
                              _planStartDate = DateTime.now();
                              Navigator.pop(ctx);
                              _savePlan();
                              setState(() {});
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.get('customPattern'),
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: template.asMap().entries.map((e) {
                      final t = e.value;
                      return GestureDetector(
                        onTap: () {
                          final next =
                              {
                                'low': 'medium',
                                'medium': 'high',
                                'high': 'low',
                              }[t] ??
                              'low';
                          setSheetState(() => template[e.key] = next);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.format('cycleDayLabel', {
                                  'day': (e.key + 1).toString(),
                                  'type': labels[t] ?? '',
                                }),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (template.length > 2)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => setSheetState(
                                    () => template.removeAt(e.key),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Icon(Icons.close, size: 16),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (template.length < 30) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          setSheetState(() => template.add('medium')),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(l10n.get('addDay')),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Start date
                  Text(
                    l10n.get('startDate'),
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.get('cycleStartDateHint'),
                    style: TextStyle(fontSize: 12, color: _mutedTextColor),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: startCtrl,
                    decoration: const InputDecoration(
                      hintText: 'yyyy-MM-dd',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      final d = DateTime.tryParse(v);
                      if (d != null) setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(l10n.get('cancel')),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          final d = DateTime.tryParse(startCtrl.text);
                          _cycleTemplate = template;
                          _planStartDate = d ?? DateTime.now();
                          Navigator.pop(ctx);
                          _savePlan();
                          setState(() {});
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
      ),
    );
  }

  int _daysUntilRefeed() {
    final start = _planStartDate ?? DateTime.now();
    final elapsed = DateTime.now().difference(start).inDays;
    return 14 - (elapsed % 14);
  }

  void _confirmReset(L10n l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.get('resetPlan')),
        content: Text(l10n.get('resetPlanDescription')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = ref.read(currentUserIdProvider);
              await AppDatabase.instance.deleteNutritionPlan(userId);
              ref.read(nutritionCycleProvider.notifier).state = null;
              ref.read(nutritionStartDateProvider.notifier).state = null;
              setState(() {
                _step = 0;
                _goal = null;
                _planType = null;
                _activityFactor = 1.55;
                _planDurationDays = null;
              });
            },
            child: Text(l10n.get('reset')),
          ),
        ],
      ),
    );
  }
}
