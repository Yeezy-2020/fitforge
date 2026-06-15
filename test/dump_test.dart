import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pill size check', (tester) async {
    final c = Colors.blue;
    Widget pill(String t) => GestureDetector(
      onTap: () {},
      child: Container(width: 120, height: 28, alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(width: 2, color: c), borderRadius: BorderRadius.circular(16)),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue))),
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(appBar: AppBar(title: Row(mainAxisSize: MainAxisSize.min, children: [
      pill('+ Add Workout'), const SizedBox(width: 8), const Text('Training'), const SizedBox(width: 8), pill('Today'),
    ])))));
    await tester.pumpAndSettle();

    final containers = find.byWidgetPredicate((w) => w is Container && w.child is Text && ((w.child as Text).data == '+ Add Workout' || (w.child as Text).data == 'Today'));
    final elements = containers.evaluate().toList();
    for (final e in elements) {
      final box = e.renderObject as RenderBox;
      final text = ((e.widget as Container).child as Text).data;
      print('[$text] ${box.size.width.toStringAsFixed(0)}x${box.size.height.toStringAsFixed(0)}px');
    }
    expect(elements.length, 2);
    final s1 = (elements[0].renderObject as RenderBox).size;
    final s2 = (elements[1].renderObject as RenderBox).size;
    expect(s1.width, s2.width);
    expect(s1.height, s2.height);
  });
}
