import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/exercise.dart';
import '../data/models/workout_log.dart';
import '../data/models/food.dart';
import '../data/models/diet_log.dart';
import '../data/models/user_profile.dart';
import '../data/models/progression_rule.dart';
import '../data/models/training_program.dart';
import '../data/repositories/app_database.dart';
import '../core/services/supabase_service.dart';
import '../core/utils/nutrition_calculator.dart';
import '../core/utils/progression_calculator.dart';
import '../core/utils/program_prescription_calculator.dart';

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => AppDatabase.instance,
);
final supabaseProvider = Provider<SupabaseService>(
  (ref) => SupabaseService.instance,
);

class UserDataOwnerMismatchException implements Exception {
  final String entity;
  final String expectedUserId;
  final String actualUserId;

  const UserDataOwnerMismatchException({
    required this.entity,
    required this.expectedUserId,
    required this.actualUserId,
  });

  @override
  String toString() =>
      'UserDataOwnerMismatchException: $entity belongs to $actualUserId, '
      'expected $expectedUserId.';
}

class _StaleUserScopeException implements Exception {
  const _StaleUserScopeException();
}

void _requireOwner(String entity, String expectedUserId, String actualUserId) {
  if (actualUserId != expectedUserId) {
    throw UserDataOwnerMismatchException(
      entity: entity,
      expectedUserId: expectedUserId,
      actualUserId: actualUserId,
    );
  }
}

void _requireWorkoutLogOwners(
  Iterable<WorkoutLog> logs,
  String expectedUserId,
) {
  for (final log in logs) {
    _requireOwner('WorkoutLog ${log.id}', expectedUserId, log.userId);
  }
}

void _requireDietLogOwners(Iterable<DietLog> logs, String expectedUserId) {
  for (final log in logs) {
    _requireOwner('DietLog ${log.id}', expectedUserId, log.userId);
  }
}

void _requireProgressionRuleOwners(
  Iterable<ProgressionRule> rules,
  String expectedUserId,
) {
  for (final rule in rules) {
    _requireOwner('ProgressionRule ${rule.id}', expectedUserId, rule.userId);
  }
}

abstract interface class UserDataStore {
  Future<UserProfile?> getUserProfile(String userId);

  Future<void> saveUserProfile(String userId, UserProfile profile);

  Future<List<Exercise>> getExercises(String userId);

  Future<void> addExercise(String userId, Exercise exercise);

  Future<List<WorkoutLog>> getWorkoutLogs(String userId, DateTime date);

  Future<List<WorkoutLog>> getWorkoutLogsForMonth(
    String userId,
    DateTime month,
  );

  Future<WorkoutLog?> getLastWorkoutLogForExercise(
    String userId,
    String exerciseId,
    DateTime before,
  );

  Future<List<ProgressionRule>> getProgressionRules(String userId);

  Future<void> saveProgressionRule(String userId, ProgressionRule rule);

  Future<void> deleteProgressionRule(String userId, String exerciseId);

  Future<List<Food>> getFoods(String userId);

  Future<bool> getSubscriptionStatus(String userId);

  Future<void> setSubscriptionStatus(String userId, bool isPro);
}

class _AppDatabaseUserDataStore implements UserDataStore {
  final AppDatabase _database;

  const _AppDatabaseUserDataStore(this._database);

  @override
  Future<UserProfile?> getUserProfile(String userId) {
    return _database.getUserProfile(userId);
  }

  @override
  Future<void> saveUserProfile(String userId, UserProfile profile) {
    return _database.saveUserProfile(userId, profile);
  }

  @override
  Future<List<Exercise>> getExercises(String userId) {
    return _database.getExercises(userId);
  }

  @override
  Future<void> addExercise(String userId, Exercise exercise) {
    return _database.addExercise(userId, exercise);
  }

  @override
  Future<List<WorkoutLog>> getWorkoutLogs(String userId, DateTime date) {
    return _database.getWorkoutLogs(userId, date);
  }

  @override
  Future<List<WorkoutLog>> getWorkoutLogsForMonth(
    String userId,
    DateTime month,
  ) {
    return _database.getWorkoutLogsForMonth(userId, month);
  }

  @override
  Future<WorkoutLog?> getLastWorkoutLogForExercise(
    String userId,
    String exerciseId,
    DateTime before,
  ) {
    return _database.getLastWorkoutLogForExercise(userId, exerciseId, before);
  }

  @override
  Future<List<ProgressionRule>> getProgressionRules(String userId) {
    return _database.getProgressionRules(userId);
  }

  @override
  Future<void> saveProgressionRule(String userId, ProgressionRule rule) {
    return _database.saveProgressionRule(userId, rule);
  }

