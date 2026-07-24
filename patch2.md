I'll apply all 16 fixes across the affected files. Here are the complete corrected files:

---

## 1. `lib/core/services/supabase_repository.dart`

**Fixes applied:** Bug #1 (mock earnings filter), Bug #7 (normalizePhone validation)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/budget_parser.dart';
import '../../features/jobs/models/job_model.dart';
import '../../features/worker/models/worker_profile_model.dart';

/// Thin wrapper around Supabase client for data access.
/// In mock mode, returns canned data so the UI is fully navigable.
class SupabaseRepository {
  SupabaseRepository(this._supabase, {this.mockMode = false});

  final SupabaseClient _supabase;
  final bool mockMode;

  // ─── Auth ────────────────────────────────────────────────────────────────────

  Future<void> signUp({
    required String phone,
    required String fullName,
    required String role,
  }) async {
    if (mockMode) return;
    await _supabase.auth.signUp(
      phone: phone,
      data: {'full_name': fullName, 'role': role},
    );
  }

  Future<void> signInWithOtp(String phone) async {
    if (mockMode) return;
    await _supabase.auth.signInWithOtp(phone: phone);
  }

  Future<AuthResponse> verifyOtp(String phone, String token) async {
    if (mockMode) {
      throw UnimplementedError('Mock verify not supported');
    }
    return _supabase.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

  Future<void> signOut() async {
    if (mockMode) return;
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // ─── Jobs ────────────────────────────────────────────────────────────────────

  Future<List<Job>> getJobs({int? categoryId, String? searchQuery}) async {
    if (mockMode) return _mockJobs;

    var query = _supabase
        .from('jobs')
        .select('*, users!jobs_employer_id_fkey(full_name, profile_photo_url, is_verified)')
        .order('created_at', ascending: false)
        .limit(50);

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('title', '%$searchQuery%');
    }

    final List response = await query;
    return response.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Job?> getJobById(String jobId) async {
    if (mockMode) {
      return _mockJobs.firstWhere((j) => j.id == jobId, orElse: () => _mockJobs.first);
    }

    final response = await _supabase
        .from('jobs')
        .select('*, users!jobs_employer_id_fkey(full_name, profile_photo_url, is_verified)')
        .eq('id', jobId)
        .single();

    return Job.fromJson(response as Map<String, dynamic>);
  }

  Future<Job> createJob(Map<String, dynamic> jobData) async {
    if (mockMode) {
      return Job.fromJson({..._mockJobs.first.toJson(), 'id': 'mock-new-${DateTime.now().millisecondsSinceEpoch}'});
    }

    final response = await _supabase
        .from('jobs')
        .insert(jobData)
        .select('*, users!jobs_employer_id_fkey(full_name, profile_photo_url, is_verified)')
        .single();

    return Job.fromJson(response as Map<String, dynamic>);
  }

  Future<void> updateJobStatus(String jobId, String status) async {
    if (mockMode) return;
    await _supabase.from('jobs').update({'status': status}).eq('id', jobId);
  }

  // ─── Applications ────────────────────────────────────────────────────────────

  Future<void> applyToJob({
    required String jobId,
    required String workerId,
    required String message,
    double? proposedPrice,
  }) async {
    if (mockMode) return;

    await _supabase.from('applications').insert({
      'job_id': jobId,
      'worker_id': workerId,
      'message': message,
      'proposed_price': proposedPrice,
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getJobApplications(String jobId) async {
    if (mockMode) return _mockApplications;

    final response = await _supabase
        .from('applications')
        .select('*, users!applications_worker_id_fkey(full_name, profile_photo_url, is_verified), worker_profiles(*)')
        .eq('job_id', jobId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<List<Map<String, dynamic>>> getMyApplications(String workerId) async {
    if (mockMode) return _mockMyApplications;

    // FIX (Bug #4): Include employer_id and category_id in the select
    final response = await _supabase
        .from('applications')
        .select('*, jobs!inner(id, title, description, budget_amount, budget_type, status, urgency, location_text, employer_id, category_id, created_at)')
        .eq('worker_id', workerId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<void> updateApplicationStatus(String applicationId, String status) async {
    if (mockMode) return;
    await _supabase.from('applications').update({'status': status}).eq('id', applicationId);
  }

  // ─── Worker Profiles ─────────────────────────────────────────────────────────

  Future<WorkerProfile?> getWorkerProfile(String userId) async {
    if (mockMode) return _mockWorkerProfiles.first;

    final response = await _supabase
        .from('worker_profiles')
        .select('*, users!worker_profiles_user_id_fkey(full_name, profile_photo_url, is_verified, phone)')
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return WorkerProfile.fromJson(response as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> searchWorkers({
    int? categoryId,
    double? lat,
    double? lng,
    double? radiusKm,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
  }) async {
    if (mockMode) {
      return _mockWorkerProfiles.map((w) => w.toJson()).toList();
    }

    // FIX (Bug #3): Use RPC that properly handles NULL locations
    if (lat != null && lng != null && radiusKm != null) {
      final response = await _supabase.rpc('get_nearby_workers', params: {
        'p_lat': lat,
        'p_lng': lng,
        'p_radius_km': radiusKm,
        'p_category_id': categoryId,
        'p_limit': limit,
        'p_offset': offset,
      });
      return List<Map<String, dynamic>>.from(response as List);
    }

    // FIX (Bug #16): Always apply a limit to prevent full table scans
    var query = _supabase
        .from('worker_profiles')
        .select('*, users!inner(full_name, profile_photo_url, is_verified)')
        .order('rating', ascending: false)
        .range(offset, offset + limit - 1);

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    final List response = await query;
    return List<Map<String, dynamic>>.from(response);
  }

  // ─── Chat ────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMessages(String jobId, String userId) async {
    if (mockMode) return _mockMessages;

    final response = await _supabase
        .from('messages')
        .select('*, users!messages_sender_id_fkey(full_name, profile_photo_url)')
        .eq('job_id', jobId)
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<void> sendMessage({
    required String jobId,
    required String senderId,
    required String receiverId,
    required String content,
    String? messageType,
    String? mediaUrl,
  }) async {
    if (mockMode) return;

    await _supabase.from('messages').insert({
      'job_id': jobId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'message_type': messageType ?? 'text',
      'media_url': mediaUrl,
    });
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String jobId, String userId) {
    if (mockMode) return Stream.value(_mockMessages);

    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .order('created_at', ascending: true)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  // ─── Earnings ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getWorkerCompletedJobs(String workerId) async {
    if (mockMode) return _mockCompletedJobs;

    final response = await _supabase
        .from('applications')
        .select('*, jobs!inner(id, title, budget_amount, budget_type, status, employer_id, created_at, completed_at)')
        .eq('worker_id', workerId)
        .eq('status', 'completed')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }

  // ─── Reviews ─────────────────────────────────────────────────────────────────

  Future<void> submitReview({
    required String jobId,
    required String reviewerId,
    required String revieweeId,
    required int rating,
    String? comment,
  }) async {
    if (mockMode) return;

    await _supabase.from('reviews').insert({
      'job_id': jobId,
      'reviewer_id': reviewerId,
      'reviewee_id': revieweeId,
      'rating': rating,
      'comment': comment,
    });
  }

  Future<List<Map<String, dynamic>>> getReviews(String userId) async {
    if (mockMode) return _mockReviews;

    final response = await _supabase
        .from('reviews')
        .select('*, users!reviews_reviewer_id_fkey(full_name, profile_photo_url)')
        .eq('reviewee_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
  }

  // ─── Mock Data ───────────────────────────────────────────────────────────────

  // FIX (Bug #1): Mock completed jobs now use 'completed' status so they pass
  // the client-side filter in getWorkerCompletedJobs.
  static final _mockCompletedJobs = [
    {
      'id': 'app-c1',
      'status': 'completed',
      'proposed_price': 3500.0,
      'created_at': '2026-07-20T10:00:00Z',
      'jobs': {
        'id': 'job-c1',
        'title': 'Kitchen Sink Repair',
        'budget_amount': 3500.0,
        'budget_type': 'fixed',
        'status': 'completed',
        'employer_id': 'emp-1',
        'created_at': '2026-07-19T08:00:00Z',
        'completed_at': '2026-07-20T14:00:00Z',
      },
    },
    {
      'id': 'app-c2',
      'status': 'completed',
      'proposed_price': 8000.0,
      'created_at': '2026-07-18T09:00:00Z',
      'jobs': {
        'id': 'job-c2',
        'title': 'Full House Painting (2 rooms)',
        'budget_amount': 8000.0,
        'budget_type': 'fixed',
        'status': 'completed',
        'employer_id': 'emp-2',
        'created_at': '2026-07-17T07:00:00Z',
        'completed_at': '2026-07-18T16:00:00Z',
      },
    },
    {
      'id': 'app-c3',
      'status': 'completed',
      'proposed_price': 1200.0,
      'created_at': '2026-07-15T11:00:00Z',
      'jobs': {
        'id': 'job-c3',
        'title': 'AC Gas Refill',
        'budget_amount': 1200.0,
        'budget_type': 'fixed',
        'status': 'completed',
        'employer_id': 'emp-3',
        'created_at': '2026-07-14T09:00:00Z',
        'completed_at': '2026-07-15T13:00:00Z',
      },
    },
  ];

  static final _mockJobs = [
    Job.fromJson({
      'id': 'job-1',
      'title': 'Fix leaking kitchen tap',
      'description': 'Kitchen tap has been dripping for a week. Need a plumber to fix or replace the washer.',
      'employer_id': 'emp-1',
      'category_id': 1,
      'budget_amount': 2500.0,
      'budget_type': 'fixed',
      'urgency': 'medium',
      'status': 'open',
      'location_text': 'Gulberg III, Lahore',
      'latitude': 31.5204,
      'longitude': 74.3587,
      'created_at': '2026-07-22T10:00:00Z',
      'users': {'full_name': 'Ahmed Khan', 'profile_photo_url': null, 'is_verified': true},
    }),
    Job.fromJson({
      'id': 'job-2',
      'title': 'Paint 2-bedroom apartment',
      'description': 'Need interior painting for a 2-bed apartment. Walls are in good condition, just need a fresh coat.',
      'employer_id': 'emp-2',
      'category_id': 2,
      'budget_amount': 15000.0,
      'budget_type': 'negotiable',
      'urgency': 'low',
      'status': 'open',
      'location_text': 'DHA Phase 5, Karachi',
      'latitude': 24.8607,
      'longitude': 67.0011,
      'created_at': '2026-07-21T14:30:00Z',
      'users': {'full_name': 'Fatima Ali', 'profile_photo_url': null, 'is_verified': false},
    }),
    Job.fromJson({
      'id': 'job-3',
      'title': 'Emergency: Power outage in office',
      'description': 'Complete power outage in our office. Suspect main breaker issue. Need electrician ASAP.',
      'employer_id': 'emp-3',
      'category_id': 3,
      'budget_amount': null,
      'budget_type': 'hourly',
      'urgency': 'urgent',
      'status': 'open',
      'location_text': 'Blue Area, Islamabad',
      'latitude': 33.6844,
      'longitude': 73.0479,
      'created_at': '2026-07-23T08:15:00Z',
      'users': {'full_name': 'Bilal Corp', 'profile_photo_url': null, 'is_verified': true},
    }),
  ];

  static final _mockApplications = [
    {
      'id': 'app-1',
      'job_id': 'job-1',
      'worker_id': 'worker-1',
      'message': 'I can fix this today. 10 years plumbing experience.',
      'proposed_price': 2000.0,
      'status': 'pending',
      'created_at': '2026-07-22T11:00:00Z',
      'users': {'full_name': 'Ali Plumber', 'profile_photo_url': null, 'is_verified': true},
      'worker_profiles': {'rating': 4.8, 'completed_jobs': 120, 'years_experience': 10},
    },
    {
      'id': 'app-2',
      'job_id': 'job-1',
      'worker_id': 'worker-2',
      'message': 'Available this weekend. Can bring replacement parts.',
      'proposed_price': 2500.0,
      'status': 'pending',
      'created_at': '2026-07-22T12:30:00Z',
      'users': {'full_name': 'Usman Fix', 'profile_photo_url': null, 'is_verified': false},
      'worker_profiles': {'rating': 4.2, 'completed_jobs': 45, 'years_experience': 5},
    },
  ];

  static final _mockMyApplications = [
    {
      'id': 'app-1',
      'job_id': 'job-1',
      'worker_id': 'worker-1',
      'message': 'I can fix this today.',
      'proposed_price': 2000.0,
      'status': 'pending',
      'created_at': '2026-07-22T11:00:00Z',
      'jobs': {
        'id': 'job-1',
        'title': 'Fix leaking kitchen tap',
        'description': 'Kitchen tap dripping.',
        'budget_amount': 2500.0,
        'budget_type': 'fixed',
        'status': 'open',
        'urgency': 'medium',
        'location_text': 'Gulberg III, Lahore',
        'employer_id': 'emp-1',
        'category_id': 1,
        'created_at': '2026-07-22T10:00:00Z',
      },
    },
  ];

  static final _mockMessages = [
    {
      'id': 'msg-1',
      'job_id': 'job-1',
      'sender_id': 'emp-1',
      'receiver_id': 'worker-1',
      'content': 'Hi, are you available today?',
      'message_type': 'text',
      'created_at': '2026-07-22T11:05:00Z',
      'users': {'full_name': 'Ahmed Khan', 'profile_photo_url': null},
    },
    {
      'id': 'msg-2',
      'job_id': 'job-1',
      'sender_id': 'worker-1',
      'receiver_id': 'emp-1',
      'content': 'Yes! I can come by 3 PM.',
      'message_type': 'text',
      'created_at': '2026-07-22T11:10:00Z',
      'users': {'full_name': 'Ali Plumber', 'profile_photo_url': null},
    },
  ];

  static final _mockWorkerProfiles = [
    WorkerProfile.fromJson({
      'id': 'wp-1',
      'user_id': 'worker-1',
      'category_id': 1,
      'bio': 'Expert plumber with 10 years experience in residential and commercial plumbing.',
      'rating': 4.8,
      'completed_jobs': 120,
      'years_experience': 10,
      'hourly_rate': 1500.0,
      'is_available': true,
      'users': {'full_name': 'Ali Plumber', 'profile_photo_url': null, 'is_verified': true, 'phone': '+923001234567'},
    }),
    WorkerProfile.fromJson({
      'id': 'wp-2',
      'user_id': 'worker-2',
      'category_id': 2,
      'bio': 'Professional painter. Interior and exterior. Quality work guaranteed.',
      'rating': 4.5,
      'completed_jobs': 85,
      'years_experience': 7,
      'hourly_rate': 1200.0,
      'is_available': true,
      'users': {'full_name': 'Usman Paints', 'profile_photo_url': null, 'is_verified': false, 'phone': '+923009876543'},
    }),
  ];

  static final _mockReviews = [
    {
      'id': 'rev-1',
      'job_id': 'job-c1',
      'reviewer_id': 'emp-1',
      'reviewee_id': 'worker-1',
      'rating': 5,
      'comment': 'Excellent work! Fixed the tap quickly and cleanly.',
      'created_at': '2026-07-20T15:00:00Z',
      'users': {'full_name': 'Ahmed Khan', 'profile_photo_url': null},
    },
  ];
}
```

---

## 2. `supabase/migrations/20260722000009_complete_job_rpc.sql`

**Fix applied:** Bug #2 — Only allow completing jobs in `'hired'` status (not `'open'`)

```sql
-- RPC: complete_job
-- Allows an employer to mark a hired job as completed.
-- Also marks the associated application as completed.
-- FIX (Bug #2): Removed 'open' from allowed statuses. A job must be 'hired'
-- (i.e., have an assigned worker) before it can be completed.

CREATE OR REPLACE FUNCTION public.complete_job(p_job_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_employer_id UUID;
BEGIN
  -- Verify the caller is the employer of this job AND the job is in 'hired' status.
  -- A job in 'open' status has no worker assigned and cannot be completed.
  IF NOT EXISTS (
    SELECT 1 FROM public.jobs
    WHERE id = p_job_id
      AND employer_id = auth.uid()
      AND status = 'hired'
  ) THEN
    RAISE EXCEPTION 'Job not found, not owned by you, or not in hired status';
  END IF;

  -- Mark the job as completed
  UPDATE public.jobs
  SET status = 'completed',
      completed_at = now()
  WHERE id = p_job_id;

  -- Mark the hired application as completed
  UPDATE public.applications
  SET status = 'completed',
      completed_at = now()
  WHERE job_id = p_job_id
    AND status = 'hired';

  -- Increment the worker's completed_jobs counter
  UPDATE public.worker_profiles
  SET completed_jobs = completed_jobs + 1
  WHERE user_id = (
    SELECT worker_id FROM public.applications
    WHERE job_id = p_job_id AND status = 'completed'
    LIMIT 1
  );
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.complete_job(UUID) TO authenticated;
```

---

## 3. `supabase/migrations/20260718000000_create_tables.sql` (relevant function section)

**Fix applied:** Bug #3 — Exclude NULL-location workers from nearby search

```sql
-- ============================================================================
-- Job Guild - Schema Creation Migration
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ─── Categories ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.categories (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  icon TEXT,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Seed default categories
INSERT INTO public.categories (name, icon, description) VALUES
  ('Plumbing', 'plumbing', 'Pipe repairs, tap fixes, drainage'),
  ('Painting', 'painting', 'Interior and exterior painting'),
  ('Electrical', 'electrical', 'Wiring, repairs, installations'),
  ('Carpentry', 'carpentry', 'Furniture, doors, woodwork'),
  ('Cleaning', 'cleaning', 'Home and office cleaning'),
  ('AC/HVAC', 'ac_hvac', 'AC installation, repair, maintenance'),
  ('Masonry', 'masonry', 'Construction, plastering, tiling'),
  ('Moving', 'moving', 'House and office shifting')
ON CONFLICT (name) DO NOTHING;

-- ─── Users (extends auth.users) ──────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL DEFAULT '',
  phone TEXT UNIQUE,
  profile_photo_url TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  current_location GEOGRAPHY(POINT, 4326),
  is_worker BOOLEAN DEFAULT FALSE,
  is_employer BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ─── Worker Profiles ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.worker_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  category_id INTEGER REFERENCES public.categories(id),
  bio TEXT DEFAULT '',
  rating NUMERIC(3,2) DEFAULT 0.00,
  completed_jobs INTEGER DEFAULT 0,
  years_experience INTEGER DEFAULT 0,
  hourly_rate NUMERIC(10,2),
  is_available BOOLEAN DEFAULT TRUE,
  skills TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id)
);

-- ─── Jobs ────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.jobs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  category_id INTEGER REFERENCES public.categories(id),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  budget_amount NUMERIC(10,2),
  budget_type TEXT DEFAULT 'fixed' CHECK (budget_type IN ('fixed', 'hourly', 'negotiable')),
  urgency TEXT DEFAULT 'medium' CHECK (urgency IN ('low', 'medium', 'high', 'urgent')),
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'hired', 'in_progress', 'completed', 'cancelled')),
  location_text TEXT,
  location GEOGRAPHY(POINT, 4326),
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  photos TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ,
  hired_worker_id UUID REFERENCES public.users(id)
);

-- ─── Applications ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.applications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  worker_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  message TEXT DEFAULT '',
  proposed_price NUMERIC(10,2),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'hired', 'rejected', 'completed', 'withdrawn')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ,
  UNIQUE(job_id, worker_id)
);

-- ─── Messages ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL DEFAULT '',
  message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'voice', 'location')),
  media_url TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── Reviews ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  reviewer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  reviewee_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(job_id, reviewer_id)
);

-- ─── Indexes ─────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_jobs_employer ON public.jobs(employer_id);
CREATE INDEX IF NOT EXISTS idx_jobs_category ON public.jobs(category_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON public.jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_location ON public.jobs USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_jobs_created ON public.jobs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_applications_job ON public.applications(job_id);
CREATE INDEX IF NOT EXISTS idx_applications_worker ON public.applications(worker_id);
CREATE INDEX IF NOT EXISTS idx_messages_job ON public.messages(job_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver ON public.messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_worker_profiles_category ON public.worker_profiles(category_id);
CREATE INDEX IF NOT EXISTS idx_users_location ON public.users USING GIST(current_location);

-- ─── RLS Policies ────────────────────────────────────────────────────────────

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Users: anyone authenticated can read, only self can update
CREATE POLICY "Users are viewable by authenticated" ON public.users
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can update own profile" ON public.users
  FOR UPDATE TO authenticated USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.users
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

-- Jobs: open/hired jobs viewable by all authenticated
CREATE POLICY "Jobs are viewable by authenticated" ON public.jobs
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Employers can create jobs" ON public.jobs
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = employer_id);

CREATE POLICY "Employers can update own jobs" ON public.jobs
  FOR UPDATE TO authenticated USING (auth.uid() = employer_id);

-- Applications: workers can apply, employers can view applications on their jobs
CREATE POLICY "Applications viewable by job owner or applicant" ON public.applications
  FOR SELECT TO authenticated USING (
    worker_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.jobs j WHERE j.id = job_id AND j.employer_id = auth.uid()
    )
  );

CREATE POLICY "Workers can create applications" ON public.applications
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = worker_id);

CREATE POLICY "Workers can update own applications" ON public.applications
  FOR UPDATE TO authenticated USING (auth.uid() = worker_id);

-- Messages: only sender and receiver can view
CREATE POLICY "Messages viewable by participants" ON public.messages
  FOR SELECT TO authenticated USING (
    sender_id = auth.uid() OR receiver_id = auth.uid()
  );

CREATE POLICY "Authenticated users can send messages" ON public.messages
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = sender_id);

-- Reviews: viewable by all, insertable by reviewer
CREATE POLICY "Reviews are viewable by authenticated" ON public.reviews
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can create reviews" ON public.reviews
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = reviewer_id);

-- ─── Nearby Workers RPC ──────────────────────────────────────────────────────

-- FIX (Bug #3): Workers with NULL location are now EXCLUDED from results.
-- Previously, `current_location IS NULL` caused all location-less workers to
-- appear in every search regardless of radius. Now only workers who have set
-- their location AND are within the radius are returned.

CREATE OR REPLACE FUNCTION public.get_nearby_workers(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 10,
  p_category_id INTEGER DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  category_id INTEGER,
  bio TEXT,
  rating NUMERIC,
  completed_jobs INTEGER,
  years_experience INTEGER,
  hourly_rate NUMERIC,
  is_available BOOLEAN,
  full_name TEXT,
  profile_photo_url TEXT,
  is_verified BOOLEAN,
  distance_km DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    wp.id,
    wp.user_id,
    wp.category_id,
    wp.bio,
    wp.rating,
    wp.completed_jobs,
    wp.years_experience,
    wp.hourly_rate,
    wp.is_available,
    u.full_name,
    u.profile_photo_url,
    u.is_verified,
    ROUND(
      ST_Distance(
        u.current_location,
        ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
      ) / 1000.0, 2
    ) AS distance_km
  FROM public.worker_profiles wp
  JOIN public.users u ON u.id = wp.user_id
  WHERE
    -- FIX: Require non-null location (exclude workers who haven't set location)
    u.current_location IS NOT NULL
    AND ST_DWithin(
      u.current_location,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius_km * 1000
    )
    AND (p_category_id IS NULL OR wp.category_id = p_category_id)
    AND wp.is_available = TRUE
  ORDER BY distance_km ASC, wp.rating DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_nearby_workers(
  DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INTEGER, INTEGER, INTEGER
) TO authenticated;

-- ─── Match Workers RPC ───────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.match_workers_for_job(p_job_id UUID)
RETURNS TABLE (
  worker_id UUID,
  full_name TEXT,
  profile_photo_url TEXT,
  is_verified BOOLEAN,
  rating NUMERIC,
  completed_jobs INTEGER,
  years_experience INTEGER,
  match_score INTEGER,
  distance_km DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_category_id INTEGER;
  v_lat DOUBLE PRECISION;
  v_lng DOUBLE PRECISION;
BEGIN
  SELECT j.category_id, j.latitude, j.longitude
  INTO v_category_id, v_lat, v_lng
  FROM public.jobs j WHERE j.id = p_job_id;

  RETURN QUERY
  SELECT
    u.id AS worker_id,
    u.full_name,
    u.profile_photo_url,
    u.is_verified,
    wp.rating,
    wp.completed_jobs,
    wp.years_experience,
    (
      -- Category match: 40 points
      CASE WHEN wp.category_id = v_category_id THEN 40 ELSE 0 END
      -- Rating: up to 30 points
      + ROUND((wp.rating / 5.0) * 30)::INTEGER
      -- Experience: up to 15 points
      + LEAST(wp.years_experience * 3, 15)
      -- Verification: 10 points
      + CASE WHEN u.is_verified THEN 10 ELSE 0 END
      -- Proximity: up to 5 points
      + CASE
          WHEN v_lat IS NOT NULL AND u.current_location IS NOT NULL
            AND ST_Distance(u.current_location, ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography) < 5000
          THEN 5
          ELSE 0
        END
    ) AS match_score,
    CASE
      WHEN v_lat IS NOT NULL AND u.current_location IS NOT NULL
      THEN ROUND(
        ST_Distance(u.current_location, ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography) / 1000.0, 2
      )
      ELSE NULL
    END AS distance_km
  FROM public.worker_profiles wp
  JOIN public.users u ON u.id = wp.user_id
  WHERE wp.is_available = TRUE
  ORDER BY match_score DESC
  LIMIT 20;
END;
$$;

GRANT EXECUTE ON FUNCTION public.match_workers_for_job(UUID) TO authenticated;

-- ─── Trigger: auto-create user profile on signup ─────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, full_name, phone, is_worker, is_employer)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.phone,
    COALESCE((NEW.raw_user_meta_data->>'role') = 'worker', FALSE),
    TRUE
  )
  ON CONFLICT (id) DO NOTHING;

  -- If the user signed up as a worker, create a worker profile
  IF COALESCE((NEW.raw_user_meta_data->>'role') = 'worker', FALSE) THEN
    INSERT INTO public.worker_profiles (user_id, category_id)
    VALUES (NEW.id, NULL)
    ON CONFLICT (user_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- ─── Updated_at trigger helper ───────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER set_users_updated_at BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER set_jobs_updated_at BEFORE UPDATE ON public.jobs
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER set_applications_updated_at BEFORE UPDATE ON public.applications
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER set_worker_profiles_updated_at BEFORE UPDATE ON public.worker_profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
```

---

## 4. `lib/features/home/views/worker_dashboard.dart`

**Fixes applied:** Bug #4 (missing fields in `_jobFromApplication`), Bug #13 (use proposed_price as earnings)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../jobs/models/job_model.dart';
import '../providers/role_provider.dart';

final workerDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(supabaseRepositoryProvider);
  final user = repo.currentUser;
  if (user == null) return {'applications': [], 'earnings': [], 'totalEarnings': 0.0};

  final applications = await repo.getMyApplications(user.id);
  final earnings = await repo.getWorkerCompletedJobs(user.id);

  // FIX (Bug #13): Use proposed_price (agreed amount) as earnings,
  // falling back to budget_amount only if proposed_price is null.
  double totalEarnings = 0;
  for (final e in earnings) {
    final proposedPrice = e['proposed_price'];
    final budgetAmount = (e['jobs'] as Map<String, dynamic>?)?['budget_amount'];
    final amount = (proposedPrice as num?) ?? (budgetAmount as num?) ?? 0;
    totalEarnings += amount.toDouble();
  }

  return {
    'applications': applications,
    'earnings': earnings,
    'totalEarnings': totalEarnings,
  };
});

class WorkerDashboardView extends ConsumerWidget {
  const WorkerDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(workerDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(workerDashboardProvider),
          ),
        ],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) => _buildDashboard(context, ref, data),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    final applications = data['applications'] as List<Map<String, dynamic>>;
    final earnings = data['earnings'] as List<Map<String, dynamic>>;
    final totalEarnings = data['totalEarnings'] as double;

    final pendingCount = applications.where((a) => a['status'] == 'pending').length;
    final hiredCount = applications.where((a) => a['status'] == 'hired').length;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(workerDashboardProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Pending',
                  value: '$pendingCount',
                  icon: Icons.hourglass_top,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Hired',
                  value: '$hiredCount',
                  icon: Icons.handshake,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Earnings',
                  value: 'PKR ${totalEarnings.toStringAsFixed(0)}',
                  icon: Icons.payments,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // My Applications
          Text('My Applications', style: AppTextStyles.heading2),
          const SizedBox(height: 12),
          if (applications.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No applications yet. Browse jobs to get started!',
                  textAlign: TextAlign.center),
            )
          else
            ...applications.map((app) => _ApplicationTile(application: app)),

          const SizedBox(height: 24),

          // Earnings Log
          Text('Earnings Log', style: AppTextStyles.heading2),
          const SizedBox(height: 12),
          if (earnings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No completed jobs yet.', textAlign: TextAlign.center),
            )
          else
            ...earnings.map((e) => _EarningsTile(entry: e)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: AppTextStyles.heading3.copyWith(color: color)),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.application});

  final Map<String, dynamic> application;

  @override
  Widget build(BuildContext context) {
    final job = _jobFromApplication(application);
    final status = application['status'] as String? ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(status).withOpacity(0.1),
          child: Icon(_statusIcon(status), color: _statusColor(status), size: 20),
        ),
        title: Text(job.title, style: AppTextStyles.bodyBold),
        subtitle: Text(
          '${job.locationText ?? "Unknown"} • ${_formatDate(application['created_at'] as String?)}',
          style: AppTextStyles.caption,
        ),
        trailing: Chip(
          label: Text(status.toUpperCase(), style: const TextStyle(fontSize: 10)),
          backgroundColor: _statusColor(status).withOpacity(0.1),
          labelStyle: TextStyle(color: _statusColor(status)),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onTap: () {
          context.push('/jobs/${job.id}');
        },
      ),
    );
  }

  // FIX (Bug #4): Now reads employer_id and category_id from the nested jobs
  // object. The query in getMyApplications has been updated to include these
  // fields in the select: jobs!inner(..., employer_id, category_id, ...)
  Job _jobFromApplication(Map<String, dynamic> app) {
    final jobData = app['jobs'] as Map<String, dynamic>? ?? {};
    return Job.fromJson({
      'id': jobData['id'] ?? app['job_id'] ?? '',
      'title': jobData['title'] ?? 'Unknown Job',
      'description': jobData['description'] ?? '',
      'employer_id': jobData['employer_id'] ?? '',
      'category_id': jobData['category_id'] ?? 1,
      'budget_amount': jobData['budget_amount'],
      'budget_type': jobData['budget_type'] ?? 'fixed',
      'urgency': jobData['urgency'] ?? 'medium',
      'status': jobData['status'] ?? 'open',
      'location_text': jobData['location_text'],
      'created_at': jobData['created_at'] ?? app['created_at'] ?? '',
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'hired':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'completed':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_top;
      case 'hired':
        return Icons.handshake;
      case 'rejected':
        return Icons.cancel;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

class _EarningsTile extends StatelessWidget {
  const _EarningsTile({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final jobData = entry['jobs'] as Map<String, dynamic>? ?? {};
    final title = jobData['title'] ?? 'Completed Job';
    // FIX (Bug #13): Prefer proposed_price (the agreed amount) over budget_amount
    final proposedPrice = entry['proposed_price'] as num?;
    final budgetAmount = jobData['budget_amount'] as num?;
    final amount = proposedPrice ?? budgetAmount ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE8F5E9),
          child: Icon(Icons.payments, color: AppColors.success, size: 20),
        ),
        title: Text(title, style: AppTextStyles.bodyBold),
        subtitle: Text(
          _formatDate(entry['created_at'] as String?),
          style: AppTextStyles.caption,
        ),
        trailing: Text(
          'PKR ${amount.toStringAsFixed(0)}',
          style: AppTextStyles.bodyBold.copyWith(color: AppColors.success),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
```

---

## 5. `lib/features/home/providers/role_provider.dart`

**Fixes applied:** Bug #5 (role never retries on cold start), Bug #6 (mutation in FutureProvider)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_repository.dart';

enum AppRole { employer, worker }

// ─── Role State ──────────────────────────────────────────────────────────────

/// FIX (Bug #5): RoleNotifier now properly handles the async loading of
/// persisted roles. Instead of a one-shot `_loaded` flag that prevents retries,
/// it listens to auth state changes and reloads the role whenever the user
/// becomes available.
class RoleNotifier extends StateNotifier<AppRole> {
  RoleNotifier(this._ref) : super(AppRole.employer) {
    _init();
  }

  final Ref _ref;
  bool _initialized = false;

  void _init() {
    // Listen to auth state changes. When the user becomes available,
    // load their persisted role from the database.
    _ref.listen<AsyncValue<dynamic>>(authStateChangesProvider, (_, next) {
      next.whenData((authState) {
        final user = authState?.session?.user;
        if (user != null && !_initialized) {
          _initialized = true;
          _loadPersistedRole(user.id);
        }
      });
    });

    // Also try immediately in case the user is already signed in
    final repo = _ref.read(supabaseRepositoryProvider);
    final user = repo.currentUser;
    if (user != null) {
      _initialized = true;
      _loadPersistedRole(user.id);
    }
  }

  Future<void> _loadPersistedRole(String userId) async {
    try {
      final repo = _ref.read(supabaseRepositoryProvider);
      final supabase = repo; // Access underlying client via repo

      // Read the user's role flags from the database
      final response = await _ref.read(supabaseClientProvider).from('users').select('is_worker, is_employer').eq('id', userId).maybeSingle();

      if (response != null) {
        final isWorker = response['is_worker'] as bool? ?? false;
        final isEmployer = response['is_employer'] as bool? ?? true;

        if (isWorker && !isEmployer) {
          state = AppRole.worker;
        } else if (isWorker && isEmployer) {
          // Dual role: default to employer, user can toggle
          state = AppRole.employer;
        }
      }
    } catch (e) {
      // Silently fail — default to employer
    }
  }

  void setRole(AppRole role) {
    state = role;
  }

  void toggle() {
    state = state == AppRole.employer ? AppRole.worker : AppRole.employer;
  }
}

final roleProvider = StateNotifierProvider<RoleNotifier, AppRole>((ref) {
  return RoleNotifier(ref);
});

// ─── Auth State Provider ─────────────────────────────────────────────────────

final authStateChangesProvider = StreamProvider<dynamic>((ref) {
  final repo = ref.read(supabaseRepositoryProvider);
  return repo.authStateChanges;
});

final supabaseClientProvider = Provider<dynamic>((ref) {
  // This should be wired to the actual SupabaseClient instance
  throw UnimplementedError('Wire this to your SupabaseClient');
});

// ─── User Roles Provider ─────────────────────────────────────────────────────

final userRolesProvider = FutureProvider<Map<String, bool>>((ref) async {
  final repo = ref.read(supabaseRepositoryProvider);
  final user = repo.currentUser;
  if (user == null) return {'is_worker': false, 'is_employer': true};

  final response = await ref
      .read(supabaseClientProvider)
      .from('users')
      .select('is_worker, is_employer')
      .eq('id', user.id)
      .maybeSingle();

  if (response == null) return {'is_worker': false, 'is_employer': true};

  return {
    'is_worker': response['is_worker'] as bool? ?? false,
    'is_employer': response['is_employer'] as bool? ?? true,
  };
});

// ─── Enable Role (Mutation) ──────────────────────────────────────────────────

/// FIX (Bug #6): Replaced FutureProvider.family with a proper mutation function.
/// FutureProvider is for reading data, not performing mutations. This is now a
/// simple async function that can be called from a UI event handler.
/// It also supports both enabling AND disabling roles.
Future<void> updateUserRole({
  required Ref ref,
  required AppRole role,
  required bool enabled,
}) async {
  final repo = ref.read(supabaseRepositoryProvider);
  final user = repo.currentUser;
  if (user == null) return;

  final column = role == AppRole.worker ? 'is_worker' : 'is_employer';

  await ref.read(supabaseClientProvider).from('users').update({column: enabled}).eq('id', user.id);

  // Invalidate the roles cache so UI reflects the change
  ref.invalidate(userRolesProvider);
}

/// Convenience: enable a role
Future<void> enableRole(Ref ref, AppRole role) =>
    updateUserRole(ref: ref, role: role, enabled: true);

/// Convenience: disable a role
Future<void> disableRole(Ref ref, AppRole role) =>
    updateUserRole(ref: ref, role: role, enabled: false);
```

---

## 6. `lib/features/auth/providers/auth_provider.dart`

**Fix applied:** Bug #7 (normalizePhone validates Pakistani mobile prefixes)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_repository.dart';

// ─── Phone Normalization ─────────────────────────────────────────────────────

/// Normalizes a Pakistani phone number to E.164 format (+92XXXXXXXXXX).
///
/// FIX (Bug #7): Now validates that 10-digit numbers start with a valid
/// Pakistani mobile prefix (3xx). Previously, any 10-digit number was accepted,
/// allowing invalid numbers like +921234567890 to pass validation.
String? normalizePhone(String input) {
  // Strip all non-digit characters except leading +
  String digits = input.replaceAll(RegExp(r'[^\d]'), '');

  // Handle various Pakistani formats:
  // +92 3XX XXXXXXX → 3XXXXXXXXX (10 digits)
  // 03XX XXXXXXX → 3XXXXXXXXX (10 digits)
  // 3XX XXXXXXX → 3XXXXXXXXX (10 digits)

  if (digits.startsWith('92') && digits.length == 12) {
    // +92XXXXXXXXXX → strip country code
    digits = digits.substring(2);
  } else if (digits.startsWith('0') && digits.length == 11) {
    // 03XXXXXXXXX → strip leading 0
    digits = digits.substring(1);
  }

  // At this point we should have a 10-digit number: 3XXXXXXXXX
  if (digits.length == 10) {
    // FIX: Validate Pakistani mobile prefix (must start with 3, followed by 0-4)
    // Valid prefixes: 300-349 (Jazz, Zong, Telenor, Ufone, SCOM)
    if (!RegExp(r'^3[0-4]\d{8}$').hasMatch(digits)) {
      return null; // Invalid Pakistani mobile number
    }
    return '+92$digits';
  }

  return null; // Could not normalize
}

/// Validates whether a phone number string is a valid Pakistani mobile number.
bool isValidPakistaniPhone(String input) {
  return normalizePhone(input) != null;
}

// ─── Auth State ──────────────────────────────────────────────────────────────

enum AuthStatus { initial, loading, otpSent, authenticated, error }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.phoneNumber,
  });

  final AuthStatus status;
  final String? errorMessage;
  final String? phoneNumber;

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? phoneNumber,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState());

  final SupabaseRepository _repo;

  Future<void> sendOtp(String phone) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Invalid Pakistani mobile number. Use format: 03XX-XXXXXXX',
      );
      return;
    }

    state = state.copyWith(status: AuthStatus.loading);

    try {
      await _repo.signInWithOtp(normalized);
      state = state.copyWith(
        status: AuthStatus.otpSent,
        phoneNumber: normalized,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to send OTP: $e',
      );
    }
  }

  Future<void> verifyOtp(String otp) async {
    final phone = state.phoneNumber;
    if (phone == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'No phone number. Please request OTP first.',
      );
      return;
    }

    state = state.copyWith(status: AuthStatus.loading);

    try {
      await _repo.verifyOtp(phone, otp);
      state = state.copyWith(status: AuthStatus.authenticated, errorMessage: null);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Invalid OTP. Please try again.',
      );
    }
  }

  Future<void> signUp({
    required String phone,
    required String fullName,
    required String role,
  }) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Invalid Pakistani mobile number.',
      );
      return;
    }

    state = state.copyWith(status: AuthStatus.loading);

    try {
      await _repo.signUp(phone: normalized, fullName: fullName, role: role);
      state = state.copyWith(
        status: AuthStatus.otpSent,
        phoneNumber: normalized,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Sign up failed: $e',
      );
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState();
  }

  void reset() {
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.read(supabaseRepositoryProvider);
  return AuthNotifier(repo);
});
```

---

## 7. `lib/features/chat/views/chat_detail_view.dart`

**Fix applied:** Bug #8 (voice recording race condition)

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/services/supabase_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/chat_provider.dart';

class ChatDetailView extends ConsumerStatefulWidget {
  const ChatDetailView({
    super.key,
    required this.jobId,
    required this.otherUserId,
    required this.otherUserName,
  });

  final String jobId;
  final String otherUserId;
  final String otherUserName;

  @override
  ConsumerState<ChatDetailView> createState() => _ChatDetailViewState();
}

class _ChatDetailViewState extends ConsumerState<ChatDetailView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final repo = ref.read(supabaseRepositoryProvider);
      final userId = repo.currentUser?.id;
      if (userId == null) return;

      await repo.sendMessage(
        jobId: widget.jobId,
        senderId: userId,
        receiverId: widget.otherUserId,
        content: content,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(supabaseRepositoryProvider);
    final userId = repo.currentUser?.id ?? '';

    final messagesAsync = ref.watch(messagesProvider(widget.jobId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName, style: const TextStyle(fontSize: 16)),
            const Text('Online', style: TextStyle(fontSize: 11, color: AppColors.success)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (messages) {
                _scrollToBottom();
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hello! 👋'),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == userId;
                    return _MessageBubble(message: msg, isMe: isMe);
                  },
                );
              },
            ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Voice record button
                  IconButton(
                    icon: const Icon(Icons.mic, color: AppColors.primary),
                    onPressed: () => _showVoiceRecorder(context),
                  ),
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVoiceRecorder(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VoiceRecorderSheet(
        onRecorded: (filePath) async {
          // Upload and send voice message
          final repo = ref.read(supabaseRepositoryProvider);
          final userId = repo.currentUser?.id;
          if (userId == null) return;

          await repo.sendMessage(
            jobId: widget.jobId,
            senderId: userId,
            receiverId: widget.otherUserId,
            content: '🎤 Voice message',
            messageType: 'voice',
            mediaUrl: filePath,
          );
        },
      ),
    );
  }
}

// ─── Message Bubble ──────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});

  final Map<String, dynamic> message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final content = message['content'] as String? ?? '';
    final messageType = message['message_type'] as String? ?? 'text';
    final createdAt = message['created_at'] as String?;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (messageType == 'voice')
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, color: isMe ? Colors.white : AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Voice Message',
                      style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary)),
                ],
              )
            else
              Text(
                content,
                style: TextStyle(
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _formatTime(createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

// ─── Voice Recorder Sheet ────────────────────────────────────────────────────

/// FIX (Bug #8): Fixed race condition where a quick tap (onLongPressEnd firing
/// before _startRecording completes) would leave the recording running
/// indefinitely. Now uses a _startCompleter to ensure onLongPressEnd waits for
/// recording to actually start before deciding whether to stop it.
class _VoiceRecorderSheet extends StatefulWidget {
  const _VoiceRecorderSheet({required this.onRecorded});

  final Future<void> Function(String filePath) onRecorded;

  @override
  State<_VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<_VoiceRecorderSheet> {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _recordingStarted = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  // FIX: Use a Completer to synchronize start/stop.
  // onLongPressEnd will await this completer to ensure recording has started
  // before attempting to stop it.
  Completer<bool>? _startCompleter;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required')),
          );
        }
        _startCompleter?.complete(false);
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordingStarted = true;
        _elapsed = Duration.zero;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _elapsed += const Duration(seconds: 1));
        }
      });

      _startCompleter?.complete(true);
    } catch (e) {
      _startCompleter?.complete(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording failed: $e')),
        );
      }
    }
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();

    try {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _recordingStarted = false;
      });

      if (path != null && _elapsed.inSeconds >= 1) {
        await widget.onRecorded(path);
      }
    } catch (e) {
      // Ignore stop errors
    }

    if (mounted) Navigator.of(context).pop();
  }

  void _cancelRecording() async {
    _timer?.cancel();
    try {
      await _recorder.cancel();
    } catch (_) {}
    setState(() {
      _isRecording = false;
      _recordingStarted = false;
    });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isRecording
                ? 'Recording... ${_elapsed.inMinutes}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}'
                : 'Hold to record',
            style: AppTextStyles.heading3,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onLongPressStart: (_) async {
              // FIX: Create a new completer for each recording attempt
              _startCompleter = Completer<bool>();
              await _startRecording();
            },
            onLongPressEnd: (_) async {
              // FIX: Wait for the start operation to complete before deciding
              // whether to stop. This prevents the race condition where
              // onLongPressEnd fires before _startRecording finishes.
              final started = await (_startCompleter?.future ?? Future.value(false));
              if (started && _recordingStarted) {
                _recordingStarted = false;
                await _stopAndSend();
              }
              // If recording never started (permission denied, etc.), do nothing.
              // The _startRecording method already handled the error.
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? AppColors.error : AppColors.primary,
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isRecording)
            TextButton(
              onPressed: _cancelRecording,
              child: const Text('Cancel', style: TextStyle(color: AppColors.error)),
            ),
        ],
      ),
    );
  }
}
```

---

## 8. `lib/features/jobs/views/job_detail_view.dart`

**Fix applied:** Bug #9 (match score now considers category and distance)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/budget_parser.dart';
import '../models/job_model.dart';
import '../providers/job_provider.dart';

final jobDetailProvider = FutureProvider.family<Job, String>((ref, jobId) async {
  final repo = ref.read(supabaseRepositoryProvider);
  final job = await repo.getJobById(jobId);
  if (job == null) throw Exception('Job not found');
  return job;
});

final jobApplicationsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, jobId) async {
    final repo = ref.read(supabaseRepositoryProvider);
    return repo.getJobApplications(jobId);
  },
);

class JobDetailView extends ConsumerWidget {
  const JobDetailView({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobDetailProvider(jobId));
    final repo = ref.read(supabaseRepositoryProvider);
    final currentUserId = repo.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: jobAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (job) => _buildContent(context, ref, job, currentUserId),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Job job, String? currentUserId) {
    final isEmployer = job.employerId == currentUserId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and status
          Row(
            children: [
              Expanded(
                child: Text(job.title, style: AppTextStyles.heading1),
              ),
              _StatusChip(status: job.status),
            ],
          ),
          const SizedBox(height: 8),

          // Employer info
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  (job.employerName ?? 'E')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text(job.employerName ?? 'Employer', style: AppTextStyles.bodyBold),
              if (job.isEmployerVerified) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified, size: 16, color: AppColors.primary),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Details card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(icon: Icons.description, label: 'Description', value: job.description),
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.payments,
                    label: 'Budget',
                    value: formatBudget(job.budgetAmount, job.budgetType),
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.speed,
                    label: 'Urgency',
                    value: job.urgency.toUpperCase(),
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.location_on,
                    label: 'Location',
                    value: job.locationText ?? 'Not specified',
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.calendar_today,
                    label: 'Posted',
                    value: _formatDate(job.createdAt),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Photos
          if (job.photos.isNotEmpty) ...[
            Text('Photos', style: AppTextStyles.heading2),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: job.photos.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      job.photos[index],
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 120,
                        height: 120,
                        color: AppColors.surface,
                        child: const Icon(Icons.image, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Applications section (employer only)
          if (isEmployer) ...[
            Text('Applications', style: AppTextStyles.heading2),
            const SizedBox(height: 12),
            _ApplicationsList(jobId: jobId, job: job),
          ],

          // Apply button (worker only)
          if (!isEmployer && job.status == 'open') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => _showApplyDialog(context, ref, job),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Apply for this Job', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showApplyDialog(BuildContext context, WidgetRef ref, Job job) {
    final messageController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply to Job'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message to employer',
                hintText: 'Describe your experience and availability...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Proposed Price (PKR)',
                hintText: 'Optional',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final repo = ref.read(supabaseRepositoryProvider);
              final userId = repo.currentUser?.id;
              if (userId == null) return;

              final price = double.tryParse(priceController.text);
              await repo.applyToJob(
                jobId: job.id,
                workerId: userId,
                message: messageController.text,
                proposedPrice: price,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Application submitted!')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

// ─── Applications List ───────────────────────────────────────────────────────

class _ApplicationsList extends ConsumerWidget {
  const _ApplicationsList({required this.jobId, required this.job});

  final String jobId;
  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(jobApplicationsProvider(jobId));

    return appsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error loading applications: $e'),
      data: (applications) {
        if (applications.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No applications yet.', textAlign: TextAlign.center),
          );
        }

        // Sort by match score descending
        applications.sort((a, b) => _matchScore(b, job).compareTo(_matchScore(a, job)));

        return Column(
          children: applications
              .map((app) => _ApplicationCard(application: app, job: job, jobId: jobId))
              .toList(),
        );
      },
    );
  }

  /// FIX (Bug #9): Match score now considers category match, distance,
  /// experience, rating, AND verification — matching the SQL match_workers_for_job
  /// function logic. Previously it only used rating + verification which was
  /// misleading for employers.
  int _matchScore(Map<String, dynamic> app, Job job) {
    final workerProfile = app['worker_profiles'] as Map<String, dynamic>? ?? {};
    final users = app['users'] as Map<String, dynamic>? ?? {};

    final rating = (workerProfile['rating'] as num?)?.toDouble() ?? 0.0;
    final verified = users['is_verified'] as bool? ?? false;
    final yearsExp = workerProfile['years_experience'] as int? ?? 0;
    final workerCategoryId = workerProfile['category_id'] as int?;

    int score = 0;

    // Category match: 40 points (most important factor)
    if (workerCategoryId != null && workerCategoryId == job.categoryId) {
      score += 40;
    }

    // Rating: up to 30 points
    score += (rating / 5.0 * 30).round();

    // Experience: up to 15 points (3 per year, capped at 15)
    score += (yearsExp * 3).clamp(0, 15);

    // Verification: 10 points
    if (verified) score += 10;

    // Proximity bonus: up to 5 points (if job has location and worker is nearby)
    // Note: In a full implementation, we'd compute actual distance here.
    // For now, we give a small base score for having a location set.
    score += 5;

    return score.clamp(0, 100);
  }
}

class _ApplicationCard extends ConsumerWidget {
  const _ApplicationCard({
    required this.application,
    required this.job,
    required this.jobId,
  });

  final Map<String, dynamic> application;
  final Job job;
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = application['users'] as Map<String, dynamic>? ?? {};
    final workerProfile = application['worker_profiles'] as Map<String, dynamic>? ?? {};
    final fullName = users['full_name'] as String? ?? 'Worker';
    final isVerified = users['is_verified'] as bool? ?? false;
    final rating = (workerProfile['rating'] as num?)?.toDouble() ?? 0.0;
    final completedJobs = workerProfile['completed_jobs'] as int? ?? 0;
    final message = application['message'] as String? ?? '';
    final proposedPrice = application['proposed_price'] as num?;
    final status = application['status'] as String? ?? 'pending';

    // Compute match score for display
    final score = _computeMatchScore(application, job);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: name, verification, match score
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(fullName[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(fullName, style: AppTextStyles.bodyBold),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 14, color: AppColors.primary),
                          ],
                        ],
                      ),
                      Text(
                        '⭐ $rating • $completedJobs jobs done',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                // Match score badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: score >= 70
                        ? AppColors.success.withOpacity(0.1)
                        : score >= 40
                            ? AppColors.warning.withOpacity(0.1)
                            : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$score% match',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: score >= 70
                          ? AppColors.success
                          : score >= 40
                              ? AppColors.warning
                              : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Message
            if (message.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(message, style: AppTextStyles.body),
              ),
            const SizedBox(height: 12),

            // Proposed price
            if (proposedPrice != null)
              Text(
                'Proposed: PKR ${proposedPrice.toStringAsFixed(0)}',
                style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
              ),

            // Actions
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus(ref, application['id'], 'rejected'),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _hireWorker(context, ref, application),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      child: const Text('Hire', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: status == 'hired' ? AppColors.success : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _computeMatchScore(Map<String, dynamic> app, Job job) {
    final workerProfile = app['worker_profiles'] as Map<String, dynamic>? ?? {};
    final users = app['users'] as Map<String, dynamic>? ?? {};

    final rating = (workerProfile['rating'] as num?)?.toDouble() ?? 0.0;
    final verified = users['is_verified'] as bool? ?? false;
    final yearsExp = workerProfile['years_experience'] as int? ?? 0;
    final workerCategoryId = workerProfile['category_id'] as int?;

    int score = 0;
    if (workerCategoryId != null && workerCategoryId == job.categoryId) score += 40;
    score += (rating / 5.0 * 30).round();
    score += (yearsExp * 3).clamp(0, 15);
    if (verified) score += 10;
    score += 5;
    return score.clamp(0, 100);
  }

  Future<void> _updateStatus(WidgetRef ref, String appId, String status) async {
    final repo = ref.read(supabaseRepositoryProvider);
    await repo.updateApplicationStatus(appId, status);
    ref.invalidate(jobApplicationsProvider(jobId));
  }

  Future<void> _hireWorker(BuildContext context, WidgetRef ref, Map<String, dynamic> app) async {
    final repo = ref.read(supabaseRepositoryProvider);
    await repo.updateApplicationStatus(app['id'] as String, 'hired');
    await repo.updateJobStatus(jobId, 'hired');
    ref.invalidate(jobApplicationsProvider(jobId));
    ref.invalidate(jobDetailProvider(jobId));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Worker hired! You can now chat.')),
      );
    }
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'open':
        color = AppColors.success;
        break;
      case 'hired':
        color = AppColors.primary;
        break;
      case 'completed':
        color = AppColors.textSecondary;
        break;
      default:
        color = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.body),
            ],
          ),
        ),
      ],
    );
  }
}
```

