import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/user_profile.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  Gender _gender = Gender.male;
  final _ageController = TextEditingController(text: '25');
  final _heightController = TextEditingController(text: '175');
  final _weightController = TextEditingController(text: '70');
  FitnessGoal _goal = FitnessGoal.buildMuscle;

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    final profile = UserProfile(
      id: uid ?? 'local_user',
      gender: _gender,
      age: int.parse(_ageController.text),
      heightCm: double.parse(_heightController.text),
      weightKg: double.parse(_weightController.text),
      goal: _goal,
    );

    await ref.read(userProfileProvider.notifier).saveProfile(profile);

    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Icon(
                  Icons.fitness_center,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.get('appName'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.get('setupTitle'),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.get('gender'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SegmentedButton<Gender>(
                  segments: [
                    ButtonSegment(
                      value: Gender.male,
                      label: Text(l10n.get('male')),
                    ),
                    ButtonSegment(
                      value: Gender.female,
                      label: Text(l10n.get('female')),
                    ),
                  ],
                  selected: {_gender},
                  onSelectionChanged: (v) => setState(() => _gender = v.first),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.get('age'),
                    suffixText: l10n.get('yrs'),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return l10n.get('ageRequired');
                    }
                    if (int.tryParse(v) == null) {
                      return l10n.get('invalidNumber');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.get('height'),
                    suffixText: 'cm',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return l10n.get('heightRequired');
                    }
                    if (double.tryParse(v) == null) {
                      return l10n.get('invalidNumber');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.get('weight'),
                    suffixText: 'kg',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return l10n.get('weightRequired');
                    }
                    if (double.tryParse(v) == null) {
                      return l10n.get('invalidNumber');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.get('goal'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _save,
                  child: Text(l10n.get('getStarted')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
