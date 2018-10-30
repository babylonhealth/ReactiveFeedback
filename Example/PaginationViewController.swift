//
//  PaginationViewController.swift
//  ReactiveFeedback
//
//  Created by sergdort on 29/08/2017.
//  Copyright © 2017 sergdort. All rights reserved.
//

import UIKit
import ReactiveSwift
import ReactiveCocoa
import Kingfisher
import ReactiveFeedback
import enum Result.NoError

final class PaginationViewController: UICollectionViewController {
    let dataSource = ArrayCollectionViewDataSource<Movie>()
    let viewModel = PaginationViewModel()
    private let (retrySignal, retryObserver) = Signal<Void, NoError>.pipe()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDataSource()
        bindViewModel()
    }

    func bindViewModel() {
        viewModel.nearBottomBinding <~ collectionView!.rac_nearBottomSignal
        viewModel.retryBinding <~ retrySignal
        viewModel.movies.producer.bind(with: collectionView!.rac_items(dataSource: dataSource))
        viewModel.errors.producer
            .skipNil()
            .startWithValues { [weak self] in
                self?.showAlert(for: $0)
            }
    }

    func setupDataSource() {
        dataSource.cellFactory = { cv, ip, item in
            let cell = cv.dequeueReusableCell(withReuseIdentifier: "MoviewCell", for: ip) as! MoviewCell
            cell.configure(with: item)
            return cell
        }
    }

    func showAlert(for error: MovieError) {
        let alert = UIAlertController(title: "Error",
                                      message: error.message,
                                      preferredStyle: .alert)
        let action = UIAlertAction(title: "Retry", style: .cancel, handler: { _ in
            self.retryObserver.send(value: ())
        })
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
}

final class PaginationViewModel {
    private let token = Lifetime.Token()
    private var lifetime: Lifetime {
        return Lifetime(token)
    }
    private let nearBottomObserver: Signal<Void, NoError>.Observer
    private let retryObserver: Signal<Void, NoError>.Observer

    private let stateProperty: Property<State>
    let movies: Property<[Movie]>
    let errors: Property<MovieError?>
    let refreshing: Property<Bool>

    var nearBottomBinding: BindingTarget<Void> {
        return BindingTarget(lifetime: lifetime) { value in
            self.nearBottomObserver.send(value: value)
        }
    }

    var retryBinding: BindingTarget<Void> {
        return BindingTarget(lifetime: lifetime) { value in
            self.retryObserver.send(value: value)
        }
    }

    init() {
        let (nearBottomSignal, nearBottomObserver) = Signal<Void, NoError>.pipe()
        let (retrySignal, retryObserver) = Signal<Void, NoError>.pipe()
        let feedbacks = [
            Feedbacks.pagingFeedback(),
            Feedbacks.retryPagingFeedback()
        ]

        let inputs = Feedback.InputCollection.empty()
            .add(Inputs.nearBottomInput(for: nearBottomSignal))
            .add(Inputs.retryInput(for: retrySignal))

        let system: SignalProducer<State, NoError> = .system(input: inputs,
                                                             initial: State.initial,
                                                             scheduler: UIScheduler(),
                                                             reduce: State.reduce,
                                                             feedbacks: feedbacks)

        self.stateProperty = Property(initial: State.initial, then: system)

        self.movies = Property<[Movie]>(initial: [],
                                        then: stateProperty.producer.filterMap { $0.newMovies })

        self.errors = stateProperty.map { $0.lastError }
        self.refreshing = stateProperty.map { $0.isRefreshing }
        self.nearBottomObserver = nearBottomObserver
        self.retryObserver = retryObserver
    }

    enum Inputs {
        static func nearBottomInput(for nearBottomSignal: Signal<Void, NoError>) -> Feedback<State, Event>.Input<Void> {
            return Feedback.Input(inputEvents: nearBottomSignal) { (state: State, inputEvent: Void) -> Event? in
                return state.paging ? nil : .startLoadingNextPage
            }
        }

        static func retryInput(for retrySignal: Signal<Void, NoError>) -> Feedback<State, Event>.Input<Void> {
            return Feedback.Input(inputEvents: retrySignal) { (state: State, inputEvent: Void) -> Event? in
                return .retry
            }
        }
    }

    enum Feedbacks {
        static func pagingFeedback() -> Feedback<State, Event> {
            return Feedback<State, Event>(skippingRepeated: { $0.nextPage }) { (nextPage) -> SignalProducer<Event, NoError> in
                URLSession.shared.fetchMovies(page: nextPage)
                    .map(Event.response)
                    .flatMapError { error in
                        SignalProducer(value: Event.failed(error))
                    }.observe(on: UIScheduler())
            }
        }

