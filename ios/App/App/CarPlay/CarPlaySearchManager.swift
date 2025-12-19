//
//  CarPlaySearchManager.swift
//  App
//
//  Created for CarPlay integration
//

import CarPlay
import Foundation

class CarPlaySearchManager: NSObject, CPSearchTemplateDelegate {

    static let shared = CarPlaySearchManager()

    private let dataProvider = CarPlayDataProvider()
    private let imageLoader = CarPlayImageLoader()
    private var currentSearchTask: DispatchWorkItem?
    private weak var interfaceController: CPInterfaceController?

    private override init() {
        super.init()
    }

    func setInterfaceController(_ controller: CPInterfaceController?) {
        self.interfaceController = controller
    }

    // MARK: - CPSearchTemplateDelegate

    func searchTemplate(_ searchTemplate: CPSearchTemplate, updatedSearchText searchText: String, completionHandler: @escaping ([CPListItem]) -> Void) {
        // Cancel previous search
        currentSearchTask?.cancel()

        // Debounce search
        let task = DispatchWorkItem { [weak self] in
            self?.performSearch(query: searchText, completion: completionHandler)
        }

        currentSearchTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }

    func searchTemplate(_ searchTemplate: CPSearchTemplate, selectedResult item: CPListItem, completionHandler: @escaping () -> Void) {
        // Item selection is handled by the item's handler
        completionHandler()
    }

    func searchTemplateSearchButtonPressed(_ searchTemplate: CPSearchTemplate) {
        // Search button pressed - results already displayed
    }

    // MARK: - Search Implementation

    private func performSearch(query: String, completion: @escaping ([CPListItem]) -> Void) {
        guard !query.isEmpty else {
            completion([])
            return
        }

        // Check if connected to server
        guard Store.serverConfig != nil else {
            let offlineItem = CPListItem(text: "Not Connected", detailText: "Open app to connect to server")
            offlineItem.isEnabled = false
            completion([offlineItem])
            return
        }

        dataProvider.search(query: query) { [weak self] items in
            guard let self = self else {
                completion([])
                return
            }

            if items.isEmpty {
                let noResultsItem = CPListItem(text: "No results found", detailText: "Try a different search term")
                noResultsItem.isEnabled = false
                completion([noResultsItem])
                return
            }

            let listItems = items.map { item -> CPListItem in
                let listItem = CPListItem(text: item.title, detailText: item.subtitle)

                // Load artwork
                if let coverUrl = item.coverUrl {
                    self.imageLoader.loadImage(from: coverUrl) { image in
                        if let image = image {
                            listItem.setImage(image)
                        }
                    }
                }

                // Capture values for handler
                let libraryItemId = item.libraryItemId
                let episodeId = item.episodeId

                // Handle selection
                listItem.handler = { [weak self] _, handlerCompletion in
                    if let libraryItemId = libraryItemId {
                        self?.playItem(libraryItemId: libraryItemId, episodeId: episodeId)
                    }
                    handlerCompletion()
                }

                return listItem
            }

            completion(listItems)
        }
    }

    private func playItem(libraryItemId: String, episodeId: String?) {
        ApiClient.startPlaybackSession(libraryItemId: libraryItemId, episodeId: episodeId, forceTranscode: false) { [weak self] session in
            guard !session.id.isEmpty else {
                AbsLogger.error(message: "CarPlay Search: Failed to create playback session")
                return
            }

            do {
                try session.save()
                let playbackRate = PlayerSettings.main().playbackRate
                PlayerHandler.startPlayback(sessionId: session.id, playWhenReady: true, playbackRate: playbackRate)

                // Show now playing
                if let interfaceController = self?.interfaceController {
                    let nowPlayingTemplate = CPNowPlayingTemplate.shared
                    interfaceController.pushTemplate(nowPlayingTemplate, animated: true, completion: nil)
                }
            } catch {
                AbsLogger.error(message: "CarPlay Search: Failed to start playback: \(error)")
            }
        }
    }
}