  @override
  Future<void> deleteProgressionRule(String userId, String exerciseId) {
    return _database.deleteProgressionRule(userId, exerciseId);
  }

  @override
  Future<List<Food>> getFoods(String userId) {
    return _database.getFoods(userId);
  }

  @override
  Future<bool> getSubscriptionStatus(String userId) {
    return _database.getSubscriptionStatus(userId);
  }

  @override
  Future<void> setSubscriptionStatus(String userId, bool isPro) {
    return _database.setSubscriptionStatus(userId, isPro);
  }
}

final userDataStoreProvider = Provider<UserDataStore>((ref) {
  return _AppDatabaseUserDataStore(ref.watch(appDatabaseProvider));
});

abstract interface class UserDataRemote {
  Future<UserProfile?> getProfile(String userId);

  Future<void> upsertProfile(String userId, UserProfile profile);

  Future<List<Food>> getPublicFoods(String userId);

  Future<List<WorkoutLog>> getWorkoutLogs(String userId, DateTime date);

  Future<List<WorkoutLog>> getWorkoutLogsForMonth(
    String userId,
    DateTime month,
  );

  Future<List<DietLog>> getDietLogs(String userId, DateTime date);
}

class _SupabaseUserDataRemote implements UserDataRemote {
  final SupabaseService _supabase;

  const _SupabaseUserDataRemote(this._supabase);

  Future<T> _runInScope<T>(String userId, Future<T> Function() request) async {
    if ((_supabase.userId ?? '') != userId) {
      throw const _StaleUserScopeException();
    }
    final result = await request();
    if ((_supabase.userId ?? '') != userId) {
      throw const _StaleUserScopeException();
    }
    return result;
  }

  @override
  Future<UserProfile?> getProfile(String userId) {
    return _runInScope(userId, _supabase.getProfile);
  }

  @override
  Future<void> upsertProfile(String userId, UserProfile profile) {
    return _runInScope(userId, () => _supabase.upsertProfile(profile));
  }

  @override
  Future<List<Food>> getPublicFoods(String userId) {
    return _runInScope(userId, _supabase.getPublicFoods);
  }

  @override
  Future<List<WorkoutLog>> getWorkoutLogs(String userId, DateTime date) {
    return _runInScope(userId, () => _supabase.getWorkoutLogs(date));
  }

  @override
  Future<List<WorkoutLog>> getWorkoutLogsForMonth(
    String userId,
    DateTime month,
  ) {
    return _runInScope(userId, () => _supabase.getWorkoutLogsForMonth(month));
  }

  @override
  Future<List<DietLog>> getDietLogs(String userId, DateTime date) {
    return _runInScope(userId, () => _supabase.getDietLogs(date));
  }
}

final userDataRemoteProvider = Provider<UserDataRemote>((ref) {
  return _SupabaseUserDataRemote(ref.watch(supabaseProvider));
});

abstract interface class WorkoutLogWriteStore {
  Future<void> addWorkoutLog(String userId, WorkoutLog log);

  Future<void> saveWorkoutSetLogs(String userId, List<WorkoutSetLog> setLogs);

  Future<void> addUnsyncedWorkout(String userId, WorkoutLog log);
}

class _AppDatabaseWorkoutLogWriteStore implements WorkoutLogWriteStore {
  final AppDatabase _database;

  const _AppDatabaseWorkoutLogWriteStore(this._database);

  @override
  Future<void> addWorkoutLog(String userId, WorkoutLog log) {
    _requireOwner('WorkoutLog ${log.id}', userId, log.userId);
    return _database.addWorkoutLog(userId, log);
  }

  @override
  Future<void> saveWorkoutSetLogs(String userId, List<WorkoutSetLog> setLogs) {
    return _database.saveWorkoutSetLogs(userId, setLogs);
  }

  @override
  Future<void> addUnsyncedWorkout(String userId, WorkoutLog log) {
    _requireOwner('WorkoutLog ${log.id}', userId, log.userId);
    return _database.addUnsyncedWorkout(userId, log);
  }
}

final workoutLogWriteStoreProvider = Provider<WorkoutLogWriteStore>((ref) {
  return _AppDatabaseWorkoutLogWriteStore(ref.watch(appDatabaseProvider));
});

abstract interface class WorkoutLogRemoteWriter {
  Future<void> addWorkoutLog(WorkoutLog log, {required String expectedUserId});
}

class _SupabaseWorkoutLogRemoteWriter implements WorkoutLogRemoteWriter {
  final SupabaseService _supabase;

  const _SupabaseWorkoutLogRemoteWriter(this._supabase);

  @override
  Future<void> addWorkoutLog(WorkoutLog log, {required String expectedUserId}) {
    _requireOwner('WorkoutLog ${log.id}', expectedUserId, log.userId);
    return _supabase.addWorkoutLogForSync(log, expectedUserId: expectedUserId);
  }
}

