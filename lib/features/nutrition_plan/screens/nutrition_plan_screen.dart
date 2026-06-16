import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/nutrition_plan.dart';
import '../../../data/models/user_profile.dart';
import '../../../core/utils/nutrition_calculator.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/app_providers.dart';
import '../../../core/localization/l10n.dart';

class NutritionPlanScreen extends ConsumerWidget {
  final NutritionPlanConfig? config;
  const NutritionPlanScreen({super.key, this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final calc = const NutritionCalculator();

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.get('nutritionPlan'))),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.person_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(l10n.get('setupBodyFirst')),
          ]),
        ),
      );
    }

    final planConfig = config;
    if (planConfig == null) {
      // Fallback: use legacy calculation based on profile goal
      final legacy = calc.calculateLegacy(profile);
      return Scaffold(
        appBar: AppBar(title: Text(l10n.get('nutritionPlan'))),
        body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
          Card(
            child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              Row(children: [
                Text(l10n.get('nutritionPlan'), style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                _pill(ctx: context, label: profile.goal == FitnessGoal.loseFat ? 'Cut' : profile.goal == FitnessGoal.buildMuscle ? 'Bulk' : 'Maintain'),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _stat(l10n.get('target'), '${legacy.tdee.toStringAsFixed(0)}', 'kcal', Theme.of(context).colorScheme.primary),
                _stat(l10n.get('protein'), '${legacy.protein.toStringAsFixed(0)}', 'g', Colors.blue),
                _stat(l10n.get('carbs'), '${legacy.carbs.toStringAsFixed(0)}', 'g', Colors.orange),
                _stat(l10n.get('fat'), '${legacy.fat.toStringAsFixed(0)}', 'g', Colors.red),
              ]),
            ])),
          ),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            _infoRow('BMR', '${calc.bmr(profile).toStringAsFixed(0)} kcal'),
            _infoRow('TDEE', '${calc.tdee(calc.bmr(profile), 1.55).toStringAsFixed(0)} kcal'),
          ]))),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showPlanPicker(context, ref, profile),
            icon: const Icon(Icons.workspace_premium),
            label: const Text('Select Plan (Pro)'),
          ),
        ])),
      );
    }

    final b = calc.bmr(profile);
    final tdee = calc.tdee(b, planConfig.activityFactor);
    final tef = calc.tef(tdee);
    final today = DateTime.now();

    // Compute today's targets based on plan type
    ({double cals, double protein, double carbs, double fat}) targets;

    if (planConfig.planType == 'carb_cycle' && planConfig.cycleTemplate != null) {
      final dayIdx = (today.weekday + 6) % 7; // Monday=0
      final template = planConfig.cycleTemplate!;
      // Cycle repeats: dayIdx % template.length
      final templateDay = template[dayIdx % template.length];
      targets = calc.carbCycleDay(profile, templateDay, planConfig.activityFactor, planConfig.deficit.toDouble());
    } else if (planConfig.planType == 'carb_taper') {
      targets = calc.carbTaper(profile, planConfig.activityFactor, planConfig.deficit.toDouble(), planConfig.currentCarbGPerKg, planConfig.fatGPerKg);
    } else {
      targets = calc.bulk(profile, planConfig.activityFactor, planConfig.surplus, planConfig.experienceLevel);
    }

    final cycleLabels = {'high': 'High Carb', 'medium': 'Med Carb', 'low': 'Low Carb'};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.get('nutritionPlan'))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        // Summary card
        Card(
          child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Row(children: [
              Text(l10n.get('nutritionPlan'), style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (planConfig.planType == 'carb_cycle')
                _pill(ctx: context, label: cycleLabels[planConfig.cycleTemplate![(today.weekday + 6) % 7 % planConfig.cycleTemplate!.length]] ?? ''),
              if (planConfig.planType == 'carb_taper') _pill(ctx: context, label: 'Carb Taper'),
              if (planConfig.planType == 'bulk') _pill(ctx: context, label: 'Bulk'),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _stat(l10n.get('target'), '${targets.cals.toStringAsFixed(0)}', 'kcal', Theme.of(context).colorScheme.primary),
              _stat(l10n.get('protein'), '${targets.protein.toStringAsFixed(0)}', 'g', Colors.blue),
              _stat(l10n.get('carbs'), '${targets.carbs.toStringAsFixed(0)}', 'g', Colors.orange),
              _stat(l10n.get('fat'), '${targets.fat.toStringAsFixed(0)}', 'g', Colors.red),
            ]),
          ])),
        ),
        const SizedBox(height: 12),
        // BMR/TDEE/TEF info
        Card(
          child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            _infoRow('BMR', '${b.toStringAsFixed(0)} kcal'),
            _infoRow('TDEE', '${tdee.toStringAsFixed(0)} kcal (×${planConfig.activityFactor})'),
            _infoRow('TEF', '${tef.toStringAsFixed(0)} kcal'),
            _infoRow('Activity', _activityLabel(planConfig.activityFactor)),
          ])),
        ),
        // Carb cycle week view
        if (planConfig.planType == 'carb_cycle' && planConfig.cycleTemplate != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Weekly Cycle', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].asMap().entries.map((e) {
                final t = planConfig.cycleTemplate![e.key.clamp(0, planConfig.cycleTemplate!.length - 1)];
                final isToday = e.key == (today.weekday + 6) % 7;
                final colors = {'high': Colors.orange, 'medium': Colors.blue, 'low': Colors.grey};
                return Column(children: [
                  Text(e.value, style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Container(
                    width: 32, height: 32,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: (colors[t] ?? Colors.grey).withValues(alpha: isToday ? 1.0 : 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: isToday ? Border.all(width: 2, color: Colors.white) : null,
                    ),
                    child: Center(child: Text(t[0].toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isToday ? Colors.white : colors[t]))),
                  ),
                ]);
              }).toList()),
            ])),
          ),
        ],
      ])),
    );
  }

  Widget _stat(String label, String value, String unit, Color color) => Column(children: [
    Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
    Text('$label ($unit)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
  ]);

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      Text(value, style: const TextStyle(fontSize: 13)),
    ]),
  );

  Widget _pill({required BuildContext ctx, required String label}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.3))),
    child: Text(label, style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.primary, fontWeight: FontWeight.bold)),
  );

  String _activityLabel(double f) {
    for (final e in NutritionCalculator.activityFactors.entries) {
      if (e.value == f) return e.key;
    }
    return f.toString();
  }

  static void _showPlanPicker(BuildContext context, WidgetRef ref, UserProfile profile) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Select Your Plan', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 16),
          _planCard(ctx, 'Carb Cycling', 'High/Medium/Low carb days based on training intensity', 'carb_cycle'),
          const SizedBox(height: 8),
          _planCard(ctx, 'Carb Taper', 'Gradual carb reduction with refeed days', 'carb_taper'),
          const SizedBox(height: 8),
          _planCard(ctx, 'Bulk', 'Controlled calorie surplus for muscle gain', 'bulk'),
        ]),
      ),
    );
  }

  static Widget _planCard(BuildContext ctx, String title, String desc, String planType) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.pop(ctx);
        final config = NutritionPlanConfig(
          planType: planType,
          deficit: planType != 'bulk' ? 500 : 0,
          surplus: planType == 'bulk' ? 500 : 0,
          cycleTemplate: planType == 'carb_cycle' ? ['low','low','medium','low','medium','medium','high'] : null,
        );
        Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) => ProviderScope(child: NutritionPlanScreen(config: config)),
        ));
      },
    );
  }
}
