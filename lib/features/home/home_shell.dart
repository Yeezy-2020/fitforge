import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';
import '../workout/screens/workout_calendar_screen.dart';
import '../diet/screens/diet_log_screen.dart';
import '../nutrition_plan/screens/nutrition_plan_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      final isPro = ref.read(isProProvider);
      if (!isPro) { context.push('/paywall'); return; }
    }
    setState(() => _currentIndex = index);
    _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final destinations = [
      NavigationDestination(icon: const Icon(Icons.fitness_center_outlined), selectedIcon: const Icon(Icons.fitness_center), label: l10n.get('training')),
      NavigationDestination(icon: const Icon(Icons.restaurant_outlined), selectedIcon: const Icon(Icons.restaurant), label: l10n.get('diet')),
      NavigationDestination(icon: const Icon(Icons.pie_chart_outline), selectedIcon: const Icon(Icons.pie_chart), label: l10n.get('nutrition')),
    ];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: const [
          WorkoutCalendarScreen(),
          DietLogScreen(),
          NutritionPlanScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(selectedIndex: _currentIndex, onDestinationSelected: _onTabTapped, destinations: destinations),
    );
  }
}
