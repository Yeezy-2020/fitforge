import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/exercise.dart';
import '../data/models/workout_log.dart';
import '../data/models/food.dart';
import '../data/models/diet_log.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/app_database.dart';
import '../core/services/supabase_service.dart';
import '../core/utils/nutrition_calculator.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);
final supabaseProvider = Provider<SupabaseService>((ref) => SupabaseService.instance);

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final currentUserIdProvider = StateProvider<String>((ref) {
  return Supabase.instance.client.auth.currentUser?.id ?? '';
});

final isOnlineProvider = StateProvider<bool>((ref) => true);

final isProProvider = StateProvider<bool>((ref) => false);

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
final nutritionPlanProvider = Provider<({
  double tdee,
  double protein,
  double carbs,
  double fat,
})?>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (profile == null) return null;
  return const NutritionCalculator().calculate(profile);
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
      final dates = logs.map((l) => DateTime(l.date.year, l.date.month, l.date.day)).toSet();
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

class WorkoutLogCacheNotifier extends StateNotifier<Map<String, List<WorkoutLog>>> {
  final SupabaseService _supabase;
  WorkoutLogCacheNotifier(this._supabase) : super({});
  String _k(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  List<WorkoutLog> getLogs(DateTime d) => state[_k(d)] ?? [];
  Future<void> loadDate(DateTime d) async {
    try { final logs = await _supabase.getWorkoutLogs(d); state = {...state, _k(d): logs}; } catch (_) {}
  }
  void addLogs(DateTime d, List<WorkoutLog> logs) {
    final k = _k(d); final e = List<WorkoutLog>.from(state[k] ?? []); e.addAll(logs); state = {...state, k: e};
  }
}

final workoutLogCacheProvider = StateNotifierProvider<WorkoutLogCacheNotifier, Map<String, List<WorkoutLog>>>(
  (ref) => WorkoutLogCacheNotifier(ref.read(supabaseProvider)),
);

final workoutDatesForMonthProvider =
    FutureProvider.family<Set<DateTime>, DateTime>((ref, month) async {
      try {
        if (ref.read(isOnlineProvider)) {
          final remote = await ref.read(supabaseProvider).getWorkoutLogsForMonth(month);
          return remote.map((l) => DateTime(l.date.year, l.date.month, l.date.day)).toSet();
        }
      } catch (_) {}
      final userId = ref.read(currentUserIdProvider);
      final local = await AppDatabase.instance.getWorkoutLogsForMonth(userId, month);
      return local.map((l) => DateTime(l.date.year, l.date.month, l.date.day)).toSet();
    });

// ===== Diet Logs =====
// ---- Diet Cache (in-memory, offline-ready) ----
class DietCacheNotifier extends StateNotifier<Map<String, List<DietLog>>> {
  final SupabaseService _supabase;
  DietCacheNotifier(this._supabase) : super({});

  String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
  final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  final logs = cache[dateKey] ?? [];
  double total = 0;
  for (final log in logs) {
    total += log.calories;
  }
  return total;
});

final dailyMacrosProvider = Provider.family<
  ({double protein, double carbs, double fat}),
  DateTime
>((ref, date) {
  final cache = ref.watch(dietCacheProvider);
  final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
