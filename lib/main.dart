import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/services/supabase_service.dart';
import 'core/services/sync_service.dart';
import 'data/repositories/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
  );

  SyncService.init(SupabaseService.instance, AppDatabase.instance);

  runApp(
    const ProviderScope(
      child: FitForgeApp(),
    ),
  );
}
