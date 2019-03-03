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
    private lazy var viewModel = PaginationViewModel(flowController: FlowController(viewController: self))
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
        viewModel.color.startWithValues { [weak self] in
            self?.collectionView?.backgroundColor = $0
        }
    }

    func setupDataSource() {
        dataSource.cellFactory = { cv, ip, item in
            let cell = cv.dequeueReusableCell(withReuseIdentifier: "MoviewCell", for: ip) as! MoviewCell
            cell.configure(with: item)
            return cell
        }
        self.collectionView?.delegate = self
    }

    func showAlert(for error: NSError) {
        let alert = UIAlertController(title: "Error",
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        let action = UIAlertAction(title: "Retry", style: .cancel, handler: { _ in
            self.retryObserver.send(value: ())
        })
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        viewModel.selectColor()
    }
}

final class FlowController {
    private weak var viewController: UIViewController?
    private let storyBoard = UIStoryboard(name: "Main", bundle: nil)
    init(viewController: UIViewController) {
        self.viewController = viewController
    }
    
    func showColorPicker() -> SignalProducer<UIColor, NoError> {
        return SignalProducer { [storyBoard, viewController] (observer, lifetime) in
            let vc = storyBoard.instantiateViewController(withIdentifier: "ColorPickerViewController") as! ColorPickerViewController
            vc.didPickColor = { color in
                observer.send(value: color)
                observer.sendCompleted()
            }
            vc.didCancel = observer.sendInterrupted
            
            viewController?.present(vc, animated: true, completion: nil)
            
            lifetime += AnyDisposable {
                vc.dismiss(animated: true, completion: nil)
            }
        }
    }
}

final class PaginationViewModel {
    private let token = Lifetime.Token()
    private var lifetime: Lifetime {
        return Lifetime(token)
    }
    private let nearBottomObserver: Signal<Void, NoError>.Observer
    private let retryObserver: Signal<Void, NoError>.Observer
    private let (selection, selectionObserver) = Signal<Void, NoError>.pipe()

    private let stateProperty: Property<State>
    let movies: Property<[Movie]>
    let errors: Property<NSError?>
    let refreshing: Property<Bool>
    let color: SignalProducer<UIColor, NoError>

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

    init(flowController: FlowController) {
        let (nearBottomSignal, nearBottomObserver) = Signal<Void, NoError>.pipe()
        let (retrySignal, retryObserver) = Signal<Void, NoError>.pipe()
        let feedbacks = [
            Feedbacks.loadNextFeedback(for: nearBottomSignal),
            Feedbacks.pagingFeedback(),
            Feedbacks.retryFeedback(for: retrySignal),
            Feedbacks.retryPagingFeedback(),
            Feedbacks.input(signal: selection),
            Feedbacks.whenSelectingColor(flowController: flowController)
        ]

        self.stateProperty = Property(initial: State.initial,
                                      reduce: State.reduce,
                                      feedbacks: feedbacks)

        self.movies = Property<[Movie]>(initial: [],
                                        then: stateProperty.producer.filterMap { $0.newMovies })

        self.errors = stateProperty.map { $0.lastError }
        self.refreshing = stateProperty.map { $0.isRefreshing }
        self.nearBottomObserver = nearBottomObserver
        self.retryObserver = retryObserver
        self.color = stateProperty.producer.filterMap { $0.context.color }
    }
    
    func selectColor() {
        selectionObserver.send(value: ())
    }

    enum Feedbacks {
        static func input(signal: Signal<Void, NoError>) -> Feedback<State, Event> {
            return Feedback(events: { (scheduler, _) -> Signal<Event, NoError> in
                return signal
                    .map { Event.selectColor }
                    .observe(on: scheduler)
            })
        }
        
        static func whenSelectingColor(flowController: FlowController) -> Feedback<State, Event> {
            return Feedback(ignoreAllUntilFinished: { $0.selectingColor }) {
                return flowController.showColorPicker()
                    .map(Event.didSelectColor)
            }
        }
        
        static func loadNextFeedback(for nearBottomSignal: Signal<Void, NoError>) -> Feedback<State, Event> {
            return Feedback(predicate: { !$0.paging }) { _ in
                nearBottomSignal
                    .map { Event.startLoadingNextPage }
            }
        }

