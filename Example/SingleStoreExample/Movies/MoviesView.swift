import UIKit
import ReactiveFeedback

final class MoviesView: UICollectionView, NibLoadable, UICollectionViewDelegateFlowLayout {
    private let adapter = ArrayCollectionViewDataSource<Movie>()
    private let loadNext = Command()

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
        reloadData()
        loadNext.action = {
            context.send(event: .startLoadingNextPage)
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.row == adapter.items.count - 4 {
            loadNext.action()
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
