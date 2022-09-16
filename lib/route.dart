class Route {
  final RouteId id;
  _RouteState _state;
  int _toteCount;
  bool? _driverIsAbleToWork;

  int _latestEventVersion = 0;
  final List<Versioned<RouteEvent>> _uncommittedEvents = [];

  Route._fromInitialSnapshot(_InitialSnapshot snapshot)
      : id = RouteId(snapshot.routeId),
        _state = _DriverAllocatedRoute(),
        _toteCount = snapshot.toteCount;

  static Route fromEvents(Iterable<RouteEvent> events) {
    if (events.isEmpty) {
      throw const RouteException("Cannot hydrate Route from no events");
    }

    final firstEvent = events.first;

    if (firstEvent is! _InitialSnapshot) {
      throw const RouteException(
        "Cannot start hydrating Route without initial snapshot",
      );
    }

    final route = Route._fromInitialSnapshot(firstEvent);

    for (final event in events.skip(1)) {
      route._apply(event);
    }

    return route;
  }

  RouteStatus get status => _state._status;
  int get toteCount => _toteCount;

  void checkIn() {
    if (_state is! _DriverAllocatedRoute) {
      throw const RouteException(
        "Only a driver-allocated route can be checked in",
      );
    }

    _emit(_RouteCheckedIn());
  }

  /// Throws [RouteException] if loading for this [Route] cannot be completed.
  void completeLoading({
    required bool driverIsAbleToWork,
    required int revisedToteCount,
  }) {
    if (revisedToteCount > _toteCount) {
      throw RouteException(
        "Cannot increase the count of totes to more than $_toteCount",
      );
    }

    _emit(_LoadingCompleted(
      revisedToteCount: revisedToteCount,
      driverIsAbleToWork: driverIsAbleToWork,
    ));
  }

  void _emit(RouteEvent event) {
    _uncommittedEvents.add(
      Versioned._(version: _latestEventVersion + 1, event: event),
    );
    _apply(event);
  }

  void _apply(RouteEvent event) {
    if (event is _InitialSnapshot) {
      throw const RouteException(
        "Cannot apply initial snapshot, it can only be used to construct a new Route",
      );
    }

    if (event is _RouteCheckedIn) {
      _applyRouteCheckedIn();
    } else if (event is _LoadingCompleted) {
      _applyLoadingCompleted(event);
    } else {
      throw RouteException(
        "Attempted to apply unrecognised event type ${event.runtimeType}",
      );
    }

    _latestEventVersion++;
  }

  void _applyRouteCheckedIn() {
    _state = _CheckedInRoute();
  }

  void _applyLoadingCompleted(_LoadingCompleted event) {
    _toteCount = event.revisedToteCount;
    _driverIsAbleToWork = event.driverIsAbleToWork;

    _state = _InProgressRoute();
  }

  List<Versioned<RouteEvent>> _flushUncommittedEvents() {
    final result = List<Versioned<RouteEvent>>.from(_uncommittedEvents);

    _uncommittedEvents.clear();

    return result;
  }
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

abstract class _RouteState {}

class _DriverAllocatedRoute implements _RouteState {}

class _CheckedInRoute implements _RouteState {}

class _InProgressRoute implements _RouteState {}

class RouteException implements Exception {
  final String message;

  const RouteException(this.message);
}

class Versioned<RouteEvent> {
  final int version;
  final RouteEvent event;

  const Versioned._({required this.version, required this.event});
}

abstract class RouteEvent {}

class _InitialSnapshot implements RouteEvent {
  final String routeId;
  final int toteCount;

  const _InitialSnapshot({
    required this.routeId,
    required this.toteCount,
  });
}

class _RouteCheckedIn implements RouteEvent {}

class _LoadingCompleted implements RouteEvent {
  final int revisedToteCount;
  final bool driverIsAbleToWork;

  const _LoadingCompleted({
    required this.revisedToteCount,
    required this.driverIsAbleToWork,
  });
}

abstract class RouteRepository {
  Future<Route?> findRouteById(RouteId id);
  Future<void> save(Route route);
}

mixin RouteEventStore {
  List<Versioned<RouteEvent>> popUncommittedEvents(Route route) =>
      route._flushUncommittedEvents();
}