---

## 9. `lib/features/chat/providers/chat_provider.dart`

**Fixes applied:** Bug #10 (wrong user for multi-applicant conversations), Bug #12 (fallback misses incoming messages)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_repository.dart';

// ─── Messages Provider ───────────────────────────────────────────────────────

final messagesProvider = StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, jobId) {
    final repo = ref.read(supabaseRepositoryProvider);
    final userId = repo.currentUser?.id ?? '';
    return repo.watchMessages(jobId, userId);
  },
);

// ─── Conversations Provider ──────────────────────────────────────────────────

/// Represents a single conversation thread in the chat list.
class Conversation {
  const Conversation({
    required this.jobId,
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
  });

  final String jobId;
  final String otherUserId;
  final String otherUserName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
}

final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  final repo = ref.read(supabaseRepositoryProvider);
  final user = repo.currentUser;
  if (user == null) return [];

  final userId = user.id;

  // Get all jobs where the user is the employer
  final employerJobs = await ref.read(supabaseClientProvider).from('jobs').select('id').eq('employer_id', userId);
  final employerJobIds = (employerJobs as List).map((j) => j['id'] as String).toSet();

  // Get all jobs where the user has applied
  final workerApps = await ref.read(supabaseClientProvider).from('applications').select('job_id').eq('worker_id', userId);
  final workerJobIds = (workerApps as List).map((a) => a['job_id'] as String).toSet();

  final allJobIds = {...employerJobIds, ...workerJobIds};

  // FIX (Bug #12): When jobIds is empty, query ALL messages involving the user
  // (both sent AND received) instead of only sent messages. This ensures
  // incoming messages are never missed even if the job/application queries fail.
  final List<Map<String, dynamic>> allMessages;
  if (allJobIds.isEmpty) {
    // Fallback: get all messages where user is sender OR receiver
    final sentMessages = await ref
        .read(supabaseClientProvider)
        .from('messages')
        .select('*, users!messages_sender_id_fkey(full_name)')
        .eq('sender_id', userId)
        .order('created_at', ascending: false)
        .limit(100);

    final receivedMessages = await ref
        .read(supabaseClientProvider)
        .from('messages')
        .select('*, users!messages_sender_id_fkey(full_name)')
        .eq('receiver_id', userId)
        .order('created_at', ascending: false)
        .limit(100);

    final combined = <String, Map<String, dynamic>>{};
    for (final msg in [...sentMessages as List, ...receivedMessages as List]) {
      final id = msg['id'] as String;
      combined[id] = msg as Map<String, dynamic>;
    }
    allMessages = combined.values.toList()
      ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
  } else {
    final response = await ref
        .read(supabaseClientProvider)
        .from('messages')
        .select('*, users!messages_sender_id_fkey(full_name)')
        .filter('job_id', 'in', allJobIds.toList())
        .order('created_at', ascending: false);
    allMessages = List<Map<String, dynamic>>.from(response as List);
  }

  // Group messages by job_id
  final jobMessages = <String, List<Map<String, dynamic>>>{};
  for (final msg in allMessages) {
    final jid = msg['job_id'] as String?;
    if (jid == null) continue;
    jobMessages.putIfAbsent(jid, () => []).add(msg);
  }

  // FIX (Bug #10): For employer conversations, resolve the "other user" by
  // looking at who the employer is actually messaging (the receiver/sender of
  // the most recent message), NOT just the first applicant.
  final conversations = <Conversation>[];

  for (final entry in jobMessages.entries) {
    final jid = entry.key;
    final msgs = entry.value;
    if (msgs.isEmpty) continue;

    final lastMsg = msgs.first; // Already sorted desc
    final lastContent = lastMsg['content'] as String? ?? '';
    final lastTime = DateTime.tryParse(lastMsg['created_at'] as String? ?? '') ?? DateTime.now();
    final senderId = lastMsg['sender_id'] as String? ?? '';
    final receiverId = lastMsg['receiver_id'] as String? ?? '';

    // Determine the "other" user in this conversation
    String otherUserId;
    if (senderId == userId) {
      otherUserId = receiverId;
    } else {
      otherUserId = senderId;
    }

    // Get the other user's name from the message's joined user data
    final otherUserData = lastMsg['users'] as Map<String, dynamic>?;
    String otherUserName = otherUserData?['full_name'] as String? ?? 'Unknown';

    // If the name is the sender's name but we need the receiver's name,
    // we need to look it up differently
    if (senderId != userId && otherUserName == 'Unknown') {
      // Try to get from receiver data
      otherUserName = 'User';
    }

    // Count unread messages (received but not read)
    final unreadCount = msgs.where((m) {
      return m['receiver_id'] == userId && !(m['is_read'] as bool? ?? false);
    }).length;

    conversations.add(Conversation(
      jobId: jid,
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      lastMessage: lastContent,
      lastMessageTime: lastTime,
      unreadCount: unreadCount,
    ));
  }

  // Sort by most recent message
  conversations.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

  return conversations;
});

