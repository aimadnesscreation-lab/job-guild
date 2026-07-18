import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/job_model.dart';

class JobRepository {
  final SupabaseClient _supabase;

  JobRepository(this._supabase);

  Future<void> createJob(Job job) async {
    await _supabase.from('jobs').insert(job.toJson());
  }

  Future<List<Job>> getNearbyJobs(double lat, double lng, double radiusKm) async {
    // PostGIS query via RPC or direct raw query if possible
    // For MVP, we can use a simple bounding box or a stored procedure
    final response = await _supabase.rpc('get_nearby_jobs', params: {
      'lat': lat,
      'lng': lng,
      'radius_km': radiusKm,
    });
    return (response as List).map((json) => Job.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> parseJobDescription(String description) async {
    // This calls a Supabase Edge Function that uses OpenRouter
    final response = await _supabase.functions.invoke(
      'bright-api',
      body: {'description': description},
    );
    return response.data;
  }
}
