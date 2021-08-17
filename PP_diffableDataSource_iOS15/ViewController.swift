//
//  ViewController.swift
//  PP_diffableDataSource_iOS15
//
//  Created by Oleg Soldatoff on 10.08.21.
//

import Combine
import UIKit

struct Link: Identifiable {
    let id: String
    var text: String
    let url: String
    var image: UIImage?
}

class MyData {
    static let links: [String] = [
        "https://content.onliner.by/news/1100x5616/4541f5d2f53ac60ac7ebb41f6525ef9a.jpeg",
        "https://content.onliner.by/news/1100x5616/9442772e3c4b2fcd8ee53207b282fe8c.jpeg",
        "https://content.onliner.by/news/1100x5616/4331182f9ce3bf2d4f891dd1b4b2db86.jpeg",
        "https://content.onliner.by/news/1100x5616/822d6e953ab90d69cb3e0a7762020611.jpeg",
        "https://content.onliner.by/news/1100x5616/673d79aa27fc38aec048b63083edea8c.jpeg",
        "https://content.onliner.by/news/1400x5616/f3b75beb20c202d43f823729e345db67.jpeg",
        "https://content.onliner.by/news/1100x5616/cba728526b534b8f7dc8f123f7d3c1ba.jpeg",
        "https://content.onliner.by/news/1100x5616/555ddfa04ed031473adaa6989b169f32.jpeg",
        "https://content.onliner.by/news/970x485/93b407f9c58dc70a7711f4c699c40fd0.jpeg",
        "https://content.onliner.by/news/970x485/36bedd39574ebc58b654c9d1017a9ac1.jpeg",
        "https://content.onliner.by/news/970x485/2d8bfd5a991fadf8a695d81ba172d88f.jpeg",
        "https://content.onliner.by/news/1100x5616/b910c3c8c52e2ff89a54b30cf762c78f.jpeg",
        "https://content.onliner.by/news/1100x5616/1cc0c85c68d9253ce48caaff74ca9e82.jpeg",
        "https://content.onliner.by/news/1100x5616/1d34b4b52e1fc82f21e9106e19f4cf82.jpeg"
    ]
}


class ViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<Int, String>!
    var links: [Link]!
    fileprivate var prefetchingIndexPathOperations = [IndexPath: AnyCancellable]()
    var session: URLSession!

    override func viewDidLoad() {
        let config = URLSessionConfiguration.ephemeral
        session = URLSession(configuration: config)
        super.viewDidLoad()
        links = MyData.links.enumerated().map { (index, element) in Link(id: element, text: "\(index)" , url: element) }
        addCollectionView()
    }

    func addCollectionView() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, String> { [weak self] cell, indexPath, id in
            print("INdexPath from CellRegistration \(indexPath)")
            guard let self = self else { return }
            let link = self.links.first(where: { $0.id == id })
            guard var link = link else { return }

            var contentConfiguration = cell.defaultContentConfiguration()
            contentConfiguration.text = link.text
            contentConfiguration.textProperties.color = .lightGray
            if link.image != nil {
                contentConfiguration.image = link.image
            }
            else if self.prefetchingIndexPathOperations[indexPath] == nil {
                self.prefetchingIndexPathOperations[indexPath] = self.session.dataTaskPublisher(for: URL(string: link.url)!).sink(receiveCompletion: { _ in }, receiveValue: { [weak self] (data, response) in
//                    link.image = UIImage(data: data)
                    link.image = UIImage(data: data)?.preparingForDisplay()
                    self?.updateLink(at: nil, link: link)
                    self?.setLinkNeedsUpdate(id)
                })
            }
            cell.contentConfiguration = contentConfiguration
        }

        dataSource = UICollectionViewDiffableDataSource<Int, String>(collectionView: collectionView, cellProvider: { (collectionView, indexPath, id) -> UICollectionViewCell? in

            let cell = collectionView.dequeueConfiguredReusableCell(using: cellRegistration,
                                                                    for: indexPath,
                                                                    item: id)

            return cell
        })
        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([0])
        snapshot.appendItems(links.map { $0.id }, toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

}

extension ViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let selectedID = dataSource.itemIdentifier(for: indexPath),
              let linkIndex = links.firstIndex(where: { $0.id == selectedID }) else { return }

        var link = links[linkIndex]
        link.text = link.text.appending(" *")
        updateLink(at: linkIndex, link: link)

        setLinkNeedsUpdate(selectedID)
    }

    func updateLink(at linkIndex: Int?, link: Link) {
        if let linkIndex = linkIndex {
            links[linkIndex] = link
        } else if let linkIndex = links.firstIndex(where: { $0.id == link.id }) {
            links[linkIndex] = link
        }
    }

    func setLinkNeedsUpdate(_ id: Link.ID) {
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems([id])
//        snapshot.reloadItems([id])
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}

extension ViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
//        return
        print("INdexPaths from prefetchItemsAt \(indexPaths)")
        for indexPath in indexPaths {
            guard prefetchingIndexPathOperations[indexPath] == nil else {
                continue
            }
            guard let destinationID = dataSource.itemIdentifier(for: indexPath),
                  var destinationLink = links.first(where: { $0.id == destinationID }) else {
                continue
            }

            prefetchingIndexPathOperations[indexPath] =
            session.dataTaskPublisher(for: URL(string: destinationLink.url)!)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { [weak self] (data, response) in
//                    destinationLink.image = UIImage(data: data)
                    destinationLink.image = UIImage(data: data)?.preparingForDisplay()
                    self?.updateLink(at: nil, link: destinationLink)
                    self?.setLinkNeedsUpdate(destinationID)
                })
        }
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
//        return
        for indexPath in indexPaths {
            prefetchingIndexPathOperations.removeValue(forKey: indexPath)?.cancel()
        }
    }
}
