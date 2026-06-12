import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/app_providers.dart';

class NutritionPlanScreen extends ConsumerWidget {
  const NutritionPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(nutritionPlanProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final macrosAsync = ref.watch(dailyMacrosProvider(selectedDate));

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition Plan')),
      body:
          plan == null
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text('Set up your body data first'),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CalorieCard(plan: plan),
                    const SizedBox(height: 16),
                    _MacroProgressCard(
                      target: plan,
                      consumed: macrosAsync,
                    ),
                    const SizedBox(height: 16),
                    _MacroPieChart(target: plan),
                  ],
                ),
              ),
    );
  }
}

class _CalorieCard extends StatelessWidget {
  final ({double tdee, double protein, double carbs, double fat}) plan;
  const _CalorieCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Target',
                  value: plan.tdee.toStringAsFixed(0),
                  unit: 'kcal',
                ),
                _StatItem(
                  label: 'Protein',
                  value: plan.protein.toStringAsFixed(0),
                  unit: 'g',
                ),
                _StatItem(
                  label: 'Carbs',
                  value: plan.carbs.toStringAsFixed(0),
                  unit: 'g',
                ),
                _StatItem(
                  label: 'Fat',
                  value: plan.fat.toStringAsFixed(0),
                  unit: 'g',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                unit,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MacroProgressCard extends StatelessWidget {
  final ({double tdee, double protein, double carbs, double fat}) target;
  final ({double protein, double carbs, double fat}) consumed;
  const _MacroProgressCard({
    required this.target,
    required this.consumed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today vs Target',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _ProgressBar(
              label: 'Protein',
              current: consumed.protein,
              target: target.protein,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _ProgressBar(
              label: 'Carbs',
              current: consumed.carbs,
              target: target.carbs,
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            _ProgressBar(
              label: 'Fat',
              current: consumed.fat,
              target: target.fat,
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double current;
  final double target;
  final Color color;
  const _ProgressBar({
    required this.label,
    required this.current,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(
              '${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} g',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _MacroPieChart extends StatelessWidget {
  final ({double tdee, double protein, double carbs, double fat}) target;
  const _MacroPieChart({required this.target});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Macro Split',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: target.protein * 4,
                            color: Colors.blue,
                            title: '${((target.protein * 4 / target.tdee) * 100).toStringAsFixed(0)}%',
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            value: target.carbs * 4,
                            color: Colors.orange,
                            title: '${((target.carbs * 4 / target.tdee) * 100).toStringAsFixed(0)}%',
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            value: target.fat * 9,
                            color: Colors.red,
                            title: '${((target.fat * 9 / target.tdee) * 100).toStringAsFixed(0)}%',
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                        centerSpaceRadius: 30,
                      ),
                    ),
                  ),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LegendItem(color: Colors.blue, label: 'Protein'),
                      SizedBox(height: 8),
                      _LegendItem(color: Colors.orange, label: 'Carbs'),
                      SizedBox(height: 8),
                      _LegendItem(color: Colors.red, label: 'Fat'),
                    ],
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
