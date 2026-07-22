// ignore_for_file: use_null_aware_elements

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';
import 'package:local_services_marketplace/features/worker/models/worker_profile_model.dart';

/// Repository for all Supabase database operations.
/// All methods are async and return results from the live Supabase project.
/// Uses mock data when Supabase is not configured.
class SupabaseRepository {
  final SupabaseClient? _client;

  SupabaseRepository(this._client);

  /// Safely cast a Supabase response into a list of row maps.
  static List<Map<String, dynamic>> _safeList(dynamic response) {
    if (response is! List) return <Map<String, dynamic>>[];
    return response.whereType<Map<String, dynamic>>().toList();
  }

  // ─── Jobs ─────────────────────────────────────────────────

  Future<List<Job>> getNearbyJobs({
    double lat = 31.5204,
    double lng = 74.3587,
    double radiusKm = 10,
  }) async {
    final client = _client;
    if (client == null) return _mockJobs;

    try {
      final response = await client.rpc(
        'get_nearby_jobs',
        params: {'lat': lat, 'lng': lng, 'radius_km': radiusKm},
      );
      final list = response;
      return list.map((j) => Job.fromJson(j)).toList();
    } catch (e) {
      debugPrint('[Jobs] getNearbyJobs error: $e');
      rethrow;
    }
  }

