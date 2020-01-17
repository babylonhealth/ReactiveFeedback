import XCTest
import Nimble
import ReactiveSwift
@testable import ReactiveFeedback

class SystemTests: XCTestCase {

    func test_emits_initial() {
        let initial = "initial"
        let feedback = Feedback<String, String> { state in
            return SignalProducer(value: "_a")
        }
        let system = SignalProducer<String, Never>.system(
            initial: initial,
            reduce: { (state: String, event: String) in
                return state + event
            },
            feedbacks: feedback)
        let result = ((try? system.first()?.get()) as String??)

        expect(result) == initial
    }

    func test_reducer_with_one_feedback_loop() {
        let feedback = Feedback<String, String> { state in
            return SignalProducer(value: "_a")
        }
        let system = SignalProducer<String, Never>.system(
            initial: "initial",
            reduce: { (state: String, event: String) in
                return state + event
            },
            feedbacks: feedback)

        var result: [String]!
        system.take(first: 3)
            .collect()
            .startWithValues {
                result = $0
            }

        let expected = [
            "initial",
            "initial_a",
            "initial_a_a"
        ]
        expect(result).toEventually(equal(expected))
    }

    func test_reduce_with_two_immediate_feedback_loops() {
        let feedback1 = Feedback<String, String> { state in
            return !state.hasSuffix("_a") ? SignalProducer(value: "_a") : .empty
        }
        let feedback2 = Feedback<String, String> { state in
            return !state.hasSuffix("_b") ? SignalProducer(value: "_b") : .empty
        }
        let system = SignalProducer<String, Never>.system(
            initial: "initial",
            reduce: { (state: String, event: String) in
                return state + event
            },
            feedbacks: feedback1, feedback2)

        var result: [String]!
        system.take(first: 5)
            .collect()
            .startWithValues {
                result = $0
            }

        let expected = [
            "initial",
            "initial_a",
            "initial_a_b",
            "initial_a_b_a",
            "initial_a_b_a_b",
        ]
        expect(result).toEventually(equal(expected))
    }

    func test_reduce_with_async_feedback_loop() {
        let feedback = Feedback<String, String> { state -> SignalProducer<String, Never> in
            if state == "initial" {
                return SignalProducer(value: "_a")
                    .delay(0.1, on: QueueScheduler.main)
            }
            if state == "initial_a" {
                return SignalProducer(value: "_b")
            }
            if state == "initial_a_b" {
                return SignalProducer(value: "_c")
            }
            return SignalProducer.empty
        }
        let system = SignalProducer<String, Never>.system(
            initial: "initial",
            reduce: { (state: String, event: String) in
                return state + event
            },
            feedbacks: feedback)

        var result: [String]!
        system.take(first: 4)
            .collect()
            .startWithValues {
                result = $0
            }

        let expected = [
            "initial",
            "initial_a",
            "initial_a_b",
            "initial_a_b_c"
        ]
        expect(result).toEventually(equal(expected))
    }

    func test_should_observe_signals_immediately() {
        let scheduler = TestScheduler()
        let (signal, observer) = Signal<String, Never>.pipe()

        let system = SignalProducer<String, Never>.system(
            initial: "initial",
            scheduler: scheduler,
            reduce: { (state: String, event: String) -> String in
                return state + event
            },
            feedbacks: [
                Feedback { state -> Signal<String, Never> in
                    return signal
                }
            ]
        )

        var value: String?
        system.startWithValues { value = $0 }

        expect(value) == "initial"

        observer.send(value: "_a")
        expect(value) == "initial"

        scheduler.advance()
        expect(value) == "initial_a"
    }


    func test_should_start_producers_immediately() {
        let scheduler = TestScheduler()
        var startCount = 0

        let system = SignalProducer<String, Never>.system(
            initial: "initial",
            scheduler: scheduler,
            reduce: { (state: String, event: String) -> String in
                return state + event
            },
            feedbacks: [
                Feedback { state -> SignalProducer<String, Never> in
                    return SignalProducer(value: "_a")
                        .on(starting: { startCount += 1 })
                }
            ]
        )

        var value: String?
        system
            .skipRepeats()
            .take(first: 2)
            .startWithValues { value = $0 }

        expect(value) == "initial"
        expect(startCount) == 1

        scheduler.advance()
        expect(value) == "initial_a"
        expect(startCount) == 2

        scheduler.advance()
        expect(value) == "initial_a"
        expect(startCount) == 2
    }

    func test_should_not_miss_delivery_to_reducer_when_started_asynchronously() {
        let creationScheduler = QueueScheduler()
        let systemScheduler = QueueScheduler()

        let observedState: Atomic<[String]> = Atomic([])

        let semaphore = DispatchSemaphore(value: 0)

        creationScheduler.schedule {
             SignalProducer<String, Never>
                .system(
                    initial: "initial",
                    scheduler: systemScheduler,
                    reduce: { (state: String, event: String) -> String in
                        return state + event
                    },
                    feedbacks: [
                        Feedback { scheduler, state in
                            return state
                                .take(first: 1)
                                .map(value: "_event")
                                .observe(on: scheduler)
                                .on(terminated: { semaphore.signal() })
                        }
                    ]
                )
                .startWithValues { state in
                    observedState.modify { $0.append(state) }
                }
        }

        semaphore.wait()
        expect(observedState.value).toEventually(equal(["initial", "initial_event"]))
    }

