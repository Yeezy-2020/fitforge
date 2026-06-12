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
          _radioTile<AppLocale>(title: l10n.get('english'), subtitle: 'English', value: AppLocale.en, groupValue: locale, onChanged: (v) => ref.read(localeProvider.notifier).state = v),
          _radioTile<AppLocale>(title: l10n.get('chinese'), subtitle: '中文', value: AppLocale.zh, groupValue: locale, onChanged: (v) => ref.read(localeProvider.notifier).state = v),
          _header(theme, l10n.get('trainingWeightUnit')),
          _radioTile<WeightUnit>(title: 'Kilogram (kg)', value: WeightUnit.kg, groupValue: trainUnit, onChanged: (v) => ref.read(trainingWeightUnitProvider.notifier).state = v),
          _radioTile<WeightUnit>(title: 'Pound (lb)', value: WeightUnit.lb, groupValue: trainUnit, onChanged: (v) => ref.read(trainingWeightUnitProvider.notifier).state = v),
          _header(theme, l10n.get('dietWeightUnit')),
          _radioTile<DietWeightUnit>(title: 'Gram (g)', value: DietWeightUnit.g, groupValue: dietUnit, onChanged: (v) => ref.read(dietWeightUnitProvider.notifier).state = v),
          _radioTile<DietWeightUnit>(title: 'Ounce (oz)', value: DietWeightUnit.oz, groupValue: dietUnit, onChanged: (v) => ref.read(dietWeightUnitProvider.notifier).state = v),
        ],
      ),
    );
  }

  Widget _radioTile<T>({
    required String title,
    String? subtitle,
    required T value,
    required T groupValue,
    required void Function(T) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: Radio<T>(value: value, groupValue: groupValue, onChanged: (v) { if (v != null) onChanged(v); }),
      onTap: () => onChanged(value),
    );
  }

  Widget _header(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}
