import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/settings_providers.dart';
import '../workout/screens/workout_calendar_screen.dart';
import '../diet/screens/diet_log_screen.dart';
import '../nutrition_plan/screens/nutrition_plan_screen.dart';
import '../settings/screens/profile_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  final Widget child;
  final List<Widget>? pages;

  const HomeShell({super.key, required this.child, this.pages})
    : assert(pages == null || pages.length == 4);

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final _pageController = PageController();
  int _currentIndex = 0;
  int? _pendingTabIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      final isPro = ref.read(isProProvider);
      if (!isPro) {
        context.push('/paywall');
        return;
      }
    }
    setState(() {
      _currentIndex = index;
      _pendingTabIndex = index;
    });
    _pageController
        .animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        )
        .whenComplete(() {
          if (mounted && _pendingTabIndex == index) {
            setState(() => _pendingTabIndex = null);
          }
        });
  }

  void _onPageChanged(int index) {
    if (_pendingTabIndex != null && index != _pendingTabIndex) {
      return;
    }
    if (index == 2 && !ref.read(isProProvider)) {
      context.push('/paywall');
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    setState(() {
      _currentIndex = index;
      if (_pendingTabIndex == index) _pendingTabIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.fitness_center_outlined),
        selectedIcon: const Icon(Icons.fitness_center),
        label: l10n.get('training'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.restaurant_outlined),
        selectedIcon: const Icon(Icons.restaurant),
        label: l10n.get('diet'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.pie_chart_outline),
        selectedIcon: const Icon(Icons.pie_chart),
        label: l10n.get('nutrition'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: l10n.get('account'),
      ),
    ];
    final pages =
        widget.pages ??
        const [
          WorkoutCalendarScreen(),
          DietLogScreen(),
          NutritionPlanScreen(),
          ProfileScreen(),
        ];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        destinations: destinations,
      ),
    );
  }
}