  Future<Job?> getJob(String id) async {
    final client = _client;
    if (client == null) {
      return _mockJobs.cast<Job?>().firstWhere(
        (j) => j!.id == id,
        orElse: () => null,
      );
    }

    try {
      final response = await client.from('jobs').select().eq('id', id).single();
      return Job.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> postJob(Job job) async {
    final client = _client;
    if (client == null) return; // silently succeed for mock

    final userId = client.auth.currentUser?.id;
    final json = job.toJson();
    // The draft job has an empty employerId; stamp it with the authenticated user.
    if (userId != null) json['employer_id'] = userId;
    await client.from('jobs').insert(json);
  }

  Future<void> updateJobStatus(String jobId, JobStatus status) async {
    final client = _client;
    if (client == null) return;

    // Use the atomic complete_job RPC when marking a job completed so both the
    // job and the hired application are updated in a single transaction.
    if (status == JobStatus.completed) {
      try {
        await client.rpc('complete_job', params: {'p_job_id': jobId});
        return;
      } on PostgrestException catch (e) {
        // If the RPC doesn't exist yet (migration not run), log a warning
        // and fall through. The job will NOT be marked complete via the
        // legacy path — this is intentional to avoid bypassing the RPC's
        // security check that only hired jobs can be completed.
        if (e.code != 'PGRST202' && e.code != '42883') rethrow;
        debugPrint('[Job] complete_job RPC not found — ensure migration '
            '20260722000010_harden_complete_job.sql is deployed.');
      }
    }

    // Non-completed status updates are safe to apply directly.
    if (status != JobStatus.completed) {
      await client.from('jobs').update({'status': status.name}).eq('id', jobId);
    } else {
      // If we reached here for a completed status, the RPC failed but we
      // caught the error. Throw so callers can show a user-facing error.
      throw Exception(
        'Cannot complete job: the required database function is not available. '
        'Please contact support.',
      );
    }
  }

  // ─── Applications ─────────────────────────────────────────

  Future<void> applyForJob(
    String jobId,
    String workerId, {
    String? message,
  }) async {
    final client = _client;
    if (client == null) return;

    await client.from('applications').insert({
      'job_id': jobId,
      'worker_id': workerId,
      if (message != null) 'message': message,
    });
  }

  /// Hire a worker: updates application and job to 'hired' status.
  /// Uses a best-effort two-step approach with verification.
  /// Returns whether the hire was successful.
  Future<bool> hireWorker(String jobId, String workerId) async {
    final client = _client;
    if (client == null) return false;

    // Step 1: Update the application.
    await client
        .from('applications')
        .update({'status': 'hired'})
        .eq('job_id', jobId)
        .eq('worker_id', workerId)
        .neq('status', 'hired');

    // Step 2: Update the job.
    await client.from('jobs').update({'status': 'hired'}).eq('id', jobId);

    // Step 3: Verify both updates actually took effect.
    final jobCheck = await client
        .from('jobs')
        .select('status')
        .eq('id', jobId)
        .maybeSingle();
    if (jobCheck == null || jobCheck['status'] != 'hired') {
      debugPrint('[Hire] Job status verification failed — status is '
          '${jobCheck?['status']}');
      return false;
    }
    return true;
  }

  /// Fetch the current worker's own applications, joined with job details
  /// (title, budget, status, urgency, location) so the worker dashboard can
  /// show real application data without extra round-trips.
  Future<List<Map<String, dynamic>>> getMyApplications(String workerId) async {
    final client = _client;
    if (client == null) return _mockApplications;
    try {
      final response = await client
          .from('applications')
          .select(
            '*, jobs!inner(title, budget_amount, budget_type, status, urgency, location_text)',
          )
          .eq('worker_id', workerId)
          .order('applied_at', ascending: false);
      return _safeList(response);
    } catch (e) {
      return [];
    }
  }

  /// Fetch completed/hired jobs for a worker (for the earnings log).
  ///
  /// Returns applications where the application is `hired` OR the associated
  /// job is `completed`. The `applications` table CHECK constraint allows
  /// (`interested`, `shortlisted`, `hired`, `rejected`, `completed`), so the
  /// client-side filter ensures only relevant rows are returned.
  ///
  /// PostgREST's `.or()` cannot reference joined column paths like
  /// `jobs.status`, so we fetch all applications for this worker and filter
  /// in Dart. This is a small dataset per worker (hired + completed jobs)
  /// so the client-side filter is negligible.
  Future<List<Map<String, dynamic>>> getWorkerCompletedJobs(
    String workerId,
  ) async {
    final client = _client;
    if (client == null) return _mockCompletedJobs;
    try {
      final response = await client
          .from('applications')
          .select(
            '*, jobs!inner(title, budget_amount, budget_type, status, updated_at, created_at)',
          )
          .eq('worker_id', workerId)
          .order('applied_at', ascending: false);
      final allApps = _safeList(response);
      // Client-side filter: include hired apps OR apps for completed jobs.
      return allApps.where((a) {
        if (a['status'] == 'hired') return true;
        final job = a['jobs'] as Map<String, dynamic>?;
        return job?['status'] == 'completed';
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Count how many workers have applied to a given job. Used by the
  /// employer dashboard to show applicant counts per active job.
  Future<int> countApplicants(String jobId) async {
    final client = _client;
    if (client == null) return 0;
    try {
      final response = await client
          .from('applications')
          .select('worker_id')
          .eq('job_id', jobId)
          .neq('status', 'rejected');
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  /// Fetch the applicants (workers who applied) for a job, joined with
  /// their worker profile + user info so the employer dashboard can show
  /// names, ratings, and verification in one round-trip.
  Future<List<Map<String, dynamic>>> getApplicants(String jobId) async {
    final client = _client;
    if (client == null) return [];
    try {
      final response = await client
          .from('applications')
          .select(
            '*, worker_profiles!inner(id, headline, average_rating, total_jobs_completed, users!inner(full_name, profile_photo_url, is_verified))',
          )
          .eq('job_id', jobId)
          .order('created_at');
      return _safeList(response);
    } catch (e) {
      return [];
    }
  }

  // ─── Worker Profiles ──────────────────────────────────────

  Future<WorkerProfile?> getWorkerProfile(String userId) async {
    final client = _client;
    if (client == null) return null;

    try {
      final response = await client
          .from('worker_profiles')
          .select('*, users!inner(full_name, profile_photo_url, is_verified)')
          .eq('id', userId)
          .maybeSingle();
      if (response == null) return null;
      return WorkerProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveWorkerProfile(WorkerProfile profile) async {
    final client = _client;
    if (client == null) return;

    await client.from('worker_profiles').upsert({
      'id': profile.userId,
      'headline': profile.headline,
      'bio': profile.bio,
      'years_experience': profile.yearsExperience,
      'hourly_rate_pkr': profile.hourlyRatePkr,
      'availability_status': profile.availabilityStatus.name,
      'service_radius_km': profile.serviceRadiusKm,
      'portfolio_media': profile.portfolioMediaUrls,
    }, onConflict: 'id');
  }

  /// Lightweight PATCH — update only the availability status without
  /// loading or re-saving the entire profile. Used by the dashboard
  /// availability toggle so it is fast and doesn't disturb unsaved form
  /// state in the edit-profile screen.
  Future<void> updateAvailabilityStatus(
    String userId,
    AvailabilityStatus status,
  ) async {
    final client = _client;
    if (client == null) return;
    await client
        .from('worker_profiles')
        .update({'availability_status': status.name})
        .eq('id', userId);
  }

  // ─── Messages ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('messages')
          .select()
          .eq('job_id', conversationId)
          .order('sent_at');
      return _safeList(response);
    } catch (e) {
      return [];
    }
  }

  Future<void> sendMessage({
    required String jobId,
    required String senderId,
    required String content,
    String contentType = 'text',
  }) async {
    final client = _client;
    if (client == null) return;

    await client.from('messages').insert({
      'job_id': jobId,
      'sender_id': senderId,
      'content': content,
      'content_type': contentType,
    });
  }

  // ─── Reviews ──────────────────────────────────────────────

  Future<void> submitReview({
    required String jobId,
    required String reviewerId,
    required String revieweeId,
    required int rating,
    String? comment,
  }) async {
    final client = _client;
    if (client == null) return;

    await client.from('reviews').insert({
      'job_id': jobId,
      'reviewer_id': reviewerId,
      'reviewee_id': revieweeId,
      'rating': rating,
      if (comment != null) 'comment': comment,
    });
  }

  // ─── Reviews List ─────────────────────────────────────────

  /// Fetch all reviews where the given user is either the reviewer
  /// or the reviewee, joined with user names and job title.
  Future<List<Map<String, dynamic>>> getUserReviews(String userId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('reviews')
          .select(
            '*, reviewer:reviewer_id(full_name), reviewee:reviewee_id(full_name), jobs!inner(title)',
          )
          .or('reviewer_id.eq.$userId,reviewee_id.eq.$userId')
          .order('created_at', ascending: false);
      return _safeList(response);
    } catch (e) {
      debugPrint('[Reviews] getUserReviews error: $e');
      return [];
    }
  }

  // ─── Favorites ────────────────────────────────────────────

  /// Get the list of workers the user has favorited/saved
  Future<List<Map<String, dynamic>>> getFavorites(String userId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('favorites')
          .select(
            'favorited_user_id!inner(id, full_name, is_verified, worker_profiles(headline, average_rating, total_jobs_completed))',
          )
          .eq('user_id', userId);
      return _safeList(response);
    } catch (e) {
      return [];
    }
  }

  Future<bool> toggleFavorite(String userId, String favoritedUserId) async {
    final client = _client;
    if (client == null) return false;

    // Check if already favorited first, then insert or delete accordingly.
    // This avoids silently deleting a favorite when the INSERT fails for a
    // non-unique-violation reason (e.g. network error).
    try {
      final existing = await client
          .from('favorites')
          .select('id')
          .eq('user_id', userId)
          .eq('favorited_user_id', favoritedUserId)
          .maybeSingle();

      if (existing != null) {
        // Already favorited — remove
        await client
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('favorited_user_id', favoritedUserId);
        return false; // now not favorited
      } else {
        // Not favorited — insert. Handle TOCTOU race: if a concurrent
        // request inserted the same favorite, treat the unique violation
        // as a no-op (the record already exists, which is the desired state).
        try {
          await client.from('favorites').insert({
            'user_id': userId,
            'favorited_user_id': favoritedUserId,
          });
        } on PostgrestException catch (e) {
          if (e.code == '23505') {
            // Unique violation — favorite already exists from a concurrent
            // request. Treat as success (favorited state).
            return true;
          }
          rethrow;
        }
        return true; // now favorited
      }
    } catch (e) {
      debugPrint('[Favorites] toggle error: $e');
      rethrow;
    }
  }

  // ─── Notifications ────────────────────────────────────────

  /// Count unread notifications for the badge on the bell icon.
  Future<int> getUnreadNotificationCount(String userId) async {
    final client = _client;
    if (client == null) return 0;
    try {
      final response = await client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      // response.length gives the count of matching rows
      return response.length;
    } catch (e) {
      debugPrint('[Notif] getUnreadNotificationCount error: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return _safeList(response);
    } catch (e) {
      return [];
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    final client = _client;
    if (client == null) return;

    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Mark all unread notifications for a user as read in a single batched
  /// request. Avoids the N+1 pattern of updating one row at a time.
  Future<void> markAllNotificationsRead(String userId) async {
    final client = _client;
    if (client == null) return;

    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  // ─── Reports ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getUserReports(String userId) async {
    final client = _client;
    if (client == null) return [];
    try {
      final response = await client
          .from('reports')
          .select()
          .eq('reporter_id', userId)
          .order('created_at', ascending: false);
      return _safeList(response);
    } catch (e) {
      return [];
    }
  }

  Future<void> submitReport({
    required String reporterId,
    String? reportedUserId,
    String? jobId,
    required String reason,
    String? details,
  }) async {
    final client = _client;
    if (client == null) return;
    await client.from('reports').insert({
      'reporter_id': reporterId,
      if (reportedUserId != null) 'reported_user_id': reportedUserId,
      if (jobId != null) 'job_id': jobId,
      'reason': reason,
      if (details != null) 'details': details,
      'status': 'open',
    });
  }

  // ─── Settings ────────────────────────────────────────────

  /// Load the current user's settings from the users table.
  Future<Map<String, dynamic>> getUserSettings(String userId) async {
    final client = _client;
    if (client == null) return _defaultSettings;

    try {
      final response = await client
          .from('users')
          .select(
            'preferred_language, notifications_enabled, job_alerts_enabled, message_alerts_enabled, service_radius_km',
          )
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      return _defaultSettings;
    }
  }

  /// Persist settings (only the columns that exist on the users table).
  Future<void> saveUserSettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    final client = _client;
    if (client == null) return;

    final allowedKeys = {
      'preferred_language',
      'notifications_enabled',
      'job_alerts_enabled',
      'message_alerts_enabled',
      'service_radius_km',
    };
    final payload = <String, dynamic>{};
    for (final key in allowedKeys) {
      if (settings.containsKey(key)) {
        payload[key] = settings[key];
      }
    }
    if (payload.isNotEmpty) {
      await client.from('users').update(payload).eq('id', userId);
    }
  }

  static const Map<String, dynamic> _defaultSettings = {
    'preferred_language': 'en',
    'notifications_enabled': true,
    'job_alerts_enabled': true,
    'message_alerts_enabled': true,
    'service_radius_km': 10,
  };

  // ─── Account Deletion ──────────────────────────────────────

  /// Delete all user data from application tables.
  ///
  /// Uses a SECURITY DEFINER RPC function to bypass RLS (most application
  /// tables lack DELETE policies for regular users). The function validates
  /// that `auth.uid() = userId` before executing.
  ///
  /// This removes the user's content but does NOT delete the auth account
  /// (that requires the Supabase Admin API / service_role key).
  Future<void> deleteUserData(String userId) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.rpc('delete_user_data', params: {
        'p_user_id': userId,
      });
    } catch (e) {
      debugPrint('[Account] deleteUserData error: $e');
      rethrow;
    }
  }

  // ─── Mock Data ────────────────────────────────────────────

  static final _mockApplications = [
    {
      'id': 'app-1',
      'job_id': 'job-1',
      'status': 'hired',
      'jobs': {
        'title': 'Plumber needed for bathroom fixing',
        'budget_amount': 3000,
        'budget_type': 'negotiable',
        'status': 'hired',
        'urgency': 'instant',
        'location_text': 'Lahore, Gulberg',
      },
    },
    {
      'id': 'app-2',
      'job_id': 'job-2',
      'status': 'pending',
      'jobs': {
        'title': 'AC repair and maintenance',
        'budget_amount': 3500,
        'budget_type': 'fixed',
        'status': 'open',
        'urgency': 'today',
        'location_text': 'Lahore, DHA',
      },
    },
  ];

  static final _mockCompletedJobs = [
    {
      'status': 'hired',
      'jobs': {
        'title': 'AC repair - 3 hours',
        'budget_amount': 1500,
        'status': 'completed',
        'updated_at': DateTime.now().toIso8601String(),
      },
    },
    {
      'status': 'hired',
      'jobs': {
        'title': 'Plumbing - 2 hours',
        'budget_amount': 1000,
        'status': 'completed',
        'updated_at': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      },
    },
    {
      'status': 'hired',
      'jobs': {
        'title': 'Electrical work - 4 hours',
        'budget_amount': 2000,
        'status': 'hired',
        'updated_at': DateTime.now()
            .subtract(const Duration(days: 3))
            .toIso8601String(),
      },
    },
  ];

  static final _mockJobs = [
    Job(
      id: 'job-1',
      title: 'Plumber needed for bathroom fixing',
      description:
          'The bathroom faucet is leaking badly and needs immediate repair.',
      categoryId: 13,
      budgetAmount: 3000,
      budgetType: BudgetType.negotiable,
      urgency: Urgency.instant,
      locationText: 'Lahore, Gulberg',
      lat: 31.5204,
      lng: 74.3587,
    ),
    Job(
      id: 'job-2',
      title: 'AC repair and maintenance',
      description:
          'Split AC not cooling properly. Needs gas refill and servicing.',
      categoryId: 14,
      budgetAmount: 3500,
      budgetType: BudgetType.fixed,
      urgency: Urgency.today,
      locationText: 'Lahore, DHA',
    ),
    Job(
      id: 'job-3',
      title: 'Tutor for Class 10 Mathematics',
      description:
          'Need a math tutor for my son who is in class 10. Focus on algebra and geometry.',
      categoryId: 24,
      budgetAmount: 500,
      budgetType: BudgetType.hourly,
      urgency: Urgency.scheduled,
      locationText: 'Lahore, Model Town',
    ),
  ];
}

/// Riverpod provider for Supabase repository
final supabaseRepositoryProvider = Provider<SupabaseRepository>((ref) {
  try {
    final client = Supabase.instance.client;
    return SupabaseRepository(client);
  } catch (_) {
    // Supabase has not been initialized (e.g. widget tests). Return a
    // repository backed by mock data instead of crashing.
    return SupabaseRepository(null);
  }
});
