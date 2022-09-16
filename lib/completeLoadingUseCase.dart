import 'package:event_sourcing/in_memory_route_repository.dart';
import 'package:event_sourcing/route.dart';
import 'package:event_sourcing/route_not_found_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final completeLoadingUseCaseProvider = Provider<CompleteLoadingUseCase>(
  (ref) => CompleteLoadingUseCase(
    repository: ref.read(routeRepositoryProvider),
  ),
);

class CompleteLoadingUseCase {
  final RouteRepository _repository;

  const CompleteLoadingUseCase({
    required RouteRepository repository,
  }) : _repository = repository;

  Future<_CompleteLoadingResult> completeLoading({
    required RouteId routeId,
    required bool driverIsAbleToWork,
    required int revisedToteCount,
  }) async {
    final route = await _repository.findRouteById(routeId);

    if (route == null) {
      throw RouteNotFoundException();
    }

    route.completeLoading(
      driverIsAbleToWork: driverIsAbleToWork,
      revisedToteCount: revisedToteCount,
    );

    await _repository.save(route);

    return _CompleteLoadingResult(loadingCompletedRoute: route);
  }
}

class _CompleteLoadingResult {
  final Route loadingCompletedRoute;

  const _CompleteLoadingResult({required this.loadingCompletedRoute});
}
