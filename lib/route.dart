class Route {
  final RouteId id;
  _RouteState _state;
  int _toteCount;
  bool? _driverIsAbleToWork;

  // The latest event version is used to version all the route events as they're
  // emitted. This can help keep ordering of events clear, and could potentially
  // be used for concurrency control, though due to the nature of our app,
  // concurrency is a low risk.
  int _latestEventVersion = 0;

  // Uncommitted events are buffered here until the Event Store-based route
  // repository flushes them when saving the route.
  final List<Versioned<RouteEvent>> _uncommittedEvents = [];

  // This sample's implementation assumes the backend is forming the initial
  // route snapshot, which the remote DB syncs to the local device. As part of
  // a migration to Event Sourcing though, we could construct a route from what
  // we receive from the backend via its HTTP API.
  Route._fromInitialSnapshot(_InitialSnapshot snapshot)
      : id = snapshot.routeId,
        _state = _DriverAllocatedRoute(),
        _toteCount = snapshot.toteCount;

  // This is a key premise. We need to be able to build up a route from a series
  // of ordered events. This method could operate on versioned route events if
  // we wanted it to ensure all events are received in order, this sample
  // trusts the repo to return events in order. Generally, this method is a
  // simple process of asking the route to apply each event in exactly the same
  // way it would when the event is first emitted by a route object.
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

  // As soon as the route object accepts a command, e.g. 'complete loading', it
  // emits 1 or many relevant events. The events are pushed to a queue of
  // uncommitted events and immediately applied. This keeps the events the
  // route has emitted and its current state (derived by applying the events)
  // in sync.
  void _emit(RouteEvent event) {
    _uncommittedEvents.add(
      Versioned._(version: _latestEventVersion + 1, event: event),
    );
    _apply(event);
  }

  // Events are applied when a route is being hydrated from an existing event
  // stream, or when this route object emits an event. It's the act of applying
  // an event that causes state change within this route. Applying the event
  // should trust that the event does not require any validation - all validation
  // should occur prior to raising an event in the first place. The only
  // validation that occurs here is to check that we never apply an initial
  // snapshot. This was because in this sample an initial snapshot is treated as
  // just another event, but other ways of modeling this can be found.
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

abstract class _RouteState {
  RouteStatus get _status;
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

class RouteException implements Exception {
  final String message;

  const RouteException(this.message);
}

enum RouteStatus {
  driverAllocated,
  checkedIn,
  inProgress,
}

class Versioned<RouteEvent> {
  final int version;
  final RouteEvent event;

  const Versioned._({required this.version, required this.event});
}

abstract class RouteEvent {}

class _InitialSnapshot implements RouteEvent {
  final RouteId routeId;
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

// Defining a mixin like this that the repository implementation can use helps
// keep the Event Sourcing nature of our route aggregate completely contained
// to the 'route.dart' library and the repository implementation's library. This
// means that any code that grabs a 'Route' can't attempt to add / remove / even
// query the uncommitted events the route has queued. But handling encapsulation
// this way is a suggestion, not a prescribing.
mixin RouteEventStore {
  List<Versioned<RouteEvent>> popUncommittedEvents(Route route) =>
      route._flushUncommittedEvents();

  RouteEvent seedFakeInitialSnapshot({required RouteId forRouteId}) =>
      _InitialSnapshot(
        routeId: forRouteId,
        toteCount: 10,
      );
}

// These extension methods are just to help with the data visualisation that
// we try to do in this sample, since different route event derivations are
// private to this library. In reality, these extension methods wouldn't exist
// here at all.
extension RenderingRouteEvents on RouteEvent {
  String type() {
    if (this is _InitialSnapshot) {
      return "InitialSnapshot";
    } else if (this is _RouteCheckedIn) {
      return "RouteCheckedIn";
    } else if (this is _LoadingCompleted) {
      return "LoadingCompleted";
    } else {
      throw UnsupportedError(
        "The type method was called on an unsupported route event",
      );
    }
  }

  String render() {
    if (this is _InitialSnapshot) {
      final initialSnapshot = this as _InitialSnapshot;
      return """{
          "routeId": "${initialSnapshot.routeId}",
          "toteCount": ${initialSnapshot.toteCount}
        }""";
    } else if (this is _RouteCheckedIn) {
      return "{ }";
    } else if (this is _LoadingCompleted) {
      final loadingCompleted = this as _LoadingCompleted;
      return """{
          "revisedToteCount": ${loadingCompleted.revisedToteCount},
          "driverIsAbleToWork": ${loadingCompleted.driverIsAbleToWork}
        }""";
    } else {
      throw UnsupportedError(
        "The render method was called on an unsupported route event",
      );
    }
  }
}
