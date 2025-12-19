//
//  CarPlayDataProvider.swift
//  App
//
//  Created for CarPlay integration
//

import Foundation
import RealmSwift

// MARK: - CarPlay Listable Item Protocol

protocol CarPlayListableItem {
    var title: String { get }
    var subtitle: String? { get }
    var coverUrl: URL? { get }
    var isLocal: Bool { get }
    var libraryItemId: String? { get }
    var episodeId: String? { get }
    var localLibraryItem: LocalLibraryItem? { get }
}

// MARK: - Data Models

struct CarPlayAuthor {
    let id: String
    let name: String
}

struct CarPlaySeries {
    let id: String
    let name: String
}

struct CarPlayLibraryItem: CarPlayListableItem {
    let title: String
    let subtitle: String?
    let coverUrl: URL?
    let isLocal: Bool
    let libraryItemId: String?
    let episodeId: String?
    let localLibraryItem: LocalLibraryItem?
    let progress: Double?
}

// MARK: - Data Provider

class CarPlayDataProvider {

    // MARK: - Continue Listening

    func fetchContinueListeningItems(completion: @escaping ([CarPlayLibraryItem]) -> Void) {
        var items: [CarPlayLibraryItem] = []

        // Get items with local progress
        let localProgress = Database.shared.getAllLocalMediaProgress()
            .filter { !$0.isFinished && $0.progress > 0 && $0.progress < 0.99 }
            .sorted { $0.lastUpdate > $1.lastUpdate }

        for progress in localProgress.prefix(20) {
            if let localItem = Database.shared.getLocalLibraryItem(localLibraryItemId: progress.localLibraryItemId) {
                let item = CarPlayLibraryItem(
                    title: localItem.media?.metadata?.title ?? "Unknown",
                    subtitle: formatProgress(progress.progress),
                    coverUrl: localItem.coverUrl,
                    isLocal: true,
                    libraryItemId: localItem.libraryItemId,
                    episodeId: progress.episodeId,
                    localLibraryItem: localItem,
                    progress: progress.progress
                )
                items.append(item)
            }
        }

        DispatchQueue.main.async {
            completion(items)
        }
    }

    // MARK: - Library Items

    func fetchLibraryItems(mediaType: String, completion: @escaping ([CarPlayLibraryItem]) -> Void) {
        guard Store.serverConfig != nil else {
            completion([])
            return
        }

        let endpoint = "api/libraries?minified=1"
        ApiClient.getResource(endpoint: endpoint, decodable: CarPlayLibraryListResponse.self) { response in
            guard let libraries = response?.libraries else {
                completion([])
                return
            }

            // Find library matching media type
            guard let library = libraries.first(where: { $0.mediaType == mediaType }) else {
                completion([])
                return
            }

            // Fetch items from library
            let itemsEndpoint = "api/libraries/\(library.id)/items?minified=1&limit=100"
            ApiClient.getResource(endpoint: itemsEndpoint, decodable: CarPlayLibraryItemsResponse.self) { itemsResponse in
                guard let results = itemsResponse?.results else {
                    completion([])
                    return
                }

                let items = results.map { item in
                    CarPlayLibraryItem(
                        title: item.media?.metadata?.title ?? "Unknown",
                        subtitle: item.media?.metadata?.authorDisplayName,
                        coverUrl: self.getCoverUrl(for: item.id),
                        isLocal: false,
                        libraryItemId: item.id,
                        episodeId: nil,
                        localLibraryItem: nil,
                        progress: item.userMediaProgress?.progress
                    )
                }

                DispatchQueue.main.async {
                    completion(items)
                }
            }
        }
    }

    // MARK: - Authors

    func fetchAuthors(completion: @escaping ([CarPlayAuthor]) -> Void) {
        guard Store.serverConfig != nil else {
            completion([])
            return
        }

        // First get a library ID
        let endpoint = "api/libraries?minified=1"
        ApiClient.getResource(endpoint: endpoint, decodable: CarPlayLibraryListResponse.self) { response in
            guard let library = response?.libraries.first(where: { $0.mediaType == "book" }) else {
                completion([])
                return
            }

            let authorsEndpoint = "api/libraries/\(library.id)/authors"
            ApiClient.getResource(endpoint: authorsEndpoint, decodable: CarPlayAuthorsResponse.self) { authorsResponse in
                let authors = authorsResponse?.authors.map { CarPlayAuthor(id: $0.id, name: $0.name) } ?? []
                DispatchQueue.main.async {
                    completion(authors)
                }
            }
        }
    }

