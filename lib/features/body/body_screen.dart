import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/localization/l10n.dart';
import '../../data/models/body_measurement.dart';
import '../../data/repositories/app_database.dart';
import '../../providers/app_providers.dart';
import '../../providers/settings_providers.dart';

class BodyScreen extends ConsumerStatefulWidget {
  const BodyScreen({super.key});
  @override
  ConsumerState<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends ConsumerState<BodyScreen> {
  List<BodyMeasurement> _entries = [];
  final _weightCtrl = TextEditingController();
  final _chestCtrl = TextEditingController();
  final _waistCtrl = TextEditingController();
  final _armCtrl = TextEditingController();
  int _chartDays = 30;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final userId = ref.read(currentUserIdProvider);
    final entries = await AppDatabase.instance.getBodyMeasurements(userId);
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  Future<void> _addEntry() async {
    final w = double.tryParse(_weightCtrl.text);
    if (w == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(l10nProvider).get('invalidNumber'))),
      );
      return;
    }
    final entry = BodyMeasurement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: ref.read(currentUserIdProvider),
      date: DateTime.now(),
      weight: w,
      chest: double.tryParse(_chestCtrl.text),
      waist: double.tryParse(_waistCtrl.text),
      leftArm: double.tryParse(_armCtrl.text),
    );
    await AppDatabase.instance.saveBodyMeasurement(
      ref.read(currentUserIdProvider),
      entry,
    );
    _weightCtrl.clear();
    _chestCtrl.clear();
    _waistCtrl.clear();
    _armCtrl.clear();
    _loadEntries();
  }

  Future<void> _deleteEntry(String id) async {
    await AppDatabase.instance.deleteBodyMeasurement(
      ref.read(currentUserIdProvider),
      id,
    );
    _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.get('bodyMeasurements'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_entries.isNotEmpty) ...[
              SizedBox(height: 200, child: _buildChart()),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <int>[7, 30, 90]
                    .map(
                      (days) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(
                            l10n.format('chartDays', {'count': '$days'}),
                          ),
                          selected: _chartDays == days,
                          onSelected: (_) => setState(() => _chartDays = days),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      l10n.get('addBodyEntry'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _weightCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.get('weightKg'),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _chestCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.get('chestCm'),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _waistCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.get('waistCm'),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _armCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.get('armCm'),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _addEntry,
                      child: Text(l10n.get('save')),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_entries.isNotEmpty) ...[
              Text(
                l10n.get('bodyHistory'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              ..._entries.map(
                (entry) => ListTile(
                  dense: true,
                  title: Text(
                    '${l10n.shortDate(entry.date)}  ${entry.weight?.toStringAsFixed(1) ?? '-'} kg',
                  ),
                  subtitle: Text(_measurementDetails(l10n, entry)),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    tooltip: l10n.get('deleteBodyEntry'),
                    onPressed: () => _deleteEntry(entry.id),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _measurementDetails(L10n l10n, BodyMeasurement entry) {
    return [
      if (entry.chest != null)
        l10n.format('measurementValue', {
          'label': l10n.get('chest'),
          'value': '${entry.chest}',
          'unit': 'cm',
        }),
      if (entry.waist != null)
        l10n.format('measurementValue', {
          'label': l10n.get('waist'),
          'value': '${entry.waist}',
          'unit': 'cm',
        }),
      if (entry.leftArm != null)
        l10n.format('measurementValue', {
          'label': l10n.get('arm'),
          'value': '${entry.leftArm}',
          'unit': 'cm',
        }),
    ].join('  ');
  }

  Widget _buildChart() {
    final filtered = _entries.reversed
        .take(_chartDays)
        .toList()
        .reversed
        .toList();
    if (filtered.isEmpty) return const SizedBox.shrink();
    final weights = filtered.map((e) => e.weight ?? 100).toList();
    final minY = weights.reduce((a, b) => a < b ? a : b) - 2;
    final maxY = weights.reduce((a, b) => a > b ? a : b) + 2;
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: filtered
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.weight ?? 0))
                .toList(),
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _chestCtrl.dispose();
    _waistCtrl.dispose();
    _armCtrl.dispose();
    super.dispose();
  }
}
