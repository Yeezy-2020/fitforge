import 'dart:async';

import 'package:fitforge/data/models/diet_log.dart';
import 'package:fitforge/data/models/exercise.dart';
import 'package:fitforge/data/models/food.dart';
import 'package:fitforge/data/models/progression_rule.dart';
import 'package:fitforge/data/models/user_profile.dart';
import 'package:fitforge/data/models/workout_log.dart';
import 'package:fitforge/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('user-scoped builds', () {
    test(
      'exercise build publishes only the latest user after A to B',
      () async {
        final store = _FakeUserDataStore(
          exercisesByUser: {
            'user-a': [_exercise('a')],
            'user-b': [_exercise('b')],
          },
        );
        final remote = _FakeUserDataRemote();
        final aRead = Completer<List<Exercise>>();
        store.exerciseReadGates['user-a'] = [aRead];
        final container = _container(store, remote);
        addTearDown(container.dispose);

        final firstBuild = container.read(exerciseListProvider.future);
        expect(store.calls, contains('getExercises:user-a'));

        container.read(currentUserIdProvider.notifier).state = 'user-b';
        final userBExercises = await container.read(
          exerciseListProvider.future,
        );
        expect(userBExercises.map((exercise) => exercise.id), ['b']);

        aRead.complete([_exercise('late-a')]);
        await firstBuild;
        expect(
          container
              .read(exerciseListProvider)
              .requireValue
              .map((exercise) => exercise.id),
          ['b'],
        );
      },
    );

    test('logout rebuilds account providers with empty values', () async {
      final store = _FakeUserDataStore(
        exercisesByUser: {
          'user-a': [_exercise('a')],
        },
        rulesByUser: {
          'user-a': [_rule('user-a')],
        },
        foodsByUser: {
          'user-a': [_food('a')],
        },
      );
      final remote = _FakeUserDataRemote(publicFoods: [_food('public')]);
      final container = _container(store, remote);
      addTearDown(container.dispose);

      await container.read(exerciseListProvider.future);
      await container.read(progressionRulesProvider.future);
      await container.read(foodListProvider.future);

      container.read(currentUserIdProvider.notifier).state = '';

      expect(await container.read(exerciseListProvider.future), isEmpty);
      expect(await container.read(progressionRulesProvider.future), isEmpty);
      expect(await container.read(foodListProvider.future), isEmpty);
      expect(
        await container.read(
          workoutLogsForDateProvider(DateTime(2026, 7, 13)).future,
        ),
        isEmpty,
      );
      expect(
        await container.read(
          workoutDatesForMonthProvider(DateTime(2026, 7)).future,
        ),
        isEmpty,
      );
    });
  });

  group('user-scoped mutations', () {
    test('A to B to A cannot publish a stale exercise mutation', () async {
      final originalA = _exercise('original-a');
      final addedA = _exercise('added-a');
      final store = _FakeUserDataStore(
        exercisesByUser: {
          'user-a': [originalA],
          'user-b': [_exercise('b')],
        },
      );
      final container = _container(store, _FakeUserDataRemote());
      addTearDown(container.dispose);
      await container.read(exerciseListProvider.future);

      store.addExerciseGate = Completer<void>();
      final operation = container
          .read(exerciseListProvider.notifier)
          .addExercise(addedA);
      expect(store.calls, contains('addExercise:user-a'));

      container.read(currentUserIdProvider.notifier).state = 'user-b';
      await container.read(exerciseListProvider.future);
      container.read(currentUserIdProvider.notifier).state = 'user-a';
      expect(
        (await container.read(
          exerciseListProvider.future,
        )).map((exercise) => exercise.id),
        ['original-a'],
      );

      store.addExerciseGate!.complete();
      await operation;

      expect(
        container
            .read(exerciseListProvider)
            .requireValue
            .map((exercise) => exercise.id),
        ['original-a'],
      );
      expect(store.exercisesByUser['user-a']!.map((exercise) => exercise.id), [
        'original-a',
        'added-a',
      ]);
    });

    test(
      'progression mutation cannot publish user A data after switch',
      () async {
        final store = _FakeUserDataStore(
          rulesByUser: {
            'user-a': [_rule('user-a')],
            'user-b': [_rule('user-b')],
          },
        );
        final container = _container(store, _FakeUserDataRemote());
        addTearDown(container.dispose);
        await container.read(progressionRulesProvider.future);

        store.saveRuleGate = Completer<void>();
        final operation = container
            .read(progressionRulesProvider.notifier)
            .save(_rule('user-a', id: 'replacement-a'));
        expect(store.calls, contains('saveRule:user-a'));

        container.read(currentUserIdProvider.notifier).state = 'user-b';
        expect(
          (await container.read(
            progressionRulesProvider.future,
          )).map((rule) => rule.userId),
          ['user-b'],
        );

        store.saveRuleGate!.complete();
        await operation;
        expect(
          container
              .read(progressionRulesProvider)
              .requireValue
              .map((rule) => rule.userId),
          ['user-b'],
        );
      },
    );

    test(
      'owner mismatches fail before progression or profile writes',
      () async {
        final store = _FakeUserDataStore();
        final container = _container(store, _FakeUserDataRemote());
        addTearDown(container.dispose);
        await container.read(progressionRulesProvider.future);
        await container.read(userProfileProvider.future);

        await expectLater(
          container
              .read(progressionRulesProvider.notifier)
              .save(_rule('user-b')),
          throwsA(isA<UserDataOwnerMismatchException>()),
        );
        await expectLater(
          container
              .read(userProfileProvider.notifier)
              .saveProfile(_profile('user-b')),
          throwsA(isA<UserDataOwnerMismatchException>()),
        );
        expect(store.calls.where((call) => call.startsWith('save')), isEmpty);
      },
    );
  });

  group('profile remote and local contract', () {
    test('remote profile is cached and returned', () async {
      final store = _FakeUserDataStore();
      final remoteProfile = _profile('user-a', displayName: 'Remote');
      final remote = _FakeUserDataRemote(
        profilesByUser: {'user-a': remoteProfile},
      );
      final container = _container(store, remote);
      addTearDown(container.dispose);

      expect(await container.read(userProfileProvider.future), remoteProfile);
      expect(store.profilesByUser['user-a'], remoteProfile);
      expect(store.calls, contains('saveProfile:user-a'));
    });

    test('remote null returns the local profile or null', () async {
      final localProfile = _profile('user-a', displayName: 'Local');
      final store = _FakeUserDataStore(
        profilesByUser: {'user-a': localProfile},
      );
      final container = _container(store, _FakeUserDataRemote());
      addTearDown(container.dispose);

      expect(await container.read(userProfileProvider.future), localProfile);

      store.profilesByUser.clear();
      container.invalidate(userProfileProvider);
      expect(await container.read(userProfileProvider.future), isNull);
    });

    test(
      'remote error falls back locally but stays AsyncError without cache',
      () async {
        final remoteError = StateError('profile unavailable');
        final cachedProfile = _profile('user-a');
        final cachedStore = _FakeUserDataStore(
          profilesByUser: {'user-a': cachedProfile},
        );
        final cachedContainer = _container(
          cachedStore,
          _FakeUserDataRemote(profileErrors: {'user-a': remoteError}),
        );
        addTearDown(cachedContainer.dispose);

        expect(
          await cachedContainer.read(userProfileProvider.future),
          cachedProfile,
        );

        final emptyContainer = _container(
          _FakeUserDataStore(),
          _FakeUserDataRemote(profileErrors: {'user-a': remoteError}),
        );
        addTearDown(emptyContainer.dispose);
        await expectLater(
          emptyContainer.read(userProfileProvider.future),
          throwsA(same(remoteError)),
        );
        expect(
          emptyContainer.read(userProfileProvider),
          isA<AsyncError<UserProfile?>>(),
        );
      },
    );

    test('remote owner mismatch is not treated as a cache miss', () async {
      final container = _container(
        _FakeUserDataStore(profilesByUser: {'user-a': _profile('user-a')}),
        _FakeUserDataRemote(profilesByUser: {'user-a': _profile('user-b')}),
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(userProfileProvider.future),
        throwsA(isA<UserDataOwnerMismatchException>()),
      );
    });
  });

  group('account-scoped in-memory caches', () {
    test('A cache state is cleared for B, logout, and a fresh A scope', () {
      final store = _FakeUserDataStore();
      final remote = _FakeUserDataRemote();
      final container = _container(store, remote);
      addTearDown(container.dispose);
      final date = DateTime(2026, 7, 13);

      container.read(workoutCacheProvider.notifier).addDate(date);
      container.read(workoutLogCacheProvider.notifier).addLogs(date, [
        _workoutLog('user-a'),
      ]);
      container.read(dietCacheProvider.notifier).addLog(_dietLog('user-a'));
      container.read(dietDatesProvider.notifier).addDate(date);

      expect(container.read(workoutCacheProvider), isNotEmpty);
      expect(container.read(workoutLogCacheProvider), isNotEmpty);
      expect(container.read(dietCacheProvider), isNotEmpty);
      expect(container.read(dietDatesProvider), isNotEmpty);

      for (final userId in ['user-b', '', 'user-a']) {
        container.read(currentUserIdProvider.notifier).state = userId;
        expect(container.read(workoutCacheProvider), isEmpty);
        expect(container.read(workoutLogCacheProvider), isEmpty);
        expect(container.read(dietCacheProvider), isEmpty);
        expect(container.read(dietDatesProvider), isEmpty);
      }
    });

    test('an in-flight A cache load cannot publish after switch', () async {
      final remote = _FakeUserDataRemote();
      final loadGate = Completer<List<WorkoutLog>>();
      remote.workoutDateReadGates['user-a'] = [loadGate];
      final container = _container(_FakeUserDataStore(), remote);
      addTearDown(container.dispose);
      final date = DateTime(2026, 7, 13);

      final operation = container
          .read(workoutLogCacheProvider.notifier)
          .loadDate(date);
      expect(remote.calls, contains('getWorkoutLogs:user-a'));

      container.read(currentUserIdProvider.notifier).state = 'user-b';
      expect(container.read(workoutLogCacheProvider), isEmpty);

      loadGate.complete([_workoutLog('user-a')]);
      await operation;
      expect(container.read(workoutLogCacheProvider), isEmpty);
    });

    test('cache owner mismatch is surfaced instead of swallowed', () async {
      final remote = _FakeUserDataRemote(
        workoutLogsByUser: {
          'user-a': [_workoutLog('user-b')],
        },
      );
      final container = _container(_FakeUserDataStore(), remote);
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(workoutLogCacheProvider.notifier)
            .loadDate(DateTime(2026, 7, 13)),
        throwsA(isA<UserDataOwnerMismatchException>()),
      );
      expect(container.read(workoutLogCacheProvider), isEmpty);
    });

    test('isPro starts false for each account and logout', () async {
      final store = _FakeUserDataStore(
        subscriptionsByUser: {'user-a': true, 'user-b': false},
      );
      final container = _container(store, _FakeUserDataRemote());
      addTearDown(container.dispose);

      await container.read(isProProvider.notifier).load();
      expect(container.read(isProProvider), isTrue);

      container.read(currentUserIdProvider.notifier).state = 'user-b';
      expect(container.read(isProProvider), isFalse);
      await container.read(isProProvider.notifier).load();
      expect(container.read(isProProvider), isFalse);

      container.read(currentUserIdProvider.notifier).state = '';
      expect(container.read(isProProvider), isFalse);
    });

    test('nutrition cycle state is cleared for every account scope', () {
      final container = _container(_FakeUserDataStore(), _FakeUserDataRemote());
      addTearDown(container.dispose);
      final firstUserAScope = container.read(currentUserScopeProvider);

      container.read(nutritionCycleProvider.notifier).state = const [
        'high',
        'low',
      ];
      container.read(nutritionStartDateProvider.notifier).state = DateTime(
        2026,
        7,
        13,
      );

      container.read(currentUserIdProvider.notifier).state = 'user-b';
      expect(
        container.read(currentUserScopeProvider),
        isNot(same(firstUserAScope)),
      );
      expect(container.read(nutritionCycleProvider), isNull);
      expect(container.read(nutritionStartDateProvider), isNull);

      container.read(nutritionCycleProvider.notifier).state = const ['medium'];
      container.read(nutritionStartDateProvider.notifier).state = DateTime(
        2026,
        7,
        14,
      );
      container.read(currentUserIdProvider.notifier).state = '';
      expect(container.read(nutritionCycleProvider), isNull);
      expect(container.read(nutritionStartDateProvider), isNull);

      container.read(currentUserIdProvider.notifier).state = 'user-a';
      expect(
        container.read(currentUserScopeProvider),
        isNot(same(firstUserAScope)),
      );
      expect(container.read(nutritionCycleProvider), isNull);
      expect(container.read(nutritionStartDateProvider), isNull);
    });
  });
}

