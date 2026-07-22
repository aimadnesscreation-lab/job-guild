import 'package:flutter_test/flutter_test.dart';
import 'package:local_services_marketplace/core/services/openrouter_service.dart';
import 'package:local_services_marketplace/core/services/notification_service.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';
import 'package:local_services_marketplace/features/worker/models/worker_profile_model.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';

// ═════════════════════════════════════════════════════════════════════
//  OpenRouterService
// ═════════════════════════════════════════════════════════════════════

void main() {
  group('OpenRouterService', () {
    test('constructor uses default values when no params given', () {
      // This should not throw — the service uses AppConstants defaults
      expect(() => OpenRouterService(), isNot(throwsException));
    });

    test('constructor accepts custom apiKey and baseUrl', () {
      final service = OpenRouterService(
        apiKey: 'test-key',
        baseUrl: 'https://test.example.com',
      );
      // No direct way to inspect private fields, but no crash means
      // the constructor accepted the values.
      service.dispose();
    });

    group('generateText (mock mode)', () {
      test('returns mock response when called with empty prompt', () async {
        final service = OpenRouterService(
          apiKey: 'test-key',
          baseUrl: 'https://test.example.com',
        );
        final result = await service.generateText(prompt: '');
        expect(result, isNotEmpty);
        expect(result, contains('Professional'));
        service.dispose();
      });

      test('returns mock response that mentions the input', () async {
        final service = OpenRouterService(
          apiKey: 'test-key',
          baseUrl: 'https://test.example.com',
        );
        final result = await service.generateText(prompt: 'plumbing');
        expect(result, contains('plumbing'));
        service.dispose();
      });

      test('handles null system prompt gracefully', () async {
        final service = OpenRouterService(
          apiKey: 'test-key',
          baseUrl: 'https://test.example.com',
        );
        final result = await service.generateText(
          prompt: 'test',
          systemPrompt: null,
        );
        expect(result, isNotEmpty);
        service.dispose();
      });
    });

    group('generateJson (mock mode)', () {
      late OpenRouterService service;

      setUp(() {
        service = OpenRouterService(
          apiKey: 'test-key',
          baseUrl: 'https://test.example.com',
        );
      });

      tearDown(() {
        service.dispose();
      });

      test('returns valid JSON with correct keys', () async {
        final result = await service.generateJson(
          prompt: 'Fix my bathroom faucet',
        );
        expect(result, isA<Map<String, dynamic>>());
        expect(result.containsKey('category'), isTrue);
        expect(result.containsKey('urgency'), isTrue);
        expect(result.containsKey('suggested_budget_pkr'), isTrue);
        expect(result.containsKey('estimated_duration_hours'), isTrue);
        expect(result.containsKey('required_skills'), isTrue);
      });

      test('infers Plumbing category from plumbing keywords', () async {
        final result = await service.generateJson(
          prompt: 'plumbing pipe repair',
        );
        expect(result['category'], 'Plumbing');
      });

      test('infers Electrical category from electrical keywords', () async {
        final result = await service.generateJson(
          prompt: 'electrical wiring installation',
        );
        expect(result['category'], 'Electrical');
      });

      test('infers Painting category from painting keywords', () async {
        final result = await service.generateJson(
          prompt: 'paint my bedroom walls',
        );
        expect(result['category'], 'Painting');
      });

      test('infers Carpentry category from carpentry keywords', () async {
        final result = await service.generateJson(
          prompt: 'carpentry custom shelves',
        );
        expect(result['category'], 'Carpentry');
      });

      test('infers Cleaning category from cleaning keywords', () async {
        final result = await service.generateJson(prompt: 'clean my apartment');
        expect(result['category'], 'Cleaning');
      });

      test('infers Tutor category from tutor keywords', () async {
        final result = await service.generateJson(
          prompt: 'tutor for mathematics',
        );
        expect(result['category'], 'Tutor');
      });

      test('infers Mechanic category from mechanic keywords', () async {
        final result = await service.generateJson(
          prompt: 'mechanic car repair',
        );
        expect(result['category'], 'Mechanic');
      });

      test('infers Cook category from cook keywords', () async {
        final result = await service.generateJson(
          prompt: 'cook for dinner party',
        );
        expect(result['category'], 'Cook');
      });

      test('infers Moving category from moving keywords', () async {
        final result = await service.generateJson(
          prompt: 'move furniture to new house',
        );
        expect(result['category'], 'Moving');
      });

      test('defaults to General Labor for unknown input', () async {
        final result = await service.generateJson(
          prompt: 'random unknown task',
        );
        expect(result['category'], 'General Labor');
      });

      test('detects instant urgency from urgent/emergency keywords', () async {
        final result = await service.generateJson(
          prompt: 'urgent emergency plumbing repair',
        );
        expect(result['urgency'], 'instant');
      });

      test(
        'detects scheduled urgency from tomorrow/next week keywords',
        () async {
          final result = await service.generateJson(
            prompt: 'schedule for next week painting',
          );
          expect(result['urgency'], 'scheduled');
        },
      );

      test('defaults to today urgency for neutral input', () async {
        final result = await service.generateJson(
          prompt: 'fix bathroom faucet',
        );
        expect(result['urgency'], 'today');
      });

      test('estimates budget from numeric input', () async {
        final result = await service.generateJson(
          prompt: 'budget 5000 plumbing repair',
        );
        expect(result['suggested_budget_pkr'], 5000);
      });

      test('estimates budget with k suffix multiplies by 1000', () async {
        final result = await service.generateJson(prompt: '5k rs plumbing');
        expect(result['suggested_budget_pkr'], 5000);
      });

      test('uses category budget when no numeric hint', () async {
        final result = await service.generateJson(
          prompt: 'plumbing work needed',
        );
        expect(result['suggested_budget_pkr'], 3000);
      });

      test('estimates 1 hour duration for hour-related text', () async {
        final result = await service.generateJson(prompt: '1 hour plumbing');
        expect(result['estimated_duration_hours'], 1);
      });

      test('estimates 8 hours for day-related text', () async {
        final result = await service.generateJson(prompt: 'full day painting');
        expect(result['estimated_duration_hours'], 8);
      });

      test('estimates 40 hours for week-related text', () async {
        final result = await service.generateJson(prompt: 'week long project');
        expect(result['estimated_duration_hours'], 40);
      });

      test('defaults to 2 hours for unspecified duration', () async {
        final result = await service.generateJson(prompt: 'fix leaking pipe');
        expect(result['estimated_duration_hours'], 2);
      });

      test('includes required_skills containing the category', () async {
        final result = await service.generateJson(prompt: 'electrical wiring');
        expect(result['required_skills'], contains('Electrical'));
      });

      test('handles system prompt parameter gracefully', () async {
        final result = await service.generateJson(
          prompt: 'clean my house',
          systemPrompt: 'You are a helpful assistant.',
        );
        expect(result, isA<Map<String, dynamic>>());
        expect(result.containsKey('category'), isTrue);
        expect(result.containsKey('urgency'), isTrue);
      });
    });

    group('dispose', () {
      test('can be called multiple times without throwing', () {
        final service = OpenRouterService(
          apiKey: 'test-key',
          baseUrl: 'https://test.example.com',
        );
        service.dispose();
        // Calling dispose a second time should not throw
        expect(() => service.dispose(), isNot(throwsException));
      });
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  //  NotificationService
  // ═════════════════════════════════════════════════════════════════════

  group('NotificationService', () {
    late NotificationService service;

    setUp(() {
      service = NotificationService();
    });

    test('fcmToken returns null before initialization', () {
      expect(service.fcmToken, isNull);
    });

    test('onUserChanged with null userId does not throw', () {
      expect(() => service.onUserChanged(null), isNot(throwsException));
    });

    test('onUserChanged with non-null userId before init does not throw', () {
      // Without FCM initialized, saving to Supabase will fail silently
      expect(() => service.onUserChanged('user-123'), isNot(throwsException));
    });

    test('initialize can be called without onMessageTap', () async {
      // Firebase is not available in tests, so this will catch and log
      // silently. The important thing is it doesn't throw.
      await expectLater(service.initialize(), completes);
    });

    test('initialize with onMessageTap callback does not throw', () async {
      int callCount = 0;
      await service.initialize(onMessageTap: (_) => callCount++);
      // Init will fail because Firebase not configured, but shouldn't throw
      expect(callCount, 0);
    });

    test('double initialize returns early without error', () async {
      await service.initialize();
      // Second call should return early since _initialized is true
      await expectLater(service.initialize(), completes);
    });

    test('multiple services can be created independently', () {
      final service2 = NotificationService();
      expect(service2.fcmToken, isNull);
      expect(service.fcmToken, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  //  SupabaseRepository (null-client / mock-datapath)
  // ═════════════════════════════════════════════════════════════════════

  group('SupabaseRepository (null client = mock mode)', () {
    late SupabaseRepository repo;

    setUp(() {
      repo = SupabaseRepository(null);
    });

    // ─── Jobs ───────────────────────────────────────────────────

    group('getNearbyJobs', () {
      test('returns mock jobs when client is null', () async {
        final jobs = await repo.getNearbyJobs();
        expect(jobs, isNotEmpty);
        expect(jobs.length, greaterThanOrEqualTo(2));
      });

      test('returns Job instances with correct types', () async {
        final jobs = await repo.getNearbyJobs();
        for (final job in jobs) {
          expect(job, isA<Job>());
          expect(job.id, isNotEmpty);
          expect(job.title, isNotEmpty);
        }
      });

      test('returns same mock data across calls', () async {
        final first = await repo.getNearbyJobs();
        final second = await repo.getNearbyJobs();
        expect(first.length, second.length);
        expect(first[0].id, second[0].id);
      });
    });

    group('getJob', () {
      test('returns matching mock job when id exists', () async {
        final job = await repo.getJob('job-1');
        expect(job, isNotNull);
        expect(job!.id, 'job-1');
        expect(job.title, contains('Plumber'));
      });

      test('returns null for non-existent id', () async {
        final job = await repo.getJob('non-existent');
        expect(job, isNull);
      });
    });

    group('postJob', () {
      test('silently succeeds when client is null', () async {
        final job = Job(id: 'test-job', title: 'Test', description: 'Testing');
        await expectLater(repo.postJob(job), completes);
      });
    });

    group('updateJobStatus', () {
      test('silently succeeds when client is null', () async {
        await expectLater(
          repo.updateJobStatus('job-1', JobStatus.hired),
          completes,
        );
      });
    });

    // ─── Applications ──────────────────────────────────────────

    group('applyForJob', () {
      test('silently succeeds when client is null', () async {
        await expectLater(repo.applyForJob('job-1', 'worker-1'), completes);
      });

      test('handles optional message parameter', () async {
        await expectLater(
          repo.applyForJob('job-1', 'worker-1', message: 'I am interested'),
          completes,
        );
      });
    });

    group('hireWorker', () {
      test('silently succeeds when client is null', () async {
        await expectLater(repo.hireWorker('job-1', 'worker-1'), completes);
      });
    });

    group('getMyApplications', () {
      test('returns mock applications when client is null', () async {
        final apps = await repo.getMyApplications('worker-1');
        expect(apps, isNotEmpty);
        expect(apps.length, 2);
      });

      test('mock applications have expected structure', () async {
        final apps = await repo.getMyApplications('worker-1');
        final first = apps.first;
        expect(first['id'], isNotEmpty);
        expect(first['job_id'], isNotEmpty);
        expect(first['status'], isNotEmpty);
        expect(first['jobs'], isA<Map<String, dynamic>>());
      });
    });

    group('getWorkerCompletedJobs', () {
      test('returns mock completed jobs when client is null', () async {
        final jobs = await repo.getWorkerCompletedJobs('worker-1');
        expect(jobs, isNotEmpty);
        expect(jobs.length, 3);
      });

      test('mock completed jobs have earnings data', () async {
        final jobs = await repo.getWorkerCompletedJobs('worker-1');
        for (final job in jobs) {
          final jobData = job['jobs'] as Map<String, dynamic>;
          expect(jobData['budget_amount'], isA<int>());
          expect(jobData['title'], isNotEmpty);
        }
      });
    });

    group('countApplicants', () {
      test('returns 0 when client is null', () async {
        final count = await repo.countApplicants('job-1');
        expect(count, 0);
      });
    });

    group('getApplicants', () {
      test('returns empty list when client is null', () async {
        final applicants = await repo.getApplicants('job-1');
        expect(applicants, isEmpty);
      });
    });

    // ─── Worker Profiles ───────────────────────────────────────

    group('getWorkerProfile', () {
      test('returns null when client is null', () async {
        final profile = await repo.getWorkerProfile('user-1');
        expect(profile, isNull);
      });
    });

    group('saveWorkerProfile', () {
      test('silently succeeds when client is null', () async {
        final profile = WorkerProfile(
          userId: 'user-1',
          fullName: 'Test Worker',
        );
        await expectLater(repo.saveWorkerProfile(profile), completes);
      });
    });

    group('updateAvailabilityStatus', () {
      test('silently succeeds when client is null', () async {
        await expectLater(
          repo.updateAvailabilityStatus('user-1', AvailabilityStatus.today),
          completes,
        );
      });
    });

    // ─── Messages ──────────────────────────────────────────────

    group('getMessages', () {
      test('returns empty list when client is null', () async {
        final messages = await repo.getMessages('conv-1');
        expect(messages, isEmpty);
      });
    });

    group('sendMessage', () {
      test('silently succeeds when client is null', () async {
        await expectLater(
          repo.sendMessage(
            jobId: 'job-1',
            senderId: 'user-1',
            content: 'Hello',
          ),
          completes,
        );
      });

      test('handles custom content type', () async {
        await expectLater(
          repo.sendMessage(
            jobId: 'job-1',
            senderId: 'user-1',
            content: 'image_url',
            contentType: 'image',
          ),
          completes,
        );
      });
    });

    // ─── Reviews ───────────────────────────────────────────────

    group('submitReview', () {
      test('silently succeeds when client is null', () async {
        await expectLater(
          repo.submitReview(
            jobId: 'job-1',
            reviewerId: 'user-1',
            revieweeId: 'user-2',
            rating: 5,
            comment: 'Great work!',
          ),
          completes,
        );
      });

      test('handles missing comment', () async {
        await expectLater(
          repo.submitReview(
            jobId: 'job-1',
            reviewerId: 'user-1',
            revieweeId: 'user-2',
            rating: 4,
          ),
          completes,
        );
      });
    });

    group('getUserReviews', () {
      test('returns empty list when client is null', () async {
        final reviews = await repo.getUserReviews('user-1');
        expect(reviews, isEmpty);
      });
    });

    // ─── Favorites ─────────────────────────────────────────────

    group('getFavorites', () {
      test('returns empty list when client is null', () async {
        final favorites = await repo.getFavorites('user-1');
        expect(favorites, isEmpty);
      });
    });

    group('toggleFavorite', () {
      test('returns false when client is null', () async {
        final result = await repo.toggleFavorite('user-1', 'worker-1');
        expect(result, isFalse);
      });
    });

    // ─── Notifications ─────────────────────────────────────────

    group('getNotifications', () {
      test('returns empty list when client is null', () async {
        final notifications = await repo.getNotifications('user-1');
        expect(notifications, isEmpty);
      });
    });

    group('markNotificationRead', () {
      test('silently succeeds when client is null', () async {
        await expectLater(repo.markNotificationRead('notif-1'), completes);
      });
    });

    // ─── Reports ───────────────────────────────────────────────

    group('getUserReports', () {
      test('returns empty list when client is null', () async {
        final reports = await repo.getUserReports('user-1');
        expect(reports, isEmpty);
      });
    });

    group('submitReport', () {
      test('silently succeeds when client is null', () async {
        await expectLater(
          repo.submitReport(
            reporterId: 'user-1',
            reason: 'Spam',
            details: 'This user is spamming',
          ),
          completes,
        );
      });

      test('handles optional reportedUserId and jobId', () async {
        await expectLater(
          repo.submitReport(
            reporterId: 'user-1',
            reportedUserId: 'user-2',
            jobId: 'job-1',
            reason: 'Harassment',
          ),
          completes,
        );
      });
    });

    // ─── Settings ──────────────────────────────────────────────

    group('getUserSettings', () {
      test('returns default settings when client is null', () async {
        final settings = await repo.getUserSettings('user-1');
        expect(settings['preferred_language'], 'en');
        expect(settings['notifications_enabled'], true);
        expect(settings['job_alerts_enabled'], true);
        expect(settings['message_alerts_enabled'], true);
        expect(settings['service_radius_km'], 10);
      });
    });

    group('saveUserSettings', () {
      test('silently succeeds when client is null', () async {
        await expectLater(
          repo.saveUserSettings('user-1', {
            'preferred_language': 'ur',
            'service_radius_km': 20,
          }),
          completes,
        );
      });

      test('filters out non-allowed keys silently', () async {
        await expectLater(
          repo.saveUserSettings('user-1', {
            'preferred_language': 'ur',
            'nonexistent_key': 'value',
          }),
          completes,
        );
      });
    });
  });
}
