import ReactiveSwift
import Result

public protocol FeedbackInputSignal {
    associatedtype State
    associatedtype Event
    func input(state: Property<State>) -> Signal<Event, NoError>
}

extension Feedback {

    public struct Input<ExternalEvent>: FeedbackInputSignal {
        let inputEvents: Signal<ExternalEvent, NoError>
        let inputReducer: (State, ExternalEvent) -> Event?
        let scheduler: Scheduler

        public func input(state: Property<State>) -> Signal<Event, NoError> {
            return inputEvents.observe(on: scheduler).map {
                self.inputReducer(state.value, $0)
            }.skipNil()
        }

        public init(inputEvents: Signal<ExternalEvent, NoError>,
                    inputReducer: @escaping (State, ExternalEvent) -> Event?,
                    scheduler: Scheduler) {
            self.inputEvents = inputEvents
            self.inputReducer = inputReducer
            self.scheduler = scheduler
        }
    }

    public struct InputCollection: FeedbackInputSignal {
        private var inputFunctions: [(Property<State>) -> Signal<Event, NoError>]

        public func input(state: Property<State>) -> Signal<Event, NoError> {
            return .merge(inputFunctions.map { $0(state) })
        }

        public mutating func add<InputSignal>(input: InputSignal) -> Void
            where InputSignal: FeedbackInputSignal,
            InputSignal.State == State,
            InputSignal.Event == Event {
                inputFunctions.append(input.input)
        }
    }
}
