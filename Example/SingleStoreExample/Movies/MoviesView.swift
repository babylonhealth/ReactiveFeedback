import UIKit
import ReactiveFeedback

final class MoviesViewController: ContainerViewController<MoviesView> {
    private let store: Store<Movies.State, Movies.Event>
    
    init(store: Store<Movies.State, Movies.Event>) {
        self.store = store
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        store.state.producer.startWithValues(contentView.render)
        contentView.didSelectItem.action = { [unowned self] movie in
            let nc = self.navigationController!
            let vc = ColorPickerViewController(
                store: self.store.view(
                    value: \.colorPicker,
                    event: Movies.Event.picker
                )
            )
            nc.pushViewController(vc, animated: true)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class MoviesView: UICollectionView, NibLoadable, UICollectionViewDelegateFlowLayout {
    public let didSelectItem = CommandWith<Movie>()
    private let adapter = ArrayCollectionViewDataSource<Movie>()
    private let loadNext = Command()
    private var isReloadInProgress = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.dataSource = adapter
        register(MovieCell.nib, forCellWithReuseIdentifier: "\(MovieCell.self)")
        adapter.cellFactory = { (collectionView, indexPath, item) -> UICollectionViewCell in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "\(MovieCell.self)",
                for: indexPath
                ) as! MovieCell
            cell.configure(with: item)
            
            return cell
        }
        self.delegate = self
    }
    
    func render(context: Context<Movies.State, Movies.Event>) {
        adapter.update(with: context.movies)
        backgroundColor = context.backgroundColor
        loadNext.action = {
            context.send(event: .startLoadingNextPage)
        }
        reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let movie = adapter.items[indexPath.row]
        didSelectItem.action(movie)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.row == adapter.items.count - 1 {
            // Because feedbacks are now synchronous
            // Dispatching some events may cause a dead lock
            // because collection view calls it again during reload data
            DispatchQueue.main.async {
                self.loadNext.action()
            }
        }
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let flowLayout = collectionViewLayout as! UICollectionViewFlowLayout
        let spacing = flowLayout.minimumInteritemSpacing
        let width = (collectionView.bounds.width - 3 * spacing) / 3
        
        return CGSize(
            width: width,
            height: width * 1.5
        )
    }
}