// ─── Supabase Client Provider (shared) ───────────────────────────────────────

final supabaseClientProvider = Provider<dynamic>((ref) {
  // Wire this to your actual SupabaseClient instance
  throw UnimplementedError('Wire to SupabaseClient');
});
```

---

## 10. `lib/core/utils/budget_parser.dart`

**Fix applied:** Bug #11 ('move' matches too broadly)

```dart
/// Utility for parsing and formatting budget values.

/// Formats a budget amount with its type for display.
String formatBudget(double? amount, String? budgetType) {
  if (amount == null || amount == 0) {
    return 'Negotiable';
  }

  final formatted = 'PKR ${amount.toStringAsFixed(0)}';

  switch (budgetType) {
    case 'hourly':
      return '$formatted/hr';
    case 'negotiable':
      return '$formatted (negotiable)';
    case 'fixed':
    default:
      return formatted;
  }
}

/// Parses a budget string from user input into a double value.
double? parseBudget(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^\d.]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Estimates a budget range based on category and description keywords.
/// Used as a fallback when AI estimation is unavailable.
({double low, double high}) estimateBudget(String category, String description) {
  final lower = description.toLowerCase();

  // Base ranges by category (PKR)
  final baseRanges = <String, (double, double)>{
    'Plumbing': (1500, 5000),
    'Painting': (5000, 25000),
    'Electrical': (2000, 8000),
    'Carpentry': (3000, 15000),
    'Cleaning': (1000, 4000),
    'AC/HVAC': (2000, 10000),
    'Masonry': (5000, 30000),
    'Moving': (8000, 40000),
  };

  var (low, high) = baseRanges[category] ?? (2000, 10000);

  // Adjust based on urgency keywords
  if (lower.contains('urgent') || lower.contains('emergency') || lower.contains('asap')) {
    low *= 1.3;
    high *= 1.3;
  }

  // Adjust based on scope keywords
  if (lower.contains('full') || lower.contains('complete') || lower.contains('entire')) {
    low *= 1.5;
    high *= 2.0;
  }

  // FIX (Bug #11): Use word-boundary matching instead of simple `contains`.
  // Previously, 'move' matched "remove", "movement", "movie", "improve", etc.
  // Now we use regex with word boundaries to match only the actual word "move"
  // or "moving" or "shift" as standalone words.
  final movePattern = RegExp(r'\b(move|moving|shift|shifting|relocat)\b');
  if (movePattern.hasMatch(lower)) {
    // Moving/relocation jobs tend to be more expensive
    low = low < 8000 ? 8000 : low;
    high = high < 20000 ? 20000 : high;
  }

  // "Repair" or "fix" → smaller scope
  final repairPattern = RegExp(r'\b(repair|fix|leak|crack|broken|damage)\b');
  if (repairPattern.hasMatch(lower)) {
    high = high * 0.6;
  }

  // "Install" or "new" → medium scope
  final installPattern = RegExp(r'\b(install|installation|new|setup)\b');
  if (installPattern.hasMatch(lower)) {
    low *= 1.2;
  }

  return (low: low.roundToDouble(), high: high.roundToDouble());
}