final workoutLogRemoteWriterProvider = Provider<WorkoutLogRemoteWriter>((ref) {
  return _SupabaseWorkoutLogRemoteWriter(ref.watch(supabaseProvider));
});

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final currentUserIdProvider = StateProvider<String>((ref) {
  return Supabase.instance.client.auth.currentUser?.id ?? '';
});

class UserScope {
  final String userId;

  const UserScope(this.userId);
}

/// A new identity is created for every account transition, including A -> B -> A.
final currentUserScopeProvider = Provider<UserScope>((ref) {
  return UserScope(ref.watch(currentUserIdProvider));
});

final isOnlineProvider = StateProvider<bool>((ref) => true);

// Share nutrition plan with calendar for carb cycle markers
final nutritionCycleProvider = StateProvider<List<String>?>((ref) {
  ref.watch(currentUserScopeProvider);
  return null;
});
final nutritionStartDateProvider = StateProvider<DateTime?>((ref) {
  ref.watch(currentUserScopeProvider);
  return null;
});

// Track which dates have diet logs (for calendar green dots)
class DietDatesNotifier extends StateNotifier<Set<String>> {
  final UserDataRemote _remote;
  final String _userId;
  bool _active = true;

  DietDatesNotifier(this._remote, this._userId) : super({});

  String _k(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void addDate(DateTime d) {
    if (!_active || _userId.isEmpty) return;
    state = {...state, _k(d)};
  }

  Future<void> loadMonth(int year, int month) async {
    if (!_active || _userId.isEmpty) return;
    try {
      final firstDay = DateTime(year, month, 1);
      final logs = await _remote.getDietLogs(_userId, firstDay);
      _requireDietLogOwners(logs, _userId);
      if (!_active) return;
      state = {...state, ...logs.map((log) => _k(log.date))};
    } on UserDataOwnerMismatchException {
      rethrow;
    } catch (_) {}
  }

  @override
  void dispose() {
    _active = false;
    super.dispose();
  }
}

final dietDatesProvider = StateNotifierProvider<DietDatesNotifier, Set<String>>(
  (ref) => DietDatesNotifier(
    ref.watch(userDataRemoteProvider),
    ref.watch(currentUserIdProvider),
  ),
);

final isProProvider = StateNotifierProvider<IsProNotifier, bool>((ref) {
  final n = IsProNotifier.forUser(
    ref.watch(currentUserIdProvider),
    store: ref.watch(userDataStoreProvider),
  );
  n.load();
  return n;
});

class IsProNotifier extends StateNotifier<bool> {
  final String _userId;
  final UserDataStore _store;
  bool _active = true;

  IsProNotifier() : this.forUser('');

  IsProNotifier.forUser(this._userId, {UserDataStore? store})
    : _store = store ?? _AppDatabaseUserDataStore(AppDatabase.instance),
      super(false);

  Future<void> load() async {
    if (_userId.isEmpty) return;
    final value = await _store.getSubscriptionStatus(_userId);
    if (_active) state = value;
  }

  Future<void> setPro(bool value) async {
    if (!_active || _userId.isEmpty) return;
    state = value;
    await _store.setSubscriptionStatus(_userId, value);
  }

  @override
  void dispose() {
    _active = false;
    super.dispose();
  }
}

// ===== Profile =====
final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(
      UserProfileNotifier.new,
    );

class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  Object _userScope = Object();

  @override
  Future<UserProfile?> build() async {
    _userScope = Object();
    final userScope = _userScope;
    final userId = ref.watch(currentUserIdProvider);
    if (userId.isEmpty) return null;

    final remote = ref.watch(userDataRemoteProvider);
    final store = ref.watch(userDataStoreProvider);
    Object? remoteError;
    StackTrace? remoteStackTrace;
    UserProfile? remoteProfile;
    try {
      remoteProfile = await remote.getProfile(userId);
    } on UserDataOwnerMismatchException {
      rethrow;
    } catch (error, stackTrace) {
      remoteError = error;
      remoteStackTrace = stackTrace;
    }

    if (remoteProfile != null) {
      _requireOwner('UserProfile', userId, remoteProfile.id);
      if (_isCurrentUserScope(userId, userScope)) {
        await store.saveUserProfile(userId, remoteProfile);
      }
      return remoteProfile;
    }

    final localProfile = await store.getUserProfile(userId);
    if (localProfile != null) {
      _requireOwner('UserProfile', userId, localProfile.id);
      return localProfile;
    }

    if (remoteError != null) {
      Error.throwWithStackTrace(remoteError, remoteStackTrace!);
    }
    return null;
  }

