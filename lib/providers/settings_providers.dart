import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/localization/l10n.dart';

final localeProvider = StateProvider<AppLocale>((ref) => AppLocale.en);

final l10nProvider = Provider<L10n>((ref) {
  final locale = ref.watch(localeProvider);
  return L10n(locale);
});

enum WeightUnit { kg, lb }

final trainingWeightUnitProvider = StateProvider<WeightUnit>((ref) => WeightUnit.kg);

enum DietWeightUnit { g, oz }

final dietWeightUnitProvider = StateProvider<DietWeightUnit>((ref) => DietWeightUnit.g);

const kgToLb = 2.20462;
const gToOz = 0.035274;

String formatTrainingWeight(double kg, WeightUnit unit) {
  if (unit == WeightUnit.lb) {
    return '${(kg * kgToLb).toStringAsFixed(1)} lb';
  }
  return '${kg.toStringAsFixed(1)} kg';
}

String formatDietWeight(double grams, DietWeightUnit unit) {
  if (unit == DietWeightUnit.oz) {
    return '${(grams * gToOz).toStringAsFixed(1)} oz';
  }
  return '${grams.toStringAsFixed(0)} g';
}
