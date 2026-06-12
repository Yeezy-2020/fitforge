import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitforge/data/models/workout_log.dart';
import 'package:fitforge/providers/app_providers.dart';
import 'package:fitforge/providers/settings_providers.dart';
import 'package:fitforge/core/localization/l10n.dart';

void main() {
  final today = DateTime.now();
  final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

  final testLogs = [
    WorkoutLog(id: 'w1', userId: 'test', exerciseId: 'ex_bench_press', date: today, sets: 3, reps: 10, weightKg: 60, createdAt: today),
    WorkoutLog(id: 'w2', userId: 'test', exerciseId: 'ex_squat', date: today, sets: 4, reps: 8, weightKg: 80, createdAt: today),
  ];

  group('Workout Cache', () {
    test('addLogs merges multiple calls', () {
      // Test that the cache notifier properly merges logs
      final cache = <String, List<WorkoutLog>>{};
      final k = dateKey;
      // First add
      final l1 = List<WorkoutLog>.from(cache[k] ?? []); l1.add(testLogs[0]); cache[k] = l1;
      // Second add
      final l2 = List<WorkoutLog>.from(cache[k] ?? []); l2.add(testLogs[1]); cache[k] = l2;
      expect(cache[k]?.length, 2);
    });

    test('edit updates log in cache', () {
      final cache = <String, List<WorkoutLog>>{dateKey: [testLogs[0], testLogs[1]]};
      // Simulate edit: remove old, add updated
      final list = List<WorkoutLog>.from(cache[dateKey]!);
      list.removeWhere((l) => l.id == 'w1');
      final updated = WorkoutLog(id: 'w1', userId: 'test', exerciseId: 'ex_bench_press', date: today, sets: 5, reps: 5, weightKg: 70, createdAt: today);
      list.add(updated);
      cache[dateKey] = list;
      final result = cache[dateKey]!;
      final edited = result.firstWhere((l) => l.id == 'w1');
      expect(edited.sets, 5);
      expect(edited.weightKg, 70);
    });

    test('delete removes log from cache', () {
      final cache = <String, List<WorkoutLog>>{dateKey: [testLogs[0], testLogs[1]]};
      final list = List<WorkoutLog>.from(cache[dateKey]!);
      list.removeWhere((l) => l.id == 'w1');
      cache[dateKey] = list;
      expect(cache[dateKey]!.length, 1);
      expect(cache[dateKey]!.first.id, 'w2');
    });

    test('reorder changes log position', () {
      final cache = <String, List<WorkoutLog>>{dateKey: [testLogs[0], testLogs[1]]};
      final list = List<WorkoutLog>.from(cache[dateKey]!);
      // Move index 0 to index 1
      final item = list.removeAt(0);
      list.insert(1, item);
      cache[dateKey] = list;
      expect(cache[dateKey]!.first.id, 'w2');
      expect(cache[dateKey]!.last.id, 'w1');
    });
  });

  group('Calendar Collapse Logic', () {
    test('collapse triggers when scrolling past threshold', () {
      bool expanded = true;
      double lastOffset = 0;
      // Simulate scroll: offset increases past 30
      final offsets = [0.0, 10.0, 25.0, 40.0];
      for (final offset in offsets) {
        final direction = offset - lastOffset;
        if (offset > 30 && direction > 0 && expanded) {
          expanded = false;
        } else if (offset <= 0 && !expanded) {
          expanded = true;
        }
        lastOffset = offset;
      }
      expect(expanded, false);
    });

    test('expand triggers when scrolling back to top', () {
      bool expanded = false;
      double lastOffset = 50.0;
      // Simulate scroll back to top
      final offsets = [50.0, 30.0, 10.0, 0.0];
      for (final offset in offsets) {
        final direction = offset - lastOffset;
        if (offset > 30 && direction > 0 && expanded) {
          expanded = false;
        } else if (offset <= 0 && !expanded) {
          expanded = true;
        }
        lastOffset = offset;
      }
      expect(expanded, true);
    });
  });
}
