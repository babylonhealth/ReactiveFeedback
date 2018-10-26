import ReactiveSwift
import Result

public protocol FeedbackInputSignal {
    associatedtype State
    associatedtype Event
    func input(state: Property<State>, scheduler: Scheduler) -> Signal<Event, NoError>
}

extension Feedback {

    public struct Input<ExternalEvent>: FeedbackInputSignal {
        let inputEvents: Signal<ExternalEvent, NoError>
        let inputReducer: (State, ExternalEvent) -> Event?

        public func input(state: Property<State>, scheduler: Scheduler) -> Signal<Event, NoError> {
            return inputEvents.observe(on: scheduler).map {
                self.inputReducer(state.value, $0)
            }.skipNil()
        }

        public init(inputEvents: Signal<ExternalEvent, NoError>,
                    inputReducer: @escaping (State, ExternalEvent) -> Event?) {
            self.inputEvents = inputEvents
            self.inputReducer = inputReducer
        }
    }

    public struct InputCollection: FeedbackInputSignal {
        private var inputFunctions: [(Property<State>, Scheduler) -> Signal<Event, NoError>]

        public func input(state: Property<State>, scheduler: Scheduler) -> Signal<Event, NoError> {
            return .merge(inputFunctions.map { $0(state, scheduler) })
        }

        public static func empty() -> InputCollection { return self.init(inputFunctions: []) }

        public func add<InputSignal>(_ input: InputSignal) -> InputCollection
            where InputSignal: FeedbackInputSignal,
            InputSignal.State == State,
            InputSignal.Event == Event {
                var inputFunctions = self.inputFunctions
                inputFunctions.append(input.input)

                return InputCollection(inputFunctions: inputFunctions)
        }

        public mutating func add<InputSignal>(_ input: InputSignal) -> Void
            where InputSignal: FeedbackInputSignal,
            InputSignal.State == State,
            InputSignal.Event == Event {
                inputFunctions.append(input.input)
        }
    }
}
