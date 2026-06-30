import 'package:fitforge/features/home/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

const _testPages = [
  SizedBox(key: Key('training-page')),
  SizedBox(key: Key('diet-page')),
  SizedBox(key: Key('nutrition-page')),
  SizedBox(key: Key('account-page')),
];

void main() {
  testWidgets('HomeShell exposes account as fourth bottom tab', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: HomeShell(pages: _testPages, child: const SizedBox.shrink()),
        isPro: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('Training'), findsWidgets);
    expect(find.text('Diet'), findsWidgets);
    expect(find.text('Nutrition'), findsWidgets);
    expect(find.text('Account'), findsWidgets);
  });

  testWidgets('HomeShell selects the account tab from bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: HomeShell(pages: _testPages, child: const SizedBox.shrink()),
        isPro: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Account').last);
    await tester.pumpAndSettle();

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 3);
  });

  testWidgets('HomeShell no longer renders account in a top app bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: HomeShell(pages: _testPages, child: const SizedBox.shrink()),
        isPro: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FitForge'), findsNothing);
    expect(find.byType(AppBar), findsNothing);
  });
}