  bool _isCurrentUserScope(String userId, Object userScope) {
    return identical(_userScope, userScope) &&
        ref.read(currentUserIdProvider) == userId;
  }

  Future<void> saveProfile(UserProfile profile) async {
    final userId = ref.read(currentUserIdProvider);
    final userScope = _userScope;
    if (userId.isEmpty) return;
    _requireOwner('UserProfile', userId, profile.id);
    final store = ref.read(userDataStoreProvider);
    await store.saveUserProfile(userId, profile);
    if (!_isCurrentUserScope(userId, userScope)) return;

    try {
      await ref.read(userDataRemoteProvider).upsertProfile(userId, profile);
    } on UserDataOwnerMismatchException {
      rethrow;
    } catch (_) {}

    if (_isCurrentUserScope(userId, userScope)) {
      state = AsyncData(profile);
    }
  }
}

// ===== Nutrition =====
final nutritionPlanProvider =
    Provider<({double tdee, double protein, double carbs, double fat})?>((ref) {
      final profile = ref.watch(userProfileProvider).valueOrNull;
      if (profile == null) return null;
      return const NutritionCalculator().calculateLegacy(profile);
    });

// ===== Exercises =====
final exerciseListProvider =
    AsyncNotifierProvider<ExerciseListNotifier, List<Exercise>>(
      ExerciseListNotifier.new,
    );

class ExerciseListNotifier extends AsyncNotifier<List<Exercise>> {
  Object _userScope = Object();

  @override
  Future<List<Exercise>> build() async {
    _userScope = Object();
    final userId = ref.watch(currentUserIdProvider);
    if (userId.isEmpty) return [];
    return ref.watch(userDataStoreProvider).getExercises(userId);
  }

  Future<void> addExercise(Exercise exercise) async {
    final userId = ref.read(currentUserIdProvider);
    final userScope = _userScope;
    if (userId.isEmpty) return;
    final store = ref.read(userDataStoreProvider);
    await store.addExercise(userId, exercise);
    if (!_isCurrentUserScope(userId, userScope)) return;
    final exercises = await store.getExercises(userId);
    if (_isCurrentUserScope(userId, userScope)) {
      state = AsyncData(exercises);
    }
  }

  bool _isCurrentUserScope(String userId, Object userScope) {
    return identical(_userScope, userScope) &&
        ref.read(currentUserIdProvider) == userId;
  }
}

final exercisesByBodyPartProvider = Provider.family<List<Exercise>, String>((
  ref,
  bodyPart,
) {
  final exercises = ref.watch(exerciseListProvider).valueOrNull ?? [];
  return exercises.where((e) => e.bodyPart == bodyPart).toList();
});

final bodyPartsProvider = Provider<List<String>>((ref) {
  final exercises = ref.watch(exerciseListProvider).valueOrNull ?? [];
  return exercises.map((e) => e.bodyPart).toSet().toList()..sort();
});

// ===== Workout Logs =====
final workoutLogsForDateProvider =
    FutureProvider.family<List<WorkoutLog>, DateTime>((ref, date) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId.isEmpty) return [];
      final remote = ref.watch(userDataRemoteProvider);
      final store = ref.watch(userDataStoreProvider);
      try {
        final logs = await remote.getWorkoutLogs(userId, date);
        _requireWorkoutLogOwners(logs, userId);
        return logs;
      } on UserDataOwnerMismatchException {
        rethrow;
      } catch (_) {
        final logs = await store.getWorkoutLogs(userId, date);
        _requireWorkoutLogOwners(logs, userId);
        return logs;
      }
    });

// ---- Workout Dates Cache (in-memory, offline-ready) ----
class WorkoutCacheNotifier extends StateNotifier<Map<String, Set<DateTime>>> {
  final UserDataRemote _remote;
  final String _userId;
  bool _active = true;

  WorkoutCacheNotifier(this._remote, this._userId) : super({});

  String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  Set<DateTime> getDatesForMonth(DateTime month) {
    return state[_key(month)] ?? {};
  }

  void addDate(DateTime date) {
    if (!_active || _userId.isEmpty) return;
    final k = _key(date);
    state = {
      ...state,
      k: {...(state[k] ?? {}), DateTime(date.year, date.month, date.day)},
    };
  }

  Future<void> loadMonth(DateTime month) async {
    if (!_active || _userId.isEmpty) return;
    try {
      final logs = await _remote.getWorkoutLogsForMonth(_userId, month);
      _requireWorkoutLogOwners(logs, _userId);
      if (!_active) return;
      final dates = logs
          .map((l) => DateTime(l.date.year, l.date.month, l.date.day))
          .toSet();
      state = {...state, _key(month): dates};
    } on UserDataOwnerMismatchException {
      rethrow;
    } catch (_) {}
  }