ProviderContainer _container(
  _FakeUserDataStore store,
  _FakeUserDataRemote remote,
) {
  return ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 'user-a'),
      userDataStoreProvider.overrideWith((ref) => store),
      userDataRemoteProvider.overrideWith((ref) => remote),
      isOnlineProvider.overrideWith((ref) => true),
    ],
  );
}

Exercise _exercise(String id) => Exercise(id: id, name: id, bodyPart: 'test');

Food _food(String id) => Food(
  id: id,
  name: id,
  caloriesPer100g: 100,
  proteinPer100g: 10,
  carbsPer100g: 10,
  fatPer100g: 2,
);

UserProfile _profile(String userId, {String? displayName}) => UserProfile(
  id: userId,
  gender: Gender.male,
  age: 30,
  heightCm: 180,
  weightKg: 80,
  goal: FitnessGoal.buildMuscle,
  displayName: displayName,
);

ProgressionRule _rule(String userId, {String? id}) => ProgressionRule(
  id: id ?? 'rule-$userId',
  userId: userId,
  exerciseId: 'exercise',
  type: ProgressionType.doubleProgression,
);

WorkoutLog _workoutLog(String userId) => WorkoutLog(
  id: 'workout-$userId',
  userId: userId,
  exerciseId: 'exercise',
  date: DateTime(2026, 7, 13),
  sets: 3,
  reps: 8,
  weightKg: 80,
);

