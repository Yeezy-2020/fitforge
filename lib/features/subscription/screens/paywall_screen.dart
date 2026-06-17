import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/app_providers.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});
  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  int _selectedPlan = 1; // 0 = monthly, 1 = annual (default)

  void _handleSubscribe() {
    ref.read(isProProvider.notifier).state = true;
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('订阅成功！(演示模式)')),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(Icons.workspace_premium, size: 64, color: Colors.amber.shade600),
              const SizedBox(height: 16),
              Text(
                'Upgrade to FitForge Pro',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Unlock personalized nutrition plans',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              _SubscriptionCard(
                title: 'Monthly',
                price: '\$9.99/mo',
                isRecommended: false,
                isSelected: _selectedPlan == 0,
                onTap: () => setState(() => _selectedPlan = 0),
              ),
              const SizedBox(height: 12),
              _SubscriptionCard(
                title: 'Annual',
                price: '\$59.99/yr',
                subtitle: 'Equivalent to \$4.99/mo',
                isRecommended: true,
                isSelected: _selectedPlan == 1,
                onTap: () => setState(() => _selectedPlan = 1),
              ),
              const SizedBox(height: 24),
              const _FeatureList(),
              const Spacer(),
              FilledButton(
                onPressed: _handleSubscribe,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_selectedPlan == 0 ? 'Subscribe Monthly' : 'Subscribe Annually', style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Subscribe via App Store / Google Play',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
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
  final bool isRecommended;
  final bool isSelected;
  final VoidCallback onTap;
  const _SubscriptionCard({
    required this.title,
    required this.price,
    this.subtitle,
    required this.isRecommended,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final borderColor = isSelected ? c.primary : (isRecommended ? c.primary : Colors.transparent);
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: isSelected ? c.primaryContainer : (isRecommended ? c.primaryContainer : null),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: isSelected ? 2 : (isRecommended ? 1 : 0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Best Value', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  ],
                ]),
              ),
              Text(price, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? c.primary : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  @override
  Widget build(BuildContext context) {
    const items = [
      'Personalized macro ratios (cut/bulk)',
      'Daily macro tracking',
      'Nutrition intake progress charts',
      'Detailed food macro analysis',
      'Unlimited workout history sync',
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
