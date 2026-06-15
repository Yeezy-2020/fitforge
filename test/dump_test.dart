import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pill check', (tester) async {
    final c = Colors.blue;
    Widget pill(String t) => GestureDetector(
      onTap: () {},
      child: Container(width: 130, padding: const EdgeInsets.symmetric(vertical: 4), alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(width: 2, color: c), borderRadius: BorderRadius.circular(16)),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue))),
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(
      appBar: AppBar(
        title: Row(children: [pill('+ Add Workout'), const Spacer(), const Text('Training'), const Spacer(), pill('Today')]),
        actions: [],
      ),
      body: const SizedBox(),
    )));
    await tester.pumpAndSettle();

    // Check pill sizes
    final containers = find.byWidgetPredicate((w) => w is Container && w.child is Text && ((w.child as Text).data == '+ Add Workout' || (w.child as Text).data == 'Today'));
    final elements = containers.evaluate().toList();
    for (final e in elements) {
      final box = e.renderObject as RenderBox;
      final text = ((e.widget as Container).child as Text).data;
      print('[Pill: $text] ${box.size.width.toStringAsFixed(0)}x${box.size.height.toStringAsFixed(0)}px');
    }

    // Check for duplicates
    final appBars = find.byType(AppBar).evaluate().toList();
    print('[AppBars: ${appBars.length}]');

    final personIcons = find.byIcon(Icons.person_outline).evaluate().toList();
    print('[person_outline icons: ${personIcons.length}]');
    expect(personIcons.length, 0, reason: 'person_outline should only be in HomeShell, not calendar');
  });
}
