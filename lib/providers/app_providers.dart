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

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final currentUserIdProvider = StateProvider<String>((ref) {
  return Supabase.instance.client.auth.currentUser?.id ?? '';
});

final isOnlineProvider = StateProvider<bool>((ref) => true);

// Share nutrition plan with calendar for carb cycle markers
final nutritionCycleProvider = StateProvider<List<String>?>((ref) => null);
final nutritionStartDateProvider = StateProvider<DateTime?>((ref) => null);

// Track which dates have diet logs (for calendar green dots)
class DietDatesNotifier extends StateNotifier<Set<String>> {
  final SupabaseService _supabase;
  DietDatesNotifier(this._supabase) : super({});

  String _k(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void addDate(DateTime d) {
    state = {...state, _k(d)};
  }

  void loadMonth(int year, int month) async {
    try {
      final firstDay = DateTime(year, month, 1);

      final logs = await _supabase.getDietLogs(firstDay);
      for (final log in logs) {
        state = {...state, _k(log.date)};
      }
    } catch (_) {}
  }
}

final dietDatesProvider = StateNotifierProvider<DietDatesNotifier, Set<String>>(
  (ref) => DietDatesNotifier(ref.read(supabaseProvider)),
);

final isProProvider = StateNotifierProvider<IsProNotifier, bool>((ref) {
  final n = IsProNotifier();
  n.load();
  ref.listen(currentUserIdProvider, (_, __) => n.load());
  return n;
});

class IsProNotifier extends StateNotifier<bool> {
  IsProNotifier() : super(false);

  Future<void> load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (uid.isNotEmpty) {
      state = await AppDatabase.instance.getSubscriptionStatus(uid);
    }
  }

  Future<void> setPro(bool value) async {
    state = value;
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (uid.isNotEmpty) {
      await AppDatabase.instance.setSubscriptionStatus(uid, value);
    }
  }
}

// ===== Profile =====
final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(
      UserProfileNotifier.new,
    );

class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId.isEmpty) return null;

    final supabase = ref.read(supabaseProvider);
    try {
      final remote = await supabase.getProfile();
      if (remote != null) {
        await AppDatabase.instance.saveUserProfile(userId, remote);
        return remote;
      }
    } catch (_) {}

    return AppDatabase.instance.getUserProfile(userId);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final userId = ref.read(currentUserIdProvider);
    await AppDatabase.instance.saveUserProfile(userId, profile);

    try {
      await ref.read(supabaseProvider).upsertProfile(profile);
    } catch (_) {}

    state = AsyncData(profile);
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
  @override
  Future<List<Exercise>> build() async {
    final userId = ref.read(currentUserIdProvider);
    return AppDatabase.instance.getExercises(userId);
  }

  Future<void> addExercise(Exercise exercise) async {
    final userId = ref.read(currentUserIdProvider);
    await AppDatabase.instance.addExercise(userId, exercise);
    state = AsyncData(await AppDatabase.instance.getExercises(userId));
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
      try {
        return ref.read(supabaseProvider).getWorkoutLogs(date);
      } catch (_) {
        final userId = ref.read(currentUserIdProvider);
        return AppDatabase.instance.getWorkoutLogs(userId, date);
      }
    });

// ---- Workout Dates Cache (in-memory, offline-ready) ----
class WorkoutCacheNotifier extends StateNotifier<Map<String, Set<DateTime>>> {
  final SupabaseService _supabase;
  WorkoutCacheNotifier(this._supabase) : super({});

  String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  Set<DateTime> getDatesForMonth(DateTime month) {
    return state[_key(month)] ?? {};
  }

  void addDate(DateTime date) {
    final k = _key(date);
    state = {
      ...state,
      k: {...(state[k] ?? {}), DateTime(date.year, date.month, date.day)},
    };
  }

  Future<void> loadMonth(DateTime month) async {
    try {
      final logs = await _supabase.getWorkoutLogsForMonth(month);
      final dates = logs
          .map((l) => DateTime(l.date.year, l.date.month, l.date.day))
          .toSet();
      state = {...state, _key(month): dates};
    } catch (_) {}
  }

  Future<void> loadAll() async {
    final now = DateTime.now();
    for (int i = -3; i <= 3; i++) {
      final month = DateTime(now.year, now.month + i);
      await loadMonth(month);
    }
  }
}

final workoutCacheProvider =
    StateNotifierProvider<WorkoutCacheNotifier, Map<String, Set<DateTime>>>(
      (ref) => WorkoutCacheNotifier(ref.read(supabaseProvider)),
    );

