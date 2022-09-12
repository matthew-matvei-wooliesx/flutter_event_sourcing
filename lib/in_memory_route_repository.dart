import 'dart:collection';

import 'package:event_sourcing/route.dart';

/// This in-memory implementation approximates what an Event Sourcing solution
/// may look like. While a simple map of lists is used, with each list
/// representing a route's Event Stream, this models the way that we'd utilise
/// Firestore as an Event Store well enough for this sample.
class InMemoryEventStoreRouteRepository
    with RouteEventStore
    implements RouteRepository {
  final Map<RouteId, List<_RouteEventDocument>> _routesEventStore = HashMap();

  @override
  Future<Route?> findRouteById(RouteId id) async {
    final foundRouteEventStream = _routesEventStore[id];

    return foundRouteEventStream != null
        ? Route.fromEvents(foundRouteEventStream.map((e) => e.toEvent()))
        : null;
  }

  @override
  Future<void> save(Route route) async {
    final uncommittedVersionedEvents = popUncommittedEvents(route).map(
      (e) => _RouteEventDocument(
        routeEventId: "${route.id}-Version-${e.version}",
        event: e.event,
      ),
    );

    _routesEventStore.update(
      route.id,
      (eventStream) => [...eventStream, ...uncommittedVersionedEvents],
      ifAbsent: () => uncommittedVersionedEvents.toList(),
    );
  }
}

/// This document model would be a Firestore schema in the real world, but it's
/// enough to get this sample going with an in-memory implementation. While
/// we can forget about deserialising [RouteEvent] in this sample, a real-world
/// version of this would likely want to store the name of the event type so
/// that the correct runtime type can be resolved during deserialisation.
class _RouteEventDocument {
  final String _routeEventId;
  final RouteEvent _event;

  _RouteEventDocument({
    required String routeEventId,
    required RouteEvent event,
  })  : _routeEventId = routeEventId,
        _event = event;

  RouteEvent toEvent() => _event;
}
