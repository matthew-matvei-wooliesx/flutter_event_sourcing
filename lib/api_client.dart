import 'package:event_sourcing/route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class ApiClient {
  Future<InitialRouteSeed> getInitialRoute();
}

final apiClientProvider = Provider<ApiClient>((_) => _FakeApiClient());

class _FakeApiClient implements ApiClient {
  @override
  Future<InitialRouteSeed> getInitialRoute() => Future.delayed(
        const Duration(seconds: 2),
        () => const InitialRouteSeed(routeId: "ABCD1234", toteCount: 10),
      );
}
