import 'package:event_sourcing/checkInUseCase.dart';
import 'package:event_sourcing/completeLoadingUseCase.dart';
import 'package:event_sourcing/in_memory_route_repository.dart';
import 'package:event_sourcing/route.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Event Sourcing Demo'),
    );
  }
}

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  domain.Route? _route;
  bool _driverIsReadyForWork = false;
  int? _revisedToteCount;

  @override
  void initState() {
    super.initState();

    _hydrateRoute().then((route) => {
          setState(() {
            _route = route;
          })
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _route == null
                  ? const Text("Loading Route")
                  : Text("Route ${_route!.id} is currently ${_route!.status}"),
            ),
            if (_route?.status == domain.RouteStatus.driverAllocated)
              ElevatedButton(
                onPressed: _checkInRoute,
                child: const Text("Check in"),
              ),
            if (_route?.status == domain.RouteStatus.checkedIn) ...[
              Padding(
                padding: const EdgeInsets.all(50),
                child: CheckboxListTile(
                  value: _driverIsReadyForWork,
                  onChanged: _toggleDriverIsReadyForWork,
                  title: const Text("Is driver ready for work?"),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(50),
                child: TextField(
                  decoration: const InputDecoration(
                    label: Text("Number of actual totes"),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: _setActualNumberOfTotes,
                ),
              ),
              if (_revisedToteCount != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50, bottom: 50),
                    child: ElevatedButton(
                      onPressed: _completeLoadingRoute,
                      child: const Text("Complete loading"),
                    ),
                  ),
                ),
            ],
            if (_route?.status == domain.RouteStatus.inProgress)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: Text("Have a nice day!"),
                ),
              )
          ],
        ),
      ),
    );
  }

  Future<domain.Route> _hydrateRoute() async {
    final route = await ref
        .read(routeRepositoryProvider)
        .findRouteById(const domain.RouteId("ABCD1234"));

    return route!;
  }

  void _checkInRoute() async {
    final checkInResult =
        await ref.read(checkInUseCaseProvider).checkIn(routeId: _route!.id);

    setState(() {
      _route = checkInResult.checkedInRoute;
    });
  }

  void _completeLoadingRoute() async {
    ref
        .read(completeLoadingUseCaseProvider)
        .completeLoading(
          routeId: _route!.id,
          driverIsAbleToWork: _driverIsReadyForWork,
          revisedToteCount: _revisedToteCount!,
        )
        .then((result) => {
              setState(() {
                _route = result.loadingCompletedRoute;
              })
            })
        .onError(
            (error, _) => {
                  Fluttertoast.showToast(
                      msg: (error as domain.RouteException).message,
                      toastLength: Toast.LENGTH_LONG,
                      timeInSecForIosWeb: 4)
                },
            test: (error) => error is domain.RouteException);
  }

  void _toggleDriverIsReadyForWork(bool? value) {
    setState(() {
      _driverIsReadyForWork = value!;
    });
  }

  void _setActualNumberOfTotes(String numberOfTotes) {
    final result = int.tryParse(numberOfTotes, radix: 10);

    if (result == null) {
      return;
    }

    setState(() {
      _revisedToteCount = result;
    });
  }
}
