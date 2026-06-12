import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    _bodyFatCtrl = TextEditingController(text: p?.bodyFatPct?.toStringAsFixed(1) ?? '');
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log Out')),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('This action is irreversible. All your data will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/login');
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
            onPressed: () => context.push('/settings'),
          ),
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(l10n.get('save')),
            ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('暂无数据'));
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
                      profile.email ?? 'No email',
                      style: theme.textTheme.titleMedium,
                      ),
                      if (profile.displayName != null)
                        Text(
                          profile.displayName!,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
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
                      Text('Body Data', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 12),
                      if (_editing) ...[
                        _buildEditFields(theme),
                      ] else ...[
                        _buildReadRow('Gender', profile.gender == Gender.male ? 'Male' : 'Female'),
                        _buildReadRow('Age', '${profile.age} yrs'),
                        _buildReadRow('Height', '${profile.heightCm.toStringAsFixed(0)} cm'),
                        _buildReadRow('Weight', '${profile.weightKg.toStringAsFixed(1)} kg'),
                        _buildReadRow('Goal', _goalLabel(profile.goal)),
                        if (profile.bodyFatPct != null)
                          _buildReadRow('Body Fat', '${profile.bodyFatPct!.toStringAsFixed(1)}%'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              ListTile(
                leading: const Icon(Icons.straighten),
                title: const Text('Body Measurements'),
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
                          Text('Plan', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Text(
                            ref.watch(isProProvider) ? 'FitForge Pro' : 'Free',
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
                          child: const Text('Upgrade'),
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
                label: const Text('Log Out'),
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
                label: const Text('Delete Account'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, e) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Widget _buildReadRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildEditFields(ThemeData theme) {
    return Column(
      children: [
        SegmentedButton<Gender>(
          segments: const [
            ButtonSegment(value: Gender.male, label: Text('Male')),
            ButtonSegment(value: Gender.female, label: Text('Female')),
          ],
          selected: {_gender},
          onSelectionChanged: (v) => setState(() => _gender = v.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ageCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Age', suffixText: 'yrs', isDense: true),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _heightCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Height', suffixText: 'cm', isDense: true),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _weightCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Weight', suffixText: 'kg', isDense: true),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bodyFatCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Body Fat', suffixText: '%', isDense: true),
        ),
        const SizedBox(height: 12),
        SegmentedButton<FitnessGoal>(
          segments: const [
            ButtonSegment(value: FitnessGoal.loseFat, label: Text('Cut')),
            ButtonSegment(value: FitnessGoal.buildMuscle, label: Text('Bulk')),
            ButtonSegment(value: FitnessGoal.maintain, label: Text('Maintain')),
          ],
          selected: {_goal},
          onSelectionChanged: (v) => setState(() => _goal = v.first),
        ),
      ],
    );
  }

  String _goalLabel(FitnessGoal g) {
    switch (g) {
      case FitnessGoal.loseFat: return 'Cut';
      case FitnessGoal.buildMuscle: return 'Bulk';
      case FitnessGoal.maintain: return 'Maintain';
    }
  }
}