        static func pagingFeedback() -> Feedback<State, Event> {
            return Feedback<State, Event>(skippingRepeated: { $0.nextPage }) { (nextPage) -> SignalProducer<Event, NoError> in
                URLSession.shared.fetchMovies(page: nextPage)
                    .map(Event.response)
                    .flatMapError { error in
                        SignalProducer(value: Event.failed(error))
                    }.observe(on: UIScheduler())
            }
        }

        static func retryFeedback(for retrySignal: Signal<Void, NoError>) -> Feedback<State, Event> {
            return Feedback<State, Event>(skippingRepeated: { $0.lastError }) { _ -> Signal<Event, NoError> in
                retrySignal.map { Event.retry }
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
        var color: UIColor?

        static var empty: Context {
            return Context(batch: Results.empty(), movies: [], color: nil)
        }
    }

    enum State {
        case initial
        case paging(context: Context)
        case loadedPage(context: Context)
        case refreshing(context: Context)
        case refreshed(context: Context)
        case error(error: NSError, context: Context)
        case retry(context: Context)
        case selectingColor(Context)
        case colorChanged(Context)

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
            case .selectingColor(let context):
                return context
            case .colorChanged(let context):
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

        var lastError: NSError? {
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
        
        var selectingColor: ()? {
            switch self {
            case .selectingColor:
                return ()
            default:
                return nil
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
            case .selectColor:
                return .selectingColor(state.context)
            case .didSelectColor(let color):
                var copy = state.context
                copy.color = color
                return .colorChanged(copy)
            }
        }
    }

    enum Event {
        case startLoadingNextPage
        case response(Results)
        case failed(NSError)
        case retry
        case selectColor
        case didSelectColor(UIColor)
    }
}

// MARK: - ⚠️ Danger ⚠️ Boilerplate

extension Signal {
    public func flatMapFirst<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, Error> where Inner.Error == Error {
        return Signal<Inner.Value, Error> { (observer, lifetime) in
            let isInProgress = Atomic(false)
            let isOuterCompleted = Atomic(false)
            lifetime += self.observe { (event) in
                switch event {
                case let .value(value):
                    if isInProgress.swap(true) {
                        return
                    }
                    lifetime += transform(value).producer.start { (innerEvent) in
                        switch innerEvent {
                        case let .value(value):
                            observer.send(value: value)
                        case let .failed(error):
                            observer.send(error: error)
                        case .completed:
                            isInProgress.swap(false)
                            if isOuterCompleted.value {
                                observer.sendCompleted()
                            }
                        case .interrupted:
                            isInProgress.swap(false)
                            if isOuterCompleted.value {
                                observer.sendInterrupted()
                            }
                        }
                    }
                case let .failed(error):
                    observer.send(error: error)
                case .completed:
                    isOuterCompleted.swap(true)
                    if isInProgress.value == false {
                        observer.sendCompleted()
                    }
                case .interrupted:
                    observer.sendInterrupted()
                }
            }
        }
    }
}

extension Feedback {
    public init<Effect: SignalProducerConvertible, Control>(
        ignoreAllUntilFinished query: @escaping (State) -> Control?,
        effect: @escaping (Control) -> Effect
    ) where Effect.Value == Event, Effect.Error == NoError {
        self.init { scheduler, state in
            state.filterMap(query)
                .flatMapFirst {
                    return effect($0).producer
                        .observe(on: scheduler)
                }
        }
    }
}

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
let apiKey = "d4f0bdb3e246e2cb3555211e765c89e3"
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

func switchFail() {
    shouldFail = !shouldFail
}

extension URLSession {
    func fetchMovies(page: Int) -> SignalProducer<Results, NSError> {
        return SignalProducer.init({ (observer, lifetime) in
            let url = URL(string: "https://api.themoviedb.org/3/discover/movie?api_key=\(shouldFail ? apiKey : correctKey)&sort_by=popularity.desc&page=\(page)")!
            switchFail()
            let task = self.dataTask(with: url, completionHandler: { (data, response, error) in
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                    let error = NSError(domain: "come.reactivefeedback",
                                        code: 401,
                                        userInfo: [NSLocalizedDescriptionKey: "Forced failure to illustrate Retry"])
                    observer.send(error: error)
                } else if let data = data {
                    do {
                        let results = try JSONDecoder().decode(Results.self, from: data)
                        observer.send(value: results)
                    } catch {
                        observer.send(error: error as NSError)
                    }
                } else if let error = error {
                    observer.send(error: error as NSError)
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
