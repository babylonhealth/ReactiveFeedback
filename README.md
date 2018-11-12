# ReactiveFeedback

Unidirectional Reactive Architecture. This is a [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift) implemetation of [RxFeedback](https://github.com/kzaher/RxFeedback)

## Documentation

![](diagrams/ReactiveFeedback.jpg)

### Motivation

Requirements for iOS apps have become huge. Our code has to manage a lot of state e.g. server responses, cached data, UI state, routing etc. Some may say that Reactive Programming can help us a lot but, in the wrong hands, it can do even more harm to your code base.

The goal of this library is to provide a simple and intuitive approach to designing reactive state machines.

### Core Concepts

##### State 

`State` is the single source of truth. It represents a state of your system and is usually a plain Swift type (which doesn't contain any ReactiveSwift primitives). Your state is immutable. The only way to transition from one `State` to another is to emit an `Event`.

```swift
struct Results<T: JSONSerializable> {
    let page: Int
    let totalResults: Int
    let totalPages: Int
    let results: [T]

    static func empty() -> Results<T> {
        return Results<T>(page: 0, totalResults: 0, totalPages: 0, results: [])
    }
}

struct Context {
    var batch: Results<Movie>
    var movies: [Movie]

    static var empty: Context {
        return Context(batch: Results.empty(), movies: [])
    }
}

enum State {
    case initial
    case paging(context: Context)
    case loadedPage(context: Context)
    case refreshing(context: Context)
    case refreshed(context: Context)
    case error(error: NSError, context: Context)
    case retry(context: Context)
}
```

##### Event

Represents all possible events that can happen in your system which can cause a transition to a new `State`.

```swift
enum Event {
    case startLoadingNextPage
    case response(Results<Movie>)
    case failed(NSError)
    case retry
}
```

##### Reducer 

A Reducer is a pure function with a signature of `(State, Event) -> State`. While `Event` represents an action that results in a `State` change, it's actually not what _causes_ the change. An `Event` is just that, a representation of the intention to transition from one state to another. What actually causes the `State` to change, the embodiment of the corresponding `Event`, is a Reducer. A Reducer is the only place where a `State` can be changed.

```swift
static func reduce(state: State, event: Event) -> State {
    switch event {
    case .startLoadingNextPage:
        return .paging(context: state.context)
    case .response(let batch):
        var copy = state.context
        copy.batch = batch
        copy.movies += batch.results
        return .loadedPage(context: copy)
    case .failed(let error):
        return .error(error: error, context: state.context)
    case .retry:
        return .retry(context: state.context)
    }
}
```

##### Feedback

While `State` represents where the system is at a given time, `Event` represents a state change, and a `Reducer` is the pure function that enacts the event causing the state to change, there is not as of yet any type to decide which event should take place given a particular current state. That's the job of the `Feedback`. It's essentially a "processing engine", listening to changes in the current `State` and emitting the corresponding next events to take place. It's represented by a pure function with a signature of `Signal<State, NoError> -> Signal<Event, NoError>`. Feedbacks don't directly mutate states. Instead, they only emit events which then cause states to change in reducers.

```swift
public struct Feedback<State, Event> {
    public let events: (Scheduler, Signal<State, NoError>) -> Signal<Event, NoError>
}

func loadNextFeedback(for nearBottomSignal: Signal<Void, NoError>) -> Feedback<State, Event> {
    return Feedback(predicate: { !$0.paging }) { _ in
        return nearBottomSignal
            .map { Event.startLoadingNextPage }
        }
}

func pagingFeedback() -> Feedback<State, Event> {
    return Feedback<State, Event>(skippingRepeated: { $0.nextPage }) { (nextPage) -> SignalProducer<Event, NoError> in
        return URLSession.shared.fetchMovies(page: nextPage)
            .map(Event.response)
            .flatMapError { (error) -> SignalProducer<Event, NoError> in
                return SignalProducer(value: Event.failed(error))
            }
        }
}

func retryFeedback(for retrySignal: Signal<Void, NoError>) -> Feedback<State, Event> {
    return Feedback<State, Event>(skippingRepeated: { $0.lastError }) { _ -> Signal<Event, NoError> in
        return retrySignal.map { Event.retry }
    }
}

func retryPagingFeedback() -> Feedback<State, Event> {
    return Feedback<State, Event>(skippingRepeated: { $0.retryPage }) { (nextPage) -> SignalProducer<Event, NoError> in
        return URLSession.shared.fetchMovies(page: nextPage)
            .map(Event.response)
            .flatMapError { (error) -> SignalProducer<Event, NoError> in
                return SignalProducer(value: Event.failed(error))
            }
        }
}
```

### The Flow

1. As you can see from the diagram above we always start with an initial state.
2. Every change to the `State` will be then delivered to all `Feedback` loops that were added to the system.
3. `Feedback` then decides whether any action should be performed with a subset of the `State` (e.g calling API, observe UI events) by dispatching an `Event`, or ignoring it by returning `SignalProducer.empty`.
4. Dispatched `Event` then goes to the `Reducer` which applies it and returns a new value of the `State`.
5. And then cycle starts all over (see 2).

##### Example
```swift
let increment = Feedback<Int, Event> { _ in
    return self.plusButton.reactive
        .controlEvents(.touchUpInside)
        .map { _ in Event.increment }
}

let decrement = Feedback<Int, Event> { _ in
    return self.minusButton.reactive
        .controlEvents(.touchUpInside)
        .map { _ in Event.decrement }
}

let system = SignalProducer<Int, NoError>.system(initial: 0,
    reduce: { (count, event) -> Int in
        switch event {
        case .increment:
            return count + 1
        case .decrement:
            return count - 1
        }
    },
    feedbacks: [increment, decrement])

label.reactive.text <~ system.map(String.init)
```

![](diagrams/increment_example.gif)]

### Advantages

TODO