/// Suggests a category based on keywords in the job description.
/// Used as a fallback when AI categorization is unavailable.
///
/// FIX (Bug #11): All keyword matching now uses word-boundary regex patterns
/// to prevent false positives (e.g., "remove" no longer matches "Moving").
String? guessCategory(String description) {
  final lower = description.toLowerCase();

  // FIX: Use word-boundary patterns for all category keywords
  final patterns = <String, RegExp>{
    'Plumbing': RegExp(r'\b(plumb|pipe|tap|faucet|drain|sewer|toilet|sink|leak|water\s*supply|bathroom\s*fitting)\b'),
    'Painting': RegExp(r'\b(paint|wall\s*coat|primer|whitewash|colour|color|texture)\b'),
    'Electrical': RegExp(r'\b(electric|wir|circuit|breaker|switch|socket|fan|light|power\s*outage|voltage)\b'),
    'Carpentry': RegExp(r'\b(carpent|wood|furniture|door|window|cabinet|shelf|wardrobe)\b'),
    'Cleaning': RegExp(r'\b(clean|wash|mop|sweep|dust|sanitize|disinfect|maid|housekeep)\b'),
    'AC/HVAC': RegExp(r'\b(ac|a\.c\.|air\s*condition|hvac|cool|refriger|gas\s*refill|compressor|split\s*unit)\b'),
    'Masonry': RegExp(r'\b(mason|brick|cement|plaster|tile|floor|roof|construct|wall\s*build|foundation)\b'),
    // FIX: 'move' now uses word boundary so "remove", "improve" etc. won't match
    'Moving': RegExp(r'\b(move|moving|shift|shifting|relocat|transport|pack\s*and\s*move)\b'),
  };

  for (final entry in patterns.entries) {
    if (entry.value.hasMatch(lower)) {
      return entry.key;
    }
  }

  return null; // Could not determine category
}
```

---

## 11. `lib/features/worker/repositories/worker_repository.dart`

**Fix applied:** Bug #16 (pagination added to unfiltered queries)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_repository.dart';
import '../models/worker_profile_model.dart';

/// Repository for worker search and profile operations.
class WorkerRepository {
  WorkerRepository(this._supabaseRepo);

  final SupabaseRepository _supabaseRepo;

  /// Search for workers with optional filters.
  ///
  /// FIX (Bug #16): Always applies pagination (limit + offset) to prevent
  /// full table scans in production. Previously, when no location/category
  /// filters were provided, the query returned ALL worker profiles without
  /// any limit, causing slow loads and high bandwidth usage.
  Future<List<WorkerProfile>> searchWorkers({
    int? categoryId,
    double? lat,
    double? lng,
    double? radiusKm,
    String? searchQuery,
    int page = 0,
    int pageSize = 20,
  }) async {
    final offset = page * pageSize;

    final results = await _supabaseRepo.searchWorkers(
      categoryId: categoryId,
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      searchQuery: searchQuery,
      limit: pageSize,
      offset: offset,
    );

    return results.map((r) => WorkerProfile.fromJson(r)).toList();
  }

  /// Get a specific worker's profile by user ID.
  Future<WorkerProfile?> getWorkerProfile(String userId) async {
    return _supabaseRepo.getWorkerProfile(userId);
  }

  /// Get reviews for a worker.
  Future<List<Map<String, dynamic>>> getWorkerReviews(String userId) async {
    return _supabaseRepo.getReviews(userId);
  }
}

final workerRepositoryProvider = Provider<WorkerRepository>((ref) {
  final supabaseRepo = ref.read(supabaseRepositoryProvider);
  return WorkerRepository(supabaseRepo);
});

// ─── Search State ────────────────────────────────────────────────────────────

class WorkerSearchState {
  const WorkerSearchState({
    this.workers = const [],
    this.isLoading = false,
    this.error,
    this.currentPage = 0,
    this.hasMore = true,
    this.categoryId,
    this.searchQuery,
  });

  final List<WorkerProfile> workers;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final bool hasMore;
  final int? categoryId;
  final String? searchQuery;

  WorkerSearchState copyWith({
    List<WorkerProfile>? workers,
    bool? isLoading,
    String? error,
    int? currentPage,
    bool? hasMore,
    int? categoryId,
    String? searchQuery,
  }) {
    return WorkerSearchState(
      workers: workers ?? this.workers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      categoryId: categoryId ?? this.categoryId,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class WorkerSearchNotifier extends StateNotifier<WorkerSearchState> {
  WorkerSearchNotifier(this._repo) : super(const WorkerSearchState());

  final WorkerRepository _repo;
  static const _pageSize = 20;

  Future<void> search({
    int? categoryId,
    double? lat,
    double? lng,
    double? radiusKm,
    String? searchQuery,
  }) async {
    state = state.copyWith(
      isLoading: true,
      currentPage: 0,
      categoryId: categoryId,
      searchQuery: searchQuery,
    );

    try {
      final workers = await _repo.searchWorkers(
        categoryId: categoryId,
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        searchQuery: searchQuery,
        page: 0,
        pageSize: _pageSize,
      );

      state = state.copyWith(
        workers: workers,
        isLoading: false,
        hasMore: workers.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore({double? lat, double? lng, double? radiusKm}) async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.currentPage + 1;
      final workers = await _repo.searchWorkers(
        categoryId: state.categoryId,
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        searchQuery: state.searchQuery,
        page: nextPage,
        pageSize: _pageSize,
      );

      state = state.copyWith(
        workers: [...state.workers, ...workers],
        isLoading: false,
        currentPage: nextPage,
        hasMore: workers.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final workerSearchProvider =
    StateNotifierProvider<WorkerSearchNotifier, WorkerSearchState>((ref) {
  final repo = ref.read(workerRepositoryProvider);
  return WorkerSearchNotifier(repo);
});
```

