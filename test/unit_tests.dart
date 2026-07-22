import 'package:flutter_test/flutter_test.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/features/chat/models/message_model.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';
import 'package:local_services_marketplace/features/jobs/providers/job_provider.dart';
import 'package:local_services_marketplace/features/settings/providers/settings_provider.dart';
import 'package:local_services_marketplace/features/worker/models/worker_profile_model.dart';
import 'package:local_services_marketplace/features/worker/providers/worker_profile_provider.dart';

// ═════════════════════════════════════════════════════════════════════
//  Model: Job
// ═════════════════════════════════════════════════════════════════════

void main() {
  group('Job model', () {
    test('default constructor sets sensible defaults', () {
      final job = Job();
      expect(job.id, '');
      expect(job.title, '');
      expect(job.status, JobStatus.open);
      expect(job.urgency, Urgency.today);
      expect(job.budgetType, BudgetType.negotiable);
      expect(job.lat, 31.5204);
      expect(job.lng, 74.3587);
      expect(job.isOpen, isTrue);
      expect(job.isInstant, isFalse);
    });

    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'job-123',
        'employer_id': 'emp-456',
        'category_id': 13,
        'title': 'Fix bathroom faucet',
        'description': 'The faucet is leaking badly.',
        'budget_amount': 3000,
        'budget_type': 'fixed',
        'location_text': 'Lahore, Gulberg',
        'location_coords': {
          'type': 'Point',
          'coordinates': [74.3587, 31.5204],
        },
        'status': 'open',
        'urgency': 'instant',
        'created_at': '2026-07-20T10:00:00.000Z',
      };

      final job = Job.fromJson(json);
      expect(job.id, 'job-123');
      expect(job.employerId, 'emp-456');
      expect(job.categoryId, 13);
      expect(job.title, 'Fix bathroom faucet');
      expect(job.description, 'The faucet is leaking badly.');
      expect(job.budgetAmount, 3000);
      expect(job.budgetType, BudgetType.fixed);
      expect(job.locationText, 'Lahore, Gulberg');
      expect(job.lat, 31.5204);
      expect(job.lng, 74.3587);
      expect(job.status, JobStatus.open);
      expect(job.urgency, Urgency.instant);
      expect(job.isOpen, isTrue);
      expect(job.isInstant, isTrue);
    });

    test('fromJson parses WKT location format', () {
      final json = {
        'id': 'job-1',
        'title': 'Test',
        'location_coords': 'POINT(74.3587 31.5204)',
      };
      final job = Job.fromJson(json);
      expect(job.lat, 31.5204);
      expect(job.lng, 74.3587);
    });

    test('fromJson falls back to legacy lat/lng columns', () {
      final json = {
        'id': 'job-1',
        'title': 'Test',
        'location_lat': 31.5,
        'location_lng': 74.3,
      };
      final job = Job.fromJson(json);
      expect(job.lat, 31.5);
      expect(job.lng, 74.3);
    });

    test('fromJson handles missing location gracefully', () {
      // When no location data exists, _parseCoordinates returns (0.0, 0.0)
      // rather than the default constructor values.
      final json = {'id': 'job-1', 'title': 'Test'};
      final job = Job.fromJson(json);
      expect(job.lat, 0.0);
      expect(job.lng, 0.0);
    });

    test('fromJson parses all job statuses', () {
      expect(
        Job.fromJson({'id': '1', 'status': 'open'}).status,
        JobStatus.open,
      );
      expect(
        Job.fromJson({'id': '1', 'status': 'hired'}).status,
        JobStatus.hired,
      );
      expect(
        Job.fromJson({'id': '1', 'status': 'completed'}).status,
        JobStatus.completed,
      );
      expect(
        Job.fromJson({'id': '1', 'status': 'cancelled'}).status,
        JobStatus.cancelled,
      );
      expect(
        Job.fromJson({'id': '1', 'status': 'expired'}).status,
        JobStatus.expired,
      );
      expect(
        Job.fromJson({'id': '1', 'status': 'unknown'}).status,
        JobStatus.open,
      );
    });

    test('fromJson parses all budget types', () {
      expect(
        Job.fromJson({'id': '1', 'budget_type': 'fixed'}).budgetType,
        BudgetType.fixed,
      );
      expect(
        Job.fromJson({'id': '1', 'budget_type': 'hourly'}).budgetType,
        BudgetType.hourly,
      );
      expect(
        Job.fromJson({'id': '1', 'budget_type': 'whatever'}).budgetType,
        BudgetType.negotiable,
      );
    });

    test('fromJson parses all urgency levels', () {
      expect(
        Job.fromJson({'id': '1', 'urgency': 'instant'}).urgency,
        Urgency.instant,
      );
      expect(
        Job.fromJson({'id': '1', 'urgency': 'scheduled'}).urgency,
        Urgency.scheduled,
      );
      expect(
        Job.fromJson({'id': '1', 'urgency': 'today'}).urgency,
        Urgency.today,
      );
    });

    test('fromJson parses ai_extracted_metadata', () {
      final json = {
        'id': 'job-1',
        'ai_extracted_metadata': {
          'category': 'Plumbing',
          'urgency': 'instant',
          'suggested_budget_pkr': 3000,
          'estimated_duration_hours': 2,
          'required_skills': ['Plumbing', 'Pipe fitting'],
        },
      };
      final job = Job.fromJson(json);
      expect(job.aiExtractedMetadata, isNotNull);
      expect(job.aiExtractedMetadata!.category, 'Plumbing');
      expect(job.aiExtractedMetadata!.suggestedBudgetPkr, 3000);
      expect(job.aiExtractedMetadata!.requiredSkills, [
        'Plumbing',
        'Pipe fitting',
      ]);
    });

    test('toJson outputs correct WKT format', () {
      final job = Job(
        id: 'job-1',
        employerId: 'emp-1',
        title: 'Test Job',
        lat: 31.5,
        lng: 74.3,
        budgetAmount: 2000,
        budgetType: BudgetType.fixed,
        urgency: Urgency.instant,
        status: JobStatus.open,
      );
      final json = job.toJson();
      expect(json['location_coords'], 'POINT(74.3 31.5)');
      expect(json['budget_type'], 'fixed');
      expect(json['status'], 'open');
      expect(json['urgency'], 'instant');
    });

    test('toJson excludes optional null fields', () {
      final job = Job(id: 'job-1', title: 'Test');
      final json = job.toJson();
      expect(json.containsKey('budget_amount'), isFalse);
      expect(json.containsKey('scheduled_for'), isFalse);
      expect(json.containsKey('ai_extracted_metadata'), isFalse);
    });

    test('toJson includes id only when non-empty', () {
      final jobEmptyId = Job(title: 'Test');
      expect(jobEmptyId.toJson().containsKey('id'), isFalse);

      final jobWithId = Job(id: 'abc', title: 'Test');
      expect(jobWithId.toJson()['id'], 'abc');
    });

    test('copyWith preserves unchanged fields', () {
      final job = Job(
        id: 'job-1',
        title: 'Original',
        budgetAmount: 1000,
        lat: 31.0,
        lng: 74.0,
      );
      final copied = job.copyWith(title: 'Updated');
      expect(copied.id, 'job-1');
      expect(copied.title, 'Updated');
      expect(copied.budgetAmount, 1000);
      expect(copied.lat, 31.0);
      expect(copied.lng, 74.0);
    });

    test('copyWith clears ai metadata when flag set', () {
      final job = Job(
        aiExtractedMetadata: JobAiMetadata(
          category: 'Plumbing',
          urgency: 'instant',
          suggestedBudgetPkr: 2000,
          estimatedDurationHours: 2,
        ),
      );
      expect(job.aiExtractedMetadata, isNotNull);

      final cleared = job.copyWith(clearAiMetadata: true);
      expect(cleared.aiExtractedMetadata, isNull);
    });

    test('copyWith overrides individual fields', () {
      final job = Job();
      final overridden = job.copyWith(
        id: 'new-id',
        employerId: 'new-emp',
        title: 'New Title',
        budgetAmount: 5000,
        budgetType: BudgetType.hourly,
        status: JobStatus.hired,
        urgency: Urgency.instant,
      );
      expect(overridden.id, 'new-id');
      expect(overridden.employerId, 'new-emp');
      expect(overridden.title, 'New Title');
      expect(overridden.budgetAmount, 5000);
      expect(overridden.budgetType, BudgetType.hourly);
      expect(overridden.status, JobStatus.hired);
      expect(overridden.urgency, Urgency.instant);
    });

    test('budgetDisplay shows Negotiable when no amount', () {
      final job = Job(budgetAmount: null);
      expect(job.budgetDisplay, 'Negotiable');
    });

    test('budgetDisplay shows PKR amount', () {
      final job = Job(budgetAmount: 3000);
      expect(job.budgetDisplay, 'PKR 3000');
    });

    test('isInstant and isOpen helpers', () {
      final openJob = Job(status: JobStatus.open, urgency: Urgency.today);
      expect(openJob.isOpen, isTrue);
      expect(openJob.isInstant, isFalse);

      final urgentJob = Job(urgency: Urgency.instant);
      expect(urgentJob.isInstant, isTrue);

      final hiredJob = Job(status: JobStatus.hired);
      expect(hiredJob.isOpen, isFalse);
    });
  });

  group('JobAiMetadata', () {
    test('fromJson parses all fields', () {
      final json = {
        'category': 'Electrical',
        'urgency': 'scheduled',
        'suggested_budget_pkr': 3500,
        'estimated_duration_hours': 3,
        'required_skills': ['Electrical', 'Wiring'],
      };
      final meta = JobAiMetadata.fromJson(json);
      expect(meta.category, 'Electrical');
      expect(meta.urgency, 'scheduled');
      expect(meta.suggestedBudgetPkr, 3500);
      expect(meta.estimatedDurationHours, 3);
      expect(meta.requiredSkills, ['Electrical', 'Wiring']);
    });

    test('fromJson handles missing fields with defaults', () {
      final meta = JobAiMetadata.fromJson({});
      expect(meta.category, '');
      expect(meta.urgency, 'today');
      expect(meta.suggestedBudgetPkr, 0);
      expect(meta.estimatedDurationHours, 2);
      expect(meta.requiredSkills, isEmpty);
    });

    test('toJson round-trips correctly', () {
      final meta = JobAiMetadata(
        category: 'Cleaning',
        urgency: 'today',
        suggestedBudgetPkr: 1500,
        estimatedDurationHours: 2,
        requiredSkills: ['Cleaning'],
      );
      final json = meta.toJson();
      expect(json['category'], 'Cleaning');
      expect(json['urgency'], 'today');
      expect(json['suggested_budget_pkr'], 1500);
      expect(json['estimated_duration_hours'], 2);
      expect(json['required_skills'], ['Cleaning']);

      // Round-trip
      final restored = JobAiMetadata.fromJson(json);
      expect(restored.category, meta.category);
      expect(restored.urgency, meta.urgency);
      expect(restored.suggestedBudgetPkr, meta.suggestedBudgetPkr);
      expect(restored.estimatedDurationHours, meta.estimatedDurationHours);
      expect(restored.requiredSkills, meta.requiredSkills);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  //  Model: WorkerProfile
  // ═════════════════════════════════════════════════════════════════════

  group('WorkerProfile model', () {
    test('default constructor sets sensible defaults', () {
      final profile = WorkerProfile(userId: 'user-1', fullName: 'Test User');
      expect(profile.userId, 'user-1');
      expect(profile.fullName, 'Test User');
      expect(profile.yearsExperience, 0);
      expect(profile.averageRating, 0);
      expect(profile.totalJobsCompleted, 0);
      expect(profile.availabilityStatus, AvailabilityStatus.offline);
      expect(profile.isVerified, isFalse);
      expect(profile.portfolioMediaUrls, isEmpty);
      expect(profile.categories, isEmpty);
    });

    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'worker-1',
        'users': {
          'full_name': 'Ali Raza',
          'profile_photo_url': 'https://example.com/photo.jpg',
          'is_verified': true,
        },
        'headline': 'Experienced Plumber',
        'bio': '8 years of plumbing experience.',
        'years_experience': 8,
        'hourly_rate_pkr': 500,
        'fixed_rate_note': 'Negotiable for big jobs',
        'availability_status': 'today',
        'service_radius_km': 15,
        'average_rating': 4.5,
        'total_jobs_completed': 127,
        'response_time_avg_minutes': 12,
        'portfolio_media': ['https://example.com/img1.jpg'],
        'categories': ['Plumbing', 'Electrical'],
        'is_featured': true,
      };

      final profile = WorkerProfile.fromJson(json);
      expect(profile.userId, 'worker-1');
      expect(profile.fullName, 'Ali Raza');
      expect(profile.profilePhotoUrl, 'https://example.com/photo.jpg');
      expect(profile.headline, 'Experienced Plumber');
      expect(profile.bio, '8 years of plumbing experience.');
      expect(profile.yearsExperience, 8);
      expect(profile.hourlyRatePkr, 500);
      expect(profile.fixedRateNote, 'Negotiable for big jobs');
      expect(profile.availabilityStatus, AvailabilityStatus.today);
      expect(profile.serviceRadiusKm, 15);
      expect(profile.averageRating, 4.5);
      expect(profile.totalJobsCompleted, 127);
      expect(profile.responseTimeAvgMinutes, 12);
      expect(profile.portfolioMediaUrls, ['https://example.com/img1.jpg']);
      expect(profile.categories, ['Plumbing', 'Electrical']);
      expect(profile.isVerified, isTrue);
      expect(profile.isFeatured, isTrue);
    });

    test(
      'fromJson falls back to top-level fields when users join is absent',
      () {
        final json = {
          'id': 'worker-1',
          'full_name': 'Direct Name',
          'headline': 'Worker',
        };
        final profile = WorkerProfile.fromJson(json);
        expect(profile.fullName, 'Direct Name');
      },
    );

    test('fromJson handles missing optional fields', () {
      final profile = WorkerProfile.fromJson({'id': 'worker-1'});
      expect(profile.fullName, '');
      expect(profile.headline, isNull);
      expect(profile.bio, isNull);
      expect(profile.hourlyRatePkr, isNull);
      expect(profile.fixedRateNote, isNull);
    });

    test('toJson excludes fields that live on users table', () {
      final profile = WorkerProfile(
        userId: 'worker-1',
        fullName: 'Ali Raza',
        headline: 'Plumber',
        bio: 'Experienced',
        yearsExperience: 5,
        hourlyRatePkr: 500,
        availabilityStatus: AvailabilityStatus.today,
        serviceRadiusKm: 10,
        portfolioMediaUrls: ['https://example.com/img.jpg'],
        isVerified: true,
        isFeatured: true,
      );
      final json = profile.toJson();
      // full_name and is_verified must NOT be in the payload
      expect(json.containsKey('full_name'), isFalse);
      expect(json.containsKey('is_verified'), isFalse);
      expect(json.containsKey('average_rating'), isFalse);
      expect(json.containsKey('total_jobs_completed'), isFalse);
      expect(json.containsKey('response_time_avg_minutes'), isFalse);

      // These SHOULD be in the payload
      expect(json['id'], 'worker-1');
      expect(json['headline'], 'Plumber');
      expect(json['hourly_rate_pkr'], 500);
      expect(json['availability_status'], 'today');
      expect(json['service_radius_km'], 10);
      expect(json['is_featured'], isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      final profile = WorkerProfile(
        userId: 'u1',
        fullName: 'Original',
        yearsExperience: 5,
        hourlyRatePkr: 500,
      );
      final copied = profile.copyWith(fullName: 'Updated');
      expect(copied.userId, 'u1');
      expect(copied.fullName, 'Updated');
      expect(copied.yearsExperience, 5);
      expect(copied.hourlyRatePkr, 500);
    });

    test('copyWith clears nullable fields with flags', () {
      final profile = WorkerProfile(
        userId: 'u1',
        fullName: 'Test',
        profilePhotoUrl: 'https://example.com/photo.jpg',
        headline: 'Worker',
        bio: 'Bio text',
        fixedRateNote: 'Note',
      );

      final cleared = profile.copyWith(
        clearProfilePhoto: true,
        clearHeadline: true,
        clearBio: true,
        clearFixedRateNote: true,
      );

      expect(cleared.profilePhotoUrl, isNull);
      expect(cleared.headline, isNull);
      expect(cleared.bio, isNull);
      expect(cleared.fixedRateNote, isNull);
    });

    test('ratingDisplay shows message when no ratings', () {
      final profile = WorkerProfile(
        userId: 'u1',
        fullName: 'Test',
        averageRating: 0,
      );
      expect(profile.ratingDisplay, 'No ratings yet');
    });

    test('ratingDisplay formats rating with star', () {
      final profile = WorkerProfile(
        userId: 'u1',
        fullName: 'Test',
        averageRating: 4.5,
      );
      expect(profile.ratingDisplay, '4.5 ⭐');
    });

    test('ratingDisplay rounds to 1 decimal place', () {
      final profile = WorkerProfile(
        userId: 'u1',
        fullName: 'Test',
        averageRating: 4.567,
      );
      expect(profile.ratingDisplay, '4.6 ⭐');
    });

    test('availabilityLabel returns correct labels', () {
      expect(
        WorkerProfile(
          userId: 'u1',
          fullName: 'Test',
          availabilityStatus: AvailabilityStatus.today,
        ).availabilityLabel,
        'Available Today',
      );
      expect(
        WorkerProfile(
          userId: 'u1',
          fullName: 'Test',
          availabilityStatus: AvailabilityStatus.offline,
        ).availabilityLabel,
        'Offline',
      );
      expect(
        WorkerProfile(
          userId: 'u1',
          fullName: 'Test',
          availabilityStatus: AvailabilityStatus.busy,
        ).availabilityLabel,
        'Currently Busy',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  //  AvailabilityStatus enum
  // ═════════════════════════════════════════════════════════════════════

  group('AvailabilityStatus', () {
    test('all statuses have labels', () {
      for (final status in AvailabilityStatus.values) {
        expect(status.label, isNotEmpty);
      }
    });

    test('all statuses have icons', () {
      for (final status in AvailabilityStatus.values) {
        expect(status.icon, isNotNull);
      }
    });

    test('has 8 values', () {
      expect(AvailabilityStatus.values.length, 8);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  //  Enums: JobStatus, BudgetType, Urgency
  // ═════════════════════════════════════════════════════════════════════

  group('Job related enums', () {
    test('JobStatus has 5 values', () {
      expect(JobStatus.values.length, 5);
      expect(
        JobStatus.values,
        containsAll([
          JobStatus.open,
          JobStatus.hired,
          JobStatus.completed,
          JobStatus.cancelled,
          JobStatus.expired,
        ]),
      );
    });

    test('BudgetType has 3 values', () {
      expect(BudgetType.values.length, 3);
      expect(
        BudgetType.values,
        containsAll([
          BudgetType.fixed,
          BudgetType.hourly,
          BudgetType.negotiable,
        ]),
      );
    });

    test('Urgency has 3 values', () {
      expect(Urgency.values.length, 3);
      expect(
        Urgency.values,
        containsAll([Urgency.instant, Urgency.today, Urgency.scheduled]),
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  //  AuthNotifier.normalizePhone
  // ═════════════════════════════════════════════════════════════════════

  group('AuthNotifier.normalizePhone', () {
    test('normalizes 03xx format', () {
      expect(AuthNotifier.normalizePhone('03001234567'), '+923001234567');
    });

    test('normalizes 3xx format (without leading 0)', () {
      expect(AuthNotifier.normalizePhone('3001234567'), '+923001234567');
    });

    test('normalizes +92 format', () {
      expect(AuthNotifier.normalizePhone('+923001234567'), '+923001234567');
    });

    test('normalizes 92 format without +', () {
      expect(AuthNotifier.normalizePhone('923001234567'), '+923001234567');
    });

    test('strips non-digit characters', () {
      expect(AuthNotifier.normalizePhone('0300-1234567'), '+923001234567');
      expect(AuthNotifier.normalizePhone('+92 300 1234567'), '+923001234567');
      expect(AuthNotifier.normalizePhone('(92) 300-123-4567'), '+923001234567');
    });

    test('handles empty string', () {
      // Empty string → digits = '' → '+92'
      expect(AuthNotifier.normalizePhone(''), '+92');
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  //  PostJobState
  // ═════════════════════════════════════════════════════════════════════

  group('PostJobState', () {
    test('default constructor sets correct defaults', () {
      final state = PostJobState();
      expect(state.freeformText, '');
      expect(state.isParsingWithAi, isFalse);
      expect(state.parsedResult, isNull);
      expect(state.draftJob.id, '');
      expect(state.isPosting, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('hasAiResult returns false when no parsed result', () {
      final state = PostJobState();
      expect(state.hasAiResult, isFalse);
    });

    test('hasAiResult returns true when parsed result is present', () {
      final state = PostJobState(
        parsedResult: JobAiMetadata(
          category: 'Plumbing',
          urgency: 'today',
          suggestedBudgetPkr: 2000,
          estimatedDurationHours: 2,
        ),
      );
      expect(state.hasAiResult, isTrue);
    });

    test('copyWith updates fields correctly', () {
      final state = PostJobState();
      final updated = state.copyWith(
        freeformText: 'Fix my pipe',
        isParsingWithAi: true,
        errorMessage: 'An error',
      );
      expect(updated.freeformText, 'Fix my pipe');
      expect(updated.isParsingWithAi, isTrue);
      expect(updated.errorMessage, 'An error');
    });

    test('copyWith clearError removes error message', () {
      final state = PostJobState(errorMessage: 'Some error');
      final cleared = state.copyWith(clearError: true);
      expect(cleared.errorMessage, isNull);
    });

    test('copyWith clearParseResult removes parsed result', () {
      final state = PostJobState(
        parsedResult: JobAiMetadata(
          category: 'Test',
          urgency: 'today',
          suggestedBudgetPkr: 0,
          estimatedDurationHours: 1,
        ),
      );
      final cleared = state.copyWith(clearParseResult: true);
      expect(cleared.parsedResult, isNull);
    });

    test('copyWith overrides draftJob', () {
      final state = PostJobState();
      final newJob = Job(title: 'New Job');
      final updated = state.copyWith(draftJob: newJob);
      expect(updated.draftJob.title, 'New Job');
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  //  ChatState is tested in test/chat_state_test.dart
  //  (import conflict prevented combining them in this file)
  // ═════════════════════════════════════════════════════════════════════

  // ═════════════════════════════════════════════════════════════════════
  //  Message model
  // ═════════════════════════════════════════════════════════════════════

  group('Message model', () {
    test('default constructor sets sensible defaults', () {
      // When both senderId and the static currentUserId are empty strings,
      // isMine returns true ('' == ''). The app sets currentUserId at login
      // time so this edge case only arises in test isolation.
      final msg = Message();
      expect(msg.id, '');
      expect(msg.content, '');
      expect(msg.senderName, '');
      expect(msg.contentType, MessageContentType.text);
      expect(msg.isRead, isFalse);
      expect(msg.isMine, isTrue);
    });

    test('fromJson parses all fields', () {
      final json = {
        'id': 'msg-1',
        'job_id': 'job-1',
        'sender_id': 'user-1',
        'sender': {
          'full_name': 'Ali',
          'profile_photo_url': 'https://example.com/photo.jpg',
        },
        'content_type': 'text',
        'content': 'Hello there',
        'sent_at': '2026-07-20T10:00:00.000Z',
        'read_at': '2026-07-20T10:05:00.000Z',
      };
      final msg = Message.fromJson(json);
      expect(msg.id, 'msg-1');
      expect(msg.jobId, 'job-1');
      expect(msg.senderId, 'user-1');
      expect(msg.senderName, 'Ali');
      expect(msg.senderPhotoUrl, 'https://example.com/photo.jpg');
      expect(msg.contentType, MessageContentType.text);
      expect(msg.content, 'Hello there');
      expect(msg.isRead, isTrue);
    });

    test('fromJson parses image content type', () {
      final msg = Message.fromJson({
        'id': '1',
        'content_type': 'image',
        'content': 'https://example.com/img.jpg',
        'sent_at': '2026-07-20T10:00:00.000Z',
      });
      expect(msg.contentType, MessageContentType.image);
    });

    test('fromJson parses voice, location, file content types', () {
      expect(
        Message.fromJson({
          'id': '1',
          'content_type': 'voice',
          'sent_at': '2026-07-20T10:00:00.000Z',
        }).contentType,
        MessageContentType.voice,
      );
      expect(
        Message.fromJson({
          'id': '1',
          'content_type': 'location',
          'sent_at': '2026-07-20T10:00:00.000Z',
        }).contentType,
        MessageContentType.location,
      );
      expect(
        Message.fromJson({
          'id': '1',
          'content_type': 'file',
          'sent_at': '2026-07-20T10:00:00.000Z',
        }).contentType,
        MessageContentType.file,
      );
    });

    test('isMine compares against currentUserId', () {
      Message.currentUserId = 'user-1';
      final myMsg = Message.fromJson({
        'id': '1',
        'sender_id': 'user-1',
        'sent_at': '2026-07-20T10:00:00.000Z',
      });
      expect(myMsg.isMine, isTrue);

      final otherMsg = Message.fromJson({
        'id': '2',
        'sender_id': 'user-2',
        'sent_at': '2026-07-20T10:00:00.000Z',
      });
      expect(otherMsg.isMine, isFalse);
    });

    test('toJson round-trips correctly', () {
      final msg = Message(
        id: 'msg-1',
        jobId: 'job-1',
        senderId: 'user-1',
        content: 'Hello',
        sentAt: DateTime.fromMillisecondsSinceEpoch(1721460000000),
      );
      final json = msg.toJson();
      expect(json['job_id'], 'job-1');
      expect(json['sender_id'], 'user-1');
      expect(json['content'], 'Hello');
      expect(json['content_type'], 'text');

      // Round-trip
      final restored = Message.fromJson(json);
      expect(restored.id, msg.id);
      expect(restored.jobId, msg.jobId);
      expect(restored.senderId, msg.senderId);
      expect(restored.content, msg.content);
      expect(restored.contentType, msg.contentType);
    });
  });

  group('Conversation', () {
    test('default constructor sets sensible defaults', () {
      final conv = Conversation();
      expect(conv.id, '');
      expect(conv.jobTitle, '');
      expect(conv.unreadCount, 0);
      expect(conv.lastMessage, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  //  UserSettings
  // ═════════════════════════════════════════════════════════════════════

  group('UserSettings', () {
    test('default constructor sets defaults', () {
      final s = const UserSettings();
      expect(s.preferredLanguage, 'en');
      expect(s.notificationsEnabled, isTrue);
      expect(s.jobAlertsEnabled, isTrue);
      expect(s.messageAlertsEnabled, isTrue);
      expect(s.serviceRadiusKm, 10);
    });

    test('copyWith updates fields', () {
      final s = const UserSettings();
      final updated = s.copyWith(
        preferredLanguage: 'ur',
        notificationsEnabled: false,
        serviceRadiusKm: 25,
      );
      expect(updated.preferredLanguage, 'ur');
      expect(updated.notificationsEnabled, isFalse);
      expect(updated.serviceRadiusKm, 25);
      // Unchanged fields persist
      expect(updated.jobAlertsEnabled, isTrue);
      expect(updated.messageAlertsEnabled, isTrue);
    });

    test('toJson maps fields correctly', () {
      final s = UserSettings(
        preferredLanguage: 'ur',
        notificationsEnabled: false,
        jobAlertsEnabled: true,
        messageAlertsEnabled: false,
        serviceRadiusKm: 20,
      );
      final json = s.toJson();
      expect(json['preferred_language'], 'ur');
      expect(json['notifications_enabled'], false);
      expect(json['job_alerts_enabled'], true);
      expect(json['message_alerts_enabled'], false);
      expect(json['service_radius_km'], 20);
    });

    test('fromJson parses correctly with defaults for missing keys', () {
      final s = UserSettings.fromJson({'preferred_language': 'ur'});
      expect(s.preferredLanguage, 'ur');
      expect(s.notificationsEnabled, isTrue); // default
      expect(s.serviceRadiusKm, 10); // default
    });

    test('fromJson parses all fields', () {
      final s = UserSettings.fromJson({
        'preferred_language': 'ur',
        'notifications_enabled': false,
        'job_alerts_enabled': true,
        'message_alerts_enabled': false,
        'service_radius_km': 25,
      });
      expect(s.preferredLanguage, 'ur');
      expect(s.notificationsEnabled, isFalse);
      expect(s.jobAlertsEnabled, isTrue);
      expect(s.messageAlertsEnabled, isFalse);
      expect(s.serviceRadiusKm, 25);
    });

    test('toJson round-trips correctly', () {
      final original = UserSettings(
        preferredLanguage: 'ur',
        notificationsEnabled: false,
        jobAlertsEnabled: true,
        messageAlertsEnabled: true,
        serviceRadiusKm: 30,
      );
      final json = original.toJson();
      final restored = UserSettings.fromJson(json);
      expect(restored.preferredLanguage, original.preferredLanguage);
      expect(restored.notificationsEnabled, original.notificationsEnabled);
      expect(restored.jobAlertsEnabled, original.jobAlertsEnabled);
      expect(restored.messageAlertsEnabled, original.messageAlertsEnabled);
      expect(restored.serviceRadiusKm, original.serviceRadiusKm);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  //  SettingsState
  // ═════════════════════════════════════════════════════════════════════

  group('SettingsState', () {
    test('stores settings and metadata', () {
      final state = SettingsState(
        settings: const UserSettings(preferredLanguage: 'ur'),
        isLoading: true,
      );
      expect(state.settings.preferredLanguage, 'ur');
      expect(state.isLoading, isTrue);
      expect(state.isSaving, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('copyWith updates fields', () {
      final state = SettingsState(settings: const UserSettings());
      final updated = state.copyWith(
        settings: const UserSettings(preferredLanguage: 'ur'),
        isSaving: true,
      );
      expect(updated.settings.preferredLanguage, 'ur');
      expect(updated.isSaving, isTrue);
    });

    test('copyWith clearError removes error', () {
      final state = SettingsState(
        settings: const UserSettings(),
        errorMessage: 'Failed',
      );
      final cleared = state.copyWith(clearError: true);
      expect(cleared.errorMessage, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  //  WorkerProfileState
  // ═════════════════════════════════════════════════════════════════════

  group('WorkerProfileState', () {
    final baseProfile = WorkerProfile(userId: 'u1', fullName: 'Test User');

    test('requires a profile', () {
      final state = WorkerProfileState(profile: baseProfile);
      expect(state.profile.fullName, 'Test User');
      expect(state.isSaving, isFalse);
      expect(state.isGeneratingBio, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.aiSuggestionText, isNull);
      expect(state.aiSuggestedCategories, isNull);
      expect(state.tempBioInput, '');
    });

    test('copyWith updates fields correctly', () {
      final state = WorkerProfileState(profile: baseProfile);
      final updated = state.copyWith(
        isSaving: true,
        tempBioInput: 'I work in construction',
      );
      expect(updated.isSaving, isTrue);
      expect(updated.tempBioInput, 'I work in construction');
    });

    test('copyWith clearError removes error', () {
      final state = WorkerProfileState(
        profile: baseProfile,
        errorMessage: 'Some error',
      );
      final cleared = state.copyWith(clearError: true);
      expect(cleared.errorMessage, isNull);
    });

    test('copyWith clearAiSuggestion removes AI suggestion', () {
      final state = WorkerProfileState(
        profile: baseProfile,
        aiSuggestionText: 'Professional bio text',
        aiSuggestedCategories: ['Plumbing'],
      );
      final cleared = state.copyWith(clearAiSuggestion: true);
      expect(cleared.aiSuggestionText, isNull);
      expect(cleared.aiSuggestedCategories, isNull);
    });

    test('copyWith updates profile', () {
      final state = WorkerProfileState(profile: baseProfile);
      final updatedProfile = baseProfile.copyWith(fullName: 'Updated Name');
      final updated = state.copyWith(profile: updatedProfile);
      expect(updated.profile.fullName, 'Updated Name');
    });
  });
}
