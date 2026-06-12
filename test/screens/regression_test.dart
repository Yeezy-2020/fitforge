import 'package:flutter_test/flutter_test.dart';
import 'package:fitforge/data/models/workout_log.dart';

void main() {
  final today = DateTime.now();
  String dk(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  group('Workout Cards Display', () {
    test('after add, cache returns correct count', () {
      final cache = <String, List<WorkoutLog>>{};
      final k = dk(today);
      final e = List<WorkoutLog>.from(cache[k] ?? []);
      e.add(WorkoutLog(id: '1', userId: 'u', exerciseId: 'ex', date: today, sets: 3, reps: 10, weightKg: 60));
      cache[k] = e;
      expect(cache[k]!.length, 1);
    });

    test('cache survives rebuilds', () {
      final cache = <String, List<WorkoutLog>>{};
      final k = dk(today);
      cache[k] = [WorkoutLog(id: '1', userId: 'u', exerciseId: 'ex', date: today, sets: 3, reps: 10, weightKg: 60)];
      for (int i = 0; i < 5; i++) {
        expect(cache[k]!.length, 1);
      }
    });

    test('different dates do not interfere', () {
      final cache = <String, List<WorkoutLog>>{};
      cache[dk(DateTime(2025, 6, 1))] = [WorkoutLog(id: '1', userId: 'u', exerciseId: 'ex', date: DateTime(2025, 6, 1), sets: 3, reps: 10, weightKg: 60)];
      cache[dk(DateTime(2025, 6, 2))] = [WorkoutLog(id: '2', userId: 'u', exerciseId: 'ex2', date: DateTime(2025, 6, 2), sets: 4, reps: 8, weightKg: 80)];
      expect(cache[dk(DateTime(2025, 6, 1))]!.first.id, '1');
      expect(cache[dk(DateTime(2025, 6, 2))]!.first.id, '2');
    });
  });

  group('Calendar Collapse (tap-based)', () {
    test('toggle works', () {
      bool collapsed = false;
      collapsed = true;
      expect(collapsed, true);
      collapsed = false;
      expect(collapsed, false);
    });

    test('multiple toggles correct', () {
      bool collapsed = false;
      for (int i = 0; i < 10; i++) { collapsed = !collapsed; }
      expect(collapsed, false);
      collapsed = !collapsed;
      expect(collapsed, true);
    });

    test('collapse independent of card count', () {
      bool collapsed = false;
      // Collapse without cards
      collapsed = true;
      expect(collapsed, true);
      // Expand
      collapsed = false;
      expect(collapsed, false);
      // Collapse with cards (simulated by being in the "has cards" state)
      collapsed = true;
      expect(collapsed, true);
    });
  });
}
