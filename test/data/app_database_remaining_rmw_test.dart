import 'package:fitforge/data/models/body_measurement.dart';
import 'package:fitforge/data/models/diet_log.dart';
import 'package:fitforge/data/models/exercise.dart';
import 'package:fitforge/data/models/food.dart';
import 'package:fitforge/data/models/workout_log.dart';
import 'package:fitforge/data/models/workout_template.dart';
import 'package:fitforge/data/repositories/app_database.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final database = AppDatabase.instance;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('remaining same-key read-modify-write operations', () {
    test(
      'exercise adds retain defaults and every concurrent custom item',
      () async {
        const userId = 'exercise-add-owner';
        final defaultIds = (await database.getExercises(
          userId,
        )).map((exercise) => exercise.id).toSet();

        await Future.wait(
          List.generate(
            16,
            (index) => database.addExercise(userId, _exercise('custom-$index')),
          ),
        );

        final exercises = await database.getExercises(userId);
        expect(exercises, hasLength(defaultIds.length + 16));
        expect(exercises.map((exercise) => exercise.id).toSet(), {
          ...defaultIds,
          ...List.generate(16, (index) => 'custom-$index'),
        });
      },
    );

    test(
      'exercise replace and later adds execute in invocation order',
      () async {
        const userId = 'exercise-replace-owner';

        await Future.wait([
          database.saveExercises(userId, [_exercise('replacement')]),
          ...List.generate(
            8,
            (index) => database.addExercise(userId, _exercise('added-$index')),
          ),
        ]);

        expect(
          (await database.getExercises(userId)).map((exercise) => exercise.id),
          ['replacement', ...List.generate(8, (index) => 'added-$index')],
        );
      },
    );

    test('diet add, delete, and sync merge lose no updates', () async {
      const userId = 'diet-log-owner';
      await database.addDietLog(userId, _diet(userId, 'delete-me'));

      await Future.wait([
        database.deleteDietLog(userId, 'delete-me'),
        ...List.generate(
          12,
          (index) => database.addDietLog(userId, _diet(userId, 'add-$index')),
        ),
        ...List.generate(
          8,
          (index) =>
              database.saveDietLogs(userId, [_diet(userId, 'sync-$index')]),
        ),
      ]);

      final logs = await database.getDietLogs(userId, _date);
      expect(logs, hasLength(20));
      expect(logs.map((log) => log.id), isNot(contains('delete-me')));
      expect(logs.map((log) => log.id).toSet(), hasLength(20));
    });

    test(
      'food adds retain defaults and every concurrent custom food',
      () async {
        const userId = 'food-owner';
        final defaultIds = (await database.getFoods(
          userId,
        )).map((food) => food.id).toSet();

        await Future.wait(
          List.generate(
            14,
            (index) => database.addFood(userId, _food('food-$index')),
          ),
        );

        final foods = await database.getFoods(userId);
        expect(foods, hasLength(defaultIds.length + 14));
        expect(foods.map((food) => food.id).toSet(), {
          ...defaultIds,
          ...List.generate(14, (index) => 'food-$index'),
        });
      },
    );

    test('unsynced workouts serialize add, remove, and clear', () async {
      const userId = 'unsynced-workout-owner';
      await database.addUnsyncedWorkout(userId, _workout(userId, 'delete-me'));

      await Future.wait([
        database.removeUnsyncedWorkoutLogs(userId, {'delete-me'}),
        ...List.generate(
          12,
          (index) => database.addUnsyncedWorkout(
            userId,
            _workout(userId, 'add-$index'),
          ),
        ),
      ]);

      var logs = await database.getUnsyncedWorkoutLogs(userId);
      expect(logs.map((log) => log.id).toSet(), {
        ...List.generate(12, (index) => 'add-$index'),
      });

      await Future.wait([
        database.clearUnsyncedWorkouts(userId),
        database.addUnsyncedWorkout(userId, _workout(userId, 'after-clear')),
      ]);
      logs = await database.getUnsyncedWorkoutLogs(userId);
      expect(logs.map((log) => log.id), ['after-clear']);
    });

    test('unsynced diets serialize upserts and removes', () async {
      const userId = 'unsynced-diet-owner';
      await database.addUnsyncedDiet(userId, _diet(userId, 'delete-me'));

      await Future.wait([
        database.removeUnsyncedDietLogs(userId, {'delete-me'}),
        ...List.generate(
          15,
          (index) =>
              database.addUnsyncedDiet(userId, _diet(userId, 'diet-$index')),
        ),
      ]);

      final logs = await database.getUnsyncedDietLogs(userId);
      expect(logs.map((log) => log.id).toSet(), {
        ...List.generate(15, (index) => 'diet-$index'),
      });
    });

    test('pending delete queues retain unique adds around removals', () async {
      const userId = 'pending-delete-owner';
      await database.addPendingWorkoutDelete(userId, 'old-workout');
      await database.addPendingDietDelete(userId, 'old-diet');

      await Future.wait([
        database.removePendingWorkoutDeletes(userId, {'old-workout'}),
        database.removePendingDietDeletes(userId, {'old-diet'}),
        ...List.generate(
          12,
          (index) =>
              database.addPendingWorkoutDelete(userId, 'workout-${index % 6}'),
        ),
        ...List.generate(
          10,
          (index) => database.addPendingDietDelete(userId, 'diet-${index % 5}'),
        ),
      ]);

      expect((await database.getPendingWorkoutDeletes(userId)).toSet(), {
        ...List.generate(6, (index) => 'workout-$index'),
      });
      expect((await database.getPendingDietDeletes(userId)).toSet(), {
        ...List.generate(5, (index) => 'diet-$index'),
      });
    });

    test('workout template saves and deletes lose no updates', () async {
      const userId = 'workout-template-owner';
      await database.saveTemplate(userId, _template('delete-me'));

      await Future.wait([
        database.deleteTemplate(userId, 'delete-me'),
        ...List.generate(
          18,
          (index) =>
              database.saveTemplate(userId, _template('template-$index')),
        ),
      ]);

      final templates = await database.getTemplates(userId);
      expect(templates, hasLength(18));
      expect(templates.map((template) => template.id).toSet(), {
        ...List.generate(18, (index) => 'template-$index'),
      });
    });

    test('meal template saves retain invocation order and data', () async {
      const userId = 'meal-template-owner';

      await Future.wait(
        List.generate(
          15,
          (index) => database.saveMealTemplate(
            userId,
            'meal-$index',
            'payload-$index',
          ),
        ),
      );

      expect(
        await database.getMealTemplates(userId),
        List.generate(15, (index) => 'meal-$index'),
      );
      for (var index = 0; index < 15; index++) {
        expect(
          await database.getMealTemplateData(userId, 'meal-$index'),
          'payload-$index',
        );
      }
    });

    test('body measurement saves and deletes lose no updates', () async {
      const userId = 'body-owner';
      await database.saveBodyMeasurement(
        userId,
        _measurement(userId, 'delete-me'),
      );

      await Future.wait([
        database.deleteBodyMeasurement(userId, 'delete-me'),
        ...List.generate(
          16,
          (index) => database.saveBodyMeasurement(
            userId,
            _measurement(userId, 'measurement-$index'),
          ),
        ),
      ]);

      final entries = await database.getBodyMeasurements(userId);
      expect(entries, hasLength(16));
      expect(entries.map((entry) => entry.id).toSet(), {
        ...List.generate(16, (index) => 'measurement-$index'),
      });
    });
  });

  test(
    'concurrent mutations stay isolated by full user and storage key',
    () async {
      await Future.wait([
        ...List.generate(
          10,
          (index) =>
              database.addExercise('user-a', _exercise('a-exercise-$index')),
        ),
        ...List.generate(
          7,
          (index) =>
              database.addExercise('user-b', _exercise('b-exercise-$index')),
        ),
        ...List.generate(
          9,
          (index) => database.addFood('user-a', _food('a-food-$index')),
        ),
      ]);

      final userAExercises = (await database.getExercises(
        'user-a',
      )).map((exercise) => exercise.id).toSet();
      final userBExercises = (await database.getExercises(
        'user-b',
      )).map((exercise) => exercise.id).toSet();
      final userAFoods = (await database.getFoods(
        'user-a',
      )).map((food) => food.id).toSet();

      expect(
        userAExercises.where((id) => id.startsWith('a-exercise-')),
        hasLength(10),
      );
      expect(userAExercises, isNot(contains('b-exercise-0')));
      expect(
        userBExercises.where((id) => id.startsWith('b-exercise-')),
        hasLength(7),
      );
      expect(userBExercises, isNot(contains('a-exercise-0')));
      expect(userAFoods.where((id) => id.startsWith('a-food-')), hasLength(9));
      expect(userAExercises, isNot(contains('a-food-0')));
    },
  );
}

final _date = DateTime.utc(2026, 7, 13);

Exercise _exercise(String id) =>
    Exercise(id: id, name: 'Exercise $id', bodyPart: 'Test');

Food _food(String id) => Food(
  id: id,
  name: 'Food $id',
  caloriesPer100g: 100,
  proteinPer100g: 10,
  carbsPer100g: 12,
  fatPer100g: 2,
);

DietLog _diet(String userId, String id) => DietLog(
  id: id,
  userId: userId,
  foodId: 'food-$id',
  date: _date,
  mealType: MealType.lunch,
  grams: 100,
  calories: 200,
);

WorkoutLog _workout(String userId, String id) => WorkoutLog(
  id: id,
  userId: userId,
  exerciseId: 'exercise-$id',
  date: _date,
  sets: 3,
  reps: 8,
  weightKg: 80,
);

WorkoutTemplate _template(String id) =>
    WorkoutTemplate(id: id, name: 'Template $id', exercises: const []);

BodyMeasurement _measurement(String userId, String id) =>
    BodyMeasurement(id: id, userId: userId, date: _date, weight: 80);
