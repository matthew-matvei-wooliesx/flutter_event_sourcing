# event_sourcing

A simple Flutter project to explore and demonstrate Event Sourcing

## Where to Look

This project has been bootstrapped in the usual Flutter way. Ignore `lib/main.dart`, look at the other files in that
folder instead. `route.dart` would likely be the best file to start, then the `in_memory_route_repository.dart`, then
the use cases after that. 

## How to Look

Once you have a general idea of what's going on here in this branch, you can contrast this with the `with-event-sourcing`
branch. There is a draft PR to make the comparison easier available [here](https://github.com/matthew-matvei-wooliesx/flutter_event_sourcing/pull/1).

## What we find

The changes here are as interesting as the things that don't change.

### What changes

Overall, the `Route` aggregate's library changes by:

1. Needing to know that internally it emits and applies immutable events. It emits the events to say that something has
    happened, and applies them to update state based on the events that have happened. Since applying the events is
    inately something that the route has to perform, it means we need a method for handling each unique route event
    type we have. But since the object would have needed to update its state anyway, this is certainly more _words_ (i.e.
    defining classes and private methods), but not really a lot more complexity.

1. Needing to define many route events. Since these are immutable buckets of data, there's not a great deal of added
    complexity, and keeping all derivates of `RouteEvent` private can help keep clients far less coupled to these
    events.

1. Providing a mixin for repository implementations to get at the uncommitted events of the `Route`. This is useful
    though for controlling which clients can flush the uncommitted events from the route, since only the repository
    implementation should be doing this.

The `in_memory_route_repository.dart` library changes quite significantly, as you would expect:

1. The repo seeds some data on construction as a simulation of how we may seed initial route data in the back end
    eventually.

1. The implementation stores and retrieves routes as and from an immutable series of events.

The `main.dart` library changes slightly, owing only to the idea that we're not 'retrieving' the route from the back
end, but rather expecting it to have been sync'ed there.

### What doesn't change

All the clients of a `Route` and an abstract `RouteRepository`, such as the use cases and where widgets hold a `Route`
object, don't need to change at all.

This shows that with suitable encapsulation in a rich domain model representing a Route, as well as depending on
abstract repositories instead of implementations, we can suitably:

1. Start with a document-oriented model
1. Then migrate to an Event Sourcing model when we feel ready

All our unit tests that define how our `Route` aggregate behaves and our integration tests that involve storing and
retrieving those routes can help us make the refactor confidently.
