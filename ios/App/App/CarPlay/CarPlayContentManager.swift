//
//  CarPlayContentManager.swift
//  App
//
//  Created for CarPlay integration
//

import CarPlay
import Foundation

class CarPlayContentManager {

    private weak var interfaceController: CPInterfaceController?
    private let dataProvider: CarPlayDataProvider
    private let imageLoader: CarPlayImageLoader

    // Tab templates
    private var libraryTemplate: CPListTemplate?
    private var continueListeningTemplate: CPListTemplate?
    private var downloadsTemplate: CPListTemplate?
    private var searchTemplate: CPSearchTemplate?

    init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        self.dataProvider = CarPlayDataProvider()
        self.imageLoader = CarPlayImageLoader()
    }

    // MARK: - Root Template

    func createRootTabBarTemplate() -> CPTabBarTemplate {
        // Create Continue Listening tab
        continueListeningTemplate = createContinueListeningTemplate()

        // Create Library tab
        libraryTemplate = createLibraryTemplate()

        // Create Downloads tab
        downloadsTemplate = createDownloadsTemplate()

        // Create Search tab
        searchTemplate = createSearchTemplate()

        let tabBarTemplate = CPTabBarTemplate(templates: [
            continueListeningTemplate!,
            libraryTemplate!,
            downloadsTemplate!,
            searchTemplate!
        ])

        return tabBarTemplate
    }

    // MARK: - Continue Listening Tab

    private func createContinueListeningTemplate() -> CPListTemplate {
        let template = CPListTemplate(title: "Continue", sections: [])
        template.tabSystemItem = .recents
        template.tabImage = UIImage(systemName: "play.circle")

        refreshContinueListeningContent(template: template)

        return template
    }

    private func refreshContinueListeningContent(template: CPListTemplate) {
        dataProvider.fetchContinueListeningItems { [weak self] items in
            guard let self = self else { return }

            if items.isEmpty {
                let emptyItem = CPListItem(text: "No items in progress", detailText: "Start listening to see items here")
                emptyItem.isEnabled = false
                template.updateSections([CPListSection(items: [emptyItem])])
                return
            }

            var listItems: [CPListItem] = []

            for item in items {
                let listItem = self.createListItem(from: item)
                listItems.append(listItem)
            }

            template.updateSections([CPListSection(items: listItems)])
        }
    }

    // MARK: - Library Tab

    private func createLibraryTemplate() -> CPListTemplate {
        let template = CPListTemplate(title: "Library", sections: [])
        template.tabSystemItem = .mostViewed
        template.tabImage = UIImage(systemName: "books.vertical")

        // Load library categories asynchronously
        refreshLibraryContent(template: template)

        return template
    }

    private func refreshLibraryContent(template: CPListTemplate) {
        // Check if connected to server
        guard Store.serverConfig != nil else {
            let offlineItem = CPListItem(text: "Not Connected", detailText: "Open app to connect to server")
            offlineItem.isEnabled = false
            template.updateSections([CPListSection(items: [offlineItem])])
            return
        }

        // Create category list items
        var items: [CPListItem] = []

        // Audiobooks section
        let audiobooksItem = CPListItem(text: "Audiobooks", detailText: nil)
        audiobooksItem.accessoryType = .disclosureIndicator
        audiobooksItem.handler = { [weak self] _, completion in
            self?.showAudiobooksLibrary()
            completion()
        }
        items.append(audiobooksItem)

        // Podcasts section
        let podcastsItem = CPListItem(text: "Podcasts", detailText: nil)
        podcastsItem.accessoryType = .disclosureIndicator
        podcastsItem.handler = { [weak self] _, completion in
            self?.showPodcastsLibrary()
            completion()
        }
        items.append(podcastsItem)

        // Browse by Author
        let authorsItem = CPListItem(text: "Authors", detailText: nil)
        authorsItem.accessoryType = .disclosureIndicator
        authorsItem.handler = { [weak self] _, completion in
            self?.showAuthors()
            completion()
        }
        items.append(authorsItem)

        // Browse by Series
        let seriesItem = CPListItem(text: "Series", detailText: nil)
        seriesItem.accessoryType = .disclosureIndicator
        seriesItem.handler = { [weak self] _, completion in
            self?.showSeries()
            completion()
        }
        items.append(seriesItem)

        // Browse by Genre
        let genresItem = CPListItem(text: "Genres", detailText: nil)
        genresItem.accessoryType = .disclosureIndicator
        genresItem.handler = { [weak self] _, completion in
            self?.showGenres()
            completion()
        }
        items.append(genresItem)

        template.updateSections([CPListSection(items: items)])
    }

    // MARK: - Downloads Tab

    private func createDownloadsTemplate() -> CPListTemplate {
        let template = CPListTemplate(title: "Downloads", sections: [])
        template.tabSystemItem = .downloads
        template.tabImage = UIImage(systemName: "arrow.down.circle")

        refreshDownloadsContent(template: template)

        return template
    }

    private func refreshDownloadsContent(template: CPListTemplate) {
        let localItems = Database.shared.getLocalLibraryItems()

        if localItems.isEmpty {
            let emptyItem = CPListItem(text: "No downloads", detailText: "Download audiobooks to listen offline")
            emptyItem.isEnabled = false
            template.updateSections([CPListSection(items: [emptyItem])])
            return
        }

        var listItems: [CPListItem] = []

        for item in localItems {
            let title = item.media?.metadata?.title ?? "Unknown"
            let author = item.media?.metadata?.authorDisplayName ?? "Unknown Author"

            let listItem = CPListItem(text: title, detailText: author)
            listItem.accessoryType = .disclosureIndicator

            // Load artwork
            if let coverUrl = item.coverUrl {
                imageLoader.loadImage(from: coverUrl) { image in
                    if let image = image {
                        listItem.setImage(image)
                    }
                }
            }

            // Handle selection - capture item.id to avoid realm threading issues
            let localItemId = item.id
            listItem.handler = { [weak self] _, completion in
                self?.playLocalItem(localItemId: localItemId)
                completion()
            }

            listItems.append(listItem)
        }

        template.updateSections([CPListSection(items: listItems)])
    }

    // MARK: - Search Tab

    private func createSearchTemplate() -> CPSearchTemplate {
        let template = CPSearchTemplate()
        template.tabSystemItem = .search
        template.tabImage = UIImage(systemName: "magnifyingglass")
        template.delegate = CarPlaySearchManager.shared

        return template
    }

    // MARK: - Navigation Helpers

    private func showAudiobooksLibrary() {
        showLoadingTemplate(title: "Audiobooks")

        dataProvider.fetchLibraryItems(mediaType: "book") { [weak self] items in
            guard let self = self else { return }

            let listItems = items.map { self.createListItem(from: $0) }
            let template = CPListTemplate(title: "Audiobooks", sections: [CPListSection(items: listItems)])

            // Pop loading template and push real content
            self.interfaceController?.popTemplate(animated: false, completion: nil)
            self.interfaceController?.pushTemplate(template, animated: true, completion: nil)
        }
    }

    private func showPodcastsLibrary() {
        showLoadingTemplate(title: "Podcasts")

        dataProvider.fetchLibraryItems(mediaType: "podcast") { [weak self] items in
            guard let self = self else { return }

            let listItems = items.map { self.createListItem(from: $0) }
            let template = CPListTemplate(title: "Podcasts", sections: [CPListSection(items: listItems)])

            self.interfaceController?.popTemplate(animated: false, completion: nil)
            self.interfaceController?.pushTemplate(template, animated: true, completion: nil)
        }
    }

    private func showAuthors() {
        showLoadingTemplate(title: "Authors")

        dataProvider.fetchAuthors { [weak self] authors in
            guard let self = self else { return }

            var listItems: [CPListItem] = []
            for author in authors {
                let item = CPListItem(text: author.name, detailText: nil)
                item.accessoryType = .disclosureIndicator
                let authorId = author.id
                let authorName = author.name
                item.handler = { [weak self] _, completion in
                    self?.showItemsByAuthor(authorId: authorId, authorName: authorName)
                    completion()
                }
                listItems.append(item)
            }

            let template = CPListTemplate(title: "Authors", sections: [CPListSection(items: listItems)])
            self.interfaceController?.popTemplate(animated: false, completion: nil)
            self.interfaceController?.pushTemplate(template, animated: true, completion: nil)
        }
    }

    private func showSeries() {
        showLoadingTemplate(title: "Series")

        dataProvider.fetchSeries { [weak self] seriesList in
            guard let self = self else { return }

            var listItems: [CPListItem] = []
            for series in seriesList {
                let item = CPListItem(text: series.name, detailText: nil)
                item.accessoryType = .disclosureIndicator
                let seriesId = series.id
                let seriesName = series.name
                item.handler = { [weak self] _, completion in
                    self?.showItemsBySeries(seriesId: seriesId, seriesName: seriesName)
                    completion()
                }
                listItems.append(item)
            }

            let template = CPListTemplate(title: "Series", sections: [CPListSection(items: listItems)])
            self.interfaceController?.popTemplate(animated: false, completion: nil)
            self.interfaceController?.pushTemplate(template, animated: true, completion: nil)
        }
    }

    private func showGenres() {
        showLoadingTemplate(title: "Genres")

        dataProvider.fetchGenres { [weak self] genres in
            guard let self = self else { return }

            var listItems: [CPListItem] = []
            for genre in genres {
                let item = CPListItem(text: genre, detailText: nil)
                item.accessoryType = .disclosureIndicator
                item.handler = { [weak self] _, completion in
                    self?.showItemsByGenre(genre: genre)
                    completion()
                }
                listItems.append(item)
            }

            let template = CPListTemplate(title: "Genres", sections: [CPListSection(items: listItems)])
            self.interfaceController?.popTemplate(animated: false, completion: nil)
            self.interfaceController?.pushTemplate(template, animated: true, completion: nil)
        }
    }

    private func showItemsByAuthor(authorId: String, authorName: String) {
        showLoadingTemplate(title: authorName)

        dataProvider.fetchItemsByAuthor(authorId: authorId) { [weak self] items in
            self?.pushItemsList(title: authorName, items: items)
        }
    }

    private func showItemsBySeries(seriesId: String, seriesName: String) {
        showLoadingTemplate(title: seriesName)

        dataProvider.fetchItemsBySeries(seriesId: seriesId) { [weak self] items in
            self?.pushItemsList(title: seriesName, items: items)
        }
    }

    private func showItemsByGenre(genre: String) {
        showLoadingTemplate(title: genre)

        dataProvider.fetchItemsByGenre(genre: genre) { [weak self] items in
            self?.pushItemsList(title: genre, items: items)
        }
    }

    private func pushItemsList(title: String, items: [CarPlayLibraryItem]) {
        let listItems = items.map { createListItem(from: $0) }
        let template = CPListTemplate(title: title, sections: [CPListSection(items: listItems)])
        interfaceController?.popTemplate(animated: false, completion: nil)
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func showLoadingTemplate(title: String) {
        let loadingItem = CPListItem(text: "Loading...", detailText: nil)
        loadingItem.isEnabled = false
        let loadingTemplate = CPListTemplate(title: title, sections: [CPListSection(items: [loadingItem])])
        interfaceController?.pushTemplate(loadingTemplate, animated: true, completion: nil)
    }

    // MARK: - Item Creation

    private func createListItem(from item: CarPlayLibraryItem) -> CPListItem {
        let listItem = CPListItem(
            text: item.title,
            detailText: item.subtitle
        )
        listItem.accessoryType = .disclosureIndicator

        // Load artwork asynchronously
        if let coverUrl = item.coverUrl {
            imageLoader.loadImage(from: coverUrl) { image in
                if let image = image {
                    listItem.setImage(image)
                }
            }
        }

        // Capture values for the handler
        let isLocal = item.isLocal
        let localItemId = item.localLibraryItem?.id
        let libraryItemId = item.libraryItemId
        let episodeId = item.episodeId

        // Set up playback handler
        listItem.handler = { [weak self] _, completion in
            if isLocal, let localItemId = localItemId {
                self?.playLocalItem(localItemId: localItemId, episodeId: episodeId)
            } else if let libraryItemId = libraryItemId {
                self?.playServerItem(libraryItemId: libraryItemId, episodeId: episodeId)
            }
            completion()
        }

        return listItem
    }

    // MARK: - Playback

    private func playLocalItem(localItemId: String, episodeId: String? = nil) {
        guard let localItem = Database.shared.getLocalLibraryItem(localLibraryItemId: localItemId) else {
            AbsLogger.error(message: "CarPlay: Local item not found: \(localItemId)")
            return
        }

        // Get the episode if provided
        let episode = episodeId != nil ? localItem.getPodcastEpisode(episodeId: episodeId) : nil

        let session = localItem.getPlaybackSession(episode: episode)

        do {
            try session.save()
            let playbackRate = PlayerSettings.main().playbackRate
            PlayerHandler.startPlayback(sessionId: session.id, playWhenReady: true, playbackRate: playbackRate)
            showNowPlaying()
        } catch {
            AbsLogger.error(message: "CarPlay: Failed to start local playback: \(error)")
        }
    }

    private func playServerItem(libraryItemId: String, episodeId: String?) {
        ApiClient.startPlaybackSession(libraryItemId: libraryItemId, episodeId: episodeId, forceTranscode: false) { [weak self] session in
            guard !session.id.isEmpty else {
                AbsLogger.error(message: "CarPlay: Failed to create server playback session")
                return
            }

            do {
                try session.save()
                let playbackRate = PlayerSettings.main().playbackRate
                PlayerHandler.startPlayback(sessionId: session.id, playWhenReady: true, playbackRate: playbackRate)
                self?.showNowPlaying()
            } catch {
                AbsLogger.error(message: "CarPlay: Failed to start server playback: \(error)")
            }
        }
    }

    private func showNowPlaying() {
        let nowPlayingTemplate = CPNowPlayingTemplate.shared
        interfaceController?.pushTemplate(nowPlayingTemplate, animated: true, completion: nil)
    }
}
