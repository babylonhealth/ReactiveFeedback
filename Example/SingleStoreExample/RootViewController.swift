import UIKit
import ReactiveSwift
import ReactiveFeedback

final class RootViewController: UITabBarController {
    private let store: Store<State, Event>
    private lazy var counterVC = ContainerViewController<CounterView>()
    private lazy var moviesVC = ContainerViewController<MoviesView>()

    init() {
        let appReducer: Reducer<State, Event> = combine(
            pullback(
                Counter.reduce,
                value: \.counter,
                event: \.counter
            ),
            pullback(
                Movies.reduce,
                value: \.movies,
                event: \.movies
            )
        )

        let appFeedbacks: Feedback<State, Event> = Feedback.combine(
            Feedback.pullback(
                feedback: Movies.feedback,
                value: \.movies,
                event: Event.movies
            )
        )
        self.store = Store(
            initial: State(),
            reducer: appReducer,
            feedbacks: [appFeedbacks],
            scheduler: QueueScheduler.main
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewControllers = [counterVC, moviesVC]
        counterVC.tabBarItem = UITabBarItem(
            title: "Counter",
            image: UIImage(named: "counter"),
            selectedImage: UIImage(named: "counter")
        )
        moviesVC.tabBarItem = UITabBarItem(
            title: "Movies",
            image: UIImage(named: "movie"),
            selectedImage: UIImage(named: "movie")
        )
        bindStore()
    }

    func bindStore() {
        store.state.producer
            .map { $0.view(value: \.counter, event: Event.counter) }
            .startWithValues(counterVC.contentView.render)
        store.state.producer
            .map { $0.view(value: \.movies, event: Event.movies) }
            .startWithValues(moviesVC.contentView.render)
    }
}

final class ContainerViewController<Content: UIView & NibLoadable>: UIViewController {
    lazy private(set) var contentView = Content.loadFromNib()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.view = contentView
    }
}

struct State {
    var counter = Counter.State()
    var movies = Movies.State.empty
}

enum Event {
    case counter(Counter.Event)
    case movies(Movies.Event)

    var counter: Counter.Event? {
        get {
            guard case let .counter(value) = self else { return nil }
            return value
        }
        set {
            guard case .counter = self, let newValue = newValue else { return }
            self = .counter(newValue)
        }
    }

    var movies: Movies.Event? {
        get {
            guard case let .movies(value) = self else { return nil }
            return value
        }
        set {
            guard case .movies = self, let newValue = newValue else { return }
            self = .movies(newValue)
        }
    }
}
