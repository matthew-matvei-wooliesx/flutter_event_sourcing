import 'dart:collection';

import 'package:event_sourcing/route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final routeRepositoryProvider = Provider<RouteRepository>(
  (_) => InMemoryDocumentOrientedRouteRepository(),
);

/// This in-memory implementation approximates what a document-oriented,
/// non-Event Sourcing solution may look like. While a simple map is used, this
/// models the key-value store model that we'd utilise from Firestore.
class InMemoryDocumentOrientedRouteRepository implements RouteRepository {
  final Map<RouteId, _RouteDocument> _routeDocumentStore = HashMap();

  @override
  Future<Route?> findRouteById(RouteId id) async {
    final foundRouteDocument = _routeDocumentStore[id];

    return foundRouteDocument != null
        ? Route.fromMemento(foundRouteDocument.toMemento())
        : null;
  }

  @override
  Future<void> save(Route route) async {
    _routeDocumentStore.update(
      route.id,
      (_) => _RouteDocument.fromMemento(route.toMemento()),
      ifAbsent: () => _RouteDocument.fromMemento(route.toMemento()),
    );
  }
}

/// This document model would be a Firestore schema in the real world, but it's
/// enough to get this sample going with an in-memory implementation.
class _RouteDocument {
  final String id;
  final String status;
  final int toteCount;
  final bool? driverIsAbleToWork;

  const _RouteDocument({
    required this.id,
    required this.status,
    required this.toteCount,
    required this.driverIsAbleToWork,
  });

  _RouteDocument.fromMemento(RouteMemento memento)
      : this(
          id: memento.routeId.toString(),
          status: memento.routeStatus.toString(),
          toteCount: memento.toteCount,
          driverIsAbleToWork: memento.driverIsAbleToWork,
        );

  RouteMemento toMemento() => RouteMemento(
        routeId: RouteId(id),
        routeStatus: _parseRouteStatus(status),
        toteCount: toteCount,
        driverIsAbleToWork: driverIsAbleToWork,
      );

  static RouteStatus _parseRouteStatus(String routeStatus) {
    switch (routeStatus) {
      case "RouteStatus.driverAllocated":
        return RouteStatus.driverAllocated;
      case "RouteStatus.checkedIn":
        return RouteStatus.checkedIn;
      case "RouteStatus.inProgress":
        return RouteStatus.inProgress;
      default:
        throw ArgumentError.value(
          routeStatus,
          "routeStatus",
          "Could not parse RouteStatus from argument",
        );
    }
  }
}