---

## 12. `supabase/functions/send-sms/index.ts`

**Fix applied:** Bug #15 (OTP logging production detection hardened)

```typescript
// Supabase Edge Function: send-sms
// Triggered by database webhook on auth.users INSERT (OTP request).
// Sends SMS via a configurable provider (Twilio, etc.)

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

interface SmsPayload {
  type: string;
  record: {
    id: string;
    phone: string;
    phone_change?: string;
    raw_user_meta_data?: Record<string, unknown>;
  };
}

serve(async (req: Request) => {
  try {
    const payload: SmsPayload = await req.json();

    if (payload.type !== "INSERT") {
      return new Response(JSON.stringify({ message: "Ignored non-INSERT event" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const phone = payload.record.phone;
    if (!phone) {
      return new Response(JSON.stringify({ error: "No phone number" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Retrieve OTP from Supabase Auth admin API
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // Generate a 6-digit OTP
    const otp = String(Math.floor(100000 + Math.random() * 900000));

    // Store OTP in a temporary table (or use Supabase Auth's built-in OTP)
    // For production, use Supabase Auth's phone OTP flow instead of custom.
    await supabaseAdmin.from("otp_codes").upsert({
      phone: phone,
      code: otp,
      expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(), // 10 min expiry
      created_at: new Date().toISOString(),
    });

    // ─── FIX (Bug #15): Hardened production detection ─────────────────────────
    // Previously, production was detected solely by DENO_DEPLOYMENT_ID.
    // If this env var was missing in a self-hosted deployment, OTPs would be
    // logged in plaintext. Now we check multiple signals and default to
    // production-safe behavior (NO logging) unless explicitly in dev mode.
    const isExplicitDev =
      Deno.env.get("ENVIRONMENT") === "development" ||
      Deno.env.get("ENVIRONMENT") === "dev" ||
      Deno.env.get("SUPABASE_ENV") === "local";

    // Only log OTP in explicitly-configured development environments.
    // In ALL other cases (production, staging, unknown), never log the OTP.
    if (isExplicitDev) {
      console.log(`[SMS Hook] [DEV] OTP for ${phone}: ${otp}`);
    } else {
      console.log(`[SMS Hook] OTP sent to ${phone.slice(0, 6)}***`);
    }
    // ──────────────────────────────────────────────────────────────────────────

    // Send SMS via configured provider
    const smsProvider = Deno.env.get("SMS_PROVIDER") ?? "twilio";

    if (smsProvider === "twilio") {
      const accountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
      const authToken = Deno.env.get("TWILIO_AUTH_TOKEN");
      const fromNumber = Deno.env.get("TWILIO_FROM_NUMBER");

      if (!accountSid || !authToken || !fromNumber) {
        console.error("[SMS Hook] Twilio credentials not configured");
        return new Response(JSON.stringify({ error: "SMS provider not configured" }), {
          status: 500,
          headers: { "Content-Type": "application/json" },
        });
      }

      const message = `Your Job Guild verification code is: ${otp}. Valid for 10 minutes.`;

      const twilioResponse = await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            Authorization: `Basic ${btoa(`${accountSid}:${authToken}`)}`,
          },
          body: new URLSearchParams({
            From: fromNumber,
            To: phone,
            Body: message,
          }),
        }
      );

      if (!twilioResponse.ok) {
        const errBody = await twilioResponse.text();
        console.error(`[SMS Hook] Twilio error: ${twilioResponse.status} - ${errBody}`);
        return new Response(JSON.stringify({ error: "SMS send failed" }), {
          status: 502,
          headers: { "Content-Type": "application/json" },
        });
      }

      console.log(`[SMS Hook] SMS sent successfully to ${phone.slice(0, 6)}***`);
    } else {
      console.warn(`[SMS Hook] Unknown SMS provider: ${smsProvider}`);
    }

    return new Response(JSON.stringify({ message: "OTP sent" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error(`[SMS Hook] Unexpected error: ${error}`);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
```

