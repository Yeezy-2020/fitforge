import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pill button dimensions', (tester) async {
    // Replicate the exact AppBar structure from the calendar screen
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            leading: Padding(
              padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: const BorderSide(width: 2, color: Colors.green),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {},
                child: const Text('+ Add Workout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
              ),
            ),
            leadingWidth: 130,
            title: const Text('Training', style: TextStyle(fontSize: 16)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: const BorderSide(width: 2, color: Colors.green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () {},
                  child: const Text('Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                ),
              ),
            ],
          ),
          body: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buttons = find.byType(OutlinedButton);
    for (final el in buttons.evaluate()) {
      final btn = el.widget as OutlinedButton;
      final text = (btn.child as Text?)?.data ?? '?';
      final render = el.renderObject as RenderBox;
      final s = render.size;
      print('[$text] ${s.width.toStringAsFixed(0)}×${s.height.toStringAsFixed(0)}px  padding:H12  border:2  radius:20  font:13');
    }
  });
}
