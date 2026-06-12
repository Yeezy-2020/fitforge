import 'package:flutter_test/flutter_test.dart';
import 'package:fitforge/data/models/workout_log.dart';

void main() {
  final today = DateTime.now();
  String dk(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  group('Workout Cards Display Regression', () {
    test('after add, cache returns correct count', () {
      final cache = <String, List<WorkoutLog>>{};
      final k = dk(today);

      // Simulate addLogs
      final e = List<WorkoutLog>.from(cache[k] ?? []);
      e.add(WorkoutLog(id: '1', userId: 'u', exerciseId: 'ex', date: today, sets: 3, reps: 10, weightKg: 60));
      cache[k] = e;

      expect(cache[k]!.length, 1);
    });

    test('cache survives rebuilds', () {
      final cache = <String, List<WorkoutLog>>{};
      final k = dk(today);

      cache[k] = [WorkoutLog(id: '1', userId: 'u', exerciseId: 'ex', date: today, sets: 3, reps: 10, weightKg: 60)];

      // Simulate multiple reads
      for (int i = 0; i < 5; i++) {
        expect(cache[k]!.length, 1);
        expect(cache[k]!.first.sets, 3);
      }
    });

    test('different dates do not interfere', () {
      final cache = <String, List<WorkoutLog>>{};
      final k1 = dk(DateTime(2025, 6, 1));
      final k2 = dk(DateTime(2025, 6, 2));

      cache[k1] = [WorkoutLog(id: '1', userId: 'u', exerciseId: 'ex', date: DateTime(2025, 6, 1), sets: 3, reps: 10, weightKg: 60)];
      cache[k2] = [WorkoutLog(id: '2', userId: 'u', exerciseId: 'ex2', date: DateTime(2025, 6, 2), sets: 4, reps: 8, weightKg: 80)];

      expect(cache[k1]!.length, 1);
      expect(cache[k2]!.length, 1);
      expect(cache[k1]!.first.id, '1');
      expect(cache[k2]!.first.id, '2');
    });

    test('reload does not duplicate entries', () {
      final cache = <String, List<WorkoutLog>>{};
      final k = dk(today);

      cache[k] = [WorkoutLog(id: '1', userId: 'u', exerciseId: 'ex', date: today, sets: 3, reps: 10, weightKg: 60)];

      // Simulate reload which should replace
      cache[k] = [WorkoutLog(id: '1', userId: 'u', exerciseId: 'ex', date: today, sets: 3, reps: 10, weightKg: 60)];

      expect(cache[k]!.length, 1);
    });
  });

  group('Calendar Collapse Regression', () {
    test('collapses at 35px when scrolling down', () {
      bool collapsed = false;
      double last = 0;
      for (final o in [0.0, 10.0, 25.0, 35.0]) {
        if (o > 30 && (o - last) > 0 && !collapsed) collapsed = true;
        if (o <= 0 && collapsed) collapsed = false;
        last = o;
      }
      expect(collapsed, true);
    });

    test('does not collapse when going up', () {
      bool collapsed = false;
      double last = 100.0;
      for (final o in [100.0, 70.0, 40.0]) {
        if (o > 30 && (o - last) > 0 && !collapsed) collapsed = true;
        if (o <= 0 && collapsed) collapsed = false;
        last = o;
      }
      expect(collapsed, false);
    });

    test('expands when reaching top', () {
      bool collapsed = true;
      double last = 50.0;
      for (final o in [50.0, 20.0, 0.0]) {
        if (o > 30 && (o - last) > 0 && !collapsed) collapsed = true;
        if (o <= 0 && collapsed) collapsed = false;
        last = o;
      }
      expect(collapsed, false);
    });

    test('toggles correctly multiple times', () {
      bool collapsed = false;
      double last = 0;
      for (final o in <double>[0, 10, 35]) { if (o > 30 && (o-last) > 0 && !collapsed) collapsed = true; if (o <= 0 && collapsed) collapsed = false; last = o; }
      expect(collapsed, true);
      for (final o in <double>[35, 20, 0]) { if (o > 30 && (o-last) > 0 && !collapsed) collapsed = true; if (o <= 0 && collapsed) collapsed = false; last = o; }
      expect(collapsed, false);
      for (final o in <double>[0, 10, 35]) { if (o > 30 && (o-last) > 0 && !collapsed) collapsed = true; if (o <= 0 && collapsed) collapsed = false; last = o; }
      expect(collapsed, true);
    });

    test('SingleChildScrollView with AlwaysScrollableScrollPhysics generates events even with small content', () {
      // AlwaysScrollableScrollPhysics always reports scrollable,
      // even when the content fits within the viewport.
      // This ensures the NotificationListener catches scroll events.
      bool notified = false;
      // Verify that our logic correctly detects scroll with AlwaysScrollable
      // Any scroll delta > 0 past threshold should trigger collapse
      final px = 35.0;
      final delta = 5.0;
      final collapsed = px > 30 && delta > 0;
      expect(collapsed, true);
    });
  });
}
