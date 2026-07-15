import '../../data/models/training_program.dart';

/// Pure transformations used while editing a training program.
abstract final class TrainingProgramEditor {
  static TrainingProgram appendDay(
    TrainingProgram program,
    ProgramDay day, {
    required DateTime editedAt,
  }) {
    return program.copyWith(days: [...program.days, day], updatedAt: editedAt);
  }

  static TrainingProgram updateDay(
    TrainingProgram program, {
    required int dayIndex,
    required String name,
    required DayKind kind,
    required DateTime editedAt,
  }) {
    final day = program.days[dayIndex];
    final days = [...program.days];
    days[dayIndex] = kind == DayKind.rest
        ? _asRestDay(day, name: name)
        : day.copyWith(name: name, kind: kind);

    if (kind == DayKind.rest) {
      for (var index = 0; index < days.length; index += 1) {
        if (index != dayIndex && days[index].deloadSourceDayId == day.id) {
          days[index] = _asRestDay(days[index]);
        }
      }
    }
    return program.copyWith(days: days, updatedAt: editedAt);
  }

  static ProgramDay _asRestDay(ProgramDay day, {String? name}) =>
      ProgramDay(id: day.id, name: name ?? day.name, kind: DayKind.rest);

  static TrainingProgram deleteDay(
    TrainingProgram program,
    int dayIndex, {
    required DateTime editedAt,
  }) {
    return program.removeDayAt(dayIndex, removedAt: editedAt);
  }

  static TrainingProgram reorderDay(
    TrainingProgram program, {
    required int oldIndex,
    required int newIndex,
    required DateTime editedAt,
  }) {
    return program.reorderDay(oldIndex, newIndex, reorderedAt: editedAt);
  }

  static TrainingProgram insertDay(
    TrainingProgram program, {
    required int dayIndex,
    required ProgramDay day,
    required DateTime editedAt,
  }) {
    return program.insertDayAt(dayIndex, day, insertedAt: editedAt);
  }

  static TrainingProgram addExercise(
    TrainingProgram program, {
    required int dayIndex,
    required ProgramExercise exercise,
    required DateTime editedAt,
  }) {
    final day = program.days[dayIndex];
    final configured = exercise.copyWith(sortOrder: day.exercises.length);
    return _replaceDayExercises(
      program,
      dayIndex: dayIndex,
      exercises: [...day.exercises, configured],
      editedAt: editedAt,
    );
  }

  static TrainingProgram updateExercise(
    TrainingProgram program, {
    required int dayIndex,
    required int exerciseIndex,
    required ProgramExercise exercise,
    required DateTime editedAt,
  }) {
    final day = program.days[dayIndex];
    final exercises = [...day.exercises];
    exercises[exerciseIndex] = exercise;
    return _replaceDayExercises(
      program,
      dayIndex: dayIndex,
      exercises: exercises,
      editedAt: editedAt,
    );
  }

  static TrainingProgram deleteExercise(
    TrainingProgram program, {
    required int dayIndex,
    required int exerciseIndex,
    required DateTime editedAt,
  }) {
    final exercises = [...program.days[dayIndex].exercises]
      ..removeAt(exerciseIndex);
    return _replaceDayExercises(
      program,
      dayIndex: dayIndex,
      exercises: [
        for (var i = 0; i < exercises.length; i++)
          exercises[i].copyWith(sortOrder: i),
      ],
      editedAt: editedAt,
    );
  }

  static TrainingProgram _replaceDayExercises(
    TrainingProgram program, {
    required int dayIndex,
    required List<ProgramExercise> exercises,
    required DateTime editedAt,
  }) {
    final day = program.days[dayIndex];
    final days = [...program.days];
    days[dayIndex] = day.copyWith(exercises: exercises);
    var updated = program.copyWith(days: days, updatedAt: editedAt);
    if (day.kind == DayKind.training) {
      updated = updated.refreshLinkedDeloadsForDay(
        day.id,
        refreshedAt: editedAt,
      );
    }
    return updated;
  }
}
