import 'package:event_sourcing/route.dart';
import 'package:event_sourcing/route_not_found_exception.dart';

class CompleteLoadingUseCase {
  final RouteRepository _repository;

  const CompleteLoadingUseCase({
    required RouteRepository repository,
  }) : _repository = repository;

  Future<void> completeLoading({
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
  }
}
