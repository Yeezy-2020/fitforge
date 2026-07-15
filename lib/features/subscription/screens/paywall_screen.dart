import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/l10n.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});
  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  int _selectedPlan = 1; // 0 = monthly, 1 = annual (default)

  Future<void> _handleSubscribe() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = ref.read(l10nProvider);
    await ref.read(isProProvider.notifier).setPro(true);
    if (!mounted) return;
    context.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.get('subscriptionDemoSuccess'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.get('close'),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(
                Icons.workspace_premium,
                size: 64,
                color: Colors.amber.shade600,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.get('upgradePro'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.get('unlockNutrition'),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              _SubscriptionCard(
                title: l10n.get('monthly'),
                price: l10n.get('monthlyPrice'),
                recommendedLabel: l10n.get('bestValue'),
                isRecommended: false,
                isSelected: _selectedPlan == 0,
                onTap: () => setState(() => _selectedPlan = 0),
              ),
              const SizedBox(height: 12),
              _SubscriptionCard(
                title: l10n.get('annual'),
                price: l10n.get('annualPrice'),
                subtitle: l10n.get('annualEquivalent'),
                recommendedLabel: l10n.get('bestValue'),
                isRecommended: true,
                isSelected: _selectedPlan == 1,
                onTap: () => setState(() => _selectedPlan = 1),
              ),
              const SizedBox(height: 24),
              _FeatureList(l10n: l10n),
              const Spacer(),
              FilledButton(
                onPressed: _handleSubscribe,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _selectedPlan == 0
                        ? l10n.get('subscribeMonthly')
                        : l10n.get('subscribeAnnually'),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.get('subscribeVia'),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final String title;
  final String price;
  final String? subtitle;
  final String recommendedLabel;
  final bool isRecommended;
  final bool isSelected;
  final VoidCallback onTap;
  const _SubscriptionCard({
    required this.title,
    required this.price,
    this.subtitle,
    required this.recommendedLabel,
    required this.isRecommended,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final borderColor = isSelected ? c.primary : Colors.transparent;
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: isSelected ? c.primaryContainer : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: isSelected ? 2 : 0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    recommendedLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                price,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? c.primary : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  final L10n l10n;

  const _FeatureList({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final items = [
      l10n.get('proFeature1'),
      l10n.get('proFeature2'),
      l10n.get('proFeature3'),
      l10n.get('proFeature4'),
      l10n.get('proFeature5'),
    ];

    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(item, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        );
      }).toList(),
    );
  }
}
