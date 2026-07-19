import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import '../models/worker_profile_model.dart';
import '../repositories/worker_repository.dart';
import '../../../core/utils/location_utils.dart';

/// Provides a [WorkerRepository] bound to the Supabase client.
final workerRepositoryProvider = Provider<WorkerRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return WorkerRepository(client);
});

/// Loads the current user's worker profile (null if they aren't a worker yet).
final myWorkerProfileProvider = FutureProvider<WorkerProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(workerRepositoryProvider).getWorkerProfile(user.id);
});

/// Loads workers near the current device location (10 km radius).
final nearbyWorkersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final position = await LocationUtils.getCurrentLocation();
  return ref.watch(workerRepositoryProvider).getNearbyWorkers(
        position.latitude,
        position.longitude,
        10, // 10km radius
      );
});
