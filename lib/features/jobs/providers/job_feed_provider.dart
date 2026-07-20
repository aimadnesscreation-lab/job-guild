import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';

/// Raw stream provider that emits lists of jobs from the Supabase `jobs` table.
/// Uses `stream()` under the hood, which opens a Realtime subscription
/// so any INSERT, UPDATE, or DELETE on the jobs table is reflected instantly.
///
/// This provider is the single source of truth for the live job feed.
///
/// Guarded so that, before `Supabase.initialize()` has run (e.g. widget tests
/// with no Supabase client), it emits an empty list instead of throwing.
final liveJobFeedProvider = StreamProvider<List<Job>>((ref) {
  try {
    final client = Supabase.instance.client;

    return client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          return data.map((json) => Job.fromJson(json)).toList();
        });
  } catch (_) {
    // Supabase not initialized (e.g. widget tests) — emit an empty list.
    final controller = StreamController<List<Job>>();
    controller.add(const []);
    controller.close();
    return controller.stream;
  }
});

/// Provider that filters jobs to only 'open' status for the worker feed.
final openJobsProvider = Provider<AsyncValue<List<Job>>>((ref) {
  final allJobs = ref.watch(liveJobFeedProvider);
  return allJobs.whenData(
    (jobs) => jobs.where((j) => j.isOpen).toList(),
  );
});

/// Provider that filters jobs by employer ID for the employer dashboard.
final employerJobsProvider =
    Provider.family<AsyncValue<List<Job>>, String>((ref, employerId) {
  final allJobs = ref.watch(liveJobFeedProvider);
  return allJobs.whenData(
    (jobs) => jobs.where((j) => j.employerId == employerId).toList(),
  );
});
