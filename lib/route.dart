class Route {
  final RouteId id;
  _RouteState _state;
  int _toteCount;
  bool? _driverIsAbleToWork;

  Route({
    required InitialRouteSeed initialRouteSeed,
  })  : id = RouteId(initialRouteSeed.routeId),
        _state = _DriverAllocatedRoute(),
        _toteCount = initialRouteSeed.toteCount;

  Route.fromMemento(RouteMemento memento)
      : id = memento.routeId,
        _state = _RouteState._fromStatus(memento.routeStatus),
        _toteCount = memento.toteCount,
        _driverIsAbleToWork = memento.driverIsAbleToWork;

  void checkIn() {
    if (_state is! _DriverAllocatedRoute) {
      throw const RouteException(
        "Only a driver-allocated route can be checked in",
      );
    }

    _state = _CheckedInRoute();
  }

  /// Throws [RouteException] if loading for this [Route] cannot be completed.
  void completeLoading({
    required bool driverIsAbleToWork,
    required int revisedToteCount,
  }) {
    if (revisedToteCount > _toteCount) {
      throw const RouteException("Cannot increase the count of totes");
    }

    _toteCount = revisedToteCount;
    _driverIsAbleToWork = driverIsAbleToWork;

    _state = _InProgressRoute();
  }

  RouteMemento toMemento() => RouteMemento(
        routeId: id,
        routeStatus: _state._status,
        toteCount: _toteCount,
        driverIsAbleToWork: _driverIsAbleToWork,
      );
}

class RouteId {
  final String _id;

  const RouteId(String id) : _id = id;

  @override
  String toString() => _id;

  @override
  bool operator ==(Object other) => other is RouteId ? _id == other._id : false;

  @override
  int get hashCode => _id.hashCode;
}

abstract class _RouteState {
  RouteStatus get _status;

  static _RouteState _fromStatus(RouteStatus status) {
    switch (status) {
      case RouteStatus.driverAllocated:
        return _DriverAllocatedRoute();
      case RouteStatus.checkedIn:
        return _CheckedInRoute();
      case RouteStatus.inProgress:
        return _InProgressRoute();
    }
  }
}

class _DriverAllocatedRoute implements _RouteState {
  @override
  RouteStatus get _status => RouteStatus.driverAllocated;
}

class _CheckedInRoute implements _RouteState {
  @override
  RouteStatus get _status => RouteStatus.checkedIn;
}

class _InProgressRoute implements _RouteState {
  @override
  RouteStatus get _status => RouteStatus.inProgress;
}

class InitialRouteSeed {
  final String routeId;
  final int toteCount;

  const InitialRouteSeed({
    required this.routeId,
    required this.toteCount,
  });
}

class RouteException implements Exception {
  final String message;

  const RouteException(this.message);
}

/// The Memento pattern here allows us to avoid exposing properties of a
/// [Route] simply for the purposes of persistence. It
class RouteMemento {
  final RouteId routeId;
  final RouteStatus routeStatus;
  final int toteCount;
  final bool? driverIsAbleToWork;

  const RouteMemento({
    required this.routeId,
    required this.routeStatus,
    required this.toteCount,
    required this.driverIsAbleToWork,
  });
}

enum RouteStatus {
  driverAllocated,
  checkedIn,
  inProgress,
}

abstract class RouteRepository {
  Future<Route?> findRouteById(RouteId id);
  Future<void> save(Route route);
}
