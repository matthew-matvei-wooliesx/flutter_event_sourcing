import 'dart:collection';

import 'package:event_sourcing/route.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final routeRepositoryProvider = Provider<RouteRepository>(
  (ref) => ref.read(_watchableRepositoryProvider),
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

// This only exists to assist with the widget here that visualises the data in
// the repo for this sample's purposes.
class _WatchableRepository extends widgets.ChangeNotifier
    implements RouteRepository {
  final RouteRepository _repository;
  _RouteDocument? latestRouteDocument;

  _WatchableRepository({
    required RouteRepository repository,
  }) : _repository = repository;

  @override
  Future<Route?> findRouteById(RouteId id) => _repository.findRouteById(id);

  @override
  Future<void> save(Route route) async {
    await _repository.save(route);

    latestRouteDocument = _RouteDocument.fromMemento(route.toMemento());
    notifyListeners();
  }
}

final _watchableRepositoryProvider =
    ChangeNotifierProvider<_WatchableRepository>(
  (_) => _WatchableRepository(
    repository: InMemoryDocumentOrientedRouteRepository(),
  ),
);

// This widget only exists to help visualise (albeit not in a very pretty way)
// the nature of the data as it sits in the DB. Since this repository
// implementation is document-oriented in nature, it displays the data as a
// JSON object.
class RepositoryVisualiser extends ConsumerWidget {
  const RepositoryVisualiser({widgets.Key? key}) : super(key: key);

  @override
  widgets.Widget build(widgets.BuildContext context, WidgetRef ref) {
    final watchedRepo = ref.watch(_watchableRepositoryProvider);

    return watchedRepo.latestRouteDocument == null
        ? const widgets.Text("No data saved yet")
        : widgets.Text(_renderRoute(watchedRepo.latestRouteDocument!));
  }

  String _renderRoute(_RouteDocument route) => """
    {
      "id": "${route.id}",
      "status": "${route.status}",
      "toteCount": ${route.toteCount},
      "driverIsAbleToWork": ${route.driverIsAbleToWork}
    }
    """;
}
