//
//  SceneDelegate.swift
//  App
//
//  Created for CarPlay integration
//

import UIKit
import Capacitor

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let initialViewController = storyboard.instantiateInitialViewController()
        window?.rootViewController = initialViewController
        window?.makeKeyAndVisible()

        // Handle any URLs passed on launch
        if let urlContext = connectionOptions.urlContexts.first {
            handleURL(urlContext.url)
        }

        // Handle user activities (Universal Links)
        if let userActivity = connectionOptions.userActivities.first {
            _ = handleUserActivity(userActivity)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleURL(url)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        _ = handleUserActivity(userActivity)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        AbsLogger.info(message: "Audiobookshelf scene is now active")
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Handle as needed
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        AbsLogger.info(message: "Audiobookshelf scene is now in background")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        AbsLogger.info(message: "Audiobookshelf scene is now in foreground")
    }

    // MARK: - Private Helpers

    private func handleURL(_ url: URL) {
        _ = ApplicationDelegateProxy.shared.application(UIApplication.shared, open: url, options: [:])
    }

    private func handleUserActivity(_ userActivity: NSUserActivity) -> Bool {
        return ApplicationDelegateProxy.shared.application(UIApplication.shared, continue: userActivity, restorationHandler: { _ in })
    }
}
