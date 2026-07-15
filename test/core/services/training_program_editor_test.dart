import 'package:fitforge/core/services/training_program_editor.dart';
import 'package:fitforge/data/models/training_program.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime(2025, 1, 1);
  final editedAt = DateTime(2025, 2, 2, 12);

  TrainingProgram programWithDays({
    List<ProgramDay> days = const [],
    int currentDayIndex = 0,
    int activatedDayIndex = 0,
  }) {
    return TrainingProgram(
      id: 'program',
      userId: 'user',
      name: 'Program',
      days: days,
      active: true,
      currentDayIndex: currentDayIndex,
      activatedDayIndex: activatedDayIndex,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  ProgramExercise exercise(
    String id,
    String exerciseId, {
    double weight = 50,
    int sortOrder = 0,
  }) {
    return ProgramExercise(
      id: id,
      exerciseId: exerciseId,
      startingWeightKg: weight,
      sortOrder: sortOrder,
    );
  }

  TrainingProgram linkedDeloadProgram() {
    final source = ProgramDay(
      id: 'source',
      name: 'Upper',
      exercises: [exercise('source_bench', 'bench', weight: 100)],
    );
    final deload = createDeloadDayFrom(
      baseDay: source,
      id: 'deload',
      name: 'Upper deload',
      exerciseIdBuilder: (index, source) => 'deload_${source.id}',
    );
    return programWithDays(days: [source, deload]);
  }

  group('TrainingProgramEditor day transforms', () {
    test('appends and updates a day without mutating the source program', () {
      final source = programWithDays(
        days: [
          ProgramDay(
            id: 'a',
            name: 'A',
            exercises: [exercise('bench', 'bench')],
          ),
        ],
      );

      final appended = TrainingProgramEditor.appendDay(
        source,
        const ProgramDay(id: 'b', name: 'B'),
        editedAt: editedAt,
      );
      final updated = TrainingProgramEditor.updateDay(
        appended,
        dayIndex: 0,
        name: 'Rest',
        kind: DayKind.rest,
        editedAt: editedAt,
      );

      expect(source.days, hasLength(1));
      expect(appended.days.map((day) => day.id), ['a', 'b']);
      expect(updated.days.first.name, 'Rest');
      expect(updated.days.first.kind, DayKind.rest);
      expect(updated.days.first.exercises, isEmpty);
      expect(updated.updatedAt, editedAt);
    });

    test('reorder preserves active and activated day identities', () {
      final source = programWithDays(
        days: const [
          ProgramDay(id: 'a', name: 'A'),
          ProgramDay(id: 'b', name: 'B'),
          ProgramDay(id: 'c', name: 'C'),
        ],
        currentDayIndex: 1,
        activatedDayIndex: 2,
      );

      final updated = TrainingProgramEditor.reorderDay(
        source,
        oldIndex: 0,
        newIndex: 2,
        editedAt: editedAt,
      );

      expect(updated.days.map((day) => day.id), ['b', 'c', 'a']);
      expect(updated.currentDay?.id, 'b');
      expect(updated.days[updated.normalizedActivatedDayIndex].id, 'c');
      expect(updated.updatedAt, editedAt);
    });

    test('delete adjusts current and activated indexes', () {
      final source = programWithDays(
        days: const [
          ProgramDay(id: 'a', name: 'A'),
          ProgramDay(id: 'b', name: 'B'),
          ProgramDay(id: 'c', name: 'C'),
        ],
        currentDayIndex: 2,
        activatedDayIndex: 1,
      );

      final updated = TrainingProgramEditor.deleteDay(
        source,
        0,
        editedAt: editedAt,
      );

      expect(updated.days.map((day) => day.id), ['b', 'c']);
      expect(updated.currentDay?.id, 'c');
      expect(updated.days[updated.normalizedActivatedDayIndex].id, 'b');
      expect(updated.updatedAt, editedAt);
    });

    test('turning a source into rest also retires its linked deload', () {
      final linked = linkedDeloadProgram();
      final source = programWithDays(
        days: linked.days,
        currentDayIndex: 1,
        activatedDayIndex: 0,
      );

      final updated = TrainingProgramEditor.updateDay(
        source,
        dayIndex: 0,
        name: 'Recovery',
        kind: DayKind.rest,
        editedAt: editedAt,
      );

      expect(updated.days.map((day) => day.id), ['source', 'deload']);
      expect(updated.currentDayIndex, 1);
      expect(updated.currentDay?.id, 'deload');
      expect(updated.activatedDayIndex, 0);
      expect(updated.days[updated.normalizedActivatedDayIndex].id, 'source');
      expect(updated.days.first.name, 'Recovery');
      expect(updated.days.first.kind, DayKind.rest);
      expect(updated.days.first.exercises, isEmpty);

      final retiredDeload = updated.days[1];
      expect(retiredDeload.name, 'Upper deload');
      expect(retiredDeload.kind, DayKind.rest);
      expect(retiredDeload.deloadSourceDayId, isNull);
      expect(retiredDeload.deloadPreset, isNull);
      expect(retiredDeload.deloadWeightPercent, isNull);
      expect(retiredDeload.deloadSetRatio, isNull);
      expect(retiredDeload.deloadRepRatio, isNull);
      expect(retiredDeload.exercises, isEmpty);
      expect(updated.updatedAt, editedAt);

      expect(source.days.first.kind, DayKind.training);
      expect(source.days[1].kind, DayKind.deload);
      expect(source.days[1].deloadSourceDayId, 'source');
      expect(source.days[1].exercises, isNotEmpty);
    });

    test('turning a deload into rest clears its deload metadata', () {
      final source = linkedDeloadProgram();

      final updated = TrainingProgramEditor.updateDay(
        source,
        dayIndex: 1,
        name: 'Recovery',
        kind: DayKind.rest,
        editedAt: editedAt,
      );

      final restDay = updated.days[1];
      expect(restDay.id, 'deload');
      expect(restDay.name, 'Recovery');
      expect(restDay.kind, DayKind.rest);
      expect(restDay.deloadSourceDayId, isNull);
      expect(restDay.deloadPreset, isNull);
      expect(restDay.deloadWeightPercent, isNull);
      expect(restDay.deloadSetRatio, isNull);
      expect(restDay.deloadRepRatio, isNull);
      expect(restDay.exercises, isEmpty);
    });
  });

  group('TrainingProgramEditor linked deload refresh', () {
    test('adding a source exercise adds a linked deload exercise', () {
      final updated = TrainingProgramEditor.addExercise(
        linkedDeloadProgram(),
        dayIndex: 0,
        exercise: exercise('source_row', 'row', weight: 50, sortOrder: 99),
        editedAt: editedAt,
      );

      expect(updated.days.first.exercises.last.sortOrder, 1);
      final deloadExercises = updated.days[1].exercises;
      expect(deloadExercises.map((entry) => entry.exerciseId), [
        'bench',
        'row',
      ]);
      expect(deloadExercises.last.deloadSourceExerciseId, 'source_row');
      expect(deloadExercises.last.startingWeightKg, 35);
      expect(updated.updatedAt, editedAt);
    });

    test('updating a source exercise refreshes linked deload load', () {
      final source = linkedDeloadProgram();
      final updated = TrainingProgramEditor.updateExercise(
        source,
        dayIndex: 0,
        exerciseIndex: 0,
        exercise: source.days.first.exercises.first.copyWith(
          startingWeightKg: 120,
        ),
        editedAt: editedAt,
      );

      expect(updated.days[1].exercises.single.startingWeightKg, 84);
      expect(updated.days[1].exercises.single.id, 'deload_source_bench');
      expect(updated.updatedAt, editedAt);
    });

    test('deleting a source exercise refreshes deload and sort order', () {
      var source = linkedDeloadProgram();
      source = TrainingProgramEditor.addExercise(
        source,
        dayIndex: 0,
        exercise: exercise('source_row', 'row', weight: 50),
        editedAt: editedAt,
      );

      final updated = TrainingProgramEditor.deleteExercise(
        source,
        dayIndex: 0,
        exerciseIndex: 0,
        editedAt: editedAt,
      );

      expect(updated.days.first.exercises.single.id, 'source_row');
      expect(updated.days.first.exercises.single.sortOrder, 0);
      expect(updated.days[1].exercises.single.exerciseId, 'row');
      expect(
        updated.days[1].exercises.single.deloadSourceExerciseId,
        'source_row',
      );
    });
  });
}
