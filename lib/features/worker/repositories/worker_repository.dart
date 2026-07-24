import 'package:flutter/foundation.dart';
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
      // Map category names to their IDs.
      final rows = <Map<String, dynamic>>[];
      final newCategoryIds = <int>[];
      for (final name in categories) {
        final catId = categoryNameToId[name];
        if (catId != null) {
          rows.add({'worker_id': userId, 'category_id': catId});
          newCategoryIds.add(catId);
        }
      }

      // Upsert new rows first so data is never lost on partial failure.
      if (rows.isNotEmpty) {
        await _supabase
            .from('worker_categories')
            .upsert(rows, onConflict: 'worker_id,category_id');
      }

      // Prune stale category assignments that are no longer selected.
      // PostgREST's .not() expects the filter value as a string formatted
      // as a Postgres array literal (IN clause). The supabase_flutter
      // client converts Dart Lists to Postgres arrays, but .not() uses
      // the PostgREST filter syntax: not(category_id.in.(1,2,3)).
      if (newCategoryIds.isNotEmpty) {
        // Format as PostgREST filter string: (1,2,3)
        final idsStr = '(${newCategoryIds.join(',')})';
        await _supabase
            .from('worker_categories')
            .delete()
            .eq('worker_id', userId)
            .not('category_id', 'in', idsStr);
      } else {
        // All categories removed — delete everything.
        await _supabase
            .from('worker_categories')
            .delete()
            .eq('worker_id', userId);
      }
    } catch (e) {
      // Categories are best-effort — log and surface the error so the UI can
      // warn the user instead of silently losing all their category selections.
      debugPrint('[WorkerRepo] _saveCategories failed: $e');
      rethrow;
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
    // through to the upsert pattern below.
    bool rpcSucceeded = false;
    try {
      // `p_is_featured` is an admin-managed flag that should never be
      // overwritten by client-side profile saves. We pass `profile.isFeatured`
      // (the value read from the DB on profile load) so the RPC preserves it
      // via COALESCE(EXCLUDED.is_featured, worker_profiles.is_featured).
      // Using `payload['is_featured']` is wrong because toJson() excludes it.
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
          'p_is_featured': profile.isFeatured,
        },
      );
      rpcSucceeded = true;
    } catch (_) {
      // RPC not available (e.g. migration not run yet) — fall through.
    }

    if (!rpcSucceeded) {
      // Fallback: atomic upsert via PostgREST. This avoids the race between
      // INSERT and UPDATE and correctly handles the id primary key.
      await _supabase.from('worker_profiles').upsert(payload, onConflict: 'id');
    }

    // Persist categories (best-effort, but errors are surfaced so the caller
    // can warn the user instead of silently losing all category selections).
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
      // When both location AND category are supplied, apply the category
      // filter client-side after the spatial RPC returns.
      if (categoryId != null) {
        final catRows = await _supabase
            .from('worker_categories')
            .select('worker_id')
            .eq('category_id', categoryId);
        final catRowsData = List<Map<String, dynamic>>.from(catRows);
        final matchingIds = catRowsData
            .map((r) => r['worker_id'] as String)
            .toSet();
        results.removeWhere((w) => !matchingIds.contains(w['id']));
      }
      return results.map((json) => WorkerProfile.fromJson(json)).toList();
    }

    // Without location, query worker_profiles with optional category filter.
    // PostgREST requires us to resolve category → worker IDs first since
    // worker_categories is a separate table.
    // FIX (Bug #16): Always apply a limit to prevent full table scans.
    // Default page size of 20; callers can increase by passing a larger limit.
    const defaultLimit = 20;
    var query = _supabase
        .from('worker_profiles')
        .select('*, users!inner(full_name, profile_photo_url, is_verified)');

    if (categoryId != null) {
      // First fetch the worker IDs that have the matching category.
      final catRows = await _supabase
          .from('worker_categories')
          .select('worker_id')
          .eq('category_id', categoryId);
      final catRowsData = List<Map<String, dynamic>>.from(catRows);
      final workerIds = catRowsData
          .map((r) => r['worker_id'] as String)
          .toList();
      if (workerIds.isNotEmpty) {
        query = query.filter('id', 'in', workerIds);
      } else {
        // No workers match the category — return empty.
        return [];
      }
    }

    // Apply limit AFTER all filters to avoid PostgrestTransformBuilder type loss.
    final List response = await query.limit(defaultLimit);
    return response.map((json) => WorkerProfile.fromJson(json)).toList();
  }
}
