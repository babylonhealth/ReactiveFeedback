//
//  SignalProducer+System.swift
//  ReactiveFeedback
//
//  Created by sergdort on 28/08/2017.
//  Copyright © 2017 sergdort. All rights reserved.
//

import Foundation
import ReactiveSwift
import enum Result.NoError

public typealias FeedBack<State, Event> = (Signal<State, NoError>) -> Signal<Event, NoError>

extension SignalProducerProtocol where Error == NoError {
    
    public static func system<Event>(initialState: Value,
                              reduce: @escaping (Value, Event) -> Value,
                              feedback: [FeedBack<Value, Event>]) -> SignalProducer<Value, NoError> {
        
        let (subject, observer) = Signal<Value, NoError>.pipe()

        let events = Signal<Event, NoError>.merge(feedback.map { feedback in
            return feedback(subject)
        })
        
        let stateSignal = events.scan(initialState, reduce)
        
        return SignalProducer(stateSignal)
            .prefix(value: initialState)
            .on(value: observer.send(value:))
    }
    
    public static func system<Event>(initialState: Value,
                              reduce: @escaping (Value, Event) -> Value,
                              feedback: FeedBack<Value, Event>...) -> SignalProducer<Value, Error> {
        return system(initialState: initialState, reduce: reduce, feedback: feedback)
    }
    
    public static func system<Event>(initialState: Value,
                              reduce: @escaping (Value, Event) -> Value,
                              feedback: FeedBack<Value, Event>) -> SignalProducer<Value, Error> {
        return system(initialState: initialState, reduce: reduce, feedback: feedback)
    }
}