    func fetchItemsByAuthor(authorId: String, completion: @escaping ([CarPlayLibraryItem]) -> Void) {
        let endpoint = "api/authors/\(authorId)?include=items"
        ApiClient.getResource(endpoint: endpoint, decodable: CarPlayAuthorDetailResponse.self) { response in
            let items = response?.libraryItems?.map { item in
                CarPlayLibraryItem(
                    title: item.media?.metadata?.title ?? "Unknown",
                    subtitle: item.media?.metadata?.authorDisplayName,
                    coverUrl: self.getCoverUrl(for: item.id),
                    isLocal: false,
                    libraryItemId: item.id,
                    episodeId: nil,
                    localLibraryItem: nil,
                    progress: item.userMediaProgress?.progress
                )
            } ?? []

            DispatchQueue.main.async {
                completion(items)
            }
        }
    }

    // MARK: - Series

    func fetchSeries(completion: @escaping ([CarPlaySeries]) -> Void) {
        guard Store.serverConfig != nil else {
            completion([])
            return
        }

        // First get library ID
        let endpoint = "api/libraries?minified=1"
        ApiClient.getResource(endpoint: endpoint, decodable: CarPlayLibraryListResponse.self) { response in
            guard let library = response?.libraries.first(where: { $0.mediaType == "book" }) else {
                completion([])
                return
            }

            let seriesEndpoint = "api/libraries/\(library.id)/series"
            ApiClient.getResource(endpoint: seriesEndpoint, decodable: CarPlaySeriesResponse.self) { seriesResponse in
                let series = seriesResponse?.results.map { CarPlaySeries(id: $0.id, name: $0.name) } ?? []
                DispatchQueue.main.async {
                    completion(series)
                }
            }
        }
    }

    func fetchItemsBySeries(seriesId: String, completion: @escaping ([CarPlayLibraryItem]) -> Void) {
        let endpoint = "api/series/\(seriesId)?include=items"
        ApiClient.getResource(endpoint: endpoint, decodable: CarPlaySeriesDetailResponse.self) { response in
            let items = response?.books?.map { item in
                CarPlayLibraryItem(
                    title: item.media?.metadata?.title ?? "Unknown",
                    subtitle: item.media?.metadata?.authorDisplayName,
                    coverUrl: self.getCoverUrl(for: item.id),
                    isLocal: false,
                    libraryItemId: item.id,
                    episodeId: nil,
                    localLibraryItem: nil,
                    progress: item.userMediaProgress?.progress
                )
            } ?? []

            DispatchQueue.main.async {
                completion(items)
            }
        }
    }

    // MARK: - Genres

    func fetchGenres(completion: @escaping ([String]) -> Void) {
        guard Store.serverConfig != nil else {
            completion([])
            return
        }

        // Get genres from first book library
        let endpoint = "api/libraries?minified=1"
        ApiClient.getResource(endpoint: endpoint, decodable: CarPlayLibraryListResponse.self) { response in
            guard let library = response?.libraries.first(where: { $0.mediaType == "book" }) else {
                completion([])
                return
            }

            let filterEndpoint = "api/libraries/\(library.id)/filterdata"
            ApiClient.getResource(endpoint: filterEndpoint, decodable: CarPlayFilterDataResponse.self) { filterResponse in
                let genres = filterResponse?.genres ?? []
                DispatchQueue.main.async {
                    completion(genres)
                }
            }
        }
    }

    func fetchItemsByGenre(genre: String, completion: @escaping ([CarPlayLibraryItem]) -> Void) {
        guard Store.serverConfig != nil else {
            completion([])
            return
        }

        let endpoint = "api/libraries?minified=1"
        ApiClient.getResource(endpoint: endpoint, decodable: CarPlayLibraryListResponse.self) { response in
            guard let library = response?.libraries.first(where: { $0.mediaType == "book" }) else {
                completion([])
                return
            }

            // Base64 encode the genre for the filter parameter
            let genreData = genre.data(using: .utf8)!
            let genreBase64 = genreData.base64EncodedString()
            let itemsEndpoint = "api/libraries/\(library.id)/items?filter=genres.\(genreBase64)&minified=1&limit=100"

            ApiClient.getResource(endpoint: itemsEndpoint, decodable: CarPlayLibraryItemsResponse.self) { itemsResponse in
                let items = itemsResponse?.results.map { item in
                    CarPlayLibraryItem(
                        title: item.media?.metadata?.title ?? "Unknown",
                        subtitle: item.media?.metadata?.authorDisplayName,
                        coverUrl: self.getCoverUrl(for: item.id),
                        isLocal: false,
                        libraryItemId: item.id,
                        episodeId: nil,
                        localLibraryItem: nil,
                        progress: item.userMediaProgress?.progress
                    )
                } ?? []

                DispatchQueue.main.async {
                    completion(items)
                }
            }
        }
    }