  Future<void> loadAll() async {
    final now = DateTime.now();
    for (int i = -3; i <= 3; i++) {
      if (!_active || _userId.isEmpty) return;
      final month = DateTime(now.year, now.month + i);
      await loadMonth(month);
    }
  }

  @override
  void dispose() {
    _active = false;
    super.dispose();
  }
}

final workoutCacheProvider =
    StateNotifierProvider<WorkoutCacheNotifier, Map<String, Set<DateTime>>>(
      (ref) => WorkoutCacheNotifier(
        ref.watch(userDataRemoteProvider),
        ref.watch(currentUserIdProvider),
      ),
    );

class WorkoutLogCacheNotifier
    extends StateNotifier<Map<String, List<WorkoutLog>>> {
  final UserDataRemote _remote;
  final String _userId;
  bool _active = true;

  WorkoutLogCacheNotifier(this._remote, this._userId) : super({});

  String _k(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  List<WorkoutLog> getLogs(DateTime d) => state[_k(d)] ?? [];

  Future<void> loadDate(DateTime d) async {
    if (!_active || _userId.isEmpty) return;
    try {
      final logs = await _remote.getWorkoutLogs(_userId, d);
      _requireWorkoutLogOwners(logs, _userId);
      if (!_active) return;
      state = {...state, _k(d): logs};
    } on UserDataOwnerMismatchException {
      rethrow;
    } catch (_) {}
  }

  void addLogs(DateTime d, List<WorkoutLog> logs) {
    if (!_active || _userId.isEmpty) return;
    _requireWorkoutLogOwners(logs, _userId);
    final k = _k(d);
    final e = List<WorkoutLog>.from(state[k] ?? []);
    e.addAll(logs);
    state = {...state, k: e};
  }

  @override
  void dispose() {
    _active = false;
    super.dispose();
  }
}

final workoutLogCacheProvider =
    StateNotifierProvider<
      WorkoutLogCacheNotifier,
      Map<String, List<WorkoutLog>>
    >(
      (ref) => WorkoutLogCacheNotifier(
        ref.watch(userDataRemoteProvider),
        ref.watch(currentUserIdProvider),
      ),
    );

final workoutDatesForMonthProvider =
    FutureProvider.family<Set<DateTime>, DateTime>((ref, month) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId.isEmpty) return {};
      final remote = ref.watch(userDataRemoteProvider);
      final store = ref.watch(userDataStoreProvider);
      try {
        if (ref.watch(isOnlineProvider)) {
          final logs = await remote.getWorkoutLogsForMonth(userId, month);
          _requireWorkoutLogOwners(logs, userId);
          return logs
              .map((l) => DateTime(l.date.year, l.date.month, l.date.day))
              .toSet();
        }
      } on UserDataOwnerMismatchException {
        rethrow;
      } catch (_) {}
      final local = await store.getWorkoutLogsForMonth(userId, month);
      _requireWorkoutLogOwners(local, userId);
      return local
          .map((l) => DateTime(l.date.year, l.date.month, l.date.day))
          .toSet();
    });

// ===== Progression Rules =====
final progressionRulesProvider =
    AsyncNotifierProvider<ProgressionRulesNotifier, List<ProgressionRule>>(
      ProgressionRulesNotifier.new,
    );

class ProgressionRulesNotifier extends AsyncNotifier<List<ProgressionRule>> {
  Object _userScope = Object();

  @override
  Future<List<ProgressionRule>> build() async {
    _userScope = Object();
    final userId = ref.watch(currentUserIdProvider);
    if (userId.isEmpty) return [];
    final rules = await ref
        .watch(userDataStoreProvider)
        .getProgressionRules(userId);
    _requireProgressionRuleOwners(rules, userId);
    return rules;
  }

  Future<void> save(ProgressionRule rule) async {
    final userId = ref.read(currentUserIdProvider);
    final userScope = _userScope;
    if (userId.isEmpty) return;
    _requireOwner('ProgressionRule ${rule.id}', userId, rule.userId);
    final store = ref.read(userDataStoreProvider);
    await store.saveProgressionRule(userId, rule);
    await _publishRulesIfCurrent(userId, userScope, store);
  }

  Future<void> delete(String exerciseId) async {
    final userId = ref.read(currentUserIdProvider);
    final userScope = _userScope;
    if (userId.isEmpty) return;
    final store = ref.read(userDataStoreProvider);
    await store.deleteProgressionRule(userId, exerciseId);
    await _publishRulesIfCurrent(userId, userScope, store);
  }

  bool _isCurrentUserScope(String userId, Object userScope) {
    return identical(_userScope, userScope) &&
        ref.read(currentUserIdProvider) == userId;
  }

