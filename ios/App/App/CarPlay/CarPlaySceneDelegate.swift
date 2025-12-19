//
//  CarPlaySceneDelegate.swift
//  App
//
//  Created for CarPlay integration
//

import CarPlay
import Foundation

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var contentManager: CarPlayContentManager?
    private var nowPlayingManager: CarPlayNowPlayingManager?

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                   didConnect interfaceController: CPInterfaceController) {
        AbsLogger.info(message: "CarPlay connected")

        self.interfaceController = interfaceController

        // Initialize managers
        self.contentManager = CarPlayContentManager(interfaceController: interfaceController)
        self.nowPlayingManager = CarPlayNowPlayingManager()

        // Set up the root template
        setupRootTemplate()

        // Subscribe to player events
        setupNotificationObservers()

        // Post CarPlay connected notification
        NotificationCenter.default.post(name: NSNotification.Name(PlayerEvents.carPlayConnected.rawValue), object: nil)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                   didDisconnect interfaceController: CPInterfaceController) {
        AbsLogger.info(message: "CarPlay disconnected")

        // Clean up
        removeNotificationObservers()
        CarPlaySearchManager.shared.setInterfaceController(nil)
        self.contentManager = nil
        self.nowPlayingManager = nil
        self.interfaceController = nil

        // Post CarPlay disconnected notification
        NotificationCenter.default.post(name: NSNotification.Name(PlayerEvents.carPlayDisconnected.rawValue), object: nil)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                   didSelect navigationAlert: CPNavigationAlert) {
        // Handle navigation alerts if needed
    }

    // MARK: - Setup

    private func setupRootTemplate() {
        guard let contentManager = contentManager else { return }

        // Set interface controller on search manager
        CarPlaySearchManager.shared.setInterfaceController(interfaceController)

        // Create tab bar with main sections
        let tabBarTemplate = contentManager.createRootTabBarTemplate()
        interfaceController?.setRootTemplate(tabBarTemplate, animated: true, completion: nil)
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlayerUpdate),
            name: NSNotification.Name(PlayerEvents.update.rawValue),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackClosed),
            name: NSNotification.Name(PlayerEvents.closed.rawValue),
            object: nil
        )
    }

    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Player Event Handlers

    @objc private func handlePlayerUpdate() {
        nowPlayingManager?.updateNowPlaying()
    }

    @objc private func handlePlaybackClosed() {
        nowPlayingManager?.clearNowPlaying()
    }
}
