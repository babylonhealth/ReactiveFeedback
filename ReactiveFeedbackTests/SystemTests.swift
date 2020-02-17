import XCTest
import Nimble
import ReactiveSwift
@testable import ReactiveFeedback

class SystemTests: XCTestCase {

    func test_emits_initial() {
        let initial = "initial"
        let feedback = FeedbackLoop<String, String>.Feedback { state in
            return SignalProducer(value: "_a")
        }
        let system = SignalProducer<String, Never>.feedbackloop(
            initial: initial,
            reduce: { (state: String, event: String) in
                return state + event
            },
            feedbacks: feedback)
        let result = ((try? system.first()?.get()) as String??)

        expect(result) == initial
    }

    func test_reducer_with_one_feedback_loop() {
        let feedback = FeedbackLoop<String, String>.Feedback { state in
            return SignalProducer(value: "_a")
        }
        let system = SignalProducer<String, Never>.feedbackloop(
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
        let feedback1 = FeedbackLoop<String, String>.Feedback { state in
            return !state.hasSuffix("_a") ? SignalProducer(value: "_a") : .empty
        }
        let feedback2 = FeedbackLoop<String, String>.Feedback { state in
            return !state.hasSuffix("_b") ? SignalProducer(value: "_b") : .empty
        }
        let system = SignalProducer<String, Never>.feedbackloop(
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
        let feedback = FeedbackLoop<String, String>.Feedback { state -> SignalProducer<String, Never> in
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
        let system = SignalProducer<String, Never>.feedbackloop(
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
        let (signal, observer) = Signal<String, Never>.pipe()

        let system = SignalProducer<String, Never>.feedbackloop(
            initial: "initial",
            reduce: { (state: String, event: String) -> String in
                return state + event
            },
            feedbacks: [
                FeedbackLoop<String, String>.Feedback { state in
                    return signal.producer
                }
            ]
        )

        var value: String?
        system.startWithValues { value = $0 }

        expect(value) == "initial"

        observer.send(value: "_a")
        expect(value) == "initial_a"
    }

    func test_should_start_producers_immediately() {
        var startCount = 0

        let system = SignalProducer<String, Never>.feedbackloop(
            initial: "initial",
            reduce: { (state: String, event: String) -> String in
                return state + event
            },
            feedbacks: [
                FeedbackLoop<String, String>.Feedback { state -> SignalProducer<String, Never> in
                    return SignalProducer(value: "_a")
                        .on(starting: { startCount += 1 })
                }
            ]
        )

        var values: [String] = []
        system
            .skipRepeats()
            .take(first: 2)
            .startWithValues { values.append($0) }

        expect(values) == ["initial", "initial_a"]
        expect(startCount) == 2
    }

    func test_should_not_miss_delivery_to_reducer_when_started_asynchronously() {
        let creationScheduler = QueueScheduler()

        let observedState: Atomic<[String]> = Atomic([])

        let semaphore = DispatchSemaphore(value: 0)

        creationScheduler.schedule {
             SignalProducer<String, Never>
                .feedbackloop(
                    initial: "initial",
                    reduce: { (state: String, event: String) -> String in
                        return state + event
                    },
                    feedbacks: [
                        FeedbackLoop<String, String>.Feedback { state, output in
                            state
                                .take(first: 1)
                                .map(value: "_event")
                                .on(terminated: { semaphore.signal() })
                                .enqueue(to: output)
                                .start()
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
        let feedback = FeedbackLoop<Int, Event>.Feedback(predicate: { $0 < 2 }) { _ in
            incrementSignal.map { _ in Event.increment }
        }
        let system = SignalProducer<Int, Never>.feedbackloop(
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
}
