// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(jobRepository)
final jobRepositoryProvider = JobRepositoryProvider._();

final class JobRepositoryProvider
    extends $FunctionalProvider<JobRepository, JobRepository, JobRepository>
    with $Provider<JobRepository> {
  JobRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jobRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$jobRepositoryHash();

  @$internal
  @override
  $ProviderElement<JobRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  JobRepository create(Ref ref) {
    return jobRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JobRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JobRepository>(value),
    );
  }
}

String _$jobRepositoryHash() => r'f450f3445342618eba8a62a4003fe586867359fc';

@ProviderFor(nearbyJobs)
final nearbyJobsProvider = NearbyJobsProvider._();

final class NearbyJobsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Job>>,
          List<Job>,
          FutureOr<List<Job>>
        >
    with $FutureModifier<List<Job>>, $FutureProvider<List<Job>> {
  NearbyJobsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nearbyJobsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nearbyJobsHash();

  @$internal
  @override
  $FutureProviderElement<List<Job>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Job>> create(Ref ref) {
    return nearbyJobs(ref);
  }
}

String _$nearbyJobsHash() => r'ff8280d287dd0cdebe3968941ba2bc25458176e8';
