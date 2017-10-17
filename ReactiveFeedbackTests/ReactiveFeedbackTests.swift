import XCTest
import ReactiveSwift
import Result
import Nimble
import ReactiveFeedback

class ReactiveFeedbackTests: XCTestCase {
    func testPlaceholder() {
        var a = 0
        var b = 0

        let system = Property<String>(
            initial: "initial",
            reduce: { (state: String, event: String) in
                return state + event
            },
            feedbacks: [
                FeedbackLoop { state -> SignalProducer<String, NoError> in
                    guard a < 2 else { return .empty }
                    a += 1
                    return SignalProducer(value: "_a")
                },
                FeedbackLoop { state -> SignalProducer<String, NoError> in
                    guard b < 2 else { return .empty }
                    b += 1
                    return SignalProducer(value: "_b")
                }
            ]
        )

        expect(system.value) == "initial_a_b_a_b"
    }
}