        static func retryPagingFeedback() -> Feedback<State, Event> {
            return Feedback<State, Event>(skippingRepeated: { $0.retryPage }) { (nextPage) -> SignalProducer<Event, NoError> in
                URLSession.shared.fetchMovies(page: nextPage)
                    .map(Event.response)
                    .flatMapError { error in
                        SignalProducer(value: Event.failed(error))
                    }.observe(on: UIScheduler())
            }
        }
    }

    struct Context {
        var batch: Results
        var movies: [Movie]

        static var empty: Context {
            return Context(batch: Results.empty(), movies: [])
        }
    }

    enum State {
        case initial
        case paging(context: Context)
        case loadedPage(context: Context)
        case refreshing(context: Context)
        case refreshed(context: Context)
        case error(error: MovieError, context: Context)
        case retry(context: Context)

        var newMovies: [Movie]? {
            switch self {
            case .paging(context:let context):
                return context.movies
            case .loadedPage(context:let context):
                return context.movies
            case .refreshed(context:let context):
                return context.movies
            default:
                return nil
            }
        }

        var context: Context {
            switch self {
            case .initial:
                return Context.empty
            case .paging(context:let context):
                return context
            case .loadedPage(context:let context):
                return context
            case .refreshing(context:let context):
                return context
            case .refreshed(context:let context):
                return context
            case .error(error:_, context:let context):
                return context
            case .retry(context:let context):
                return context
            }
        }

        var movies: [Movie] {
            return context.movies
        }

        var batch: Results {
            return context.batch
        }

        var refreshPage: Int? {
            switch self {
            case .refreshing:
                return nil
            default:
                return 1
            }
        }

        var nextPage: Int? {
            switch self {
            case .paging(context:let context):
                return context.batch.page + 1
            case .refreshed(context:let context):
                return context.batch.page + 1
            default:
                return nil
            }
        }

        var retryPage: Int? {
            switch self {
            case .retry(context:let context):
                return context.batch.page + 1
            default:
                return nil
            }
        }

        var lastError: MovieError? {
            switch self {
            case .error(error:let error, context:_):
                return error
            default:
                return nil
            }
        }

        var isRefreshing: Bool {
            switch self {
            case .refreshing:
                return true
            default:
                return false
            }
        }

        var paging: Bool {
            switch self {
            case .paging:
                return true
            default:
                return false
            }
        }

        static func reduce(state: State, event: Event) -> State {
            switch event {
            case .startLoadingNextPage:
                return .paging(context: state.context)
            case .response(let batch):
                var copy = state.context
                copy.batch = batch
                copy.movies += batch.results
                return .loadedPage(context: copy)
            case .failed(let error):
                return .error(error: error, context: state.context)
            case .retry:
                return .retry(context: state.context)
            }
        }
    }

    enum Event {
        case startLoadingNextPage
        case response(Results)
        case failed(MovieError)
        case retry
    }
}

// MARK: - ⚠️ Danger ⚠️ Boilerplate

final class MoviewCell: UICollectionViewCell {
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var imageView: UIImageView!

    override func prepareForReuse() {
        super.prepareForReuse()
        self.title.text = nil
        self.imageView.image = nil
    }

    func configure(with moview: Movie) {
        title.text = moview.title
        imageView.kf.setImage(with: moview.posterURL,
                              options: [KingfisherOptionsInfoItem.transition(ImageTransition.fade(0.2))])
    }
}

extension UIScrollView {
    var rac_contentOffset: Signal<CGPoint, NoError> {
        return self.reactive.signal(forKeyPath: "contentOffset")
            .filterMap { change in
                guard let value = change as? NSValue else {
                    return nil
                }
                return value.cgPointValue
            }
    }

    var rac_nearBottomSignal: Signal<Void, NoError> {
        func isNearBottomEdge(scrollView: UIScrollView, edgeOffset: CGFloat = 44.0) -> Bool {
            return scrollView.contentOffset.y + scrollView.frame.size.height + edgeOffset > scrollView.contentSize.height
        }

        return rac_contentOffset
            .filterMap { _ in
            if isNearBottomEdge(scrollView: self) {
                return ()
            }
            return nil
        }
    }
}


// Key for https://www.themoviedb.org API
let apiKey = ""
let correctKey = "d4f0bdb3e246e2cb3555211e765c89e3"

struct Results: Codable {
    let page: Int
    let totalResults: Int
    let totalPages: Int
    let results: [Movie]

    static func empty() -> Results {
        return Results.init(page: 0, totalResults: 0, totalPages: 0, results: [])
    }

