import 'supabase_service.dart';
import '../../data/repositories/app_database.dart';

class SyncService {
  final SupabaseService _supabase;
  final AppDatabase _local;

  SyncService._(this._supabase, this._local);
  static SyncService? _instance;

  static SyncService init(SupabaseService supabase, AppDatabase local) {
    _instance = SyncService._(supabase, local);
    return _instance!;
  }

  static SyncService get instance => _instance!;

  /// Pull latest data from Supabase and update local cache.
  /// Called on app resume and after writes.
  Future<void> pullLatest() async {
    if (_supabase.userId == null) return;

    final now = DateTime.now();
    final userId = _supabase.userId!;

    try {
      final remoteWorkouts = await _supabase.getWorkoutLogsForMonth(now);
      final remoteDiets = await _supabase.getDietLogs(now);

      if (remoteWorkouts.isNotEmpty) {
        await _local.saveWorkoutLogs(userId, remoteWorkouts);
      }
      if (remoteDiets.isNotEmpty) {
        await _local.saveDietLogs(userId, remoteDiets);
      }
    } catch (_) {}
  }

  /// Push any pending local writes that failed to sync.
  Future<void> pushPending() async {
    if (_supabase.userId == null) return;

    final userId = _supabase.userId!;

    final syncedWorkoutDeletes = <String>{};
    for (final id in await _local.getPendingWorkoutDeletes(userId)) {
      try {
        await _supabase.deleteWorkoutLog(id);
        syncedWorkoutDeletes.add(id);
      } catch (_) {}
    }
    await _local.removePendingWorkoutDeletes(userId, syncedWorkoutDeletes);

    final syncedDietDeletes = <String>{};
    for (final id in await _local.getPendingDietDeletes(userId)) {
      try {
        await _supabase.deleteDietLog(id);
        syncedDietDeletes.add(id);
      } catch (_) {}
    }
    await _local.removePendingDietDeletes(userId, syncedDietDeletes);

    final syncedWorkouts = <String>{};
    for (final log in await _local.getUnsyncedWorkoutLogs(userId)) {
      try {
        await _supabase.addWorkoutLog(log);
        syncedWorkouts.add(log.id);
      } catch (_) {}
    }
    await _local.removeUnsyncedWorkoutLogs(userId, syncedWorkouts);

    final syncedDiets = <String>{};
    for (final log in await _local.getUnsyncedDietLogs(userId)) {
      try {
        await _supabase.addDietLog(log);
        syncedDiets.add(log.id);
      } catch (_) {}
    }
    await _local.removeUnsyncedDietLogs(userId, syncedDiets);
  }

  /// Full two-way sync.
  Future<void> fullSync() async {
    await pushPending();
    await pullLatest();
  }
}
