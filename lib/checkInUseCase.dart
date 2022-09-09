import 'package:event_sourcing/route.dart';
import 'package:event_sourcing/route_not_found_exception.dart';

class CheckInUseCase {
  final RouteRepository _repository;

  const CheckInUseCase({
    required RouteRepository repository,
  }) : _repository = repository;

  Future<void> checkIn({required RouteId routeId}) async {
    final route = await _repository.findRouteById(routeId);

    if (route == null) {
      throw RouteNotFoundException();
    }

    route.checkIn();

    await _repository.save(route);
  }
}
