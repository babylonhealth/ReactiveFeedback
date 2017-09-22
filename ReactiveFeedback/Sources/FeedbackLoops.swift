//
//  FeedbackLoops.swift
//  ReactiveFeedback
//
//  Created by sergdort on 28/08/2017.
//  Copyright © 2017 sergdort. All rights reserved.
//

import Foundation
import ReactiveSwift
import enum Result.NoError

public struct React {
    public static func feedback<State,
                                Control: Equatable,
                                Event>(query: @escaping (State) -> Control?,
                                effects: @escaping (Control) -> Signal<Event, NoError>) -> FeedBack<State, Event> {
        return { state in
            return state
                .filterMap(query)
                .skipRepeats()
                .flatMap(.latest, effects)
        }
    }
    
    public static func feedback<State,
                                Control: Equatable,
                                Event>(query: @escaping (State) -> Control?,
                                effects: @escaping (Control) -> SignalProducer<Event, NoError>) -> FeedBack<State, Event> {
        return { state in
            return state
                .filterMap(query)
                .skipRepeats()
                .flatMap(.latest, effects)
        }
    }

}
