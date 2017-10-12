import Foundation
import ReactiveSwift
import enum Result.NoError

public struct FeedbackLoop<State, Event> {
    let loop: (Signal<State, NoError>) -> Signal<Event, NoError>
    
    init(_ loop: @escaping (Signal<State, NoError>) -> Signal<Event, NoError>) {
        self.loop = loop
    }
}

extension FeedbackLoop where State: SchedulerProvidable {
    public static func feedback<Control:Equatable>(query: @escaping (State) -> Control?,
                                                   effects: @escaping (Control) -> Signal<Event, NoError>) -> FeedbackLoop<State, Event> {
        return FeedbackLoop { state in
            return state.map(query)
                .skipRepeats { $0 == $1 }
                .skipNil()
                .flatMap(.latest, effects)
        }
    }
    
    public static func feedback<Control:Equatable>(query: @escaping (State) -> Control?,
                                                   effects: @escaping (Control) -> SignalProducer<Event, NoError>) -> FeedbackLoop<State, Event> {
        return FeedbackLoop { state in
            return state.map(query)
                .skipRepeats { $0 == $1 }
                .skipNil()
                .flatMap(.latest, effects)
        }
    }
    
    public static func feedback(predicate: @escaping (State) -> Bool,
                                effects: @escaping (State) -> Signal<Event, NoError>) -> FeedbackLoop<State, Event> {
        return FeedbackLoop { state in
            return state.filter(predicate)
                .flatMap(.latest, { state in
                    return effects(state)
                        .observe(on: state.scheduler)
                })
        }
    }
    
    public static func feedback(predicate: @escaping (State) -> Bool,
                                effects: @escaping (State) -> SignalProducer<Event, NoError>) -> FeedbackLoop<State, Event> {
        return FeedbackLoop { state in
            return state.filter(predicate)
                .flatMap(.latest, { state in
                    return effects(state)
                        .enqueue(on: state.scheduler)
                })
        }
    }
    
    public static func feedback(effects: @escaping (State) -> Signal<Event, NoError>) -> FeedbackLoop<State, Event> {
        return FeedbackLoop { state in
            return state.flatMap(.latest) { state in
                return effects(state)
                    .observe(on: state.scheduler)
            }
        }
    }
    
    public static func feedback(effects: @escaping (State) -> SignalProducer<Event, NoError>) -> FeedbackLoop<State, Event> {
        return FeedbackLoop { state in
            return state.flatMap(.latest) { state in
                return effects(state)
                    .enqueue(on: state.scheduler)
            }
        }
    }
}

public protocol SchedulerProvidable {
    var scheduler: Scheduler { get }
}

extension SignalProducer {
    func enqueue(on scheduler: Scheduler) -> SignalProducer<Value, Error> {
        return start(on: scheduler)
            .observe(on: scheduler)
    }
}

