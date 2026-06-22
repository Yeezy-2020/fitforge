import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/workout_log.dart';
import '../../data/models/food.dart';
import '../../data/models/diet_log.dart';
import '../../data/models/user_profile.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  String? get userId => _client.auth.currentUser?.id;

  Food _foodFromRow(Map<String, dynamic> r) => Food(
    id: r['id'] as String,
    name: r['name'] as String,
    caloriesPer100g: (r['calories_per_100g'] as num).toDouble(),
    proteinPer100g: (r['protein_per_100g'] as num).toDouble(),
    carbsPer100g: (r['carbs_per_100g'] as num).toDouble(),
    fatPer100g: (r['fat_per_100g'] as num).toDouble(),
    source: r['source'] as String?,
  );

  Map<String, dynamic> _workoutToRow(WorkoutLog w) => {
    'id': w.id,
    'user_id': userId,
    'exercise_id': w.exerciseId,
    'date': w.date.toIso8601String().substring(0, 10),
    'sets': w.sets,
    'reps': w.reps,
    'weight_kg': w.weightKg,
    'note': w.note,
  };

  WorkoutLog _workoutFromRow(Map<String, dynamic> r) => WorkoutLog(
    id: r['id'] as String,
    userId: r['user_id'] as String,
    exerciseId: r['exercise_id'] as String,
    date: DateTime.parse(r['date'] as String),
    sets: r['sets'] as int,
    reps: r['reps'] as int,
    weightKg: (r['weight_kg'] as num).toDouble(),
    note: r['note'] as String?,
    createdAt: r['created_at'] != null
        ? DateTime.parse(r['created_at'] as String)
        : null,
  );

  Map<String, dynamic> _dietToRow(DietLog d) => {
    'id': d.id,
    'user_id': userId,
    'food_id': d.foodId,
    'date': d.date.toIso8601String().substring(0, 10),
    'meal_type': d.mealType.name,
    'grams': d.grams,
    'calories': d.calories,
  };

  DietLog _dietFromRow(Map<String, dynamic> r) => DietLog(
    id: r['id'] as String,
    userId: r['user_id'] as String,
    foodId: r['food_id'] as String,
    date: DateTime.parse(r['date'] as String),
    mealType: MealType.values.firstWhere(
      (e) => e.name == r['meal_type'],
      orElse: () => MealType.lunch,
    ),
    grams: (r['grams'] as num).toDouble(),
    calories: (r['calories'] as num).toDouble(),
    createdAt: r['created_at'] != null
        ? DateTime.parse(r['created_at'] as String)
        : null,
  );

  UserProfile _profileFromRow(Map<String, dynamic> r) => UserProfile(
    id: r['id'] as String,
    email: r['email'] as String?,
    gender: Gender.values.firstWhere(
      (e) => e.name == r['gender'],
      orElse: () => Gender.male,
    ),
    age: r['age'] as int,
    heightCm: (r['height_cm'] as num).toDouble(),
    weightKg: (r['weight_kg'] as num).toDouble(),
    goal: FitnessGoal.values.firstWhere(
      (e) => e.name == r['goal'],
      orElse: () => FitnessGoal.maintain,
    ),
    bodyFatPct: r['body_fat_pct'] != null
        ? (r['body_fat_pct'] as num).toDouble()
        : null,
    displayName: r['display_name'] as String?,
  );

  // ---- Auth ----
  Future<void> signInAnonymously() async {
    await _client.auth.signInAnonymously();
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(
    String email,
    String password,
    UserProfile profile,
  ) async {
    await _client.auth.signUp(email: email, password: password);
    await upsertProfile(profile);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ---- Profile ----
  Future<UserProfile?> getProfile() async {
    final uid = userId;
    if (uid == null) return null;
    final data = await _client.from('profiles').select().eq('id', uid).single();
    return _profileFromRow(data);
  }

  Future<void> upsertProfile(UserProfile profile) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'gender': profile.gender.name,
      'age': profile.age,
      'height_cm': profile.heightCm,
      'weight_kg': profile.weightKg,
      'goal': profile.goal.name,
      'body_fat_pct': profile.bodyFatPct,
      'display_name': profile.displayName,
      'email': profile.email,
    });
  }

  // ---- Foods ----
  Future<List<Food>> searchFoods(String query) async {
    final response = await _client
        .from('foods')
        .select()
        .ilike('name', '%$query%')
        .limit(50);
    return (response as List).map((e) => _foodFromRow(e)).toList();
  }

  Future<List<Food>> getPublicFoods() async {
    final response = await _client
        .from('foods')
        .select()
        .filter('user_id', 'is', null)
        .order('name')
        .limit(100);
    return (response as List).map((e) => _foodFromRow(e)).toList();
  }

  // ---- Workout Logs ----
  Future<List<WorkoutLog>> getWorkoutLogs(DateTime date) async {
    final uid = userId;
    if (uid == null) return [];
    final dateStr = date.toIso8601String().substring(0, 10);
    final response = await _client
        .from('workout_logs')
        .select()
        .eq('user_id', uid)
        .eq('date', dateStr);
    return (response as List).map((e) => _workoutFromRow(e)).toList();
  }

  Future<List<WorkoutLog>> getWorkoutLogsForMonth(DateTime month) async {
    final uid = userId;
    if (uid == null) return [];
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final start = '$prefix-01';
    final end = '$prefix-31';
    final response = await _client
        .from('workout_logs')
        .select()
        .eq('user_id', uid)
        .gte('date', start)
        .lte('date', end);
    return (response as List).map((e) => _workoutFromRow(e)).toList();
  }

  Future<void> addWorkoutLog(WorkoutLog log) async {
    await _client.from('workout_logs').upsert(_workoutToRow(log));
  }

  Future<void> deleteWorkoutLog(String logId) async {
    await _client.from('workout_logs').delete().eq('id', logId);
  }

  // ---- Diet Logs ----
  Future<List<DietLog>> getDietLogs(DateTime date) async {
    final uid = userId;
    if (uid == null) return [];
    final dateStr = date.toIso8601String().substring(0, 10);
    final response = await _client
        .from('diet_logs')
        .select()
        .eq('user_id', uid)
        .eq('date', dateStr);
    return (response as List).map((e) => _dietFromRow(e)).toList();
  }

  Future<void> addDietLog(DietLog log) async {
    await _client.from('diet_logs').upsert(_dietToRow(log));
  }

  Future<void> deleteDietLog(String logId) async {
    await _client.from('diet_logs').delete().eq('id', logId);
  }

  // ---- Subscription ----
  Future<bool> getSubscriptionStatus() async {
    final uid = userId;
    if (uid == null) return false;
    final response = await _client
        .from('subscriptions')
        .select('tier')
        .eq('user_id', uid)
        .single();
    final tier = response['tier'] as String;
    return tier == 'pro_monthly' || tier == 'pro_yearly';
  }
}
