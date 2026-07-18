import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import '../models/worker_profile_model.dart';
import '../repositories/worker_repository.dart';
import '../../../core/utils/location_utils.dart';

part 'worker_provider.g.dart';

@riverpod
WorkerRepository workerRepository(WorkerRepositoryRef ref) {
  final client = ref.watch(supabaseClientProvider);
  return WorkerRepository(client);
}

@riverpod
Future<WorkerProfile?> myWorkerProfile(MyWorkerProfileRef ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value(null);
  return ref.watch(workerRepositoryProvider).getWorkerProfile(user.id);
}

@riverpod
Future<List<Map<String, dynamic>>> nearbyWorkers(NearbyWorkersRef ref) async {
  final position = await LocationUtils.getCurrentLocation();
  return ref.watch(workerRepositoryProvider).getNearbyWorkers(
    position.latitude,
    position.longitude,
    10, // 10km radius
  );
}