  Future<void> _publishRulesIfCurrent(
    String userId,
    Object userScope,
    UserDataStore store,
  ) async {
    if (!_isCurrentUserScope(userId, userScope)) return;
    final rules = await store.getProgressionRules(userId);
    _requireProgressionRuleOwners(rules, userId);
    if (_isCurrentUserScope(userId, userScope)) {
      state = AsyncData(rules);
    }
  }
}

final progressionRuleForExerciseProvider =
    Provider.family<ProgressionRule?, String>((ref, exerciseId) {
      final rules = ref.watch(progressionRulesProvider).valueOrNull ?? [];
      return rules.where((r) => r.exerciseId == exerciseId).firstOrNull;
    });

final lastWorkoutLogForExerciseProvider =
    FutureProvider.family<WorkoutLog?, ({String exerciseId, DateTime before})>((
      ref,
      args,
    ) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId.isEmpty) return null;
      final log = await ref
          .watch(userDataStoreProvider)
          .getLastWorkoutLogForExercise(userId, args.exerciseId, args.before);
      if (log != null) {
        _requireOwner('WorkoutLog ${log.id}', userId, log.userId);
      }
      return log;
    });

/// Computes a progression suggestion for an exercise based on its enabled
/// rule and the most recent workout log before [before]. Returns null when no
/// enabled rule exists for the exercise.
final progressionSuggestionProvider =
    Provider.family<
      ProgressionSuggestion?,
      ({String exerciseId, DateTime before})
    >((ref, args) {
      final rule = ref.watch(
        progressionRuleForExerciseProvider(args.exerciseId),
      );
      if (rule == null || !rule.enabled) return null;
      final lastLog = ref
          .watch(lastWorkoutLogForExerciseProvider(args))
          .valueOrNull;
      return const ProgressionCalculator().calculate(
        lastLog: lastLog,
        rule: rule,
      );
    });

// ===== Training Programs =====
abstract interface class TrainingProgramStore {
  Future<List<TrainingProgram>> getTrainingPrograms(String userId);

  Future<void> saveTrainingProgram(String userId, TrainingProgram program);

  Future<void> deleteTrainingProgram(String userId, String programId);

  Future<void> setActiveTrainingProgram(
    String userId,
    String programId, {
    DateTime? activatedAt,
    required int? plannedCycleCount,
  });

  Future<void> endTrainingProgram(String userId, String programId);

  Future<TrainingProgram?> getActiveTrainingProgram(String userId);
}

class _AppDatabaseTrainingProgramStore implements TrainingProgramStore {
  final AppDatabase _database;

  const _AppDatabaseTrainingProgramStore(this._database);

  @override
  Future<List<TrainingProgram>> getTrainingPrograms(String userId) {
    return _database.getTrainingPrograms(userId);
  }

  @override
  Future<void> saveTrainingProgram(String userId, TrainingProgram program) {
    return _database.saveTrainingProgram(userId, program);
  }

  @override
  Future<void> deleteTrainingProgram(String userId, String programId) {
    return _database.deleteTrainingProgram(userId, programId);
  }

  @override
  Future<void> setActiveTrainingProgram(
    String userId,
    String programId, {
    DateTime? activatedAt,
    required int? plannedCycleCount,
  }) {
    return _database.setActiveTrainingProgram(
      userId,
      programId,
      activatedAt: activatedAt,
      plannedCycleCount: plannedCycleCount,
    );
  }

  @override
  Future<void> endTrainingProgram(String userId, String programId) {
    return _database.endTrainingProgram(userId, programId);
  }

  @override
  Future<TrainingProgram?> getActiveTrainingProgram(String userId) {
    return _database.getActiveTrainingProgram(userId);
  }
}

final trainingProgramStoreProvider = Provider<TrainingProgramStore>((ref) {
  return _AppDatabaseTrainingProgramStore(ref.watch(appDatabaseProvider));
});

final trainingProgramsProvider =
    AsyncNotifierProvider<TrainingProgramsNotifier, List<TrainingProgram>>(
      TrainingProgramsNotifier.new,
    );

class TrainingProgramsNotifier extends AsyncNotifier<List<TrainingProgram>> {
  Object _userScope = Object();

  @override
  Future<List<TrainingProgram>> build() async {
    _userScope = Object();
    final userId = ref.watch(currentUserIdProvider);
    final store = ref.watch(trainingProgramStoreProvider);
    return store.getTrainingPrograms(userId);
  }

  bool _canStartMutation(String userId, String? expectedUserId) {
    return userId.isNotEmpty &&
        (expectedUserId == null || expectedUserId == userId);
  }

  bool _isCurrentMutation(String userId, Object userScope) {
    return identical(_userScope, userScope) &&
        ref.read(currentUserIdProvider) == userId;
  }

