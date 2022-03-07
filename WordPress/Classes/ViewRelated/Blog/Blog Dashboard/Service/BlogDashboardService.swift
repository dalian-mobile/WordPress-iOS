import Foundation
import WordPressKit

class BlogDashboardService {

    private let remoteService: DashboardServiceRemote
    private let persistence: BlogDashboardPersistence

    init(managedObjectContext: NSManagedObjectContext, remoteService: DashboardServiceRemote? = nil, persistence: BlogDashboardPersistence = BlogDashboardPersistence()) {
        self.remoteService = remoteService ?? DashboardServiceRemote(wordPressComRestApi: WordPressComRestApi.defaultApi(in: managedObjectContext, localeKey: WordPressComRestApi.LocaleKeyV2))
        self.persistence = persistence
    }

    /// Fetch cards from remote
    func fetch(blog: Blog, completion: @escaping (DashboardSnapshot) -> Void, failure: ((DashboardSnapshot?) -> Void)? = nil) {

        guard let dotComID = blog.dotComID?.intValue else {
            return
        }

        let cardsToFetch: [String] = DashboardCard.remoteCases.map { $0.rawValue }

        remoteService.fetch(cards: cardsToFetch, forBlogID: dotComID, success: { [weak self] cardsDictionary in

            if let cards = self?.decode(cardsDictionary) {

                blog.dashboardState.hasCachedData = true
                blog.dashboardState.failedToLoad = false

                self?.persistence.persist(cards: cardsDictionary, for: dotComID)

                guard let snapshot = self?.parse(cardsDictionary, cards: cards, blog: blog, dotComID: dotComID) else {
                    return
                }

                completion(snapshot)
            } else {
                blog.dashboardState.failedToLoad = true
                failure?(nil)
            }

        }, failure: { [weak self] _ in
            blog.dashboardState.failedToLoad = true
            let snapshot = self?.fetchLocal(blog: blog)
            failure?(snapshot)
        })
    }

    /// Fetch cards from local
    func fetchLocal(blog: Blog) -> DashboardSnapshot {

        guard let dotComID = blog.dotComID?.intValue else {
            return DashboardSnapshot()
        }

        if let cardsDictionary = persistence.getCards(for: dotComID),
            let cards = decode(cardsDictionary) {

            blog.dashboardState.hasCachedData = true
            let snapshot = parse(cardsDictionary, cards: cards, blog: blog)
            return snapshot
        } else {
            blog.dashboardState.hasCachedData = false
            return localCards(blog: blog)
        }
    }
}

private extension BlogDashboardService {
    /// We use the `BlogDashboardRemoteEntity` to inject it into cells
    /// The `NSDictionary` is used for `Hashable` purposes
    func parse(_ cardsDictionary: NSDictionary, cards: BlogDashboardRemoteEntity, blog: Blog, dotComID: Int) -> DashboardSnapshot {
        var snapshot = DashboardSnapshot()

        DashboardCard.allCases
            .forEach { card in

            if card.isRemote {
                if let viewModel = cardsDictionary[card.rawValue] {
                    let section = DashboardCardSection(id: card)
                    let item = DashboardCardModel(id: card,
                                                  dotComID: dotComID,
                                                  hashableDictionary: viewModel as? NSDictionary,
                                                  entity: cards)

                    snapshot.appendSections([section])
                    snapshot.appendItems([item], toSection: section)
                }
            } else {

                guard card.shouldShow(for: blog) else {
                    return
                }

                let section = DashboardCardSection(id: card)
                let item = DashboardCardModel(id: card, dotComID: dotComID)

                snapshot.appendSections([section])
                snapshot.appendItems([item], toSection: section)
            }

        }

        return snapshot
    }

    func decode(_ cardsDictionary: NSDictionary) -> BlogDashboardRemoteEntity? {
        guard let data = try? JSONSerialization.data(withJSONObject: cardsDictionary, options: []) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(BlogDashboardRemoteEntity.self, from: data)
    }

    func localCards(blog: Blog) -> DashboardSnapshot {
        parse([:], cards: BlogDashboardRemoteEntity(), blog: blog)
    }
}
