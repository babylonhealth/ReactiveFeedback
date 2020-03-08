import Foundation
import ReactiveFeedback
import ReactiveSwift
import UIKit

enum Movies {
    struct State: Builder {
        var batch: Results = .empty()
        var movies: [Movie] = []
        var status: Status = .initial
        var backgroundColor = UIColor.black

        var nextPage: Int? {
            switch status {
            case .initial:
                return 1
            case .paging:
                return batch.page + 1
            case .refreshed:
                return batch.page + 1
            default:
                return nil
            }
        }

        var refreshPage: Int? {
            switch status {
            case .refreshing:
                return nil
            default:
                return 1
            }
        }

        var retryPage: Int? {
            switch status {
            case .retry:
                return batch.page + 1
            default:
                return nil
            }
        }

        var lastError: NSError? {
            switch status {
            case .error(let error):
                return error
            default:
                return nil
            }
        }

        var isRefreshing: Bool {
            switch status {
            case .refreshing:
                return true
            default:
                return false
            }
        }

        var paging: Bool {
            switch status {
            case .paging:
                return true
            default:
                return false
            }
        }

        var colorPicker: ColorPicker.State {
            get {
                ColorPicker.State(selectedColor: backgroundColor)
            }
            set {
                self.backgroundColor = newValue.selectedColor
            }
        }
    }

    enum Status {
        case initial
        case paging
        case loadedPage
        case refreshing
        case refreshed
        case error(NSError)
        case retry
    }

    enum Event {
        case startLoadingNextPage
        case response(Results)
        case failed(NSError)
        case retry
        case picker(ColorPicker.Event)

        var colorPicker: ColorPicker.Event? {
            get {
                guard case let .picker(value) = self else { return nil }
                return value
            }
            set {
                guard case .picker = self, let newValue = newValue else { return }
                self = .picker(newValue)
            }
        }
    }

    static var feedback: FeedbackLoop<State, Event>.Feedback {
        return .combine(
            pagingFeedback(),
            retryPagingFeedback()
        )
    }

    static var reduce: Reducer<State, Event> {
        return combine(
            reducer,
            pullback(
                ColorPicker.reduce,
                value: \.colorPicker,
                event: \.colorPicker
            )
        )
    }

    private static func reducer(state: inout State, event: Event) {
        switch event {
        case .startLoadingNextPage:
            state.status = .paging
        case .response(let batch):
            state.batch = batch
            state.movies += batch.results
            state.status = .loadedPage
        case .failed(let error):
            state.status = .error(error)
        case .retry:
            state.status = .retry
        case .picker(_):
            // The beauty of state composition is that at the parent level
            // we can also intercept events of the child and react to them
            // The rule should be tho that we should not mutate the state of the child
            // to not get conflicts
            break;
        }
    }

    private static func pagingFeedback() -> FeedbackLoop<State, Event>.Feedback {
        return FeedbackLoop<State, Event>.Feedback(skippingRepeated: { $0.nextPage }) { nextPage in
            return URLSession.shared.fetchMovies(page: nextPage)
                .observe(on: UIScheduler())
                .map(Event.response)
                .flatMapError { error in
                    SignalProducer(value: Event.failed(error))
                }
        }
    }

    private static func retryPagingFeedback() -> FeedbackLoop<State, Event>.Feedback {
        return .init(skippingRepeated: { $0.retryPage }) { nextPage in
            URLSession.shared.fetchMovies(page: nextPage)
                .observe(on: UIScheduler())
                .map(Event.response)
                .flatMapError { error in
                    SignalProducer(value: Event.failed(error))
                }
        }
    }
}