DietLog _dietLog(String userId) => DietLog(
  id: 'diet-$userId',
  userId: userId,
  foodId: 'food',
  date: DateTime(2026, 7, 13),
  mealType: MealType.lunch,
  grams: 100,
  calories: 100,
);

class _FakeUserDataStore implements UserDataStore {
  final Map<String, UserProfile> profilesByUser;
  final Map<String, List<Exercise>> exercisesByUser;
  final Map<String, List<ProgressionRule>> rulesByUser;
  final Map<String, List<Food>> foodsByUser;
  final Map<String, List<WorkoutLog>> workoutLogsByUser;
  final Map<String, bool> subscriptionsByUser;
  final Map<String, List<Completer<List<Exercise>>>> exerciseReadGates = {};
  final List<String> calls = [];
  Completer<void>? addExerciseGate;
  Completer<void>? saveRuleGate;

  _FakeUserDataStore({
    Map<String, UserProfile>? profilesByUser,
    Map<String, List<Exercise>>? exercisesByUser,
    Map<String, List<ProgressionRule>>? rulesByUser,
    Map<String, List<Food>>? foodsByUser,
    Map<String, List<WorkoutLog>>? workoutLogsByUser,
    Map<String, bool>? subscriptionsByUser,
  }) : profilesByUser = {...?profilesByUser},
       exercisesByUser = _copyLists(exercisesByUser),
       rulesByUser = _copyLists(rulesByUser),
       foodsByUser = _copyLists(foodsByUser),
       workoutLogsByUser = _copyLists(workoutLogsByUser),
       subscriptionsByUser = {...?subscriptionsByUser};

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    calls.add('getProfile:$userId');
    return profilesByUser[userId];
  }

  @override
  Future<void> saveUserProfile(String userId, UserProfile profile) async {
    calls.add('saveProfile:$userId');
    profilesByUser[userId] = profile;
  }

  @override
  Future<List<Exercise>> getExercises(String userId) async {
    calls.add('getExercises:$userId');
    final gates = exerciseReadGates[userId];
    if (gates != null && gates.isNotEmpty) {
      return gates.removeAt(0).future;
    }
    return List<Exercise>.from(exercisesByUser[userId] ?? const []);
  }

  @override
  Future<void> addExercise(String userId, Exercise exercise) async {
    calls.add('addExercise:$userId');
    final gate = addExerciseGate;
    if (gate != null) await gate.future;
    exercisesByUser.putIfAbsent(userId, () => []).add(exercise);
  }

  @override
  Future<List<WorkoutLog>> getWorkoutLogs(String userId, DateTime date) async {
    calls.add('getWorkoutLogs:$userId');
    return List<WorkoutLog>.from(workoutLogsByUser[userId] ?? const []);
  }

  @override
  Future<List<WorkoutLog>> getWorkoutLogsForMonth(
    String userId,
    DateTime month,
  ) async {
    calls.add('getWorkoutLogsForMonth:$userId');
    return List<WorkoutLog>.from(workoutLogsByUser[userId] ?? const []);
  }

  @override
  Future<WorkoutLog?> getLastWorkoutLogForExercise(
    String userId,
    String exerciseId,
    DateTime before,
  ) async {
    calls.add('getLastWorkoutLog:$userId');
    return (workoutLogsByUser[userId] ?? const []).firstOrNull;
  }

  @override
  Future<List<ProgressionRule>> getProgressionRules(String userId) async {
    calls.add('getRules:$userId');
    return List<ProgressionRule>.from(rulesByUser[userId] ?? const []);
  }

  @override
  Future<void> saveProgressionRule(String userId, ProgressionRule rule) async {
    calls.add('saveRule:$userId');
    final gate = saveRuleGate;
    if (gate != null) await gate.future;
    rulesByUser[userId] = [rule];
  }

  @override
  Future<void> deleteProgressionRule(String userId, String exerciseId) async {
    calls.add('deleteRule:$userId');
    rulesByUser[userId] = [
      for (final rule in rulesByUser[userId] ?? const [])
        if (rule.exerciseId != exerciseId) rule,
    ];
  }

  @override
  Future<List<Food>> getFoods(String userId) async {
    calls.add('getFoods:$userId');
    return List<Food>.from(foodsByUser[userId] ?? const []);
  }

  @override
  Future<bool> getSubscriptionStatus(String userId) async {
    calls.add('getSubscription:$userId');
    return subscriptionsByUser[userId] ?? false;
  }

  @override
  Future<void> setSubscriptionStatus(String userId, bool isPro) async {
    calls.add('setSubscription:$userId');
    subscriptionsByUser[userId] = isPro;
  }
}

