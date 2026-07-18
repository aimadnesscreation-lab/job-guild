// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workerRepository)
final workerRepositoryProvider = WorkerRepositoryProvider._();

final class WorkerRepositoryProvider
    extends
        $FunctionalProvider<
          WorkerRepository,
          WorkerRepository,
          WorkerRepository
        >
    with $Provider<WorkerRepository> {
  WorkerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workerRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workerRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkerRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WorkerRepository create(Ref ref) {
    return workerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkerRepository>(value),
    );
  }
}

String _$workerRepositoryHash() => r'81db4c36c0b6ff9665f8f67d4c53bbfa1a95e0f2';

@ProviderFor(myWorkerProfile)
final myWorkerProfileProvider = MyWorkerProfileProvider._();

final class MyWorkerProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkerProfile?>,
          WorkerProfile?,
          FutureOr<WorkerProfile?>
        >
    with $FutureModifier<WorkerProfile?>, $FutureProvider<WorkerProfile?> {
  MyWorkerProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myWorkerProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myWorkerProfileHash();

  @$internal
  @override
  $FutureProviderElement<WorkerProfile?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WorkerProfile?> create(Ref ref) {
    return myWorkerProfile(ref);
  }
}

String _$myWorkerProfileHash() => r'5e56acb7fe81c9755d7165b77ff9801f378ea5a1';

@ProviderFor(nearbyWorkers)
final nearbyWorkersProvider = NearbyWorkersProvider._();

final class NearbyWorkersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Map<String, dynamic>>>,
          List<Map<String, dynamic>>,
          FutureOr<List<Map<String, dynamic>>>
        >
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $FutureProvider<List<Map<String, dynamic>>> {
  NearbyWorkersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nearbyWorkersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nearbyWorkersHash();

  @$internal
  @override
  $FutureProviderElement<List<Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Map<String, dynamic>>> create(Ref ref) {
    return nearbyWorkers(ref);
  }
}

String _$nearbyWorkersHash() => r'78c269bf92da396c2d5420662bdb5164c0d419f4';
