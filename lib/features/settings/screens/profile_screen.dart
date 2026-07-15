import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/localization/l10n.dart';
import '../../../data/models/user_profile.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editing = false;
  late Gender _gender;
  late FitnessGoal _goal;
  late TextEditingController _ageCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _bodyFatCtrl;

  @override
  void initState() {
    super.initState();
    final p = ref.read(userProfileProvider).valueOrNull;
    _gender = p?.gender ?? Gender.male;
    _goal = p?.goal ?? FitnessGoal.buildMuscle;
    _ageCtrl = TextEditingController(text: p?.age.toString() ?? '');
    _heightCtrl = TextEditingController(text: p?.heightCm.toString() ?? '');
    _weightCtrl = TextEditingController(text: p?.weightKg.toString() ?? '');
    _bodyFatCtrl = TextEditingController(
      text: p?.bodyFatPct?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _bodyFatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) return;
    final updated = UserProfile(
      id: profile.id,
      email: profile.email,
      gender: _gender,
      age: int.tryParse(_ageCtrl.text) ?? profile.age,
      heightCm: double.tryParse(_heightCtrl.text) ?? profile.heightCm,
      weightKg: double.tryParse(_weightCtrl.text) ?? profile.weightKg,
      goal: _goal,
      bodyFatPct: double.tryParse(_bodyFatCtrl.text) ?? profile.bodyFatPct,
      displayName: profile.displayName,
    );
    await ref.read(userProfileProvider.notifier).saveProfile(updated);
    if (mounted) setState(() => _editing = false);
  }

  Future<void> _logout() async {
    final l10n = ref.read(l10nProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.get('logOut')),
        content: Text(l10n.get('logOutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.get('logOut')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      ref.read(currentUserIdProvider.notifier).state = '';
      if (mounted) context.go('/login');
    }
  }

  Future<void> _deleteAccount() async {
    final l10n = ref.read(l10nProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.get('deleteAccount')),
        content: Text(l10n.get('accountDeletionUnavailableBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.get('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.get('ok')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.get('accountDeletionUnavailable'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final theme = Theme.of(context);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.get('account')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.get('openSettings'),
            onPressed: () => context.push('/settings'),
          ),
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: l10n.get('editProfile'),
              onPressed: () => setState(() => _editing = true),
            )
          else
            TextButton(onPressed: _save, child: Text(l10n.get('save'))),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return Center(child: Text(l10n.get('noData')));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // User info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile.email ?? l10n.get('noEmail'),
                        style: theme.textTheme.titleMedium,
                      ),
                      if (profile.displayName != null)
                        Text(
                          profile.displayName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Body data
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.get('bodyData'),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      if (_editing) ...[
                        _buildEditFields(l10n),
                      ] else ...[
                        _buildReadRow(
                          l10n.get('gender'),
                          profile.gender == Gender.male
                              ? l10n.get('male')
                              : l10n.get('female'),
                        ),
                        _buildReadRow(
                          l10n.get('age'),
                          '${profile.age} ${l10n.get('yrs')}',
                        ),
                        _buildReadRow(
                          l10n.get('height'),
                          '${profile.heightCm.toStringAsFixed(0)} cm',
                        ),
                        _buildReadRow(
                          l10n.get('weight'),
                          '${profile.weightKg.toStringAsFixed(1)} kg',
                        ),
                        _buildReadRow(
                          l10n.get('goal'),
                          _goalLabel(l10n, profile.goal),
                        ),
                        if (profile.bodyFatPct != null)
                          _buildReadRow(
                            l10n.get('bodyFat'),
                            '${profile.bodyFatPct!.toStringAsFixed(1)}%',
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              ListTile(
                leading: const Icon(Icons.straighten),
                title: Text(l10n.get('bodyMeasurements')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/body'),
              ),
              const SizedBox(height: 16),

              // Subscription
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.get('plan'),
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ref.watch(isProProvider)
                                ? l10n.get('pro')
                                : l10n.get('free'),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: ref.watch(isProProvider)
                                  ? theme.colorScheme.primary
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (!ref.watch(isProProvider))
                        FilledButton.tonal(
                          onPressed: () => context.push('/paywall'),
                          child: Text(l10n.get('upgrade')),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Logout
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: Text(l10n.get('logOut')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
              const SizedBox(height: 12),

              // Delete
              TextButton.icon(
                onPressed: _deleteAccount,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: Text(l10n.get('deleteAccount')),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.get('failedToLoad'))),
      ),
    );
  }

  Widget _buildReadRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildEditFields(L10n l10n) {
    return Column(
      children: [
        SegmentedButton<Gender>(
          segments: [
            ButtonSegment(value: Gender.male, label: Text(l10n.get('male'))),
            ButtonSegment(
              value: Gender.female,
              label: Text(l10n.get('female')),
            ),
          ],
          selected: {_gender},
          onSelectionChanged: (v) => setState(() => _gender = v.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ageCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.get('age'),
            suffixText: l10n.get('yrs'),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _heightCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.get('height'),
            suffixText: 'cm',
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _weightCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.get('weight'),
            suffixText: 'kg',
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bodyFatCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.get('bodyFat'),
            suffixText: '%',
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<FitnessGoal>(
          segments: [
            ButtonSegment(
              value: FitnessGoal.loseFat,
              label: Text(l10n.get('cut')),
            ),
            ButtonSegment(
              value: FitnessGoal.buildMuscle,
              label: Text(l10n.get('bulk')),
            ),
            ButtonSegment(
              value: FitnessGoal.maintain,
              label: Text(l10n.get('maintain')),
            ),
          ],
          selected: {_goal},
          onSelectionChanged: (v) => setState(() => _goal = v.first),
        ),
      ],
    );
  }

  String _goalLabel(L10n l10n, FitnessGoal g) {
    switch (g) {
      case FitnessGoal.loseFat:
        return l10n.get('cut');
      case FitnessGoal.buildMuscle:
        return l10n.get('bulk');
      case FitnessGoal.maintain:
        return l10n.get('maintain');
    }
  }
}