class _FakeUserDataRemote implements UserDataRemote {
  final Map<String, UserProfile> profilesByUser;
  final Map<String, Object> profileErrors;
  final List<Food> publicFoods;
  final Map<String, List<WorkoutLog>> workoutLogsByUser;
  final Map<String, List<DietLog>> dietLogsByUser;
  final Map<String, List<Completer<List<WorkoutLog>>>> workoutDateReadGates =
      {};
  final List<String> calls = [];

  _FakeUserDataRemote({
    Map<String, UserProfile>? profilesByUser,
    Map<String, Object>? profileErrors,
    List<Food>? publicFoods,
    Map<String, List<WorkoutLog>>? workoutLogsByUser,
    Map<String, List<DietLog>>? dietLogsByUser,
  }) : profilesByUser = {...?profilesByUser},
       profileErrors = {...?profileErrors},
       publicFoods = List<Food>.from(publicFoods ?? const []),
       workoutLogsByUser = _copyLists(workoutLogsByUser),
       dietLogsByUser = _copyLists(dietLogsByUser);

  @override
  Future<UserProfile?> getProfile(String userId) async {
    calls.add('getProfile:$userId');
    final error = profileErrors[userId];
    if (error != null) throw error;
    return profilesByUser[userId];
  }

  @override
  Future<void> upsertProfile(String userId, UserProfile profile) async {
    calls.add('upsertProfile:$userId');
    profilesByUser[userId] = profile;
  }

