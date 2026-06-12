import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../data/models/body_measurement.dart';
import '../../../data/models/user_profile.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';

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

  void _loadEntries() {
    final userId = ref.read(currentUserIdProvider);
    setState(() {
      _entries = _entries;
    });
  }

  void _addEntry() {
    final w = double.tryParse(_weightCtrl.text);
    if (w == null) return;
    final entry = BodyMeasurement(
      id: DateTime.now().millisecondsSinceEpoch.toString(), userId: ref.read(currentUserIdProvider), date: DateTime.now(),
      weight: w, chest: double.tryParse(_chestCtrl.text), waist: double.tryParse(_waistCtrl.text),
      leftArm: double.tryParse(_armCtrl.text),
    );
    setState(() { _entries.insert(0, entry); _weightCtrl.clear(); _chestCtrl.clear(); _waistCtrl.clear(); _armCtrl.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Body')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        if (_entries.isNotEmpty) ...[
          SizedBox(height: 200, child: _buildChart()),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: <int>[7, 30, 90].map((d) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(label: Text('${d}d'), selected: _chartDays == d, onSelected: (_) => setState(() => _chartDays = d)),
          )).toList())),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Text('Add Entry', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _weightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight (kg)', isDense: true))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _chestCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Chest (cm)', isDense: true))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _waistCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Waist (cm)', isDense: true))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _armCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Arm (cm)', isDense: true))),
            ]),
            const SizedBox(height: 12),
            FilledButton(onPressed: _addEntry, child: const Text('Save')),
          ])),
        ),
        const SizedBox(height: 16),
        if (_entries.isNotEmpty) ...[
          Text('History', style: Theme.of(context).textTheme.titleSmall),
          ..._entries.map<Widget>((e) => ListTile(
            dense: true,
            title: Text('${DateFormat('MMM d').format(e.date)}  ${e.weight}kg'),
            subtitle: Text([if (e.chest != null) 'Chest: ${e.chest}cm', if (e.waist != null) 'Waist: ${e.waist}cm', if (e.leftArm != null) 'Arm: ${e.leftArm}cm'].where((s) => s.isNotEmpty).join('  ')),
          )),
        ],
      ])),
    );
  }

  Widget _buildChart() {
    final filtered = _entries.reversed.take(_chartDays).toList().reversed.toList();
    if (filtered.isEmpty) return const SizedBox.shrink();
    final minY = filtered.map((e) => e.weight ?? 100).reduce((a, b) => a < b ? a : b) - 2;
    final maxY = filtered.map((e) => e.weight ?? 0).reduce((a, b) => a > b ? a : b) + 2;
    return LineChart(LineChartData(
      minY: minY, maxY: maxY,
      gridData: FlGridData(show: true, drawVerticalLine: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [LineChartBarData(spots: filtered.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.weight ?? 0)).toList(), isCurved: true, color: Theme.of(context).colorScheme.primary, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)))],
    ));
  }

  @override
  void dispose() { _weightCtrl.dispose(); _chestCtrl.dispose(); _waistCtrl.dispose(); _armCtrl.dispose(); super.dispose(); }
}
