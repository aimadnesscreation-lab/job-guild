import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/worker_profile_model.dart';

class WorkerRepository {
  final SupabaseClient _supabase;

  WorkerRepository(this._supabase);

  Future<WorkerProfile?> getWorkerProfile(String userId) async {
    final response = await _supabase
        .from('worker_profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    
    if (response == null) return null;
    return WorkerProfile.fromJson(response);
  }

  Future<void> updateWorkerProfile(String userId, WorkerProfile profile) async {
    await _supabase.from('worker_profiles').upsert({
      'id': userId,
      ...profile.toJson(),
    });
  }

  Future<String> generateBio(String rawDescription) async {
    final response = await _supabase.functions.invoke(
      'rapid-worker',
      body: {'description': rawDescription},
    );
    return response.data['bio'];
  }

  Future<List<Map<String, dynamic>>> getNearbyWorkers(double lat, double lng, double radiusKm) async {
    final response = await _supabase.rpc('get_nearby_workers', params: {
      'lat': lat,
      'lng': lng,
      'radius_km': radiusKm,
    });
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<WorkerProfile>> searchWorkers({
    int? categoryId,
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    // Basic search implementation
    var query = _supabase.from('worker_profiles').select();
    
    // In a real app, we'd use PostGIS for location filtering here
    // For now, return all workers
    final List response = await query;
    return response.map((json) => WorkerProfile.fromJson(json)).toList();
  }
}
