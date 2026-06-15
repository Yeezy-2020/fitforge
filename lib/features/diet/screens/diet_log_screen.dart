import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../../../data/models/diet_log.dart';
import '../../../data/models/food.dart';
import '../../../core/localization/l10n.dart';
import '../../../data/repositories/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';

const _uuid = Uuid();

class DietLogScreen extends ConsumerStatefulWidget {
  const DietLogScreen({super.key});

  @override
  ConsumerState<DietLogScreen> createState() => _DietLogScreenState();
}

class _DietLogScreenState extends ConsumerState<DietLogScreen> {
  @override
  void initState() {
    super.initState();
    _loadCurrentDate();
  }

  Widget _todayBtn({required VoidCallback onTap, required String text}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.grey.withValues(alpha: 0.2),
        highlightColor: Colors.grey.withValues(alpha: 0.1),
        child: Container(
          width: 60, padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.grey.withValues(alpha: 0.1)),
          child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade600)),
        ),
      ),
    );
  }

  void _saveMealTemplate(List<DietLog> logs) async {
    final l10n = ref.read(l10nProvider);
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Meal Template'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Template name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.get('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: Text(l10n.get('save'))),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final userId = ref.read(currentUserIdProvider);
    final data = logs.map((l) => l.toJson()).toList();
    final json = jsonEncode({'name': name, 'items': data});
    await AppDatabase.instance.saveMealTemplate(userId, name, json);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Template "$name" saved')));
  }

  void _loadMealTemplate() async {
    final userId = ref.read(currentUserIdProvider);
    final templates = await AppDatabase.instance.getMealTemplates(userId);
    if (!mounted) return;
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No templates saved')));
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Meal Templates'),
        children: templates.map((t) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, t),
          child: Text(t),
        )).toList(),
      ),
    );
    if (selected == null) return;
    // Apply template: load the saved foods for today
    final userId2 = ref.read(currentUserIdProvider);
    final data = await AppDatabase.instance.getMealTemplateData(userId2, selected);
    if (data != null) {
      try {
        final list = jsonDecode(data) as List;
        final date = ref.read(selectedDateProvider);
        for (final item in list) {
          final log = DietLog.fromJson(item as Map<String, dynamic>);
          final newLog = DietLog(id: _uuid.v4(), userId: userId2, foodId: log.foodId, date: date, mealType: log.mealType, grams: log.grams, calories: log.calories, createdAt: DateTime.now());
          ref.read(dietCacheProvider.notifier).addLog(newLog);
          AppDatabase.instance.addDietLog(userId2, newLog);
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template applied')));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final cache = ref.watch(dietCacheProvider);
    final dateKey = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
    final logs = cache[dateKey] ?? [];
    final dietUnit = ref.watch(dietWeightUnitProvider);
    final foods = ref.watch(foodListProvider).valueOrNull ?? [];

    double totalKcal = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
    for (final log in logs) {
      totalKcal += log.calories;
      final food = foods.where((f) => f.id == log.foodId).firstOrNull;
      if (food != null) {
        final factor = log.grams / 100;
        totalProtein += food.proteinPer100g * factor;
        totalCarbs += food.carbsPer100g * factor;
        totalFat += food.fatPer100g * factor;
      }
    }

    String fmtGrams(double g) {
      if (dietUnit == DietWeightUnit.oz) return '${(g * 0.035274).toStringAsFixed(1)} oz';
      return '${g.toStringAsFixed(0)} g';
    }

    return Scaffold(
      appBar: AppBar(
        leading: logs.isNotEmpty
            ? IconButton(icon: const Icon(Icons.bookmark_add_outlined, size: 20), tooltip: 'Save', onPressed: () => _saveMealTemplate(logs))
            : null,
        leadingWidth: 48,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.chevron_left, size: 22), onPressed: () {
            final d = selectedDate.subtract(const Duration(days: 1));
            ref.read(selectedDateProvider.notifier).state = d;
            ref.read(dietCacheProvider.notifier).loadDate(d);
          }),
          Text('${DateFormat('MMM d').format(selectedDate)} ${l10n.get('diet')}', style: const TextStyle(fontSize: 16)),
          IconButton(icon: const Icon(Icons.chevron_right, size: 22), onPressed: () {
            final d = selectedDate.add(const Duration(days: 1));
            ref.read(selectedDateProvider.notifier).state = d;
            ref.read(dietCacheProvider.notifier).loadDate(d);
          }),
        ]),
        actions: [
          _todayBtn(text: 'Today', onTap: () {
            final today = DateTime.now();
            ref.read(selectedDateProvider.notifier).state = today;
            ref.read(dietCacheProvider.notifier).loadDate(today);
          }),
          IconButton(icon: const Icon(Icons.bookmark_outline, size: 20), tooltip: 'Load', onPressed: _loadMealTemplate),
        ],
      ),
      body: Column(
        children: [
          if (totalKcal > 0 || totalProtein > 0)
            _DailySummaryBar(l10n: l10n, calories: totalKcal, protein: totalProtein, carbs: totalCarbs, fat: totalFat),
          Expanded(
            child: logs.isEmpty
                ? Center(child: Text(l10n.get('noMeals'), style: const TextStyle(color: Colors.grey)))
                : _DietLogList(l10n: l10n, logs: logs, fmtGrams: fmtGrams),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFoodSheet(context, selectedDate),
        icon: const Icon(Icons.add),
        label: Text(l10n.get('addFood')),
        heroTag: 'add_food',
      ),
    );
  }

  void _showAddFoodSheet(BuildContext context, DateTime date) {
    final l10n = ref.read(l10nProvider);
    final foods = ref.read(foodListProvider).valueOrNull ?? [];
    final searchController = TextEditingController();
    MealType selectedMeal = MealType.lunch;
    String? selectedFoodId;
    final gramController = TextEditingController();
    bool gramError = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final query = searchController.text;
            final filtered = query.isEmpty
                ? foods
                : foods.where((f) => f.name.toLowerCase().contains(query.toLowerCase())).toList();

            return Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.get('addFood'), style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(hintText: l10n.get('searchFood'), prefixIcon: const Icon(Icons.search)),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<MealType>(
                    segments: [
                      ButtonSegment(value: MealType.breakfast, label: Text(l10n.get('b'))),
                      ButtonSegment(value: MealType.morningSnack, label: Text(l10n.get('ms'))),
                      ButtonSegment(value: MealType.lunch, label: Text(l10n.get('l'))),
                      ButtonSegment(value: MealType.afternoonSnack, label: Text(l10n.get('as'))),
                      ButtonSegment(value: MealType.dinner, label: Text(l10n.get('d'))),
                      ButtonSegment(value: MealType.eveningSnack, label: Text(l10n.get('es'))),
                    ],
                    selected: {selectedMeal},
                    onSelectionChanged: (v) => setSheetState(() => selectedMeal = v.first),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final food = filtered[i];
                        return ListTile(
                          selected: selectedFoodId == food.id,
                          title: Text(food.name),
                          subtitle: Text('${food.caloriesPer100g}kcal  P${food.proteinPer100g}g  C${food.carbsPer100g}g  F${food.fatPer100g}g', style: const TextStyle(fontSize: 12)),
                          onTap: () => setSheetState(() { selectedFoodId = food.id; gramError = false; }),
                        );
                      },
                    ),
                  ),
                  if (selectedFoodId != null) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: gramController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.get('weightG'),
                        hintText: 'e.g. 200',
                        errorText: gramError ? l10n.get('pleaseEnterValid') : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: gramError ? Colors.red : Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: gramError ? Colors.red : Theme.of(ctx).colorScheme.primary),
                        ),
                      ),
                      onChanged: (_) { if (gramError) setSheetState(() => gramError = false); },
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      if (selectedFoodId == null) return;
                      final grams = double.tryParse(gramController.text) ?? 0;
                      if (grams <= 0) { setSheetState(() => gramError = true); return; }
                      final food = foods.firstWhere((f) => f.id == selectedFoodId);
                      final calories = food.caloriesPer100g * (grams / 100);
                      final log = DietLog(id: _uuid.v4(), userId: ref.read(currentUserIdProvider),
                          foodId: selectedFoodId!, date: date, mealType: selectedMeal, grams: grams, calories: calories, createdAt: DateTime.now());
                      ref.read(dietCacheProvider.notifier).addLog(log);
                      AppDatabase.instance.addDietLog(ref.read(currentUserIdProvider), log);
                      try { await ref.read(supabaseProvider).addDietLog(log); } catch (_) {}
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: Text(l10n.get('add')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DailySummaryBar extends StatelessWidget {
  final L10n l10n;
  final double calories, protein, carbs, fat;
  const _DailySummaryBar({required this.l10n, required this.calories, required this.protein, required this.carbs, required this.fat});

  @override
  Widget build(BuildContext context) {
    if (calories == 0 && protein == 0 && carbs == 0 && fat == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _MiniStat(label: 'kcal', value: calories.toStringAsFixed(0), color: theme.colorScheme.primary),
        _MiniStat(label: l10n.get('protein'), value: '${protein.toStringAsFixed(0)}g', color: Colors.blue),
        _MiniStat(label: l10n.get('carbs'), value: '${carbs.toStringAsFixed(0)}g', color: Colors.orange),
        _MiniStat(label: l10n.get('fat'), value: '${fat.toStringAsFixed(0)}g', color: Colors.red),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
    ]);
  }
}