  @override
  Future<List<Food>> getPublicFoods(String userId) async {
    calls.add('getPublicFoods:$userId');
    return List<Food>.from(publicFoods);
  }

  @override
  Future<List<WorkoutLog>> getWorkoutLogs(String userId, DateTime date) async {
    calls.add('getWorkoutLogs:$userId');
    final gates = workoutDateReadGates[userId];
    if (gates != null && gates.isNotEmpty) {
      return gates.removeAt(0).future;
    }
    return List<WorkoutLog>.from(workoutLogsByUser[userId] ?? const []);
  }

  @override
  Future<List<WorkoutLog>> getWorkoutLogsForMonth(
    String userId,
    DateTime month,
  ) async {
    calls.add('getWorkoutLogsForMonth:$userId');
    return List<WorkoutLog>.from(workoutLogsByUser[userId] ?? const []);
  }

  @override
  Future<List<DietLog>> getDietLogs(String userId, DateTime date) async {
    calls.add('getDietLogs:$userId');
    return List<DietLog>.from(dietLogsByUser[userId] ?? const []);
  }
}

Map<String, List<T>> _copyLists<T>(Map<String, List<T>>? source) => {
  for (final entry in (source ?? <String, List<T>>{}).entries)
    entry.key: List<T>.from(entry.value),
};
