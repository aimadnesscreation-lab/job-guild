import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../jobs/providers/job_provider.dart';
import '../../jobs/models/job_model.dart';

class WorkerFeed extends ConsumerWidget {
  const WorkerFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(nearbyJobsProvider);

    return jobsAsync.when(
      data: (jobs) {
        if (jobs.isEmpty) {
          return const Center(child: Text('No nearby jobs found.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                title: Text(job.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(job.locationText ?? 'Nearby', style: const TextStyle(fontSize: 12)),
                        const Spacer(),
                        Text('PKR ${job.budgetAmount ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ],
                ),
                onTap: () {
                  // TODO: Job Details
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}
