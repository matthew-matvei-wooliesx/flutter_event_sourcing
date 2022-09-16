import 'package:event_sourcing/in_memory_route_repository.dart';
import 'package:event_sourcing/route.dart';
import 'package:event_sourcing/route_not_found_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final checkInUseCaseProvider = Provider<CheckInUseCase>(
  (ref) => CheckInUseCase(
    repository: ref.read(routeRepositoryProvider),
  ),
);

class CheckInUseCase {
  final RouteRepository _repository;

  const CheckInUseCase({
    required RouteRepository repository,
  }) : _repository = repository;

  Future<_CheckInResult> checkIn({required RouteId routeId}) async {
    final route = await _repository.findRouteById(routeId);

    if (route == null) {
      throw RouteNotFoundException();
    }

    route.checkIn();

    await _repository.save(route);

    return _CheckInResult(checkedInRoute: route);
  }
}

class _CheckInResult {
  final Route checkedInRoute;

  const _CheckInResult({required this.checkedInRoute});
}
