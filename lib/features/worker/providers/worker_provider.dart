import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import '../models/worker_profile_model.dart';
import '../repositories/worker_repository.dart';
import '../../../core/utils/location_utils.dart';

/// Provides a [WorkerRepository] bound to the Supabase client.
/// Returns null when the client is unavailable (e.g. before `Supabase.initialize`
/// in widget tests), so consumers can short-circuit without throwing.
final workerRepositoryProvider = Provider<WorkerRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : WorkerRepository(client);
});

/// Loads the current user's worker profile (null if they aren't a worker yet).
final myWorkerProfileProvider = FutureProvider<WorkerProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final repo = ref.watch(workerRepositoryProvider);
  if (repo == null) return null;
  return repo.getWorkerProfile(user.id);
});

/// Loads workers near the current device location (10 km radius).
final nearbyWorkersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(workerRepositoryProvider);
  if (repo == null) return [];
  final position = await LocationUtils.getCurrentLocation();
  return repo.getNearbyWorkers(
        position.latitude,
        position.longitude,
        10, // 10km radius
      );
});