class WorkoutLogCacheNotifier
    extends StateNotifier<Map<String, List<WorkoutLog>>> {
  final SupabaseService _supabase;
  WorkoutLogCacheNotifier(this._supabase) : super({});
  String _k(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  List<WorkoutLog> getLogs(DateTime d) => state[_k(d)] ?? [];
  Future<void> loadDate(DateTime d) async {
    try {
      final logs = await _supabase.getWorkoutLogs(d);
      state = {...state, _k(d): logs};
    } catch (_) {}
  }

  void addLogs(DateTime d, List<WorkoutLog> logs) {
    final k = _k(d);
    final e = List<WorkoutLog>.from(state[k] ?? []);
    e.addAll(logs);
    state = {...state, k: e};
  }
}

final workoutLogCacheProvider =
    StateNotifierProvider<
      WorkoutLogCacheNotifier,
      Map<String, List<WorkoutLog>>
    >((ref) => WorkoutLogCacheNotifier(ref.read(supabaseProvider)));

final workoutDatesForMonthProvider =
    FutureProvider.family<Set<DateTime>, DateTime>((ref, month) async {
      try {
        if (ref.read(isOnlineProvider)) {
          final remote = await ref
              .read(supabaseProvider)
              .getWorkoutLogsForMonth(month);
          return remote
              .map((l) => DateTime(l.date.year, l.date.month, l.date.day))
              .toSet();
        }
      } catch (_) {}
      final userId = ref.read(currentUserIdProvider);
      final local = await AppDatabase.instance.getWorkoutLogsForMonth(
        userId,
        month,
      );
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
  @override
  Future<List<ProgressionRule>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    return AppDatabase.instance.getProgressionRules(userId);
  }

  Future<void> save(ProgressionRule rule) async {
    final userId = ref.read(currentUserIdProvider);
    await AppDatabase.instance.saveProgressionRule(userId, rule);
    state = AsyncData(await AppDatabase.instance.getProgressionRules(userId));
  }

  Future<void> delete(String exerciseId) async {
    final userId = ref.read(currentUserIdProvider);
    await AppDatabase.instance.deleteProgressionRule(userId, exerciseId);
    state = AsyncData(await AppDatabase.instance.getProgressionRules(userId));
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
      return AppDatabase.instance.getLastWorkoutLogForExercise(
        userId,
        args.exerciseId,
        args.before,
      );
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
final trainingProgramsProvider =
    AsyncNotifierProvider<TrainingProgramsNotifier, List<TrainingProgram>>(
      TrainingProgramsNotifier.new,
    );

class TrainingProgramsNotifier extends AsyncNotifier<List<TrainingProgram>> {
  @override
  Future<List<TrainingProgram>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    return AppDatabase.instance.getTrainingPrograms(userId);
  }

  Future<void> save(TrainingProgram program) async {
    final userId = ref.read(currentUserIdProvider);
    await AppDatabase.instance.saveTrainingProgram(userId, program);
    state = AsyncData(await AppDatabase.instance.getTrainingPrograms(userId));
  }

  Future<void> delete(String programId) async {
    final userId = ref.read(currentUserIdProvider);
    await AppDatabase.instance.deleteTrainingProgram(userId, programId);
    state = AsyncData(await AppDatabase.instance.getTrainingPrograms(userId));
  }

  Future<void> setActive(String programId) async {
    final userId = ref.read(currentUserIdProvider);
    await AppDatabase.instance.setActiveTrainingProgram(userId, programId);
    state = AsyncData(await AppDatabase.instance.getTrainingPrograms(userId));
  }

  Future<void> advanceDay() async {
    final userId = ref.read(currentUserIdProvider);
    final program = await AppDatabase.instance.getActiveTrainingProgram(userId);
    if (program == null) return;
    if (program.isPausedNow()) return;
    final advanced = program.advanceToNextDay();
    await AppDatabase.instance.saveTrainingProgram(userId, advanced);
    state = AsyncData(await AppDatabase.instance.getTrainingPrograms(userId));
  }
}

final activeTrainingProgramProvider = Provider<TrainingProgram?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final programs = ref.watch(trainingProgramsProvider).valueOrNull ?? [];
  return activeTrainingProgramForUser(programs, userId);
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
      final program = ref.watch(activeTrainingProgramProvider);
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
        prescriptions.add(
          const ProgramPrescriptionCalculator().calculate(
            programExercise: exercise,
            programId: program.id,
            programDayId: day.id,
            lastLog: lastLog,
          ),
        );
      }
      return prescriptions;
    });

// ===== Diet Logs =====
// ---- Diet Cache (in-memory, offline-ready) ----
class DietCacheNotifier extends StateNotifier<Map<String, List<DietLog>>> {
  final SupabaseService _supabase;
  DietCacheNotifier(this._supabase) : super({});

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<DietLog> getLogsForDate(DateTime date) => state[_key(date)] ?? [];

  Future<void> loadDate(DateTime date) async {
    try {
      final logs = await _supabase.getDietLogs(date);
      state = {...state, _key(date): logs};
    } catch (_) {}
  }

  void addLog(DietLog log) {
    final k = _key(log.date);
    final logs = List<DietLog>.from(state[k] ?? []);
    logs.add(log);
    state = {...state, k: logs};
  }

  void updateLog(DietLog updated) {
    final k = _key(updated.date);
    final logs = List<DietLog>.from(state[k] ?? []);
    final idx = logs.indexWhere((l) => l.id == updated.id);
    if (idx >= 0) logs[idx] = updated;
    state = {...state, k: logs};
  }

  void deleteLog(String id, DateTime date) {
    final k = _key(date);
    final logs = List<DietLog>.from(state[k] ?? []);
    logs.removeWhere((l) => l.id == id);
    state = {...state, k: logs};
  }
}

final dietCacheProvider =
    StateNotifierProvider<DietCacheNotifier, Map<String, List<DietLog>>>(
      (ref) => DietCacheNotifier(ref.read(supabaseProvider)),
    );

// ===== Foods =====
final foodListProvider = AsyncNotifierProvider<FoodListNotifier, List<Food>>(
  FoodListNotifier.new,
);

class FoodListNotifier extends AsyncNotifier<List<Food>> {
  @override
  Future<List<Food>> build() async {
    final userId = ref.read(currentUserIdProvider);

    try {
      if (ref.read(isOnlineProvider)) {
        final remote = await ref.read(supabaseProvider).getPublicFoods();
        return remote;
      }
    } catch (_) {}

    return AppDatabase.instance.getFoods(userId);
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
