import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File(
      'supabase/migrations/202607130001_training_sync_foundation.sql',
    ).readAsStringSync();
  });

  test('JSON documents require object identity and non-null comparisons', () {
    expect(migration, contains("jsonb_typeof(document) = 'object'"));
    expect(migration, contains("document ? 'id'"));
    expect(migration, contains("document ? 'userId'"));
    expect(migration, contains("(document ->> 'id' = id) is true"));
    expect(
      migration,
      contains("(document ->> 'userId' = user_id::text) is true"),
    );
  });

  test('every synchronized table has an owner RLS guard', () {
    for (final table in [
      'workout_logs',
      'training_programs',
      'progression_rules',
      'workout_set_logs',
    ]) {
      expect(
        migration,
        contains('alter table public.$table enable row level security;'),
      );
      expect(migration, contains('fitforge_${table}_owner_guard'));
    }
    expect(migration, contains('as restrictive'));
    expect(migration, contains('revoke all on table public.workout_logs'));
  });

  test('set rows require a complete parent-matching unique slot', () {
    expect(migration, contains('program_day_id text not null'));
    expect(migration, contains('workout_set_logs_workout_slot_fkey'));
    expect(migration, contains('unique (user_id, workout_log_id, set_index)'));
    expect(migration, contains('workout_logs_owner_slot_uidx'));
  });

  test('rule exercise identity is present and unique', () {
    expect(migration, contains("document ? 'exerciseId'"));
    expect(migration, contains('progression_rules_user_exercise_uidx'));
  });
}