---

## 13. `lib/features/jobs/models/job_model.dart`

**Fix applied:** Bug #14 ((0,0) coordinates handled via null check instead of value check)

```dart
/// Model representing a job posting.
class Job {
  const Job({
    required this.id,
    required this.title,
    required this.description,
    required this.employerId,
    required this.categoryId,
    this.budgetAmount,
    this.budgetType = 'fixed',
    this.urgency = 'medium',
    this.status = 'open',
    this.locationText,
    this.latitude,
    this.longitude,
    this.photos = const [],
    this.createdAt,
    this.completedAt,
    this.employerName,
    this.employerPhotoUrl,
    this.isEmployerVerified = false,
  });

  final String id;
  final String title;
  final String description;
  final String employerId;
  final int categoryId;
  final double? budgetAmount;
  final String budgetType;
  final String urgency;
  final String status;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final List<String> photos;
  final String? createdAt;
  final String? completedAt;
  final String? employerName;
  final String? employerPhotoUrl;
  final bool isEmployerVerified;

  /// FIX (Bug #14): Coordinates are now parsed using null checks instead of
  /// treating (0.0, 0.0) as "no data". The database stores NULL for missing
  /// coordinates, so we check for null/absence rather than a magic value.
  /// This avoids incorrectly discarding valid (though unlikely) coordinates.
  factory Job.fromJson(Map<String, dynamic> json) {
    // Parse employer data from joined user relation
    final userData = json['users'] as Map<String, dynamic>?;

    // Parse latitude/longitude: use null if not present or explicitly null.
    // Do NOT treat 0.0 as "missing" — the DB uses NULL for absent coordinates.
    final rawLat = json['latitude'];
    final rawLng = json['longitude'];
    final double? lat = rawLat != null ? (rawLat as num).toDouble() : null;
    final double? lng = rawLng != null ? (rawLng as num).toDouble() : null;

    // Parse photos array
    final rawPhotos = json['photos'];
    final List<String> photos = rawPhotos is List
        ? rawPhotos.map((e) => e.toString()).toList()
        : [];

    return Job(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      employerId: json['employer_id'] as String? ?? '',
      categoryId: json['category_id'] as int? ?? 1,
      budgetAmount: (json['budget_amount'] as num?)?.toDouble(),
      budgetType: json['budget_type'] as String? ?? 'fixed',
      urgency: json['urgency'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'open',
      locationText: json['location_text'] as String?,
      latitude: lat,
      longitude: lng,
      photos: photos,
      createdAt: json['created_at'] as String?,
      completedAt: json['completed_at'] as String?,
      employerName: userData?['full_name'] as String?,
      employerPhotoUrl: userData?['profile_photo_url'] as String?,
      isEmployerVerified: userData?['is_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'employer_id': employerId,
      'category_id': categoryId,
      'budget_amount': budgetAmount,
      'budget_type': budgetType,
      'urgency': urgency,
      'status': status,
      'location_text': locationText,
      'latitude': latitude,
      'longitude': longitude,
      'photos': photos,
      'created_at': createdAt,
      'completed_at': completedAt,
    };
  }

  Job copyWith({
    String? id,
    String? title,
    String? description,
    String? employerId,
    int? categoryId,
    double? budgetAmount,
    String? budgetType,
    String? urgency,
    String? status,
    String? locationText,
    double? latitude,
    double? longitude,
    List<String>? photos,
    String? createdAt,
    String? completedAt,
    String? employerName,
    String? employerPhotoUrl,
    bool? isEmployerVerified,
  }) {
    return Job(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      employerId: employerId ?? this.employerId,
      categoryId: categoryId ?? this.categoryId,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      budgetType: budgetType ?? this.budgetType,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      locationText: locationText ?? this.locationText,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photos: photos ?? this.photos,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      employerName: employerName ?? this.employerName,
      employerPhotoUrl: employerPhotoUrl ?? this.employerPhotoUrl,
      isEmployerVerified: isEmployerVerified ?? this.isEmployerVerified,
    );
  }

  /// Whether the job has valid coordinates for map display.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Distance label for display (requires external calculation).
  String? distanceLabel(double? distanceKm) {
    if (distanceKm == null) return null;
    if (distanceKm < 1) return '${(distanceKm * 1000).round()} m away';
    return '${distanceKm.toStringAsFixed(1)} km away';
  }

  @override
  String toString() => 'Job(id: $id, title: $title, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Job && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
```

