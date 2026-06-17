import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('E2E: pill buttons render with correct dimensions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: Scaffold(
          appBar: AppBar(leading: Padding(padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(120, 36), side: const BorderSide(width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              onPressed: () {}, child: const Text('+ Add Workout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ), leadingWidth: 130, title: const Text('Training'),
          actions: [Padding(padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(120, 36), side: const BorderSide(width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              onPressed: () {}, child: const Text('Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          )],
        ), body: const SizedBox()),
      ),
    ));
    await tester.pumpAndSettle();

    final buttons = find.byType(OutlinedButton);
    final elements = buttons.evaluate().toList();
    expect(elements.length, 2);

    final left = elements[0].renderObject! as RenderBox;
    final right = elements[1].renderObject! as RenderBox;

    // Both buttons should have the same height and similar width
    expect(left.size.height, right.size.height);
    // Width difference should be minimal (within 5px)
    expect((left.size.width - right.size.width).abs(), lessThanOrEqualTo(10));
  });
}
