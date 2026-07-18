import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../worker/providers/worker_provider.dart';

class EmployerFeed extends ConsumerWidget {
  const EmployerFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workersAsync = ref.watch(nearbyWorkersProvider);

    return workersAsync.when(
      data: (workers) {
        if (workers.isEmpty) {
          return const Center(child: Text('No nearby workers found.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: workers.length,
          itemBuilder: (context, index) {
            final worker = workers[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(worker['full_name'] ?? 'Worker', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(worker['headline'] ?? 'Professional Service', maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(worker['average_rating']?.toString() ?? 'New'),
                        const SizedBox(width: 12),
                        const Icon(Icons.location_on, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${((worker['distance_meters'] ?? 0) / 1000).toStringAsFixed(1)} km away'),
                      ],
                    ),
                  ],
                ),
                onTap: () {
                  // TODO: Worker Details
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
