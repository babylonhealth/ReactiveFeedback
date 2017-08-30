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
import enum Result.NoError

class PaginationViewController: UICollectionViewController {
    let dataSource = ArrayCollectionViewDataSource<Movie>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDataSource()
        
        let loadNextFeedback: FeedBack<State, PagingEvent> = {
            return $0.flatMap(.latest, { (state) -> Signal<PagingEvent, NoError> in
                if state.paging {
                    return Signal<PagingEvent, NoError>.empty
                }
                return self.collectionView!.rac_nearBottomSignal
                    .map { _ in PagingEvent.startLoadingNextPage }
            })
        }
        
        let pagingFeedback: FeedBack<State, PagingEvent> = React
            .feedback(query: { $0.nextPage }) { (nextPage) -> SignalProducer<PagingEvent, NoError> in
                return URLSession.shared.fetchPoster(page: nextPage)
                    .map(PagingEvent.response)
                    .flatMapError { (error) -> SignalProducer<PagingEvent, NoError> in
                        return SignalProducer(value: PagingEvent.failed(error))
                    }
            }
        
        let state = SignalProducer<State, NoError>.system(initialState: State.empty,
                                              reduce: PagingReducer.reduce,
                                              feedback: loadNextFeedback, pagingFeedback)
            .map { $0.movies }
            .start(on: QueueScheduler.main)
            .observe(on: QueueScheduler.main)
        
        let property = Property<[Movie]>(initial: [], then: state)
        
        
        property.signal.bind(with: collectionView!.rac_items(dataSource: dataSource))
    }
    
    func setupDataSource() {
        dataSource.cellFactory = { cv, ip, item in
            let cell = cv.dequeueReusableCell(withReuseIdentifier: "MoviewCell", for: ip) as! MoviewCell
            cell.configure(with: item)
            return cell
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

struct State {
    var paging: Bool
    var shouldPageNext: Bool
    var batch: Results<Movie>
    var movies: [Movie]
    var lastError: NSError?
}

extension State {
    static var empty: State {
        return State(paging: false,
                     shouldPageNext: true,
                     batch: Results<Movie>(page: 0, totalResults: 0, totalPages: 0, results: []),
                     movies: [],
                     lastError: nil)
    }
    
    var nextPage: Int? {
        return shouldPageNext ? batch.page + 1 : nil
    }
}

enum PagingEvent {
    case startLoadingNextPage
    case response(Results<Movie>)
    case failed(NSError)
}

struct PagingReducer {
    static func reduce(state: State, event: PagingEvent) -> State {
        switch event {
        case .startLoadingNextPage:
            var newState = state
            newState.shouldPageNext = true
            newState.paging = true
            
            return newState
        case .response(let results):
            var newState = state
            newState.batch = results
            newState.movies = state.movies + results.results
                .filter { $0.posterPath != nil }
            newState.shouldPageNext = false
            newState.paging = false
            newState.lastError = nil
            
            return newState
        case .failed(let error):
            var newState = state
            newState.lastError = error
            newState.shouldPageNext = false
            
            return newState
        }
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

// Boring API boilerplate
typealias JSON = [String: Any]

extension Dictionary where Key == String, Value == Any {
    subscript(int key: Key) -> Int? {
        return self[key] as? Int
    }
    
    subscript(string key: Key) -> String? {
        return self[key] as? String
    }
    
    subscript(objects key: Key) -> [JSON] {
        return self[key] as? [JSON] ?? []
    }
}

protocol JSONSerializable {
    init(json: JSON)
}

struct Results<T: JSONSerializable> {
    let page: Int
    let totalResults: Int
    let totalPages: Int
    let results: [T]
}

extension Results: JSONSerializable {
    init(json: JSON) {
        self.page = json[int: "page"] ?? 0
        self.totalResults = json[int: "total_results"] ?? 0
        self.totalPages = json[int: "total_pages"] ?? 0
        self.results = json[objects: "results"].map(T.init)
    }
}

struct Movie {
    let id: Int
    let overview: String
    let title: String
    let posterPath: String?
    
    var posterURL: URL? {
        return posterPath
            .map {
                return "https://image.tmdb.org/t/p/w342/\($0)"
            }
            .flatMap(URL.init(string:))
    }
}

extension Movie: JSONSerializable {
    init(json: JSON) {
        self.id = json[int: "id"] ?? 0
        self.overview = json[string: "overview"] ?? ""
        self.title = json[string: "title"] ?? ""
        self.posterPath = json[string: "poster_path"]
    }
}

extension URLSession {
    func fetchPoster(page: Int) -> SignalProducer<Results<Movie>, NSError> {
        return SignalProducer.init({ (observer, lifetime) in
            let url = URL(string: "https://api.themoviedb.org/3/discover/movie?api_key=\(apiKey)&sort_by=popularity.desc&page=\(page)")!
            let task = self.dataTask(with: url, completionHandler: { (data, response, error) in
                if let data = data {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data, options: []) as! JSON
                        observer.send(value: Results<Movie>(json: json))
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
    func rac_items<DataSource: RACCollectionViewDataSourceType & UICollectionViewDataSource, S: SignalProtocol>(dataSource: DataSource) -> (S) -> Disposable? where S.Error == NoError, S.Value == DataSource.Element {
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

extension SignalProtocol {
    @discardableResult
    func bind<R>(with: (Signal<Value, Error>) -> R) -> R {
        return with(self.signal)
    }
}