  Future<void> _publishProgramsIfCurrent(
    String userId,
    Object userScope,
    TrainingProgramStore store,
  ) async {
    if (!_isCurrentMutation(userId, userScope)) return;
    final programs = await store.getTrainingPrograms(userId);
    if (_isCurrentMutation(userId, userScope)) {
      state = AsyncData(programs);
    }
  }

  Future<void> save(TrainingProgram program) async {
    final userId = ref.read(currentUserIdProvider);
    final userScope = _userScope;
    if (!_canStartMutation(userId, program.userId)) return;
    final store = ref.read(trainingProgramStoreProvider);
    await store.saveTrainingProgram(userId, program);
    await _publishProgramsIfCurrent(userId, userScope, store);
  }

  Future<void> delete(String programId, {String? expectedUserId}) async {
    final userId = ref.read(currentUserIdProvider);
    final userScope = _userScope;
    if (!_canStartMutation(userId, expectedUserId)) return;
    final store = ref.read(trainingProgramStoreProvider);
    await store.deleteTrainingProgram(userId, programId);
    await _publishProgramsIfCurrent(userId, userScope, store);
  }

  Future<void> setActive(
    String programId, {
    DateTime? activatedAt,
    required int? plannedCycleCount,
    String? expectedUserId,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    final userScope = _userScope;
    if (!_canStartMutation(userId, expectedUserId)) return;
    final store = ref.read(trainingProgramStoreProvider);
    await store.setActiveTrainingProgram(
      userId,
      programId,
      activatedAt: activatedAt,
      plannedCycleCount: plannedCycleCount,
    );
    await _publishProgramsIfCurrent(userId, userScope, store);
  }

  Future<void> end(String programId, {String? expectedUserId}) async {
    final userId = ref.read(currentUserIdProvider);
    final userScope = _userScope;
    if (!_canStartMutation(userId, expectedUserId)) return;
    final store = ref.read(trainingProgramStoreProvider);
    await store.endTrainingProgram(userId, programId);
    await _publishProgramsIfCurrent(userId, userScope, store);
  }

  Future<void> advanceDay({String? expectedUserId}) async {
    final userId = ref.read(currentUserIdProvider);
    final userScope = _userScope;
    if (!_canStartMutation(userId, expectedUserId)) return;
    final store = ref.read(trainingProgramStoreProvider);
    final program = await store.getActiveTrainingProgram(userId);
    if (program == null) return;
    if (program.isPausedNow()) return;
    if (!_isCurrentMutation(userId, userScope)) return;
    final advanced = program.advanceToNextDay();
    await store.saveTrainingProgram(userId, advanced);
    await _publishProgramsIfCurrent(userId, userScope, store);
  }
}

final activeTrainingProgramProvider = FutureProvider<TrainingProgram?>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  final programs = await ref.watch(trainingProgramsProvider.future);
  return activeTrainingProgramForUser(programs, userId);
});

final activeTrainingProgramForDateProvider =
    FutureProvider.family<TrainingProgram?, DateTime>((ref, date) async {
      final userId = ref.watch(currentUserIdProvider);
      final programs = await ref.watch(trainingProgramsProvider.future);
      return activeTrainingProgramForUser(programs, userId, date: date);
    });

/// Computes a list of [WorkoutPrescription]s for the given [date] based on
/// the active training program. Today's workout follows the completion-based
/// current day; other dates use the activation-date calendar projection.
/// Returns empty list when there is no active program, no current day, a rest
/// day, or an empty day.
/// Uses local-only storage — does not connect Supabase.
final workoutPrescriptionsForDateProvider =
    FutureProvider.family<List<WorkoutPrescription>, DateTime>((
      ref,
      date,
    ) async {
      final userId = ref.watch(currentUserIdProvider);
      final program = await ref.watch(
        activeTrainingProgramForDateProvider(date).future,
      );
      if (program == null) return [];
      if (program.userId != userId) return [];

      final day = program.programDayForWorkoutDate(date);
      if (day == null || day.kind == DayKind.rest) return [];

      final prescriptions = <WorkoutPrescription>[];
      final orderedExercises = [...day.exercises]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      for (final exercise in orderedExercises) {
        final lastLog = await AppDatabase.instance
            .getLastWorkoutLogForProgramExercise(
              userId,
              programId: program.id,
              programExerciseId: exercise.id,
              beforeDate: date,
            );
        final prescription = const ProgramPrescriptionCalculator().calculate(
          programExercise: exercise,
          programId: program.id,
          programDayId: day.id,
          lastLog: lastLog,
        );
        final daysSinceLastLog = lastLog == null
            ? null
            : _dateOnlyUtc(date).difference(_dateOnlyUtc(lastLog.date)).inDays;
        final previousLog = lastLog;
        prescriptions.add(
          previousLog != null &&
                  daysSinceLastLog != null &&
                  daysSinceLastLog > 7
              ? prescription.copyWith(
                  daysSinceLastLog: daysSinceLastLog,
                  lastLoggedSets: previousLog.sets,
                  lastLoggedReps: previousLog.reps,
                  lastLoggedWeightKg: previousLog.weightKg,
                )
              : prescription,
        );
      }
      return prescriptions;
    });