    // MARK: - Search

    func search(query: String, completion: @escaping ([CarPlayLibraryItem]) -> Void) {
        guard Store.serverConfig != nil, !query.isEmpty else {
            completion([])
            return
        }

        let endpoint = "api/libraries?minified=1"
        ApiClient.getResource(endpoint: endpoint, decodable: CarPlayLibraryListResponse.self) { response in
            guard let library = response?.libraries.first else {
                completion([])
                return
            }

            let queryEncoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let searchEndpoint = "api/libraries/\(library.id)/search?q=\(queryEncoded)&limit=20"

            ApiClient.getResource(endpoint: searchEndpoint, decodable: CarPlaySearchResponse.self) { searchResponse in
                var items: [CarPlayLibraryItem] = []

                // Add book results
                for result in searchResponse?.book ?? [] {
                    items.append(CarPlayLibraryItem(
                        title: result.libraryItem.media?.metadata?.title ?? "Unknown",
                        subtitle: result.libraryItem.media?.metadata?.authorDisplayName,
                        coverUrl: self.getCoverUrl(for: result.libraryItem.id),
                        isLocal: false,
                        libraryItemId: result.libraryItem.id,
                        episodeId: nil,
                        localLibraryItem: nil,
                        progress: nil
                    ))
                }

                // Add podcast results
                for result in searchResponse?.podcast ?? [] {
                    items.append(CarPlayLibraryItem(
                        title: result.libraryItem.media?.metadata?.title ?? "Unknown",
                        subtitle: "Podcast",
                        coverUrl: self.getCoverUrl(for: result.libraryItem.id),
                        isLocal: false,
                        libraryItemId: result.libraryItem.id,
                        episodeId: nil,
                        localLibraryItem: nil,
                        progress: nil
                    ))
                }

                DispatchQueue.main.async {
                    completion(items)
                }
            }
        }
    }

    // MARK: - Helpers

    func getCoverUrl(for itemId: String) -> URL? {
        guard let config = Store.serverConfig else { return nil }

        let coverUrlString: String
        if Store.isServerVersionGreaterThanOrEqualTo("2.17.0") {
            coverUrlString = "\(config.address)/api/items/\(itemId)/cover"
        } else {
            coverUrlString = "\(config.address)/api/items/\(itemId)/cover?token=\(config.token)"
        }

        return URL(string: coverUrlString)
    }

    private func formatProgress(_ progress: Double) -> String {
        let percent = Int(progress * 100)
        return "\(percent)% complete"
    }
}

// MARK: - Response Models

struct CarPlayLibraryListResponse: Decodable {
    let libraries: [CarPlayLibraryInfo]

    struct CarPlayLibraryInfo: Decodable {
        let id: String
        let name: String
        let mediaType: String
    }
}

struct CarPlayLibraryItemsResponse: Decodable {
    let results: [LibraryItem]
}

struct CarPlayAuthorsResponse: Decodable {
    let authors: [CarPlayAuthorInfo]

    struct CarPlayAuthorInfo: Decodable {
        let id: String
        let name: String
    }
}

struct CarPlayAuthorDetailResponse: Decodable {
    let libraryItems: [LibraryItem]?
}

struct CarPlaySeriesResponse: Decodable {
    let results: [CarPlaySeriesInfo]

    struct CarPlaySeriesInfo: Decodable {
        let id: String
        let name: String
    }
}

struct CarPlaySeriesDetailResponse: Decodable {
    let books: [LibraryItem]?
}

struct CarPlayFilterDataResponse: Decodable {
    let genres: [String]?
}

struct CarPlaySearchResponse: Decodable {
    let book: [CarPlayBookSearchResult]?
    let podcast: [CarPlayPodcastSearchResult]?

    struct CarPlayBookSearchResult: Decodable {
        let libraryItem: LibraryItem
    }

    struct CarPlayPodcastSearchResult: Decodable {
        let libraryItem: LibraryItem
    }
}
