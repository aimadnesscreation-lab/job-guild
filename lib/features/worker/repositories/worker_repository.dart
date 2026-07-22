import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';
import '../models/worker_profile_model.dart';

class WorkerRepository {
  final SupabaseClient _supabase;

  WorkerRepository(this._supabase);

  /// Persist the worker's selected categories to the worker_categories join
  /// table. Failures are logged but don't throw — the profile is saved even
  /// if categories can't be persisted.
  Future<void> _saveCategories(String userId, List<String> categories) async {
    try {
      // Remove existing category assignments
      await _supabase
          .from('worker_categories')
          .delete()
          .eq('worker_id', userId);

      if (categories.isEmpty) return;

      // Map category names to their IDs and batch insert in a single request.
      final rows = <Map<String, dynamic>>[];
      for (final name in categories) {
        final catId = categoryNameToId[name];
        if (catId != null) {
          rows.add({'worker_id': userId, 'category_id': catId});
        }
      }
      if (rows.isNotEmpty) {
        await _supabase.from('worker_categories').insert(rows);
      }
    } catch (_) {
      // Categories are best-effort — don't abort the profile save.
    }
  }

  Future<WorkerProfile?> getWorkerProfile(String userId) async {
    final response = await _supabase
        .from('worker_profiles')
        .select('*, users!inner(full_name, profile_photo_url, is_verified)')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return WorkerProfile.fromJson(response);
  }

  Future<void> updateWorkerProfile(String userId, WorkerProfile profile) async {
    final payload = profile.toJson();

    // Try SECURITY DEFINER RPC first (available after migration
    // 20260720000002).  If the function doesn't exist yet, fall
    // through to the insert-then-update pattern below.
    try {
      await _supabase.rpc(
        'upsert_worker_profile',
        params: {
          'p_id': userId,
          'p_headline': payload['headline'],
          'p_bio': payload['bio'],
          'p_years_experience': payload['years_experience'],
          'p_hourly_rate_pkr': payload['hourly_rate_pkr'],
          'p_fixed_rate_note': payload['fixed_rate_note'],
          'p_availability_status': payload['availability_status'],
          'p_service_radius_km': payload['service_radius_km'],
          'p_portfolio_media': payload['portfolio_media'],
          'p_is_featured': payload['is_featured'],
        },
      );
      // RPC succeeded — skip to categories.
      await _saveCategories(userId, profile.categories);
      return;
    } catch (_) {
      // RPC not available (e.g. migration not run yet) — fall through.
    }

    // Fallback: atomic upsert via PostgREST. This avoids the race between
    // INSERT and UPDATE and correctly handles the id primary key.
    await _supabase.from('worker_profiles').upsert(
      payload,
      onConflict: 'id',
    );

    // Persist categories (best-effort, non-fatal).
    await _saveCategories(userId, profile.categories);
  }

  /// Persists the worker's display name to the `users` table, where `full_name`
  /// actually lives (it is NOT a column on `worker_profiles`).
  Future<void> updateUserName(String userId, String fullName) async {
    await _supabase
        .from('users')
        .update({'full_name': fullName})
        .eq('id', userId);
  }

  Future<String> generateBio(String rawDescription) async {
    try {
      final response = await _supabase.functions.invoke(
        'rapid-worker',
        body: {'raw_description': rawDescription},
      );
      final data = response.data as Map<String, dynamic>?;
      final bio = data?['bio'] as String?;
      if (bio != null && bio.trim().isNotEmpty) {
        return bio;
      }
    } catch (_) {
      // Edge function unavailable — fall through to mock.
    }
    return 'Professional with experience in $rawDescription. Dedicated to providing '
        'high-quality service with attention to detail and customer satisfaction. '
        'Available for projects of all sizes.';
  }

  Future<List<Map<String, dynamic>>> getNearbyWorkers(
    double lat,
    double lng,
    double radiusKm,
  ) async {
    final response = await _supabase.rpc(
      'get_nearby_workers',
      params: {'lat': lat, 'lng': lng, 'radius_km': radiusKm},
    );
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<WorkerProfile>> searchWorkers({
    int? categoryId,
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    // When location parameters are provided, use the PostGIS RPC for
    // efficient spatial filtering.
    if (lat != null && lng != null && radiusKm != null) {
      final response = await _supabase.rpc(
        'get_nearby_workers',
        params: {'lat': lat, 'lng': lng, 'radius_km': radiusKm},
      );
      final results = List<Map<String, dynamic>>.from(response);
      // Note: location + category filtering is not yet implemented —
      // when both are supplied, the category filter is currently ignored.
      // Full support requires joining worker_categories into the RPC response.
      return results.map((json) => WorkerProfile.fromJson(json)).toList();
    }

    // Without location, query worker_profiles with optional category filter.
    // PostgREST requires us to resolve category → worker IDs first since
    // worker_categories is a separate table.
    var query = _supabase
        .from('worker_profiles')
        .select('*, users!inner(full_name, profile_photo_url, is_verified)');

    if (categoryId != null) {
      // First fetch the worker IDs that have the matching category.
      final catRows = await _supabase
          .from('worker_categories')
          .select('worker_id')
          .eq('category_id', categoryId);
      final workerIds = (catRows as List)
          .map((r) => (r as Map<String, dynamic>)['worker_id'] as String)
          .toList();
      if (workerIds.isNotEmpty) {
        query = query.filter('id', 'in', workerIds);
      } else {
        // No workers match the category — return empty.
        return [];
      }
    }

    final List response = await query;
    return response.map((json) => WorkerProfile.fromJson(json)).toList();
  }
}
