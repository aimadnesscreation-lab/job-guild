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

  bool get _isConnected => _client != null;

  // ─── Jobs ─────────────────────────────────────────────────

  Future<List<Job>> getNearbyJobs({
    double lat = 31.5204,
    double lng = 74.3587,
    double radiusKm = 10,
  }) async {
    if (!_isConnected) return _mockJobs;

    try {
      final response = await _client!.rpc('get_nearby_jobs', params: {
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
      });
      final list = response as List;
      return list.map((j) => Job.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      return _mockJobs;
    }
  }

  Future<Job?> getJob(String id) async {
    if (!_isConnected) return _mockJobs.firstWhere((j) => j.id == id);

    try {
      final response = await _client!
          .from('jobs')
          .select()
          .eq('id', id)
          .single();
      return Job.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<void> postJob(Job job) async {
    if (!_isConnected) return; // silently succeed for mock

    final userId = _client!.auth.currentUser?.id;
    final json = job.toJson();
    // The draft job has an empty employerId; stamp it with the authenticated user.
    if (userId != null) json['employer_id'] = userId;
    await _client!.from('jobs').insert(json);
  }

  Future<void> updateJobStatus(String jobId, JobStatus status) async {
    if (!_isConnected) return;

    await _client!
        .from('jobs')
        .update({'status': status.name})
        .eq('id', jobId);
  }

  // ─── Applications ─────────────────────────────────────────

  Future<void> applyForJob(String jobId, String workerId, {String? message}) async {
    if (!_isConnected) return;

    await _client!.from('applications').insert({
      'job_id': jobId,
      'worker_id': workerId,
      if (message != null) 'message': message,
    });
  }

  Future<void> hireWorker(String jobId, String workerId) async {
    if (!_isConnected) return;

    await _client!.from('applications').update({'status': 'hired'}).match({
      'job_id': jobId,
      'worker_id': workerId,
    });
    await _client!
        .from('jobs')
        .update({'status': 'hired'})
        .eq('id', jobId);
  }
  /// Count how many workers have applied to a given job. Used by the
  /// employer dashboard to show applicant counts per active job.
  Future<int> countApplicants(String jobId) async {
    if (!_isConnected) return 0;
    try {
      final response = await _client!
          .from('applications')
          .select('worker_id')
          .eq('job_id', jobId);
      if (response is List) return response.length;
      return 0;
    } catch (e) {
      return 0;
    }
  }
  /// Fetch the applicants (workers who applied) for a job, joined with
  /// their worker profile + user info so the employer dashboard can show
  /// names, ratings, and verification in one round-trip.
  Future<List<Map<String, dynamic>>> getApplicants(String jobId) async {
    if (!_isConnected) return [];
    try {
      final response = await _client!
          .from('applications')
          .select('*, worker_profiles!inner(id, headline, is_verified, average_rating, total_jobs_completed, users!inner(full_name, profile_photo_url))')
          .eq('job_id', jobId)
          .order('created_at');
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }


  // ─── Worker Profiles ──────────────────────────────────────

  Future<WorkerProfile?> getWorkerProfile(String userId) async {
    if (!_isConnected) return null;

    try {
      final response = await _client!
          .from('worker_profiles')
          .select('*, users!inner(full_name, profile_photo_url)')
          .eq('id', userId)
          .single();
      return _workerProfileFromJson(response as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveWorkerProfile(WorkerProfile profile) async {
    if (!_isConnected) return;

    await _client!.from('worker_profiles').upsert({
      'id': profile.userId,
      'headline': profile.headline,
      'bio': profile.bio,
      'years_experience': profile.yearsExperience,
      'hourly_rate_pkr': profile.hourlyRatePkr,
      'availability_status': profile.availabilityStatus.name,
      'service_radius_km': profile.serviceRadiusKm,
      'portfolio_media': profile.portfolioMediaUrls,
    });
  }

  // ─── Messages ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    if (!_isConnected) return [];

    try {
      final response = await _client!
          .from('messages')
          .select()
          .eq('job_id', conversationId)
          .order('sent_at');
      return (response as List).cast<Map<String, dynamic>>();
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
    if (!_isConnected) return;

    await _client!.from('messages').insert({
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
    if (!_isConnected) return;

    await _client!.from('reviews').insert({
      'job_id': jobId,
      'reviewer_id': reviewerId,
      'reviewee_id': revieweeId,
      'rating': rating,
      if (comment != null) 'comment': comment,
    });
  }

  // ─── Favorites ────────────────────────────────────────────

  Future<void> toggleFavorite(String userId, String favoritedUserId) async {
    if (!_isConnected) return;

    try {
      await _client!.from('favorites').insert({
        'user_id': userId,
        'favorited_user_id': favoritedUserId,
      });
    } catch (_) {
      // Already favorited — remove
      await _client!
          .from('favorites')
          .delete()
          .match({'user_id': userId, 'favorited_user_id': favoritedUserId});
    }
  }

  // ─── Notifications ────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    if (!_isConnected) return [];

    try {
      final response = await _client!
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    if (!_isConnected) return;

    await _client!
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  // ─── Helpers ──────────────────────────────────────────────

  WorkerProfile _workerProfileFromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    return WorkerProfile(
      userId: json['id'] as String? ?? '',
      fullName: user?['full_name'] as String? ?? '',
      profilePhotoUrl: user?['profile_photo_url'] as String?,
      headline: json['headline'] as String?,
      bio: json['bio'] as String?,
      yearsExperience: json['years_experience'] as int? ?? 0,
      hourlyRatePkr: json['hourly_rate_pkr'] as int?,
      availabilityStatus: AvailabilityStatus.values.firstWhere(
        (s) => s.name == json['availability_status'],
        orElse: () => AvailabilityStatus.offline,
      ),
      serviceRadiusKm: json['service_radius_km'] as int? ?? 10,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalJobsCompleted: json['total_jobs_completed'] as int? ?? 0,
      responseTimeAvgMinutes: json['response_time_avg_minutes'] as int? ?? 0,
      portfolioMediaUrls: (json['portfolio_media'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  // ─── Mock Data ────────────────────────────────────────────

  static final _mockJobs = [
    Job(
      id: 'job-1',
      title: 'Plumber needed for bathroom fixing',
      description: 'The bathroom faucet is leaking badly and needs immediate repair.',
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
      description: 'Split AC not cooling properly. Needs gas refill and servicing.',
      categoryId: 14,
      budgetAmount: 3500,
      budgetType: BudgetType.fixed,
      urgency: Urgency.today,
      locationText: 'Lahore, DHA',
    ),
    Job(
      id: 'job-3',
      title: 'Tutor for Class 10 Mathematics',
      description: 'Need a math tutor for my son who is in class 10. Focus on algebra and geometry.',
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
  final client = Supabase.instance.client;
  return SupabaseRepository(client);
});
