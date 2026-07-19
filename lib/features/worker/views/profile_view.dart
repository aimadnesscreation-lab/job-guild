import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import '../providers/worker_provider.dart';
import 'edit_worker_profile_view.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final workerProfileAsync = ref.watch(myWorkerProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              child: Icon(Icons.person, size: 50),
            ),
            const SizedBox(height: 16),
            Text(
              user?.phone ?? 'No Phone',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            workerProfileAsync.when(
              data: (profile) {
                if (profile == null) {
                  return Column(
                    children: [
                      const Text('You haven\'t set up a worker profile yet.'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const EditWorkerProfileView()),
                        ),
                        child: const Text('Create Worker Profile'),
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: const Text('Headline', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(profile.headline ?? 'Not set'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const EditWorkerProfileView()),
                        ),
                      ),
                    ),
                    ListTile(
                      title: const Text('Bio', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(profile.bio ?? 'Not set'),
                    ),
                    ListTile(
                      title: const Text('Experience', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${profile.yearsExperience} Years'),
                    ),
                    ListTile(
                      title: const Text('Hourly Rate', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('PKR ${profile.hourlyRatePkr ?? 'Negotiable'}'),
                    ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (err, _) => Text('Error loading profile: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
