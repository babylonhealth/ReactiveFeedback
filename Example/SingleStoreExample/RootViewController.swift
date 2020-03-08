import ReactiveFeedback
import ReactiveSwift
import UIKit

final class RootViewController: UITabBarController {
    private let store: Store<State, Event>

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

        let appFeedbacks: FeedbackLoop<State, Event>.Feedback = FeedbackLoop<State, Event>.Feedback.combine(
            FeedbackLoop<State, Event>.Feedback.pullback(
                feedback: Movies.feedback,
                value: \.movies,
                event: Event.movies
            )
        )
        store = Store(
            initial: State(),
            reducer: appReducer,
            feedbacks: [appFeedbacks]
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let counterVC = CounterViewController(
            store: store.view(
                value: \.counter,
                event: Event.counter
            )
        )
        let moviesVC = MoviesViewController(
            store: store.view(
                value: \.movies,
                event: Event.movies
            )
        )
        viewControllers = [
            UINavigationController(rootViewController: counterVC),
            UINavigationController(rootViewController: moviesVC),
            UINavigationController(rootViewController: TextInputViewController())
        ]
        if #available(iOS 11.0, *) {
            counterVC.navigationItem.largeTitleDisplayMode = .always
        }
        counterVC.title = "Counter"
        counterVC.tabBarItem = UITabBarItem(
            title: "Counter",
            image: UIImage(named: "counter"),
            selectedImage: UIImage(named: "counter")
        )
        if #available(iOS 11.0, *) {
            moviesVC.navigationItem.largeTitleDisplayMode = .always
        }
        moviesVC.title = "Movies"
        moviesVC.tabBarItem = UITabBarItem(
            title: "Movies",
            image: UIImage(named: "movie"),
            selectedImage: UIImage(named: "movie")
        )
    }
}

open class ContainerViewController<Content: UIView & NibLoadable>: UIViewController {
    private(set) lazy var contentView = Content.loadFromNib()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func loadView() {
        view = contentView
    }
}

struct State {
    var counter = Counter.State()
    var movies = Movies.State()
}

enum Event {
    case counter(Counter.Event)
    case movies(Movies.Event)

    // This can be done with CasePaths
    // https://github.com/pointfreeco/swift-case-paths
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