DateTime _dateOnlyUtc(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

// ===== Diet Logs =====
// ---- Diet Cache (in-memory, offline-ready) ----
class DietCacheNotifier extends StateNotifier<Map<String, List<DietLog>>> {
  final UserDataRemote _remote;
  final String _userId;
  bool _active = true;

  DietCacheNotifier(this._remote, this._userId) : super({});

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<DietLog> getLogsForDate(DateTime date) => state[_key(date)] ?? [];

  Future<void> loadDate(DateTime date) async {
    if (!_active || _userId.isEmpty) return;
    try {
      final logs = await _remote.getDietLogs(_userId, date);
      _requireDietLogOwners(logs, _userId);
      if (!_active) return;
      state = {...state, _key(date): logs};
    } on UserDataOwnerMismatchException {
      rethrow;
    } catch (_) {}
  }

  void addLog(DietLog log) {
    if (!_active || _userId.isEmpty) return;
    _requireOwner('DietLog ${log.id}', _userId, log.userId);
    final k = _key(log.date);
    final logs = List<DietLog>.from(state[k] ?? []);
    logs.add(log);
    state = {...state, k: logs};
  }

  void updateLog(DietLog updated) {
    if (!_active || _userId.isEmpty) return;
    _requireOwner('DietLog ${updated.id}', _userId, updated.userId);
    final k = _key(updated.date);
    final logs = List<DietLog>.from(state[k] ?? []);
    final idx = logs.indexWhere((l) => l.id == updated.id);
    if (idx >= 0) logs[idx] = updated;
    state = {...state, k: logs};
  }

  void deleteLog(String id, DateTime date) {
    if (!_active || _userId.isEmpty) return;
    final k = _key(date);
    final logs = List<DietLog>.from(state[k] ?? []);
    logs.removeWhere((l) => l.id == id);
    state = {...state, k: logs};
  }

  @override
  void dispose() {
    _active = false;
    super.dispose();
  }
}

final dietCacheProvider =
    StateNotifierProvider<DietCacheNotifier, Map<String, List<DietLog>>>(
      (ref) => DietCacheNotifier(
        ref.watch(userDataRemoteProvider),
        ref.watch(currentUserIdProvider),
      ),
    );

// ===== Foods =====
final foodListProvider = AsyncNotifierProvider<FoodListNotifier, List<Food>>(
  FoodListNotifier.new,
);

class FoodListNotifier extends AsyncNotifier<List<Food>> {
  @override
  Future<List<Food>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId.isEmpty) return [];
    final remote = ref.watch(userDataRemoteProvider);
    final store = ref.watch(userDataStoreProvider);

    try {
      if (ref.watch(isOnlineProvider)) {
        return await remote.getPublicFoods(userId);
      }
    } catch (_) {}

    return store.getFoods(userId);
  }
}

final searchFoodsProvider = Provider.family<List<Food>, String>((ref, query) {
  final foods = ref.watch(foodListProvider).valueOrNull ?? [];
  if (query.isEmpty) return foods;
  final lower = query.toLowerCase();
  return foods.where((f) => f.name.toLowerCase().contains(lower)).toList();
});

// ===== Daily Stats =====
final dailyCaloriesProvider = Provider.family<double, DateTime>((ref, date) {
  final cache = ref.watch(dietCacheProvider);
  final dateKey =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  final logs = cache[dateKey] ?? [];
  double total = 0;
  for (final log in logs) {
    total += log.calories;
  }
  return total;
});

final dailyMacrosProvider =
    Provider.family<({double protein, double carbs, double fat}), DateTime>((
      ref,
      date,
    ) {
      final cache = ref.watch(dietCacheProvider);
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final logs = cache[dateKey] ?? [];
      final foods = ref.read(foodListProvider).valueOrNull ?? [];
      double protein = 0, carbs = 0, fat = 0;
      for (final log in logs) {
        final food = foods.where((f) => f.id == log.foodId).firstOrNull;
        if (food != null) {
          final factor = log.grams / 100;
          protein += food.proteinPer100g * factor;
          carbs += food.carbsPer100g * factor;
          fat += food.fatPer100g * factor;
        }
      }
      return (protein: protein, carbs: carbs, fat: fat);
    });
