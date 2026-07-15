import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/l10n.dart';
import '../../../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final locale = ref.watch(localeProvider);
    final trainUnit = ref.watch(trainingWeightUnitProvider);
    final dietUnit = ref.watch(dietWeightUnitProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.get('settings'))),
      body: ListView(
        children: [
          _header(theme, l10n.get('language')),
          RadioGroup<AppLocale>(
            groupValue: locale,
            onChanged: (value) {
              if (value != null) {
                ref.read(localeProvider.notifier).state = value;
              }
            },
            child: Column(
              children: [
                _radioTile<AppLocale>(
                  title: l10n.get('english'),
                  subtitle: l10n.get('englishNative'),
                  value: AppLocale.en,
                  onChanged: (value) =>
                      ref.read(localeProvider.notifier).state = value,
                ),
                _radioTile<AppLocale>(
                  title: l10n.get('chinese'),
                  subtitle: l10n.get('chineseNative'),
                  value: AppLocale.zh,
                  onChanged: (value) =>
                      ref.read(localeProvider.notifier).state = value,
                ),
              ],
            ),
          ),
          _header(theme, l10n.get('trainingWeightUnit')),
          RadioGroup<WeightUnit>(
            groupValue: trainUnit,
            onChanged: (value) {
              if (value != null) {
                ref.read(trainingWeightUnitProvider.notifier).state = value;
              }
            },
            child: Column(
              children: [
                _radioTile<WeightUnit>(
                  title: l10n.get('kilogram'),
                  value: WeightUnit.kg,
                  onChanged: (value) =>
                      ref.read(trainingWeightUnitProvider.notifier).state =
                          value,
                ),
                _radioTile<WeightUnit>(
                  title: l10n.get('pound'),
                  value: WeightUnit.lb,
                  onChanged: (value) =>
                      ref.read(trainingWeightUnitProvider.notifier).state =
                          value,
                ),
              ],
            ),
          ),
          _header(theme, l10n.get('dietWeightUnit')),
          RadioGroup<DietWeightUnit>(
            groupValue: dietUnit,
            onChanged: (value) {
              if (value != null) {
                ref.read(dietWeightUnitProvider.notifier).state = value;
              }
            },
            child: Column(
              children: [
                _radioTile<DietWeightUnit>(
                  title: l10n.get('gram'),
                  value: DietWeightUnit.g,
                  onChanged: (value) =>
                      ref.read(dietWeightUnitProvider.notifier).state = value,
                ),
                _radioTile<DietWeightUnit>(
                  title: l10n.get('ounce'),
                  value: DietWeightUnit.oz,
                  onChanged: (value) =>
                      ref.read(dietWeightUnitProvider.notifier).state = value,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _radioTile<T>({
    required String title,
    String? subtitle,
    required T value,
    required void Function(T) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: Radio<T>(value: value),
      onTap: () => onChanged(value),
    );
  }

  Widget _header(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