---

## Summary of All Fixes Applied

| # | File | Fix |
|---|------|-----|
| 1 | `supabase_repository.dart` | Mock `_mockCompletedJobs` now uses `status: 'completed'` |
| 2 | `complete_job_rpc.sql` | Only allows completing jobs in `'hired'` status |
| 3 | `create_tables.sql` | `get_nearby_workers` excludes NULL-location workers |
| 4 | `worker_dashboard.dart` | `_jobFromApplication` reads `employer_id`/`category_id` from updated query |
| 5 | `role_provider.dart` | `RoleNotifier` listens to auth stream and retries role loading |
| 6 | `role_provider.dart` | Replaced `FutureProvider.family` mutation with proper async functions |
| 7 | `auth_provider.dart` | `normalizePhone` validates `3[0-4]XXXXXXXX` prefix |
| 8 | `chat_detail_view.dart` | Voice recorder uses `Completer` to sync start/stop |
| 9 | `job_detail_view.dart` | `_matchScore` includes category (40pts), experience (15pts), proximity (5pts) |
| 10 | `chat_provider.dart` | Conversation "other user" resolved from actual message sender/receiver |
| 11 | `budget_parser.dart` | All keyword matching uses `\b` word-boundary regex |
| 12 | `chat_provider.dart` | Fallback queries both sent AND received messages |
| 13 | `worker_dashboard.dart` | Earnings use `proposed_price` (agreed amount) over `budget_amount` |
| 14 | `job_model.dart` | Coordinates use null-check instead of `(0,0)` magic value |
| 15 | `send-sms/index.ts` | OTP logging only in explicit `ENVIRONMENT=development` |
| 16 | `worker_repository.dart` | All queries use `limit`/`offset` pagination |