    func test_predicate_prevents_state_updates() {
        enum Event {
            case increment
        }
        let (incrementSignal, incrementObserver) = Signal<Void, Never>.pipe()
        let feedback = Feedback<Int, Event>(predicate: { $0 < 2 }) { _ in
            incrementSignal.map { _ in Event.increment }
        }
        let system = SignalProducer<Int, Never>.system(
            initial: 0,
            reduce: { (state: Int, event: Event) in
                switch event {
                case .increment:
                    return state + 1
                }
            },
            feedbacks: [feedback])

        let (lifetime, token) = Lifetime.make()

        var result: [Int]!
        system.take(during: lifetime)
            .collect()
            .startWithValues {
                result = $0
            }

        func increment(numberOfTimes: Int) {
            guard numberOfTimes > 0 else {
                DispatchQueue.main.async { token.dispose() }
                return
            }
            DispatchQueue.main.async {
                incrementObserver.send(value: ())
                increment(numberOfTimes: numberOfTimes - 1)
            }
        }
        increment(numberOfTimes: 7)

        let expected = [0, 1, 2]

        expect(result).toEventually(equal(expected))
    }

    func test_conditionBecomesTrue() {
        let (lessThanAHundred, lessThanAHundredObserver) = Signal<Int, Never>.pipe()
        let (greaterThanAHundred, greaterThanAHundredObserver) = Signal<Int, Never>.pipe()

        var reducerCount = 0
        var lessThanAHundredStartCount = 0
        var greaterThanAHundredStartCount = 0

        let scheduler = TestScheduler()
        let garbage = Int.max

        let system = SignalProducer<Int, Never>.system(
            initial: 0,
            scheduler: scheduler,
            reduce: { (state: Int, event: Int) in
                reducerCount += 1
                return state + event
            },
            feedbacks: [
                Feedback(
                    condition: { $0 < 100 },
                    whenBecomesTrue: { _ in
                        lessThanAHundred.producer
                            .on(started: { lessThanAHundredStartCount += 1 })
                    }
                ),
                Feedback(
                    condition: { $0 > 100 },
                    whenBecomesTrue: { _ in
                        greaterThanAHundred.producer
                            .on(started: { greaterThanAHundredStartCount += 1 })
                    }
                )
            ]
        )

        var history = [Int]()
        system.startWithValues { history.append($0) }

        scheduler.advance()
        expect(history) == [0]
        expect(lessThanAHundredStartCount) == 1
        expect(greaterThanAHundredStartCount) == 0
        expect(reducerCount) == 0

        lessThanAHundredObserver.send(value: 25)
        lessThanAHundredObserver.send(value: 25)
        lessThanAHundredObserver.send(value: 25)
        lessThanAHundredObserver.send(value: 26)
        greaterThanAHundredObserver.send(value: garbage) // Garbage that should be ignored by the feedback
        greaterThanAHundredObserver.send(value: garbage) // Garbage that should be ignored by the feedback
        scheduler.advance()

        expect(history) == [0, 25, 50, 75, 101]
        expect(lessThanAHundredStartCount) == 1
        expect(greaterThanAHundredStartCount) == 1
        expect(reducerCount) == 4

        greaterThanAHundredObserver.send(value: 25)
        greaterThanAHundredObserver.send(value: 25)
        greaterThanAHundredObserver.send(value: -25)
        lessThanAHundredObserver.send(value: garbage) // Garbage that should be ignored by the feedback
        lessThanAHundredObserver.send(value: garbage) // Garbage that should be ignored by the feedback
        scheduler.advance()

        expect(history) == [0, 25, 50, 75, 101, 126, 151, 126]
        expect(lessThanAHundredStartCount) == 1
        expect(greaterThanAHundredStartCount) == 1
        expect(reducerCount) == 7

        greaterThanAHundredObserver.send(value: -40)
        lessThanAHundredObserver.send(value: garbage) // Garbage that should be ignored by the feedback
        scheduler.advance()

        expect(history) == [0, 25, 50, 75, 101, 126, 151, 126, 86]
        expect(lessThanAHundredStartCount) == 2
        expect(greaterThanAHundredStartCount) == 1
        expect(reducerCount) == 8

        lessThanAHundredObserver.send(value: 42)
        greaterThanAHundredObserver.send(value: garbage) // Garbage that should be ignored by the feedback
        scheduler.advance()

        expect(history) == [0, 25, 50, 75, 101, 126, 151, 126, 86, 128]
        expect(lessThanAHundredStartCount) == 2
        expect(greaterThanAHundredStartCount) == 2
        expect(reducerCount) == 9
    }
}