    enum CodingKeys: String, CodingKey {
        case page
        case totalResults = "total_results"
        case totalPages = "total_pages"
        case results
    }
}

struct Movie: Codable {
    let id: Int
    let overview: String
    let title: String
    let posterPath: String?

    var posterURL: URL? {
        return posterPath
            .map {
                "https://image.tmdb.org/t/p/w342/\($0)"
            }
            .flatMap(URL.init(string:))
    }

    enum CodingKeys: String, CodingKey {
        case id
        case overview
        case title
        case posterPath = "poster_path"
    }
}

var shouldFail = false
var failCounts = 0
var successCounts = 0

func switchFail() {
    if shouldFail {
        failCounts = failCounts + 1
    } else {
        successCounts = successCounts + 1
    }
    shouldFail = !shouldFail
}

struct MovieError: Error {
    let message: String
    let underlying: NSError?
}

extension URLSession {
    func fetchMovies(page: Int) -> SignalProducer<Results, MovieError> {
        return SignalProducer.init({ (observer, lifetime) in
            let failThisTime = shouldFail
            switchFail()
            let url = URL(string: "https://api.themoviedb.org/3/discover/movie?api_key=\(failThisTime ? apiKey : correctKey)&sort_by=popularity.desc&page=\(page)")!
            let task = self.dataTask(with: url, completionHandler: { (data, response, error) in
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                    let error = NSError(domain: "come.reactivefeedback",
                                        code: 401,
                                        userInfo: [NSLocalizedDescriptionKey: "Forced failure to illustrate Retry"])
                    observer.send(error: MovieError(message: "Forced failure to illustrate Retry", underlying: error))
                    observer.sendCompleted()
                } else if let data = data {
                    do {
                        let results = try JSONDecoder().decode(Results.self, from: data)
                        observer.send(value: results)
                    } catch {
                        observer.send(error: MovieError(message: "Parsing Failed", underlying: error as NSError))
                    }
                    observer.sendCompleted()
                } else if let error = error {
                    observer.send(error: MovieError(message: "Download Failed", underlying: error as NSError))
                    observer.sendCompleted()
                } else {
                    observer.sendCompleted()
                }
            })

            lifetime += AnyDisposable(task.cancel)
            task.resume()
        })
    }
}

extension UICollectionView {
    func rac_items<DataSource:RACCollectionViewDataSourceType & UICollectionViewDataSource, S:SignalProtocol>(dataSource: DataSource) -> (S) -> Disposable? where S.Error == NoError, S.Value == DataSource.Element {
        return { source in
            self.dataSource = dataSource
            return source.signal.observe({ [weak self] (event) in
                guard let tableView = self else {
                    return
                }
                dataSource.collectionView(tableView, observedEvent: event)
            })
        }
    }

    func rac_items<DataSource:RACCollectionViewDataSourceType & UICollectionViewDataSource, S:SignalProducerProtocol>(dataSource: DataSource) -> (S) -> Disposable? where S.Error == NoError, S.Value == DataSource.Element {
        return { source in
            self.dataSource = dataSource
            return source.producer.start { [weak self] event in
                guard let tableView = self else {
                    return
                }
                dataSource.collectionView(tableView, observedEvent: event)
            }
        }
    }
}

public protocol RACCollectionViewDataSourceType {
    associatedtype Element

    func collectionView(_ collectionView: UICollectionView, observedEvent: Signal<Element, NoError>.Event)
}

final class ArrayCollectionViewDataSource<T>: NSObject, UICollectionViewDataSource {
    typealias CellFactory = (UICollectionView, IndexPath, T) -> UICollectionViewCell

    private var items: [T] = []
    var cellFactory: CellFactory!

    func update(with items: [T]) {
        self.items = items
    }

    func item(atIndexPath indexPath: IndexPath) -> T {
        return items[indexPath.row]
    }

    // MARK: UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return cellFactory(collectionView, indexPath, item(atIndexPath: indexPath))
    }
}

extension ArrayCollectionViewDataSource: RACCollectionViewDataSourceType {
    func collectionView(_ collectionView: UICollectionView, observedEvent: Signal<[T], NoError>.Event) {
        switch observedEvent {
        case .value(let value):
            update(with: value)
            collectionView.reloadData()
        case .failed(let error):
            assertionFailure("Bind error \(error)")
        default:
            break
        }
    }
}

extension SignalProducerProtocol {
    @discardableResult
    func bind<R>(with: (SignalProducer<Value, Error>) -> R) -> R {
        return with(self.producer)
    }
}

extension SignalProtocol {
    @discardableResult
    func bind<R>(with: (Signal<Value, Error>) -> R) -> R {
        return with(self.signal)
    }
}