class _DietLogList extends ConsumerWidget {
  final L10n l10n;
  final List<DietLog> logs;
  final String Function(double) fmtGrams;
  const _DietLogList({required this.l10n, required this.logs, required this.fmtGrams});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (logs.isEmpty) return Center(child: Text(l10n.get('noMeals'), style: const TextStyle(color: Colors.grey)));

    final foods = ref.watch(foodListProvider).valueOrNull ?? [];
    Food? findFood(String id) => foods.where((f) => f.id == id).firstOrNull;

    final labels = {
      MealType.breakfast: l10n.get('breakfast'), MealType.morningSnack: l10n.get('morningSnack'),
      MealType.lunch: l10n.get('lunch'), MealType.afternoonSnack: l10n.get('afternoonSnack'),
      MealType.dinner: l10n.get('dinner'), MealType.eveningSnack: l10n.get('eveningSnack'),
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: MealType.values.map((meal) {
        final mealLogs = logs.where((l) => l.mealType == meal).toList();
        if (mealLogs.isEmpty) return const SizedBox.shrink();
        final totalKcal = mealLogs.fold(0.0, (sum, l) => sum + l.calories);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Row(children: [
              Text(labels[meal] ?? '', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text('${totalKcal.toStringAsFixed(0)} kcal', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ]),
          ),
          ...mealLogs.map((log) {
            final food = findFood(log.foodId);
            final foodName = food?.name ?? log.foodId;
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                title: Text(foodName),
                subtitle: Text(fmtGrams(log.grams)),
                onTap: () => _editEntry(context, ref, log, foodName),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${log.calories.toStringAsFixed(0)} kcal', style: Theme.of(context).textTheme.bodySmall),
                  GestureDetector(
                    onTap: () {
                      AppDatabase.instance.deleteDietLog(ref.read(currentUserIdProvider), log.id);
                      try { ref.read(supabaseProvider).deleteDietLog(log.id); } catch (_) {}
                      ref.read(dietCacheProvider.notifier).deleteLog(log.id, log.date);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    ),
                  ),
                ]),
              ),
            );
          }),
        ]);
      }).toList(),
    );
  }

  void _editEntry(BuildContext context, WidgetRef ref, DietLog log, String foodName) {
    final l10n = ref.read(l10nProvider);
    final gramsCtrl = TextEditingController(text: log.grams.toStringAsFixed(0));
    final foods = ref.read(foodListProvider).valueOrNull ?? [];
    final food = foods.where((f) => f.id == log.foodId).firstOrNull;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(foodName),
        content: TextField(controller: gramsCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l10n.get('weightG'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.get('cancel'))),
          FilledButton(onPressed: () async {
            final newGrams = double.tryParse(gramsCtrl.text) ?? log.grams;
            final newCalories = (food?.caloriesPer100g ?? 0) * (newGrams / 100);
            final updated = DietLog(id: log.id, userId: log.userId, foodId: log.foodId, date: log.date, mealType: log.mealType, grams: newGrams, calories: newCalories, createdAt: log.createdAt);
            AppDatabase.instance.deleteDietLog(ref.read(currentUserIdProvider), log.id);
            AppDatabase.instance.addDietLog(ref.read(currentUserIdProvider), updated);
            try { await ref.read(supabaseProvider).addDietLog(updated); } catch (_) {}
            ref.read(dietCacheProvider.notifier).updateLog(updated);
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: Text(l10n.get('save'))),
        ],
      ),
    );
  }
}
