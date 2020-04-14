import Foundation
import ReactiveSwift

final class Floodgate<State, Event>: FeedbackEventConsumer<Event> {
    struct QueueState {
        var events: [(Event, Token)] = []
        var isOuterLifetimeEnded = false

        var hasEvents: Bool {
            events.isEmpty == false && isOuterLifetimeEnded == false
        }
    }

    let (stateDidChange, changeObserver) = Signal<State, Never>.pipe()

    private let reducerLock = NSLock()
    private var state: State
    private var hasStarted = false

    private let queue = Atomic(QueueState())
    private let reducer: (inout State, Event) -> Void

    init(state: State, reducer: @escaping (inout State, Event) -> Void) {
        self.state = state
        self.reducer = reducer
    }

    func bootstrap() {
        reducerLock.lock()
        defer { reducerLock.unlock() }

        guard !hasStarted else { return }

        hasStarted = true

        changeObserver.send(value: state)
        drainEvents()
    }

    override func process(_ event: Event, for token: Token) {
        enqueue(event, for: token)

        if reducerLock.try() {
            repeat {
                drainEvents()
                reducerLock.unlock()
            } while queue.withValue({ $0.hasEvents }) && reducerLock.try()
            // ^^^
            // Restart the event draining after we unlock the reducer lock, iff:
            //
            // 1. the queue still has unprocessed events; and
            // 2. no concurrent actor has taken the reducer lock, which implies no event draining would be started
            //    unless we take active action.
            //
            // This eliminates a race condition in the following sequence of operations:
            //
            // |              Thread A              |              Thread B              |
            // |------------------------------------|------------------------------------|
            // |     concurrent dequeue: no item    |                                    |
            // |                                    |         concurrent enqueue         |
            // |                                    |         trylock lock: BUSY         |
            // |            unlock lock             |                                    |
            // |                                    |                                    |
            // |             <<<  The enqueued event is left unprocessed. >>>            |
            //
            // The trylock-unlock duo has a synchronize-with relationship, which ensures that Thread A must see any
            // concurrent enqueue that *happens before* the trylock.
        }
    }

    override func dequeueAllEvents(for token: Token) {
        queue.modify { $0.events.removeAll(where: { _, t in t == token }) }
    }

    func withValue<Result>(_ action: (State, Bool) -> Result) -> Result {
        reducerLock.perform { action(state, hasStarted) }
    }

    func dispose() {
        queue.modify {
            $0.isOuterLifetimeEnded = true
        }
    }

    private func enqueue(_ event: Event, for token: Token) {
        queue.modify { $0.events.append((event, token)) }
    }

    private func dequeue() -> Event? {
        queue.modify {
            guard $0.hasEvents else { return nil }
            return $0.events.removeFirst().0
        }
    }

    private func drainEvents() {
        // Drain any recursively produced events.
        while let next = dequeue() {
            consume(next)
        }
    }

    private func consume(_ event: Event) {
        reducer(&state, event)
        changeObserver.send(value: state)
    }
}

extension SignalProducer where Error == Never {
    public func enqueue(to consumer: FeedbackEventConsumer<Value>) -> SignalProducer<Never, Never> {
        SignalProducer<Never, Never> { observer, lifetime in
            let token = Token()

            lifetime += self.startWithValues { event in
                consumer.process(event, for: token)
            }
            lifetime.observeEnded { consumer.dequeueAllEvents(for: token) }
        }
    }
}
